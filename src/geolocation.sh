# shellcheck shell=bash

get_external_ip() {
  local output
  if ! output=$(dig +short myip.opendns.com @resolver1.opendns.com); then
    echo NULL
  fi
  echo "$output"
}

# Retrieve location info the Free Geo API.
# $1 - IP address
# $2 - (optional) Name of a specific JSON key to return, otherwise whole JSON
#      blob will be returned
get_geoip_info() {
  # Try to resolve timezone by geolocation of IP, default to UTC in case of failure
  curl --max-time 30 --fail --silent "https://freegeoip.app/json/$1" 2>/dev/null | jq -r ".${2:-}"
}
