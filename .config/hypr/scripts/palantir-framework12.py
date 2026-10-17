#!/usr/bin/env python3
"""Framework 12 posture and orientation controller for Hyprland.

Auto mode is driven by Hyprland tablet-mode switch bindings, not by requiring
unprivileged libinput access. libinput remains a best-effort fallback.
Does not touch keyboard/touchpad enablement, kernel modules, or display wallpaper.
"""
from __future__ import annotations

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
SWITCH = RUNTIME / 'palantir-framework12-switch.json'
ORIENTATIONS = {'normal': 0, 'left-up': 1, 'bottom-up': 2, 'right-up': 3}
SWITCH_PATTERN = re.compile(r'\b(?:tablet-mode|tablet mode)\s+state\s+([01])\b', re.I)
SENSOR_PATTERN = re.compile(r'orientation(?: changed)?:\s*(normal|left-up|right-up|bottom-up)\b', re.I)


def save(path: Path, obj: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f'{path.name}.{os.getpid()}.tmp')
    temporary.write_text(json.dumps(obj), encoding='utf-8')
    os.replace(temporary, path)


def read(path: Path, fallback=None) -> dict:
    try:
        value = json.loads(path.read_text(encoding='utf-8'))
        return value if isinstance(value, dict) else (fallback or {})
    except (OSError, ValueError):
        return {} if fallback is None else fallback


def run(args: list[str], *, quiet=True) -> bool:
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=4)
        if result.returncode and not quiet:
            print('Framework controller:', ' '.join(args), result.stderr.strip() or result.stdout.strip(), file=sys.stderr)
        return result.returncode == 0
    except (OSError, subprocess.TimeoutExpired) as error:
        if not quiet:
            print('Framework controller:', error, file=sys.stderr)
        return False


def internal_monitor() -> tuple[str | None, int | None]:
    """Return eDP name and reported transform; never select external displays."""
    try:
        raw = subprocess.check_output(['hyprctl', 'monitors', '-j'], text=True, timeout=4)
        for monitor in json.loads(raw):
            if str(monitor.get('name', '')).startswith('eDP-'):
                return monitor['name'], monitor.get('transform')
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError, subprocess.TimeoutExpired, TypeError):
        pass
    return None, None


def emit(monitor: str | None, degree: int, *, dry_run=False) -> bool:
    if not monitor:
        if dry_run:
            print('No internal eDP monitor detected; nothing changed')
        return False
    commands = [
        ['hyprctl', 'keyword', 'monitor', f'{monitor},preferred,auto,1,transform,{degree}'],
        ['hyprctl', 'keyword', 'input:touchdevice:transform', str(degree)],
        ['hyprctl', 'keyword', 'input:tablet:transform', str(degree)],
    ]
    if dry_run:
        for cmd in commands:
            print(' '.join(cmd))
        return True
    return all(run(cmd, quiet=False) for cmd in commands)


def stream_events(args: list[str], label: str, inbox: queue.Queue) -> None:
    if not shutil.which(args[0]):
        inbox.put(('missing', label))
        return
    while True:
        try:
            with subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                  text=True, bufsize=1) as process:
                assert process.stdout is not None
                for line in process.stdout:
                    inbox.put((label, line.strip()))
                rc = process.wait()
                if rc:
                    inbox.put(('failed', label))
        except OSError:
            inbox.put(('failed', label))
        time.sleep(10)


def choose_state(mode: str, switch_state: bool | None, orientation: str, override: str | None) -> tuple[bool, int, str]:
    """Pure posture state logic; unknown switch never guesses tablet posture."""
    if mode not in ('auto', 'tablet', 'laptop'):
        mode = 'auto'
    orient = override if override in ORIENTATIONS else orientation
    if orient not in ORIENTATIONS:
        orient = 'normal'
    tablet = mode == 'tablet' or (mode == 'auto' and switch_state is True)
    return tablet, ORIENTATIONS[orient] if tablet else 0, orient


