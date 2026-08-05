#!/usr/bin/env bash
#
# Contraparte do system-lock.sh — desfaz o que o lock apagou.
#
# Por que não chamar o `omarchy-system-wake` direto: ele faz
# `omarchy-brightness-display on`, que é `hyprctl dispatch dpms on`. O DPMS saiu
# do caminho de lock desta máquina (o porquê está no comentário longo do
# system-lock.sh), então o par correto de "apagar a tela" passou a ser restaurar
# o backlight — não religar DPMS.

# Mesma heurística de device do omarchy-brightness-display.
panel="$(ls -1 /sys/class/backlight 2>/dev/null | head -n1)"
for candidate in amdgpu_bl* intel_backlight acpi_video*; do
  if [[ -e /sys/class/backlight/$candidate ]]; then
    panel="$candidate"
    break
  fi
done

# -r devolve o nível salvo com -s no lock. Sem save prévio o brightnessctl sai
# != 0, o que aqui não é erro (acordar sem ter passado pelo lock).
[[ -n $panel ]] && brightnessctl -rd "$panel" >/dev/null 2>&1

omarchy-brightness-keyboard restore

# Rede de segurança: suspend/resume — ou qualquer script de terceiro — ainda
# pode deixar um monitor em DPMS off. Religa só se algum estiver realmente
# desligado: um `dpms on` gratuito provoca modeset, que é exatamente o que este
# arranjo existe pra evitar.
if hyprctl monitors -j 2>/dev/null | jq -e 'any(.[]; .dpmsStatus == false)' >/dev/null 2>&1; then
  hyprctl dispatch dpms on
fi
