#!/usr/bin/env bash
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

if systemctl is-active --quiet NetworkManager; then
    exec "$SCRIPT_DIR/eth_panel_logic_nmcli.sh" "$@"
else
    exec "$SCRIPT_DIR/eth_panel_logic_ip.sh" "$@"
fi
