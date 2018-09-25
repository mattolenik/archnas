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
  boxbanner "Welcome to ArchNAS" "$BOLD_$BLUE"
  cat - << EOF
Before installation begins, a few initial steps are required. After you have
booted the Arch installation media, do the following from the initial command
prompt:

1. Enable sshd:
  # systemctl start sshd

2. Set a password (anything) for the root user:
  # chpasswd <<< root:archnas

3. Find the machine's IP address:
  # ip address show

Look for your Eth/WiFi device, it likely has a 192.x.x.x or 10.x.x.x IP address,
which is typical for home routers.

At this point you are ready to proceed with the installation steps below.

EOF
  printf %s "$GREEN"
  ask TARGET_IP "(required) Enter the IP of the target machine:" "*"
  echo
  ask SSH_KEY $'(optional) By default, ArchNAS will automatically create an SSH key for secure access (recommended).\n           You can also enter the path for your own:' "*" "${SSH_KEY:-skip}"
  printf %s "$CLR"

  [[ $SSH_KEY == skip ]] && SSH_KEY="$(gen_ssh_key "$USER" "$HOST_NAME")"
  [[ ! -f $SSH_KEY ]] && fail "The SSH key file '$SSH_KEY' does not exist"
}

main
