#!/usr/bin/env bash
# Starts or stops qs-vpets according to the $vpets flag in autostart.conf.
#
# Called from `exec` (not exec-once), so it runs again on every `hyprctl
# reload`: flip the flag to 0 and reload to dismiss the pets, flip it back
# to 1 and reload to bring them back, without restarting the session.
#
# pgrep/pkill need -x alongside -f: without it the pattern also matches the
# `sh -c` wrapper Hyprland spawns (its command line contains the pattern),
# which would kill that shell before it ever launches qs.

set -u

PROJECT="$HOME/.local/share/qs/qs-vpets"
PATTERN="qs -p $PROJECT"

if [[ "${1:-1}" == "1" ]]; then
  # the || only fires when no instance is alive, so a reload neither
  # duplicates the pets nor restarts a session that is already fine
  pgrep -x -f "$PATTERN" >/dev/null || exec qs -p "$PROJECT"
else
  pkill -x -f "$PATTERN"
fi