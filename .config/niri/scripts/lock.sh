#!/usr/bin/env bash
# For swayidle: start hyprlock once and return, so waiting on it doesn't hold up suspend.
pidof hyprlock >/dev/null || exec niri msg action spawn -- hyprlock
