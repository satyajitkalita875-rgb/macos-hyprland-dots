#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v dnf >/dev/null 2>&1; then
    echo "Error: 'dnf' was not found. This installer is intended for Fedora Linux."
    echo "On Arch / CachyOS, run './install.sh' directly."
    exit 1
fi

echo "==> Checking Fedora environment..."
if [ -r /etc/os-release ]; then
    . /etc/os-release
    echo "    Detected: ${PRETTY_NAME:-Fedora}"
fi

echo "==> Enabling required Fedora COPR repositories..."
# Hyprland 0.57+ (HyprLua) + Hypr ecosystem
if ! sudo dnf copr enable -y lionheartp/Hyprland; then
    echo "    Fallback: trying solopasha/hyprland COPR..."
    sudo dnf copr enable -y solopasha/hyprland || true
fi

# Quickshell (Qt6/QML Wayland shell)
sudo dnf copr enable -y errornointernet/quickshell || true

# Matugen (Material You color generator)
sudo dnf copr enable -y avengemedia/danklinux || true

echo "==> Installing Hyprland, Quickshell, Matugen & desktop dependencies..."
CORE_PKGS=(
    hyprland
    hyprlock
    hypridle
    hyprsunset
    hyprpicker
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    quickshell
    matugen
    uwsm
)

QT_QML_PKGS=(
    qt6-qt5compat
    qt6-qtdeclarative
    qt6-qtsvg
    qt6-qtwayland
    qt6-qtmultimedia
    qt6-qtimageformats
    qt6-qtpositioning
    kf6-kirigami
    kf6-qqc2-desktop-style
    qt6ct
    qt5ct
)

WAYLAND_UTILS=(
    grim
    slurp
    wl-clipboard
    cliphist
    wf-recorder
    brightnessctl
    ddcutil
    playerctl
    jq
    curl
    git
    rsync
    unzip
    tar
    ImageMagick
    vips-tools
    ffmpeg-free
    libnotify
    pavucontrol
    NetworkManager
    bluez
    pipewire
    wireplumber
    upower
    polkit
    xhost
)

PYTHON_PKGS=(
    python3
    python3-pillow
    python3-gobject
    python3-numpy
    python3-opencv
    python3-tqdm
    python3-click
)

APPS_AND_THEMES=(
    kitty
    btop
    nautilus
    gnome-text-editor
    gnome-calculator
    adw-gtk3-theme
    adwaita-icon-theme
    breeze-icon-theme
    google-noto-sans-fonts
    google-noto-emoji-fonts
    jetbrains-mono-fonts
)

sudo dnf install -y --skip-unavailable \
    "${CORE_PKGS[@]}" \
    "${QT_QML_PKGS[@]}" \
    "${WAYLAND_UTILS[@]}" \
    "${PYTHON_PKGS[@]}" \
    "${APPS_AND_THEMES[@]}"

# Fallback: if matugen wasn't available via COPR, advise or install via cargo if present
if ! command -v matugen >/dev/null 2>&1; then
    echo "Warning: 'matugen' was not installed from COPR."
    if command -v cargo >/dev/null 2>&1; then
        echo "==> Installing matugen via cargo..."
        cargo install matugen || true
    else
        echo "    Install matugen manually via 'sudo dnf install cargo && cargo install matugen'"
        echo "    or download a prebuilt binary from https://github.com/InioX/matugen/releases"
    fi
fi

# Install Bibata-Modern-Ice cursor theme if not present
CURSOR_DIR="$HOME/.local/share/icons/Bibata-Modern-Ice"
if [ ! -d "$CURSOR_DIR" ]; then
    echo "==> Installing Bibata-Modern-Ice cursor theme..."
    mkdir -p "$HOME/.local/share/icons"
    TMP_TAR="$(mktemp /tmp/bibata-XXXXXX.tar.xz)"
    if curl -fSL -o "$TMP_TAR" "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz"; then
        tar -xf "$TMP_TAR" -C "$HOME/.local/share/icons/" || true
    else
        echo "    Could not download Bibata-Modern-Ice cursor theme (continuing with system cursor)."
    fi
    rm -f "$TMP_TAR"
fi

# Verify Hyprland 0.57+ (HyprLua support)
if command -v hyprland >/dev/null 2>&1; then
    HL_VER="$(hyprland --version 2>/dev/null | head -n1 || true)"
    echo "==> Installed Hyprland: $HL_VER"
    if echo "$HL_VER" | grep -qE '0\.([0-4][0-9]|5[0-6])\.'; then
        echo ""
        echo "WARNING: Detected Hyprland < 0.57!"
        echo "This dotfiles setup uses Hyprland 0.57+ native HyprLua (hyprland.lua)."
        echo "Please ensure you have a COPR enabled that provides Hyprland 0.57+ (e.g. lionheartp/Hyprland)."
        echo ""
    fi
else
    echo "Warning: 'hyprland' binary not found in PATH after dnf install."
fi

echo "==> Deploying dotfiles..."
bash "$REPO_DIR/install.sh"

echo "==> Installing & enabling SDDM display manager with macOS Hyprland theme..."
bash "$REPO_DIR/install-sddm.sh"

echo ""
echo "=================================================================="
echo " Fedora macOS Hyprland setup complete!"
echo " Next steps:"
echo "   1. Reboot (or log out) to enter the macOS-themed SDDM login screen."
echo "   2. Select 'Hyprland' (or 'Hyprland (uwsm-managed)') at the top-right"
echo "      session selector and log in."
echo "   3. Press Super + G for App Drawer, Super + X for Control Center,"
echo "      Super + Space for Spotlight, and Super + Z for Settings."
echo "=================================================================="
