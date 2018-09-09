#!/usr/bin/env bash
#[[ -n ${TRACE:-} ]] && set -x
set -euo pipefail
exec > >(tee -i "${LOG_FILE:-install.log}")
exec 2>&1

hostname=nas
domain=home.lan
username=nasuser
password=lemmein123

packages=(
  base
  base-devel
  btrfs-progs
  efibootmgr
  f2fs-tools
  git
  go
  grub
  intel-ucode
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

ESP=/boot

bail() {
  echo "$@" && exit 1
}

install() {
  timedatectl set-ntp true

  system_device="${1:-}"
  [[ -z $system_device ]] && bail "First argument must be device for system install"

  echo "Continue installation onto $system_device? This will destroy any existing data."
  read -rp "Type YES to proceed, anything else to abort) " continue
  [[ $continue != "YES" ]] && bail "Aborting installation"

  set -x
  wipefs -a "$system_device"
  parted "$system_device" mklabel gpt

  parted "$system_device" mkpart primary fat32 1MiB 551MiB
  set 1 esp on
  parted "$system_device" mkpart primary linux-swap 551MiB 9GiB
  parted "$system_device" mkpart primary 9GiB 100%

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

  genfstab -U /mnt >> /mnt/etc/fstab

  cat /mnt/etc/fstab

  export ESP="$esp"
  export HOSTNAME="$hostname"
  export DOMAIN="$domain"
  export USERNAME="$username"
  export PASSWORD="$password"
  cat inside-chroot.sh | arch-chroot /mnt /bin/bash
  umount -R /mnt
  echo "Done!"
}

install "$@"
