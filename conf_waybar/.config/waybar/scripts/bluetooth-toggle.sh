#!/usr/bin/env bash

dir="$HOME/.config/rofi/powermenu/type-4"
theme='style-1'

status=$(bluetoothctl show | grep 'Powered:' | \
awk '{
  if ($2=="no") $2="󰂯"
  if ($2=="yes") $2="󰂲"
  print $2
}')

action=$(echo -e "$status\n" | rofi -dmenu -mesg 'Bluetooth action' -theme "$dir/shared/confirm.rasi")

if echo "$action" | grep '󰂯'; then
  bluetoothctl power on
fi

if echo "$action" | grep '󰂲'; then
  bluetoothctl power off
fi

if echo "$action" | grep ''; then
  bluetoothctl power on
  blueman-manager &
fi
