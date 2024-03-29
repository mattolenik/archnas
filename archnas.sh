#!/usr/bin/env bash
set -euo pipefail

ARCHNAS_REPO="${ARCHNAS_REPO:-mattolenik/archnas}"

IMPORT="$(dirname "${BASH_SOURCE[0]}")/archnas"
source "${IMPORT}/hue.sh" @import
source "${IMPORT}/args.sh"
source "${IMPORT}/common.sh"

main() {
  local dist_url
  dist_url="$(github_get_latest_release "$ARCHNAS_REPO" | grep archnas.tar.gz)"
  if [[ -z $dist_url ]]; then
    fail "Could not get latest release of ArchNAS from https://github.com/$ARCHNAS_REPO"
  fi
  local version
  version="$(basename "$(dirname "$dist_url")")"

  boxbanner "Welcome to ArchNAS $version" "$BOLD_$BLUE"
  cat - << EOF
Before installation begins, a few initial steps are required. After you have
booted the Arch installation media, do the following from the initial command
prompt:

1. Set up the temporary install user:
   chpasswd <<< root:archnas

2. Find and note the machine's IP address:
   ip address show

Look for your Ethernet or WiFi device, it likely has a 192.x.x.x or 10.x.x.x IP address,
which is typical for home routers.

At this point you are ready to proceed with the installation steps below.

EOF
  printf %s "$GREEN"
  ask TARGET_IP "(required) Enter the IP of the target machine:" "*" "${TARGET_IP:-}"
  gh_user="$(awk -F ': ' '/github.com:/ {getline; if ($1 ~ /^[[:space:]]+user/) print $2}' ~/.config/gh/hosts.yml 2>/dev/null || true)"
  ask export GITHUB_USER "(optional) Allow SSH for a GitHub user:" "*" "$gh_user"
  echo

  ask proceed "Proceed with installation on $TARGET_IP?" "*" "y"
  if [[ ${proceed,,} != y ]]; then
    fail "Aborting"
  fi
  clr

  ssh -t root@$TARGET_IP "export HOST_NAME=${HOST_NAME:-} USER_NAME=${USER_NAME:-} DOMAIN=${DOMAIN:-} GITHUB_USERNAME=${GITHUB_USERNAME:-} && curl -sSL $dist_url | tar -xz && archnas/install.sh"
}

main
