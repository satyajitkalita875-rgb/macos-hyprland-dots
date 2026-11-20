pragma Singleton

import qs
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string dotsRepoUrl: "https://github.com/satyajitkalita875-rgb/macos-hyprland-dots.git"

    function runSystemUpdate() {
        Quickshell.execDetached([
            "kitty", "--hold",
            "bash", "-lc",
            "if command -v dnf >/dev/null 2>&1; then sudo dnf upgrade --refresh; elif command -v yay >/dev/null 2>&1; then yay -Syu --combinedupgrade=false; elif command -v paru >/dev/null 2>&1; then paru -Syu; elif command -v pacman >/dev/null 2>&1; then sudo pacman -Syu; fi"
        ])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }

    function runUpdateDots() {
        const updateScript = `
            set -e
            REPO_DIR="$HOME/Projects/macos-hyprland-dots"
            REPO_URL="${root.dotsRepoUrl}"

            if [ -d "$REPO_DIR/.git" ]; then
                echo "==> Pulling latest updates from $REPO_URL..."
                git -C "$REPO_DIR" pull --ff-only
            else
                echo "==> Cloning $REPO_URL..."
                mkdir -p "$(dirname "$REPO_DIR")"
                git clone "$REPO_URL" "$REPO_DIR"
            fi

            echo "==> Applying dotfiles..."
            bash "$REPO_DIR/install.sh"
        `

        Quickshell.execDetached(["kitty", "--hold", "bash", "-c", updateScript])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }
}
