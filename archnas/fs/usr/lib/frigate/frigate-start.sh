#!/usr/bin/env bash
set -euo pipefail

RUNTIME_CONFIG="${RUNTIME_CONFIG}"
MEDIA_DIR="${MEDIA_DIR}"
CONFIG_FILE="${CONFIG_FILE:-/etc/frigate.yml}"

mkdir -p "$MEDIA_DIR"

password="$(systemd-creds decrypt "$CRED_FILE")"
if [[ -z "$password" ]]; then
  echo "Could not find Frigate RTSP password, make sure you have run:"
  echo "    echo 'mypassword' | systemd-creds encrypt - $CRED_FILE"
  exit 1
fi

sd __RTSP_PASSWORD__ "$password" < "$CONFIG_FILE" > "$RUNTIME_CONFIG"

/usr/bin/podman run \
    --cidfile="$CIDFILE" \
    --cgroups=no-conmon \
    --rm \
    --sdnotify=conmon \
    --replace \
    -d \
    --name frigate \
    --mount type=tmpfs,target=/tmp/cache,tmpfs-size=1000000000 \
    --device /dev/bus/usb:/dev/bus/usb \
    --device /dev/dri/renderD128 \
    --shm-size=128mb \
    -v "$MEDIA_DIR:/media/frigate" \
    -v "$RUNTIME_CONFIG:/config/config.yml" \
    -v /etc/localtime:/etc/localtime:ro \
    -e FRIGATE_RTSP_PASSWORD="$password" \
    -p 5000:5000 \
    -p 8554:8554 \
    -p 8555:8555 ghcr.io/blakeblackshear/frigate:stable

