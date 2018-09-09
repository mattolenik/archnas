#!/usr/bin/env bash
set -euo pipefail
hostname=nas
domain=home.lan
username=nasuser
password=lemmein123
packages=(
  base
  base-devel
  efibootmgr
  f2fs-tools
  grub
  intel-ucode
  libva-intel-driver
  libvdpau-va-gl
  linux-lts
  linux-lts-headers
  lm_sensors
  monit
  openssh
  samba
  snapper
  smartmontools
  sudo
  zsh
)
packages_ignore=(
  linux
  linux-headers
)

get_part_uuid() {
  blkid $1 | awk -F\" '/PARTUUID/ {print $2}'
}

bail() {
  echo "$@" 1>&2 && exit 1
}

install_yay() {
  tmp="$(mktemp)"
  trap "rm -rf $tmp" RETURN
  git clone https://aur.archlinux.org/yay.git "$tmp"
  cd "$tmp"
  makepkg -si
}

install() {
  timedatectl set-ntp true

  system_device="${1:-}"
  # TODO: Check if device is valid
  [[ -z $system_device ]] && bail "First argument must be device for system install"

  echo "Continue installation onto $system_device? This will destroy any existing data."
  read -p "Type YES to proceed, anything else to abort) " continue
  [[ $continue != "YES" ]] && bail "Aborting installation"

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
  boot_uuid="$(get_part_uuid "$boot_part")"
  root_uuid="$(get_part_uuid "$root_part")"
  root_label=system

  mkswap "$swap_part"
  mkfs.fat -F32 "$boot_part"
  mkfs.btrfs -f -L "$root_label" "$root_part"
  mount "$root_part" /mnt
  mkdir -p /mnt/efi
  mount "$boot_part" /mnt/efi

  pacstrap /mnt ${packages[@]} --ignore ${packages_ignore[@]}

  genfstab -U /mnt >> /mnt/etc/fstab

  arch-chroot /mnt

  ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
  hwclock --systohc

  echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
  echo 'LANG=en_US.UTF-8' > /etc/locale.conf
  locale-gen

  echo "$hostname" > /etc/hostname
  echo "127.0.0.1	$hostname.$domain $hostname" >> /etc/hosts

  write-efistub-update-path
  write-efistub-update-service
  systemctl enable efistub-update.path
  systemctl start efistub-update.path

  grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
  grub-mkconfig -o /boot/grub/grub.cfg

  install_yay

  yay -Syu plex-media-server-plexpass
  write_plex_config

  setup_users
  #umount -R /mnt
}

setup_users() {
  useradd -d "/home/$username" -G wheel -s "$(which zsh)" "$username"
  printf '%s:%s' "$username" "$password" | chpasswd
  echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
  passwd -l root
}

write-efistub-update-path() {
cat << 'EOF' > /etc/systemd/system/efistub-update.path
[Unit]
Description=Copy EFISTUB Kernel to EFI system partition

[Path]
PathChanged=/boot/initramfs-linux-fallback.img

[Install]
WantedBy=multi-user.target
WantedBy=system-update.target
EOF
}

write-efistub-update-service() {
cat << EOF > /etc/systemd/system/efistub-update.service
[Unit]
Description=Copy EFISTUB Kernel to EFI system partition

[Service]
Type=oneshot
ExecStart=/usr/bin/cp -af /boot/vmlinuz-linux esp/EFI/arch/
ExecStart=/usr/bin/cp -af /boot/initramfs-linux.img esp/EFI/arch/
ExecStart=/usr/bin/cp -af /boot/initramfs-linux-fallback.img esp/EFI/arch/
EOF
}

write_plex_config() {
cat << EOF > /etc/systemd/system/plexmediaserver.service.d/restrict.conf
[Service]
ReadOnlyDirectories=/
ReadWriteDirectories=/var/lib/plex /tmp
EOF
}

install "$@"
