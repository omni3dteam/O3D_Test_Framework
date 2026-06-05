#!/usr/bin/env bash
# build_release.sh
# Builds the release Docker image extending the latest dev-release image
# with baked-in config, firmware and deploy CMD.
set -e

CONFIG_DIR="$1"
RELEASE_IMAGE="$2"

if [ -z "$CONFIG_DIR" ] || [ -z "$RELEASE_IMAGE" ]; then
    echo "Usage: $0 <CONFIG_DIR> <RELEASE_IMAGE>"
    exit 1
fi

# get the latest dev-release tag
DEV_RELEASE_TAG=$(docker images "omni3d-stack" --format "{{.Tag}}" | grep "dev-release" | sort -r | head -1)
if [ -z "$DEV_RELEASE_TAG" ]; then
    echo "ERROR: No dev-release image found"
    exit 1
fi

echo "── Extending omni3d-stack:$DEV_RELEASE_TAG for release ──"
echo "── Config: $CONFIG_DIR ──"

# write release Dockerfile
cat > /tmp/Dockerfile.release << EOF
FROM omni3d-stack:${DEV_RELEASE_TAG}
COPY ${CONFIG_DIR}/src/macros/ /app/config/macros/
COPY ${CONFIG_DIR}/src/sys/    /app/config/sys/
COPY RRF_Environment/bin/      /app/firmware/bin/
CMD ["/bin/bash", "-c", "/app/deploy_config.sh && /usr/bin/supervisord -n -c /etc/supervisor/conf.d/omni3d.conf"]
EOF

docker build -f /tmp/Dockerfile.release -t "$RELEASE_IMAGE" .
rm /tmp/Dockerfile.release

echo "── Release image built: $RELEASE_IMAGE ──"
