#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/../caching.sh"
qs_ensure_cache "music"

# QS_STATE_MUSIC (~/.local/state), não QS_RUN_MUSIC ($XDG_RUNTIME_DIR): o run dir
# é tmpfs e sumia a cada reboot. O preset abaixo sobrevive, então a UI voltava
# marcando "Flat" enquanto o EasyEffects seguia aplicando a curva antiga.
STATE_FILE="$QS_STATE_MUSIC/eq_state.json"
PRESET_DIR="$HOME/.local/share/easyeffects/output"
PRESET_NAME="live_eq"
PRESET_FILE="$PRESET_DIR/${PRESET_NAME}.json"
EE_SINK="easyeffects_sink"
AUDIO_BACKEND="$HOME/.config/Brain_Shell/src/scripts/audio-control.sh"

mkdir -p "$PRESET_DIR"

# Sem estado salvo, o preset é a fonte da verdade — é ele que está tocando, e numa
# máquina nova é ele que vem versionado no dotfiles. Reconstruir os sliders a
# partir dele mantém UI e áudio dizendo a mesma coisa; só cai pro Flat quando não
# há preset nenhum.
if [ ! -f "$STATE_FILE" ]; then
    seeded=""
    if [ -f "$PRESET_FILE" ]; then
        seeded=$(python3 -c "
import json, sys
try:
    eq = json.load(open(sys.argv[1]))['output']['equalizer#0']
    bands = eq['left']
    state = {'b%d' % (i + 1): bands['band%d' % i]['gain'] for i in range(int(eq['num-bands']))}
    state.update({'preset': 'Custom', 'pending': False})
    print(json.dumps(state))
except Exception:
    pass
" "$PRESET_FILE" 2>/dev/null)
    fi
    if [ -n "$seeded" ]; then
        echo "$seeded" > "$STATE_FILE"
    else
        echo '{"b1": 0, "b2": 0, "b3": 0, "b4": 0, "b5": 0, "b6": 0, "b7": 0, "b8": 0, "b9": 0, "b10": 0, "preset": "Flat", "pending": false}' > "$STATE_FILE"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Geração do preset
#
# Formato do EasyEffects 8.x — dois detalhes que quebravam silenciosamente antes:
#
#   1. A chave do plugin é "equalizer#0" (com o sufixo de instância), tanto em
#      plugins_order quanto no objeto. Com só "equalizer" o EE ignora o plugin,
#      retorna exit 0 e não muda nada.
#   2. Em cada banda, `type`, `mode` e `slope` são STRINGS. O script antigo
#      mandava "mode": "Bell" — mas Bell é um *type*, não um mode — e omitia
#      `type`. Isso derrubava o parser com
#      "[json.exception.type_error.302] type must be string, but is number".
#
# Dá pra conferir se pegou com: easyeffects -a output   (imprime o preset ativo)
#
# São 10 bandas, uma por slider da UI. A versão anterior declarava 32 bandas e
# espalhava os 10 sliders nos índices 0,3,6,…,27; o resto ficava em 0 e o LSP
# ainda reclamava de "port symbol not found: gl_6" no journal.
# ─────────────────────────────────────────────────────────────────────────────
apply_eq() {
    vals=$(cat "$STATE_FILE")
    python3 -c "
import sys, json

data  = json.loads(sys.argv[1])
freqs = [31.0, 62.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0]
gains = [float(data['b%d' % (i + 1)]) for i in range(10)]
# Preserve headroom: a +7 dB bass band with 0 dB preamp clips before the
# hardware volume is even considered. Compensate by the largest positive band.
preamp = -max(0.0, max(gains))

def channel():
    bands = {}
    for i, (freq, gain) in enumerate(zip(freqs, gains)):
        bands['band%d' % i] = {
            'type':      'Bell',
            'mode':      'RLC (BT)',
            'slope':     'x1',
            'frequency': freq,
            'gain':      gain,
            'q':         1.0,
            'width':     1.0,
            'mute':      False,
            'solo':      False,
        }
    return bands

preset = {
    'output': {
        'blocklist':     [],
        'plugins_order': ['equalizer#0'],
        'equalizer#0': {
            'bypass':         False,
            'input-gain':     0.0,
            'output-gain':    preamp,
            'mode':           'IIR',
            'num-bands':      len(freqs),
            'split-channels': False,
            'balance':        0.0,
            'pitch-left':     0.0,
            'pitch-right':    0.0,
            'left':           channel(),
            'right':          channel(),
        }
    }
}
print(json.dumps(preset, indent=4))
" "$vals" > "$PRESET_FILE" || return 1

    ensure_easyeffects
    easyeffects -l "$PRESET_NAME" >/dev/null 2>&1
    route_through_ee
}

ensure_easyeffects() {
    if ! pgrep -x easyeffects > /dev/null; then
        easyeffects --service-mode >/dev/null 2>&1 &
        # Espera o sink virtual aparecer antes de tentar rotear.
        for _ in $(seq 1 20); do
            pactl list short sinks 2>/dev/null | grep -q "$EE_SINK" && break
            sleep 0.25
        done
    fi
}

# O Brain_Shell é a autoridade única de roteamento. O EasyEffects upstream pede
# que o hardware continue sendo o default; o sink virtual é apenas um detalhe do
# grafo e não deve aparecer como se fosse um alto-falante. O backend também
# desliga o bypass global, que antes podia deixar a UI em "aplicado" sem efeito.
route_through_ee() {
    if [ -x "$AUDIO_BACKEND" ]; then
        "$AUDIO_BACKEND" effects on >/dev/null
        return
    fi
    easyeffects -b 2 >/dev/null 2>&1 || true
}

# Desliga o processamento e conserva a saída física escolhida no painel.
unroute() {
    if [ -x "$AUDIO_BACKEND" ]; then
        "$AUDIO_BACKEND" effects off >/dev/null
        return
    fi
    easyeffects -b 1 >/dev/null 2>&1 || true
}

# Save state helper (Always sets pending to false because Presets apply instantly)
save_preset() {
    jq -n -c --arg b1 "$1" --arg b2 "$2" --arg b3 "$3" --arg b4 "$4" --arg b5 "$5" \
          --arg b6 "$6" --arg b7 "$7" --arg b8 "$8" --arg b9 "$9" --arg b10 "${10}" --arg p "${11}" \
       '{"b1": $b1, "b2": $b2, "b3": $b3, "b4": $b4, "b5": $b5, "b6": $b6, "b7": $b7, "b8": $b8, "b9": $b9, "b10": $b10, "preset": $p, "pending": false}' > "$STATE_FILE"
}

cmd=$1
arg1=$2
arg2=$3

case $cmd in
    "get") cat "$STATE_FILE" ;;
    "status")
        echo "active preset: $(easyeffects -a output 2>/dev/null | head -1)"
        echo "bypass: $(easyeffects -b 3 2>/dev/null | head -1)"
        echo "physical output: $(pactl get-default-sink 2>/dev/null)"
        ;;
    "set_band")
        # SLIDER MOVE: Set pending = true, Preset = Custom. DO NOT APPLY.
        tmp=$(cat "$STATE_FILE")
        updated=$(echo "$tmp" | jq -c --arg val "$arg2" ".b$arg1 = \$val | .preset = \"Custom\" | .pending = true")
        echo "$updated" > "$STATE_FILE"
        ;;
    "apply")
        # APPLY BUTTON: Set pending = false, then Apply.
        tmp=$(cat "$STATE_FILE")
        updated=$(echo "$tmp" | jq -c ".pending = false")
        echo "$updated" > "$STATE_FILE"
        apply_eq
        ;;
    "route")   route_through_ee ;;
    "unroute") unroute ;;
    "preset")
        # PRESET CLICK: Save values (pending=false) and Apply Instantly.
        case $arg1 in
            "Flat")    save_preset 0 0 0 0 0 0 0 0 0 0 "Flat" ;;
            "Bass")    save_preset 5 7 5 2 1 0 0 0 1 2 "Bass" ;;
            "Treble")  save_preset -2 -1 0 1 2 3 4 5 6 6 "Treble" ;;
            "Vocal")   save_preset -2 -1 1 3 5 5 4 2 1 0 "Vocal" ;;
            "Pop")     save_preset 2 4 2 0 1 2 4 2 1 2 "Pop" ;;
            "Rock")    save_preset 5 4 2 -1 -2 -1 2 4 5 6 "Rock" ;;
            "Jazz")    save_preset 3 3 1 1 1 1 2 1 2 3 "Jazz" ;;
            "Classic") save_preset 0 1 2 2 2 2 1 2 3 4 "Classic" ;;
        esac
        apply_eq
        ;;
esac
