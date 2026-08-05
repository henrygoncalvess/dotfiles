#!/usr/bin/env bash

WALLPAPERS_DIR="$HOME/wallpapers/desktop/SPKyjw9HRTImK90/8mWeerfxH3HwuPa/jOsyc1nZGsaPUXw"
QS_CACHE="$HOME/.cache/quickshell/wallpaper_picker"
RELOAD_SCRIPT="$HOME/.config/quickshell/wallpaper/matugen_reload.sh"

# Kill other instances of this script safely
pgrep -f "random-paper-hypr.sh" | grep -v $$ | xargs -r kill -9 2>/dev/null
sleep 0.3

# Wait for awww-daemon to be ready
while ! awww query &>/dev/null; do
  sleep 0.5
done

# Omarchy (the theme's base) might start swaybg a bit late, so let's kill it aggressively
# to ensure it doesn't cover awww's wallpaper.
for i in {1..10}; do
  killall swaybg 2>/dev/null
  sleep 0.5
done &

apply_wallpaper() {
  local PIC="$1"
  local STEP=$(shuf -i 1-90 -n 1)
  
  # Copy to Quickshell's expected current wallpaper location (only if it's a new random one)
  mkdir -p "$QS_CACHE"
  if [ "$PIC" != "$QS_CACHE/current_wallpaper.png" ]; then
      cp "$PIC" "$QS_CACHE/current_wallpaper.png" 2>/dev/null || true
  fi

  awww img "$PIC" --transition-duration 3 --transition-fps 60 --transition-type any --transition-step $STEP

  # Apply matugen colors and reload quickshell
  if command -v matugen &>/dev/null; then
    ( matugen image "$PIC" || true; bash "$RELOAD_SCRIPT" || true ) &
  fi
}

pick_random() {
  find "$WALLPAPERS_DIR" -type f 2>/dev/null | shuf -n 1 --random-source=/dev/random
}

# 1. No login sempre entra um wallpaper aleatório.
PIC=$(pick_random)
if [ -z "$PIC" ]; then
  echo "Nenhum wallpaper encontrado em $WALLPAPERS_DIR" >&2
  exit 1
fi
apply_wallpaper "$PIC"

# 2. Depois disso, rotaciona a cada INTERVAL segundos.
#    300 = 5 min, 600 = 10 min, 1800 = 30 min. INTERVAL=0 desliga a rotação e
#    deixa só o sorteio do login.
INTERVAL=1800

[ "$INTERVAL" -le 0 ] && exit 0

# O wallpaper picker do Quickshell também escreve em current_wallpaper.png
# quando você escolhe algo a dedo. Guardamos uma cópia do que ESTE script
# aplicou: se na próxima volta o arquivo não bater mais, foi você que trocou —
# aí a rotação para e a sua escolha fica. Volta a sortear no próximo login.
MARKER="$QS_CACHE/.random_paper_marker"
cp "$PIC" "$MARKER" 2>/dev/null || true

while true; do
  sleep "$INTERVAL"

  if ! cmp -s "$QS_CACHE/current_wallpaper.png" "$MARKER"; then
    echo "wallpaper trocado manualmente — rotação automática desligada até o próximo login"
    rm -f "$MARKER"
    exit 0
  fi

  # Evita sortear o mesmo de novo quando há mais de uma opção.
  for _ in 1 2 3; do
    NEXT=$(pick_random)
    [ "$NEXT" != "$PIC" ] && break
  done

  if [ -n "$NEXT" ]; then
    PIC="$NEXT"
    apply_wallpaper "$PIC"
    cp "$PIC" "$MARKER" 2>/dev/null || true
  fi
done
