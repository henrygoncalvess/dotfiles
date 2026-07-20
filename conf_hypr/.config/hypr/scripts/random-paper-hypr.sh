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

# Kill Omarchy's default swaybg so it doesn't cover awww
killall swaybg 2>/dev/null || true

random_transition() {
  local PIC="$1"
  local STEP=$(shuf -i 1-90 -n 1)
  effects=("wipe" "any")
  chosen_effect=$(printf "%s\n" "${effects[@]}" | shuf -n 1)

  # Copy to Quickshell's expected current wallpaper location
  mkdir -p "$QS_CACHE"
  cp "$PIC" "$QS_CACHE/current_wallpaper.png" 2>/dev/null || true

  case "$chosen_effect" in
    wipe)
      ANGLE=$(shuf -i 0-365 -n 1)
      awww img "$PIC" --transition-duration 5 --transition-fps 60 --transition-type wipe --transition-step $STEP --transition-angle $ANGLE
      ;;
    any)
      awww img "$PIC" --transition-duration 5 --transition-fps 60 --transition-type any --transition-step $STEP
      ;;
  esac

  # Apply matugen colors and reload quickshell
  if command -v matugen &>/dev/null; then
    ( matugen image "$PIC" || true; bash "$RELOAD_SCRIPT" || true ) &
  fi
}

PIC=$(find "$WALLPAPERS_DIR" -type f 2>/dev/null | shuf -n 1 --random-source=/dev/random)
if [ -n "$PIC" ]; then
  random_transition "$PIC"
fi

while true; do
  sleep 30m
  PIC=$(find "$WALLPAPERS_DIR" -type f 2>/dev/null | shuf -n 1 --random-source=/dev/random)
  if [ -n "$PIC" ]; then
    random_transition "$PIC"
  fi
done