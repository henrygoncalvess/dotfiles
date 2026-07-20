#!/usr/bin/env bash

WALLPAPERS_DIR="$HOME/wallpapers/desktop/SPKyjw9HRTImK90/8mWeerfxH3HwuPa/jOsyc1nZGsaPUXw"
QS_CACHE="$HOME/.cache/quickshell/wallpaper_picker"
RELOAD_SCRIPT="$HOME/.config/quickshell/wallpaper/matugen_reload.sh"

# Kill other instances of this script safely
pgrep -f "random-paper-hypr.sh" | grep -v $$ | xargs -r kill -9 2>/dev/null
sleep 0.3

# Wait for awww-daemon to be ready
while ! awww query &>/dev/null; do
  sleep 0.5
done

# Omarchy (the theme's base) might start swaybg a bit late, so let's kill it aggressively
# to ensure it doesn't cover awww's wallpaper.
for i in {1..10}; do
  killall swaybg 2>/dev/null
  sleep 0.5
done &

apply_wallpaper() {
  local PIC="$1"
  local STEP=$(shuf -i 1-90 -n 1)
  
  # Copy to Quickshell's expected current wallpaper location (only if it's a new random one)
  mkdir -p "$QS_CACHE"
  if [ "$PIC" != "$QS_CACHE/current_wallpaper.png" ]; then
      cp "$PIC" "$QS_CACHE/current_wallpaper.png" 2>/dev/null || true
  fi

  awww img "$PIC" --transition-duration 3 --transition-fps 60 --transition-type any --transition-step $STEP

  # Apply matugen colors and reload quickshell
  if command -v matugen &>/dev/null; then
    ( matugen image "$PIC" || true; bash "$RELOAD_SCRIPT" || true ) &
  fi
}

# Restore last selected wallpaper by the user, or pick a random one if none exists
if [ -f "$QS_CACHE/current_wallpaper.png" ]; then
  apply_wallpaper "$QS_CACHE/current_wallpaper.png"
else
  PIC=$(find "$WALLPAPERS_DIR" -type f 2>/dev/null | shuf -n 1 --random-source=/dev/random)
  if [ -n "$PIC" ]; then
    apply_wallpaper "$PIC"
  fi
fi
