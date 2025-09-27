#!/usr/bin/env bash
[[ -n ${TRACE:-} ]] && set -x && export TRACE
set -euo pipefail
trap 'echo ERROR on line $LINENO in file inside-chroot.sh' ERR

STEPS_DIR="${STEPS_DIR:-steps/}"
export USER_HOME="/home/$USER_NAME"
export ARCH="${ARCH:-x86_64}"

echo "Running steps under $STEPS_DIR with environment:"
env

for stepfile in "$STEPS_DIR"/*.sh; do
  IFS=. read -r -a step <<< "${stepfile##*/}"
  echo "Running step #${step[0]} - ${step[1]}"
  #shellcheck disable=SC1090
  . "$stepfile"
done
