#!/usr/bin/env bash

# Find first ethernet device
ETH_DEV=$(ls -1 /sys/class/net | grep -E '^e' | head -n1)

if [[ -z "$ETH_DEV" ]]; then
    jq -nc --arg power "off" '{ "present": false, "power": $power, "device": "", "connected": null }'
    exit 0
fi

OPERSTATE=$(cat /sys/class/net/"$ETH_DEV"/operstate 2>/dev/null)

if [[ "$OPERSTATE" == "up" || "$OPERSTATE" == "unknown" ]]; then
    POWER="on"
    
    IP=$(ip -4 addr show dev "$ETH_DEV" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    [ -z "$IP" ] && IP="No IP"

    SPEED=$(cat /sys/class/net/"$ETH_DEV"/speed 2>/dev/null)
    [ -n "$SPEED" ] && SPEED="${SPEED} Mbps" || SPEED="Unknown"

    MAC=$(cat /sys/class/net/"$ETH_DEV"/address 2>/dev/null)
    PROFILE="Wired Connection"

    CONNECTED_JSON=$(jq -nc \
        --arg id "$ETH_DEV" \
        --arg name "$PROFILE" \
        --arg icon "󰈀" \
        --arg ip "$IP" \
        --arg speed "$SPEED" \
        --arg mac "$MAC" \
        '{id: $id, name: $name, icon: $icon, ip: $ip, speed: $speed, mac: $mac}')
else
    POWER="off"
    CONNECTED_JSON="null"
fi

jq -nc \
    --arg power "$POWER" \
    --arg device "$ETH_DEV" \
    --argjson connected "$CONNECTED_JSON" \
    '{present: true, power: $power, device: $device, connected: $connected}'
