#!/usr/bin/env bash
[[ -n ${TRACE:-} ]] && set -x && export TRACE
set -euo pipefail
trap 'echo ERROR on line $LINENO in file inside-chroot.sh' ERR
HOME="/home/$USER_NAME"
ARCH="${ARCH:-x86_64}"
FIRSTBOOT_SCRIPT="/var/tmp/firstboot.sh"

SERVICES=(
  cockpit.socket
  firstboot
  frigate
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
  setup_swap
  setup_clock
  set_locale "$LOCALE"
  setup_users
  install_packages
  setup_services
  write_firstboot setup_ufw
  install_bootloader
  chmod -c -R 0600 /etc/credstore*
  cleanup
}

cleanup() {
  rm -rf /tmp/*
  rm -rf /var/log/*
  # Remove bash and zsh history from all users
  # shellcheck disable=SC2038
  find /root /home -type f \( -name .bash_history -o -name .zsh_history \) | xargs rm -f
  # Remove leftovers from AUR builds
  rm -rf "$HOME/go"
  passwd -l root &>/dev/null
}

install_packages() {
  install_yay
  runuser -u "$USER_NAME" -- yay --noconfirm -Sy ${aur_packages[@]}
}

add_ssh_key_from_github() {
  echo "Allowing SSH for GitHub user $1"
  mkdir -m 0700 -p $HOME/.ssh
  curl -sS "https://github.com/$1.keys" >> $HOME/.ssh/authorized_keys
  chmod 600 $HOME/.ssh/authorized_keys
}

install_bootloader() {
  grub-install --target=$ARCH-efi --efi-directory="$ESP" --bootloader-id=GRUB
  grub-mkconfig -o /boot/grub/grub.cfg
}

install_yay() {
  (
    cd "$(mktemp -d)"
    curl -sSL "$(github_get_latest_release Jguer/yay | grep $ARCH)" | tar xz --strip-components=1
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

setup_swap() {
  btrfs subvolume create /swap
  btrfs filesystem mkswapfile --size ${SWAPFILE_SIZE} --uuid clear /swap/swapfile
  swapon /swap/swapfile
  echo "/swap/swapfile none swap defaults 0 0" >> /etc/fstab
}

 # must be done in firstboot
setup_ufw() {
  ufw enable
  ufw default allow outgoing
  ufw default deny incoming

  local allow=(
    cockpit       # Cockpit web UI
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
    plex          # Plex web UI
    rsync         # Backup
    rtsp          # Used by Frigate
    rtsps         # Used by Frigate
    smtp          # Mail relay
    ssh           # SSH
    syslog        # Accept logs from other hosts
    webrtc        # Used by Frigate
  )
  for svc in "${allow[@]}"; do
    ufw allow "$svc"
  done
  ufw limit ssh
  ufw limit smtp 30/minute
}

setup_users() {
  echo "Setting up user $USER_NAME"
  useradd -m -G adm,log,sys,uucp,wheel -s "$(command -v zsh)" "$USER_NAME"
  chpasswd <<< "$USER_NAME:$PASSWORD"
  add_ssh_key_from_github "$GITHUB_USERNAME"
  echo 'command -v starship &>/dev/null && eval "$(starship init bash)"' >> "$HOME/.bashrc"
  echo 'command -v starship &>/dev/null && eval "$(starship init zsh)"'  >> "$HOME/.zshrc"
  chown -c -R "$USER_NAME:$USER_NAME" "$HOME"
}

setup_services() {
  systemctl enable "${SERVICES[@]}"
}

write_firstboot() {
  echo "SERVICES=(${SERVICES[*]})" >> "$FIRSTBOOT_SCRIPT"
  # Copy the functions into the script
  for func in "$@"; do
    type "$func" | sed 1d >> "$FIRSTBOOT_SCRIPT"
  done
  # Copy the function calls into the script, surrounding with set -x and set +x if TRACE is set
  if [[ -n ${TRACE:-} ]]; then
    echo "set -x" >> "$FIRSTBOOT_SCRIPT"
  fi
  for func in "$@"; do
    echo "$func" >> "$FIRSTBOOT_SCRIPT"
  done
  if [[ -n ${TRACE:-} ]]; then
    echo "set +x" >> "$FIRSTBOOT_SCRIPT"
  fi
}

main "$@"


