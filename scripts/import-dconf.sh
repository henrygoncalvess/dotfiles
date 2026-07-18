#!/usr/bin/env bash

PROFILE_DIR=$(find "$HOME/.mozilla/firefox" -maxdepth 1 -type d -name "*.default-release" | head -n 1)

echo -e "\033[1;33m- - - - - - - - - - - - - - - - - - - -\033[0m\n"

echo -e "\033[1;33mCriando Symlinks com GNU Stow\033[0m\n"

# A matriz agora foca na raiz do VS Code para evitar a travessia de symlinks.
CONF_TARGETS=(
  "$PROFILE_DIR/chrome"
  "$HOME/.config/Code"
  "$HOME/.config/kitty"
  "$HOME/.config/nvim"
  "$HOME/.config/oh_my_posh_config"
  "$HOME/.config/waybar"
  "$HOME/.config/rofi"
  "$HOME/.config/pip"
  "$HOME/.config/hypr"
  "$HOME/.config/quickshell"
  "$HOME/.config/Brain_Shell"
  "$HOME/.local/share/quickshell-lockscreen"
  "$HOME/.bashrc"
  "$HOME/.zshrc"
  "$HOME/.gitconfig"
  "$HOME/frigate"
  "$HOME/.face"
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
stow -v -t "$HOME" frigate conf_home conf_wall conf_posh conf_code conf_git conf_nvim conf_shell conf_kitty conf_waybar conf_rofi conf_pip conf_hypr conf_quickshell conf_qylock

# CRIA o diretório de destino do Firefox antes de rodar o Stow
echo "Garantindo que o diretório de destino do Firefox exista..."
mkdir -p "$PROFILE_DIR/chrome"

# Aplica as configurações do Firefox
stow -v -t "$PROFILE_DIR/chrome" conf_firefox

echo -e "\n\033[3;32m\u2714 Symlinks criados com sucesso!\033[0m\n"

echo -e "\033[1;33m- - - - - - - - - - - - - - - - - - - -\033[0m\n"
