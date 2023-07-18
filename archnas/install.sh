#!/usr/bin/env bash
# shellcheck disable=SC2006
##
# Installs an Arch-based NAS onto the specified disk.
# It will partition the disk and install the OS.
#
# No arguments are needed, guided prompts will follow.
##
# TODO: Set up SMB user and SMB shares
# TODO: Add help
##

set -euo pipefail
[[ -n ${TRACE:-} ]] && set -x && export TRACE
#[[ $(uname -r) != *arch* ]] && echo "This script can only run on Arch Linux!" && exit 1

# Elevate to root if necessary, usually only needed during testing
[[ $EUID != 0 ]] && exec sudo "$0" "$@"

script_name="${0##*/}"
LOG_FILE="${LOG_FILE:-${script_name%.*}.log}"
exec > >(tee -i "$LOG_FILE"); exec 2>&1
trap 'echo ERROR on line $LINENO in $script_name' ERR

IMPORT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
source "${IMPORT}/hue.sh" @import
source "${IMPORT}/args.sh"
source "${IMPORT}/common.sh"
source "${IMPORT}/geolocation.sh"
source "${IMPORT}/packages.sh"

JQ_URL="https://github.com/jqlang/jq/releases/download/jq-1.6/jq-linux64"

# UEFI system partition location
ESP=${ESP:-/boot/efi}
SWAP_PART_SIZE=${SWAP_PART_SIZE:-16384}
BOOT_PART_SIZE=${BOOT_PART_SIZE:-550}

is_test() { [[ -n ${IS_TEST:-} ]]; }

install() {
  ask LOCALE "Enter a locale" "*" "${LOCALE:-en_US}"
  ask HOST_NAME "Enter a hostname" "*" "${HOST_NAME:-archnas}"
  ask DOMAIN "Enter the domain" "*" "${DOMAIN:-local}"
  ask TIMEZONE "Enter timezone" "*" "${TIMEZONE:-auto-detect}"
  ask GITHUB_USERNAME "Add public key of GitHub user for SSH access (optional)" "*" "${GITHUB_USERNAME:-}"
  ask USER_NAME "Enter a username" "*" "${USER_NAME:-${HOST_NAME}user}"
  ask_password_confirm PASSWORD "Enter a password for ${USER_NAME}" "*"

  echo
  local system_device
  select_disk system_device
  confirm_disk "$"

  timedatectl set-ntp true

  start_time="$(date +%s)"
  boxbanner "Installing..." "$GREEN$BOLD_"
  echo
  echo "Output is logged to a file named `green "$LOG_FILE"`"

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
  mkfs.btrfs -f -L "system" "$root_part"

  # Always mount root partition before next steps
  mount --mkdir "$root_part" /mnt
  mount --mkdir "$boot_part" "/mnt${ESP}"

  # The following installs 'base' but without the 'linux' package.
  # This allows the desired kernel, e.g. 'linux-lts', it to be specified packages.sh
  local base_packages
  readarray -t base_packages < <(pacman -Sgq base | grep -Ev '^linux$')

  # Bootstrap
  pacstrap -K /mnt ${base_packages[@]} ${system_packages[@]}

  rsync -v $IMPORT/fs/copy/ /mnt/

  # The contents of the fs/append tree are not copied into the new install but added/appended to any existing files.
  # This provides a convenient way to modify configuration by just writing it in files and having it merged for you.
  for f in $(find $IMPORT/fs/append -type f); do
    local destFile="/mnt/${f#$IMPORT/fs/append/}"
    mkdir -p "$(dirname "$destFile")"
    echo Appending "$f" to "$destFile"
    echo | cat - ${f} >> "$destFile"
  done

  # Set hostname and domain
  echo "$HOST_NAME" > /mnt/etc/hostname
  echo "$DOMAIN" > /mnt/etc/domain
  echo "127.0.0.1 localhost $HOST_NAME.$DOMAIN $HOST_NAME" >> /mnt/etc/hosts

  genfstab -U /mnt | tee /mnt/etc/fstab

  export_vars ESP LOCALE USER_NAME PASSWORD TIMEZONE GITHUB_USERNAME |
    cat - "$IMPORT/packages.sh" "$IMPORT/geolocation.sh" "$IMPORT/inside-chroot.sh" |
    arch-chroot /mnt /bin/bash

  boxbanner "Done!" "$GREEN$BOLD_"

  local elapsed=$(( $(date +%s) - start_time ))
  echo "Installation ran for $(( elapsed / 60 )) minutes and $(( elapsed % 60)) seconds"

  if ! is_test; then
    umount -R /mnt
  fi

  echo $'\nInstallation complete! Remove installation media and reboot.'
}

confirm_disk() {
  if [[ -n ${AUTO_APPROVE:-} ]]; then return 0; fi
  local continue
  echo "`red NOTICE:` ArchNAS is about to be installed onto disk: `red "$1"`"
  echo "Continue? This will `red DESTROY` any existing data."
  read -rp "Type YES to proceed, or anything else to abort: " continue
  if [[ $continue != "YES" ]]; then
    fail "Aborting installation"
  fi
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

install_prereqs() {
  curl -sSLo /usr/bin/jq "$JQ_URL"
  chmod +x /usr/bin/jq
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
      USER_NAME="$1"
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
    *)
      fail "Unknown option '$__$opt'"
  esac
}

parse_args handle_option positionals "$@"

main "$@"
