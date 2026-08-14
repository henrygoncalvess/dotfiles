#!/usr/bin/env bash
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

if systemctl is-active --quiet NetworkManager; then
    exec "$SCRIPT_DIR/wifi_panel_logic_nmcli.sh" "$@"
else
    exec python3 "$SCRIPT_DIR/wifi_panel_logic_iwd.py" "$@"
fi
