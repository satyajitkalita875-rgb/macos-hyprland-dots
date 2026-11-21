# macOS Hyprland + Quickshell Dotfiles

A cohesive macOS-inspired desktop setup for **Hyprland** (HyprLua 0.57+) and **Quickshell** (`end4-pC` fork) with dynamic **Material You** wallpaper theming via `matugen` — supporting both **Arch / CachyOS / EndeavourOS** and **Fedora 42+**.

## Quick Install (One-Line Copy & Paste)

Copy and paste this single command into your terminal. It installs **Hyprland 0.57+**, **Quickshell**, **Matugen**, **SDDM** (macOS login theme), all required Qt6/Wayland/font/cursor dependencies, **16 dark & light 6K macOS wallpapers**, and all dotfiles **completely unattended** (you only enter your `sudo` password once at the start):

```bash
curl -fsSL https://raw.githubusercontent.com/satyajitkalita875-rgb/macos-hyprland-dots/main/setup.sh | bash
```

> Supports **Arch Linux / CachyOS / EndeavourOS / Manjaro** (`pacman` + automatic AUR fallback) and **Fedora 42+** (`dnf` + COPR). After it finishes, reboot (or log out) and select **Hyprland** on the macOS-themed SDDM login screen.

## Highlights
- **macOS Menu Bar & Dynamic Island**: Translucent frosted glass floating pills with customizable modules (Settings → Bar), active app title, workspace switcher, system tray, horizontal battery with hover details, Wi-Fi, Bluetooth, scroll-to-adjust Volume, Spotlight search, **Wallpaper Selector icon** (right-click for random), Control Center dual-switch icon, and Date & Time with calendar popup.
- **macOS Control Center**: Floating top-right frosted glass bento popover with Connectivity (Wi-Fi, Bluetooth, VPN) and smooth inline drill-down sub-pages, Focus/Do Not Disturb, Night Shift, Light/Dark Mode toggle, Display & Sound sliders, Now Playing media controls, Quick Utilities, Notifications drawer, and quick-launch **Wallpaper Selector**.
- **Built-in Wallpaper Selector + 6K macOS Pack**: Browse and apply 16 official 6K dark & light macOS wallpapers (Tahoe, Golden Gate, Sequoia, Sonoma, Ventura, Monterey, Big Sur, Mojave) from the Menu Bar, Control Center, or `Super + Shift + W`, with fast automatic thumbnail generation (`magick` / `vipsthumbnail` / `ffmpeg`) and instant Material You color sync.
- **macOS Tahoe App Drawer**: Floating frosted glass application launcher with live XDG + Flatpak app discovery (`scan-apps.py`) and full-color high-res app icons (no restart needed after installing apps).
- **Floating Dock**: macOS-style floating dock with minimize-to-dock (`special:minimized`) and window previews.
- **macOS Lock Screen, Idle & Login Manager (SDDM)**: Custom frosted-glass `hyprlock` (giant clock, battery badge, user avatar, pill password field), `hypridle` auto-dim/lock/DPMS power management, and a matching Qt6 **SDDM** display manager theme (`sddm/macos-hyprland`).
- **Unified Material You Glass UI**: Consistent translucent Material You colors, RE2-compliant Hyprland frosted glass blur rules (`shellOverrides/blur.lua`), and macOS left-aligned GTK window buttons (`close,minimize,maximize:`).

## Keybindings
| Shortcut | Action |
| --- | --- |
| `Super + G` | Toggle App Drawer |
| `Super + Space` / `Super + Tab` | Toggle Spotlight Search |
| `Super + X` | Toggle Control Center |
| `Super + Shift + W` | Toggle Wallpaper Selector |
| `Super + Z` | Toggle Settings |
| `Super + Return` | Open Terminal (`kitty`) |
| `Super + E` | Open File Manager (`nautilus`) |
| `Super + W` | Open Browser (`firefox`) |
| `Super + Up` | Maximize active window |
| `Super + Down` | Unmaximize / Restore active window |
| `Super + M` | Minimize active window to dock |
| `Super + Shift + M` | Restore last minimized window |
| `Super + D` | Toggle maximize |
| `Super + F` | Toggle true fullscreen |
| `Super + Shift + F` | Toggle floating for active window |
| `Super + Alt + T` | Switch to Tiling window mode |
| `Super + Alt + S` | Switch to Stacking (floating) window mode |
| `Super + Q` | Close active window |
| `Super + L` | Lock screen (`hyprlock`) |
| `Super + Alt + C` | Session / Power menu |
| `Print` | Region screenshot / screen snip |

## Manual / Selective Installation

If you already cloned the repo and want to run an individual script manually:

```bash
git clone https://github.com/satyajitkalita875-rgb/macos-hyprland-dots.git ~/macos-hyprland-dots
cd ~/macos-hyprland-dots

./setup.sh          # Full unattended install (auto-detects Arch/CachyOS or Fedora)
./install-arch.sh   # Full unattended Arch / CachyOS install (packages + dotfiles + SDDM)
./install-fedora.sh # Full unattended Fedora 42+ install (COPR + packages + dotfiles + SDDM)
./install.sh        # Dotfiles, wallpapers & Material You colors only (backs up existing configs)
./install-sddm.sh   # macOS SDDM login theme only
```

> **Note on Hyprland Version:** This config uses **Hyprland 0.57+** native HyprLua (`hyprland.lua`). `setup.sh` / `install-fedora.sh` automatically enable the required COPR repos on Fedora (`lionheartp/Hyprland`, `errornointernet/quickshell`, `avengemedia/danklinux`) and install Hyprland + Quickshell + Matugen from pacman/AUR on Arch-based distros.
