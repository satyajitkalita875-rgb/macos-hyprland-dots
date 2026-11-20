#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
WALL_DIR="$HOME/Pictures/Wallpapers"

backup_and_copy() {
    local src="$1"
    local dst="$2"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mkdir -p "$BACKUP_DIR"
        cp -a "$dst" "$BACKUP_DIR/" 2>/dev/null || true
    fi
    mkdir -p "$(dirname "$dst")"
    rm -rf "$dst"
    cp -a "$src" "$dst"
}

echo "==> Installing Hyprland, Quickshell, Matugen, UWSM & Illogical Impulse configs..."
backup_and_copy "$REPO_DIR/config/hypr" "$HOME/.config/hypr"
backup_and_copy "$REPO_DIR/config/quickshell/end4-pC" "$HOME/.config/quickshell/end4-pC"
backup_and_copy "$REPO_DIR/config/matugen" "$HOME/.config/matugen"
backup_and_copy "$REPO_DIR/config/uwsm" "$HOME/.config/uwsm"
backup_and_copy "$REPO_DIR/config/illogical-impulse" "$HOME/.config/illogical-impulse"

# Expand $HOME placeholders in config.json for the current user
sed -i "s|__HOME__|$HOME|g" "$HOME/.config/illogical-impulse/config.json"

# Ensure scripts are executable
chmod +x "$HOME/.config/quickshell/end4-pC/scripts/scan-apps.py" \
         "$HOME/.config/quickshell/end4-pC/scripts/icon-resolve.py" \
         "$HOME/.config/quickshell/end4-pC/scripts/colors/switchwall.sh" \
         "$HOME/.config/quickshell/end4-pC/scripts/colors/applycolor.sh" 2>/dev/null || true

mkdir -p "$HOME/.config/hypr/custom/scripts" "$WALL_DIR"
cp -n "$REPO_DIR/wallpapers/"* "$WALL_DIR/" 2>/dev/null || true

# Download 6K macOS Tahoe Light wallpaper if not present
TAHOE_WALL="$WALL_DIR/macOS-Tahoe-Light.png"
if [ ! -f "$TAHOE_WALL" ]; then
    echo "==> Downloading macOS Tahoe Light (6K) wallpaper..."
    curl -fSL -o "$TAHOE_WALL" "https://media.512pixels.net/downloads/macos-wallpapers-6k/26-Tahoe-Light-6K.png" || true
fi

# Ensure ~/.config/gtk-4.0/gtk.css is writable for matugen (not a read-only symlink)
if [ -L "$HOME/.config/gtk-4.0/gtk.css" ]; then
    rm -f "$HOME/.config/gtk-4.0/gtk.css"
fi

if [ -f "$TAHOE_WALL" ]; then
    echo "==> Applying wallpaper & Material You colors..."
    bash "$HOME/.config/quickshell/end4-pC/scripts/colors/switchwall.sh" --image "$TAHOE_WALL" || true
fi

echo "==> Reloading Hyprland & Quickshell..."
hyprctl reload 2>/dev/null || true
killall qs 2>/dev/null || true
sleep 0.4
setsid qs -c end4-pC >/tmp/qs.log 2>&1 < /dev/null &
disown

echo "Done! Backups (if any) saved in: $BACKUP_DIR"
