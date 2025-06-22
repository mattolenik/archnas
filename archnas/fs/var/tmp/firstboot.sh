#!/usr/bin/env bash
[[ -n ${TRACE:-} ]] && set -x && export TRACE
set -exuo pipefail

SWAPFILE_SIZE="${SWAPFILE_SIZE:-8G}"

script_name="${0##*/}"
LOG_FILE="/var/log/${LOG_FILE:-${script_name%.*}.log}"
exec > >(tee -i "$LOG_FILE"); exec 2>&1
trap 'echo ERROR on line $LINENO in $script_name' ERR
trap cleanup EXIT

cleanup() {
  systemctl --no-block disable firstboot.service
  rm -f /etc/systemd/system/firstboot.service "$0"
}

setup_creds() {
  mkdir -p /creds/frigate/rtsp
}

setup_snapper() {
  snapper -c root create-config /
  # setup pacman snapshotting, done after installation to avoid snapshotting during install.
  pacman -S --noconfirm snap-pac
}


setup_swap() {
  btrfs subvolume create -p /swap
  btrfs filesystem mkswapfile --size "$SWAPFILE_SIZE" --uuid clear /swap/swapfile
  swapon /swap/swapfile
  echo "/swap/swapfile none swap defaults 0 0" >> /etc/fstab
}

setup_ufw() {
  ufw enable
  ufw default allow outgoing
  ufw default deny incoming

  ufw route allow in on eno1 out on podman0

  local allow=(
    CIFS            # File and print sharing
    Cockpit         # Cockpit web UI
    Frigate         # Frigate NVR web UI
    http            # HTTP on 80
    https           # HTTPS on 443
    Mail            # SMTPS for mail proxy
    Monit           # Monit web UI
    NFS             # Network File Sharing
    nut             # Network UPS Tools
    Plex            # Plex Server
    rsync           # Backup
    ssh             # SSH
    Syslog          # syslog server
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

setup_swap
setup_creds
setup_snapper
setup_ufw

