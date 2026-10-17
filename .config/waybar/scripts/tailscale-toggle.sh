#!/usr/bin/env bash
# Never initiate interactive sudo from Waybar; grant tailscale operator permission separately.
set -u
if ! command -v tailscale >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  command -v notify-send >/dev/null 2>&1 && notify-send 'Tailscale unavailable' 'Install tailscale first.'
  exit 1
fi
state=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // "Stopped"' 2>/dev/null) || state='Stopped'
if [[ "$state" == Running ]]; then
  sudo tailscale down >/dev/null 2>&1 || {
    command -v notify-send >/dev/null 2>&1 && notify-send 'Tailscale permission denied' 'See the README: set an operator with tailscale set --operator.'
    exit 1
  }
else
  sudo tailscale up >/dev/null 2>&1 || {
    command -v notify-send >/dev/null 2>&1 && notify-send 'Tailscale could not connect' 'Run tailscale up in a terminal for interactive setup.'
    exit 1
  }
fi
