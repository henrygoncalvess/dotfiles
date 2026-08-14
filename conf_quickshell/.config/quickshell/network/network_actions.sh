#!/usr/bin/env bash

ACTION=$1
shift

HAS_NM=false
systemctl is-active --quiet NetworkManager && HAS_NM=true

get_wlan_iface() {
    ls -1 /sys/class/net | grep -E '^wl' | head -n1 || iw dev | awk '$1=="Interface"{print $2; exit}'
}
get_eth_iface() {
    ls -1 /sys/class/net | grep -E '^e' | head -n1
}

case "$ACTION" in
    wifi_connect)
        SSID=$1
        PASS=$2
        if $HAS_NM; then
            if [ -n "$PASS" ]; then
                nmcli device wifi connect "$SSID" password "$PASS"
            else
                nmcli con up id "$SSID" || nmcli device wifi connect "$SSID"
            fi
        else
            IFACE=$(get_wlan_iface)
            if [ -n "$PASS" ]; then
                iwctl --passphrase="$PASS" station "$IFACE" connect "$SSID"
            else
                iwctl station "$IFACE" connect "$SSID"
            fi
        fi
        ;;
    wifi_connect_enterprise)
        SSID=$1
        USER=$2
        PASS=$3
        if $HAS_NM; then
            nmcli con add type wifi con-name "$SSID" ifname $(get_wlan_iface) ssid "$SSID" wifi-sec.key-mgmt wpa-eap 802-1x.eap peap 802-1x.phase2-auth mschapv2 802-1x.identity "$USER" 802-1x.password "$PASS"
            nmcli con up "$SSID"
        else
            echo "Error: iwd standalone enterprise connection is not supported via this UI. Use nmcli or iwd provisioning files." >&2
        fi
        ;;
    wifi_disconnect)
        if $HAS_NM; then
            DEV=$(nmcli -t -f DEVICE,TYPE d | grep wifi | cut -d: -f1 | head -n1)
            [ -n "$DEV" ] && nmcli device disconnect "$DEV"
        else
            IFACE=$(get_wlan_iface)
            iwctl station "$IFACE" disconnect
        fi
        ;;
    wifi_forget)
        SSID=$1
        if $HAS_NM; then
            for uuid in $(nmcli -g UUID,TYPE connection show | awk -F: '$2=="802-11-wireless"{print $1}'); do
                if [ "$(nmcli -g 802-11-wireless.ssid connection show "$uuid" 2>/dev/null)" = "$SSID" ]; then
                    nmcli connection delete "$uuid"
                fi
            done
        else
            iwctl known-networks "$SSID" forget
        fi
        ;;
    wifi_power)
        STATE=$1
        if $HAS_NM; then
            nmcli radio wifi "$STATE"
        else
            IFACE=$(get_wlan_iface)
            if [ "$STATE" = "on" ]; then
                ip link set "$IFACE" up
            else
                ip link set "$IFACE" down
            fi
        fi
        ;;
    eth_connect)
        MAC_OR_DEV=$1
        if $HAS_NM; then
            nmcli device connect "$MAC_OR_DEV"
        else
            ip link set "$MAC_OR_DEV" up
        fi
        ;;
    eth_disconnect)
        MAC_OR_DEV=$1
        if $HAS_NM; then
            nmcli device disconnect "$MAC_OR_DEV"
        else
            ip link set "$MAC_OR_DEV" down
        fi
        ;;
    get_saved_wifi)
        if $HAS_NM; then
            nmcli -t -f NAME connection show | grep -v 'lo'
        else
            iwctl known-networks list | sed -e 's/\x1b\[[0-9;]*m//g' | awk -F' {2,}' 'NR>4 && NF>0 {print $1}'
        fi
        ;;
    wifi_status)
        if $HAS_NM; then
            nmcli radio wifi
        else
            IFACE=$(get_wlan_iface)
            if [ -z "$IFACE" ]; then echo "disabled"; exit 0; fi
            OPERSTATE=$(cat /sys/class/net/$IFACE/operstate 2>/dev/null)
            if [ "$OPERSTATE" = "down" ]; then echo "disabled"; else echo "enabled"; fi
        fi
        ;;
    wifi_list_legacy)
        if $HAS_NM; then
            nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null
        else
            python3 -c "
import json, subprocess, os
try:
    j = json.loads(subprocess.check_output(['python3', os.path.expanduser('~/.config/quickshell/network/wifi_panel_logic_iwd.py')]).decode('utf-8'))
    conn = j.get('connected')
    conn_ssid = conn['ssid'] if conn else None
    for n in j.get('networks', []):
        in_use = '*' if n['ssid'] == conn_ssid else ' '
        print(f\"{in_use}:{n['ssid']}:{n['signal']}:{n['security']}\")
except:
    pass
"
        fi
        ;;
esac
