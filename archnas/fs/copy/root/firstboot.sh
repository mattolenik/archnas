#!/usr/bin/env bash
[[ -n ${TRACE:-} ]] && set -x && export TRACE
set -euo pipefail

cleanup() {
 systemctl --no-block disable firstboot.service
 rm /etc/systemd/system/firstboot.service "$0"
}

trap cleanup EXIT

