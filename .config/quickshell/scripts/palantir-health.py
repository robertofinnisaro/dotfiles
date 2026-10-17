#!/usr/bin/env python3
"""Palantír Stage 3.3 read-only user/system service health.

No sudo, no service changes, no collection of private user information.
"""
import argparse
import json
import shutil
import subprocess

SERVICES = [
    ("Quickshell supervisor", "user", "palantir-quickshell.service"),
    ("PipeWire audio", "user", "pipewire.service"),
    ("WirePlumber", "user", "wireplumber.service"),
    ("Clipboard text watcher", "user", "palantir-clipboard-text.service"),
    ("Clipboard image watcher", "user", "palantir-clipboard-image.service"),
    ("Desktop portal", "user", "xdg-desktop-portal.service"),
    ("NetworkManager", "system", "NetworkManager.service"),
    ("Bluetooth daemon", "system", "bluetooth.service"),
    ("Sensor proxy", "system", "iio-sensor-proxy.service"),
]


def service_status(scope, unit):
    if not shutil.which("systemctl"):
        return "unavailable"
    cmd = ["systemctl"]
    if scope == "user":
        cmd.append("--user")
    cmd += ["is-active", unit]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=3, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return "unavailable"
    word = p.stdout.strip().splitlines()
    if word:
        status = word[-1].lower()
        if status in {"active", "inactive", "failed", "activating", "deactivating", "unknown"}:
            return status
    return "unavailable"


def report():
    items = []
    for title, scope, unit in SERVICES:
        items.append({"title": title, "scope": scope, "unit": unit, "status": service_status(scope, unit)})
    active = sum(x["status"] == "active" for x in items)
    return {"services": items, "note": f"{active} of {len(items)} tracked systemd units active; inactive can be expected when not installed or enabled."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="JSON for the Quickshell UI")
    args = parser.parse_args()
    result = report()
    if args.json:
        print(json.dumps(result))
    else:
        print(result["note"])
        for item in result["services"]:
            print(f"{item['title']:<27} {item['status']:<13} ({item['scope']}: {item['unit']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
