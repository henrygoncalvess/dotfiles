#!/usr/bin/env bash

PROCESS_NAME_HIDDEN="hidden-random-paper-hypr.sh"

start_script() {
  local script_path=$1
  exec "$script_path"
}

stop_other() {
  local random_paper_script=$(ps aux | grep "random-paper-hypr.sh" | grep -v "$$" | awk '{print $2}' | xargs kill -9 2>/dev/null)
  sleep 0.3
}

dir="$HOME/.config/rofi/scripts/wifi"
password=$(rofi -dmenu -p "Password" -password -mesg "Enter the password" -theme "$dir/password.rasi")

if [[ ! "$password" == "rosesareredvioletsareblue" ]]; then
  exit 1
fi

stop_other
start_script "$HOME/.config/hypr/scripts/$PROCESS_NAME_HIDDEN"
