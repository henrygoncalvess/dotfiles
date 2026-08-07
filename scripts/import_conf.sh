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
#
# CUIDADO: nada aqui pode ter um symlink no meio do caminho. `rm -rf` atravessa
# symlink de diretório-pai e apaga o destino, não o link. Foi o que quase
# aconteceu com ~/.local/share/qs/qs-vpets: o stow tinha dobrado ~/.local/share/qs
# num link pro repo, então limpar o alvo apagaria os arquivos versionados aqui
# dentro. Alvo de pacote overlay não entra nesta lista.
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
  # Se o alvo NÃO é o symlink em si mas mesmo assim resolve pra dentro do repo,
  # tem um symlink no meio do caminho e este `rm -rf` apagaria os arquivos
  # versionados em vez de um link. Abortar é sempre melhor que isso.
  if [ ! -L "$target" ] && [[ "$(readlink -f "$target" 2>/dev/null)" == "$HOME/.dotfiles/"* ]]; then
    echo -e "\033[1;31mPulando $target — resolve pra dentro do repositório (symlink de pai)\033[0m"
    continue
  fi
  if [ -e "$target" ] || [ -L "$target" ]; then
    echo "Limpando: $target"
    rm -rf "$target"
  fi
done

# Nos overlays só o arquivo que o pacote realmente fornece é removido.
for pkg in "${OVERLAY_PACKAGES[@]}"; do
  # 1) Desdobrar ANTES de limpar. Uma execução anterior pode ter dobrado um
  #    diretório inteiro num symlink pro repo (foi o caso de ~/.local/share/qs).
  #    Se isso continuar de pé, o passo 2 abaixo atravessa o link e apaga os
  #    arquivos VERSIONADOS aqui dentro, porque `rm -f` segue symlink de pai.
  #    Removendo só o link não se perde nada: `rm -f` num symlink nunca toca o
  #    destino, e o stow recria o diretório real logo em seguida.
  while IFS= read -r rel; do
    target="$HOME/$rel"
    if [ -L "$target" ] && [[ "$(readlink -f "$target")" == "$HOME/.dotfiles/"* ]]; then
      echo "Desdobrando (overlay): $target"
      rm -f "$target"
    fi
  done < <(cd "$HOME/.dotfiles/$pkg" && find . -mindepth 1 -type d -printf '%P\n')

  # 2) Agora sim: só o arquivo real (não-symlink) que o pacote vai substituir.
  while IFS= read -r rel; do
    target="$HOME/$rel"
    # Rede de segurança pro caso de sobrar algum symlink de pai não previsto: se
    # o caminho resolve pra dentro do repo, não é arquivo do sistema a ser
    # descartado — é o nosso original. Nunca apagar.
    case "$(readlink -f "$target" 2>/dev/null)" in
      "$HOME/.dotfiles/"*) continue ;;
    esac
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

# ── Antigravity IDE ──────────────────────────────────────────────────────────
# Antigravity is a VS Code fork, so it reads the very same settings.json and
# keybindings.json — it just looks for them under its own name (product.json:
# nameLong "Antigravity IDE"), which is why the conf_code package alone never
# reached it.
#
# The same package is stowed a second time with the Antigravity data dir as the
# target: --dir points at conf_code/.config so that the package "Code" maps its
# User/ subtree onto "<data dir>/User". No second copy of the files exists, both
# editors follow the same links into conf_code.
#
# Overlay rules apply here for the usual reason: that User/ directory also holds
# History/, globalStorage/ and workspaceStorage/, none of which belong to this
# repo — hence --no-folding, and only the two files we provide get removed
# before the stow.
ANTIGRAVITY_DIR="$HOME/.config/Antigravity IDE"
echo -e "\n\033[1;33mAplicando as configurações do VS Code no Antigravity IDE\033[0m\n"
if [ -d "$ANTIGRAVITY_DIR" ]; then
  mkdir -p "$ANTIGRAVITY_DIR/User"
  for name in settings.json keybindings.json; do
    target="$ANTIGRAVITY_DIR/User/$name"
    if [ -f "$target" ] && [ ! -L "$target" ]; then
      echo "Limpando (overlay): $target"
      rm -f "$target"
    fi
  done
  stow -v --no-folding --dir "$HOME/.dotfiles/conf_code/.config" --target "$ANTIGRAVITY_DIR" Code
else
  echo -e "\033[1;31mAntigravity IDE não encontrado — abra ele uma vez e rode o script de novo\033[0m"
fi

# ── Units systemd --user ─────────────────────────────────────────────────────
# O stow entrega os arquivos .service, mas quem os liga ao boot é o symlink em
# graphical-session.target.wants/ — sem `enable` o Brain_Shell simplesmente não
# sobe no login de uma máquina nova. `mask mako` completa o par: o qs_run.sh
# mata o mako em runtime, o mask impede que ele suba de novo.
echo -e "\n\033[1;33mHabilitando units do usuário\033[0m\n"
if systemctl --user is-system-running >/dev/null 2>&1 || [ -n "${XDG_RUNTIME_DIR:-}" ]; then
  systemctl --user daemon-reload
  systemctl --user enable brainshell.service quickshell.service
  systemctl --user mask mako.service
  echo "Units habilitadas (valem a partir do próximo login)"
else
  echo -e "\033[1;31mSem sessão de usuário do systemd — rode manualmente:\033[0m"
  echo "  systemctl --user daemon-reload"
  echo "  systemctl --user enable brainshell.service quickshell.service"
  echo "  systemctl --user mask mako.service"
fi

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
