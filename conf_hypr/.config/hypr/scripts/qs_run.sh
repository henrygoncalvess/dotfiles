#!/usr/bin/env bash

# start quickshell

mkdir -p "$HOME/.cache/quickshell/wallpaper_picker/thumbs"
mkdir -p "$HOME/.cache/quickshell/wallpaper_picker/search_thumbs"
mkdir -p "$HOME/.cache/quickshell/wallpaper_picker/colors_markers"

exec quickshell "$@"
