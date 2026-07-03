-- main entry point: base config plus modules from this directory
-- (wezterm puts the config dir on package.path, so plain require works)
local wezterm = require("wezterm")
local platform = require("platform")
local keys = require("keys")
local status = require("status")
local themes = require("themes")
local palette = require("palette")

local config = wezterm.config_builder()

config.font_size = 14
config.inactive_pane_hsb = { saturation = 0.9, brightness = 0.9 }
-- calt=contextual alternates, clig=contextual ligatures, liga=standard ligatures
config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }

-- On macOS, 'RESIZE|INTEGRATED_BUTTONS' moves window controls into the tab bar;
-- elsewhere keep the normal title bar
config.window_decorations = platform.is_mac and "RESIZE|INTEGRATED_BUTTONS" or "TITLE|RESIZE"
config.window_frame = {
	font = wezterm.font({ family = "JetBrains Mono", weight = "Bold" }),
	font_size = 13,
}

config.keys = keys

status.setup()
themes.setup()
palette.setup()

return config
