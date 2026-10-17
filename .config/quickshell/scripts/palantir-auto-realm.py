#!/usr/bin/env python3
"""Optional per-session visual Realm automation: AC -> Rivendell, battery -> Shire.

OFF by default. Never changes power profiles, wallpapers, input or config files.
Stops automatic mode if a user manually changes the Realm in the same session.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

STATE_HOME = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
STATE_PATH = Path(os.environ.get("PALANTIR_AUTO_STATE", str(STATE_HOME / "palantir/auto-realm.json")))
POWER_ROOT = Path(os.environ.get("PALANTIR_POWER_ROOT", "/sys/class/power_supply"))
REALMS = Path(__file__).with_name("palantir-realms.py")
SESSION = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")


def read_state():
    try:
        data = json.loads(STATE_PATH.read_text())
        if isinstance(data, dict):
            return data
    except (OSError, ValueError):
        pass
    return {"enabled": False}


def save_state(state):
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix="auto-realm-", dir=STATE_PATH.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(state, stream)
            stream.write("\n")
        os.chmod(name, 0o600)
        os.replace(name, STATE_PATH)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def power_state():
    """Only real online mains supplies; don't guess when hardware is ambiguous."""
    try:
        for supply in POWER_ROOT.iterdir():
            try:
                if (supply / "type").read_text().strip().lower() in ("mains", "usb_c", "usb-pd"):
                    state = (supply / "online").read_text().strip()
                    if state in ("0", "1"):
                        return "ac" if state == "1" else "battery"
            except OSError:
                continue
    except OSError:
        pass
    return "unknown"


def realm_command(command, mode=None):
    args = [sys.executable, str(REALMS), command]
    if mode:
        args.append(mode)
    try:
        run = subprocess.run(args, text=True, capture_output=True, timeout=45, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise RuntimeError(str(exc)) from exc
    if run.returncode != 0:
        raise RuntimeError(run.stderr.strip() or "Realm command failed")
    try:
        return json.loads(run.stdout)
    except ValueError as exc:
        raise RuntimeError("Invalid Realm response") from exc


def command(verb):
    state = read_state()
    power = power_state()
    if verb == "disable":
        state = {"enabled": False}
        save_state(state)
    elif verb == "enable":
        if not SESSION:
            raise RuntimeError("Enable auto Realms from inside Hyprland")
        state = {"enabled": True, "session": SESSION, "last_mode": None}
        save_state(state)
    if verb == "tick" and state.get("enabled"):
        if not SESSION:
            return {"enabled": True, "power": power, "message": "Hyprland session unavailable; nothing changed"}
        if state.get("session") != SESSION:
            state["session"] = SESSION
            state["last_mode"] = None
        target = {"ac": "rivendell", "battery": "shire"}.get(power)
        if not target:
            return {"enabled": True, "power": power, "message": "AC status unknown; no Realm changes"}
        current = realm_command("status").get("mode")
        last = state.get("last_mode")
        if last is not None and current != last:
            save_state({"enabled": False})
            return {"enabled": False, "power": power, "message": "Manual Realm choice detected; automation disabled"}
        if current != target:
            realm_command("apply", target)
        state["last_mode"] = target
        save_state(state)
        return {"enabled": True, "power": power, "realm": target, "message": "Auto Realm: " + target + " (" + power + ")"}
    enabled = bool(state.get("enabled"))
    return {"enabled": enabled, "power": power, "message": "Auto Realms on" if enabled else "Auto Realms off"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("status", "enable", "disable", "tick"))
    args = parser.parse_args()
    try:
        print(json.dumps(command(args.command)))
    except RuntimeError as exc:
        print(f"Auto Realms: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
