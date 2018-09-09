#!/usr/bin/env bash
#[[ -n ${TRACE:-} ]] && set -x
set -exuo pipefail
exec > >(tee -i "${LOG_FILE:-install.log}")
exec 2>&1

hostname=nas
domain=home.lan
username=nasuser
password=lemmein123

packages=(
  base
  base-devel
  efibootmgr
  f2fs-tools
  intel-ucode
  libva-intel-driver
  libvdpau-va-gl
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
  sudo
  systemd-boot
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

  pacstrap /mnt "${packages[@]}" --ignore "${packages_ignore[@]}"

  genfstab -U /mnt >> /mnt/etc/fstab

  arch-chroot /mnt

  setup_clock

  set_locale

  set_hostname "$hostname" "$domain"

  #pip install pip --upgrade
  #pip2 install pip --upgrade
  #pip install neovim
  #pip2 install neovim

  bootctl --path=$ESP install
  write_pacman_systemd_boot_hook
  write_loader_conf
  write_loader_entry

  install_yay

  install_plexpass

  setup_users

  exit
  umount -R /mnt
}

install_plexpass() {
  yay -Syu plex-media-server-plexpass
  write_plex_config
}

install_yay() {
  tmp="$(mktemp)"
  trap 'rm -rf $tmp' RETURN
  git clone https://aur.archlinux.org/yay.git "$tmp"
  cd "$tmp"
  makepkg -si
}

setup_clock() {
  ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
  hwclock --systohc
}

setup_users() {
  useradd -d "/home/$username" -G wheel -s "$(command -v zsh)" "$username"
  printf '%s:%s' "$username" "$password" | chpasswd
  # Force change upon next login
  passwd --expire "$username"
  echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
  passwd -l root
}

set_locale() {
  echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
  echo 'LANG=en_US.UTF-8' > /etc/locale.conf
  locale-gen
}

set_hostname() {
  local hostname="$1"
  local domain="$2"
  echo "$hostname" > /etc/hostname
  echo "127.0.0.1	$hostname.$domain $hostname" >> /etc/hosts
}

write_loader_conf() {
  cat << EOF > $ESP/loader/loader.conf
default arch
timeout 3
editor  no
EOF
}

write_loader_entry() {
  cat << EOF > $ESP/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=LABEL=arch_os rw
EOF
}

write_plex_config() {
  cat << EOF > /etc/systemd/system/plexmediaserver.service.d/restrict.conf
[Service]
ReadOnlyDirectories=/
ReadWriteDirectories=/var/lib/plex /tmp
EOF
}

write_pacman_systemd_boot_hook() {
  cat << EOF > /etc/pacman.d/hooks/systemd-boot.hook
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Updating systemd-boot
When = PostTransaction
Exec = /usr/bin/bootctl update
EOF

if [[ ${1:-} != startup ]]; then
  pacman --noconfirm -Sy tmux
  exec tmux new-session -d -s "'$0' startup $@"
fi

shift
install "$@"
