#!/usr/bin/env bash

networks=$(nmcli -c no -t -f SSID,BARS,SECURITY device wifi | \
awk -F: '!seen[$1]++ {
  signal=$2
  if (signal=="▂▄▆█") icon="- 󰤨 "
  else if (signal=="▂▄▆_") icon="- 󰤥 "
  else if (signal=="▂▄__") icon="- 󰤢 "
  else if (signal=="▂___") icon="- 󰤟 "
  else icon="- 󰤯 "
  printf "%s %s [%s]\n", $1, icon, $3}
')

[[ -z "$networks" ]] && notify-send "Nenhuma rede encontrada." && exit

chosen=$(echo "$networks" | wofi --dmenu --prompt "Wi-Fi:" --width 600 --height 400)

ssid=$(echo "$chosen" | awk -F- '{print $1}')

if [[ -n "$ssid" ]]; then
  nmcli device wifi connect "\"$ssid\""
fi
