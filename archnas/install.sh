#!/usr/bin/env bash
# shellcheck disable=SC2006
##
# Installs an Arch-based NAS onto the specified disk.
# It will partition the disk and install the OS.
#
# No arguments are needed, guided prompts will follow.
##
# TODO: Copy over public key, defaulting to id_rsa, offer to make new one?
# TODO: Set up SMB user and SMB shares
# TODO: Setup ufw
# TODO: Add help
# TODO: Copy over custom SSL cert for web UIs
# TODO: Break into multiple files/functions, groups/tags
# TODO: Install AUR packages
##

set -euo pipefail
[[ -n ${TRACE:-} ]] && set -x && export TRACE
[[ $(uname -r) != *arch* ]] && echo "This script can only run on Arch Linux!" && exit 1

# Elevate to root if necessary, usually only needed during testing
[[ $EUID != 0 ]] && exec sudo "$0" "$@"

script_name="${0##*/}"
LOG_FILE="${LOG_FILE:-${script_name%.*}.log}"
exec > >(tee -i "$LOG_FILE"); exec 2>&1
trap 'echo ERROR on line $LINENO in $script_name' ERR
start_time="$(date +%s)"

IMPORT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
source "${IMPORT}/hue.sh" @import
source "${IMPORT}/args.sh"
source "${IMPORT}/common.sh"
source "${IMPORT}/geolocation.sh"

ROOT_LABEL=${ROOT_LABEL:-system}
CHROOT_SCRIPT="${IMPORT}/inside-chroot.sh"

PACKAGE_FILE="${IMPORT}/packages.txt"
PACKAGE_IGNORE_FILE="${IMPORT}/packages-ignore.txt"

# UEFI system partition location
export ESP=${ESP:-/boot}

unset USERNAME

COMMENT_REGEX='^[[:blank:]]*$|#'
strip_comments() { grep -Ev  "$1"; }

is_test() { [[ -n ${IS_TEST:-} ]]; }

