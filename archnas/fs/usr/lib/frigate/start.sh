#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$MEDIA_DIR"

password="$(systemd-creds decrypt /creds/frigate/rtsp/cam-fd)"
if [[ -z "$password" ]]; then
  echo "Could not find Frigate RTSP password, make sure you have run:"
  echo "    echo 'mypassword' | systemd-creds encrypt - $CRED_FILE"
  exit 1
fi

tepid "$CONFIG_FILE" > "$RUNTIME_CONFIG"

# TODO: verify $password is actually needed here as opposed to just put into config.yml
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
    -p 8555:8555 "$FRIGATE_IMAGE:$FRIGATE_VERSION"

