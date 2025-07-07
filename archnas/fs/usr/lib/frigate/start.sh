#!/usr/bin/env bash
set -exuo pipefail

mkdir -p "$MEDIA_DIR"
mkdir -p "$CONFIG_DIR"

tepid "$CONFIG_FILE" > "$RUNTIME_CONFIG"

podman run \
    --cidfile="$CIDFILE" \
    --cgroups=no-conmon \
    --rm \
    --sdnotify=conmon \
    --replace \
    -d \
    --privileged \
    --name frigate \
    --mount type=tmpfs,target=/tmp/cache,tmpfs-size=1000000000 \
    --device /dev/bus/usb:/dev/bus/usb \
    --device /dev/dri/renderD128 \
    --shm-size="$SHM_SIZE" \
    -v "$MEDIA_DIR:/media/frigate" \
    -v "$CONFIG_DIR:/config" \
    -v "$RUNTIME_CONFIG:/config/config.yml" \
    -v /etc/localtime:/etc/localtime:ro \
    -p "$PORT_UI:8971" \
    -p "$PORT_RTSP:8554" \
    -p "$PORT_WEBRTC:8555/tcp" \
    -p "$PORT_WEBRTC:8555/udp" \
    "$FRIGATE_IMAGE:$FRIGATE_VERSION"

