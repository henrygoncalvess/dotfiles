#!/usr/bin/env bash

networks=$(nmcli -c no -t -f SSID,BARS,SECURITY device wifi | \
awk -F: '!seen[$1]++ {
  signal=$2
  # Usando os ícones que você definiu
  if (signal=="▂▄▆█") icon="-> 󰤨 "
  else if (signal=="▂▄▆_") icon="-> 󰤥 "
  else if (signal=="▂▄__") icon="-> 󰤢 "
  else if (signal=="▂___") icon="-> 󰤟 "
  else icon="-> 󰤯 "
  printf "%s %s [%s]\n", $1, icon, $3}
')

[[ -z "$networks" ]] && notify-send "Nenhuma rede encontrada." -t 5000 && exit

numlines=$(echo "$networks" | wc -l)
height=$(( 34 * numlines ))

if "$rumlines" == 1; then
  height=45
fi

chosen=$(echo "$networks" | wofi --dmenu --prompt "Wi-Fi:" --width 400 --height "$height")

ssid=$(echo "$chosen" | awk -F" ->" '{print $1}' | xargs)

if [[ -n "$ssid" ]]; then
  notify-send "Type the password for: $ssid" -t 5000
  password=$(wofi --dmenu --prompt "Password:" --width 600 --height 45 --password)
  
  notify-send "Trying to connect to: $ssid ..." -t 5000
  nmcli device wifi connect "$ssid" password "$password"

  NMCLI_STATUS=$?

  if [[ $NMCLI_STATUS -eq 0 ]]; then
    notify-send "Successfully connected to $ssid!" -t 5000
    exit 0
  fi
  
  if [[ $NMCLI_STATUS -eq 10 ]]; then
    notify-send "Connection FAILED: SSID '$ssid' not found or activation failed." -t 5000
  elif [[ $NMCLI_STATUS -eq 1 ]]; then
    notify-send "Wrong password, Try again." -t 5000
  else
    notify-send "Connection FAILED (Code $NMCLI_STATUS)." -t 5000
  fi
fi
