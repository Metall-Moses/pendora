#!/usr/bin/env bash
# apply-gnome-keyboard-layout.sh - Detect GNOME/system keyboard layout and apply to Sway
set -euo pipefail

detect_keyboard_layout() {
    local target_user="${1:-$USER}"
    local sources=""
    local layouts=()
    local variants=()

    # 1. Query GNOME desktop input-sources
    if [ -n "$target_user" ]; then
        sources="$(sudo -u "$target_user" gsettings get org.gnome.desktop.input-sources sources 2>/dev/null || true)"
    fi
    if [ -z "$sources" ] && command -v gsettings &>/dev/null; then
        sources="$(gsettings get org.gnome.desktop.input-sources sources 2>/dev/null || true)"
    fi

    # 2. Query localectl status if gsettings was empty
    local x11_layout=""
    local x11_variant=""
    if [ -z "$sources" ] || [ "$sources" = "@a(ss) []" ]; then
        if command -v localectl &>/dev/null; then
            x11_layout="$(localectl status 2>/dev/null | awk -F: '/X11 Layout/ {gsub(/^[ \t]+/, "", $2); print $2}')"
            x11_variant="$(localectl status 2>/dev/null | awk -F: '/X11 Variant/ {gsub(/^[ \t]+/, "", $2); print $2}')"
        fi
        if [ -z "$x11_layout" ] && [ -f /etc/vconsole.conf ]; then
            x11_layout="$(grep '^KEYMAP=' /etc/vconsole.conf 2>/dev/null | cut -d= -f2 | tr -d '"'"'" || true)"
        fi
    fi

    # If gsettings had sources, parse them
    if [ -n "$sources" ] && [ "$sources" != "@a(ss) []" ]; then
        for item in $(echo "$sources" | grep -oP "'xkb',\s*'\K[^']+"); do
            [ -z "$item" ] && continue
            if [[ "$item" == *"+"* ]]; then
                layouts+=("${item%%+*}")
                variants+=("${item#*+}")
            else
                layouts+=("$item")
                variants+=("")
            fi
        done
    fi

    local final_layout=""
    local final_variant=""
    if [ ${#layouts[@]} -gt 0 ]; then
        final_layout="$(IFS=,; echo "${layouts[*]}")"
        final_variant="$(IFS=,; echo "${variants[*]}")"
    elif [ -n "$x11_layout" ]; then
        final_layout="$x11_layout"
        final_variant="$x11_variant"
    else
        final_layout="us"
    fi

    echo "$final_layout|$final_variant"
}

parsed="$(detect_keyboard_layout)"
layout="${parsed%%|*}"
variant="${parsed#*|}"

[ -z "$layout" ] && layout="us"

# Apply dynamically to running Sway session
if command -v swaymsg &>/dev/null && [ -n "${SWAYSOCK:-}" ]; then
    swaymsg input "type:keyboard" xkb_layout "$layout" 2>/dev/null || true
    if [ -n "$variant" ]; then
        swaymsg input "type:keyboard" xkb_variant "$variant" 2>/dev/null || true
    fi
    if [[ "$layout" == *","* ]]; then
        swaymsg input "type:keyboard" xkb_options "grp:alt_shift_toggle" 2>/dev/null || true
    fi
fi
