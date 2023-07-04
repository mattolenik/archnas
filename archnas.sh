#!/usr/bin/env bash
set -euo pipefail

IMPORT="$(dirname "${BASH_SOURCE[0]}")/src"
source "${IMPORT}/hue.sh" @import
source "${IMPORT}/args.sh"
source "${IMPORT}/common.sh"

main() {
  boxbanner "Welcome to ArchNAS" "$BOLD_$BLUE"
  cat - << EOF
Before installation begins, a few initial steps are required. After you have
booted the Arch installation media, do the following from the initial command
prompt:

1. Enable sshd:
  # systemctl start sshd

2. Set up the temporary install user
  # chpasswd <<< root:archnas

3. Find the machine's IP address:
  # ip address show

Look for your Eth/WiFi device, it likely has a 192.x.x.x or 10.x.x.x IP address,
which is typical for home routers.

At this point you are ready to proceed with the installation steps below.

EOF
  printf %s "$GREEN"
  ask TARGET_IP "(required) Enter the IP of the target machine:" "*" "${TARGET_IP:-}"
  gh_user="$(awk -F ': ' '/github.com:/ {getline; if ($1 ~ /^[[:space:]]+user/) print $2}' ~/.config/gh/hosts.yml 2>/dev/null || true)"
  ask GITHUB_USER "(optional) Allow SSH for a GitHub user:" "*" "$gh_user"
  echo

  ask proceed "Proceed with installation on $TARGET_IP?" "*" "y"
  if [[ ${proceed,,} != y ]]; then
    echo "Aborting"; exit 1
  fi

  scp -r $PWD/src root@$TARGET_IP:~/archnas
  ssh -t root@$TARGET_IP "GITHUB_USERNAME=$gh_user archnas/install.sh | tee install.log"
}

main
