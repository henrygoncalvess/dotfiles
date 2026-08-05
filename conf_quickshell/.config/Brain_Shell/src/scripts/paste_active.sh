#!/usr/bin/env bash
# Paste the clipboard into the window that had focus before a Brain_Shell popup
# opened. Used by the emoji picker and by the clipboard popup's double tap.
#
# Two strategies, best first:
#
#   wtype        types the text through a virtual keyboard. Independent of the
#                app's own paste binding, so it works everywhere — but it is a
#                separate package (`pacman -S wtype`).
#   sendshortcut Hyprland presses the paste shortcut for us. Needs no extra
#                package, but depends on the app's binding, which is
#                Ctrl+Shift+V in terminals and Ctrl+V everywhere else.
#
# The leading delay lets the popup drop its exclusive keyboard focus first,
# otherwise the keystroke lands on the layer surface instead of the window.

set -u

sleep "${1:-0.35}"

if command -v wtype >/dev/null 2>&1; then
    wl-paste -n | wtype -
    exit
fi

class=$(hyprctl activewindow -j 2>/dev/null | grep -oP '"class"\s*:\s*"\K[^"]*' | head -1)

case "${class,,}" in
    *term*|kitty|foot|alacritty|konsole|com.mitchellh.ghostty|org.wezfurlong.wezterm)
        combo="CTRL SHIFT, V" ;;
    *)
        combo="CTRL, V" ;;
esac

hyprctl dispatch sendshortcut "$combo, activewindow" >/dev/null
