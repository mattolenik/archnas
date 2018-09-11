#!/usr/bin/env bash
set -euo pipefail
trap 'echo ERROR on line $LINENO in "$(basename -- "$0")"' ERR
HOME="/home/$USERNAME"/
PURE_URL_PREFIX="https://github.com/sindresorhus/pure/blob/master"

main() {
  setup_users
  setup_zsh
  setup_bash

  install_pip
  setup_clock
  set_locale
  set_hostname "$HOSTNAME" "$DOMAIN"

  grub-install --target=x86_64-efi --efi-directory=$ESP --bootloader-id=GRUB
  grub-mkconfig -o /boot/grub/grub.cfg

  install_yay
  install_plexpass
  #install_ups

  setup_services

  set_user_password

  cleanup
}

cleanup() {
  rm -rf /tmp/*
  find /var/log -type f | xargs rm -f
  find /root /home -type f -name .bash_history | xargs rm -f
}

get_github_latest_release() {
  curl -s https://api.github.com/repos/$1/releases/latest | jq -r '.assets[].browser_download_url'
}


install_ups() {
  yay -Syu network-ups-tools
  cat <<EOF > /etc/ups/ups.conf
[ups]
    driver = usbhid-ups
    port = auto
EOF
}

install_pip() {
  pip install pip --upgrade
  pip2 install pip --upgrade
  pip install neovim
  pip2 install neovim
}

install_plexpass() {
  #sudo -u "$USERNAME" yay -Syu plex-media-server-plexpass
  write_plex_config
}

install_yay() {
  (
    cd $(mktemp -d)
    curl -sSL $(get_github_latest_release Jguer/yay) | tar xz --strip-components=1
    mv yay /usr/bin
    mv yay.8 /usr/share/man/
    mv bash /etc/bashrc.d/yay
    mv zsh /etc/zshrc.d/yay
  )
}

setup_clock() {
  [[ $TIMEZONE == auto ]] && export TIMEZONE="$(get_timezone_by_ip "$(get_external_ip)")"
  ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
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
  echo "127.0.0.1 $hostname.$domain $hostname" >> /etc/hosts
}

get_external_ip() {
  dig +short myip.opendns.com @resolver1.opendns.com
}

get_timezone_by_ip() {
  curl -s "https://freegeoip.app/json/$1" | jq -r .time_zone
}

setup_users() {
  echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
  echo "PermitRootLogin no" >> /etc/ssh/sshd_config
  useradd -d "$HOME" -G wheel -s "$(command -v zsh)" "$USERNAME"
  mkdir -p "$HOME"
  chown -R "$USERNAME:$USERNAME" "$HOME"
  passwd -l root
}

setup_zsh() {
  zshd="/etc/zshrc.d"
  usr_funcs="/usr/local/share/zsh/site-functions"
  zshd_funcs="$zshd/site-functions"
  mkdir -p "$zshd_funcs"
  mkdir -p "$usr_funcs"

  # Install Pure, a nicer prompt for zsh.
  wget -P "$zshd_funcs" "$PURE_URL_PREFIX/pure.zsh"
  wget -P "$zshd_funcs" "$PURE_URL_PREFIX/async.zsh"
  ln -s "$zshd_funcs/pure.zsh" "$usr_funcs/prompt_pure_setup"
  ln -s "$zshd_funcs/async.zsh" "$usr_funcs/async"

  # This will prefix the rc files with the contents of SHELL.
  zshrc="$HOME/.zshrc"
  cat << SHELL | cat - "$zshrc" | tee "$zshrc"
autoload -U promptinit; promptinit
prompt pure
source $zshd/*
SHELL
}

setup_bash() {
  bashd="/etc/bashrc.d"
  bashrc="$HOME/.bashrc"
  mkdir -p "$bashd"
  # This will prefix the rc files with the contents of SHELL.
  cat << SHELL | cat - "$bashrc" | tee "$bashrc"
source $bashd/*
SHELL
}

set_user_password() {
  local password="$(openssl rand -hex 3)"
  echo "$USERNAME:$password" | chpasswd
  passwd --expire "$USERNAME"
  echo "$password" > "$PASSWORD_FILE"
}

setup_services() {
  services=(
    dhcpcd
    nmb
    smb
    sshd
  )
  systemctl enable ${services[@]}
}

write_plex_config() {
  conf=/etc/systemd/system/plexmediaserver.service.d/restrict.conf
  mkdir -p "$(dirname "$conf")"
  cat << 'EOF' > "$conf"
[Service]
ReadOnlyDirectories=/
ReadWriteDirectories=/var/lib/plex /tmp
EOF
}

main "$@"
