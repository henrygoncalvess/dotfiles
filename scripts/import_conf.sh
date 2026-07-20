#!/usr/bin/env bash

# Firefox pode criar o perfil em ~/.mozilla (padrão) OU em ~/.config/mozilla
# (builds novos usam XDG quando ~/.mozilla não existe) — procura nos dois.
PROFILE_DIR=$(find "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox" -maxdepth 1 -type d -name "*.default-release" 2>/dev/null | head -n 1)
[[ -z "$PROFILE_DIR" ]] && PROFILE_DIR=$(find "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox" -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -n 1)

echo -e "\033[1;33m- - - - - - - - - - - - - - - - - - - -\033[0m\n"

echo -e "\033[1;33mCriando Symlinks com GNU Stow\033[0m\n"

# Paths to clean before stowing (avoids conflicts with pre-existing dirs/files).
CONF_TARGETS=(
  "$HOME/.config/Code"
  "$HOME/.config/kitty"
  "$HOME/.config/oh_my_posh_config"
  "$HOME/.config/rofi"
  "$HOME/.config/quickshell"
  "$HOME/.config/Brain_Shell"
  "$HOME/.config/hypr"
  "$HOME/.config/nvim"
  "$HOME/.local/share/quickshell-lockscreen"
  "$HOME/.bash_profile"
  "$HOME/.bashrc"
  "$HOME/.zshrc"
  "$HOME/.gitconfig"
  "$HOME/frigate"
  "$HOME/.face"
  "$HOME/wallpapers"
  "$HOME/.vscode"
)

STOW_PACKAGES=(frigate conf_home conf_wall conf_posh conf_code conf_git conf_shell conf_kitty conf_rofi conf_quickshell conf_qylock conf_hypr conf_nvim)

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
stow -v -t "$HOME" "${STOW_PACKAGES[@]}"

# O user.js/userChrome só se aplica se o Firefox já tiver um perfil criado
if [[ -n "$PROFILE_DIR" ]]; then
  rm -rf "$PROFILE_DIR/chrome"

  echo "Garantindo que o diretório de destino do Firefox exista..."
  mkdir -p "$PROFILE_DIR/chrome"

  # Aplica as configurações do Firefox
  stow -v -t "$PROFILE_DIR/chrome" conf_firefox
else
  echo -e "\n\033[1;31mPerfil do Firefox não encontrado — abra o Firefox uma vez e rode o script de novo pra aplicar o userChrome\033[0m"
fi

echo -e "\n\033[3;32m✔ Symlinks criados com sucesso!\033[0m\n"

echo -e "\033[1;33m- - - - - - - - - - - - - - - - - - - -\033[0m\n"
