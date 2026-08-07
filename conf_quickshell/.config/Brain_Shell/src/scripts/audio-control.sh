#!/usr/bin/env bash

# Brain_Shell audio backend.
#
# PipeWire exposes EasyEffects as if it were another speaker/microphone. That is
# useful to the audio graph, but confusing in a device picker. This helper keeps
# that routing detail out of the UI and, importantly, reconnects application
# streams after a card profile change (PipeWire does not always do it itself).

set -u

readonly EE_SINK="easyeffects_sink"
readonly EE_SOURCE="easyeffects_source"
readonly STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/brain-shell"
readonly STATE_FILE="${STATE_DIR}/audio.json"

json_error() {
    jq -nc --arg message "$1" '{ok: false, message: $message}'
}

json_ok() {
    jq -nc --arg message "$1" '{ok: true, message: $message}'
}

require_audio_server() {
    command -v pactl >/dev/null 2>&1 || {
        json_error "pactl is not installed"
        return 1
    }
    command -v jq >/dev/null 2>&1 || {
        json_error "jq is not installed"
        return 1
    }
    pactl info >/dev/null 2>&1 || {
        json_error "Could not connect to PipeWire"
        return 1
    }
}

pactl_json() {
    pactl -f json "$@" 2>/dev/null
}

default_sink() {
    pactl get-default-sink 2>/dev/null || true
}

default_source() {
    pactl get-default-source 2>/dev/null || true
}

physical_sink_exists() {
    local name="$1"
    pactl_json list sinks | jq -e --arg name "$name" --arg ee "$EE_SINK" '
        any(.[];
            .name == $name and
            .name != $ee and
            .properties["node.virtual"] != "true" and
            .properties["application.id"] != "com.github.wwmm.easyeffects")
    ' >/dev/null
}

physical_source_exists() {
    local name="$1"
    pactl_json list sources | jq -e --arg name "$name" --arg ee "$EE_SOURCE" '
        any(.[];
            .name == $name and
            .name != $ee and
            (.name | endswith(".monitor") | not) and
            .properties["device.class"] != "monitor" and
            .properties["node.virtual"] != "true" and
            .properties["application.id"] != "com.github.wwmm.easyeffects")
    ' >/dev/null
}

saved_sink() {
    [[ -r "$STATE_FILE" ]] || return 0
    jq -r '.physicalSink // empty' "$STATE_FILE" 2>/dev/null || true
}

