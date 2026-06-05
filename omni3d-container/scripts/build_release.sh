#!/usr/bin/env bash
# build_release.sh
# Builds the release Docker image extending the latest ci-test image
# with baked-in config, firmware and deploy CMD.
set -e

CONFIG_DIR="$1"
RELEASE_TAG="$2"

if [ -z "$CONFIG_DIR" ] || [ -z "$RELEASE_TAG" ]; then
    echo "Usage: $0 <CONFIG_DIR> <RELEASE_TAG>"
    echo "Example: $0 OMNIPRO_Config omni3d-stack:dev-release-20260605-094304"
    exit 1
fi

# get the latest ci-test image
CI_TEST_TAG=$(docker images "omni3d-stack" --format "{{.Tag}}" | grep "ci-test" | sort -r | head -1)
if [ -z "$CI_TEST_TAG" ]; then
    echo "ERROR: No ci-test image found"
    exit 1
fi

echo "── Extending omni3d-stack:$CI_TEST_TAG ──"
echo "── Config: $CONFIG_DIR ──"
echo "── Release tag: $RELEASE_TAG ──"

# write release Dockerfile
cat > /tmp/Dockerfile.release << DOCKERFILE
FROM omni3d-stack:${CI_TEST_TAG}
COPY ${CONFIG_DIR}/src/macros/ /app/config/macros/
COPY ${CONFIG_DIR}/src/sys/    /app/config/sys/
COPY RRF_Environment/bin/      /app/firmware/bin/
CMD ["/bin/bash", "-c", "/app/deploy_config.sh && /usr/bin/supervisord -n -c /etc/supervisor/conf.d/omni3d.conf"]
DOCKERFILE

docker build -f /tmp/Dockerfile.release -t "$RELEASE_TAG" .
rm /tmp/Dockerfile.release

echo "── Release image built: $RELEASE_TAG ──"
