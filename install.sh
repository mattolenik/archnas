#!/usr/bin/env bash
##
# Installs an Arch-based NAS onto the specified disk.
# It will partition the disk and install the OS.
#
# Args:
#   $1 - Device to be auto-partitioned, e.g. /dev/sda.
#        Existing data will be removed.
##

# TODO: Add banners/section announcements with timestamps

[[ -n ${TRACE:-} ]] && set -x
set -euo pipefail

script_name="${0##*/}"
script_noext="${script_name%.*}"
exec > >(tee -i "${LOG_FILE:-$script_noext.log}"); exec 2>&1

trap 'echo ERROR on line $LINENO in "$(basename -- "$0")"' ERR

source vars.sh
export HOSTNAME
export DOMAIN
export USERNAME
export TIMEZONE=${TIMEZONE:-auto}
BOOT_PART_SIZE=${BOOT_PART_SIZE:-550}
SWAP_PART_SIZE=${SWAP_PART_SIZE:-4096}

# UEFI system partition location
export ESP=/boot
export PASSWORD_FILE=/userpassword

packages=(
  base
  base-devel
  btrfs-progs
  efibootmgr
  git
  grub
  intel-ucode
  jq
  libva-intel-driver
  libvdpau-va-gl
  libutil-linux
  linux-lts
  linux-lts-headers
  lm_sensors
  neovim
  monit
  openssh
  python
  python-pip
  python2
  python2-pip
  sudo
  samba
  snapper
  smartmontools
  tmux
  zsh
)

packages_ignore=(
  linux
  linux-headers
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

install() {
  system_device="${1:-}"
  [[ -z $system_device ]] && bail "First argument must be device for system install"

  timedatectl set-ntp true

  echo
  echo "`yellow NOTICE:` ArchNAS is about to installed onto disk: `yellow $system_device`"
  echo "Continue? This will `red destroy` any existing data."
  read -rp "Type YES to proceed, or anything else to abort: " continue
  [[ $continue != "YES" ]] && bail "Aborting installation"

  print_install_banner

  wipefs -a "$system_device"
  parted "$system_device" mklabel gpt

  parted "$system_device" mkpart primary fat32 1MiB $((1+BOOT_PART_SIZE))MiB
  set 1 esp on
  parted "$system_device" mkpart primary linux-swap $((1+BOOT_PART_SIZE))MiB $((1+BOOT_PART_SIZE+SWAP_PART_SIZE))MiB
  parted "$system_device" mkpart primary $((1+BOOT_PART_SIZE+SWAP_PART_SIZE))MiB 100%

  parts=($(fdisk -l "$system_device" | awk '/^\/dev/ {print $1}'))
  boot_part="${parts[0]}"
  swap_part="${parts[1]}"
  root_part="${parts[2]}"
  root_label=system

  mkswap "$swap_part"
  mkfs.fat -F32 "$boot_part"
  mkfs.btrfs -f -L "$root_label" "$root_part"
  mount "$root_part" /mnt
  mkdir -p /mnt${ESP}
  mount "$boot_part" /mnt${ESP}

  pacstrap /mnt "${packages[@]}" --ignore "${packages_ignore[@]}"

  # Add discard flag to enable SSD trim
  genfstab -U /mnt | sed 's/ssd/ssd,discard/' > /mnt/etc/fstab

  cat /mnt/etc/fstab

  cat inside-chroot.sh | arch-chroot /mnt /bin/bash

  print_done_banner
  print_password_notice "/mnt/$PASSWORD_FILE"
  rm -f "/mnt/$PASSWORD_FILE"

  umount -R /mnt

  read -rp $'Installation complete! Jot down your password and press enter to reboot\n'
  reboot
}

get_disk_devices() {
  lsblk -o name,type -nrd | awk '/disk$/ {print $1}'
}

print_install_banner() {
  printf %s $bold$blue
  cat <<'EOF'
 ___
  |  ._   _ _|_  _. | | o ._   _
 _|_ | | _>  |_ (_| | | | | | (_| o o o
                               _|
EOF
  printf %s $clr
}

print_done_banner() {
  printf %s $bold$green
  cat <<'EOF'
  _
 | \  _  ._   _  |
 |_/ (_) | | (/_ o

EOF
  printf $clr
}

print_password_notice() {
  local pass_file="$1"
  printf %s $bold$red
  cat << 'EOF'
  __           _   ___    ___  __    _       __  __        _   _   _
 (_   /\ \  / |_    | |_|  |  (_    |_) /\  (_  (_ \    / / \ |_) | \ |
 __) /--\ \/  |_    | | | _|_ __)   |  /--\ __) __) \/\/  \_/ | \ |_/ o
EOF
  cat << EOF
Your `red "temporary password"` for user $USERNAME is: `red "$(< "$pass_file")"`
You will be prompted to choose a new password upon first login.

EOF
}

install "$@"
