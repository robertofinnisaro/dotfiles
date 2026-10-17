#!/usr/bin/env bash
# Diagnostic only. Does not collect clipboard contents or modify root/system files.
set -u
printf 'PALANTIR SYSTEM DIAGNOSTICS (read only)\n'
printf '\n=== Session ===\n'
printf 'WAYLAND_DISPLAY: %s\n' "${WAYLAND_DISPLAY:-unset}"
if command -v hyprctl >/dev/null; then
  hyprctl version 2>&1 | head -8
  printf '\nHyprland config errors:\n'; hyprctl configerrors 2>&1 | head -35
fi
printf '\n=== Quickshell ===\n'
command -v qs || true
qs ipc show 2>&1 | head -55 || true
if command -v systemctl >/dev/null; then
  for service in palantir-quickshell palantir-clipboard-text palantir-clipboard-image power-profiles-daemon tlp tuned iio-sensor-proxy; do
    if [[ "$service" == palantir-* ]]; then opts=(--user); else opts=(); fi
    printf '%-31s %s\n' "$service" "$(systemctl "${opts[@]}" is-active "${service}.service" 2>/dev/null || true)"
  done
fi
printf '\n=== Dependencies ===\n'
for program in python3 monitor-sensor libinput cliphist wl-paste wl-copy powerprofilesctl hyprctl grim slurp; do
  printf '%-20s %s\n' "$program" "$(command -v "$program" || printf 'missing')"
done
printf '\n=== Framework sensors & switches ===\n'
python3 "$HOME/.config/hypr/scripts/palantir-framework12.py" doctor
for module in cros_ec_sensors pinctrl_tigerlake soc_button_array; do
  if [[ -d "/sys/module/$module" ]]; then echo "$module: present"; else echo "$module: absent or built-in"; fi
done
printf '\n=== Clipboard ===\n'
if command -v cliphist >/dev/null; then
  cliphist list >/dev/null 2>&1 && echo 'cliphist list: OK' || echo 'cliphist list: FAILED (no entries or watcher/database issue)'
fi
printf '\n=== Display manager ===\n'
readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true
printf '\nNo clipboard data or privileged logs printed.\n'
