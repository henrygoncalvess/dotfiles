#!/usr/bin/env bash

dir="$HOME/.config/rofi/scripts/goanime"

anime_name=$(rofi -dmenu -mesg "Enter anime name" -theme "$dir/prompt.rasi")

if [ -n "$anime_name" ]; then
  kitty --class="goanime-float" -e goanime "$anime_name"
fi
