#!/usr/bin/env python3
"""Framework 12 orientation / tablet-mode bridge for a Hyprland user session.

No root needed. Never disables keyboard, mouse or touchscreen hardware.
Uses the same preferred,auto,1 monitor mode as the user's prior auto-rotate.sh.
"""
import argparse
import json
import os
from pathlib import Path
import queue
import re
import shutil
import subprocess
import sys
import threading
import time

RUNTIME = Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}'))
STATE = RUNTIME / 'palantir-framework12.json'
COMMAND = RUNTIME / 'palantir-framework12-command.json'
ORIENTATIONS = {'normal': 0, 'left-up': 1, 'bottom-up': 2, 'right-up': 3}


def save(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + f'.{os.getpid()}.tmp')
    temp.write_text(json.dumps(obj))
    os.replace(temp, path)


def read(path, fallback=None):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {} if fallback is None else fallback


def run(args, *, quiet=True):
    try:
        result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=3)
        if result.returncode != 0 and not quiet:
            print('Framework controller:', ' '.join(args), result.stderr.strip(), file=sys.stderr)
        return result.returncode == 0
    except (OSError, subprocess.TimeoutExpired) as error:
        if not quiet:
            print('Framework controller:', error, file=sys.stderr)
        return False


def internal_monitor():
    """Prefer built-in eDP and do not rotate a connected external display."""
    try:
        data = subprocess.check_output(['hyprctl', 'monitors', '-j'], text=True, timeout=3)
        monitors = json.loads(data)
        for m in monitors:
            if m.get('name', '').startswith('eDP-'):
                return m['name']
    except (OSError, ValueError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
        pass
    return None


def emit(effects, monitor, degree, *, dry_run=False):
    result = []
    if not monitor:
        return ['No internal eDP monitor detected; nothing changed']
    result.append(['hyprctl', 'keyword', 'monitor', f'{monitor},preferred,auto,1,transform,{degree}'])
    # Hyprland's input subcategories accept the same 0/1/2/3 rotations.
    result.append(['hyprctl', 'keyword', 'input:touchdevice:transform', str(degree)])
    result.append(['hyprctl', 'keyword', 'input:tablet:transform', str(degree)])
    for cmd in result:
        if dry_run:
            print(' '.join(cmd))
        else:
            run(cmd, quiet=False)
    return result


def stream_events(args, label, inbox):
    if not shutil.which(args[0]):
        inbox.put(('missing', label))
        return
    while True:
        try:
            with subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                  text=True, bufsize=1) as proc:
                for line in proc.stdout:
                    inbox.put((label, line.strip()))
                if proc.wait() != 0:
                    inbox.put(('failed', label))
        except OSError:
            inbox.put(('failed', label))
        time.sleep(10)


def daemon():
    inbox = queue.Queue()
    # libinput is best-effort: some systems require a privileged seat grant.
    # Never assume unknown switch state means tablet mode.
    for command, name in [(['monitor-sensor', '--accel'], 'sensor'),
                          (['libinput', 'debug-events', '--udev'], 'libinput')]:
        threading.Thread(target=stream_events, args=(command, name, inbox), daemon=True).start()
    orientation = 'normal'
    folded = False
    seen_tablet_switch = False
    effective_transform = None
    current_command = None
    last_monitor = None
    last_status = None
    while True:
        try:
            source, message = inbox.get(timeout=1)
            if source == 'sensor':
                match = re.search(r'orientation(?: changed)?:\s*(normal|left-up|right-up|bottom-up)', message)
                if match:
                    orientation = match.group(1)
            elif source == 'libinput' and 'tablet-mode' in message and 'SWITCH_TOGGLE' in message:
                match = re.search(r'tablet-mode\s+state\s+([01])', message)
                if match:
                    folded = match.group(1) == '1'
                    seen_tablet_switch = True
        except queue.Empty:
            pass
        request = read(COMMAND, {'mode': 'auto'})
        # mode is user-owned and persisted only for the current session.
        mode = request.get('mode', 'auto')
        if mode not in ('auto', 'tablet', 'laptop'):
            mode = 'auto'
        tablet = mode == 'tablet' or (mode == 'auto' and seen_tablet_switch and folded)
        preferred_orientation = request.get('orientation', orientation)
        if preferred_orientation not in ORIENTATIONS:
            preferred_orientation = orientation
        transform = ORIENTATIONS[preferred_orientation] if tablet else 0
        monitor = internal_monitor() if (transform != effective_transform or last_monitor is None) else last_monitor
        if monitor != last_monitor or transform != effective_transform:
            if monitor:
                emit(None, monitor, transform)
                effective_transform, last_monitor = transform, monitor
        status = {'mode': mode, 'tablet': tablet, 'switch_detected': seen_tablet_switch,
                  'orientation': preferred_orientation, 'transform': transform, 'monitor': monitor}
        if status != last_status:
            save(STATE, status)
            last_status = status
        if current_command != mode:
            current_command = mode
            print(f'Framework mode: {mode}; tablet={tablet}; sensor={orientation}', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('daemon')
    mod = sub.add_parser('mode'); mod.add_argument('value', choices=['auto', 'tablet', 'laptop', 'toggle'])
    orient = sub.add_parser('orientation'); orient.add_argument('value', choices=['auto'] + list(ORIENTATIONS))
    sub.add_parser('status')
    sub.add_parser('doctor')
    rotation = sub.add_parser('rotate-test'); rotation.add_argument('value', choices=ORIENTATIONS)
    args = parser.parse_args()
    if args.command == 'daemon':
        daemon()
    elif args.command == 'mode':
        previous = read(COMMAND, {'mode': 'auto'}).get('mode', 'auto')
        state = read(STATE)
        value = ('laptop' if state.get('tablet') else 'tablet') if args.value == 'toggle' else args.value
        save(COMMAND, {'mode': value})
        print('Framework mode requested:', value, '(the running daemon applies it)')
    elif args.command == 'orientation':
        previous = read(COMMAND, {'mode': 'auto'})
        if args.value == 'auto':
            previous.pop('orientation', None)
        else:
            previous['orientation'] = args.value
        save(COMMAND, previous)
        print('Orientation override:', args.value)
    elif args.command == 'status':
        state = read(STATE)
        print(json.dumps(state or {'status': 'daemon not running / no state yet'}, indent=2))
    elif args.command == 'rotate-test':
        emit(None, internal_monitor(), ORIENTATIONS[args.value], dry_run=True)
    elif args.command == 'doctor':
        for name in ('hyprctl', 'monitor-sensor', 'libinput', 'qs'):
            print(f'{name:16} {shutil.which(name) or "NOT FOUND"}')
        print('Internal monitor:', internal_monitor() or 'not found')
        print('Current status:', json.dumps(read(STATE)))
        print('Switch detection is best-effort; use mode tablet/laptop if libinput lacks seat access.')


if __name__ == '__main__':
    main()
