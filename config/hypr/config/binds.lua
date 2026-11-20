local mainMod = "SUPER"
local qsCall = "qs -c end4-pC ipc call "
local launchPrefix = "uwsm app -- " -- if you are not using UWSM, make this empty (e.g. "")

-- AZERTY fix: the number-row keys emit symbols (& é " ' ...) without Shift, so
-- binding to the digit characters fails. Bind by physical keycode instead.
-- Digit d -> evdev keycode: 1..9 => 10..18, 0 => 19
local function digitCode(d)
    return "code:" .. (d == 0 and 19 or (9 + d))
end

---------------------------
---- WINDOW MANAGEMENT ----
---------------------------

-- Window manipulation
hl.bind(mainMod .. " + Escape",      hl.dsp.exec_cmd("hyprctl kill"))
hl.bind(mainMod .. " + Q",           hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" })) -- Floating <-> tiled
hl.bind(mainMod .. " + D",           hl.dsp.window.fullscreen({ mode = 1 }))     -- Toggle maximize
hl.bind(mainMod .. " + F",           hl.dsp.window.fullscreen())               -- Toggle true fullscreen
hl.bind(mainMod .. " + Up",          hl.dsp.window.fullscreen_state({ internal = 1, client = 0 })) -- Maximize
hl.bind(mainMod .. " + Down",        hl.dsp.window.fullscreen_state({ internal = 0, client = 0 })) -- Unmaximize (restore)
hl.bind(mainMod .. " + M",           hl.dsp.window.move({ workspace = "special:minimized", follow = false })) -- Minimize to dock
hl.bind(mainMod .. " + SHIFT + M",   function()
    local wins = hl.get_workspace_windows("special:minimized")
    local ws = hl.get_active_workspace()
    if wins and #wins > 0 and ws then
        local target = "address:" .. tostring(wins[#wins].address)
        hl.dispatch(hl.dsp.window.move({ workspace = tostring(ws.id), window = target }))
        hl.dispatch(hl.dsp.focus({ window = target }))
    end
end) -- Restore last minimized
hl.bind(mainMod .. " + J",           hl.dsp.layout("togglesplit"))

-- Change focus
hl.bind(mainMod .. " + Left",        hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Right",       hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + ALT + Up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + ALT + Down",  hl.dsp.focus({ direction = "down" }))
hl.bind("ALT + Tab",           hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + Tab",   hl.dsp.exec_cmd(qsCall .. "search toggle"))

-- Move active window around workspaces & monitors
hl.bind(mainMod .. " + SHIFT + Up",                   hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + Right",                hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + Left",                 hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + Down",                 hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + " .. digitCode(1),     hl.dsp.window.move({ monitor = MONITOR1 }))
hl.bind(mainMod .. " + SHIFT + " .. digitCode(2),     hl.dsp.window.move({ monitor = MONITOR2 }))
hl.bind(mainMod .. " + SHIFT + " .. digitCode(3),     hl.dsp.window.move({ monitor = MONITOR3 }))
hl.bind(mainMod .. " + SHIFT + mouse_up",             hl.dsp.window.move({ monitor   = "-1" }))
hl.bind(mainMod .. " + SHIFT + mouse_down",           hl.dsp.window.move({ monitor   = "+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Right",      hl.dsp.window.move({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Left",       hl.dsp.window.move({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_up",   hl.dsp.window.move({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_down", hl.dsp.window.move({ workspace = "m+1" }))
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + SHIFT + CONTROL + " .. digitCode(key), hl.dsp.window.move({ workspace = "m~" .. i }))
end
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + SHIFT + ALT + " .. digitCode(key), hl.dsp.window.move({ workspace = "m~" .. i, follow = false }))
end

-- Move & Resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())

-- Zoom
local function zoomfunction(value)
    local zoomvalue = hl.get_config("cursor:zoom_factor")
    if (zoomvalue + value) > 3.0 then
        hl.config({ cursor = { zoom_factor = 3.0 } })
    elseif (zoomvalue + value) < 1.0 then
        hl.config({ cursor = { zoom_factor = 1.0 } })
    else
        hl.config({ cursor = { zoom_factor = zoomvalue + value } })
    end
end
hl.bind(mainMod .. " + Minus", function() zoomfunction(-0.3) end, { repeating = true})
hl.bind(mainMod .. " + Plus", function() zoomfunction(0.3) end, { repeating = true })

--# Zoom with keypad
hl.bind(mainMod .. " + code:82", function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + code:86", function() zoomfunction(0.3) end, { repeating = true })


------------------
---- LAUNCHER ----
------------------

hl.bind(mainMod .. " + Return",     hl.dsp.exec_cmd(launchPrefix .. TERMINAL))
hl.bind(mainMod .. " + E",          hl.dsp.exec_cmd(launchPrefix .. FILE_MANAGER))
hl.bind(mainMod .. " + T",          hl.dsp.exec_cmd(launchPrefix .. EDITOR))
hl.bind(mainMod .. " + C",          hl.dsp.exec_cmd(launchPrefix .. CALCULATOR))
hl.bind("XF86Calculator",           hl.dsp.exec_cmd(launchPrefix .. CALCULATOR))
hl.bind(mainMod .. " + W",          hl.dsp.exec_cmd(launchPrefix .. BROWSER))
hl.bind("CONTROL + SHIFT + Escape", hl.dsp.exec_cmd(launchPrefix .. TERMINAL .. " -e btop"))
hl.bind(mainMod .. " + Z",          hl.dsp.exec_cmd(qsCall .. "settings toggle"))
hl.bind(mainMod .. " + X",          hl.dsp.exec_cmd(qsCall .. "sidebarRight toggle"))
hl.bind(mainMod .. " + G",          hl.dsp.exec_cmd(qsCall .. "appDrawer toggle"))
hl.bind(mainMod .. " + Space",      hl.dsp.exec_cmd(qsCall .. "search toggle"))
hl.bind(mainMod .. " + period",     hl.dsp.exec_cmd(qsCall .. "search toggle"))
hl.bind(mainMod .. " + L",          hl.dsp.exec_cmd(qsCall .. "lock activate"))
hl.bind(mainMod .. " + ALT + C",    hl.dsp.exec_cmd(qsCall .. "session toggle"))

---------------------------
---- HARDWARE CONTROLS ----
---------------------------

-- Audio
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),   { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),  { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

-- Media
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(qsCall .. "mpris playPause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(qsCall .. "mpris playPause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd(qsCall .. "mpris next"),      { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd(qsCall .. "mpris previous"),  { locked = true })

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(qsCall .. "brightness increment"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(qsCall .. "brightness decrement"), { locked = true, repeating = true })

-------------------
---- UTILITIES ----
-------------------

-- Screen Capture
hl.bind(mainMod .. " + P",     hl.dsp.exec_cmd("hyprpicker -a -n"))
hl.bind("Print",               hl.dsp.exec_cmd(qsCall .. "region screenshot"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("sh -c 'grim /tmp/hyprland-fullscreen-$(date +%s).png'"))

-- Theming and Wallpaper
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(qsCall .. "wallpaperSelector toggle"))

-- Clipboard
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(qsCall .. "search clipboardToggle"))

-- Notifications
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(qsCall .. "sidebarRight open"))

-------------------------------
---- WORKSPACES & MONITORS ----
-------------------------------

-- Focus on monitors
hl.bind(mainMod .. " + " .. digitCode(1), hl.dsp.focus({ monitor = MONITOR1 }))
hl.bind(mainMod .. " + " .. digitCode(2), hl.dsp.focus({ monitor = MONITOR2 }))
hl.bind(mainMod .. " + " .. digitCode(3), hl.dsp.focus({ monitor = MONITOR3 }))

-- Focus on workspace number
-- Absolute
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + ALT + " .. digitCode(key), hl.dsp.focus({ workspace = i }))
end
-- Relative
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + CONTROL + " .. digitCode(key), hl.dsp.focus({ workspace = "m~" .. i }))
end

-- Move to adjacent workspaces and next empty on a given monitor
hl.bind(mainMod .. " + CONTROL + Right",       hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + Left",        hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + Down",        hl.dsp.focus({ workspace = "emptym" }))

-- Scroll through existing workspaces & monitors
hl.bind(mainMod .. " + mouse_down",           hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + mouse_up",             hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + mouse_up",   hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + mouse_down", hl.dsp.focus({ workspace = "m+1" }))

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special" }))
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special())
