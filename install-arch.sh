#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo "Error: Please run this script as your normal user (not root)."
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo "Error: 'pacman' was not found. This installer is intended for Arch / CachyOS."
    echo "On Fedora, run './install-fedora.sh' (or './setup.sh')."
    exit 1
fi

echo "==> Checking Arch / CachyOS environment..."
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "    Detected: ${PRETTY_NAME:-Arch Linux}"
fi

echo "==> Refreshing pacman package databases..."
sudo pacman -Sy --noconfirm

DESIRED_PKGS=(
    # Core Hyprland + Quickshell + Matugen
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
    # Qt6 / QML / Kirigami
    qt6-declarative
    qt6-svg
    qt6-5compat
    qt6-wayland
    qt6-multimedia
    qt6-imageformats
    qt6-positioning
    qt6ct
    qt5ct
    kirigami
    qqc2-desktop-style
    # Wayland utilities, media, thumbnails & system services
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
    imagemagick
    libvips
    ffmpeg
    libnotify
    pavucontrol
    networkmanager
    bluez
    bluez-utils
    pipewire
    wireplumber
    upower
    polkit
    xorg-xhost
    # Default apps, themes, icons, fonts & build tools
    kitty
    btop
    nautilus
    gnome-text-editor
    gnome-calculator
    adw-gtk-theme
    adwaita-icon-theme
    breeze-icons
    noto-fonts
    noto-fonts-emoji
    ttf-jetbrains-mono-nerd
    sddm
    base-devel
)

# Filter to packages available in enabled pacman repositories so a missing AUR package never aborts pacman
declare -A REPO_INDEX=()
while IFS= read -r pkg; do
    REPO_INDEX["$pkg"]=1
done < <(pacman -Slq)

REPO_PKGS=()
MISSING_PKGS=()
for pkg in "${DESIRED_PKGS[@]}"; do
    if [ -n "${REPO_INDEX[$pkg]:-}" ]; then
        REPO_PKGS+=("$pkg")
    else
        MISSING_PKGS+=("$pkg")
    fi
done

if [ "${#REPO_PKGS[@]}" -gt 0 ]; then
    echo "==> Installing ${#REPO_PKGS[@]} packages from official/enabled repositories..."
    sudo pacman -S --needed --noconfirm "${REPO_PKGS[@]}"
fi

# Install any missing core packages (e.g. quickshell, matugen on vanilla Arch) from the AUR automatically
AUR_NEEDED=()
command -v qs >/dev/null 2>&1 || command -v quickshell >/dev/null 2>&1 || AUR_NEEDED+=("quickshell")
command -v matugen >/dev/null 2>&1 || AUR_NEEDED+=("matugen-bin")

if [ "${#AUR_NEEDED[@]}" -gt 0 ]; then
    echo "==> Installing AUR packages (${AUR_NEEDED[*]})..."
    AUR_HELPER=""
    if command -v paru >/dev/null 2>&1; then
        AUR_HELPER="paru"
    elif command -v yay >/dev/null 2>&1; then
        AUR_HELPER="yay"
    else
        echo "==> Bootstrapping yay-bin AUR helper automatically..."
        TMP_YAY="$(mktemp -d /tmp/yay-bin-XXXXXX)"
        if git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$TMP_YAY"; then
            (cd "$TMP_YAY" && makepkg -si --noconfirm --needed) || true
        fi
        rm -rf "$TMP_YAY"
        command -v yay >/dev/null 2>&1 && AUR_HELPER="yay"
    fi

    if [ -n "$AUR_HELPER" ]; then
        for aur_pkg in "${AUR_NEEDED[@]}"; do
            if ! "$AUR_HELPER" -S --needed --noconfirm "$aur_pkg"; then
                case "$aur_pkg" in
                    quickshell) "$AUR_HELPER" -S --needed --noconfirm quickshell-git || true ;;
                    matugen-bin) "$AUR_HELPER" -S --needed --noconfirm matugen || true ;;
                esac
            fi
        done
    else
        echo "Warning: Could not install AUR helper automatically; install ${AUR_NEEDED[*]} manually."
    fi
fi

# Enable networking & bluetooth services if installed
systemctl list-unit-files NetworkManager.service >/dev/null 2>&1 && sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
systemctl list-unit-files bluetooth.service >/dev/null 2>&1 && sudo systemctl enable --now bluetooth.service 2>/dev/null || true

# Install Bibata-Modern-Ice cursor theme if not present
CURSOR_DIR="$HOME/.local/share/icons/Bibata-Modern-Ice"
if [ ! -d "$CURSOR_DIR" ] && [ ! -d "/usr/share/icons/Bibata-Modern-Ice" ]; then
    echo "==> Installing Bibata-Modern-Ice cursor theme..."
    mkdir -p "$HOME/.local/share/icons"
    TMP_TAR="$(mktemp /tmp/bibata-XXXXXX.tar.xz)"
    if curl -fsSL -o "$TMP_TAR" "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz"; then
        tar -xf "$TMP_TAR" -C "$HOME/.local/share/icons/" || true
    else
        echo "    Could not download Bibata-Modern-Ice cursor theme (continuing with system cursor)."
    fi
    rm -f "$TMP_TAR"
fi

echo "==> Deploying dotfiles & wallpapers..."
bash "$REPO_DIR/install.sh"

echo "==> Installing & enabling SDDM display manager with macOS Hyprland theme..."
bash "$REPO_DIR/install-sddm.sh"

echo ""
echo "=================================================================="
echo " Arch / CachyOS macOS Hyprland setup complete!"
echo " Next steps:"
echo "   1. Reboot (or log out) to enter the macOS-themed SDDM login screen."
echo "   2. Select 'Hyprland' (or 'Hyprland (uwsm-managed)') and log in."
echo "   3. Shortcuts: Super+G (App Drawer), Super+X (Control Center),"
echo "      Super+Space (Spotlight), Super+Shift+W (Wallpaper Selector),"
echo "      Super+Z (Settings)."
echo "=================================================================="
