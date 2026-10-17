#!/usr/bin/env bash
# Super+Print: area screenshot to the Wayland clipboard.
set -euo pipefail
missing=()
for dep in grim slurp wl-copy; do
  command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
done
if ((${#missing[@]})); then
  printf 'Screenshot tools missing: %s\nInstall: sudo pacman -S grim slurp wl-clipboard\n' "${missing[*]}" >&2
  command -v notify-send >/dev/null 2>&1 && notify-send 'Screenshot unavailable' "Missing: ${missing[*]}" || true
  exit 1
fi
# A user cancelling selection should not replace their clipboard.
geometry="$(slurp)" || exit 0
[[ -n "$geometry" ]] || exit 0
if ! grim -g "$geometry" - | wl-copy --type image/png; then
  command -v notify-send >/dev/null 2>&1 && notify-send 'Screenshot failed' 'Check grim permissions and compositor logs.' || true
  exit 1
fi
command -v notify-send >/dev/null 2>&1 && notify-send 'Capture ready' 'Image copied to clipboard.' || true
