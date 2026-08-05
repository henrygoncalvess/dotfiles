#!/usr/bin/env bash

# start quickshell

mkdir -p "$HOME/.cache/quickshell/wallpaper_picker/thumbs"
mkdir -p "$HOME/.cache/quickshell/wallpaper_picker/search_thumbs"
mkdir -p "$HOME/.cache/quickshell/wallpaper_picker/colors_markers"

# O Brain_Shell é o daemon de notificação; qualquer outro que já tenha pego o
# nome org.freedesktop.Notifications no D-Bus precisa sair antes.
# O laço em background existe porque o autostart do Omarchy sobe o mako depois
# de nós — matar só uma vez aqui não pega esse caso.
killall mako dunst swaync 2>/dev/null || true
(
  for _ in $(seq 1 10); do
    sleep 0.5
    killall mako dunst swaync 2>/dev/null || true
  done
) &

exec quickshell "$@"
