#!/usr/bin/env bash
# Framework 12 rotation + aligned touchscreen/stylus transforms.
# This replaces the original screen-only loop; the Hyprland startup line remains unchanged.
set -euo pipefail
exec python3 "$HOME/.config/hypr/scripts/palantir-framework12.py" daemon
