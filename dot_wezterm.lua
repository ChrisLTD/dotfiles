local wezterm = require("wezterm")

local act = wezterm.action
local config = wezterm.config_builder()

-- comment favorite themes out of random arrays below
local fav_theme = { light = "Catppuccin Latte", dark = "Catppuccin Mocha" }
if wezterm.GLOBAL.follow_os_appearance == nil then
	wezterm.GLOBAL.follow_os_appearance = true
end
local is_mac = wezterm.target_triple:find("darwin") ~= nil
-- primary modifier for custom bindings: CMD on macOS, SUPER (the logo key) on Linux
local mod = is_mac and "CMD" or "SUPER"

-- glyphs: powerline branch + nerdfont folder
local BRANCH_GLYPH = utf8.char(0xe0a0)
local FOLDER_GLYPH = wezterm.nerdfonts.md_folder
local SCHEME_GLYPH = wezterm.nerdfonts.md_palette

-- local filesystem path of the pane's cwd (nil if unavailable or not a local
-- path, e.g. for remote/SSH panes)
local function pane_cwd_path(pane)
	local cwd = pane:get_current_working_dir()
	if not cwd or cwd.scheme ~= "file" or not cwd.file_path then
		return nil
	end
	return cwd.file_path
end

-- basename, or "/" when at the filesystem root
local function dir_basename(path)
	return path:match("([^/]+)/?$") or "/"
end

-- git branch for a local cwd path ("" outside a repo), with the same prefix
-- stripping as the nvim statusline, truncated to 25 chars.
--
-- Result is cached per path to keep git off the per-second status hot path
-- (and so panes sharing a cwd share one git run): re-run only when BRANCH_TTL
-- seconds have elapsed (wall clock, so it's independent of how often the
-- status redraws or the flash is pressed). A branch switch in place can
-- therefore take up to BRANCH_TTL seconds to show.
local BRANCH_TTL = 5
local branch_cache = {}

local function branch_for(path)
	local now = os.time()
	local cached = branch_cache[path]
	if cached and now < cached.expires_at then
		return cached.branch
	end

	local branch = ""
	local ok, stdout = wezterm.run_child_process({
		"git", "-C", path, "rev-parse", "--abbrev-ref", "HEAD",
	})
	if ok then
		branch = stdout:gsub("%s+$", "")
		if branch == "HEAD" then
			-- detached HEAD: the literal "HEAD" says nothing, show the short hash
			local ok_sha, sha = wezterm.run_child_process({
				"git", "-C", path, "rev-parse", "--short", "HEAD",
			})
			branch = ok_sha and sha:gsub("%s+$", "") or ""
		else
			branch = branch:gsub("^chrisltd/", ""):gsub("^feature/eng%-", "")
			branch = branch:sub(1, 25)
		end
	end
	branch_cache[path] = { branch = branch, expires_at = now + BRANCH_TTL }
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

-- flash a scheme name in the left status, prefixed with the palette glyph.
-- The extra left padding on macOS clears the traffic-light buttons that are
-- integrated into the tab bar.
local LEFT_PAD = is_mac and "     " or " "
local function flash_scheme(window, scheme)
	flash(window, LEFT_PAD .. SCHEME_GLYPH .. " " .. scheme .. "  ")
end

-- step forward/back through the active scheme list; assigned below the lists.
local cycle_scheme
local scheme_next = wezterm.action_callback(function(window, _)
	cycle_scheme(window, 1)
end)
local scheme_prev = wezterm.action_callback(function(window, _)
	cycle_scheme(window, -1)
end)

-- per-window right-status mode, cycled by mod+SHIFT+I:
--   "branch" (default, cwd fallback) -> "cwd" -> "both" (cwd + branch)
local right_status_modes = { "branch", "cwd", "both" }
local right_status_mode = {}
local function next_right_status(mode)
	for i, m in ipairs(right_status_modes) do
		if m == (mode or "branch") then
			return right_status_modes[i % #right_status_modes + 1]
		end
	end
	return right_status_modes[1]
end
local function toggle_right_status(window, _)
	local id = window:window_id()
	right_status_mode[id] = next_right_status(right_status_mode[id])
end

config.font_size = 14
config.inactive_pane_hsb = { saturation = 0.9, brightness = 0.9 }
-- calt=contextual alternates, clig=contextual ligatures, liga=standard ligatures
config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }

