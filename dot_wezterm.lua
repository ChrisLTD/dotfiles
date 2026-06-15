local wezterm = require("wezterm")

local act = wezterm.action
local config = wezterm.config_builder()

-- comment favorite themes out of random arrays below
local fav_theme = { light = "Catppuccin Latte", dark = "Catppuccin Mocha" }
if wezterm.GLOBAL.follow_os_appearance == nil then
	wezterm.GLOBAL.follow_os_appearance = true
end
local is_mac = wezterm.target_triple:find("darwin") ~= nil

-- glyphs: powerline branch + nerdfont folder
local BRANCH_GLYPH = utf8.char(0xe0a0)
local FOLDER_GLYPH = wezterm.nerdfonts.md_folder

-- basename of the pane's cwd ("" if unavailable)
local function pane_dir(pane)
	local cwd = pane:get_current_working_dir()
	if not cwd then
		return ""
	end
	return cwd.file_path:match("([^/]+)/?$") or ""
end

-- git branch for the pane's cwd ("" outside a repo), with the same prefix
-- stripping as the nvim statusline, truncated to 25 chars
local function pane_branch(pane)
	local cwd = pane:get_current_working_dir()
	if not cwd then
		return ""
	end
	local ok, stdout = wezterm.run_child_process({
		"git", "-C", cwd.file_path, "rev-parse", "--abbrev-ref", "HEAD",
	})
	if not ok then
		return ""
	end
	local branch = stdout:gsub("%s+$", "")
	branch = branch:gsub("^chrisltd/", ""):gsub("^feature/eng%-", "")
	return branch:sub(1, 25)
end

-- flash branch + cwd basename in the left status. Drawn in-window rather than
-- via toast_notification, which depends on macOS notification permissions.
local function show_path_info(window, pane)
	local branch = pane_branch(pane)
	local dir = pane_dir(pane)
	local lpad = "     " -- 5 chars on the left
	local rpad = "" -- no padding on the right
	local text
	if branch ~= "" then
		text = lpad .. FOLDER_GLYPH .. " " .. dir .. "   " .. BRANCH_GLYPH .. " " .. branch .. rpad
	else
		text = lpad .. FOLDER_GLYPH .. " " .. dir .. rpad
	end
	window:set_left_status(wezterm.format({
		{ Attribute = { Intensity = "Bold" } },
		{ Text = text },
	}))
	-- clear it again after a few seconds
	wezterm.time.call_after(5, function()
		window:set_left_status("")
	end)
end

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
	{
		-- show full cwd + branch in a toast (status bar shows only the basename)
		key = "i",
		mods = "CMD|SHIFT",
		action = wezterm.action_callback(show_path_info),
	},
	{
		key = "w",
		mods = "CMD",
		action = wezterm.action_callback(function(window, pane)
			local tab = window:active_tab()
			if #tab:panes() > 1 then
				window:perform_action(act.CloseCurrentPane({ confirm = true }), pane)
			else
				window:perform_action(act.CloseCurrentTab({ confirm = true }), pane)
			end
		end),
	},
}

-- show git branch (preferred) or cwd in right part of top bar
wezterm.on("update-right-status", function(window, pane)
	local branch = pane_branch(pane)

	-- Grab the utf8 character for the "powerline" solid angle
	-- powerline symbols: https://github.com/ryanoasis/powerline-extra-symbols
	local SYMBOL = utf8.char(0xe0ba)

	-- Grab the current window's configuration
	local color_scheme = window:effective_config().resolved_palette
	local bg = color_scheme.background
	local fg = color_scheme.foreground

	-- prefer the branch; fall back to the cwd basename only when not in a repo
	local text
	if branch ~= "" then
		text = " " .. BRANCH_GLYPH .. " " .. branch .. " "
	else
		text = " " .. FOLDER_GLYPH .. " " .. pane_dir(pane) .. " "
	end

	window:set_right_status(wezterm.format({
		-- arrow
		{ Background = { Color = "none" } },
		{ Foreground = { Color = bg } },
		{ Text = SYMBOL },
		-- text
		{ Background = { Color = bg } },
		{ Foreground = { Color = fg } },
		{ Text = text },
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
	"Unikitty Dark (base16)",
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
	"Unikitty Light (base16)",
}

local all_schemes = {}
for _, s in ipairs(dark_schemes) do
	table.insert(all_schemes, s)
end
for _, s in ipairs(light_schemes) do
	table.insert(all_schemes, s)
end

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
			brief = "Show current path + branch",
			icon = "md_folder_information",
			action = wezterm.action_callback(show_path_info),
		},
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
				.. (wezterm.GLOBAL.follow_os_appearance and "on" or "off")
				.. ")",
			icon = "md_theme_light_dark",
			action = wezterm.action_callback(function(window, _)
				wezterm.GLOBAL.follow_os_appearance = not wezterm.GLOBAL.follow_os_appearance
				window:set_config_overrides({})
			end),
		},
	}
end)

return config
