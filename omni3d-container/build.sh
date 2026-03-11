#!/bin/bash
# build.sh
# Run from inside omni3d-container/
# Expects sibling directories:
#   OMNI3D_Update/
#   OMNI3D_RFID_Middleware/
#   OMNI3D_Work_Time_Counter/
#   OMNI3D_Timelapse/

set -e

IMAGE="omni3d-stack"
TAG="${1:-dev}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "── Building $IMAGE:$TAG ──"

docker build \
    -f "$SCRIPT_DIR/Dockerfile" \
    -t "$IMAGE:$TAG" \
    "$SCRIPT_DIR/.."

echo ""
echo "── Build complete: $IMAGE:$TAG ──"
echo "Run with: ./run.sh"
