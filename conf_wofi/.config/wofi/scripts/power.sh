#!/usr/bin/env bash

chosen=$(echo -e " Power Off\n Restart\n Suspend\n Lock" | wofi --dmenu --prompt "Power:" --width 200 --height 100 --hide-scroll)

case "$chosen" in
  *Lock) swaylock ;;
  *Restart) systemctl reboot ;;
  *"Power Off") systemctl poweroff ;;
  *Suspend) systemctl suspend ;;
esac
