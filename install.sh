#!/usr/bin/env bash
##
# Installs an Arch-based NAS onto the specified disk.
# It will partition the disk and install the OS.
#
# No arguments are needed, guided prompts will follow.
##
# TODO: Add banners/section announcements with timestamps
# TODO: Prompts for variables instead of vars.sh
# TODO: Copy over public key, defaulting to id_rsa, offer to make new one?
# TODO: Set up SMB user and SMB shares
# TODO: Add prompts for options in addition to vars
# TODO: Define service list in outer script
# TODO: Setup ufw
# TODO: Add a post-install fix or TODO log (e.g. timezone lookup failed, FYI it's UTC)
# TODO: Run services in Docker? Rockstor-like plugins but much simpler?
# TODO: Figure out the device busy thing that occurs on second run of this script
##

set -euo pipefail
[[ -n ${TRACE:-} ]] && set -x
[[ $(uname -r) != *ARCH* ]] && echo "This script can only run on Arch Linux!" && exit 1

script_name="${0##*/}"
LOG_FILE="${LOG_FILE:-${script_name%.*}.log}"
exec > >(tee -i "$LOG_FILE"); exec 2>&1
trap 'echo ERROR on line $LINENO in $script_name' ERR
start_time="$(date +%s)"

source vars.sh
export USERNAME=${USERNAME:-nasuser}
export HOST_NAME=${HOST_NAME:-archnas}
export DOMAIN=${DOMAIN:-local}
export TIMEZONE=${TIMEZONE:-auto}
ROOT_LABEL=${ROOT_LABEL:-system}
BOOT_PART_SIZE=${BOOT_PART_SIZE:-550}
SWAP_PART_SIZE=${SWAP_PART_SIZE:-8192}

# UEFI system partition location
export ESP=${ESP:-/boot}

packages=(
  base
  base-devel
  btrfs-progs
  bind-tools
  efibootmgr
  git
  grub
  htop
  intel-ucode
  jq
  libva-intel-driver
  libvdpau-va-gl
  libutil-linux
  lm_sensors
  neovim
  netdata
  monit
  openssh
  python
  python-pip
  python2
  python2-pip
  ranger
  rsync
  sudo
  samba
  snapper
  smartmontools
  syncthing
  tmux
  ufw
  wget
  zsh
)

bail() {
  echo "$@" && exit 1
}

red="$(tput setaf 1)"
green="$(tput setaf 2)"
yellow="$(tput setaf 3)"
blue="$(tput setaf 4)"
bold="$(tput bold)"
clr="$(tput sgr0)"
yellow() { printf %s "${yellow}${bold}$*${clr}"; }
green() { printf %s "${green}${bold}$*${clr}"; }
red() { printf %s "${red}${bold}$*${clr}"; }
blue() { printf %s "${blue}${bold}$*${clr}"; }
bold() { printf %s "${bold}$*${clr}"; }

install() {
  select_disk system_device

  timedatectl set-ntp true

  echo
  echo "`yellow NOTICE:` ArchNAS is about to be installed onto disk: `yellow "$system_device"`"
  echo "Continue? This will `red DESTROY` any existing data."
  read -rp "Type YES to proceed, or anything else to abort: " continue
  [[ $continue != "YES" ]] && bail "Aborting installation"

  cbanner $green$bold "Installing..."
  echo
  echo "Output is logged to a file named `green "$LOG_FILE"`"

  wipefs -af "$system_device"
  parted "$system_device" mklabel gpt

  parted "$system_device" mkpart primary fat32 1MiB $((1+BOOT_PART_SIZE))MiB
  set 1 esp on
  parted "$system_device" mkpart primary linux-swap $((1+BOOT_PART_SIZE))MiB $((1+BOOT_PART_SIZE+SWAP_PART_SIZE))MiB
  parted "$system_device" mkpart primary $((1+BOOT_PART_SIZE+SWAP_PART_SIZE))MiB 100%

  parts=($(fdisk -l "$system_device" | awk '/^\/dev/ {print $1}'))
  boot_part="${parts[0]}"
  swap_part="${parts[1]}"
  root_part="${parts[2]}"

  # Create partitions
  mkswap "$swap_part"
  swapon "$swap_part"
  mkfs.fat -F32 "$boot_part"
  mkfs.btrfs -f -L "$ROOT_LABEL" "$root_part"

  # Always mount root partition before next steps
  mount "$root_part" /mnt

  mkdir -p /mnt${ESP}
  mount "$boot_part" /mnt${ESP}

  pacstrap /mnt "${packages[@]}"

  # Add discard flag to enable SSD trim.
  genfstab -U /mnt | sed 's/ssd/ssd,discard/' > /mnt/etc/fstab

  # Print out fstab for logging purposes.
  cat /mnt/etc/fstab

  # Perform the part of the install that runs inside the chroot.
  arch-chroot /mnt /bin/bash < inside-chroot.sh

  cbanner $green$bold "...done!"

  local elapsed=$(( $(date +%s) - start_time ))
  echo "Installation ran for $(( elapsed / 60 )) minutes and $(( elapsed % 60)) seconds"

  set_temp_password temp_password
  print_password_notice

  umount -R /mnt

  read -rp $'Installation complete! Jot down your password and press enter to reboot.\n'
  reboot
}

# Colored banner, first arg should be character(s) from tput
cbanner() {
  printf %s $1
  shift
  figlet "$*"
  printf %s $clr
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
  echo "Choose a disk to auto-partition. Any existing data will be lost. Press CTRL-C to abort."
  PS3=$'\nChoose disk #) '
  IFS=$'\n'
  trap 'unset PS3; unset IFS' RETURN

  local disks
  mapfile -t disks < <(list_disks)
  select disk in ${disks[@]}; do
    # If input is a number and within the range of options
    if [[ $REPLY =~ ^[0-9]$ ]] && (( REPLY > 0 )) && (( REPLY <= ${#disks[@]} )); then
      read -r "$1" < <(echo "$disk" | awk '{print $1}')
      break
    else
      echo "That's not a valid option, please choose again."
    fi
  done
}

# Set a random, temporary, 4 character password for the user. The password will
# be set inside the chroot and the user will be required to change it upon next login.
# $1 - out variable that will store the temp password
set_temp_password() {
  # Use a random 4 character string as the initial password
  read -r "$1" < <(openssl rand -hex 2)
  eval "printf '%s:%s' $USERNAME \$$1" | chpasswd --root /mnt
  passwd --quiet --root /mnt --expire "$USERNAME"
}

print_password_notice() {
  printf %s $red$bold
  figlet -f small "Password NOTICE"
  printf %s $clr
  cat << EOF
A temporary password is used for the first login, after which you will be asked to choose a new password.

The temporary password for `bold $USERNAME` is: `red "$temp_password"`

EOF
}

prereqs=(
  figlet
)
if ! command -v "${prereqs[0]}" $>/dev/null; then
  echo `blue "Installing prereqs..."`
  pacman --noconfirm -Syq ${prereqs[@]}
  clear
  sleep 1
  printf %s $blue$bold
  figlet ArchNAS
  printf %s $clr
fi

# TODO: redo tmux?
install "$@"
