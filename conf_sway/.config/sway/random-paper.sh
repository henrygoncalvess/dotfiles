#!/usr/bin/env bash

while true
do

  PIC=$(find "$HOME/Documents/wallpapers" -type f | shuf -n 1 --random-source=/dev/random)

  swaymsg output "*" bg "$PIC" fill > /dev/null

  sleep 2h

done
