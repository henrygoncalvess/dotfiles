#!/usr/bin/env bash

ps aux | grep "random-paper-hypr.sh" | grep -v "$$" | awk '{print $2}' | xargs kill -9 2>/dev/null
sleep 0.5 

PIC=$(find "$HOME/wallpapers/desktop" -type f | shuf -n 1 --random-source=/dev/random)
pkill -9 -f "swaybg"
swaybg -m fill -i "$PIC" &

while true
do
  sleep 45m
  
  PIC=$(find "$HOME/wallpapers/desktop" -type f | shuf -n 1 --random-source=/dev/random)

  pkill -9 -f "swaybg"
  swaybg -m fill -i "$PIC" &
done
