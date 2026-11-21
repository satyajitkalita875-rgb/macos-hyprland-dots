#!/usr/bin/env bash
set -euo pipefail

addr="$(hyprctl clients -j | jq -r '[.[] | select(.workspace.name == "special:minimized")] | last | .address // empty')"
ws="$(hyprctl activeworkspace -j | jq -r '.id // empty')"

if [ -n "$addr" ] && [ -n "$ws" ]; then
    hyprctl dispatch movetoworkspace "${ws},address:${addr}"
    hyprctl dispatch focuswindow "address:${addr}"
fi