save_sink() {
    local sink="$1"
    mkdir -p "$STATE_DIR"
    jq -nc --arg sink "$sink" '{physicalSink: $sink}' >"${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

first_physical_sink() {
    local preferred="${1:-}"
    local sinks
    sinks="$(pactl_json list sinks)" || return 1

    if [[ -n "$preferred" ]] && physical_sink_exists "$preferred"; then
        printf '%s\n' "$preferred"
        return 0
    fi

    jq -r --arg ee "$EE_SINK" '
        [ .[]
          | select(.name != $ee)
          | select(.properties["node.virtual"] != "true")
          | select(.properties["application.id"] != "com.github.wwmm.easyeffects")
        ]
        | (map(select(.active_port == "analog-output-speaker"))[0]
           // map(select(.state == "RUNNING"))[0]
           // .[0]
           // empty)
        | .name
    ' <<<"$sinks"
}

selected_physical_sink() {
    local current fallback
    current="$(default_sink)"

    # Respect changes made outside Brain_Shell (for example in pavucontrol).
    # The saved device is only a fallback when a virtual/removed sink became
    # the PulseAudio default.
    if [[ -n "$current" ]] && physical_sink_exists "$current"; then
        save_sink "$current"
        printf '%s\n' "$current"
        return 0
    fi

    fallback="$(first_physical_sink "$(saved_sink)")"
    [[ -n "$fallback" ]] && printf '%s\n' "$fallback"
}

first_physical_source() {
    local preferred="${1:-}"
    local sources
    sources="$(pactl_json list sources)" || return 1

    if [[ -n "$preferred" ]] && physical_source_exists "$preferred"; then
        printf '%s\n' "$preferred"
        return 0
    fi

    jq -r --arg ee "$EE_SOURCE" '
        [ .[]
          | select(.name != $ee)
          | select(.name | endswith(".monitor") | not)
          | select(.properties["device.class"] != "monitor")
          | select(.properties["node.virtual"] != "true")
          | select(.properties["application.id"] != "com.github.wwmm.easyeffects")
        ]
        | (map(select(.active_port == "analog-input-mic"))[0]
           // map(select(.active_port == "analog-input-internal-mic"))[0]
           // map(select(.state == "RUNNING"))[0]
           // .[0]
           // empty)
        | .name
    ' <<<"$sources"
}

sink_for_card() {
    local card="$1"
    pactl_json list sinks | jq -r --arg card "$card" --arg ee "$EE_SINK" '
        [ .[]
          | select(.name != $ee)
          | select(.properties["node.virtual"] != "true")
          | select(.properties["device.name"] == $card)
        ]
        | (map(select(.active_port == "analog-output-speaker"))[0]
           // map(select(.state == "RUNNING"))[0]
           // .[0]
           // empty)
        | .name
    '
}

source_for_card() {
    local card="$1"
    pactl_json list sources | jq -r --arg card "$card" --arg ee "$EE_SOURCE" '
        [ .[]
          | select(.name != $ee)
          | select(.name | endswith(".monitor") | not)
          | select(.properties["device.class"] != "monitor")
          | select(.properties["node.virtual"] != "true")
          | select(.properties["device.name"] == $card)
        ]
        | (map(select(.active_port == "analog-input-mic"))[0]
           // map(select(.active_port == "analog-input-internal-mic"))[0]
           // .[0]
           // empty)
        | .name
    '
}

move_playback_streams() {
    local target="$1"
    local stream sinks ee_index

    sinks="$(pactl_json list sinks)" || return 1
    ee_index="$(jq -r --arg ee "$EE_SINK" '[.[] | select(.name == $ee)][0].index // -1' <<<"$sinks")"

    while IFS= read -r stream; do
        [[ -n "$stream" ]] || continue
        pactl move-sink-input "$stream" "$target" >/dev/null 2>&1 || true
    done < <(pactl_json list sink-inputs | jq -r --argjson eeIndex "$ee_index" '
        .[]
        | select(.properties["application.id"] != "com.github.wwmm.easyeffects")
        | select(.properties["application.name"] != "Quickshell Peak Detect")
        | select((.properties["application.name"] // "") | test("easy ?effects"; "i") | not)
        # Apps already intercepted by EasyEffects stay on its stable virtual
        # sink; only the processor output needs to follow the physical device.
        | select(.sink != $eeIndex)
        | .index
    ')
}

move_recording_streams() {
    local target="$1"
    local stream sources

    sources="$(pactl_json list sources)" || return 1

    while IFS= read -r stream; do
        [[ -n "$stream" ]] || continue
        pactl move-source-output "$stream" "$target" >/dev/null 2>&1 || true
    done < <(pactl_json list source-outputs | jq -r --arg eeSource "$EE_SOURCE" --argjson sources "$sources" '
        .[]
        | select(.properties["application.id"] != "com.github.wwmm.easyeffects")
        | select(.properties["application.name"] != "Quickshell Peak Detect")
        | select((.properties["application.name"] // "") | test("easy ?effects"; "i") | not)
        | . as $stream
        | ([ $sources[] | select(.index == $stream.source) ][0] // null) as $source
        # Screen recorders and cava intentionally capture a sink monitor.
        # Changing the default microphone must not redirect those streams.
        | select($source != null and $source.name != $eeSource and (
            (($source.name // "") | endswith(".monitor") | not) and
            $source.properties["device.class"] != "monitor"))
        | .index
    ')
}

fixed_streams_for_card() {
    local card="$1"
    local sinks sources sink_inputs source_outputs

    sinks="$(pactl_json list sinks)" || return 1
    sources="$(pactl_json list sources)" || return 1
    sink_inputs="$(pactl_json list sink-inputs)" || return 1
    source_outputs="$(pactl_json list source-outputs)" || return 1

    jq -nr --arg card "$card" \
        --argjson sinks "$sinks" --argjson sources "$sources" \
        --argjson playback "$sink_inputs" --argjson recording "$source_outputs" '
        def fixed:
            ((.properties["node.dont-reconnect"] // false) == true or
             (.properties["node.dont-reconnect"] // "false") == "true");
        ([ $playback[]
          | . as $stream
          | ([ $sinks[] | select(.index == $stream.sink) ][0] // null) as $sink
          | select($sink != null and $sink.properties["device.name"] == $card)
          | select($stream | fixed)
          | ($stream.properties["application.name"] // "Application")
        ] +
        [ $recording[]
          | . as $stream
          | ([ $sources[] | select(.index == $stream.source) ][0] // null) as $source
          | select($source != null and $source.properties["device.name"] == $card)
          | select($stream | fixed)
          | ($stream.properties["application.name"] // "Application")
        ]) | unique | join(", ")
    '
}

fixed_effect_streams() {
    local sinks sources sink_inputs source_outputs
    sinks="$(pactl_json list sinks)" || return 1
    sources="$(pactl_json list sources)" || return 1
    sink_inputs="$(pactl_json list sink-inputs)" || return 1
    source_outputs="$(pactl_json list source-outputs)" || return 1

    jq -nr --arg eeSink "$EE_SINK" --arg eeSource "$EE_SOURCE" \
        --argjson sinks "$sinks" --argjson sources "$sources" \
        --argjson playback "$sink_inputs" --argjson recording "$source_outputs" '
        def fixed:
            ((.properties["node.dont-reconnect"] // false) == true or
             (.properties["node.dont-reconnect"] // "false") == "true");
        ([ $playback[]
           | . as $stream
           | ([ $sinks[] | select(.index == $stream.sink) ][0].name // "") as $sink
           | select($sink == $eeSink and ($stream | fixed))
           | ($stream.properties["application.name"] // "Application")
         ] +
         [ $recording[]
           | . as $stream
           | ([ $sources[] | select(.index == $stream.source) ][0].name // "") as $source
           | select($source == $eeSource and ($stream | fixed))
           | ($stream.properties["application.name"] // "Application")
         ]) | unique | join(", ")
    '
}

orphaned_playback_apps() {
    pactl_json list sink-inputs | jq -r '
        [ .[]
          | select(.sink == 4294967295)
          | select(.properties["application.id"] != "com.github.wwmm.easyeffects")
          | select(.properties["application.name"] != "Quickshell Peak Detect")
          | select((.properties["application.name"] // "") | test("easy ?effects"; "i") | not)
          | (.properties["application.name"] // "Application")
        ] | unique | join(", ")
    '
}

orphaned_recording_apps() {
    pactl_json list source-outputs | jq -r '
        [ .[]
          | select(.source == 4294967295)
          | select(.properties["application.id"] != "com.github.wwmm.easyeffects")
          | select(.properties["application.name"] != "Quickshell Peak Detect")
          | select((.properties["application.name"] // "") | test("easy ?effects"; "i") | not)
          | (.properties["application.name"] // "Application")
        ] | unique | join(", ")
    '
}

wait_for_stable_routes() {
    local attempt playback recording
    for attempt in {1..20}; do
        playback="$(orphaned_playback_apps)"
        recording="$(orphaned_recording_apps)"
        [[ -z "$playback" && -z "$recording" ]] && return 0
        sleep 0.1
    done
    return 1
}

move_easyeffects_output() {
    local target="$1"
    local stream

    while IFS= read -r stream; do
        [[ -n "$stream" ]] || continue
        pactl move-sink-input "$stream" "$target" >/dev/null 2>&1 || true
    done < <(pactl_json list sink-inputs | jq -r '
        .[]
        | select(
            .properties["application.id"] == "com.github.wwmm.easyeffects" or
            ((.properties["application.name"] // "") | test("easy ?effects"; "i")))
        | .index
    ')
}

wait_for_sink() {
    local name="$1"
    local attempt
    for attempt in {1..20}; do
        pactl_json list sinks | jq -e --arg name "$name" 'any(.[]; .name == $name)' >/dev/null && return 0
        sleep 0.1
    done
    return 1
}

wait_for_sink_to_disappear() {
    local name="$1"
    local attempt
    for attempt in {1..20}; do
        pactl_json list sinks | jq -e --arg name "$name" 'any(.[]; .name == $name)' >/dev/null || return 0
        sleep 0.1
    done
    return 1
}

select_output() {
    local target="$1"

    physical_sink_exists "$target" || {
        json_error "The selected output is no longer available"
        return 1
    }

    # EasyEffects upstream explicitly asks users to keep a hardware endpoint as
    # the default. Its "process all outputs" policy handles interception; the
    # virtual sink is an implementation detail, never a speaker choice.
    pactl set-default-sink "$target" >/dev/null || {
        json_error "Could not make this output the default"
        return 1
    }
    save_sink "$target"
    move_easyeffects_output "$target"
    move_playback_streams "$target"
}

select_input() {
    local target="$1"
    physical_source_exists "$target" || {
        json_error "The selected microphone is no longer available"
        return 1
    }
    pactl set-default-source "$target" >/dev/null || {
        json_error "Could not make this microphone the default"
        return 1
    }
    move_recording_streams "$target"
}

start_easyeffects() {
    if pactl_json list sinks | jq -e --arg sink "$EE_SINK" 'any(.[]; .name == $sink)' >/dev/null; then
        return 0
    fi

    command -v easyeffects >/dev/null 2>&1 || return 1
    easyeffects --hide-window --service-mode >/dev/null 2>&1 &
    wait_for_sink "$EE_SINK"
}

toggle_effects() {
    local wanted="$1"
    local target actual attempt fixed_apps
    target="$(selected_physical_sink)"
    [[ -n "$target" ]] || {
        json_error "No physical output is available"
        return 1
    }

    if [[ "$wanted" == "on" ]]; then
        start_easyeffects || {
            json_error "Could not start EasyEffects"
            return 1
        }
        # EasyEffects keeps bypass separately from its PipeWire route. Disable
        # bypass explicitly so "ligado" always means audible processing.
        select_output "$target" || return 1
        easyeffects -b 2 >/dev/null 2>&1 || {
            json_error "EasyEffects did not enable processing"
            return 1
        }
        actual="1"
        for attempt in {1..10}; do
            actual="$(easyeffects -b 3 2>/dev/null | head -n 1)"
            [[ "$actual" == "0" ]] && break
            sleep 0.1
        done
        [[ "$actual" == "0" ]] || {
            json_error "EasyEffects remained in bypass mode"
            return 1
        }
        json_ok "EasyEffects enabled; physical device preserved"
    else
        if pactl_json list sinks | jq -e --arg sink "$EE_SINK" 'any(.[]; .name == $sink)' >/dev/null; then
            fixed_apps="$(fixed_effect_streams)"
            if [[ -n "$fixed_apps" ]]; then
                json_error "$fixed_apps pinned the EasyEffects route. Stop audio in that app before turning effects off"
                return 1
            fi
            easyeffects -b 1 >/dev/null 2>&1 || {
                json_error "EasyEffects did not enter bypass mode"
                return 1
            }
            easyeffects -q >/dev/null 2>&1 || {
                json_error "Could not stop EasyEffects"
                return 1
            }
            wait_for_sink_to_disappear "$EE_SINK" || {
                json_error "EasyEffects entered bypass mode but remained open"
                return 1
            }
        fi
        select_output "$target" || return 1
        wait_for_stable_routes || true
        actual="$(orphaned_playback_apps)"
        [[ -z "$actual" ]] || {
            json_error "$actual could not leave the EasyEffects route; resume audio in the app"
            return 1
        }
        json_ok "EasyEffects disabled; physical output preserved"
    fi
}

profile_available() {
    local card="$1"
    local profile="$2"
    pactl_json list cards | jq -e --arg card "$card" --arg profile "$profile" '
        any(.[];
            .name == $card and
            (.profiles[$profile] != null) and
            ((.profiles[$profile] | has("available") | not) or
             (.profiles[$profile].available != false and
              .profiles[$profile].available != "no" and
              .profiles[$profile].available != "not available")))
    ' >/dev/null
}

set_profile() {
    local card="$1"
    local profile="$2"
    local previous_sink previous_source previous_output_port previous_input_port
    local target_sink target_source expected_sinks expected_sources profile_kind
    local active_profile fixed_apps orphan_apps attempt ready profile_incomplete

    profile_available "$card" "$profile" || {
        json_error "This profile is not available for the card"
        return 1
    }

    active_profile="$(pactl_json list cards | jq -r --arg card "$card" '
        .[] | select(.name == $card)
        | if (.active_profile | type) == "object"
          then (.active_profile.name // "")
          else (.active_profile // "") end
    ')"
    if [[ "$active_profile" == "$profile" ]]; then
        json_ok "This mode is already active"
        return 0
    fi

    # A stream created with node.dont-reconnect cannot be moved after its sink
    # disappears. Refuse the destructive transition instead of silently
    # stranding it; the local pipewire-pulse rule prevents this for new streams.
    fixed_apps="$(fixed_streams_for_card "$card")"
    if [[ -n "$fixed_apps" ]]; then
        json_error "$fixed_apps pinned the current output. Pause or reload audio in that app and try again"
        return 1
    fi

    read -r expected_sinks expected_sources profile_kind < <(
        pactl_json list cards | jq -r --arg card "$card" --arg profile "$profile" '
            .[] | select(.name == $card)
            | .profiles[$profile]
            | (.sinks // .["n-sinks"] // 0) as $outs
            | (.sources // .["n-sources"] // 0) as $ins
            | [$outs, $ins,
               (if $profile == "pro-audio" then "pro"
                elif $profile == "off" then "off"
                elif $outs > 0 and $ins > 0 then "duplex"
                elif $outs > 0 then "output"
                elif $ins > 0 then "input"
                else "other" end)] | @tsv
        '
    )

    previous_sink="$(selected_physical_sink)"
    previous_source="$(default_source)"
    previous_output_port="$(pactl_json list sinks | jq -r --arg card "$card" '
        [ .[] | select(.properties["device.name"] == $card) ][0].active_port // empty
    ')"
    previous_input_port="$(pactl_json list sources | jq -r --arg card "$card" '
        [ .[]
          | select(.properties["device.name"] == $card)
          | select(.name | endswith(".monitor") | not)
        ][0].active_port // empty
    ')"

    pactl set-card-profile "$card" "$profile" >/dev/null || {
        json_error "PipeWire refused the profile change"
        return 1
    }

    # ACP recreates nodes asynchronously. For Duplex, wait for both directions;
    # seeing only the microphone first does not mean the new profile is ready.
    target_sink=""
    target_source=""
    ready=false
    for attempt in {1..25}; do
        target_sink="$(sink_for_card "$card")"
        target_source="$(source_for_card "$card")"
        ready=true
        (( expected_sinks > 0 )) && [[ -z "$target_sink" ]] && ready=false
        (( expected_sources > 0 )) && [[ -z "$target_source" ]] && ready=false
        [[ "$ready" == "true" ]] && break
        sleep 0.1
    done
    profile_incomplete=false
    [[ "$ready" == "true" ]] || profile_incomplete=true

    if [[ -n "$target_sink" ]]; then
        if [[ -n "$previous_output_port" ]] && pactl_json list sinks | jq -e \
            --arg sink "$target_sink" --arg port "$previous_output_port" \
            'any(.[]; .name == $sink and any((.ports // [])[]; .name == $port))' >/dev/null; then
            pactl set-sink-port "$target_sink" "$previous_output_port" >/dev/null 2>&1 || true
        fi
        select_output "$target_sink" || return 1
    elif [[ -n "$previous_sink" ]] && physical_sink_exists "$previous_sink"; then
        select_output "$previous_sink" || return 1
    fi

    if [[ -n "$target_source" ]]; then
        if [[ -n "$previous_input_port" ]] && pactl_json list sources | jq -e \
            --arg source "$target_source" --arg port "$previous_input_port" \
            'any(.[]; .name == $source and any((.ports // [])[]; .name == $port))' >/dev/null; then
            pactl set-source-port "$target_source" "$previous_input_port" >/dev/null 2>&1 || true
        fi
        select_input "$target_source" || return 1
    elif [[ -n "$previous_source" ]] && physical_source_exists "$previous_source"; then
        select_input "$previous_source" || return 1
    fi

    if [[ "$profile_incomplete" == "true" ]]; then
        json_error "The mode changed, but PipeWire did not finish creating all inputs and outputs"
        return 1
    fi

    wait_for_stable_routes || true
    orphan_apps="$(orphaned_playback_apps)"
    if [[ -n "$orphan_apps" ]]; then
        json_error "Mode applied, but $orphan_apps must pause and resume audio"
        return 1
    fi
    orphan_apps="$(orphaned_recording_apps)"
    if [[ -n "$orphan_apps" ]]; then
        json_error "Mode applied, but $orphan_apps must stop and resume recording"
        return 1
    fi

    case "$profile_kind" in
        duplex) json_ok "Sound + microphone enabled; routes restored" ;;
        output) json_ok "Output only enabled; this card's microphone was disabled" ;;
        input) json_ok "Microphone only enabled; this card's output was disabled" ;;
        pro) json_ok "Pro Audio enabled" ;;
        off) json_ok "Audio card disabled" ;;
        *) json_ok "Audio mode applied" ;;
    esac
}

recommended_profile() {
    local card="$1"
    pactl_json list cards | jq -r --arg card "$card" '
        .[] | select(.name == $card)
        | .profiles
        | to_entries
        | map(. + {
            sinks: (.value.sinks // .value["n-sinks"] // 0),
            sources: (.value.sources // .value["n-sources"] // 0),
            available: ((.value | has("available") | not) or
                        (.value.available != false and
                         .value.available != "no" and
                         .value.available != "not available")),
            priority: (.value.priority // 0)
          })
        | map(select(.available != false))
        | map(select(.key != "pro-audio" and .key != "off"))
        | map(select(.key | contains("hdmi") | not))
        | map(select(.sinks > 0 and .sources > 0))
        | sort_by(.priority) | reverse | .[0].key // empty
    '
}

repair_audio() {
    local card profile active_profile active_sinks active_sources
    local target sink source orphan_apps orphan_recording_apps unsafe_cards

    # "Restore" means an everyday-safe state. Recover ALSA cards left in
    # Pro Audio, Off or one-direction-only modes even when Pro exposes a node.
    while IFS=$'\t' read -r card active_profile active_sinks active_sources; do
        [[ -n "$card" ]] || continue
        profile="$(recommended_profile "$card")"
        [[ -n "$profile" && "$profile" != "$active_profile" ]] || continue
        if [[ "$active_profile" == "pro-audio" || "$active_profile" == "off" ||
              "$active_sinks" == "0" || "$active_sources" == "0" ]]; then
            set_profile "$card" "$profile" >/dev/null || true
        fi
    done < <(pactl_json list cards | jq -r '
        .[]
        | select(.name | startswith("alsa_card."))
        | (if (.active_profile | type) == "object"
           then (.active_profile.name // "")
           else (.active_profile // "") end) as $active
        | (.profiles[$active] // {}) as $details
        | [.name, $active,
           ($details.sinks // $details["n-sinks"] // 0),
           ($details.sources // $details["n-sources"] // 0)] | @tsv
    ')

    unsafe_cards=""
    while IFS=$'\t' read -r card active_profile active_sinks active_sources; do
        [[ -n "$card" ]] || continue
        profile="$(recommended_profile "$card")"
        [[ -n "$profile" ]] || continue
        if [[ "$profile" != "$active_profile" ]] &&
           [[ "$active_profile" == "pro-audio" || "$active_profile" == "off" ||
              "$active_sinks" == "0" || "$active_sources" == "0" ]]; then
            unsafe_cards="${unsafe_cards:+$unsafe_cards, }$card"
        fi
    done < <(pactl_json list cards | jq -r '
        .[]
        | select(.name | startswith("alsa_card."))
        | (if (.active_profile | type) == "object"
           then (.active_profile.name // "")
           else (.active_profile // "") end) as $active
        | (.profiles[$active] // {}) as $details
        | [.name, $active,
           ($details.sinks // $details["n-sinks"] // 0),
           ($details.sources // $details["n-sources"] // 0)] | @tsv
    ')
    if [[ -n "$unsafe_cards" ]]; then
        json_error "Could not restore Sound + microphone mode; stop application audio and try again"
        return 1
    fi

    sink="$(selected_physical_sink)"
    source="$(first_physical_source "$(default_source)")"

    target="$sink"
    [[ -n "$target" ]] || {
        json_error "Could not find a physical output to restore"
        return 1
    }

    select_output "$target" || return 1
    if [[ -n "$source" ]] && physical_source_exists "$source"; then
        select_input "$source" || return 1
    fi

    wait_for_stable_routes || true
    orphan_apps="$(orphaned_playback_apps)"
    if [[ -n "$orphan_apps" ]]; then
        json_error "$orphan_apps kept an old route. Pause and resume audio in that app"
        return 1
    fi
    orphan_recording_apps="$(orphaned_recording_apps)"
    if [[ -n "$orphan_recording_apps" ]]; then
        json_error "$orphan_recording_apps kept an old input. Stop and resume recording in that app"
        return 1
    fi
    json_ok "Safe mode and physical routes restored"
}

set_output_port() {
    local sink="$1"
    local port="$2"
    physical_sink_exists "$sink" || {
        json_error "The output is no longer available"
        return 1
    }
    pactl set-sink-port "$sink" "$port" >/dev/null || {
        json_error "Could not activate this output port"
        return 1
    }
    select_output "$sink" || return 1
    json_ok "Output changed"
}

set_input_port() {
    local source="$1"
    local port="$2"
    physical_source_exists "$source" || {
        json_error "The microphone is no longer available"
        return 1
    }
    pactl set-source-port "$source" "$port" >/dev/null || {
        json_error "Could not activate this input"
        return 1
    }
    select_input "$source" || return 1
    json_ok "Microphone changed"
}

move_app() {
    local stream="$1"
    local sink="$2"
    physical_sink_exists "$sink" || {
        json_error "The selected output is no longer available"
        return 1
    }
    [[ "$stream" =~ ^[0-9]+$ ]] || {
        json_error "Invalid application"
        return 1
    }
    pactl move-sink-input "$stream" "$sink" >/dev/null || {
        json_error "Could not move the application"
        return 1
    }
    json_ok "Application moved to another output"
}

key_volume() {
    local operation="$1"
    local sink
    sink="$(selected_physical_sink)"
    [[ -n "$sink" ]] || return 1

    case "$operation" in
        raise|lower|mute-toggle|+1|-1) ;;
        *) return 1 ;;
    esac

    if command -v omarchy-swayosd-client >/dev/null 2>&1; then
        omarchy-swayosd-client --device "$sink" --max-volume 100 --output-volume "$operation"
    else
        case "$operation" in
            raise) pactl set-sink-volume "$sink" +5% ;;
            lower) pactl set-sink-volume "$sink" -5% ;;
            mute-toggle) pactl set-sink-mute "$sink" toggle ;;
            +1) pactl set-sink-volume "$sink" +1% ;;
            -1) pactl set-sink-volume "$sink" -1% ;;
        esac
    fi
}

key_input_mute() {
    local source
    source="$(first_physical_source "$(default_source)")"
    [[ -n "$source" ]] || return 1

    # Keep Omarchy's mic-mute LED behavior whenever the physical source is
    # already the default; otherwise target the physical source explicitly.
    if [[ "$(default_source)" == "$source" ]] && command -v omarchy-audio-input-mute >/dev/null 2>&1; then
        omarchy-audio-input-mute
    elif command -v omarchy-swayosd-client >/dev/null 2>&1; then
        omarchy-swayosd-client --device "$source" --input-volume mute-toggle
    else
        pactl set-source-mute "$source" toggle
    fi
}

next_output() {
    local current names_json count next_index next description
    current="$(selected_physical_sink)"
    names_json="$(pactl_json list sinks | jq -c --arg ee "$EE_SINK" '[
        .[]
        | select(.name != $ee)
        | select(.properties["node.virtual"] != "true")
        | select(.properties["application.id"] != "com.github.wwmm.easyeffects")
        | {name, description}
    ]')"
    count="$(jq 'length' <<<"$names_json")"
    (( count > 0 )) || return 1

    next_index="$(jq -r --arg current "$current" '
        (map(.name) | index($current)) as $index
        | if $index == null then 0 else (($index + 1) % length) end
    ' <<<"$names_json")"
    next="$(jq -r ".[$next_index].name" <<<"$names_json")"
    description="$(jq -r ".[$next_index].description // .[$next_index].name" <<<"$names_json")"

    select_output "$next" || return 1
    if command -v omarchy-swayosd-client >/dev/null 2>&1; then
        omarchy-swayosd-client --custom-message "$description" --custom-icon "audio-speakers-symbolic"
    fi
}

snapshot() (
    local tmp_dir selected_sink selected_source ee_bypass ee_preset ee_installed ee_running
    tmp_dir="$(mktemp -d)" || return 1
    trap 'rm -rf -- "$tmp_dir"' EXIT

    pactl_json info >"$tmp_dir/info.json" || return 1
    pactl_json list sinks >"$tmp_dir/sinks.json" || return 1
    pactl_json list sources >"$tmp_dir/sources.json" || return 1
    pactl_json list cards >"$tmp_dir/cards.json" || return 1
    pactl_json list sink-inputs >"$tmp_dir/sink-inputs.json" || printf '[]\n' >"$tmp_dir/sink-inputs.json"
    pactl_json list source-outputs >"$tmp_dir/source-outputs.json" || printf '[]\n' >"$tmp_dir/source-outputs.json"

    selected_sink="$(selected_physical_sink)"
    selected_source="$(first_physical_source "$(default_source)")"
    ee_bypass="1"
    ee_preset=""
    ee_installed="false"
    ee_running="false"
    if command -v easyeffects >/dev/null 2>&1; then
        ee_installed="true"
        if jq -e --arg sink "$EE_SINK" 'any(.[]; .name == $sink)' "$tmp_dir/sinks.json" >/dev/null; then
            ee_running="true"
            ee_bypass="$(easyeffects -b 3 2>/dev/null | head -n 1)"
            ee_preset="$(easyeffects -s 2>/dev/null | awk -F': ' '/^output:/ {print $2; exit}')"
        fi
    fi

    jq -n \
        --slurpfile info "$tmp_dir/info.json" \
        --slurpfile sinks "$tmp_dir/sinks.json" \
        --slurpfile sources "$tmp_dir/sources.json" \
        --slurpfile cards "$tmp_dir/cards.json" \
        --slurpfile playback "$tmp_dir/sink-inputs.json" \
        --slurpfile recording "$tmp_dir/source-outputs.json" \
        --arg eeSink "$EE_SINK" \
        --arg eeSource "$EE_SOURCE" \
        --arg selectedSink "$selected_sink" \
        --arg selectedSource "$selected_source" \
        --arg eeBypass "$ee_bypass" \
        --arg eePreset "$ee_preset" \
        --argjson eeInstalled "$ee_installed" \
        --argjson eeRunning "$ee_running" '
        def port_available:
            (.availability // "") as $a
            | ($a != "not available" and $a != "no");

        def profile_available($entry):
            (($entry.value | has("available") | not) or
             ($entry.value.available != false and
              $entry.value.available != "no" and
              $entry.value.available != "not available"));

        def active_port($device):
            [($device.ports // [])[] | select(.name == $device.active_port)][0] // {};

        def device_icon($device; $direction):
            (active_port($device).type // "" | ascii_downcase) as $type
            | if $type == "speaker" then "speaker"
              elif $type == "headphones" or $type == "headset" then "headphones"
              elif $type == "hdmi" or $type == "displayport" then "display"
              elif $type == "mic" or $type == "microphone" then "microphone"
              elif ($device.properties["device.bus"] // "") == "bluetooth" then "bluetooth"
              elif ($device.properties["device.bus"] // "") == "usb" then "usb"
              else $direction end;

        def device_label($device; $direction):
            active_port($device) as $port
            | ($device.properties["device.form_factor"] // "") as $form
            | ($device.properties["device.bus"] // "") as $bus
            | if $port.type == "Speaker" and $form == "internal" then "Laptop speakers"
              elif $port.type == "Speaker" then "Speakers"
              elif $port.type == "Headphones" then "Headphones"
              elif $port.type == "Mic" and ($port.name | contains("internal")) then "Internal microphone"
              elif $port.type == "Mic" then "External microphone"
              elif ($port.description // "") != "" then $port.description
              elif $bus == "bluetooth" then ($device.description // "Bluetooth audio")
              elif $bus == "usb" and $direction == "input" then ($device.description // "USB microphone")
              elif $bus == "usb" then ($device.description // "USB audio")
              else ($device.description // $device.name) end;

        def normal_device($device; $ee):
            $device.name != $ee and
            $device.properties["node.virtual"] != "true" and
            $device.properties["application.id"] != "com.github.wwmm.easyeffects";

        def profile_kind($entry):
            ($entry.value.sinks // $entry.value["n-sinks"] // 0) as $outs
            | ($entry.value.sources // $entry.value["n-sources"] // 0) as $ins
            | if $entry.key == "pro-audio" then "pro"
              elif $entry.key == "off" then "off"
              elif $outs > 0 and $ins > 0 then "duplex"
              elif $outs > 0 then "output"
              elif $ins > 0 then "input"
              else "other" end;

        def profile_title($entry):
            profile_kind($entry) as $kind
            | ($entry.value.description // $entry.key) as $description
            | if $kind == "duplex" and ($entry.key | contains("hdmi")) then "HDMI + microphone"
              elif $kind == "duplex" then "Sound + microphone"
              elif $kind == "output" and ($entry.key | contains("a2dp")) then "High-quality audio"
              elif $kind == "output" and ($entry.key | contains("hdmi")) then "Audio through monitor/TV"
              elif $kind == "output" then "Output only"
              elif $kind == "input" then "Microphone only"
              elif $kind == "pro" then "Pro Audio"
              elif $kind == "off" then "Disabled"
              else $description end;

        def active_profile_name($card):
            if ($card.active_profile | type) == "object"
            then ($card.active_profile.name // "")
            else ($card.active_profile // "")
            end;

        ($info[0]) as $i
        | ($sinks[0]) as $allSinks
        | ($sources[0]) as $allSources
        | {
            ok: true,
            defaultSink: ($i.default_sink_name // ""),
            defaultSource: ($i.default_source_name // ""),
            selectedSink: $selectedSink,
            selectedSource: $selectedSource,
            effects: {
                available: $eeInstalled,
                installed: $eeInstalled,
                running: $eeRunning,
                invalidDefault: (($i.default_sink_name // "") == $eeSink),
                bypassed: ($eeBypass != "0"),
                enabled: ($eeRunning and $eeBypass == "0"),
                preset: $eePreset
            },
            sinks: [
                $allSinks[]
                | select(normal_device(.; $eeSink))
                | . as $device
                | {
                    id: .index,
                    name: .name,
                    label: device_label($device; "output"),
                    description: (.description // .name),
                    icon: device_icon($device; "output"),
                    state: (.state // ""),
                    card: (.properties["device.name"] // ""),
                    activePort: (.active_port // ""),
                    technical: (.name | contains(".pro-")),
                    ports: [(.ports // [])[] | {
                        name: .name,
                        label: (if .type == "Speaker" and (.name | contains("speaker")) then "Laptop speakers"
                                elif .type == "Speaker" then "Speakers"
                                elif .type == "Headphones" then "Headphones"
                                elif .type == "Mic" and (.name | contains("internal")) then "Internal microphone"
                                elif .type == "Mic" then "External microphone"
                                else (.description // .name) end),
                        type: (.type // ""),
                        availability: (.availability // "unknown"),
                        available: port_available,
                        active: (.name == $device.active_port)
                    }],
                    isSelected: (.name == $selectedSink)
                }
            ],
            sources: [
                $allSources[]
                | select(normal_device(.; $eeSource))
                | select(.name | endswith(".monitor") | not)
                | select(.properties["device.class"] != "monitor")
                | . as $device
                | {
                    id: .index,
                    name: .name,
                    label: device_label($device; "input"),
                    description: (.description // .name),
                    icon: device_icon($device; "input"),
                    state: (.state // ""),
                    card: (.properties["device.name"] // ""),
                    activePort: (.active_port // ""),
                    technical: (.name | contains(".pro-")),
                    ports: [(.ports // [])[] | {
                        name: .name,
                        label: (if .type == "Speaker" then "Speakers"
                                elif .type == "Headphones" then "Headphones"
                                elif .type == "Mic" and (.name | contains("internal")) then "Internal microphone"
                                elif .type == "Mic" then "External microphone"
                                else (.description // .name) end),
                        type: (.type // ""),
                        availability: (.availability // "unknown"),
                        available: port_available,
                        active: (.name == $device.active_port)
                    }],
                    isSelected: (.name == $selectedSource)
                }
            ],
            cards: [
                $cards[0][]
                | . as $card
                | {
                    name: .name,
                    label: (.properties["device.description"] // .name),
                    active: active_profile_name($card),
                    profiles: [
                        (.profiles // {} | to_entries[])
                        | select(profile_available(.))
                        | . as $entry
                        | {
                            key: .key,
                            title: profile_title($entry),
                            description: (.value.description // .key),
                            kind: profile_kind($entry),
                            priority: (.value.priority // 0),
                            recommended: (profile_kind($entry) == "duplex" and (.key | contains("hdmi") | not)),
                            active: (.key == active_profile_name($card))
                        }
                    ] | sort_by(.priority) | reverse
                }
            ],
            playback: [
                $playback[0][]
                | select(.properties["application.id"] != "com.github.wwmm.easyeffects")
                | select(.properties["application.name"] != "Quickshell Peak Detect")
                | select((.properties["application.name"] // "") | test("easy ?effects"; "i") | not)
                | . as $stream
                | {
                    index: .index,
                    app: (.properties["application.name"] // "Application"),
                    media: (.properties["media.name"] // ""),
                    sink: .sink,
                    sinkName: (([ $allSinks[] | select(.index == $stream.sink) | .name ][0] // "") as $route
                               | if $route == $eeSink then $selectedSink else $route end),
                    orphaned: (.sink == 4294967295)
                }
            ],
            recording: [
                $recording[0][]
                | select(.properties["application.id"] != "com.github.wwmm.easyeffects")
                | select(.properties["application.name"] != "Quickshell Peak Detect")
                | select((.properties["application.name"] // "") | test("easy ?effects"; "i") | not)
                | . as $stream
                | ([ $allSources[] | select(.index == $stream.source) ][0] // null) as $source
                | {
                    index: .index,
                    app: (.properties["application.name"] // "Application"),
                    media: (.properties["media.name"] // ""),
                    source: .source,
                    sourceName: ($source.name // ""),
                    isMonitor: ($source != null and (
                        (($source.name // "") | endswith(".monitor")) or
                        $source.properties["device.class"] == "monitor")),
                    orphaned: (.source == 4294967295)
                }
            ]
        }
    '
)

main() {
    local command="${1:-snapshot}" orphan_apps
    shift || true

    require_audio_server || return 1

    case "$command" in
        snapshot)
            snapshot || json_error "Could not read audio state"
            ;;
        set-output)
            [[ $# -eq 1 ]] || { json_error "Invalid output"; return 1; }
            if select_output "$1"; then
                wait_for_stable_routes || true
                orphan_apps="$(orphaned_playback_apps)"
                if [[ -n "$orphan_apps" ]]; then
                    json_error "Output changed, but $orphan_apps must pause and resume audio"
                    return 1
                fi
                json_ok "Output changed and applications reconnected"
            else
                return 1
            fi
            ;;
        set-input)
            [[ $# -eq 1 ]] || { json_error "Invalid input"; return 1; }
            select_input "$1" && json_ok "Microphone changed"
            ;;
        set-output-port)
            [[ $# -eq 2 ]] || { json_error "Invalid output port"; return 1; }
            set_output_port "$1" "$2"
            ;;
        set-input-port)
            [[ $# -eq 2 ]] || { json_error "Invalid input port"; return 1; }
            set_input_port "$1" "$2"
            ;;
        move-app)
            [[ $# -eq 2 ]] || { json_error "Invalid application route"; return 1; }
            move_app "$1" "$2"
            ;;
        set-profile)
            [[ $# -eq 2 ]] || { json_error "Invalid profile"; return 1; }
            set_profile "$1" "$2"
            ;;
        effects)
            [[ "${1:-}" == "on" || "${1:-}" == "off" ]] || {
                json_error "Invalid EasyEffects state"
                return 1
            }
            toggle_effects "$1"
            ;;
        repair)
            repair_audio
            ;;
        key-volume)
            [[ $# -eq 1 ]] || return 1
            key_volume "$1"
            ;;
        key-input-mute)
            key_input_mute
            ;;
        next-output)
            next_output
            ;;
        *)
            json_error "Unknown audio command"
            return 1
            ;;
    esac
}

main "$@"
