#!/usr/bin/env bash

THEME="$1"
STYLE="$HOME/.config/waybar/style.css"

sed -i "s|@import .*themes/.*|@import \"themes/${THEME}.css\";|" "$STYLE"

pkill waybar
waybar &
