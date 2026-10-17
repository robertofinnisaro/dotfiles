#!/usr/bin/env bash
# Route keybindings through Quickshell IPC, so a failed command is visible.
set -euo pipefail
case "${1:-}" in
  deck) args=(deck toggle);;
  overlay) args=(overlay toggle);;
  overview) args=(search workspacesToggle);;
  keyboard) args=(osk toggle);;
  clipboard) args=(search clipboardToggle);;
  launcher) args=(search toggle);;
  *) printf 'Usage: %s {deck|overlay|overview|keyboard|clipboard|launcher}\n' "$0" >&2; exit 2;;
esac
if ! command -v qs >/dev/null 2>&1; then
  echo 'Palantír: Quickshell CLI (qs) is not installed/in PATH.' >&2
  command -v notify-send >/dev/null 2>&1 && notify-send -u normal 'Palantír' 'Quickshell not installed or not in PATH.' || true
  exit 127
fi
if output="$(qs ipc call "${args[@]}" 2>&1)"; then
  exit 0
fi
printf 'Palantír IPC failed: qs ipc call %s\n%s\n' "${args[*]}" "$output" >&2
if command -v notify-send >/dev/null 2>&1; then
  notify-send -u normal 'Palantír IPC unavailable' "${args[*]} failed. In terminal: qs ipc show; qs log" || true
fi
exit 1
