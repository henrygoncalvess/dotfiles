#!/usr/bin/env bash

dir="$HOME/.config/rofi/scripts/bluetooth"

status=$(bluetoothctl show | grep 'Powered:' | \
awk '{
  if ($2=="no") $2="on"
  if ($2=="yes") $2="off"
  print $2
}')

action=$(echo -e "Turn $status 󰂲\nSearch Devices " | rofi -dmenu -p 'Bluetooth Action' -theme "$dir/action.rasi")

if echo "$action" | grep 'Turn'; then
  bluetoothctl power "$status"
fi

if echo "$action" | grep 'Search'; then
  bluetoothctl power on
  blueman-manager &
fi
