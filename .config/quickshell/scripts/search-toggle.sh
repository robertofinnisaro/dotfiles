#!/usr/bin/env bash
# Use this shell's real IPC handler, not the old `qs -c ipc call TEST_ALIVE`.
if command -v qs >/dev/null 2>&1 && qs ipc call search toggle >/dev/null 2>&1; then
  exit 0
fi
if command -v fuzzel >/dev/null 2>&1; then
  exec fuzzel
elif command -v hyprlauncher >/dev/null 2>&1; then
  exec hyprlauncher
fi
command -v notify-send >/dev/null 2>&1 && notify-send 'Launcher unavailable' 'Start Quickshell or install fuzzel.'
exit 1
