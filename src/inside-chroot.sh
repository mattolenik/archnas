#!/usr/bin/env bash
[[ -n ${TRACE:-} ]] && set -x && export TRACE
set -euo pipefail
trap 'echo ERROR on line $LINENO in file inside-chroot.sh' ERR
HOME="/home/$USERNAME"
FIRSTBOOT="$HOME/firstboot.sh"

main() {
  setup_clock
  set_locale "$LOCALE"
  set_hostname "$HOST_NAME" "$DOMAIN"

  pacman -Syu
  # Packages
  upgrade_pip

  # Root setup steps
  setup_services
  write_firstboot_func firstboot_ufw
  setup_smb

  # User setup and preferences
  setup_users
  setup_zsh
  setup_bash
  chown -R "$USERNAME:$USERNAME" "$HOME"

  # User install steps
  install_yay
  install_plexpass
  install_ups
  install_go

  install_bootloader

  cleanup
}

cleanup() {
  rm -rf /tmp/*
  rm -rf /var/log/*
  # Remove bash and zsh history from all users
  # shellcheck disable=SC2038
  find /root /home -type f \( -name .bash_history -o -name .zsh_history \) | xargs rm -f
  # Remove temporary nopasswd on sudo
  rm /etc/sudoers.d/20-wheel
}

get_github_latest_release() {
  curl -s "https://api.github.com/repos/$1/releases/latest" | jq -r '.assets[].browser_download_url'
}

install_bootloader() {
  grub-install --target=x86_64-efi --efi-directory="$ESP" --bootloader-id=GRUB
  grub-mkconfig -o /boot/grub/grub.cfg

}

install_ups() {
  yay_install network-ups-tools
  cat <<EOF > /etc/ups/ups.conf
[ups]
    driver = usbhid-ups
    port = auto
EOF
}

upgrade_pip() {
  pip install pip --upgrade
  pip2 install pip --upgrade
}

install_zfs() {
  yay_install zfs-dkms
}

yay_install() {
  sudo -u "$USERNAME" yay --noconfirm -Sy "$@"
}

install_plexpass() {
  yay_install plex-media-server-plexpass
  # Plex config
  conf=/etc/systemd/system/plexmediaserver.service.d/restrict.conf
  mkdir -p "$(dirname "$conf")"
  cat << 'EOF' > "$conf"
[Service]
ReadOnlyDirectories=/
ReadWriteDirectories=/var/lib/plex /tmp
EOF
  write_firstboot_func "firstboot_plex"
  systemctl enable plexmediaserver
}

firstboot_plex() {
  # Firewall rules
  # Plex general port
  ufw allow 32400
  # Plex GDM network discovery
  ufw allow 32410/udp
  ufw allow 32412:32414/udp
  # Plex DLNA
  ufw allow 32469/tcp
  ufw allow 1900/udp
}

install_yay() {
  (
    cd "$(mktemp -d)"
    curl -sSL "$(get_github_latest_release Jguer/yay)" | tar xz --strip-components=1
    mv yay /usr/bin
    mv yay.8 /usr/share/man/
    mv bash /etc/bashrc.d/yay
    mv zsh /etc/zshrc.d/yay
  )
}

install_go() {
  pacman --noconfirm -S go
  cat << EOF >> /etc/profile.d/go.sh
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"
EOF
}

setup_clock() {
  # shellcheck disable=SC2155
  local tz="$(get_geoip_info "$(get_external_ip)" time_zone || true)"
  [[ $TIMEZONE == auto-detect ]] && export TIMEZONE="${tz:-UTC}"
  echo "Setting timezone to $TIMEZONE"
  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  hwclock --systohc
}

set_locale() {
  echo "$1.UTF-8 UTF-8" > /etc/locale.gen
  echo "LANG=$1.UTF-8" > /etc/locale.conf
  locale-gen
}

# Sets hostname and domain
# $1 - hostname
# $2 - domain
set_hostname() {
  echo "$1" > /etc/hostname
  echo "127.0.0.1 $1.$2 $1" >> /etc/hosts
}

# Appends a string to the firstboot script
# $@ - all args are appended as a string
write_firstboot() {
  if [[ ! -f "$FIRSTBOOT" ]]; then
    cat << EOF > "$FIRSTBOOT"
#!/usr/bin/env bash
set -euo pipefail

EOF
  chmod +x "$FIRSTBOOT"
  fi
  echo "$@" >> "$FIRSTBOOT"
}

write_firstboot_func() {
  write_firstboot "$(type "$1")"
  write_firstboot "$1"
}

firstboot_ufw() {
  ufw enable
  ufw default allow outgoing
  ufw default deny incoming
  ufw allow ssh
  ufw limit ssh
}

setup_smb() {
  write_firstboot_func firstboot_smb
}

firstboot_smb() {
  # CIFS
  ufw allow 137:138/udp
  ufw allow 139/tcp
  ufw allow 445/tcp
}

setup_users() {
  echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/10-wheel
  # Temporarily override the first entry and lift password requirement during setup
  echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/20-wheel
  echo "Defaults lecture = never" > /etc/sudoers.d/disable-lecture
  echo "PermitRootLogin no" >> /etc/ssh/sshd_config
  useradd -d "$HOME" -G docker,wheel -s "$(command -v zsh)" "$USERNAME"
  mkdir -p "$HOME/.ssh"
  touch "$HOME/.ssh/authorized_keys"
  passwd -l root
}

setup_zsh() {
  zshrc="$HOME/.zshrc"
  zshrc_dir="/etc/zshrc.d"
  touch "$zshrc"
  mkdir -p "$zshrc_dir"

  # Add a better default shell with directory and exit status
  cat << 'SHELL' >> /etc/zsh/zprofile
export PS1='%n@%m %~'$'\n''%(?..%? )%(!.#.$) '
SHELL

  # This will prefix the rc files with the contents of SHELL
  cat << SHELL | cat - "$zshrc" | tee "$zshrc"
# Uncomment to automatically source all files in $zshrc_dir
#for f in "$zshrc_dir/*"; do
#  [[ -f \$f ]] && source "\$f"
#done
#
# Or a source a specific file
# source $zshrc_dir/myfile
SHELL
}

setup_bash() {
  bashrc_dir="/etc/bashrc.d"
  bashrc="$HOME/.bashrc"
  touch "$bashrc"
  mkdir -p "$bashrc_dir"

  # Add a better default shell with directory and exit status
  cat << 'SHELL' >> /etc/bash.bashrc
export PS1="\u@\h \w\n\$? \\$ \[$(tput sgr0)\]"
SHELL

  # This will prefix the rc files with the contents of SHELL.
  cat << SHELL | cat - "$bashrc" | tee "$bashrc"
# Uncomment to automatically source all files in $bashrc_dir
#for f in "$bashrc_dir/*"; do
#  [[ -f \$f ]] && source "\$f"
#done
#
# Or a source a specific file
# source $bashrc_dir/myfile
SHELL
}

setup_services() {
  services=(
    docker
    nmb
    smb
    sshd
    ufw
  )
  systemctl enable "${services[@]}"
}

main "$@"
