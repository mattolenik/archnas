#!/usr/bin/env bash
set -euo pipefail
trap 'echo ERROR on line $LINENO in file inside-chroot.sh' ERR
HOME="/home/$USERNAME"

main() {
  setup_users
  setup_zsh
  setup_bash

  install_pip
  setup_clock
  set_locale "$LOCALE"
  set_hostname "$HOST_NAME" "$DOMAIN"

  grub-install --target=x86_64-efi --efi-directory="$ESP" --bootloader-id=GRUB
  grub-mkconfig -o /boot/grub/grub.cfg

  install_yay
  install_plexpass
  install_ups

  setup_services

  chown -R "$USERNAME:$USERNAME" "$HOME"
  cleanup
}

cleanup() {
  rm -rf /tmp/*
  rm -rf /var/log/*
  # Remove bash and zsh history from all users
  # shellcheck disable=SC2038
  find /root /home -type f \( -name .bash_history -o -name .zsh_history \) | xargs rm -f
}

get_github_latest_release() {
  curl -s "https://api.github.com/repos/$1/releases/latest" | jq -r '.assets[].browser_download_url'
}

install_ups() {
  su -c "yay -Syu network-ups-tools" -s /bin/sh "$USERNAME"
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
  su -c "yay -Syu plex-media-server-plexpass" -s /bin/sh "$USERNAME"
  write_plex_config
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

setup_clock() {
  # shellcheck disable=SC2155
  [[ $TIMEZONE == auto-detect ]] && export TIMEZONE="$(get_timezone_by_ip "$(get_external_ip)")"
  echo "Setting timezone to $TIMEZONE"
  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  hwclock --systohc
}

set_locale() {
  echo "$1.UTF-8 UTF-8" > /etc/locale.gen
  locale-gen
  localectl set-locale "LANG=$1.UTF-8"
}

set_hostname() {
  local hostname="$1"
  local domain="$2"
  echo "$hostname" > /etc/hostname
  echo "127.0.0.1 $hostname.$domain $hostname" >> /etc/hosts
}

get_external_ip() {
  local output
  if ! output=$(dig +short myip.opendns.com @resolver1.opendns.com); then
    echo NULL
  fi
  echo "$output"
}

get_timezone_by_ip() {
  [[ $1 == NULL ]] && echo UTC && return
  # Try to resolve timezone by geolocation of IP, default to UTC in case of failure
  curl --max-time 30 --fail --silent "https://freegeoip.app/json/$1" 2>/dev/null | jq -r .time_zone || echo UTC
}

setup_users() {
  echo "%wheel ALL=(ALL) ALL"   > /etc/sudoers.d/wheel
  echo "Defaults lecture = never" > /etc/sudoers.d/disable-lecture
  echo "PermitRootLogin no" >> /etc/ssh/sshd_config
  useradd -d "$HOME" -G wheel -s "$(command -v zsh)" "$USERNAME"
  mkdir -p "$HOME"
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
    dhcpcd
    nmb
    smb
    sshd
    ufw
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