-- On macOS, 'RESIZE|INTEGRATED_BUTTONS' moves window controls into the tab bar;
-- elsewhere keep the normal title bar
config.window_decorations = is_mac and "RESIZE|INTEGRATED_BUTTONS" or "TITLE|RESIZE"
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
	{ key = "d", mods = mod, action = act.SplitPane({ direction = "Right" }) },
	{ key = "d", mods = mod .. "|SHIFT", action = act.SplitPane({ direction = "Down" }) },
	-- step forward/back through the active color scheme list (mod+SHIFT+< / >).
	-- both glyph forms are bound since wezterm may report the key as the shifted
	-- glyph (< >) or the base key (, .) depending on the setup.
	{ key = ">", mods = mod .. "|SHIFT", action = scheme_next },
	{ key = ".", mods = mod .. "|SHIFT", action = scheme_next },
	{ key = "<", mods = mod .. "|SHIFT", action = scheme_prev },
	{ key = ",", mods = mod .. "|SHIFT", action = scheme_prev },
	{
		-- toggle the right status between branch and cwd (per window)
		key = "i",
		mods = mod .. "|SHIFT",
		action = wezterm.action_callback(toggle_right_status),
	},
	{
		key = "w",
		mods = mod,
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

-- show git branch (preferred) or cwd in right part of top bar; mod+SHIFT+I
-- toggles between the two per window
wezterm.on("update-right-status", function(window, pane)
	-- Grab the utf8 character for the "powerline" solid angle
	-- powerline symbols: https://github.com/ryanoasis/powerline-extra-symbols
	local SYMBOL = utf8.char(0xe0ba)

	-- Grab the current window's configuration
	local color_scheme = window:effective_config().resolved_palette
	local bg = color_scheme.background
	local fg = color_scheme.foreground

	-- branch mode prefers the branch, falling back to the cwd basename outside a
	-- repo; cwd mode always shows the cwd basename; both mode always shows cwd +
	-- branch (with the branch truncated harder to keep it short)
	local mode = right_status_mode[window:window_id()] or "branch"
	local path = pane_cwd_path(pane)
	local dir = path and dir_basename(path) or ""
	local branch = (path and mode ~= "cwd") and branch_for(path) or ""

	-- on main/master the branch name says nothing about which repo/worktree this
	-- is, so show cwd + branch like "both" mode
	if mode == "branch" and (branch == "main" or branch == "master") then
		mode = "both"
	end

	local text
	if mode == "cwd" or branch == "" then
		text = " " .. FOLDER_GLYPH .. " " .. dir .. " "
	elseif mode == "both" then
		text = " " .. FOLDER_GLYPH .. " " .. dir .. " " .. BRANCH_GLYPH .. " " .. branch:sub(1, 13) .. " "
	else
		text = " " .. BRANCH_GLYPH .. " " .. branch .. " "
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
	if #schemes == 0 then
		return
	end
	local current = (window:get_config_overrides() or {}).color_scheme
	-- when the current scheme isn't in the list, seed idx so the first press lands
	-- on schemes[1] going forward and schemes[#schemes] going back.
	local idx = delta > 0 and 0 or 1
	for i, s in ipairs(schemes) do
		if s == current then
			idx = i
			break
		end
	end
	local scheme = schemes[(idx - 1 + delta) % #schemes + 1]
	window:set_config_overrides({ color_scheme = scheme })
	flash_scheme(window, scheme)
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
	flash_scheme(window, scheme)
end)

wezterm.on("augment-command-palette", function(window, _)
	return {
		{
			brief = "Scheme: " .. (window:effective_config().color_scheme or "default"),
			icon = "md_palette",
			action = wezterm.action_callback(function(win, _)
				flash_scheme(win, win:effective_config().color_scheme or "default")
			end),
		},
		{
			brief = "Right status: switch to " .. next_right_status(right_status_mode[window:window_id()]),
			icon = "md_swap_horizontal",
			action = wezterm.action_callback(toggle_right_status),
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
