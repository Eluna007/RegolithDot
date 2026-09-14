-- Shared program definitions & variables.
-- Require this from any file that needs these values:
--  local env = require("env")

local M = {}

M.terminal = "kitty"
M.launcher = "wofi --show drun"
M.fileManager = "thunar"

-- Qt apps (like OnlyOffice) need this to render sharp instead of blurry
-- when routed through XWayland at 1.5x scale

return M
