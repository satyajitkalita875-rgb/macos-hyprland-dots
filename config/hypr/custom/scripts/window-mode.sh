#!/usr/bin/env bash
set -euo pipefail

MODE_FILE="$HOME/.config/hypr/window-mode.conf"
ACTION="${1:-toggle}"

current_mode() {
    if [ -f "$MODE_FILE" ] && grep -qE '^\s*windowrule\s*=.*float\s+1' "$MODE_FILE"; then
        echo "stacking"
    else
        echo "tiling"
    fi
}

if [ "$ACTION" = "status" ]; then
    current_mode
    exit 0
fi

if [ "$ACTION" = "toggle" ]; then
    if [ "$(current_mode)" = "stacking" ]; then
        ACTION="tiling"
    else
        ACTION="stacking"
    fi
fi

case "$ACTION" in
    tiling)
        cat > "$MODE_FILE" <<'EOF'
# Managed by ~/.config/hypr/custom/scripts/window-mode.sh
# Mode: tiling
EOF
        hyprctl reload >/dev/null

        batch="$(hyprctl clients -j | jq -r '
            .[]
            | select(
                .mapped == true
                and .floating == true
                and .pinned == false
                and .class != ""
                and .workspace.name != "special:minimized"
            )
            | "dispatch settiled address:\(.address)"
        ' | paste -sd ';' -)"

        if [ -n "$batch" ]; then
            hyprctl --batch "$batch" >/dev/null
        fi

        if command -v notify-send >/dev/null 2>&1; then
            notify-send -t 2000 \
                -h string:x-canonical-private-synchronous:hypr-window-mode \
                "Window Mode: Tiling" \
                "Windows tiled; new windows will open tiled."
        fi
        ;;

    stacking)
        cat > "$MODE_FILE" <<'EOF'
# Managed by ~/.config/hypr/custom/scripts/window-mode.sh
# Mode: stacking
windowrule = match:class .*, float 1
EOF
        hyprctl reload >/dev/null

        batch="$(hyprctl clients -j | jq -r '
            .[]
            | select(
                .mapped == true
                and .floating == false
                and .class != ""
                and .workspace.name != "special:minimized"
            )
            | "dispatch setfloating address:\(.address)"
        ' | paste -sd ';' -)"

        if [ -n "$batch" ]; then
            hyprctl --batch "$batch" >/dev/null
        fi

        if command -v notify-send >/dev/null 2>&1; then
            notify-send -t 2000 \
                -h string:x-canonical-private-synchronous:hypr-window-mode \
                "Window Mode: Stacking" \
                "Windows floating; new windows will open floating."
        fi
        ;;

    *)
        echo "Usage: $0 {tiling|stacking|toggle|status}" >&2
        exit 1
        ;;
esac
