-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

local is_mac = wezterm.target_triple:find("darwin") ~= nil

config.font_size = 14
-- Disable ligatures (calt=contextual alternates, clig=contextual ligatures, liga=standard ligatures)
config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }
-- config.color_scheme = 'AdventureTime'

-- style window chrome

-- Removes the title bar. Keeps the ability to resize by dragging edges.
-- On macOS, 'RESIZE|INTEGRATED_BUTTONS' puts window controls in tab bar
config.window_decorations = "RESIZE|INTEGRATED_BUTTONS"
config.window_frame = {
	font = wezterm.font({ family = "JetBrains Mono", weight = "Bold" }),
	font_size = 12,
}

-- key bindings
config.keys = {
	{
		key = "P",
		mods = is_mac and "CMD|SHIFT" or "CTRL|SHIFT",
		action = wezterm.action.ActivateCommandPalette,
	},
}

-- random color scheme from https://alexplescan.com/posts/2024/08/10/wezterm/
-- Creates a lua table containing the name of every color scheme WezTerm
-- ships with.
local scheme_names = {}
for name, _ in pairs(wezterm.color.get_builtin_schemes()) do
	table.insert(scheme_names, name)
end

-- When the config for a window is reloaded (i.e. when you save this file
-- or open a new window)...
wezterm.on("window-config-reloaded", function(window, _)
	-- Don't proceed if the config has already been overriden, otherwise
	-- we'll enter an infinite loop of neverending colour scheme changes.
	-- If that sounds like your kinda thing, then remove this line ;) - but
	-- don't say you haven't been warned.
	if window:get_config_overrides() then
		return
	end
	-- Pick a random colour scheme name.
	local scheme = scheme_names[math.random(#scheme_names)]
	-- Assign it as an override for this window.
	window:set_config_overrides({ color_scheme = scheme })
	-- And log it for good measure
	wezterm.log_info("Your colour scheme is now: " .. scheme)
end)

-- Finally, return the configuration to wezterm:
return config
