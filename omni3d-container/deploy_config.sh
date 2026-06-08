#!/bin/bash
# deploy_config.sh
# Runs before supervisord on container startup.
# Sequence:
#   1. Deploy config (always - fast, no reboot needed)
#   2. Deploy firmware only if version differs from what's on the board
#   3. Exit — supervisord starts services

DSF_SD="/opt/dsf/sd"
CONFIG_MACROS="/app/config/macros"
CONFIG_SYS="/app/config/sys"
FIRMWARE_DIR="/app/firmware/bin"

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

# ── 2. deploy firmware only if version differs ────────────────────────────────
echo "── Step 2: Checking firmware versions ──"

if [ ! -d "$FIRMWARE_DIR" ] || [ -z "$(ls -A $FIRMWARE_DIR 2>/dev/null)" ]; then
    echo "── No firmware found — skipping firmware update ──"
else
    mkdir -p "$DSF_SD/firmware"
    cp -r "$FIRMWARE_DIR/"* "$DSF_SD/firmware/"

    # query boards and their current firmware versions
    BOARDS=$(curl -s --max-time 10 http://host-gateway/machine/model \
        | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    boards = data.get('boards', [])
    for i, board in enumerate(boards):
        short_name = board.get('shortName', '')
        fw_file = board.get('firmwareFileName', '')
        fw_version = board.get('firmwareVersion', '')
        can_addr = board.get('canAddress', 0)
        if short_name and fw_file:
            print(f'{i}|{short_name}|{fw_file}|{fw_version}|{can_addr}')
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
" 2>/dev/null)

    if [ -z "$BOARDS" ]; then
        echo "── Could not query boards — skipping firmware flash ──"
    else
        NEEDS_FLASH=0

        # check each board
        echo "$BOARDS" | while IFS='|' read -r idx short_name fw_file fw_version can_addr; do
            FW_PATH="$FIRMWARE_DIR/$fw_file"
            if [ ! -f "$FW_PATH" ]; then
                echo "── $fw_file not found — skipping $short_name ──"
                continue
            fi

            # get version from versions.json
            VERSIONS_FILE="$FIRMWARE_DIR/versions.json"
            if [ -f "$VERSIONS_FILE" ]; then
                CONTAINER_VERSION=$(python3 -c "
import json, sys
data = json.load(open('$VERSIONS_FILE'))
print(data.get('$fw_file', ''))
" 2>/dev/null)
            else
                # no versions.json — always flash
                echo "── $short_name: no versions.json — will flash ──"
                echo "flash" > /tmp/flash_${can_addr}
                continue
            fi

            echo "── $short_name: board=$fw_version container=$CONTAINER_VERSION ──"
            if [ "$fw_version" != "$CONTAINER_VERSION" ]; then
                echo "── $short_name: version mismatch — will flash ──"
                echo "flash" > /tmp/flash_${can_addr}
            else
                echo "── $short_name: up to date — skipping ──"
            fi
        done

        # flash expansion boards first
        echo "$BOARDS" | while IFS='|' read -r idx short_name fw_file fw_version can_addr; do
            [ "$can_addr" = "0" ] && continue
            [ ! -f "/tmp/flash_${can_addr}" ] && continue
            echo "── Flashing $short_name (CAN: $can_addr) ──"
            curl -s --max-time 10 -X POST http://host-gateway/machine/code \
                -H "Content-Type: text/plain" \
                -d "M997 B${can_addr}" 2>/dev/null || true
            rm -f "/tmp/flash_${can_addr}"
            sleep 3
        done

        # flash main board last
        echo "$BOARDS" | while IFS='|' read -r idx short_name fw_file fw_version can_addr; do
            [ "$can_addr" != "0" ] && continue
            [ ! -f "/tmp/flash_0" ] && continue
            echo "── Flashing main board $short_name (CAN: 0) ──"
            curl -s --max-time 10 -X POST http://host-gateway/machine/code \
                -H "Content-Type: text/plain" \
                -d "M997 B0" 2>/dev/null || true
            rm -f "/tmp/flash_0"
        done

        # wait for boards back online only if something was flashed
        if ls /tmp/flash_* 2>/dev/null | grep -q .; then
            echo "── No boards needed flashing ──"
        else
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
fi

# ── 3. start services ─────────────────────────────────────────────────────────
echo "── Step 3: Starting services ──"
