#!/usr/bin/env bash
# Standalone power menu: never directly shuts down on a Waybar click.
set -euo pipefail
if [[ "${1:-}" != --terminal ]]; then
  if command -v wlogout >/dev/null 2>&1; then
    exec wlogout
  fi
  if command -v hyprshutdown >/dev/null 2>&1; then
    exec hyprshutdown
  fi
fi
# Deterministic fallback for the original Alacritty-based desktop.
# This is an explicit interactive menu, not an immediate power action.
if [[ "${1:-}" != --terminal ]]; then
  if command -v alacritty >/dev/null 2>&1; then
    exec alacritty -e bash "$0" --terminal
  fi
  command -v notify-send >/dev/null 2>&1 && notify-send 'Power menu unavailable' 'Install wlogout or alacritty for the power menu.' || true
  echo 'Power menu unavailable: need wlogout, hyprshutdown, or alacritty.' >&2
  exit 1
fi
printf '\n    THE COUNCIL OF DEPARTURE\n    ------------------------\n\n'
printf '  [1] Lock screen\n  [2] Suspend\n  [3] Log out of Hyprland\n  [4] Restart computer\n  [5] Shut down computer\n  [0] Cancel\n\n'
read -r -p 'Choose (0-5): ' choice || exit 0
case "$choice" in
  1) command -v hyprlock >/dev/null 2>&1 && exec hyprlock || { echo 'hyprlock missing'; exit 1; } ;;
  2) action=(systemctl suspend); label='suspend';;
  3) action=(hyprctl dispatch exit); label='log out';;
  4) action=(systemctl reboot); label='restart';;
  5) action=(systemctl poweroff); label='shut down';;
  *) exit 0;;
esac
read -r -p "Type YES to confirm $label: " confirmation || exit 0
[[ "$confirmation" == 'YES' ]] || exit 0
"${action[@]}"
