#!/usr/bin/env bash
[[ -n ${TRACE:-} ]] && set -x && export TRACE
set -exuo pipefail

script_name="${0##*/}"
LOG_FILE="/var/log/${LOG_FILE:-${script_name%.*}.log}"
exec > >(tee -i "$LOG_FILE"); exec 2>&1
trap 'echo ERROR on line $LINENO in $script_name' ERR

## misc
mkdir -p "$CREDENTIALS_DIRECTORY/frigate/rtsp"

snapper -c root create-config /
# setup pacman snapshotting, done after installation to avoid snapshotting during install.
pacman -S --noconfirm snap-pac

systemctl --no-block disable firstboot.service
rm -f /etc/systemd/system/firstboot.service "$0"

