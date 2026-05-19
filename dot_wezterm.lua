local wezterm = require("wezterm")

local act = wezterm.action
local config = wezterm.config_builder()

local is_mac = wezterm.target_triple:find("darwin") ~= nil

config.font_size = 14
-- calt=contextual alternates, clig=contextual ligatures, liga=standard ligatures
config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }

-- On macOS, 'RESIZE|INTEGRATED_BUTTONS' moves window controls into the tab bar
config.window_decorations = "RESIZE|INTEGRATED_BUTTONS"
config.window_frame = {
	font = wezterm.font({ family = "JetBrains Mono", weight = "Bold" }),
	font_size = 13,
}

config.keys = {
	{
		key = "P",
		mods = is_mac and "CMD|SHIFT" or "CTRL|SHIFT",
		action = wezterm.action.ActivateCommandPalette,
	},
	{ key = "[", mods = "CTRL|SHIFT", action = act.MoveTabRelative(-1) },
	{ key = "]", mods = "CTRL|SHIFT", action = act.MoveTabRelative(1) },
}

-- random color scheme from https://alexplescan.com/posts/2024/08/10/wezterm/
local dark_schemes = {
	"Catppuccin Mocha",
	"Tokyo Night",
	"Tokyo Night Storm",
	"Tokyo Night Moon",
	"Dracula (Official)",
	"Nord (Gogh)",
	"Gruvbox dark, hard (base16)",
	"rose-pine",
	"rose-pine-moon",
	"Kanagawa (Gogh)",
	"Everforest Dark (Gogh)",
	"Ayu Dark (Gogh)",
	"carbonfox",
	"nightfox",
	"duskfox",
	"terafox",
	"iceberg-dark",
	"flexoki-dark",
	"Poimandres",
	"zenbones_dark",
	"neobones_dark",
	"One Dark (Gogh)",
	"Tomorrow Night Eighties",
	"Andromeda",
	"seoulbones_dark",
	"farmhouse-dark",
	"GitHub Dark",
	"Vs Code Dark+ (Gogh)",
	"Windows 95 (base16)",
	"iTerm2 Dark Background",
	"AdventureTime",
	"Homebrew",
	"Monokai Pro (Gogh)",
	"Monokai Soda",
	"Monokai Vivid",
	"Monokai Remastered",
	"Railscasts (base16)",
}
local light_schemes = {
	"Catppuccin Latte",
	"Tokyo Night Day",
	"rose-pine-dawn",
	"Gruvbox light, hard (base16)",
	"Nord Light (Gogh)",
	"Ayu Light (Gogh)",
	"Solarized Light (Gogh)",
	"Everforest Light (Gogh)",
	"dayfox",
	"dawnfox",
	"iceberg-light",
	"flexoki-light",
	"One Light (Gogh)",
	"zenbones_light",
	"neobones_light",
	"PaperColor Light (base16)",
	"seoulbones_light",
	"farmhouse-light",
	"Github Light (Gogh)",
	"Vs Code Light+ (Gogh)",
	"Windows 95 Light (base16)",
	"iTerm2 Light Background",
}

wezterm.on("window-config-reloaded", function(window, _)
	local is_dark = wezterm.gui.get_appearance():find("Dark")
	local schemes = is_dark and dark_schemes or light_schemes

	-- Only re-pick if the current scheme isn't already from the right list.
	-- This prevents an infinite loop (setting an override triggers another reload)
	-- and also re-picks automatically when the OS appearance changes.
	local current = (window:get_config_overrides() or {}).color_scheme
	for _, s in ipairs(schemes) do
		if s == current then
			return
		end
	end

	local scheme = schemes[math.random(#schemes)]
	window:set_config_overrides({ color_scheme = scheme })
end)

wezterm.on("augment-command-palette", function(_, _)
	return {
		{
			brief = "Theme: Switch to Catppuccin Mocha (Dark)",
			icon = "md_weather_night",
			action = wezterm.action_callback(function(window, _)
				window:set_config_overrides({ color_scheme = "Catppuccin Mocha" })
			end),
		},
		{
			brief = "Theme: Switch to Catppuccin Latte (Light)",
			icon = "md_weather_sunny",
			action = wezterm.action_callback(function(window, _)
				window:set_config_overrides({ color_scheme = "Catppuccin Latte" })
			end),
		},
	}
end)

-- output all themes to file in home directory
-- local scheme_list = {}
-- for name, _ in pairs(wezterm.color.get_builtin_schemes()) do
-- 	table.insert(scheme_list, name)
-- end
-- table.sort(scheme_list)
-- local f = io.open(os.getenv("HOME") .. "/wezterm-schemes.txt", "w")
-- if f then
-- 	for _, name in ipairs(scheme_list) do
-- 		f:write(name .. "\n")
-- 	end
-- 	f:close()
-- end

wezterm.on("update-right-status", function(window, pane)
	local scheme = (window:get_config_overrides() or {}).color_scheme or ""

	local dir = ""
	local cwd = pane:get_current_working_dir()
	if cwd then
		dir = cwd.file_path:match("([^/]+)/?$") or ""
	end

	local parts = {}
	if dir ~= "" then table.insert(parts, dir) end
	if scheme ~= "" then table.insert(parts, scheme) end

	window:set_right_status(table.concat(parts, "  ·  "))
end)

return config
