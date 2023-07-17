#!/usr/bin/env bash
[[ -n ${TRACE:-} ]] && set -x && export TRACE
set -euo pipefail
trap 'echo ERROR on line $LINENO in file inside-chroot.sh' ERR
HOME="/home/$USERNAME"
ARCH="${ARCH:-x86_64}"

SERVICES=(
  docker
  dozzle
  frigate
  nmb
  plexmediaserver
  portainer
  smb
  sshd
  ufw
)

main() {
  setup_clock
  set_locale "$LOCALE"
  install_packages
  setup_users
  setup_services
  setup_ufw
  install_bootloader
  cleanup
}

cleanup() {
  rm -rf /tmp/*
  rm -rf /var/log/*
  # Remove bash and zsh history from all users
  # shellcheck disable=SC2038
  find /root /home -type f \( -name .bash_history -o -name .zsh_history \) | xargs rm -f
}

install_packages() {
  pacman -Syu
  install_yay
  yay_install "${aur_packages[@]}"
}

add_ssh_key_from_github() {
  local username="$1"
  if [[ -n $username ]]; then
    echo "Allowing SSH for GitHub user $1"
    mkdir -p $HOME/.ssh
    curl "https://github.com/$username.keys" | tee -a $HOME/.ssh/authorized_keys
    chmod -R 600 $HOME/.ssh
  fi
}

get_github_latest_release() {
  curl -s "https://api.github.com/repos/$1/releases/latest" | jq -r '.assets[].browser_download_url'
}

install_bootloader() {
  grub-install --target=x86_64-efi --efi-directory="$ESP" --bootloader-id=GRUB
  grub-mkconfig -o /boot/grub/grub.cfg
}

yay_install() {
  sudo -u "$USERNAME" yay --noconfirm -Sy "$@"
}

install_yay() {
  (
    cd "$(mktemp -d)"
    curl -sSL "$(get_github_latest_release Jguer/yay | grep $ARCH)" | tar xz --strip-components=1
    mv -f yay /usr/bin/
    mv -f yay.8 /usr/share/man/
    mkdir -p /etc/bashrc.d /etc/zshrc.d
    mv -f bash /etc/bashrc.d/yay
    mv -f zsh /etc/zshrc.d/yay
  )
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

setup_ufw() {
  ufw enable
  ufw default allow outgoing
  ufw default deny incoming

  local allow=(
    dozzle        # Docker container log viewer
    frigate       # Frigate NVR web UI
    http          # HTTP on 80
    https         # HTTPS on 443
    microsoft-ds  # Samba
    monit         # Monit web UI
    netbios-dgm   # Samba
    netbios-ns    # Samba
    netbios-ssn   # Samba
    nfs           # File sharing
    nut           # Network UPS Tools
    portainer     # Portainer web UI
    rsync         # Backup
    rtsp          # Used by Frigate
    rtsps         # Used by Frigate
    smtp          # Mail relay
    ssh           # SSH
    syslog        # Accept logs from other hosts
    webrtc        # Used by Frigate
  )
  local limit=(
    ssh
  )
  for svc in "${allow[@]}"; do
    ufw allow "$svc"
  done
  for svc in "${limit[@]}"; do
    ufw limit "$svc"
  done
}

setup_users() {
  useradd -d "$HOME" -G docker,wheel -s "$(command -v zsh)" "$USERNAME"
  chpasswd <<< "$USERNAME:$PASSWORD"
  add_ssh_key_from_github "$GITHUB_USERNAME"
  passwd -l root
  chown -R "$USERNAME:$USERNAME" "$HOME"
}

setup_services() {
  systemctl daemon-reload
  systemctl enable "${SERVICES[@]}" || true
}

main "$@"

