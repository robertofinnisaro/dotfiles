#!/usr/bin/env bash
# Called by the rotation controller: portrait gets a compact bar, as the full one is too wide.
config="$HOME/.config/waybar/config-niri"
[[ "${1:-}" == portrait ]] && config+="-portrait"
pkill -x waybar
exec niri msg action spawn -- waybar -c "$config"
