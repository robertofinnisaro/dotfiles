#!/usr/bin/env bash
if command -v qs >/dev/null 2>&1 && qs ipc call deck toggle >/dev/null 2>&1; then
  exit 0
fi
command -v notify-send >/dev/null 2>&1 && notify-send 'Palantír unavailable' 'Check Quickshell: qs log'
exit 1
