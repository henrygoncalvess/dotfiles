#!/usr/bin/env bash

# Bridge between the quickshell widgets and the "main" IPC handler in Main.qml.
# Widgets shell out to this to close or toggle themselves (appLauncher.qml and
# ClipboardManager.qml call `qs_manager.sh close` when you pick an entry or
# press Escape), so without it they open but never close.
#
# Usage:
#   qs_manager.sh close
#   qs_manager.sh toggle <widget> [arg]
#   qs_manager.sh open <widget> [arg]

# Full path first: callers reached through execDetached/Waybar don't always
# inherit the nix profile in PATH.
QS="$HOME/.nix-profile/bin/quickshell"
[ -x "$QS" ] || QS="$(command -v quickshell)"

if [ -z "$QS" ]; then
    echo "$0: quickshell not found" >&2
    exit 1
fi

CMD="${1:-}"
WIDGET="${2:-}"
ARG="${3:-}"

case "$CMD" in
    close)
        "$QS" msg main handleCommand close "" ""
        ;;
    toggle | open)
        if [ -z "$WIDGET" ]; then
            echo "usage: $0 $CMD <widget> [arg]" >&2
            exit 1
        fi
        "$QS" msg main handleCommand "$CMD" "$WIDGET" "$ARG"
        ;;
    *)
        echo "usage: $0 {close|toggle|open} [widget] [arg]" >&2
        exit 1
        ;;
esac
