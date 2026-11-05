#!/usr/bin/env python3
"""Lists the niri keybinds for the Red Book panel, as JSON on stdout.

Reads the live config each time so the list cannot go stale. Each bind's name comes
from its hotkey-overlay-title, and the comment above a group of binds names the section.
"""
import json
from pathlib import Path
import re
import sys

CONFIG = Path.home() / ".config/niri/config.kdl"
BIND = re.compile(r'^(\S+)\s+.*hotkey-overlay-title="([^"]*)"')
KEY_NAMES = {
    "Mod": "Super",
    "Return": "Enter",
    "Comma": ",",
    "Period": ".",
    "Minus": "-",
    "Equal": "=",
    "Slash": "/",
    "WheelScrollDown": "Scroll down",
    "WheelScrollUp": "Scroll up",
    "XF86AudioRaiseVolume": "Volume up",
    "XF86AudioLowerVolume": "Volume down",
    "XF86AudioMute": "Mute",
    "XF86AudioMicMute": "Mic mute",
    "XF86MonBrightnessUp": "Brightness up",
    "XF86MonBrightnessDown": "Brightness down",
    "XF86AudioNext": "Next track",
    "XF86AudioPrev": "Previous track",
    "XF86AudioPlay": "Play",
    "XF86AudioPause": "Pause",
}
# Built into niri, so these are not in the config.
BUILT_IN = {
    "title": "Built in",
    "binds": [
        {"keys": "Alt + Tab", "action": "Switch between recent windows"},
        {"keys": "Super + Left drag", "action": "Move a window"},
        {"keys": "Super + Right drag", "action": "Resize a window"},
    ],
}


def readable_keys(combo):
    return " + ".join(KEY_NAMES.get(key, key) for key in combo.split("+"))


def parse(text):
    sections = []
    title = "General"
    in_binds = False
    for raw in text.splitlines():
        line = raw.strip()
        if not in_binds:
            in_binds = line == "binds {"
            continue
        if line == "}":
            break
        if line.startswith("//"):
            title = line.lstrip("/ ").strip()
            continue
        match = BIND.match(line)
        if not match:
            continue
        if not sections or sections[-1]["title"] != title:
            sections.append({"title": title, "binds": []})
        sections[-1]["binds"].append({"keys": readable_keys(match.group(1)), "action": match.group(2)})
    return sections + [BUILT_IN]


def main():
    try:
        text = CONFIG.read_text(encoding="utf-8")
    except OSError as error:
        print(f"Red Book: cannot read {CONFIG}: {error}", file=sys.stderr)
        return 1
    print(json.dumps(parse(text)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
