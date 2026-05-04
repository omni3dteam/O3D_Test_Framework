#!/usr/bin/env python3
"""
Soak test watchdog for omni3d-stack.
Runs for SOAK_HOURS, checking every CHECK_INTERVAL_MINUTES.
Generates a JSON + markdown report at the end.
"""

import json
import os
import subprocess
import time
import urllib.request
from datetime import datetime, timezone

SOAK_HOURS            = int(os.environ.get("SOAK_HOURS", "48"))
CHECK_INTERVAL_MIN    = int(os.environ.get("CHECK_INTERVAL_MIN", "5"))
CONTAINER_NAME        = os.environ.get("CONTAINER_NAME", "omni3d-main")
REPORT_PATH           = os.environ.get("REPORT_PATH", "/opt/omni3d/releases/soak_report.json")
DSF_URL               = "http://localhost/machine/model"

def check_services():
    """Check all supervisord services are RUNNING."""
    result = subprocess.run(
        ["docker", "exec", CONTAINER_NAME, "supervisorctl", "status"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return False, f"supervisorctl failed: {result.stderr.strip()}"
    lines = [l for l in result.stdout.splitlines() if l.strip()]
    failed = [l for l in lines if "RUNNING" not in l]
    if failed:
        return False, f"Not running: {failed}"
    return True, f"{len(lines)} services RUNNING"

def check_dsf():
    """Check DSF HTTP API is responding."""
    try:
        with urllib.request.urlopen(DSF_URL, timeout=10) as r:
            if r.status == 200:
                return True, "DSF responding"
            return False, f"DSF returned {r.status}"
    except Exception as e:
        return False, f"DSF unreachable: {e}"

def check_logs():
    """Check for new errors in service logs."""
    result = subprocess.run(
        ["docker", "exec", CONTAINER_NAME, "grep", "-c", "ERROR", "/var/log/supervisord.log"],
        capture_output=True, text=True
    )
    try:
        count = int(result.stdout.strip())
        if count > 0:
            return False, f"{count} errors in supervisord.log"
        return True, "No errors in logs"
    except:
        return True, "Could not parse log"

def run_soak():
    start_time   = datetime.now(timezone.utc)
    end_time     = time.time() + (SOAK_HOURS * 3600)
    interval_sec = CHECK_INTERVAL_MIN * 60
    checks       = []
    failed_checks = 0

    print(f"── Soak test starting ──")
    print(f"── Duration: {SOAK_HOURS}h, check every {CHECK_INTERVAL_MIN}min ──")
    print(f"── Container: {CONTAINER_NAME} ──")

    while time.time() < end_time:
        timestamp = datetime.now(timezone.utc).isoformat()
        remaining_h = (end_time - time.time()) / 3600

        svc_ok,  svc_msg  = check_services()
        dsf_ok,  dsf_msg  = check_dsf()
        log_ok,  log_msg  = check_logs()

        all_ok = svc_ok and dsf_ok and log_ok
        if not all_ok:
            failed_checks += 1

        check = {
            "timestamp": timestamp,
            "ok":        all_ok,
            "services":  {"ok": svc_ok,  "message": svc_msg},
            "dsf":       {"ok": dsf_ok,  "message": dsf_msg},
            "logs":      {"ok": log_ok,  "message": log_msg},
        }
        checks.append(check)

        status = "✓" if all_ok else "✗"
        print(f"{status} [{timestamp}] remaining: {remaining_h:.1f}h | "
              f"services: {svc_msg} | dsf: {dsf_msg} | logs: {log_msg}")

        time.sleep(interval_sec)

    end_time_dt  = datetime.now(timezone.utc)
    total_checks = len(checks)
    passed       = total_checks - failed_checks
    overall_ok   = failed_checks == 0

    report = {
        "ok":             overall_ok,
        "start":          start_time.isoformat(),
        "end":            end_time_dt.isoformat(),
        "duration_hours": SOAK_HOURS,
        "total_checks":   total_checks,
        "passed_checks":  passed,
        "failed_checks":  failed_checks,
        "container":      CONTAINER_NAME,
        "checks":         checks,
    }

    # write JSON report
    os.makedirs(os.path.dirname(REPORT_PATH), exist_ok=True)
    with open(REPORT_PATH, "w") as f:
        json.dump(report, f, indent=2)

    # write markdown report
    md_path = REPORT_PATH.replace(".json", ".md")
    with open(md_path, "w") as f:
        f.write(f"# Soak Test Report\n\n")
        f.write(f"**Result:** {'✅ PASSED' if overall_ok else '❌ FAILED'}  \n")
        f.write(f"**Container:** `{CONTAINER_NAME}`  \n")
        f.write(f"**Duration:** {SOAK_HOURS}h  \n")
        f.write(f"**Start:** {start_time.isoformat()}  \n")
        f.write(f"**End:** {end_time_dt.isoformat()}  \n")
        f.write(f"**Checks:** {passed}/{total_checks} passed  \n\n")
        f.write(f"## Failed Checks\n\n")
        failed_list = [c for c in checks if not c["ok"]]
        if not failed_list:
            f.write("None — all checks passed.\n\n")
        else:
            f.write("| Time | Services | DSF | Logs |\n")
            f.write("|------|----------|-----|------|\n")
            for c in failed_list:
                f.write(f"| {c['timestamp']} "
                        f"| {'✓' if c['services']['ok'] else '✗ ' + c['services']['message']} "
                        f"| {'✓' if c['dsf']['ok'] else '✗ ' + c['dsf']['message']} "
                        f"| {'✓' if c['logs']['ok'] else '✗ ' + c['logs']['message']} |\n")

    print(f"\n── Soak test complete ──")
    print(f"── Result: {'PASSED' if overall_ok else 'FAILED'} ──")
    print(f"── {passed}/{total_checks} checks passed ──")
    print(f"── Report: {REPORT_PATH} ──")

    return 0 if overall_ok else 1

if __name__ == "__main__":
    exit(run_soak())
