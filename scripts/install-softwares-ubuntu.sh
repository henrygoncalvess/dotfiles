#!/usr/bin/env bash
# Script de setup que faz download de softwares, temas icons etc.
# Autor: Henry

set -euo pipefail

DOWNLOAD_DIR="$HOME/Downloads"
THEMES_DIR="$HOME/.themes"
ICONS_DIR="$HOME/.icons"
CONFIG_DIR="$HOME/.config"
PROFILE_DIR=$(find "$HOME/.mozilla/firefox" -maxdepth 1 -type d -name "*.default-release" | head -n 1)

PROGRAMS=(git python3 python3-pip python3-venv wget make ripgrep stow xclip)

NVM_URL="https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh"
WHITESUR_URL="https://github.com/vinceliuice/WhiteSur-gtk-theme.git"
BIBATA_URL="https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz"

GIT_CONFIG_FILE="$HOME/.gitconfig"

mkdir -p "$DOWNLOAD_DIR" "$ICONS_DIR" "$THEMES_DIR" "$CONFIG_DIR" "$PROFILE_DIR"

on_error() {
  local code=$?
  echo -e "\n\033[1;31m[ERRO]\033[0m \033[33mFalha na execução (exit code: $code)\033[0m" >&2
}
trap 'on_error' ERR

pretty_log() {
  local TYPE=$1
  local LOG_NAME=$2
  local MESSAGE=$3
  local STATUS=$4
  local TAG=""

  case "$TYPE" in
    "-f") TAG="SOFTWARE" ;;
    "-p") TAG="PACOTE" ;;
    "-t") TAG="TEMA    " ;;
    "-c") TAG="CURSOR  " ;;
    "-e") TAG="ERRO    " ;;
  esac

  if [[ "$TAG" == "[ERRO]" ]]; then
    STATUS="error"
  fi
  
  case "$STATUS" in
    success)
      echo -e "\n\033[1;36m$TAG\033[0m  \033[1m$LOG_NAME\033[0m\n\t   \033[3;32m$MESSAGE!\033[0m"
      ;;
    info)
      echo -e "\n\033[1;36m$TAG\033[0m  \033[1m$LOG_NAME\033[0m\n\t   \033[33m$MESSAGE...\033[0m"
      ;;
    error)
      echo -e "\n\033[1;31m$TAG\033[0m  \033[1m$LOG_NAME\033[0m\n\t   \033[33m$MESSAGE\033[0m" >&2
      ;;
  esac
}

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
  local NAME=$1
  local LOG=$2
  local COMMAND=""

  case "$NAME" in
    ripgrep) COMMAND="rg" ;;
    python3-pip) COMMAND="pip3" ;;
    *) COMMAND="$NAME" ;;
  esac

  if command -v "$COMMAND" &> /dev/null; then
    pretty_log -f "$LOG" "Já instalado" success
    return 0
  else
    return 1
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

install_ohmyposh() {
  local LOG="[Oh_My_Posh-download]"

  if check_command oh-my-posh "$LOG"; then
    return 0
  fi

  pretty_log -f "$LOG" "Instalando Oh My Posh" info
  curl -s https://ohmyposh.dev/install.sh | bash -s
  
  if fc-list | grep -qi "Nerd Font" | grep -qi "Hasklig"; then
   pretty_log -f "$LOG" "Nerd Font Hasklug já instalada" success
  fi

  pretty_log -f "$LOG" "Instalando Nerd Font Hasklug" info
  oh-my-posh font install Hasklig

  pretty_log -f "$LOG" "Instalado com sucesso! Abra um novo terminal para aplicar as configurações do perfil" success
}

