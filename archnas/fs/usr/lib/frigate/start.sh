#!/usr/bin/env bash
set -exuo pipefail

mkdir -p "$MEDIA_DIR"

tepid "$CONFIG_FILE" > "$RUNTIME_CONFIG"

cat "$RUNTIME_CONFIG"

podman run \
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
    -p 5000:5000 \
    -p 8554:8554 \
    -p 8555:8555 "$FRIGATE_IMAGE:$FRIGATE_VERSION"

