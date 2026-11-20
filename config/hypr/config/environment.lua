-- Environmental variables (for reference https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/)
-- if you use UWSM, define your variables in ~/.config/uwsm/env
-- if you don't use UWSM, define your variables here (e.g. hl.env("QT_QPA_PLATFORM", "wayland"))

local home = os.getenv("HOME") or ""
hl.env("XDG_DATA_DIRS", home .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share")

-- Fallback environment variables for non-UWSM sessions (e.g. Fedora GDM/SDDM direct Hyprland session)
local function envDefault(name, value)
    local cur = os.getenv(name)
    if not cur or cur == "" then
        hl.env(name, value)
    end
end

envDefault("QT_QPA_PLATFORM", "wayland;xcb")
envDefault("QT_QPA_PLATFORMTHEME", "qt6ct")
envDefault("ELECTRON_OZONE_PLATFORM_HINT", "auto")
envDefault("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
envDefault("HYPRCURSOR_SIZE", "24")
envDefault("XCURSOR_THEME", "Bibata-Modern-Ice")
envDefault("XCURSOR_SIZE", "24")

-- if you have an NVIDIA GPU uncomment the following lines:

-- hl.env("GBM_BACKEND", "nvidia-drm") -- force GBM as a backend
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia") -- force GBM as a backend
-- hl.env("LIBVA_DRIVER_NAME", "nvidia") -- Hardware acceleration on NVIDIA GPUs
-- hl.env("__GL_GSYNC_ALLOWED", "1") -- Controls if G-Sync capable monitors should use Variable Refresh Rate (VRR)
