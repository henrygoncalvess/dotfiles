#!/usr/bin/env bash

pkill -x waybar
sleep 0.3

waybar > /tmp/waybar.log 2>&1 &
WAYBAR_PID=$!
sleep 0.7

kill -SIGUSR1 $WAYBAR_PID
STATE="hidden"

while true; do
    CURSOR_Y=$(hyprctl cursorpos | awk -F', ' '{print int($2)}')
    
    if [ -z "$CURSOR_Y" ]; then
        sleep 0.1
        continue
    fi
    
    if [ "$STATE" == "hidden" ] && [ "$CURSOR_Y" -le 2 ]; then
        kill -SIGUSR1 $WAYBAR_PID
        STATE="visible"
    elif [ "$STATE" == "visible" ] && [ "$CURSOR_Y" -gt 20 ]; then
        kill -SIGUSR1 $WAYBAR_PID
        STATE="hidden"
    fi
    
    sleep 0.1
done
