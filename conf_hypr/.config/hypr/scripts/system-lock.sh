#!/usr/bin/env bash
#
# Wrapper de bloqueio de tela — ponto de entrada ÚNICO do lock nesta máquina.
#
# Por que existe: antes o ~/.local/share/omarchy/bin/omarchy-system-lock era
# editado à mão pra chamar o qylock. Aquele diretório é a árvore git do Omarchy,
# então todo `omarchy update` desfazia (ou conflitava com) o patch e o lock
# voltava pro hyprlock sem aviso. Este script é versionado no dotfiles e chamado
# por caminho absoluto pelo hypridle.conf e pelo bindings.conf, então nada
# externo pode revertê-lo.
#
# O que ele resolve além disso: o qylock roda como cliente WlSessionLock. Se o
# processo morre com a sessão travada, o Hyprland assume com a tela de
# emergência dele (fundo preto, texto em fonte cursiva). Aqui o processo é
# supervisionado: se cair sem ter autenticado, sobe de novo; se insistir em
# cair, entrega pro hyprlock — que é feio, mas nunca deixa a máquina destrancada.

LOCKER="$HOME/.local/share/quickshell-lockscreen/lock.sh"

# Sentinela escrita pelo lock_shell.qml quando a autenticação dá certo. É como o
# supervisor distingue "usuário destravou" de "processo morreu".
SENTINEL="${XDG_RUNTIME_DIR:-/tmp}/qylock-unlocked"

# Quantas vezes o locker pode cair antes de cairmos pro hyprlock.
MAX_RESTARTS=3

# Já tem lock na tela? Não empilha outro.
if pgrep -f "lock_shell.qml" >/dev/null || pidof hyprlock >/dev/null; then
  exit 0
fi

# O pgrep acima não basta: entre a queda do locker e o relaunch existe uma
# janela de ~0.5s em que nenhum processo de lock está de pé. Um segundo disparo
# do hypridle caindo nessa fresta passava pelo teste e subia um supervisor
# paralelo — dois loops relançando o locker, o que dava a impressão de bloqueio
# infinito. O flock garante um supervisor por vez pela vida inteira do lock.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/system-lock.lock"
flock -n 9 || exit 0

# Sem isso o Hyprland recusa um novo cliente de lock depois que o anterior
# morreu — o relaunch abaixo não conseguiria substituir a tela de emergência.
hyprctl keyword misc:allow_session_lock_restore 1 >/dev/null 2>&1

run_locker() {
  rm -f "$SENTINEL"

  local attempt=0
  while [ "$attempt" -le "$MAX_RESTARTS" ]; do
    "$LOCKER"

    # Autenticou: saída limpa.
    [ -f "$SENTINEL" ] && { rm -f "$SENTINEL"; return 0; }

    attempt=$((attempt + 1))
    echo "qylock caiu sem autenticar (tentativa $attempt/$MAX_RESTARTS)" >&2
    sleep 0.5
  done

  # Esgotou as tentativas: hyprlock assume pra sessão não ficar aberta.
  echo "qylock instável — caindo pro hyprlock" >&2
  command -v hyprlock >/dev/null && hyprlock
}

(
  run_locker
  "$HOME/.config/hypr/scripts/system-wake.sh"
) &

# Garante que o 1Password tranca junto.
if pgrep -x "1password" >/dev/null; then
  1password --lock &
fi

# Screensaver não deve rodar por trás do lock.
pkill -f org.omarchy.screensaver

# Apaga a tela alguns segundos depois — só se o lock realmente subiu.
# OMARCHY_LOCK_ONLY=true (usado no before_sleep_cmd) pula esta parte.
#
# NÃO usar `omarchy-brightness-display off` aqui. Ele é `hyprctl dispatch dpms
# off` em TODOS os monitores, e nesta máquina (i915, eDP-1 + HDMI-A-1 + quatro
# portas DP Type-C vazias) desligar o DPMS derruba o link do conector externo.
# O kernel responde com uma tempestade de re-probe de conector
# (intel_hotplug_detect_connector / drm_helper_probe_single_connector_modes,
# com WARN em __intel_tc_port_lock), o Hyprland destrói e recria o wl_output e
# então dispara `wl_display error 0: invalid object N` contra todo cliente que
# ainda segurava aquele output. Cliente com erro de protocolo é desconectado à
# força pelo compositor — ou seja, o app morre.
#
# Quem morre: Chromium/Electron (antigravity-ide, chrome), GTK4 (walker,
# swayosd) e Qt (easyeffects, quickshell/Brain_Shell). O Firefox trata remoção
# de wl_output corretamente e sobrevive — era só por isso que "sobrava o
# workspace 1": o Firefox morava nele. O número do workspace nunca teve relação
# com o bug.
#
# O substituto zera o backlight do painel interno via sysfs (brightnessctl), que
# não encosta no DRM. O monitor externo fica aceso mostrando o lock screen — é o
# preço de não perder a sessão inteira. O system-wake.sh restaura com -r.
if [[ ${OMARCHY_LOCK_ONLY:-false} != "true" ]]; then
  (
    sleep 3
    pgrep -f "lock_shell.qml" >/dev/null || pidof hyprlock >/dev/null || exit 0
    omarchy-brightness-keyboard off

    # panel="$(ls -1 /sys/class/backlight 2>/dev/null | head -n1)"
    # for candidate in amdgpu_bl* intel_backlight acpi_video*; do
    #   if [[ -e /sys/class/backlight/$candidate ]]; then
    #     panel="$candidate"
    #     break
    #   fi
    # done
    # [[ -n $panel ]] && brightnessctl -sd "$panel" set 0 >/dev/null
  ) &
fi
