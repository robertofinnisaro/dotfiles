#!/usr/bin/env python3
"""Palantír Realm profiles for Hyprland.

Only toggles Hyprland animation/blur at runtime. No sysfs, kernel, power manager,
service, tablet-switch, package, or config-file edits. Returns JSON on stdout.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import fcntl

PROFILES = ('shire', 'rivendell', 'mordor', 'palantir')
KEYS = ('animations:enabled', 'decoration:blur:enabled')
ENV_SIGNATURE = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')
RUNTIME = Path(os.environ.get('XDG_RUNTIME_DIR', str(Path.home() / '.local' / 'state')))
STATE = RUNTIME / 'palantir-realm-state.json'
LOCK = RUNTIME / 'palantir-realm-state.lock'


def call(args):
    try:
        return subprocess.run(args, text=True, capture_output=True, timeout=5, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise RuntimeError(f"Unable to run {args[0]}: {exc}") from exc


def load_state():
    try:
        data = json.loads(STATE.read_text())
    except (OSError, ValueError):
        return None
    if data.get('session') != ENV_SIGNATURE or not ENV_SIGNATURE:
        return None
    if data.get('mode') not in PROFILES:
        return None
    if not isinstance(data.get('baseline'), dict):
        return None
    return data


def get_option(name):
    result = call(['hyprctl', 'getoption', name, '-j'])
    if result.returncode != 0:
        raise RuntimeError(f"hyprctl getoption {name}: {result.stderr.strip()}")
    try:
        data = json.loads(result.stdout)
        val = data.get('int')
        if isinstance(val, bool):
            return int(val)
        if type(val) is int and val in (0, 1):
            return val
    except (ValueError, AttributeError):
        pass
    raise RuntimeError(f"Cannot safely interpret Hyprland option {name}")


def set_option(name, val):
    result = call(['hyprctl', 'keyword', name, str(val)])
    if result.returncode != 0:
        raise RuntimeError(f"hyprctl keyword {name}: {result.stderr.strip() or result.stdout.strip()}")


def write_state(data):
    RUNTIME.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.palantir-realm-', dir=RUNTIME)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(data, stream, indent=2)
            stream.write('\n')
        os.chmod(name, 0o600)
        os.replace(name, STATE)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def status():
    state = load_state()
    return {'mode': state['mode'] if state else 'rivendell',
            'active': bool(state),
            'session': 'running' if ENV_SIGNATURE else 'not-in-hyprland',
            'power': 'unchanged', 'tablet': 'unchanged',
            'status': 'saved for this Hyprland session' if state else 'baseline / no runtime override'}


def apply(mode):
    if not ENV_SIGNATURE:
        raise RuntimeError('HYPRLAND_INSTANCE_SIGNATURE not set; run within your Hyprland session')
    RUNTIME.mkdir(parents=True, exist_ok=True)
    with LOCK.open('a+') as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        old = load_state()
        baseline = old['baseline'] if old else {key: get_option(key) for key in KEYS}
        desired = dict(baseline) if mode in ('rivendell', 'palantir') else {key: 0 for key in KEYS}
        # Stage originals to rollback best-effort on partial failure.
        currently = {key: get_option(key) for key in KEYS}
        modified = []
        try:
            for key in KEYS:
                if currently[key] != desired[key]:
                    set_option(key, desired[key])
                    modified.append(key)
        except RuntimeError:
            for key in reversed(modified):
                try:
                    set_option(key, currently[key])
                except RuntimeError:
                    pass
            raise
        write_state({'session': ENV_SIGNATURE, 'mode': mode, 'baseline': baseline})
    return status()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='operation', required=True)
    sub.add_parser('status')
    act = sub.add_parser('apply')
    act.add_argument('mode', choices=PROFILES)
    args = parser.parse_args()
    try:
        result = status() if args.operation == 'status' else apply(args.mode)
        print(json.dumps(result))
    except RuntimeError as exc:
        print(f'Palantír realms: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
