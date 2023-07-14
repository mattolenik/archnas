#!/usr/bin/env bash
[[ -n ${TRACE:-} ]] && set -x && export TRACE
set -euo pipefail
source /tmp/install-vars.sh
trap 'echo ERROR on line $LINENO in file inside-chroot.sh' ERR
HOME="/home/$USERNAME"
FIRSTBOOT="$HOME/firstboot.sh"
ARCH=x86_64
ALLOWED_NETWORK="192.168.0.0/16"

main() {
  setup_clock
  set_locale "$LOCALE"
  set_hostname "$HOST_NAME" "$DOMAIN"

  # User setup and preferences
  setup_users
  setup_zsh
  setup_bash
  chown -R "$USERNAME:$USERNAME" "$HOME"

  pacman -Syu
  install_yay
  install_plexpass
  install_ups
  install_go
  install_zfs

  setup_services

  write_firstboot_func firstboot_ufw

  install_bootloader

  # Require manual upgrade of kernel so as to ensure it does not become out of sync with zfs-linux or zfs-linux-lts.
  # The versions for linux and zfs-linux should always match.
  echo "IgnorePkg=linux linux-lts linux-headers linux-lts-headers" >> /etc/pacman.conf

  cleanup
}

cleanup() {
  rm -rf /tmp/*
  rm -rf /var/log/*
  # Remove bash and zsh history from all users
  # shellcheck disable=SC2038
  find /root /home -type f \( -name .bash_history -o -name .zsh_history \) | xargs rm -f
}

add_ssh_key_from_github() {
  local username="$1"
  if [[ -n $username ]]; then
    echo "Allowing SSH for GitHub user $1"
    mkdir -p $HOME/.ssh
    curl https://github.com/$1.keys | tee -a $HOME/.ssh/authorized_keys
  fi
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
  mkdir -p /etc/ups
  cat <<EOF > /etc/ups/ups.conf
[ups]
    driver = usbhid-ups
    port = auto
EOF
}

install_zfs() {
  yay_install zfs-linux-lts zfs-linux-lts-headers
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

install_go() {
  pacman --noconfirm -S go
  cat << 'EOF' >> /etc/profile.d/go.sh
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
  echo "$2" > /etc/domain
  echo "127.0.0.1 $1.$2 $1" >> /etc/hosts
  echo 'HOSTNAME="$(cat /etc/hostname)"' >> /etc/profile
  echo 'DOMAIN="$(cat /etc/domain)"' >> /etc/profile
  echo 'FQDN="$HOSTNAME.$DOMAIN"' >> /etc/profile
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
  echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-wheel
  echo "Defaults lecture = never" > /etc/sudoers.d/disable-lecture
  echo "PermitRootLogin no" >> /etc/ssh/sshd_config
  echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
  useradd -d "$HOME" -G docker,wheel -s "$(command -v zsh)" "$USERNAME"
  mkdir -p "$HOME/.ssh"
  passwd -l root
  chpasswd <<< "$USERNAME:$PASSWORD"
  add_ssh_key_from_github "$GITHUB_USERNAME"
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
# Automatically source all files in $zshrc_dir
for f in "$zshrc_dir/*"; do
  [[ -f \$f ]] && source "\$f"
done
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
# Automatically source all files in $bashrc_dir
for f in "$bashrc_dir/*"; do
  [[ -f \$f ]] && source "\$f"
done
SHELL
}

setup_services() {
  services=(
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
  systemctl enable "${services[@]}"
}

main "$@"

