#!/bin/bash
# deploy_config.sh
# Copies baked-in config files to the host DSF directory on container startup.
# Runs before supervisord starts.

DSF_SD="/opt/dsf/sd"
CONFIG_DIR="/app/config"

echo "── Deploying config to host ──"

if [ ! -d "$CONFIG_DIR/macros" ] && [ ! -d "$CONFIG_DIR/sys" ]; then
    echo "── No config found in $CONFIG_DIR — skipping ──"
    exit 0
fi

if [ -d "$CONFIG_DIR/macros" ]; then
    cp -r "$CONFIG_DIR/macros" "$DSF_SD/"
    echo "── macros deployed ──"
fi

if [ -d "$CONFIG_DIR/sys" ]; then
    cp -r "$CONFIG_DIR/sys" "$DSF_SD/"
    echo "── sys deployed ──"
fi

echo "── Config deployment complete ──"

# ── signal Duet board to reboot ───────────────────────────────────────────────
echo "── Signalling Duet board to reboot ──"
curl -s --max-time 10 -X POST http://localhost/machine/code \
    -H "Content-Type: text/plain" \
    -d "M999" 2>/dev/null || true
echo "── Board reboot signal sent ──"
