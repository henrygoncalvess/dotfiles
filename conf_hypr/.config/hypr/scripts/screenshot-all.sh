#!/usr/bin/env bash

FILE_MANAGER="thunar"

SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
FILENAME="screenshot_$(date +%F_%T).png"
SAVE_PATH="$SCREENSHOT_DIR/$FILENAME"

mkdir -p "$SCREENSHOT_DIR"

grim - | tee "$SAVE_PATH" | wl-copy

action=$(notify-send -A "open" "Capture Saved and Copied" "<i>~/Pictures/Screenshots/$FILENAME</i>" -i "$SAVE_PATH")

if [[ "$action" ]]; then
  "$FILE_MANAGER" "$SCREENSHOT_DIR"
fi
