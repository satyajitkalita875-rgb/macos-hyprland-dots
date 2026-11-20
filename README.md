# macOS Hyprland + Quickshell Dotfiles

A cohesive macOS-inspired desktop setup for **Hyprland** (HyprLua 0.57+) and **Quickshell** (`end4-pC` fork) with dynamic **Material You** wallpaper theming via `matugen`.

## Highlights
- **macOS Menu Bar (`28px`)**: Transparent frosted glass top bar with active app title, compact workspace switcher, system tray, macOS horizontal battery with charging bolt indicator & hover details, Wi-Fi, Bluetooth, scroll-to-adjust Volume, Spotlight search, iconic Control Center dual-switch icon, and far-right Date & Time with calendar popup.
- **macOS Control Center**: Floating top-right frosted glass bento popover with Connectivity (Wi-Fi, Bluetooth, VPN) and smooth inline drill-down sub-pages, Focus/Do Not Disturb, Night Shift, Light/Dark Mode toggle, Display & Sound sliders, Now Playing media controls, Quick Utilities, and Notifications drawer.
- **macOS Tahoe App Drawer**: Floating frosted glass application launcher with live XDG + Flatpak app discovery (`scan-apps.py`) and original full-color high-res app icons (no restart needed after installing apps).
- **Floating Dock**: macOS-style floating dock with minimize-to-dock (`special:minimized`) and window previews.
- **Unified Material You Glass UI**: Consistent translucent Material You colors, borders, and accents across Top Bar, Control Center, App Drawer, Dock, Spotlight, Settings, and Desktop Widgets.
- **Flat-Monitor Friendly**: Sharp edge-to-edge screen corners (`fakeScreenRounding: 0`) with cleaned-up Settings UI showing only active options.

## Keybindings
| Shortcut | Action |
| --- | --- |
| `Super + G` | Toggle App Drawer |
| `Super + Space` / `Super + Tab` | Toggle Spotlight Search |
| `Super + X` | Toggle Control Center |
| `Super + Z` | Toggle Settings |
| `Super + Up` | Maximize active window |
| `Super + Down` | Unmaximize / Restore active window |
| `Super + M` | Minimize active window to dock |
| `Super + Shift + M` | Restore last minimized window |
| `Super + D` | Toggle maximize |
| `Super + F` | Toggle true fullscreen |
| `Super + Q` | Close active window |
| `Super + Shift + W` | Wallpaper Selector |
| `Super + L` | Lock screen |
| `Super + Alt + C` | Session / Power menu |

## Dependencies (Arch / CachyOS)
- `hyprland` (0.57+ with HyprLua), `hyprlock`, `hypridle`, `quickshell`, `matugen`, `jq`, `python`, `curl`
- `grim`, `slurp`, `hyprpicker`, `hyprsunset`, `brightnessctl`, `networkmanager`, `bluez`, `pipewire`, `wireplumber`, `upower`
- Fonts: `Google Sans Flex`, `JetBrains Mono NF`, `Readex Pro`, `Space Grotesk`

## Installation
```bash
git clone https://github.com/satyajitkalita875-rgb/macos-hyprland-dots.git ~/Projects/macos-hyprland-dots
cd ~/Projects/macos-hyprland-dots
./install.sh
```
`install.sh` backs up any existing configs to `~/.config-backup-<timestamp>`, installs all configs, downloads the official 6K macOS Tahoe Light wallpaper (from 512 Pixels), syncs Material You colors via `switchwall.sh`, and reloads Hyprland & Quickshell.
