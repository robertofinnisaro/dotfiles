#!/usr/bin/env bash
# Works with BAT0, BAT1 and other power_supply battery names.
shopt -s nullglob
for entry in /sys/class/power_supply/BAT*; do
  [[ -r "$entry/capacity" && -r "$entry/status" ]] || continue
  IFS= read -r capacity < "$entry/capacity"
  IFS= read -r status < "$entry/status"
  [[ "$capacity" =~ ^[0-9]+$ ]] || continue
  if [[ "$status" == Charging ]]; then
    icon='+'; state='charging'
  elif [[ "$status" == Full ]]; then
    icon='='; state='full'
  else
    icon='-'; state='discharging'
  fi
  printf '{"text":"%s%% %s","tooltip":"Battery: %s","class":"%s"}\n' "$capacity" "$icon" "$state" "$state"
  exit 0
done
printf '{"text":"AC","tooltip":"No battery detected","class":"unknown"}\n'
