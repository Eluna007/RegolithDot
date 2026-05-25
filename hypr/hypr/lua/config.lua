local M = {}

-- Core
M.mod          = "SUPER"
M.terminal     = "kitty"
M.filemanager  = "dolphin"
M.menu         = "rofi -show drun"

-- Appearance
M.gaps_in      = 5
M.gaps_out     = 10
M.border_size  = 2
M.rounding     = 10

-- Colors
M.border_active   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 }
M.border_inactive = "rgba(595959aa)"

return M
