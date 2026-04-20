#!/usr/bin/env python3
"""Send a swap command to the bootloader via Unix socket."""
import socket
import json
import sys
import os

SOCKET_PATH = "/run/omni3d/bootloader.sock"
image = os.environ.get("IMAGE", "")
action = os.environ.get("ACTION", "swap")

if not image and action == "swap":
    print("ERROR: IMAGE environment variable not set")
    sys.exit(1)

if action == "swap":
    cmd = {"action": "swap", "image": image}
elif action == "rollback":
    cmd = {"action": "rollback"}
elif action == "status":
    cmd = {"action": "status"}
else:
    print(f"ERROR: Unknown action: {action}")
    sys.exit(1)

try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SOCKET_PATH)
    s.sendall((json.dumps(cmd) + "\n").encode())
    data = b""
    while True:
        chunk = s.recv(4096)
        if not chunk:
            break
        data += chunk
        if b"\n" in data:
            break
    s.close()
    result = json.loads(data.decode().strip())
    print(json.dumps(result, indent=2))
    if not result.get("ok"):
        sys.exit(1)
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
