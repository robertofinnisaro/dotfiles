#!/usr/bin/env bash
# Called ONCE from Hyprland; imports this session's Wayland environment to user systemd.
set -u
for v in WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE XDG_CURRENT_DESKTOP DISPLAY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS; do
    [[ -n "${!v:-}" ]] && export "$v"
done
if ! command -v systemctl >/dev/null 2>&1 || ! systemctl --user show-environment >/dev/null 2>&1; then
    exec qs -n
fi
systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE XDG_CURRENT_DESKTOP DISPLAY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS || true
if ! systemctl --user start palantir-quickshell.service; then
    echo 'Unable to start managed Quickshell; falling back to direct launch' >&2
    exec qs -n
fi
# Clipboard watchers run only if binaries are installed; never start duplicates.
if command -v wl-paste >/dev/null && command -v cliphist >/dev/null; then
    systemctl --user start palantir-clipboard-text.service palantir-clipboard-image.service || true
fi
