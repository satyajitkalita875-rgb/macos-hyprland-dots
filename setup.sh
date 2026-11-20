#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${MACOS_DOTS_REPO:-https://github.com/satyajitkalita875-rgb/macos-hyprland-dots.git}"
INSTALL_DIR="${MACOS_DOTS_DIR:-$HOME/macos-hyprland-dots}"

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo "Error: Please run this installer as your normal user (not root). It will use sudo automatically."
    exit 1
fi

echo "=================================================================="
echo "  macOS Hyprland + Quickshell — Unattended One-Line Installer"
echo "=================================================================="
echo ""

# Authenticate sudo once upfront (works even when piped via `curl ... | bash`)
echo "==> Requesting sudo privileges once for unattended package installation..."
if [ -r /dev/tty ]; then
    sudo -v </dev/tty
else
    sudo -v
fi

# Keep sudo session alive for the duration of the install
(
    while true; do
        sudo -n true
        sleep 50
        kill -0 "$$" 2>/dev/null || exit
    done
) 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

# Detect distro / package manager
PKG_MGR=""
if command -v pacman >/dev/null 2>&1; then
    PKG_MGR="pacman"
elif command -v dnf >/dev/null 2>&1; then
    PKG_MGR="dnf"
else
    echo "Error: Unsupported distribution (neither 'pacman' nor 'dnf' was found)."
    echo "Supported distros: Arch Linux, CachyOS, EndeavourOS, Manjaro, and Fedora 42+."
    exit 1
fi

if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "==> Detected OS: ${PRETTY_NAME:-Linux} (using $PKG_MGR)"
fi

# Ensure git and curl are installed before cloning
if ! command -v git >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    echo "==> Installing git and curl..."
    if [ "$PKG_MGR" = "pacman" ]; then
        sudo pacman -Sy --needed --noconfirm git curl
    else
        sudo dnf install -y git curl
    fi
fi

# Determine repository directory: use current repo if run locally, otherwise clone/update
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/install.sh" ] && [ -d "$SCRIPT_DIR/config" ]; then
    REPO_DIR="$SCRIPT_DIR"
    echo "==> Using local repository at $REPO_DIR"
else
    REPO_DIR="$INSTALL_DIR"
    if [ -d "$REPO_DIR/.git" ]; then
        echo "==> Updating existing repository at $REPO_DIR..."
        git -C "$REPO_DIR" pull --ff-only || true
    else
        if [ -e "$REPO_DIR" ]; then
            BACKUP_REPO="${REPO_DIR}.bak.$(date +%Y%m%d-%H%M%S)"
            echo "==> Backing up existing $REPO_DIR to $BACKUP_REPO..."
            mv "$REPO_DIR" "$BACKUP_REPO"
        fi
        echo "==> Cloning $REPO_URL into $REPO_DIR..."
        git clone --depth 1 "$REPO_URL" "$REPO_DIR"
    fi
fi

chmod +x "$REPO_DIR/setup.sh" \
         "$REPO_DIR/install.sh" \
         "$REPO_DIR/install-arch.sh" \
         "$REPO_DIR/install-fedora.sh" \
         "$REPO_DIR/install-sddm.sh" 2>/dev/null || true

# Dispatch to the distro-specific full installer (Hyprland + Quickshell + Matugen + Dotfiles + SDDM)
if [ "$PKG_MGR" = "pacman" ]; then
    bash "$REPO_DIR/install-arch.sh"
else
    bash "$REPO_DIR/install-fedora.sh"
fi
