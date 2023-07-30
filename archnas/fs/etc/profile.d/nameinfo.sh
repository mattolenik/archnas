# Variables with useful network name information
export HOSTNAME="$(cat /etc/hostname)"
export DOMAIN="$(cat /etc/domain)"
export FQDN="$HOSTNAME.$DOMAIN"

