#!/usr/bin/env bash
# Bridge gracefully when PPD is absent. Do not install or activate conflicting backends.
set -euo pipefail
case "${1:-get}" in
  get)
    if command -v powerprofilesctl >/dev/null 2>&1; then
      powerprofilesctl get 2>/dev/null || echo unavailable
    else
      echo unavailable
    fi
    ;;
  set)
    case "${2:-}" in balanced|power-saver|performance) ;; *) exit 2 ;; esac
    if command -v powerprofilesctl >/dev/null 2>&1; then
      exec powerprofilesctl set "$2"
    fi
    echo 'Power profile unavailable. Check TLP/TuneD/PPD before changing backends.' >&2
    exit 1
    ;;
  *) echo 'Usage: power-profile.sh get | set balanced|power-saver|performance' >&2; exit 2 ;;
esac
