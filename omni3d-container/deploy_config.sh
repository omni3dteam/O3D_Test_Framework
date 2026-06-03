#!/bin/bash
# deploy_config.sh
# Runs before supervisord on container startup.
# Sequence:
#   1. Deploy config (no reboot)
#   2. Deploy firmware to each board — expansion boards first, main board last
#   3. Exit — supervisord starts services

DSF_SD="/opt/dsf/sd"
CONFIG_DIR="/app/config"
FIRMWARE_DIR="/app/firmware"

# ── 1. deploy config ──────────────────────────────────────────────────────────
echo "── Step 1: Deploying config ──"

if [ -d "$CONFIG_DIR/macros" ]; then
    cp -r "$CONFIG_DIR/macros" "$DSF_SD/"
    echo "── macros deployed ──"
fi

if [ -d "$CONFIG_DIR/sys" ]; then
    cp -r "$CONFIG_DIR/sys" "$DSF_SD/"
    echo "── sys deployed ──"
fi

echo "── Config deployed (no reboot) ──"

# ── 2. deploy firmware ────────────────────────────────────────────────────────
echo "── Step 2: Deploying firmware ──"

if [ ! -d "$FIRMWARE_DIR/bin" ] || [ -z "$(ls -A $FIRMWARE_DIR/bin 2>/dev/null)" ]; then
    echo "── No firmware found — skipping firmware update ──"
else
    # copy all firmware files to DSF firmware directory
    mkdir -p "$DSF_SD/firmware"
    cp -r "$FIRMWARE_DIR/bin/"* "$DSF_SD/firmware/" 2>/dev/null || cp -r "$FIRMWARE_DIR/"*.bin "$DSF_SD/firmware/" 2>/dev/null || true
    echo "── Firmware files deployed to $DSF_SD/firmware/ ──"

    # query all connected boards from DSF
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

        # ── flash expansion boards first (canAddress != 0) ────────────────────
        echo "── Flashing expansion boards first ──"
        echo "$BOARDS" | while IFS='|' read -r idx short_name fw_file can_addr; do
            [ "$can_addr" = "0" ] && continue  # skip main board

            FW_PATH="$FIRMWARE_DIR/bin/$fw_file"
            if [ ! -f "$FW_PATH" ]; then
                echo "── Firmware $fw_file not found — skipping $short_name ──"
                continue
            fi

            echo "── Flashing $short_name (CAN: $can_addr) with $fw_file ──"
            curl -s --max-time 10 -X POST http://host-gateway/machine/code \
                -H "Content-Type: text/plain" \
                -d "M997 B${can_addr}" 2>/dev/null || true
            echo "── Flash triggered for $short_name ──"
            sleep 3
        done

        # ── flash main board last (canAddress == 0) ───────────────────────────
        echo "$BOARDS" | while IFS='|' read -r idx short_name fw_file can_addr; do
            [ "$can_addr" != "0" ] && continue  # only main board

            FW_PATH="$FIRMWARE_DIR/bin/$fw_file"
            if [ ! -f "$FW_PATH" ]; then
                echo "── Firmware $fw_file not found — skipping $short_name ──"
                continue
            fi

            echo "── Flashing main board $short_name (CAN: 0) with $fw_file ──"
            curl -s --max-time 10 -X POST http://host-gateway/machine/code \
                -H "Content-Type: text/plain" \
                -d "M997 B0" 2>/dev/null || true
            echo "── Main board flash triggered ──"
        done

        # ── wait for all boards to come back online ───────────────────────────
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

# ── 3. services start via supervisord (CMD continues) ─────────────────────────
echo "── Step 3: Starting services ──"
