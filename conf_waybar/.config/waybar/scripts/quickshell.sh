#!/usr/bin/env bash

# This script is called from Waybar to toggle Quickshell widgets.
# Usage: quickshell.sh <widget_name>

if [ -z "$1" ]; then
    echo "Usage: $0 <widget_name>"
    exit 1
fi

WIDGET="$1"

# We use the exact path to quickshell to avoid Waybar PATH issues
"$HOME/.nix-profile/bin/quickshell" msg main handleCommand toggle "$WIDGET" ""
