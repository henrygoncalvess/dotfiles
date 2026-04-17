#!/usr/bin/env bash

PROFILE_DIR=$(find "$HOME/.mozilla/firefox" -maxdepth 1 -type d -name "*.default-release" | head -n 1)

prettyPrint(){
    local ACTION="$1"
    local SILENCE="$2"

    echo -ne "\033[36m$ACTION\033[0m"

    for string in '|' '/' '-' '\'; do
      printf "\r\033[36m$ACTION %s\033[0m" "$string"
      sleep 0.1
    done

    printf "\r\033[36m$ACTION  \033[0m"

    if [[ "$SILENCE" != "-s" ]]; then
        echo -e "\n\033[3;32m\u2714 Importadas com sucesso!\033[0m\n"
        sleep 0.1
    else
        echo ""
        sleep 0.1
    fi
}

echo -e "\033[1;33m- - - - - - - - - - - - - - - - - - - -\033[0m\n"

echo -e "\033[1;33mCriando Symlinks com GNU Stow\033[0m\n"

# A matriz agora foca na raiz do VS Code para evitar a travessia de symlinks.
CONF_TARGETS=(
  "$PROFILE_DIR/chrome"
  "$HOME/.config/Code"
  "$HOME/.config/kitty"
  "$HOME/.config/lvim"
  "$HOME/.config/oh_my_posh_config"
  "$HOME/.config/waybar"
  "$HOME/.config/rofi"
  "$HOME/.config/pip"
  "$HOME/.config/hypr"
  "$HOME/.config/dunst"
  "$HOME/.bashrc"
  "$HOME/.zshrc"
  "$HOME/.gitconfig"
)

echo -e "\033[1;33mRemovendo arquivos existentes para evitar conflitos\033[0m\n"
for target in "${CONF_TARGETS[@]}"; do
  if [ -e "$target" ] || [ -L "$target" ]; then
    echo "Limpando: $target"
    rm -rf "$target"
  fi
done

echo -e "\n\033[1;33mAplicando Stow\033[0m\n"
cd "$HOME/.dotfiles" || exit 1

# Aplica as configurações no diretório Home (que já existe)
stow -v -t "$HOME" conf_wall conf_posh conf_code conf_git conf_lvim conf_shell conf_kitty conf_waybar conf_rofi conf_pip conf_hypr conf_dunst

# CRIA o diretório de destino do Firefox antes de rodar o Stow
echo "Garantindo que o diretório de destino do Firefox exista..."
mkdir -p "$PROFILE_DIR/chrome"

# Aplica as configurações do Firefox
stow -v -t "$PROFILE_DIR/chrome" conf_firefox

echo -e "\n\033[3;32m\u2714 Symlinks criados com sucesso!\033[0m\n"

echo -e "\033[1;33mIMPORTANDO configurações do GNOME\033[0m\n"

prettyPrint "Configurações de Extensões"
dconf load /org/gnome/shell/extensions/ < ~/.dotfiles/gnome/extensions.dconf

prettyPrint "Configurações de Preferências"
dconf load /org/gnome/desktop/wm/preferences/ < ~/.dotfiles/gnome/preferences.dconf

prettyPrint "Configurações de Atalhos do teclado"
dconf load /org/gnome/settings-daemon/plugins/media-keys/ < ~/.dotfiles/gnome/gnome-keybindings.dconf

prettyPrint "Configurações de Idioma e Região"
dconf load /org/gnome/desktop/input-sources/ < ~/.dotfiles/gnome/input-sources.dconf

prettyPrint "Configurações de Interface"
dconf load /org/gnome/desktop/interface/ < ~/.dotfiles/gnome/interface.dconf

prettyPrint "Configurações do Mouse"
dconf load /org/gnome/desktop/peripherals/mouse/ < ~/.dotfiles/gnome/mouse.dconf

echo -e "\033[1;33m- - - - - - - - - - - - - - - - - - - -\033[0m"
