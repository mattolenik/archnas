#!/usr/bin/env bash
[[ -n ${TRACE:-} ]] && set -x && export TRACE
set -euo pipefail

script_name="${0##*/}"
LOG_FILE="/var/log/${LOG_FILE:-${script_name%.*}.log}"
exec > >(tee -i "$LOG_FILE"); exec 2>&1
trap 'echo ERROR on line $LINENO in $script_name' ERR

cleanup() {
  systemctl --no-block disable firstboot.service
  if (( $? == 0 )); then
    rm -f /etc/systemd/system/firstboot.service "$0"
  fi
}

trap cleanup EXIT

