#!/usr/bin/env bash
# Script de setup que faz download de softwares, temas icons etc.
# Autor: Henry

set -euo pipefail

DOWNLOAD_DIR="$HOME/Downloads"
THEMES_DIR="$HOME/.themes"
ICONS_DIR="$HOME/.icons"

PROGRAMS=(git neovim python3 python3-pip)

NVM_URL="https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh"
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
    "-f") TAG="SOFTWARE" ;;
    "-t") TAG="TEMA    " ;;
    "-i") TAG="ICON    " ;;
    "-c") TAG="CURSOR  " ;;
    "-e") TAG="ERRO    " ;;
  esac

  if [[ "$TAG" == "[ERRO]" ]]; then
    STATUS="error"
  fi
  
  case "$STATUS" in
    success)
      echo -e "\033[1;36m$TAG\033[0m  \033[1m$LOG_NAME\033[0m\n\t   \033[3;32m$MESSAGE!\033[0m"
      ;;
    info)
      echo -e "\033[1;36m$TAG\033[0m  \033[1m$LOG_NAME\033[0m\n\t   \033[33m$MESSAGE...\033[0m"
      ;;
    error)
      echo -e "\033[1;31m$TAG\033[0m  \033[1m$LOG_NAME\033[0m\n\t   \033[33m$MESSAGE\033[0m" >&2
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
        pretty_log "$LOG_TYPE" "$LOG_NAME" "Já instalado" success
        return 0
      fi
      return 1
      ;;
    "-f")
      if [[ -f "$DESTINATION" ]]; then
        pretty_log "$LOG_TYPE" "$LOG_NAME" "Já instalado" success
        return 0
      fi
      return 1
      ;;
  esac
}

check_command() {
  local COMMAND=$1
  local LOG=$2

  if command -v "$COMMAND" &> /dev/null; then
    pretty_log -f "$LOG" "Já instalado" success
    return 0
  fi
}

install_program_apt() {
  local NAME=$1
  local LOG="[$NAME-download]"

  if check_command "$NAME" "$LOG"; then
    return 0
  fi

  pretty_log -f "$LOG" "Instalando via apt" info
  
  if sudo apt-get install -y "$NAME"; then
    pretty_log -f "$LOG" "Instalado com sucesso" success
    return 0
  else
    pretty_log -e "$LOG" "Falha ao instalar $NAME" error
    return 1
  fi
}

install_docker() {
  local LOG="[Docker-download]"

  if check_command "docker" "$LOG"; then                
    return 0
  fi

  pretty_log -f "$LOG" "Instalando dependências do Docker" info

  sudo apt-get install -y ca-certificates curl
  pretty_log -f "$LOG" "Adicionando chave GPG oficial do Docker" info

  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  pretty_log -f "$LOG" "Adicionando repositório oficial do Docker" info

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  pretty_log -f "$LOG" "Atualizando pacotes e instalando Docker" info

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  docker --version
  docker compose version
  pretty_log -f "$LOG" "Docker instalado com sucesso" success
}

install_nvm() {
  local LOG="[nvm-download]"

  if [[ -d "$HOME/.nvm" ]]; then
    pretty_log -f "$LOG" "Já instalado" success
    return 0
  fi

  pretty_log -f "$LOG" "Instalando nvm" info

  curl -so- "$NVM_URL" | bash
  \. "$HOME/.nvm/nvm.sh"
  pretty_log -f "$LOG" "Instalado com sucesso! abra um novo terminal para utilizar o nvm." success
}

install_node() {
  local LOG="[Node-download]"

  if check_command "node" "$LOG"; then
    return 0
  fi

  if command -v nvm &> /dev/null; then
    pretty_log -f "$LOG" "Instalando Node" info

    nvm install --lts
    pretty_log -f "$LOG" "Instalado com sucesso" success
    return 0
  fi

  pretty_log -f "$LOG" "Abra um novo terminal para instalar o node com nvm." info
}

install_whitesur() {
  local LOG="[WhiteSur-download]"
  local DEST_DIR="$THEMES_DIR/WhiteSur-gtk-theme"

  if [[ ! -f "$DEST_DIR/install.sh" ]]; then
    pretty_log -t "$LOG" "Clonando repositório" info

    git clone --filter=blob:none --no-checkout https://github.com/vinceliuice/WhiteSur-gtk-theme.git "$DEST_DIR"
    cd "$DEST_DIR"
    git sparse-checkout init --cone
    git sparse-checkout set libs src other
    git checkout 
  fi

  if check -d -t "$LOG" "$THEMES_DIR/WhiteSur-Dark-blue/gnome-shell"; then
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
  local LOG="[Bibata-download]"
  local DEST_FILE="$DOWNLOAD_DIR/Bibata-Modern-Ice.tar.xz"
  local DEST_DIR="$ICONS_DIR/Bibata-Modern-Ice"

  if check -d -c "$LOG" "$DEST_DIR"; then
    return 0
  fi

  pretty_log -c "${LOG}" "Baixando arquivo em: $DEST_FILE" info

  curl -fL --retry 3 --retry-delay 5 --progress-bar "$BIBATA_URL" -o "$DEST_FILE"
  pretty_log -c "${LOG}" "Download concluído" success
  pretty_log -c "${LOG}" "Extraindo conteúdo para: $DEST_DIR" info

  tar -xf "$DEST_FILE" -C "$ICONS_DIR"

  pretty_log -c "${LOG}" "Arquivo extraído! Cursor Instalado com sucesso" success
  pretty_log -c "${LOG}" "Removendo $DEST_FILE" info
  rm -f "$DEST_FILE"
  pretty_log -c "${LOG}" "Arquivo removido" success
}

echo -e "\n\033[1;33m[INFO] ---Iniciando instalação de PROGRAMAS---\033[0m\n"

echo -e "\n\033[1;33m[apt-get update]\033[0m\n"
sudo apt-get update
echo -e "\n"

install_docker
echo -e "\n"

for prog in "${PROGRAMS[@]}"; do
  case "$prog" in
    neovim)
      if check_command "nvim" "[$prog-download]"; then                
        echo -e "\n"
        continue
      fi   
      ;;
    python3-pip)
      if check_command "pip" "[$prog-download]"; then
        echo -e "\n"
        continue
      fi
      ;;
    *)
      install_program_apt "$prog"
      echo -e "\n"
      ;;
  esac
done

install_nvm
echo -e "\n"

install_node
echo -e "\n"

echo -e "\033[1;33m[INFO] ---Iniciando instalação de TEMAS E ÍCONES---\033[0m\n"

install_whitesur
echo -e "\n"

install_bibata

exit 0
