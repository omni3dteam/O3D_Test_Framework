#!/bin/bash
# debug.sh
# Builds the omni3d-stack image and drops you into a shell.
# Run from O3D_Test_Framework directory.
# Usage:
#   ./omni3d-container/debug.sh          — build fresh and enter
#   ./omni3d-container/debug.sh --no-build — skip build, enter existing image

set -e

IMAGE="omni3d-stack:debug"
CONTAINER="omni3d-debug"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── parse args ────────────────────────────────────────────────────────────────
NO_BUILD=false
for arg in "$@"; do
    case $arg in
        --no-build) NO_BUILD=true ;;
    esac
done

# ── cleanup any existing debug container ─────────────────────────────────────
docker rm -f "$CONTAINER" 2>/dev/null || true

# ── build ─────────────────────────────────────────────────────────────────────
if [ "$NO_BUILD" = false ]; then
    echo "── Building $IMAGE ──"
    docker build \
        -f "$SCRIPT_DIR/Dockerfile" \
        -t "$IMAGE" \
        "$REPO_DIR"
    echo "── Build complete ──"
else
    echo "── Skipping build, using existing $IMAGE ──"
fi

# ── get DSF socket group ──────────────────────────────────────────────────────
DSF_SOCK="/var/run/dsf/dcs.sock"
if [ -S "$DSF_SOCK" ]; then
    DSF_GID=$(stat -c '%g' "$DSF_SOCK")
    GROUP_ARG="--group-add $DSF_GID"
else
    GROUP_ARG="--group-add 992"
fi

# ── enter container ───────────────────────────────────────────────────────────
echo ""
echo "── Entering $IMAGE ──"
echo "── Useful commands inside: ──"
echo "──   supervisorctl status          — check service status"
echo "──   cat /var/log/template.err     — check service errors"
echo "──   /app/template/template        — run binary directly"
echo "──   supervisord -n -c /etc/supervisor/conf.d/omni3d.conf — start all services"
echo ""

docker run -it --rm \
    --name "$CONTAINER" \
    -v /var/run/dsf:/var/run/dsf \
    -v /run/omni3d:/run/omni3d \
    -v /opt/dsf/sd/timelaps:/opt/dsf/sd/timelaps \
    -v /opt/dsf/timelaps:/opt/dsf/timelaps \
    -v /opt/omni3d/config:/app/config \
    --add-host host-gateway:host-gateway \
    $GROUP_ARG \
    "$IMAGE" \
    /bin/bash
