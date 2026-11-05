#!/usr/bin/env bash
# Super+S: show or leave the "magic" workspace, standing in for Hyprland's special workspace.
set -euo pipefail
current="$(niri msg -j workspaces | jq -r '.[] | select(.is_focused) | .name // ""')"
if [[ "$current" == magic ]]; then
  exec niri msg action focus-workspace-previous
fi
exec niri msg action focus-workspace magic
