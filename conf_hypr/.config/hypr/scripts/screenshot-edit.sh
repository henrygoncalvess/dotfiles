#!/usr/bin/env bash

# Grab a screenshot and hand it straight to the annotation editor.
#
# omarchy-capture-screenshot in "save" mode does the hard part (hyprpicker
# freeze, slurp selection with window/monitor snapping) and prints the file it
# wrote; the notification-and-click dance of its default mode is what we skip
# here, since the whole point is to land in the editor right away.
#
# Windows are forced opaque for the duration of the capture. Measured on this
# setup, shooting through the configured transparency costs ~17% of the local
# contrast (stddev 6.52 vs 7.66) because the wallpaper bleeds through the window
# and blur:brightness dims it — text ends up sitting on a mottled background.
# The override goes through `hyprctl keyword` rather than the toggle flag, so
# there is no config reload, and it is reverted before the editor opens.
#
# Usage: screenshot-edit.sh [smart|region|windows|fullscreen]

set -uo pipefail

MODE="${1:-smart}"
EDITOR_BIN="${OMARCHY_SCREENSHOT_EDITOR:-satty}"

# Launched from the Quickshell bar, i.e. from a systemd --user unit, so don't
# assume the login shell's PATH.
export PATH="$HOME/.local/share/omarchy/bin:$PATH"

# A second run while a selection is on screen means "cancel". Handle that here,
# before touching any compositor state: otherwise this run would save the
# already-overridden opacity as if it were the user's setting and restore 1.0
# for good, leaving transparency permanently off.
if pgrep -x slurp >/dev/null 2>&1; then
  pkill -x slurp
  exit 0
fi

SAVED_ACTIVE=""
SAVED_INACTIVE=""

restore_opacity() {
  [[ -n $SAVED_ACTIVE && -n $SAVED_INACTIVE ]] || return 0
  hyprctl --batch "keyword decoration:active_opacity $SAVED_ACTIVE ; \
                   keyword decoration:inactive_opacity $SAVED_INACTIVE" >/dev/null 2>&1
  # Make this idempotent: it runs explicitly before the editor exec (which would
  # skip the trap) and again from the trap on any early exit.
  SAVED_ACTIVE=""
  SAVED_INACTIVE=""
}
trap restore_opacity EXIT INT TERM

if command -v hyprctl >/dev/null 2>&1; then
  SAVED_ACTIVE="$(hyprctl getoption decoration:active_opacity -j | jq -r '.float')"
  SAVED_INACTIVE="$(hyprctl getoption decoration:inactive_opacity -j | jq -r '.float')"

  if [[ $SAVED_ACTIVE =~ ^[0-9.]+$ && $SAVED_INACTIVE =~ ^[0-9.]+$ ]]; then
    hyprctl --batch "keyword decoration:active_opacity 1.0 ; \
                     keyword decoration:inactive_opacity 1.0" >/dev/null 2>&1
    # Let the compositor draw one opaque frame before hyprpicker freezes it.
    sleep 0.15
  else
    SAVED_ACTIVE=""
    SAVED_INACTIVE=""
  fi
fi

FILEPATH="$(omarchy-capture-screenshot "$MODE" save | tail -n1)"

restore_opacity

# Empty when the selection was cancelled.
[[ -n $FILEPATH && -f $FILEPATH ]] || exit 0

case "$EDITOR_BIN" in
satty)
  exec satty --filename "$FILEPATH" \
    --output-filename "$FILEPATH" \
    --actions-on-enter save-to-clipboard \
    --save-after-copy \
    --copy-command 'wl-copy'
  ;;
swappy)
  exec swappy -f "$FILEPATH"
  ;;
*)
  exec "$EDITOR_BIN" "$FILEPATH"
  ;;
esac