def parse_sensor_line(line: str) -> str | None:
    match = SENSOR_PATTERN.search(line)
    return match.group(1).lower() if match else None


def parse_libinput_line(line: str) -> bool | None:
    if 'SWITCH_TOGGLE' not in line:
        return None
    match = SWITCH_PATTERN.search(line)
    return (match.group(1) == '1') if match else None


def daemon() -> None:
    inbox: queue.Queue = queue.Queue()
    # monitor-sensor obtains orientation; libinput is optional and may lack seat access.
    for cmd, label in [(['monitor-sensor', '--accel'], 'sensor'),
                       (['libinput', 'debug-events', '--udev'], 'libinput')]:
        threading.Thread(target=stream_events, args=(cmd, label, inbox), daemon=True).start()

    orientation = 'normal'
    seen_sensor = False
    switch_state: bool | None = None
    switch_source = 'unavailable'
    last_switch_stamp: float = -1
    last_sensor_error = None
    last_status = None
    last_mode = None
    last_monitor = None
    last_transform = None
    last_apply = 0.0
    last_probe = 0.0
    while True:
        try:
            source, line = inbox.get(timeout=1)
            if source == 'sensor':
                orient = parse_sensor_line(line)
                if orient is not None:
                    orientation = orient
                    seen_sensor = True
            elif source == 'libinput':
                folded = parse_libinput_line(line)
                # Explicit compositor bindings have priority over an optional debug process.
                if folded is not None and switch_source != 'hyprland':
                    switch_state = folded
                    switch_source = 'libinput'
            elif source in ('failed', 'missing') and line == 'sensor':
                last_sensor_error = source
        except queue.Empty:
            pass

        # Hyprland bindings write SWITCH atomically. Polling avoids another process
        # requiring exclusive input-device permissions.
        report = read(SWITCH)
        stamp = report.get('timestamp')
        if (report.get('source') == 'hyprland'
                and isinstance(stamp, (float, int)) and stamp > last_switch_stamp
                and isinstance(report.get('tablet'), bool)):
            switch_state = report['tablet']
            switch_source = 'hyprland'
            last_switch_stamp = stamp

        requested = read(COMMAND, {'mode': 'auto'})
        mode = requested.get('mode', 'auto')
        if mode not in ('auto', 'tablet', 'laptop'):
            mode = 'auto'
        tablet, transform, selected_orientation = choose_state(
            mode, switch_state, orientation, requested.get('orientation'))

        # Recover after hotplug/resume/Hyprland reload as well as posture changes.
        now = time.monotonic()
        due = now - last_probe >= 15
        if due or transform != last_transform or last_monitor is None:
            monitor, actual_transform = internal_monitor()
            last_probe = now
        else:
            monitor, actual_transform = last_monitor, last_transform
        needs_apply = monitor and (transform != last_transform or monitor != last_monitor
                                   or (due and actual_transform is not None and actual_transform != transform))
        if needs_apply and emit(monitor, transform):
            last_transform = transform
            last_monitor = monitor
            last_apply = now
        elif monitor and last_monitor is None:
            last_monitor = monitor

        warning = None
        if mode == 'auto' and switch_state is None:
            warning = 'Tablet switch not observed; fold/unfold and check Hyprland switch bindings'
        elif mode == 'auto' and tablet and not seen_sensor:
            warning = 'Tablet detected but accelerometer has not reported an orientation'
        if last_sensor_error and not seen_sensor:
            warning = 'monitor-sensor unavailable or failed; check iio-sensor-proxy'
        status = {
            'mode': mode, 'tablet': tablet, 'switch_detected': switch_state is not None,
            'switch_source': switch_source, 'switch_tablet': switch_state,
            'orientation': selected_orientation, 'sensor_detected': seen_sensor,
            'transform': transform, 'monitor': monitor,
            'warning': warning,
        }
        if status != last_status:
            save(STATE, status)
            last_status = status
        if mode != last_mode:
            print(f'Framework: mode={mode}, switch={switch_state}, source={switch_source}, '
                  f'orientation={selected_orientation}, transform={transform}', flush=True)
            last_mode = mode


