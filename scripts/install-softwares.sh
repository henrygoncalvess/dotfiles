#!/usr/bin/env bash
# Script de setup que faz download de softwares, temas icons etc.
# Autor: Henry

set -euo pipefail

DOWNLOAD_DIR="$HOME/Downloads"
THEMES_DIR="$HOME/.themes"
ICONS_DIR="$HOME/.icons"

WHITESUR_URL="https://github.com/vinceliuice/WhiteSur-gtk-theme.git"
BIBATA_URL="https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz"

mkdir -p "$DOWNLOAD_DIR" "$ICONS_DIR" "$THEMES_DIR"

pretty_log() {
  local TYPE=$1
  local LOG_NAME=$2
  local MESSAGE=$3
  local STATUS=$4
  local TAG=""

  case "$TYPE" in
    "-f") TAG="[SOFTWARE]" ;;
    "-t") TAG="[TEMA]" ;;
    "-i") TAG="[ICON]" ;;
    "-c") TAG="[CURSOR]" ;;
    "-e") TAG="[ERRO]" ;;
  esac

  if [[ "$TAG" == "[ERRO]" ]]; then
    STATUS="error"
  fi
  
  case "$STATUS" in
    success)
      echo -e "\033[1;36m$TAG\033[0m\n\t\033[1m$LOG_NAME\033[0m\n\t\033[3;32m$MESSAGE\033[0m"
      ;;
    info)
      echo -e "\033[1;36m$TAG\033[0m\n\t\033[1m$LOG_NAME\033[0m\n\t\033[33m$MESSAGE...\033[0m"
      ;;
    error)
      echo -e "\033[1;31m$TAG\033[0m \033[1m$LOG_NAME\033[0m\n\t\033[33m$MESSAGE\033[0m" >&2
      ;;
  esac
}

on_error() {
  local code=$?
  echo -e "\033[1;31m[ERRO]\033[0m \033[33mFalha na execução (exit code: $code)\033[0m" >&2
}
trap 'on_error' ERR

check() {
  local TYPE=$1
  local LOG_TYPE=$2
  local LOG_NAME=$3
  local DESTINATION=$4

  case "$TYPE" in
    "-d")
      if [[ -d "$DESTINATION" ]]; then
        pretty_log "$LOG_TYPE" "$LOG_NAME" "Já instalado!" success
        return 0
      fi
      return 1
      ;;
    "-f")
      if [[ -f "$DESTINATION" ]]; then
        pretty_log "$LOG_TYPE" "$LOG_NAME" "Já instalado!" success
        return 0
      fi
      return 1
      ;;
  esac
}

install_whitesur() {
  local LOG="[WhiteSur-Download]"
  local DEST_DIR="$THEMES_DIR/WhiteSur-gtk-theme"

  if [[ ! -f "$DEST_DIR/install.sh" ]]; then
    pretty_log -t "$LOG" "Clonando repositório" info

    git clone --filter=blob:none --no-checkout https://github.com/vinceliuice/WhiteSur-gtk-theme.git "$DEST_DIR"
    cd "$DEST_DIR"
    git sparse-checkout init --cone
    git sparse-checkout set libs src other
    git checkout 
  fi

  if check -d -t "$LOG" "$THEMES_DIR/WhiteSur-Dark-blue-nord/gnome-shell"; then
    return 0
  fi

  if [[ "$(pwd)" != "$DEST_DIR" ]]; then
    cd "$DEST_DIR"
  fi

  pretty_log -t "$LOG" "Instalando Tema" info

  ./install.sh -o normal -c dark -t blue -m -HD --shell -i apple -h smaller --round

  pretty_log -t "$LOG" "Instalado com sucesso" success
}

install_bibata() {
  local LOG="[Bibata-Download]"
  local DEST_FILE="$DOWNLOAD_DIR/Bibata-Modern-Ice.tar.xz"
  local DEST_DIR="$ICONS_DIR/Bibata-Modern-Ice"

  if check -d -c "$LOG" "$DEST_DIR"; then
    return 0
  fi

  pretty_log -c "${LOG}" "Baixando arquivo em: $DEST_FILE" info

  curl -fL --retry 3 --retry-delay 5 --progress-bar "$BIBATA_URL" -o "$DEST_FILE"
  pretty_log -c "${LOG}" "Download concluído com sucesso!" success
  pretty_log -c "${LOG}" "Extraindo conteúdo para: $DEST_DIR" info

  tar -xf "$DEST_FILE" -C "$ICONS_DIR"

  pretty_log -c "${LOG}" "Extraído com sucesso!" success
  pretty_log -c "${LOG}" "Removendo $DEST_FILE" info
  rm -f "$DEST_FILE"
  pretty_log -c "${LOG}" "Arquivo removido!" success
}

echo -e "\n\033[1;33m[INFO]\033[0m ---Iniciando instalação de PROGRAMAS---\n"



echo -e "\n\033[1;33m[INFO]\033[0m ---Iniciando instalação de TEMAS E ÍCONES---\n"

install_whitesur
echo -e "\n"
install_bibata

exit 0
