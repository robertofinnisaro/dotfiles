#!/bin/bash

monitor="eDP-1"

monitor-sensor --accel | while read -r line; do
    case "$line" in
        *"normal"*)
            hyprctl keyword monitor "$monitor,preferred,auto,1,transform,0"
            ;;
        *"left-up"*)
            hyprctl keyword monitor "$monitor,preferred,auto,1,transform,1"
            ;;
        *"right-up"*)
            hyprctl keyword monitor "$monitor,preferred,auto,1,transform,3"
            ;;
        *"bottom-up"*)
            hyprctl keyword monitor "$monitor,preferred,auto,1,transform,2"
            ;;
    esac
done
