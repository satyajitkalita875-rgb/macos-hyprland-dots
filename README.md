# macOS Hyprland + Quickshell Dotfiles

A cohesive macOS-inspired desktop setup for **Hyprland** (HyprLua 0.57+) and **Quickshell** (`end4-pC` fork) with dynamic **Material You** wallpaper theming via `matugen` — supporting both **Fedora** and **Arch / CachyOS**.

## Highlights
- **macOS Menu Bar (`28px`)**: Translucent frosted glass top bar with customizable modules (Settings → Bar), active app title, compact workspace switcher, system tray, macOS horizontal battery with charging bolt indicator & hover details, Wi-Fi, Bluetooth, scroll-to-adjust Volume, Spotlight search, Control Center dual-switch icon, and far-right Date & Time with calendar popup.
- **macOS Control Center**: Floating top-right frosted glass bento popover with Connectivity (Wi-Fi, Bluetooth, VPN) and smooth inline drill-down sub-pages, Focus/Do Not Disturb, Night Shift, Light/Dark Mode toggle, Display & Sound sliders, Now Playing media controls, Quick Utilities, and Notifications drawer.
- **macOS Tahoe App Drawer**: Floating frosted glass application launcher with live XDG + Flatpak app discovery (`scan-apps.py`) and full-color high-res app icons (no restart needed after installing apps).
- **Floating Dock**: macOS-style floating dock with minimize-to-dock (`special:minimized`) and window previews.
- **macOS Lock Screen, Idle & Login Manager (SDDM)**: Custom frosted-glass `hyprlock` (giant clock, battery badge, user avatar, pill password field), `hypridle` auto-dim/lock/DPMS power management, and a matching Qt6 **SDDM** display manager theme (`sddm/macos-hyprland`) installed via `install-sddm.sh`.
- **Unified Material You Glass UI**: Consistent translucent Material You colors, RE2-compliant Hyprland frosted glass blur rules (`shellOverrides/blur.lua`), and macOS left-aligned GTK window buttons (`close,minimize,maximize:`).
- **Cross-Distro Ready (Fedora + Arch/CachyOS)**: Auto-detects UWSM vs direct GDM/SDDM sessions, supports `dnf`/`rpm` on Fedora and `pacman`/`yay`/`paru` on Arch for updates & system info, and ships with a dedicated Fedora bootstrapper (`install-fedora.sh`).

## Keybindings
| Shortcut | Action |
| --- | --- |
| `Super + G` | Toggle App Drawer |
| `Super + Space` / `Super + Tab` | Toggle Spotlight Search |
| `Super + X` | Toggle Control Center |
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
| `Super + Q` | Close active window |
| `Super + Shift + W` | Wallpaper Selector |
| `Super + L` | Lock screen (`hyprlock`) |
| `Super + Alt + C` | Session / Power menu |
| `Print` | Region screenshot / screen snip |

## Installation

### Fedora (Workstation / KDE / Everything — Fedora 42+)
`install-fedora.sh` automatically enables the required COPR repositories (`lionheartp/Hyprland`, `errornointernet/quickshell`, `avengemedia/danklinux`), installs Hyprland 0.57+, Quickshell, Matugen, Qt6/QML modules, Wayland utilities, themes, and cursors, and deploys all dotfiles:

```bash
git clone https://github.com/satyajitkalita875-rgb/macos-hyprland-dots.git ~/Projects/macos-hyprland-dots
cd ~/Projects/macos-hyprland-dots
chmod +x install-fedora.sh install.sh
./install-fedora.sh
```

After installation finishes, log out and select **Hyprland** (or **Hyprland (uwsm-managed)**) on the GDM/SDDM login screen.

> **Note on Hyprland Version:** This config uses **Hyprland 0.57+** native HyprLua (`hyprland.lua`). `install-fedora.sh` enables `lionheartp/Hyprland` (with fallback to `solopasha/hyprland`) and verifies your installed Hyprland version automatically.

### Arch / CachyOS
Install dependencies (`hyprland` 0.57+, `hyprlock`, `hypridle`, `quickshell`, `matugen`, `jq`, `python`, `curl`, `grim`, `slurp`, `wl-clipboard`, `cliphist`, `hyprpicker`, `hyprsunset`, `brightnessctl`, `networkmanager`, `bluez`, `pipewire`, `wireplumber`, `upower`, `adw-gtk3`), then run:

```bash
git clone https://github.com/satyajitkalita875-rgb/macos-hyprland-dots.git ~/Projects/macos-hyprland-dots
cd ~/Projects/macos-hyprland-dots
./install.sh
./install-sddm.sh   # Optional: install & enable the macOS Hyprland SDDM login screen
```

`install.sh` backs up any existing configs to `~/.config-backup-<timestamp>`, installs all configs (including GTK3/GTK4 macOS window button layout), downloads the official 6K macOS Tahoe Light wallpaper (from 512 Pixels), syncs Material You colors via `switchwall.sh`, and reloads Hyprland & Quickshell when run inside an active Hyprland session.
