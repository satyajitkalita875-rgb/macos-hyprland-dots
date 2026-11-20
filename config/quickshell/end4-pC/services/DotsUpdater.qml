pragma Singleton

import qs
import QtQuick
import Quickshell

Singleton {
    id: root

    function runSystemUpdate() {
        Quickshell.execDetached([
            "kitty", "--hold",
            "fish", "-i", "-l", "-c",
            "if type -q yay; yay -Syu --combinedupgrade=false; else if type -q paru; paru -Syu; else; sudo pacman -Syu; end"
        ])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }

    // Safeguarded: never overwrite custom macOS dotfiles with upstream pctrade/end4-pC.
    function runUpdateDots() {
        Quickshell.execDetached([
            "notify-send",
            "Custom macOS Setup",
            "Upstream auto-overwrite is disabled to protect your custom configuration. Use git in your dotfiles repo to manage updates.",
            "-a", "Shell"
        ])
        Quickshell.reload(true)
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }
}