install_firefox() {
  local LOG="[Firefox-download]"

  config_firefox() {
    mkdir -p "$PROFILE_DIR/chrome"

    cat > "$PROFILE_DIR/user.js" <<EOF
/* Customização via CSS (userChrome/userContent) */
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

/* Ativar tema escuro */
user_pref("ui.systemUsesDarkTheme", 1);

/* Fonte */
user_pref("font.name.sans-serif.x-western", "Hasklug Nerd Font Propo");
user_pref("font.name.monospace.x-western", "Hasklug Nerd Font Propo");
user_pref("font.minimum-size.th", 13);
user_pref("font.size.variable.x-western", 13);
user_pref("font.size.fixed.x-western", 13);
user_pref("browser.display.use_document_fonts", 1);

/* Preferências gerais */
user_pref("browser.download.useDownloadDir", false);
user_pref("browser.download.deletePrivate", true);
user_pref("browser.download.deletePrivate.chosen", true);
user_pref("browser.tabs.groups.smart.userEnabled", false);
user_pref("browser.tabs.hoverPreview.showThumbnails", false);
user_pref("accessibility.typeaheadfind", true);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);
user_pref("browser.ctrlTab.sortByRecentlyUsed", true);
user_pref("general.autoScroll", true);
user_pref("general.smoothScroll", true);
user_pref("signon.rememberSignons", false);
user_pref("privacy.globalprivacycontrol.enabled", true);
user_pref("privacy.globalprivacycontrol.was_ever_enabled", true);
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);

/* Restaurar abas da sessão anterior */
user_pref("browser.startup.page", 3);

/* Desativar recomendações */
user_pref("browser.newtabpage.activity-stream.feeds.recommendationprovider", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.newtabpage.activity-stream.showSearch", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.suggest.bookmark", false);
user_pref("browser.urlbar.suggest.searches", false);
EOF

    pretty_log -f "[Firefox-config]" "Firefox configurado com sucesso" success
  }

  if check_command firefox "$LOG"; then
    config_firefox
    return 0
  fi

  pretty_log -f "$LOG" "Criando diretório para armazenar chaves do repositório APT" info
  sudo install -m 0755 -d /etc/apt/keyrings

  pretty_log -f "$LOG" "Importando a chave de assinatura do repositório Mozilla" info
  wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null

  pretty_log -f "$LOG" "Verificando a impressão da chave" info
  gpg -n -q --import --import-options import-show /etc/apt/keyrings/packages.mozilla.org.asc | awk '/pub/{getline; gsub(/^ +| +$/,""); if($0 == "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3") print "\nThe key fingerprint matches ("$0").\n"; else print "\nVerification failed: the fingerprint ("$0") does not match the expected one.\n"}'

  pretty_log -f "$LOG" "Adicionando repositório oficial da Mozilla" info

  if ! grep -q "packages.mozilla.org" /etc/apt/sources.list.d/mozilla.list 2>/dev/null; then
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null
  fi

  pretty_log -f "$LOG" "Configurando APT para dar prioridade aos pacotes da Mozilla" info
  echo '
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
' | sudo tee /etc/apt/preferences.d/mozilla

  pretty_log -f "$LOG" "Atualizando pacotes e instalando Firefox" info
  sudo apt-get install firefox

  pretty_log -f "$LOG" "Firefox instalado com sucesso" success

  if [[ -z "$PROFILE_DIR" ]]; then
    pretty_log -f "$LOG" "Abra o Firefox uma vez antes de rodar o script de configuração" error
    return 1
  fi

  config_firefox
}

