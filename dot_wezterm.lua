-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- or, changing the font size and color scheme.
config.font_size = 13
-- config.color_scheme = 'AdventureTime'

-- Finally, return the configuration to wezterm:
return config
