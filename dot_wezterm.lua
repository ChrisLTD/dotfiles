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

-- basename of the pane's cwd ("" if unavailable or not a local path)
local function pane_dir(pane)
	local cwd = pane:get_current_working_dir()
	if not cwd or cwd.scheme ~= "file" or not cwd.file_path then
		return ""
	end
	-- basename, or "/" when at the filesystem root
	return cwd.file_path:match("([^/]+)/?$") or "/"
end

-- git branch for the pane's cwd ("" outside a repo), with the same prefix
-- stripping as the nvim statusline, truncated to 25 chars. Only runs for local
-- panes; for remote/SSH panes cwd.file_path is not a local path.
--
-- Result is cached per pane to keep git off the per-second status hot path:
-- re-run only when the cwd changes or BRANCH_TTL seconds have elapsed (wall
-- clock, so it's independent of how often the status redraws or the flash is
-- pressed). A branch switch in place can therefore take up to BRANCH_TTL
-- seconds to show.
local BRANCH_TTL = 5
local branch_cache = {}

local function pane_branch(pane)
	local cwd = pane:get_current_working_dir()
	if not cwd or cwd.scheme ~= "file" or not cwd.file_path then
		return ""
	end
	local path = cwd.file_path
	local id = pane:pane_id()
	local now = os.time()
	local cached = branch_cache[id]
	if cached and cached.path == path and now < cached.expires_at then
		return cached.branch
	end

	local branch = ""
	local ok, stdout = wezterm.run_child_process({
		"git", "-C", path, "rev-parse", "--abbrev-ref", "HEAD",
	})
	if ok then
		branch = stdout:gsub("%s+$", "")
		branch = branch:gsub("^chrisltd/", ""):gsub("^feature/eng%-", "")
		branch = branch:sub(1, 25)
	end
	branch_cache[id] = { path = path, branch = branch, expires_at = now + BRANCH_TTL }
	return branch
end

-- flash bold text in the left status for a few seconds. Drawn in-window rather
-- than via toast_notification, which depends on macOS notification permissions.
-- Per-window generation token so a later flash isn't cleared by an earlier timer.
local flash_gen = {}
local function flash(window, text)
	window:set_left_status(wezterm.format({
		{ Attribute = { Intensity = "Bold" } },
		{ Text = text },
	}))
	local id = window:window_id()
	flash_gen[id] = (flash_gen[id] or 0) + 1
	local gen = flash_gen[id]
	wezterm.time.call_after(5, function()
		if flash_gen[id] == gen then
			-- window may have been closed before the timer fires
			pcall(function()
				window:set_left_status("")
			end)
		end
	end)
end

-- flash the cwd basename + branch on demand
local function show_path_info(window, pane)
	local branch = pane_branch(pane)
	local dir = pane_dir(pane)
	local lpad = "     " -- 5 chars on the left
	if branch ~= "" then
		flash(window, lpad .. FOLDER_GLYPH .. " " .. dir .. "   " .. BRANCH_GLYPH .. " " .. branch)
	else
		flash(window, lpad .. FOLDER_GLYPH .. " " .. dir)
	end
end

-- step forward/back through the active scheme list; assigned below the lists.
local cycle_scheme
local scheme_next = wezterm.action_callback(function(window, _)
	cycle_scheme(window, 1)
end)
local scheme_prev = wezterm.action_callback(function(window, _)
	cycle_scheme(window, -1)
end)

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
		-- flash the cwd + branch in the left status (right status shows only the branch)
		key = "i",
		mods = "CMD|SHIFT",
		action = wezterm.action_callback(show_path_info),
	},
	-- step forward/back through the active color scheme list (CMD+SHIFT+< / >).
	-- both glyph forms are bound since wezterm may report the key as the shifted
	-- glyph (< >) or the base key (, .) depending on the setup.
	{ key = ">", mods = "CMD|SHIFT", action = scheme_next },
	{ key = ".", mods = "CMD|SHIFT", action = scheme_next },
	{ key = "<", mods = "CMD|SHIFT", action = scheme_prev },
	{ key = ",", mods = "CMD|SHIFT", action = scheme_prev },
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

-- the list both the random roller and the manual cycle draw from: the
-- OS-appropriate list when following appearance, otherwise everything.
local function active_schemes()
	if wezterm.GLOBAL.follow_os_appearance then
		local is_dark = wezterm.gui.get_appearance():find("Dark")
		return is_dark and dark_schemes or light_schemes
	end
	return all_schemes
end

-- step delta places through active_schemes() from the current scheme, wrapping
-- at the ends, and flash the name. No stored index: the position is derived from
-- the current override each press, so it stays correct after a random roll. A
-- scheme that's in the list is preserved by the roller's guard, so this doesn't
-- get re-rolled out from under you.
cycle_scheme = function(window, delta)
	local schemes = active_schemes()
	local current = (window:get_config_overrides() or {}).color_scheme
	local idx = 0 -- 0 => first press lands on schemes[1]
	for i, s in ipairs(schemes) do
		if s == current then
			idx = i
			break
		end
	end
	local scheme = schemes[(idx - 1 + delta) % #schemes + 1]
	window:set_config_overrides({ color_scheme = scheme })
	flash(window, "     " .. scheme .. "  ")
end

wezterm.on("window-config-reloaded", function(window, _)
	local current = (window:get_config_overrides() or {}).color_scheme
	if current == fav_theme.light or current == fav_theme.dark then
		return
	end

	local schemes = active_schemes()
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
			brief = "Scheme: next",
			icon = "md_skip_next",
			action = scheme_next,
		},
		{
			brief = "Scheme: previous",
			icon = "md_skip_previous",
			action = scheme_prev,
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
