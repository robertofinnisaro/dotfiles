#!/usr/bin/env bash
# Called ONCE from the compositor; imports this session's Wayland environment to user systemd.
set -u
session_vars=(WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE NIRI_SOCKET XDG_SESSION_TYPE XDG_CURRENT_DESKTOP DISPLAY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS)
for v in "${session_vars[@]}"; do
    [[ -n "${!v:-}" ]] && export "$v"
done
if ! command -v systemctl >/dev/null 2>&1 || ! systemctl --user show-environment >/dev/null 2>&1; then
    exec qs -n
fi
# Clear the other compositor's socket, left behind if the user manager outlived the last session.
systemctl --user unset-environment HYPRLAND_INSTANCE_SIGNATURE NIRI_SOCKET || true
systemctl --user import-environment "${session_vars[@]}" || true
if ! systemctl --user start palantir-quickshell.service; then
    echo 'Unable to start managed Quickshell; falling back to direct launch' >&2
    exec qs -n
fi
# Clipboard watchers run only if binaries are installed; never start duplicates.
if command -v wl-paste >/dev/null && command -v cliphist >/dev/null; then
    systemctl --user start palantir-clipboard-text.service palantir-clipboard-image.service || true
fi
