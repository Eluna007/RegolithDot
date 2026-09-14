-- Autostart.
--
-- hyprlang's `exec-once = ...` becomes a hyprland.start event handler. The
-- practical difference: exec-once fired once per config *load*, this fires
-- once per session, so `hyprctl reload` no longer duplicates every daemon.

local cfg = require("lua.config")

hl.on("hyprland.start", function()
    -- The shell. Apollo lives in ~/.config/quickshell/apollo, so it has to be
    -- named: bare `quickshell` would look for a config at the root instead.
    hl.exec_cmd("qs -c apollo")

    -- Hand the session's Wayland environment to D-Bus/systemd activation, or
    -- portal-launched apps come up without knowing they're on Wayland.
    hl.exec_cmd("dbus-update-activation-environment --systemd " ..
        "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE " ..
        "QT_QPA_PLATFORMTHEME GTK_USE_PORTAL GDK_BACKEND")

    -- Portals, required for screen sharing and PipeWire capture. They're
    -- staggered because the hyprland backend has to register before the
    -- generic service starts picking backends.
    hl.exec_cmd("sleep 2 && /usr/lib/xdg-desktop-portal-hyprland")
    hl.exec_cmd("sleep 3 && /usr/lib/xdg-desktop-portal")

    hl.exec_cmd("hypridle")
    hl.exec_cmd("nm-applet")

    -- Wallpaper daemon: restore the last wallpaper, fall back to a default.
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("sleep 1 && (awww restore || awww img " ..
        cfg.wallpapers .. "/wallpaper4.jpg -t none)")

    -- Clipboard history.
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
