#!/usr/bin/env bash
[[ -n ${TRACE:-} ]] && set -x && export TRACE
set -euo pipefail
trap 'echo ERROR on line $LINENO in file inside-chroot.sh' ERR
HOME="/home/$USER_NAME"
ARCH="${ARCH:-x86_64}"

SERVICES=(
  avahi-daemon
  cockpit.socket
  firstboot
  frigate
  grub-btrfsd
  libvirtd
  monit
  nmb
  plexmediaserver
  smb
  sshd
  systemd-networkd
  systemd-resolved
  ufw
  zfs.target
  zfs-mount
)

main() {
  setup_clock
  set_locale "$LOCALE"
  setup_users
  install_packages
  build_tools
  setup_services
  install_bootloader
  mkdir -p /var/cache/netdata
  cleanup
}


cleanup() {
  rm -rf /tmp/*
  # Remove leftovers from AUR builds
  rm -rf "$HOME/go"
  passwd -d root
  passwd -l root
  exit 0
}

install_packages() {
  install_yay
  runuser -u "$USER_NAME" -- yay --noconfirm -Sy "${aur_packages[@]}"
}

build_tools() {
  go build -o /usr/bin/tepid /usr/src/tepid/main.go  # templating tool to assist with inserting systemd creds into config files
}

add_ssh_key_from_github() {
  echo "Allowing SSH for GitHub user $1"
  mkdir -m 0700 "$HOME/.ssh"
  curl -sS "https://github.com/$1.keys" >> "$HOME/.ssh/authorized_keys"
  chmod 600 "$HOME/.ssh/authorized_keys"
}

install_bootloader() {
  grub-install --target="$ARCH-efi" --efi-directory="$ESP" --bootloader-id=GRUB
  grub-mkconfig -o /boot/grub/grub.cfg
}

install_yay() {
  (
    cd "$(mktemp -d)"
    curl -sSL "$(github_get_latest_release Jguer/yay | grep "$ARCH")" | tar xz --strip-components=1
    mv -f yay /usr/bin/
    mv -f yay.8 /usr/share/man/
    mkdir -p /etc/bashrc.d /etc/zshrc.d
    mv -f bash /etc/bashrc.d/yay
    mv -f zsh /etc/zshrc.d/yay
  )
}

set_locale() {
  echo "$1.UTF-8 UTF-8" > /etc/locale.gen
  echo "LANG=$1.UTF-8" > /etc/locale.conf
  locale-gen
}

setup_clock() {
  echo "Setting timezone to $TIMEZONE"
  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  hwclock --systohc
}

setup_users() {
  echo "Setting up user $USER_NAME"
  useradd -m -G adm,log,sys,uucp,wheel -s "$(command -v zsh)" "$USER_NAME"
  chpasswd <<< "$USER_NAME:$PASSWORD"
  add_ssh_key_from_github "$GITHUB_USERNAME"
  # shellcheck disable=SC2016
  echo 'command -v starship &>/dev/null && eval "$(starship init bash)"' >> "$HOME/.bashrc"
  # shellcheck disable=SC2016
  echo 'command -v starship &>/dev/null && eval "$(starship init zsh)"'  >> "$HOME/.zshrc"
  chown -c -R "$USER_NAME:$USER_NAME" "$HOME"
}

setup_services() {
  systemctl enable "${SERVICES[@]}"
}

main "$@"

