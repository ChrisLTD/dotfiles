-- key bindings; returns the list assigned to config.keys
local wezterm = require("wezterm")
local platform = require("platform")
local status = require("status")
local themes = require("themes")

local act = wezterm.action
local mod = platform.mod

return {
	{
		key = "P",
		mods = platform.is_mac and "CMD|SHIFT" or "CTRL|SHIFT",
		action = act.ActivateCommandPalette,
	},
	{ key = "[", mods = "CTRL|SHIFT", action = act.MoveTabRelative(-1) },
	{ key = "]", mods = "CTRL|SHIFT", action = act.MoveTabRelative(1) },
	{ key = "d", mods = mod, action = act.SplitPane({ direction = "Right" }) },
	{ key = "d", mods = mod .. "|SHIFT", action = act.SplitPane({ direction = "Down" }) },
	-- step forward/back through the active color scheme list (mod+SHIFT+< / >).
	-- both glyph forms are bound since wezterm may report the key as the shifted
	-- glyph (< >) or the base key (, .) depending on the setup.
	{ key = ">", mods = mod .. "|SHIFT", action = themes.scheme_next },
	{ key = ".", mods = mod .. "|SHIFT", action = themes.scheme_next },
	{ key = "<", mods = mod .. "|SHIFT", action = themes.scheme_prev },
	{ key = ",", mods = mod .. "|SHIFT", action = themes.scheme_prev },
	{
		-- toggle the right status between branch and cwd (per window)
		key = "i",
		mods = mod .. "|SHIFT",
		action = wezterm.action_callback(status.toggle),
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
