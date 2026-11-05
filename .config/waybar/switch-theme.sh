#!/usr/bin/env bash

THEME="$1"
STYLE="$HOME/.config/waybar/style.css"

sed -i "s|@import .*themes/.*|@import \"themes/${THEME}.css\";|" "$STYLE"

if [[ -n "${NIRI_SOCKET:-}" ]]; then
  layout=landscape
  [[ "$(niri msg -j focused-output | jq '.logical.height > .logical.width')" == true ]] && layout=portrait
  exec "$HOME/.config/niri/scripts/waybar-layout.sh" "$layout"
fi

pkill waybar
waybar &
