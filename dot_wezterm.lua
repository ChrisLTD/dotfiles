local wezterm = require("wezterm")

local act = wezterm.action
local config = wezterm.config_builder()

-- comment favorite themes out of random arrays below
local fav_theme = { light = "Catppuccin Latte", dark = "Catppuccin Mocha" }
-- per-repo background tinting; toggleable from the command palette
if wezterm.GLOBAL.tint_enabled == nil then
	wezterm.GLOBAL.tint_enabled = true
end
local is_mac = wezterm.target_triple:find("darwin") ~= nil

local function os_is_dark()
	return wezterm.gui.get_appearance():find("Dark") ~= nil
end

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

-- ===== per-repo background tint =====
-- One blessed light + dark scheme; only the background hue varies, keyed to the
-- repo root (cwd basename outside a repo). Lightness is held at the blessed
-- scheme's own value so text contrast is unchanged; we nudge only hue + a little
-- saturation.

-- djb2 string hash, masked to 32 bits
local function hash(str)
	local h = 5381
	for i = 1, #str do
		h = (h * 33 + str:byte(i)) % 0x100000000
	end
	return h
end

-- pristine background lightness/alpha of a blessed scheme, memoized. Read from
-- the builtin scheme (not the live palette) so re-tinting never compounds.
local blessed_bg = {}
local function blessed_lightness(scheme)
	local cached = blessed_bg[scheme]
	if cached then
		return cached
	end
	local s = wezterm.color.get_builtin_schemes()[scheme]
	local _, _, l, a = wezterm.color.parse(s.background):hsla()
	cached = { l = l, a = a }
	blessed_bg[scheme] = cached
	return cached
end

-- repo-root basename for the pane's cwd (cwd basename outside a repo, "" if not a
-- local path). Cached per pane like pane_branch so git stays off the per-second path.
local repo_cache = {}
local function context_key(pane)
	local cwd = pane:get_current_working_dir()
	if not cwd or cwd.scheme ~= "file" or not cwd.file_path then
		return ""
	end
	local path = cwd.file_path
	local id = pane:pane_id()
	local now = os.time()
	local cached = repo_cache[id]
	if cached and cached.path == path and now < cached.expires_at then
		return cached.key
	end
	local key = ""
	local ok, stdout = wezterm.run_child_process({
		"git", "-C", path, "rev-parse", "--show-toplevel",
	})
	if ok then
		key = stdout:gsub("%s+$", ""):match("([^/]+)/?$") or ""
	end
	if key == "" then
		key = path:match("([^/]+)/?$") or "/"
	end
	repo_cache[id] = { path = path, key = key, expires_at = now + BRANCH_TTL }
	return key
end

-- apply the blessed scheme + tinted background for the active pane's context.
-- Only re-applies when the context key or OS appearance changes, so it doesn't
-- thrash config reloads from the per-second status handler.
local window_theme = {}
local function apply_theme(window, pane)
	local is_dark = os_is_dark()
	local blessed = is_dark and fav_theme.dark or fav_theme.light
	local key = wezterm.GLOBAL.tint_enabled and context_key(pane) or ""
	local id = window:window_id()
	local prev = window_theme[id]
	if prev and prev.key == key and prev.blessed == blessed then
		return
	end
	window_theme[id] = { key = key, blessed = blessed }

	local overrides = { color_scheme = blessed }
	local hue
	if key ~= "" then
		local base = blessed_lightness(blessed)
		hue = hash(key) % 360
		local sat = is_dark and 0.18 or 0.10
		local c = wezterm.color.from_hsla(hue, sat, base.l, base.a)
		local r, g, b = c:srgba_u8()
		overrides.colors = { background = string.format("#%02x%02x%02x", r, g, b) }
	end
	window:set_config_overrides(overrides)

	-- TEMPORARY calibration readout; drop once the saturation feels right
	if hue then
		flash(window, "     " .. key .. " · hue " .. hue)
	end
end

config.color_scheme = os_is_dark() and fav_theme.dark or fav_theme.light
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
	apply_theme(window, pane)
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

wezterm.on("augment-command-palette", function(_, _)
	return {
		{
			brief = "Show current path + branch",
			icon = "md_folder_information",
			action = wezterm.action_callback(show_path_info),
		},
		{
			brief = "Tint: toggle per-repo background (" .. (wezterm.GLOBAL.tint_enabled and "on" or "off") .. ")",
			icon = "md_palette",
			action = wezterm.action_callback(function(window, pane)
				wezterm.GLOBAL.tint_enabled = not wezterm.GLOBAL.tint_enabled
				window_theme[window:window_id()] = nil -- force re-apply on next tick
				apply_theme(window, pane)
			end),
		},
	}
end)

return config
