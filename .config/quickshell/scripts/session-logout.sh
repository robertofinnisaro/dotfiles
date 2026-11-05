#!/usr/bin/env bash
# Ends the current compositor session, for wlogout and the power menu.
if [[ -n "${NIRI_SOCKET:-}" ]]; then
  exec niri msg action quit --skip-confirmation
fi
exec hyprctl dispatch exit
