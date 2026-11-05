#!/usr/bin/env bash
# Framework 12 rotation + aligned touchscreen/stylus transforms.
# Started once by the compositor; works on niri and Hyprland.
set -euo pipefail
exec python3 "$HOME/.config/hypr/scripts/palantir-framework12.py" daemon
