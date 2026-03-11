#!/bin/bash
# run.sh
# Runs the omni3d-stack container with all required host mounts.

set -e

IMAGE="omni3d-stack"
TAG="${1:-dev}"
CONTAINER="omni3d-stack"

# DSF socket group GID — hardcoded to 992 (dsf group on this system)
DSF_GID=992

# ensure host directories exist before mounting
mkdir -p /opt/dsf/sd/timelaps
mkdir -p /opt/dsf/timelaps
mkdir -p /opt/omni3d/config
mkdir -p /run/omni3d

# stop existing container if running
if docker ps -q -f name="$CONTAINER" | grep -q .; then
    echo "── Stopping existing $CONTAINER ──"
    docker stop "$CONTAINER"
    docker rm "$CONTAINER"
fi

echo "── Starting $IMAGE:$TAG ──"

docker run -d \
    --name "$CONTAINER" \
    --restart unless-stopped \
    -v /var/run/dsf:/var/run/dsf \
    -v /run/omni3d:/run/omni3d \
    -v /opt/dsf/sd/timelaps:/opt/dsf/sd/timelaps \
    -v /opt/dsf/timelaps:/opt/dsf/timelaps \
    -v /opt/omni3d/config:/app/config \
    --add-host host-gateway:host-gateway \
    --group-add $DSF_GID \
    "$IMAGE:$TAG"

echo "── Container started ──"
echo ""
echo "Logs:   docker logs -f $CONTAINER"
echo "Status: docker exec $CONTAINER supervisorctl status"
echo "Stop:   docker stop $CONTAINER"
