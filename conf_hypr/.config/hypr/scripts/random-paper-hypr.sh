#!/usr/bin/env bash

WALLPAPERS_DIR="$HOME/wallpapers/desktop/SPKyjw9HRTImK90/8mWeerfxH3HwuPa/jOsyc1nZGsaPUXw"

ps aux | grep "hidden-random-paper-hypr.sh" | grep -v "$$" | awk '{print $2}' | xargs kill -9 2>/dev/null
sleep 0.3
ps aux | grep "random-paper-hypr.sh" | grep -v "$$" | awk '{print $2}' | xargs kill -9 2>/dev/null
sleep 0.3

random_transition() {
  local PIC="$1"
  local STEP=$(shuf -i 1-90 -n 1)
  effects=(
    "wipe"
    "any"
  )
  chosen_effect=$(printf "%s\n" "${effects[@]}" | shuf -n 1)

  case "$chosen_effect" in
    wipe)
      ANGLE=$(shuf -i 0-365 -n 1)
      COMMAND="swww img \"$PIC\" --transition-duration 15 --transition-fps 60 --transition-type wipe --transition-step $STEP --transition-angle $ANGLE"
      ;;

    any)
      COMMAND="swww img \"$PIC\" --transition-duration 15 --transition-fps 60 --transition-type any --transition-step $STEP"
      ;;
  esac

  eval "$COMMAND"
}

PIC=$(find "$WALLPAPERS_DIR" -type f | shuf -n 1 --random-source=/dev/random)
random_transition "$PIC"

NUM_WALLS=$(ls "$WALLPAPERS_DIR" | wc -l)
TIME=$((1440 / "$NUM_WALLS"))

while true
do
  sleep "$TIME"m
  
  PIC=$(find "$WALLPAPERS_DIR" -type f | shuf -n 1 --random-source=/dev/random)

  random_transition "$PIC"
done
