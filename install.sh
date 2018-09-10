#!/usr/bin/env bash
[[ -n ${TRACE:-} ]] && set -x
set -euo pipefail
script_name="${0##*/}"
script_noext="${script_name%.*}"
exec > >(tee -i "${LOG_FILE:-$script_noext.log}"); exec 2>&1

##
# Installs an Arch-based NAS onto the specified disk.
# It will partition the disk and install the OS.
# $1 - Device to be partitioned, e.g. /dev/sda
##

source vars.sh
export HOSTNAME
export DOMAIN
export USERNAME
export TIMEZONE=${TIMEZONE:-auto}
BOOT_PART_SIZE=${BOOT_PART_SIZE:-550}
SWAP_PART_SIZE=${SWAP_PART_SIZE:-4096}

# UEFI system partition location
export ESP=/boot


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

install() {
  system_device="${1:-}"
  [[ -z $system_device ]] && bail "First argument must be device for system install"

  timedatectl set-ntp true

  echo "NOTICE: Continue installation onto $system_device? This will destroy any existing data."
  read -rp "Type YES to proceed, anything else to abort: " continue
  [[ $continue != "YES" ]] && bail "Aborting installation"

  print_install_banner

  set -x
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

  pacstrap /mnt ${packages[@]} --ignore ${packages_ignore[@]}

  # Add discard flag to enable SSD trim
  genfstab -U /mnt | sed 's/ssd/ssd,discard/' > /mnt/etc/fstab

  cat /mnt/etc/fstab

  cat inside-chroot.sh | arch-chroot /mnt /bin/bash

  print_done_banner
  print_password_notice
  rm -f /mnt/userpassword

  umount -R /mnt
}

print_install_banner() {
  cat <<'EOF'
$(tput setaf 4)
  _____              _          _  _  _
 |_   _|            | |        | || |(_)
   | |   _ __   ___ | |_  __ _ | || | _  _ __    __ _
   | |  | '_ \ / __|| __|/ _` || || || || '_ \  / _` |
  _| |_ | | | |\__ \| |_| (_| || || || || | | || (_| | _  _  _
 |_____||_| |_||___/ \__|\__,_||_||_||_||_| |_| \__, |(_)(_)(_)
                                                 __/ |
                                                |___/
$(tput sgr0)
EOF
}

print_done_banner() {
  cat <<'EOF'
$(tput setaf 4)
  _____                       _
 |  __ \                     | |
 | |  | |  ___   _ __    ___ | |
 | |  | | / _ \ | '_ \  / _ \| |
 | |__| || (_) || | | ||  __/|_|
 |_____/  \___/ |_| |_| \___|(_)
$(tput sgr0)
EOF
}

print_password_notice() {
  cat << EOF
$(tput setaf 1)
╔═╗╔═╗╦  ╦╔═╗  ╔╦╗╦ ╦╦╔═╗  ╔═╗╔═╗╔═╗╔═╗╦ ╦╔═╗╦═╗╔╦╗  ╦
╚═╗╠═╣╚╗╔╝║╣    ║ ╠═╣║╚═╗  ╠═╝╠═╣╚═╗╚═╗║║║║ ║╠╦╝ ║║  ║
╚═╝╩ ╩ ╚╝ ╚═╝   ╩ ╩ ╩╩╚═╝  ╩  ╩ ╩╚═╝╚═╝╚╩╝╚═╝╩╚══╩╝  o
$(tput sgr0)
Your initial password for user $USERNAME: $(tput setaf 1)$(cat /mnt/userpassword)$(tput sgr0)
EOF
}

install "$@"
