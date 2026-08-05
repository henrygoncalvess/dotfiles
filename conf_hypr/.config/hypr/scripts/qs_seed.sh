#!/usr/bin/env bash
# Pre-seed the files Brain_Shell reads at startup so its FileViews don't log
# "file does not exist" on a cold boot. matugen rewrites colors.json a moment
# later (onFileChanged reloads it); this just kills the startup race/error.
#
# Run as ExecStartPre of brainshell.service. Safe to run repeatedly.
set -eu

ud="$HOME/.config/Brain_Shell/src/user_data"
mkdir -p "$ud"
[ -f "$ud/config_Provider.json" ] || printf '{"configProvider":"hyprlang"}\n' >"$ud/config_Provider.json"

cache="$HOME/.cache/brain-shell"
mkdir -p "$cache"
if [ ! -f "$cache/colors.json" ]; then
  # Fallback palette — mirrors the defaults in src/theme/ColorLoader.qml.
  cat >"$cache/colors.json" <<'JSON'
{
    "background": "#1a282a",
    "active":     "#a6d0f7",
    "text":       "#cdd6f4",
    "subtext":    "#94e2d5",
    "border":     "#ffffff",
    "iconFont":   "#2f8d97"
}
JSON
fi

exit 0
