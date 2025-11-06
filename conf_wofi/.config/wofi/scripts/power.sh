#!/usr/bin/env bash

chosen=$(echo -e " Power Off\n Restart\n Suspend\n Lock" | wofi --dmenu --prompt "Power:" --width 200 --height 150 --hide-scroll)

case "$chosen" in
  *Lock) swaylock -i "$HOME/Documents/wallpapers/astronaut-cat.jpg" -s fill ;;
  *Restart) systemctl reboot ;;
  *"Power Off") systemctl poweroff ;;
  *Suspend) systemctl suspend ;;
esac
