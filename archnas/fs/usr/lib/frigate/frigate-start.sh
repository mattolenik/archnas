#!/usr/bin/env bash
set -euo pipefail

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
    -v /media/frigate:/media/frigate \
    -v /etc/frigate.yml:/config/config.yml \
    -v /etc/localtime:/etc/localtime:ro \
    -e FRIGATE_RTSP_PASSWORD="$(systemd-creds decrypt $CRED_FILE)" \
    -p 5000:5000 \
    -p 8554:8554 \
    -p 8555:8555 ghcr.io/blakeblackshear/frigate:stable

