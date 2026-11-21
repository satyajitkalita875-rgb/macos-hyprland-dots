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

backup_and_copy_file() {
    local src="$1"
    local dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mkdir -p "$BACKUP_DIR/$(basename "$(dirname "$dst")")"
        cp -a "$dst" "$BACKUP_DIR/$(basename "$(dirname "$dst")")/" 2>/dev/null || true
    fi
    cp -a "$src" "$dst"
}

# Helpful check if running on Fedora without dependencies installed yet
if [ -r /etc/os-release ] && grep -qiE '^ID=fedora|^ID_LIKE=.*fedora' /etc/os-release; then
    missing_core=()
    for cmd in hyprland qs matugen; do
        command -v "$cmd" >/dev/null 2>&1 || missing_core+=("$cmd")
    done
    if [ ${#missing_core[@]} -gt 0 ]; then
        echo "Warning: Missing core Fedora packages (${missing_core[*]})."
        echo "Tip: Run './install-fedora.sh' first to install COPR repos and dependencies automatically."
    fi
fi

echo "==> Installing Hyprland, Quickshell, Matugen, UWSM & Illogical Impulse configs..."
backup_and_copy "$REPO_DIR/config/hypr" "$HOME/.config/hypr"
backup_and_copy "$REPO_DIR/config/quickshell/end4-pC" "$HOME/.config/quickshell/end4-pC"
backup_and_copy "$REPO_DIR/config/matugen" "$HOME/.config/matugen"
backup_and_copy "$REPO_DIR/config/uwsm" "$HOME/.config/uwsm"
backup_and_copy "$REPO_DIR/config/illogical-impulse" "$HOME/.config/illogical-impulse"

# Install GTK3/GTK4 settings (macOS traffic-light button layout & adw-gtk3 theme) without clobbering gtk.css
if [ -f "$REPO_DIR/config/gtk-3.0/settings.ini" ]; then
    backup_and_copy_file "$REPO_DIR/config/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
fi
if [ -f "$REPO_DIR/config/gtk-4.0/settings.ini" ]; then
    backup_and_copy_file "$REPO_DIR/config/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
fi

# Expand __HOME__ placeholders in config.json for the current user
sed -i "s|__HOME__|$HOME|g" "$HOME/.config/illogical-impulse/config.json"

# Ensure scripts are executable
chmod +x "$HOME/.config/quickshell/end4-pC/scripts/scan-apps.py" \
         "$HOME/.config/quickshell/end4-pC/scripts/icon-resolve.py" \
         "$HOME/.config/quickshell/end4-pC/scripts/colors/switchwall.sh" \
         "$HOME/.config/quickshell/end4-pC/scripts/colors/applycolor.sh" \
         "$HOME/.config/quickshell/end4-pC/scripts/thumbnails/generate-thumbnails-magick.sh" \
         "$HOME/.config/quickshell/end4-pC/scripts/videos/record.sh" \
         "$HOME/.config/quickshell/end4-pC/scripts/hyprland/hyprconfigurator.py" \
         "$HOME/.config/quickshell/end4-pC/scripts/hyprland/hypridleconfigurator.py" \
         "$HOME/.config/hypr/custom/scripts/"*.sh 2>/dev/null || true

# Install bundled Material Symbols font to user fonts if not present
if [ -f "$HOME/.config/quickshell/end4-pC/assets/fonts/MaterialSymbolsRounded.ttf" ]; then
    mkdir -p "$HOME/.local/share/fonts"
    cp -n "$HOME/.config/quickshell/end4-pC/assets/fonts/MaterialSymbolsRounded.ttf" "$HOME/.local/share/fonts/" 2>/dev/null || true
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
fi

mkdir -p "$HOME/.config/hypr/custom/scripts" "$WALL_DIR"
cp -n "$REPO_DIR/wallpapers/"* "$WALL_DIR/" 2>/dev/null || true

# Download curated 6K macOS Light & Dark wallpapers (skips any already present)
echo "==> Downloading 6K macOS Light & Dark wallpapers..."
WALL_DIR="$WALL_DIR" xargs -P 6 -n 2 bash -c '
    dest="$WALL_DIR/$2"
    [ -f "$dest" ] && exit 0
    tmp="$dest.part"
    if curl -fsSL --retry 2 "https://media.512pixels.net/downloads/macos-wallpapers-6k/$1" -o "$tmp" && [ -s "$tmp" ]; then
        mv "$tmp" "$dest"
    else
        rm -f "$tmp"
    fi
' _ <<'EOF' || true
26-Tahoe-Light-6K.png macOS-Tahoe-Light.png
26-Tahoe-Dark-6K.png macOS-Tahoe-Dark.png
26-Tahoe-Beach-Day.png macOS-Tahoe-Beach-Day.png
26-Tahoe-Beach-Night.png macOS-Tahoe-Beach-Night.png
27-Golden-Gate-Dark.png macOS-Golden-Gate-Dark.png
15-Sequoia-Dark-6K.jpg macOS-Sequoia-Dark.jpg
14-Sonoma-Light.jpg macOS-Sonoma-Light.jpg
14-Sonoma-Dark.jpg macOS-Sonoma-Dark.jpg
13-Ventura-Light.jpg macOS-Ventura-Light.jpg
13-Ventura-Dark.jpg macOS-Ventura-Dark.jpg
12-Monterey-Light.jpg macOS-Monterey-Light.jpg
12-Monterey-Dark.jpg macOS-Monterey-Dark.jpg
11-Big-Sur-Day-6k.jpg macOS-Big-Sur-Day.jpg
11-Big-Sur-Night-6k.jpg macOS-Big-Sur-Night.jpg
10-14-Day-6k.jpg macOS-Mojave-Day.jpg
10-14-Night-6k.jpg macOS-Mojave-Night.jpg
EOF

TAHOE_WALL="$WALL_DIR/macOS-Tahoe-Light.png"

# Pre-generate wallpaper selector thumbnails so previews load instantly
if [ -x "$HOME/.config/quickshell/end4-pC/scripts/thumbnails/generate-thumbnails-magick.sh" ]; then
    echo "==> Generating wallpaper selector thumbnails..."
    bash "$HOME/.config/quickshell/end4-pC/scripts/thumbnails/generate-thumbnails-magick.sh" --size x-large -d "$WALL_DIR" 2>/dev/null || true
fi

# Ensure ~/.config/gtk-4.0/gtk.css is writable for matugen (not a read-only symlink)
if [ -L "$HOME/.config/gtk-4.0/gtk.css" ]; then
    rm -f "$HOME/.config/gtk-4.0/gtk.css"
fi

# Apply macOS GTK/GNOME settings (left-aligned close/minimize/maximize buttons + adw-gtk3)
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice' 2>/dev/null || true
fi

if [ -f "$TAHOE_WALL" ] && command -v matugen >/dev/null 2>&1; then
    echo "==> Applying wallpaper & Material You colors..."
    bash "$HOME/.config/quickshell/end4-pC/scripts/colors/switchwall.sh" --image "$TAHOE_WALL" || true
fi

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    echo "==> Reloading Hyprland & Quickshell..."
    hyprctl reload 2>/dev/null || true
    pkill -x qs 2>/dev/null || killall qs 2>/dev/null || true
    sleep 0.4
    setsid qs -c end4-pC >/tmp/qs.log 2>&1 < /dev/null &
    disown
else
    echo "==> Not currently inside a Hyprland session; skipping live reload."
    echo "    Log out and select 'Hyprland' (or 'Hyprland (uwsm-managed)') from your display manager."
fi

echo "Done! Backups (if any) saved in: $BACKUP_DIR"
