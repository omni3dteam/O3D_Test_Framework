#!/usr/bin/env python3
"""Generate versions.json for a release."""

import json
import os
import subprocess
import urllib.request
from datetime import datetime, timezone

RELEASE_DIR  = os.environ.get("RELEASE_DIR", "/opt/omni3d/releases")
NEW_VERSION  = os.environ.get("NEW_VERSION", "unknown")
DSF_VERSION  = os.environ.get("DSF_VERSION", "unknown")
OMNODE_SHA   = os.environ.get("OMNODE_SHA", "unknown")
SERVICES     = json.loads(os.environ.get("SERVICES", "{}"))
CONFIGS      = json.loads(os.environ.get("CONFIGS", "{}"))
TRIGGERED_BY = os.environ.get("TRIGGERED_BY", "unknown")
HOSTNAME     = os.environ.get("HOSTNAME", "unknown")

# ── query boards from DSF ─────────────────────────────────────────────────────
boards = []
try:
    urllib.request.urlopen("http://localhost/rr_connect?password=", timeout=5)
    with urllib.request.urlopen("http://localhost/rr_model?key=boards", timeout=5) as r:
        result = json.loads(r.read())["result"]
        for board in result:
            boards.append({
                "name":             board.get("name", "unknown"),
                "shortName":        board.get("shortName", "unknown"),
                "firmwareVersion":  board.get("firmwareVersion", "unknown"),
                "firmwareName":     board.get("firmwareName", "unknown"),
                "firmwareDate":     board.get("firmwareDate", "unknown"),
                "firmwareFileName": board.get("firmwareFileName", "unknown"),
                "uniqueId":         board.get("uniqueId", "unknown"),
                "canAddress":       board.get("canAddress", 0),
            })
except Exception as e:
    boards = [{"error": str(e)}]

# ── assemble versions.json ────────────────────────────────────────────────────
data = {
    "released":     datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "container":    NEW_VERSION,
    "dsf":          DSF_VERSION,
    "omnode":       OMNODE_SHA,
    "services":     SERVICES,
    "config":       CONFIGS,
    "boards":       boards,
    "tested_on":    HOSTNAME,
    "triggered_by": TRIGGERED_BY,
}

os.makedirs(RELEASE_DIR, exist_ok=True)
out_path = os.path.join(RELEASE_DIR, "versions.json")
with open(out_path, "w") as f:
    json.dump(data, f, indent=2)

print(json.dumps(data, indent=2))
print(f"\n── versions.json written to {out_path} ──")