install() {
  ask LOCALE "Enter a locale" "*" "${LOCALE:-en_US}"
  ask USERNAME "Enter a username" "*" "${USERNAME:-nasuser}"
  ask HOST_NAME "Enter a hostname" "*" "${HOST_NAME:-archnas}"
  ask DOMAIN "Enter the domain" "*" "${DOMAIN:-local}"
  ask TIMEZONE "Enter timezone" "*" "${TIMEZONE:-auto-detect}"
  ask GITHUB_USERNAME "Add public key of GitHub user for SSH access (optional)" "*" "${GITHUB_USERNAME:-}"
  export LOCALE=${LOCALE:-"en_US"}
  export USERNAME
  export HOST_NAME
  export DOMAIN
  export TIMEZONE
  export GITHUB_USERNAME

  echo
  local system_device
  select_disk system_device

  timedatectl set-ntp true

  boxbanner "Installing..." "$GREEN$BOLD_"
  echo
  echo "Output is logged to a file named `green "$LOG_FILE"`"

  SWAP_PART_SIZE=${SWAP_PART_SIZE:-8192}
  BOOT_PART_SIZE=${BOOT_PART_SIZE:-550}

  wipefs -af "$system_device"
  parted "$system_device" mklabel gpt
  parted "$system_device" mkpart primary fat32 1MiB $((1+BOOT_PART_SIZE))MiB
  set 1 esp on
  parted "$system_device" mkpart primary linux-swap $((1+BOOT_PART_SIZE))MiB $((1+BOOT_PART_SIZE+SWAP_PART_SIZE))MiB
  parted "$system_device" mkpart primary $((1+BOOT_PART_SIZE+SWAP_PART_SIZE))MiB 100%

  local parts
  readarray -t parts < <(sfdisk -J "$system_device" | jq -r '.partitiontable.partitions[].node')
  local boot_part="${parts[0]}"
  local swap_part="${parts[1]}"
  local root_part="${parts[2]}"

  # Create partitions
  mkswap "$swap_part"
  swapon "$swap_part"
  mkfs.fat -F32 "$boot_part"
  mkfs.btrfs -f -L "$ROOT_LABEL" "$root_part"

  # Always mount root partition before next steps
  mount "$root_part" /mnt

  mkdir -p "/mnt${ESP}"
  mount "$boot_part" "/mnt${ESP}"

  local packages packages_ignore
  # The following installs 'base' but without the 'linux' package.
  # This allows the desired kernel, e.g. 'linux-lts', it to be specified in the "$PACKAGE_FILE"
  readarray -t packages < <(pacman -Sgq base | grep -Ev '^linux$' | cat - "$PACKAGE_FILE" |  sort -u)
  readarray -t packages_ignore < <(grep -Ev "$COMMENT_REGEX" "$PACKAGE_IGNORE_FILE" | sort -u)
  pacstrap /mnt ${packages[@]} ${packages_ignore[@]/#/--ignore }

  # Generate mounty stuff
  genfstab -U /mnt | tee /mnt/etc/fstab

  # Perform the part of the install that runs inside the chroot.
  cat "$IMPORT/geolocation.sh" "$CHROOT_SCRIPT" | arch-chroot /mnt /bin/bash

  boxbanner "...done!" "$GREEN$BOLD_"

  local elapsed=$(( $(date +%s) - start_time ))
  echo "Installation ran for $(( elapsed / 60 )) minutes and $(( elapsed % 60)) seconds"

  set_user_password

  if ! is_test; then
    umount -R /mnt
  fi

  [[ -n ${AUTO_APPROVE:-} ]] && return
  read -rp $'\nInstallation complete! Press enter to reboot.\n'
  reboot
}

confirm_disk() {
  [[ -n ${AUTO_APPROVE:-} ]] && return 0
  local continue
  echo "`red NOTICE:` ArchNAS is about to be installed onto disk: `red "$1"`"
  echo "Continue? This will `red DESTROY` any existing data."
  read -rp "Type YES to proceed, or anything else to abort: " continue
  [[ $continue != "YES" ]] && fail "Aborting installation"
}

# Find available, writeable disks for install. It will print
# the following columns: name, size, model
list_disks() {
  lsblk -o type,ro,name,size,model -nrd | \
    awk '/^disk 0/ {printf "/dev/%s %s %s\n", $3, $4, $5}' | \
    sort | \
    column -t | \
    sed -E -e 's/\\x20/ /g' -e 's/[ ]+$//'
}

# Show a menu selection of disks and return the corresponding device file.
# $1 - out variable that will store the result
select_disk() {
  if [[ -n ${AUTO_APPROVE:-} ]]; then
    [[ -z $TARGET_DISK ]] && fail "Target disk must be specified when using auto-approve"
    read -r "$1" <<< "$TARGET_DISK"
    return 0
  fi

  echo "Choose a disk to auto-partition. Any existing data will be lost. Press CTRL-C to abort."
  PS3=$'\nChoose disk #) '
  IFS=$'\n'
  trap 'unset PS3; unset IFS' RETURN

  local disks
  mapfile -t disks < <(list_disks)
  select disk in "${disks[@]}"; do
    # If input is a number and within the range of options
    if [[ $REPLY =~ ^[0-9]$ ]] && (( REPLY > 0 )) && (( REPLY <= ${#disks[@]} )); then
      read -r "$1" < <(echo "$disk" | awk '{print $1}')
      break
    else
      echo "That's not a valid option, please choose again."
    fi
  done
}

set_user_password() {
  if [[ -n ${PASSWORD:-} ]]; then
    chpasswd --root /mnt <<< "$USERNAME:$PASSWORD"

  elif [[ -n ${AUTO_APPROVE:-} ]] || [[ ! -t 1 ]]; then
    [[ -z ${PASSWORD:-} ]] && fail "The --password option is required when using --auto-approve or when not in a tty"
    chpasswd --root /mnt <<< "$USERNAME:$PASSWORD"

  elif [[ -t 1 ]]; then
    echo
    echo "`red "One last thing!"` Set the password for `bold "$USERNAME"`"
    passwd --root /mnt "$USERNAME"
  fi
}

install_prereqs() {
  local prereqs=(jq)
  blue $'Installing prereqs...\n'
  pacman --noconfirm -Syq ${prereqs[@]}
}

main() {
  install_prereqs
  boxbanner "ArchNAS Installation" "$BLUE$BOLD_"
  install
}

username_regex='^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$'

handle_option() {
  local __="$1"
  local opt="$2"
  shift 2
  case $opt in
    auto-approve)
      export AUTO_APPROVE=1
      ;;
    target-disk)
      check_opt "$opt" "$1"
      TARGET_DISK="$1"
      ;;
    username)
      check_opt "$opt" "$1" "$username_regex" "The username '$1' is not valid"
      USERNAME="$1"
      ;;
    hostname)
      check_opt "$opt" "$1"
      HOST_NAME="$1"
      ;;
    locale)
      check_opt "$opt" "$1"
      LOCALE="$1"
      ;;
    domain)
      check_opt "$opt" "$1"
      DOMAIN="$1"
      ;;
    timezone)
      check_opt "$opt" "$1"
      TIMEZONE="$1"
      ;;
    github_username)
      check_opt "$opt" "$1"
      GITHUB_USERNAME="$1"
      ;;
    swap-size)
      check_opt "$opt" "$1" '^[0-9]{4,}$' "swap-size (megabytes) must be an integer value of at least 1000"
      SWAP_PART_SIZE="$1"
      ;;
    password)
      check_opt "$opt" "$1"
      PASSWORD="$1"
      ;;
    tmux)
      export USE_TMUX=1
      ;;
    *)
      fail "Unknown option '$__$opt'"
  esac
}

parse_args handle_option positionals "$@"

main "$@"
