#!/usr/bin/env bash

STATE_FILE="$HOME/.config/waybar/scripts/state.txt"

if [[ -f "$STATE_FILE" ]] && [[ $(cat "$STATE_FILE") == "stopped"  ]]; then
  echo "recording" > "$STATE_FILE"
  flatpak run io.github.seadve.Kooha
  echo "stopped" > "$STATE_FILE"
else
  echo "stopped" > "$STATE_FILE"
  pkill kooha
fi


