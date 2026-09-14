-- Environment variables, set before the display server initializes.
--
-- Translated from the `env = KEY,VALUE` lines that lived at the top of
-- Apollo's hyprland.conf.

-- Let Qt apps pick their theme from the xdg-desktop-portal, so GTK and Qt
-- agree on light/dark and accent without a second theming tool.
hl.env("QT_QPA_PLATFORMTHEME", "xdgdesktopportal")

-- Route GTK file choosers and friends through the portal too. Without this,
-- Thunar and Firefox open their own dialogs instead of the portal's.
hl.env("GTK_USE_PORTAL", "1")
hl.env("GDK_BACKEND", "wayland")
