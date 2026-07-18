#!/usr/bin/env bash

# Current directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set library paths
export QML2_IMPORT_PATH="$DIR/imports:$QML2_IMPORT_PATH"
export QML_XHR_ALLOW_FILE_READ=1

# Os temas importam Qt5Compat.GraphicalEffects + QtMultimedia + QtSvg, que NAO estao
# no QML path do quickshell generico (sem isso o tema falha ao carregar -> tela preta).
# nix : reusa os paths exatos do store que o wrapper do flake (qylock-lock) resolve.
# arch: usa o diretorio qml padrao do qt6 (pacote qt6-5compat/qt6-multimedia/qt6-svg).
if command -v qylock-lock >/dev/null 2>&1; then
    _ql="$(command -v qylock-lock)"
    # Usa o qt5compat/multimedia/svg E o quickshell que o flake do qylock empacota: sao
    # buildados contra o MESMO Qt, entao o plugin GraphicalEffects carrega. Misturar esse
    # qt5compat com um quickshell buildado diferente da erro "plugin uses incompatible Qt
    # library" (tela preta). Por isso o quickshell do qylock entra no PATH na frente.
    for _p in $(grep -oE "/nix/store/[^']+/lib/qt-6/qml" "$_ql" | sort -u); do
        QML2_IMPORT_PATH="$_p:$QML2_IMPORT_PATH"
    done
    _qs=$(grep -oE "/nix/store/[^']+-quickshell-[^/']*/bin" "$_ql" | head -1)
    [ -n "$_qs" ] && export PATH="$_qs:$PATH"
    # Backend de video (ffmpeg/gstreamer) do QtMultimedia: sem o dir de plugins no
    # QT_PLUGIN_PATH da "QVideoSink Not available" e o fundo de video fica preto.
    _qtmm=$(grep -oE "/nix/store/[^']+-qtmultimedia-[^/']*" "$_ql" | head -1)
    [ -n "$_qtmm" ] && export QT_PLUGIN_PATH="$_qtmm/lib/qt-6/plugins:$QT_PLUGIN_PATH"
else
    for _d in /usr/lib/qt6/qml /usr/lib/qt/qml /usr/lib64/qt6/qml; do
        [ -d "$_d/Qt5Compat" ] && { QML2_IMPORT_PATH="$_d:$QML2_IMPORT_PATH"; break; }
    done
fi
export QML2_IMPORT_PATH QML_IMPORT_PATH="$QML2_IMPORT_PATH"

# Get session type
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-$(loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Type --value 2>/dev/null || echo wayland)}"

# Parse arguments
if [[ "$1" == "--test" ]]; then
    export QS_TESTING=1
    export XDG_SESSION_TYPE=x11
    shift
fi

# User theme preference
# Get user theme
CONFIG_FILE="$HOME/.config/qylock/theme"
if [ -n "$1" ]; then
    export QS_THEME="$1"
elif [ -f "$CONFIG_FILE" ]; then
    THEME_CFG=$(cat "$CONFIG_FILE")
    if [ "$THEME_CFG" = "random" ]; then
        THEMES=("dog-samurai" "pixel-hollowknight" "winter" "sword" "star-rail" "Genshin" "wuwa" "terraria")
        export QS_THEME="${THEMES[$RANDOM % ${#THEMES[@]}]}"
    else
        export QS_THEME="$THEME_CFG"
    fi
else
    export QS_THEME="nier-automata"
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
if command -v nixGLIntel &> /dev/null; then
    nixGLIntel quickshell -p "$DIR/lock_shell.qml"
else
    quickshell -p "$DIR/lock_shell.qml"
fi
