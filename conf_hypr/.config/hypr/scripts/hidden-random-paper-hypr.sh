#!/usr/bin/env bash

WALLPAPERS_DIR="$HOME/wallpapers/desktop/hidden"

ps aux | grep "random-paper-hypr.sh" | grep -v "$$" | awk '{print $2}' | xargs kill -9 2>/dev/null
sleep 0.3
ps aux | grep "hidden-random-paper-hypr.sh" | grep -v "$$" | awk '{print $2}' | xargs kill -9 2>/dev/null
sleep 0.3
pkill -f "swaybg"

PIC=$(find "$WALLPAPERS_DIR" -type f | shuf -n 1 --random-source=/dev/random)
swaybg -m fill -i "$PIC" &

while true
do
  sleep 20m
  
  PIC=$(find "$WALLPAPERS_DIR" -type f | shuf -n 1 --random-source=/dev/random)

  pkill -f "swaybg"
  swaybg -m fill -i "$PIC" &
done
