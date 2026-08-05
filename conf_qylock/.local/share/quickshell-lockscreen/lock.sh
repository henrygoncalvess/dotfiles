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

# Onde vivem os temas. Com o stow, themes_link aponta pra .dotfiles/qylock/themes.
if [ -d "$DIR/../themes" ] && [ ! -d "$DIR/themes_link" ]; then
    THEMES_DIR="$DIR/../themes"
else
    THEMES_DIR="$DIR/themes_link"
fi

# Temas que nao entram no sorteio aleatorio (continuam disponiveis se pedidos
# explicitamente por argumento ou pelo arquivo de config).
RANDOM_BLOCKLIST='^(osu|osumania)$'

# Lista os temas validos: precisam existir em disco E ter um Main.qml, senao o
# quickshell aborta no load e o Hyprland cai na tela de fallback dele.
list_themes() {
    local t
    for t in "$THEMES_DIR"/*/; do
        [ -f "$t/Main.qml" ] || continue
        basename "$t"
    done
}

random_theme() {
    local candidates
    mapfile -t candidates < <(list_themes | grep -vE "$RANDOM_BLOCKLIST")
    # Se a blocklist zerar tudo, sorteia entre todos em vez de devolver vazio.
    [ ${#candidates[@]} -eq 0 ] && mapfile -t candidates < <(list_themes)
    [ ${#candidates[@]} -eq 0 ] && return 1
    printf '%s' "${candidates[$RANDOM % ${#candidates[@]}]}"
}

# Preferencia de tema: argumento > ~/.config/qylock/theme > aleatorio.
CONFIG_FILE="$HOME/.config/qylock/theme"
if [ -n "$1" ]; then
    QS_THEME="$1"
elif [ -f "$CONFIG_FILE" ] && [ "$(cat "$CONFIG_FILE")" != "random" ]; then
    QS_THEME="$(cat "$CONFIG_FILE")"
else
    QS_THEME="$(random_theme)"
fi

# Um tema inexistente faz o quickshell morrer no boot e a sessao cair na tela de
# emergencia do Hyprland. Melhor sortear outro do que travar destrancado.
if [ ! -f "$THEMES_DIR/$QS_THEME/Main.qml" ]; then
    echo "Tema '$QS_THEME' nao encontrado em $THEMES_DIR — sorteando outro." >&2
    QS_THEME="$(random_theme)"
fi

if [ -z "$QS_THEME" ]; then
    echo "Nenhum tema valido em $THEMES_DIR — caindo pro hyprlock." >&2
    # O supervisor (system-lock.sh) so considera "usuario destravou" quando a
    # sentinela existe, e quem a escreve e o lock_shell.qml. O hyprlock nao a
    # conhece: sem escreve-la aqui, todo desbloqueio por este fallback era lido
    # como "o locker morreu" e a tela voltava a trancar na hora, uma vez por
    # tentativa do supervisor. Sai 0 so depois de autenticar de verdade.
    hyprlock
    rc=$?
    [ "$rc" -eq 0 ] && touch "${XDG_RUNTIME_DIR:-/tmp}/qylock-unlocked"
    exit "$rc"
fi

export QS_THEME
export QS_THEME_PATH="$THEMES_DIR/$QS_THEME"

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
