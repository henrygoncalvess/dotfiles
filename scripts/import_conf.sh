#!/usr/bin/env bash

# Firefox pode criar o perfil em ~/.mozilla (padrão) OU em ~/.config/mozilla
# (builds novos usam XDG quando ~/.mozilla não existe) — procura nos dois.
PROFILE_DIR=$(find "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox" -maxdepth 1 -type d -name "*.default-release" 2>/dev/null | head -n 1)
[[ -z "$PROFILE_DIR" ]] && PROFILE_DIR=$(find "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox" -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -n 1)

echo -e "\033[1;33m- - - - - - - - - - - - - - - - - - - -\033[0m\n"

echo -e "\033[1;33mCriando Symlinks com GNU Stow\033[0m\n"

# Paths to clean before stowing (avoids conflicts with pre-existing dirs/files).
# Only entries whose ENTIRE tree belongs to this repo go here — o alvo é apagado
# com `rm -rf` antes do stow.
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
  "$HOME/.local/share/qs/qs-vpets"
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

# Pacotes "overlay": o diretório de destino é COMPARTILHADO com o sistema
# (~/.config/omarchy guarda current/theme, theme.name, themes/, branding/about.txt
# — estado do Omarchy que não está neste repo; ~/.config/walker recebe arquivos
# gerados pelo `omarchy refresh walker`). Nunca dar `rm -rf` nesses alvos:
# limpa-se só o arquivo específico e aplica-se stow com --no-folding, pra ele
# criar link por arquivo em vez de trocar o diretório inteiro por um symlink.
#
# conf_systemd entra aqui por outro motivo: o systemd NÃO segue diretório de
# drop-in que seja symlink. Com o stow trocando
# ~/.config/systemd/user/app-...@autostart.service.d por um link, o restart.conf
# é silenciosamente ignorado (`systemctl show -p Restart` continua "no"). Com
# --no-folding o diretório fica real e só o .conf vira link, aí pega.
#
# conf_qs-vpets: o pacote entrega o runtime (~/.local/share/qs/qs-vpets, 100%
# nosso) E o ~/.config/qs-vpets/config.json. Esse segundo diretório é onde o
# próprio qs-vpets grava state-<Pet>.json a cada movimento; com folding o stow
# transformaria ~/.config/qs-vpets num symlink e todo esse estado cairia dentro
# do repositório.
#
# conf_easyeffects e conf_autostart compartilham o destino com arquivos que não
# são nossos: presets criados pela UI do EasyEffects e entradas .desktop que os
# próprios aplicativos instalam.
OVERLAY_PACKAGES=(conf_omarchy conf_walker conf_systemd conf_qs-vpets conf_easyeffects conf_autostart)

echo -e "\033[1;33mRemovendo arquivos existentes para evitar conflitos\033[0m\n"
for target in "${CONF_TARGETS[@]}"; do
  if [ -e "$target" ] || [ -L "$target" ]; then
    echo "Limpando: $target"
    rm -rf "$target"
  fi
done

# Nos overlays só o arquivo que o pacote realmente fornece é removido.
for pkg in "${OVERLAY_PACKAGES[@]}"; do
  while IFS= read -r rel; do
    target="$HOME/$rel"
    if [ -f "$target" ] && [ ! -L "$target" ]; then
      echo "Limpando (overlay): $target"
      rm -f "$target"
    fi
  done < <(cd "$HOME/.dotfiles/$pkg" && find . -type f -printf '%P\n')
done

echo -e "\n\033[1;33mAplicando Stow\033[0m\n"
cd "$HOME/.dotfiles" || exit 1

# Aplica as configurações no diretório Home (que já existe)
stow -v -t "$HOME" "${STOW_PACKAGES[@]}"

# --no-folding: preserva os diretórios reais do destino e linka arquivo a arquivo.
stow -v --no-folding -t "$HOME" "${OVERLAY_PACKAGES[@]}"

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
