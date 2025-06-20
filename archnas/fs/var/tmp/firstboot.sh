#!/usr/bin/env bash
[[ -n ${TRACE:-} ]] && set -x && export TRACE
set -exuo pipefail

script_name="${0##*/}"
LOG_FILE="/var/log/${LOG_FILE:-${script_name%.*}.log}"
exec > >(tee -i "$LOG_FILE"); exec 2>&1
trap 'echo ERROR on line $LINENO in $script_name' ERR

systemctl --no-block disable firstboot.service
#rm -f /etc/systemd/system/firstboot.service "$0"

# NOTICE: Don't insert firstboot logic here, use the write_firstboot functionality in inside-chroot.sh

