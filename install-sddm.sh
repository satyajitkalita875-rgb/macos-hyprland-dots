#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_SRC="$REPO_DIR/sddm/macos-hyprland"
THEME_DST="/usr/share/sddm/themes/macos-hyprland"
WALL_TAHOE="$HOME/Pictures/Wallpapers/macOS-Tahoe-Light.png"
WALL_FALLBACK="$REPO_DIR/wallpapers/macOS-Sequoia-Light.jpg"

echo "==> Installing SDDM (Display Manager)..."
if command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm sddm qt6-declarative qt6-svg qt6-5compat
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y --skip-unavailable sddm qt6-qtdeclarative qt6-qtsvg qt6-qt5compat
else
    echo "Warning: Unsupported package manager; ensure 'sddm' and Qt6 QML packages are installed."
fi

echo "==> Installing macOS Hyprland SDDM theme to $THEME_DST..."
sudo mkdir -p "$THEME_DST"
sudo cp -a "$THEME_SRC/." "$THEME_DST/"

# Download Tahoe wallpaper if not yet present, then copy into theme directory
if [ ! -f "$WALL_TAHOE" ]; then
    mkdir -p "$(dirname "$WALL_TAHOE")"
    echo "==> Downloading macOS Tahoe Light wallpaper for SDDM..."
    curl -fSL -o "$WALL_TAHOE" "https://media.512pixels.net/downloads/macos-wallpapers-6k/26-Tahoe-Light-6K.png" || true
fi

if [ -f "$WALL_TAHOE" ]; then
    sudo cp "$WALL_TAHOE" "$THEME_DST/background.png"
elif [ -f "$WALL_FALLBACK" ]; then
    sudo cp "$WALL_FALLBACK" "$THEME_DST/background.png"
fi

sudo chmod -R a+rX "$THEME_DST"

# Make Bibata-Modern-Ice cursor available system-wide for SDDM if installed in user home
if [ -d "$HOME/.local/share/icons/Bibata-Modern-Ice" ] && [ ! -d "/usr/share/icons/Bibata-Modern-Ice" ]; then
    echo "==> Installing Bibata-Modern-Ice cursor theme system-wide for SDDM..."
    sudo mkdir -p /usr/share/icons
    sudo cp -a "$HOME/.local/share/icons/Bibata-Modern-Ice" /usr/share/icons/
    sudo chmod -R a+rX /usr/share/icons/Bibata-Modern-Ice
fi

echo "==> Configuring SDDM (/etc/sddm.conf.d/10-macos-hyprland.conf)..."
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/10-macos-hyprland.conf >/dev/null <<'EOF'
[Theme]
Current=macos-hyprland
CursorTheme=Bibata-Modern-Ice
CursorSize=24

[General]
InputMethod=
EOF

echo "==> Enabling sddm.service as the display manager..."
sudo systemctl enable -f sddm.service

echo ""
echo "Done! SDDM is enabled with the 'macos-hyprland' theme."
echo "Preview it anytime with:"
echo "  sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/macos-hyprland"
echo "On next reboot, SDDM will appear automatically and let you log into Hyprland."
