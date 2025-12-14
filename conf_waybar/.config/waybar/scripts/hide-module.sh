#!/usr/bin/env bash

WORKSPACE_ID=12

current_workspace=$(hyprctl activeworkspace | awk 'match($0, /ID ([0-9]+)/, id){print id[1]}')

if [[ "$current_workspace" == "$WORKSPACE_ID" ]]; then
    echo ""
else
    echo ""
fi
