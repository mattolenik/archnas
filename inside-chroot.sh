#!/usr/bin/env bash

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

write_plex_config() {
  cat << EOF > /etc/systemd/system/plexmediaserver.service.d/restrict.conf
[Service]
ReadOnlyDirectories=/
ReadWriteDirectories=/var/lib/plex /tmp
EOF
}

setup_clock
set_locale
set_hostname "$HOSTNAME" "$DOMAIN"

grub-install --target=x86_64-efi --efi-directory=$ESP --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

install_yay
install_plexpass

pip install pip --upgrade
pip2 install pip --upgrade
pip install neovim
pip2 install neovim

echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
useradd -d "/home/$USERNAME" -G wheel -s "$(command -v zsh)" "$USERNAME"
passwd --expire "$USERNAME"
#printf '%s:%s' "$USERNAME" "$PASSWORD" | chpasswd
passwd -l root