def doctor() -> None:
    for executable in ('hyprctl', 'monitor-sensor', 'libinput', 'qs'):
        print(f'{executable:18}{shutil.which(executable) or "NOT FOUND"}')
    monitor, transform = internal_monitor()
    print('Internal monitor:', monitor or 'not detected', 'transform:', transform)
    state = read(STATE)
    print('Status:', json.dumps(state or {'message': 'No controller state; verify auto-rotate.sh is running'}, indent=2))
    print('Last Hyprland switch event:', json.dumps(read(SWITCH) or 'none'))
    try:
        proc = subprocess.run(['hyprctl', 'devices'], capture_output=True, text=True, timeout=3)
        has_switch = any('tablet mode switch' in line.lower() for line in proc.stdout.splitlines())
        print('Hyprland Tablet Mode Switch:', 'present' if has_switch else 'NOT FOUND')
    except (OSError, subprocess.TimeoutExpired):
        print('Hyprland Tablet Mode Switch: unknown (hyprctl unavailable)')
    try:
        proc = subprocess.run(['hyprctl', 'binds', '-j'], capture_output=True, text=True, timeout=3)
        binding = 'switch:on:Tablet Mode Switch' in proc.stdout and 'switch:off:Tablet Mode Switch' in proc.stdout
        print('Hyprland switch bindings:', 'reported' if binding else 'not confirmed; inspect active bindings')
    except (OSError, subprocess.TimeoutExpired):
        print('Hyprland switch bindings: unknown')
    print('Check sensor with: monitor-sensor --accel')
    print('Switch state with: python3 ~/.config/hypr/scripts/palantir-framework12.py status')
    print('Framework hardware checks: https://github.com/FrameworkComputer/linux-docs/blob/main/framework12/debugging.md')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('daemon')
    mod = sub.add_parser('mode')
    mod.add_argument('value', choices=['auto', 'tablet', 'laptop', 'toggle'])
    orient = sub.add_parser('orientation')
    orient.add_argument('value', choices=['auto'] + list(ORIENTATIONS))
    switch = sub.add_parser('switch')
    switch.add_argument('value', choices=['tablet', 'laptop'])
    sub.add_parser('status')
    sub.add_parser('doctor')
    rot = sub.add_parser('rotate-test')
    rot.add_argument('value', choices=ORIENTATIONS)
    args = parser.parse_args()
    if args.command == 'daemon':
        daemon()
    elif args.command == 'switch':
        # A switch event is a hardware reading; do NOT modify user's manual mode.
        save(SWITCH, {'tablet': args.value == 'tablet', 'source': 'hyprland', 'timestamp': time.time()})
    elif args.command == 'mode':
        previous = read(COMMAND, {'mode': 'auto'})
        state = read(STATE)
        value = ('laptop' if state.get('tablet') else 'tablet') if args.value == 'toggle' else args.value
        previous['mode'] = value  # preserve explicit orientation override
        save(COMMAND, previous)
        print('Framework mode requested:', value)
    elif args.command == 'orientation':
        previous = read(COMMAND, {'mode': 'auto'})
        if args.value == 'auto':
            previous.pop('orientation', None)
        else:
            previous['orientation'] = args.value
        save(COMMAND, previous)
        print('Orientation override:', args.value)
    elif args.command == 'status':
        print(json.dumps(read(STATE) or {'status': 'daemon not running / no state yet'}, indent=2))
    elif args.command == 'rotate-test':
        emit(internal_monitor()[0], ORIENTATIONS[args.value], dry_run=True)
    elif args.command == 'doctor':
        doctor()


if __name__ == '__main__':
    main()
