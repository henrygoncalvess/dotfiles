#!/usr/bin/env bash
# Script para exportar configurações do GNOME (Zorin OS)
# Autor: Henry

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

CONF_DIRS=("$PROFILE_DIR/chrome" .config/Code/User .config/kitty .config/lvim .config/oh_my_posh_config .config/sway .config/waybar .config/wofi)

echo -e "\033[1;33mDesfazendo links\033[0m\n"
stow -v -D -t ~ conf_posh conf_code conf_git conf_lvim conf_bash conf_kitty conf_sway conf_waybar conf_wofi
stow -v -D -t "$PROFILE_DIR/chrome" conf_firefox

echo -e "\033[1;33mRemovendo arquivos\033[0m\n"
for dir in "${CONF_DIRS[@]}"; do
  echo "R: $dir"
  rm -rf "$dir"
  mkdir -p "$dir"
done

cd ~/.dotfiles
stow -v -t ~ conf_posh conf_code conf_git conf_lvim conf_bash conf_kitty conf_sway conf_waybar conf_wofi
stow -v -t "$PROFILE_DIR/chrome" conf_firefox

echo -e "\n\033[3;32m\u2714 Symlinks criados com sucesso!\033[0m\n"

echo -e "\033[1;33mIMPORTANDO configurações do GNOME\033[0m\n"

prettyPrint "Configurações de Extensões"
dconf load /org/gnome/shell/extensions/ < ~/.dotfiles/gnome/extensions.dconf

prettyPrint "Configurações de Atalhos do teclado"
dconf load /org/gnome/settings-daemon/plugins/media-keys/ < ~/.dotfiles/gnome/gnome-keybindings.dconf

prettyPrint "Configurações de Idioma e Região"
dconf load /org/gnome/desktop/input-sources/ < ~/.dotfiles/gnome/input-sources.dconf

prettyPrint "Configurações de Interface"
dconf load /org/gnome/desktop/interface/ < ~/.dotfiles/gnome/interface.dconf

prettyPrint "Configurações do Mouse"
dconf load /org/gnome/desktop/peripherals/mouse/ < ~/.dotfiles/gnome/mouse.dconf

echo -e "\033[1;33m- - - - - - - - - - - - - - - - - - - -\033[0m"
