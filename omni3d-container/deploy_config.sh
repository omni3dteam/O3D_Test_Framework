#!/bin/bash
# deploy_config.sh
# Runs before supervisord on container startup.
# Deploys config and firmware ONLY on first start (when flag file doesn't exist).
# Subsequent starts skip deployment.

FLAG_FILE="/opt/omni3d/.deployed"
DSF_SD="/opt/dsf/sd"
CONFIG_MACROS="/app/config/macros"
CONFIG_SYS="/app/config/sys"
FIRMWARE_DIR="/app/firmware/bin"

# ── check if already deployed ─────────────────────────────────────────────────
if [ -f "$FLAG_FILE" ]; then
    echo "── Already deployed — skipping config and firmware deployment ──"
    echo "── Starting services ──"
    exit 0
fi

echo "── First start — deploying config and firmware ──"

# ── 1. deploy config ──────────────────────────────────────────────────────────
echo "── Step 1: Deploying config ──"

DEPLOYED=0
if [ -d "$CONFIG_MACROS" ] && [ "$(ls -A $CONFIG_MACROS 2>/dev/null)" ]; then
    rm -rf "$DSF_SD/macros"
    cp -r "$CONFIG_MACROS" "$DSF_SD/"
    echo "── macros deployed ──"
    DEPLOYED=1
fi

if [ -d "$CONFIG_SYS" ] && [ "$(ls -A $CONFIG_SYS 2>/dev/null)" ]; then
    rm -rf "$DSF_SD/sys"
    cp -r "$CONFIG_SYS" "$DSF_SD/"
    echo "── sys deployed ──"
    DEPLOYED=1
fi

if [ "$DEPLOYED" = "0" ]; then
    echo "── No config found — skipping ──"
else
    echo "── Config deployed ──"
fi

# ── 2. deploy firmware ────────────────────────────────────────────────────────
echo "── Step 2: Deploying firmware ──"

if [ ! -d "$FIRMWARE_DIR" ] || [ -z "$(ls -A $FIRMWARE_DIR 2>/dev/null)" ]; then
    echo "── No firmware found — skipping firmware update ──"
else
    mkdir -p "$DSF_SD/firmware"
    cp -r "$FIRMWARE_DIR/"* "$DSF_SD/firmware/"
    echo "── Firmware files deployed ──"

    echo "── Querying connected boards ──"
    BOARDS=$(curl -s --max-time 10 http://host-gateway/machine/model \
        | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    boards = data.get('boards', [])
    for i, board in enumerate(boards):
        short_name = board.get('shortName', '')
        fw_file = board.get('firmwareFileName', '')
        can_addr = board.get('canAddress', 0)
        if short_name and fw_file:
            print(f'{i}|{short_name}|{fw_file}|{can_addr}')
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
" 2>/dev/null)

    if [ -z "$BOARDS" ]; then
        echo "── Could not query boards — skipping firmware flash ──"
    else
        echo "── Found boards: ──"
        echo "$BOARDS"

        # flash expansion boards first
        echo "$BOARDS" | while IFS='|' read -r idx short_name fw_file can_addr; do
            [ "$can_addr" = "0" ] && continue
            FW_PATH="$FIRMWARE_DIR/$fw_file"
            [ ! -f "$FW_PATH" ] && echo "── $fw_file not found — skipping $short_name ──" && continue
            echo "── Flashing $short_name (CAN: $can_addr) ──"
            curl -s --max-time 10 -X POST http://host-gateway/machine/code \
                -H "Content-Type: text/plain" \
                -d "M997 B${can_addr}" 2>/dev/null || true
            sleep 3
        done

        # flash main board last
        echo "$BOARDS" | while IFS='|' read -r idx short_name fw_file can_addr; do
            [ "$can_addr" != "0" ] && continue
            FW_PATH="$FIRMWARE_DIR/$fw_file"
            [ ! -f "$FW_PATH" ] && echo "── $fw_file not found — skipping $short_name ──" && continue
            echo "── Flashing main board $short_name (CAN: 0) ──"
            curl -s --max-time 10 -X POST http://host-gateway/machine/code \
                -H "Content-Type: text/plain" \
                -d "M997 B0" 2>/dev/null || true
        done

        # wait for boards back online
        echo "── Waiting for boards to come back online ──"
        for i in $(seq 1 30); do
            sleep 3
            STATUS=$(curl -s --max-time 5 http://host-gateway/machine/model \
                | python3 -c "import sys,json; print(json.load(sys.stdin).get('state',{}).get('status','unknown'))" \
                2>/dev/null || echo "unknown")
            if [ "$STATUS" != "unknown" ] && [ "$STATUS" != "updating" ]; then
                echo "── All boards online (status: $STATUS) ──"
                break
            fi
            echo "── Waiting... ($i/30) status: $STATUS ──"
        done
    fi
fi

# ── write flag file to prevent re-deployment on next start ───────────────────
mkdir -p /opt/omni3d
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$FLAG_FILE"
echo "── Deployment complete — flag written to $FLAG_FILE ──"

# ── 3. start services ─────────────────────────────────────────────────────────
echo "── Step 3: Starting services ──"
