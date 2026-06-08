#!/usr/bin/env bash

dir="$HOME/.config/rofi/scripts/wifi"
notify-send "Looking for connections..." -t 3000

# Lista as redes disponíveis
networks=$(nmcli -c no -t -f SSID,BARS,SECURITY device wifi | \
awk -F: '!seen[$1]++ {
  signal=$2
  if (signal=="▂▄▆█") icon="-> 󰤨 "
  else if (signal=="▂▄▆_") icon="-> 󰤥 "
  else if (signal=="▂▄__") icon="-> 󰤢 "
  else if (signal=="▂___") icon="-> 󰤟 "
  else icon="-> 󰤯 "
  printf "%s %s [%s]\n", $1, icon, $3}
')

[[ -z "$networks" ]] && notify-send "Nenhuma rede encontrada." && exit

# Abre o dmenu do Rofi
chosen=$(echo "$networks" | rofi -dmenu -p "Wi-Fi" -theme "$dir/networks.rasi")
ssid=$(echo "$chosen" | awk -F" ->" '{print $1}' | xargs)

if [[ -n "$ssid" ]]; then
  
  # Verifica se a rede já possui um perfil salvo no NetworkManager
  is_saved=$(nmcli -g NAME connection show | grep -Fx "$ssid")

  if [[ -n "$is_saved" ]]; then
    # --- REDE CONHECIDA ---
    notify-send "Network known. Reconnecting to: $ssid ..."
    
    # Derruba a conexão atual graciosamente para limpar a tabela de roteamento velha
    nmcli connection down id "$ssid" > /dev/null 2>&1
    
    # Sobe a conexão forçando um novo pedido de IP (DHCP)
    nmcli connection up id "$ssid"
    NMCLI_STATUS=$?
    
  else
    # --- REDE NOVA ---
    password=$(rofi -dmenu -p "Password" -password -mesg "Enter the password for network" -theme "$dir/password.rasi")
    
    notify-send "Trying to connect to new network: $ssid ..."
    nmcli device wifi connect "$ssid" password "$password"
    NMCLI_STATUS=$?
  fi

  # Tratamento de status
  if [[ $NMCLI_STATUS -eq 0 ]]; then
    notify-send "Successfully connected to $ssid!"
    exit 0
  fi
  
  if [[ $NMCLI_STATUS -eq 10 ]]; then
    notify-send "Connection FAILED: SSID '$ssid' not found or activation failed."
  elif [[ $NMCLI_STATUS -eq 1 ]]; then
    notify-send "Wrong password, Try again."
  else
    notify-send "Connection FAILED (Code $NMCLI_STATUS)."
  fi
fi
