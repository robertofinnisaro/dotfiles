#!/usr/bin/env bash
if ! command -v tailscale >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  printf '{"text":"TS ?","class":"unknown","tooltip":"Tailscale or jq unavailable"}\n'
  exit 0
fi
state=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // "Stopped"' 2>/dev/null) || state='Stopped'
if [[ "$state" == Running ]]; then
    printf '{"text":"TS ON","class":"on","tooltip":"Tailscale: Connected"}\n'
else
    printf '{"text":"TS OFF","class":"off","tooltip":"Tailscale: %s"}\n' "$state"
fi
