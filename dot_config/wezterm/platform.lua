local wezterm = require("wezterm")

local M = {}

M.is_mac = wezterm.target_triple:find("darwin") ~= nil
-- primary modifier for custom bindings: CMD on macOS, SUPER (the logo key) on Linux
M.mod = M.is_mac and "CMD" or "SUPER"

return M
