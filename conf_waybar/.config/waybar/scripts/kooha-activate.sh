#!/usr/bin/env bash

STATE_FILE="$HOME/.config/waybar/scripts/state.txt"

if [[ -f "$STATE_FILE" ]] && [[ $(cat "$STATE_FILE") == "recording"  ]]; then
  jq -n --unbuffered --compact-output \
    --arg alt "stop" \
    '{"alt": $alt}'

else
  jq -n --unbuffered --compact-output \
    --arg alt "default" \
    '{"alt": $alt}'
fi

