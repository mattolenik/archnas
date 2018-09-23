#!/usr/bin/env bash
set -euo pipefail

IMPORT="$(dirname "${BASH_SOURCE[0]}")/src"
source "${IMPORT}/hue.sh" @import
source "${IMPORT}/args.sh"
source "${IMPORT}/common.sh"

# Generates a new, password-less SSH key
# $1 - Comment string (e.g. user/email)
# $2 - A short identifier that will be placed in the key filename: ~/.ssh/id_$2_rsa
gen_ssh_key() {
  local keyfile="$HOME/.ssh/id_$2_rsa"
  ssh-keygen -t rsa -b 4096 -C "$1" -f "$keyfile" -N ''
  echo "$keyfile"
}

main() {
  ask SSH_KEY $'(Optional) By default, ArchNAS will create an SSH key for you (recommended).\n           You can also enter the path for your own:' "*" "${SSH_KEY:-skip}"
  [[ $SSH_KEY == skip ]] && SSH_KEY="$(gen_ssh_key "$USER" "$HOST_NAME")"
}

main
