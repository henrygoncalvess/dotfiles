#!/usr/bin/env bash
# Script para exportar configurações do GNOME (Zorin OS)
# Autor: Henry

prettyPrint(){
    local action="$1"

    echo -ne "\033[33m$action\033[0m"

    for i in {1..3}; do
        for string in '|' '/' '-' '\'; do
            printf "\r\033[33m$action %s\033[0m" "$string"
            sleep 0.1
        done
    done

    printf "\r\033[33m$action  \033[0m"
    echo -e "\n\033[3;32m\u2714 Exportadas com sucesso!\033[0m\n"
    sleep 0.1
}

mkdir -p ~/.dotfiles/gnome

echo -e "\033[1;36m- - - - - - - - - - - - - - - - - - - -\033[0m\n"
echo -e "\033[1;36mEXPORTANDO configurações do GNOME\033[0m\n"

prettyPrint "Configurações de Extensões"
dconf dump /org/gnome/shell/extensions/ > ~/.dotfiles/gnome/extensions.dconf

prettyPrint "Configurações de Atalhos do teclado"
dconf dump /org/gnome/settings-daemon/plugins/media-keys/ > ~/.dotfiles/gnome/gnome-keybindings.dconf

prettyPrint "Configurações de Idioma e Região"
dconf dump /org/gnome/desktop/input-sources/ > ~/.dotfiles/gnome/input-sources.dconf

prettyPrint "Configurações de Interface"
dconf dump /org/gnome/desktop/interface/ > ~/.dotfiles/gnome/interface.dconf

prettyPrint "Configurações do Mouse"
dconf dump /org/gnome/desktop/peripherals/mouse/ > ~/.dotfiles/gnome/mouse.dconf

echo -e "\033[33mConfigurações do Terminal\033[0m"
sleep 0.2
prettyPrint "Detectando Perfis do GNOME Terminal"

PROFILE_ID=$(dconf list /org/gnome/terminal/legacy/profiles:/ | head -n 1)

dconf dump /org/gnome/terminal/legacy/profiles:/$PROFILE_ID > ~/.dotfiles/gnome/terminal.dconf
echo -e "\033[1;36m- - - - - - - - - - - - - - - - - - - -\033[0m"
