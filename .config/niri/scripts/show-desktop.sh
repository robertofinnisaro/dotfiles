#!/usr/bin/env bash
# Super+H: hide all windows by moving to an empty workspace; press again to return.
# niri has no minimise, so nothing is closed and the windows stay where they were.
set -euo pipefail
workspaces="$(niri msg -j workspaces)"
if jq -e 'any(.[]; .is_focused and .active_window_id == null)' <<<"$workspaces" >/dev/null; then
  exec niri msg action focus-workspace-previous
fi
# niri always keeps an empty unnamed workspace last on each output.
empty="$(jq -r '(.[] | select(.is_focused) | .output) as $output
  | [.[] | select(.output == $output and .name == null and .active_window_id == null)]
  | max_by(.idx) | .idx' <<<"$workspaces")"
exec niri msg action focus-workspace "$empty"
