#!/usr/bin/env bash
set -euo pipefail
hostname=nas
username=nasuser
packages=(
  base
  base-devel
  linux-lts
  linux-lts-headers
  lm_sensors
  monit
  samba
  smartmontools
  sudo
  systemd-swap
)
packages_ignore=(
  linux
)

get_part_uuid() {
  blkid $1 | awk -F\" '/PARTUUID/ {print $2}'
}

timedatectl set-ntp true

system_device=$1
# TODO: Check if device is valid

parted $system_device mklabel gpt

parted $system_device mkpart primary fat32 1MiB 551MiB
set 1 esp on
parted $system_device mkpart primary 551MiB 100%

parts=($(fdisk -l $device | awk '/^\/dev/ {print $1}'))
boot_part=${part[0]}
root_part=${part[1]}
boot_uuid=$(get_part_uuid $boot_part)
root_uuid=$(get_part_uuid $root_part)
root_label=system

mkfs.fat $boot_part
mkfs.f2fs -l $root_label $root_part
mount $root_part /mnt
mkdir -p /mnt/boot
mount $boot_part /mnt/boot

pacstrap /mnt ${packages[@]} --ignore ${packages_ignore[@]}

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
hwclock --systohc
locale-gen

echo $hostname > /etc/hostname
echo "127.0.0.1	$hostname.$domain $hostname" >> /etc/hosts

mkinitcpio -p linux

useradd -d -G wheel -s $(which zsh) $username

echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
passwd -l root

exit
umount -R /mnt
reboot
