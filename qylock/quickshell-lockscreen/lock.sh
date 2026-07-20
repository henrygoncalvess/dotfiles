#!/usr/bin/env bash

# Current directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set library paths
export QML2_IMPORT_PATH="$DIR/imports:$QML2_IMPORT_PATH"
export QML_XHR_ALLOW_FILE_READ=1

# Get session type
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-$(loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Type --value 2>/dev/null || echo wayland)}"

# User theme preference
if [ -n "$1" ]; then
    export QS_THEME="$1"
else
    # Randomly select a theme from the themes directory
    THEMES_DIR="$DIR/../themes"
    [ ! -d "$THEMES_DIR" ] && THEMES_DIR="$DIR/themes_link"
    
    THEMES=($(ls -1 "$THEMES_DIR"))
    export QS_THEME="${THEMES[$RANDOM % ${#THEMES[@]}]}"
fi

# Set theme path
if [ -d "$DIR/../themes" ] && [ ! -d "$DIR/themes_link" ]; then
    export QS_THEME_PATH="$DIR/../themes/$QS_THEME"
else
    export QS_THEME_PATH="$DIR/themes_link/$QS_THEME"
fi

echo "Locking with Quickshell using theme: $QS_THEME"
echo "Theme path: $QS_THEME_PATH"

# Kill active lockers
killall -9 hyprlock swaylock wlogout 2>/dev/null || true

# Execute lock screen
quickshell -p "$DIR/lock_shell.qml"
