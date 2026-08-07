#!/usr/bin/env bash

# Turn the window transparency configured in looknfeel.conf on and off.
#
# Rides on Omarchy's permanent-flag mechanism: hyprland.conf sources
# ~/.local/state/omarchy/toggles/hypr/*.conf *after* our own looknfeel.conf, so
# copying the flag in there overrides the opacities and the choice survives
# hyprctl reload, theme switches and reboots. Removing it falls back to the
# configured values, since a reload re-reads looknfeel.conf.
#
# Usage: toggle-transparency.sh [toggle|on|off|status]

set -uo pipefail

FLAG_NAME="opaque-windows"
FLAG_SOURCE="$HOME/.config/hypr/toggles/$FLAG_NAME.conf"
FLAG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/hypr"
FLAG="$FLAG_DIR/$FLAG_NAME.conf"

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send -u low "$1"
  return 0
}

enable_transparency() {
  rm -f "$FLAG"
  hyprctl reload >/dev/null
  notify "Window transparency: on"
}

disable_transparency() {
  if [[ ! -f $FLAG_SOURCE ]]; then
    echo "Missing flag template: $FLAG_SOURCE" >&2
    exit 1
  fi

  mkdir -p "$FLAG_DIR"
  cp "$FLAG_SOURCE" "$FLAG"
  hyprctl reload >/dev/null
  notify "Window transparency: off"
}

case "${1:-toggle}" in
on)
  enable_transparency
  ;;
off)
  disable_transparency
  ;;
status)
  if [[ -f $FLAG ]]; then echo "off"; else echo "on"; fi
  ;;
toggle)
  if [[ -f $FLAG ]]; then enable_transparency; else disable_transparency; fi
  ;;
*)
  echo "Usage: ${0##*/} [toggle|on|off|status]" >&2
  exit 1
  ;;
esac
