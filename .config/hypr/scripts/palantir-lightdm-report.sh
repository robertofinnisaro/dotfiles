#!/usr/bin/env bash
# Read-only diagnostics. Run from an accessible TTY or working graphical session.
set -uo pipefail
out="${1:-$HOME/lightdm-input-report-$(date +%Y%m%d-%H%M%S).txt}"
{
  printf 'System: '; uname -srmo
  printf 'Date: '; date -Is
  echo '==== Package versions ===='
  pacman -Q lightdm lightdm-webkit2-greeter hyprland quickshell linux linux-firmware 2>&1 || :
  echo '==== LightDM effective configuration ===='
  lightdm --show-config 2>&1 || :
  echo '==== Seat status ===='
  loginctl seat-status seat0 2>&1 || :
  echo '==== Input node permissions ===='
  ls -l /dev/input/by-path /dev/input/by-id 2>&1 || :
  echo '==== LightDM journal (current boot) ===='
  journalctl -b -u lightdm -n 160 --no-pager 2>&1 || :
  echo '==== Kernel input, i2c, HID events (current boot) ===='
  journalctl -k -b --no-pager 2>&1 | grep -Ei 'i2c.hid|hid|touchpad|keyboard|input|libinput|usb.*(disconnect|error)' | tail -160 || :
  echo '==== LightDM logs ===='
  ls -l /var/log/lightdm 2>&1 || :
} > "$out"
printf 'Saved read-only diagnostic report to: %s\n' "$out"
printf 'Review/redact usernames, paths, hostnames, serials before sharing.\n'
