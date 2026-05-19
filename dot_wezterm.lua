local wezterm = require("wezterm")

local act = wezterm.action
local config = wezterm.config_builder()

-- comment favorite themes out of random arrays below
local fav_theme = { light = "Catppuccin Latte", dark = "Catppuccin Mocha" }
if wezterm.GLOBAL.follow_os_appearance == nil then
	wezterm.GLOBAL.follow_os_appearance = true
end
local is_mac = wezterm.target_triple:find("darwin") ~= nil

config.font_size = 14
config.inactive_pane_hsb = { saturation = 0.9, brightness = 0.9 }
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
	{ key = "d", mods = "CMD", action = act.SplitPane({ direction = "Right" }) },
	{ key = "d", mods = "CMD|SHIFT", action = act.SplitPane({ direction = "Down" }) },
}

-- show cwd in right part of top bar
wezterm.on("update-right-status", function(window, pane)
	local dir = ""
	local cwd = pane:get_current_working_dir()
	if cwd then
		dir = cwd.file_path:match("([^/]+)/?$") or ""
	end
	local palette = window:effective_config().resolved_palette
	local fg = (palette and palette.foreground) or "#ffffff"
	window:set_right_status(wezterm.format({
		{ Foreground = { Color = fg } },
		{ Text = " " .. dir .. " " },
	}))
end)

-- random color scheme from https://alexplescan.com/posts/2024/08/10/wezterm/
local dark_schemes = {
	--	"Catppuccin Mocha",
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
	--	"Catppuccin Latte",
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

local all_schemes = {}
for _, s in ipairs(dark_schemes) do table.insert(all_schemes, s) end
for _, s in ipairs(light_schemes) do table.insert(all_schemes, s) end

wezterm.on("window-config-reloaded", function(window, _)
	local current = (window:get_config_overrides() or {}).color_scheme
	if current == fav_theme.light or current == fav_theme.dark then
		return
	end

	local schemes
	if wezterm.GLOBAL.follow_os_appearance then
		local is_dark = wezterm.gui.get_appearance():find("Dark")
		schemes = is_dark and dark_schemes or light_schemes
	else
		schemes = all_schemes
	end
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
			brief = "Theme: " .. fav_theme.dark,
			icon = "md_weather_night",
			action = wezterm.action_callback(function(window, _)
				window:set_config_overrides({ color_scheme = fav_theme.dark })
			end),
		},
		{
			brief = "Theme: Catppuccin Light",
			icon = "md_weather_sunny",
			action = wezterm.action_callback(function(window, _)
				window:set_config_overrides({ color_scheme = fav_theme.light })
			end),
		},
		{
			brief = "Theme: Random",
			icon = "md_shuffle",
			action = wezterm.action_callback(function(window, _)
				window:set_config_overrides({})
			end),
		},
		{
			brief = "Theme: Toggle OS appearance matching ("
				.. (wezterm.GLOBAL.follow_os_appearance and "on" or "off") .. ")",
			icon = "md_theme_light_dark",
			action = wezterm.action_callback(function(window, _)
				wezterm.GLOBAL.follow_os_appearance = not wezterm.GLOBAL.follow_os_appearance
				window:set_config_overrides({})
			end),
		},
	}
end)

return config