install_docker() {
  local LOG="[Docker-download]"

  if check_command docker "$LOG"; then                
    return 0
  fi

  pretty_log -f "$LOG" "Instalando dependências do Docker" info
  sudo apt-get install -y ca-certificates curl

  pretty_log -f "$LOG" "Adicionando chave GPG oficial do Docker" info
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  pretty_log -f "$LOG" "Adicionando repositório oficial do Docker" info

  if ! grep -q "docker" /etc/apt/sources.list.d/docker.list 2>/dev/null; then
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  fi

  pretty_log -f "$LOG" "Atualizando pacotes e instalando Docker" info
  sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
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

  if check_command node "$LOG"; then
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

install_cargo() {
  local LOG="[Cargo-download]"

  if check_command cargo "$LOG"; then
    return 0
  fi
  
  pretty_log -f "$LOG" "Instalando Cargo" info
  curl https://sh.rustup.rs -sSf | sh
  \. "$HOME/.cargo/env"

  pretty_log -f "$LOG" "Instalado com sucesso. Abra um novo terminal para aplicar as modificações" success
}

install_packages(){
  local NPM=(prettier)

  if ! command -v npm &>/dev/null; then
    pretty_log -p "[Node.js]" "npm não encontrado. Abra um novo terminal e execute o script novamente" error
    return 1
  fi

  pretty_log -p "[Node.js]" "Instalando dependências" info
  for package in "${NPM[@]}"; do
    pretty_log -p "[$package-download]" "" info
    npm install -g "$package"
    pretty_log -p "[$package-download]" "Dependência instalada" success
  done
}

install_nvim() {
  local LOG="[Neovim-download]"
  
  if check_command nvim "$LOG"; then
    return 0
  fi

  pretty_log -f "$LOG" "Adicionando repositório" info
  sudo add-apt-repository ppa:neovim-ppa/stable -y

  pretty_log -f "$LOG" "Atualizando pacotes e instalando Neovim" info
  sudo apt update
  sudo apt install neovim -y

  pretty_log -f "$LOG" "Instalado com sucesso" success
}

install_lunarvim() {
  local LOG="[LunarVim-download]"
  
  if check_command lvim "$LOG"; then
    return 0
  fi

  pretty_log -f "$LOG" "Instalando Lunar Vim" info
  LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh)

  pretty_log -f "$LOG" "Instalado com sucesso" success
}

install_kitty() {
  local LOG="[Kitty-download]"

  config_kitty() {
    if ! grep -q 'add_to_path "$HOME/.local/kitty.app/bin"' "$HOME/.bashrc"; then
      pretty_log -f "$LOG" "Adicionando Kitty ao PATH" info
      sed '0,/add_to_path .*/s//&\
      add_to_path "$HOME/.local/kitty.app/bin"' .bashrc

      pretty_log -f "$LOG" "Adiocionado com sucesso" info
    fi
  }
  
  if check_command kitty "$LOG"; then
    config_kitty
    return 0
  fi

  pretty_log -f "$LOG" "Instalando Kitty" info
  curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin

  pretty_log -f "$LOG" "Instalado com sucesso" success
  config_kitty
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

  pretty_log -c "$LOG" "Baixando arquivo em: $DEST_FILE" info
  curl -fL --retry 3 --retry-delay 5 --progress-bar "$BIBATA_URL" -o "$DEST_FILE"

  pretty_log -c "$LOG" "Download concluído" success
  pretty_log -c "$LOG" "Extraindo conteúdo para: $DEST_DIR" info
  tar -xf "$DEST_FILE" -C "$ICONS_DIR"

  pretty_log -c "$LOG" "Arquivo extraído! Cursor Instalado com sucesso" success
  pretty_log -c "$LOG" "Removendo $DEST_FILE" info
  rm -f "$DEST_FILE"

  pretty_log -c "$LOG" "Arquivo removido" success
}

echo -e "\n\033[1;33m[INFO] ---Iniciando instalação de PROGRAMAS---\033[0m\n"

echo -e "\033[1;33m[apt-get update]\033[0m\n"
sudo apt-get update

install_ohmyposh

install_firefox

for prog in "${PROGRAMS[@]}"; do
  case "$prog" in
    git)
      if check -f -f "[$prog-download]" "$GIT_CONFIG_FILE"; then
        pretty_log -f "[git-config]" "Git configurado com sucesso" success
        continue
      fi

      pretty_log -f "[$prog-download]" "Já instalado" success

      pretty_log -f "[$prog-config]" "Configurando $prog: $GIT_CONFIG_FILE  " info
      cat > "$GIT_CONFIG_FILE" << EOF
[user]
  name = henrygoncalvess
  email = octanebt@gmail.com

[init]
  defaultBranch = main

[core]
  editor = code --wait
EOF

      pretty_log -f "[$prog-config]" "Configurado com sucesso" success
      continue
      ;;
    *)
      install_program_apt "$prog"
      ;;
  esac
done

install_nvm

install_node

install_cargo

install_packages

install_nvim

install_lunarvim

install_kitty

install_docker
echo -e "\n"

echo -e "\033[1;33m[INFO] ---Iniciando instalação de TEMAS E CURSORES---\033[0m"

install_whitesur

install_bibata
echo -e "\n"

exit 0
