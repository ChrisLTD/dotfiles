-- extra command palette entries wiring themes and the right-status toggle
local wezterm = require("wezterm")
local flash = require("flash")
local status = require("status")
local themes = require("themes")

local M = {}

function M.setup()
	wezterm.on("augment-command-palette", function(window, _)
		return {
			{
				brief = "Scheme: " .. (window:effective_config().color_scheme or "default"),
				icon = "md_palette",
				action = wezterm.action_callback(function(win, _)
					flash.scheme(win, win:effective_config().color_scheme or "default")
				end),
			},
			{
				brief = "Right status: switch to " .. status.next_mode_for(window),
				icon = "md_swap_horizontal",
				action = wezterm.action_callback(status.toggle),
			},
			{
				brief = "Scheme: next",
				icon = "md_skip_next",
				action = themes.scheme_next,
			},
			{
				brief = "Scheme: previous",
				icon = "md_skip_previous",
				action = themes.scheme_prev,
			},
			{
				brief = "Theme: " .. themes.fav.dark,
				icon = "md_weather_night",
				action = wezterm.action_callback(function(win, _)
					themes.set_scheme_override(win, themes.fav.dark)
				end),
			},
			{
				brief = "Theme: " .. themes.fav.light,
				icon = "md_weather_sunny",
				action = wezterm.action_callback(function(win, _)
					themes.set_scheme_override(win, themes.fav.light)
				end),
			},
			{
				brief = "Theme: Random",
				icon = "md_shuffle",
				action = wezterm.action_callback(function(win, _)
					themes.set_scheme_override(win, nil)
				end),
			},
			{
				brief = "Theme: Toggle OS appearance matching ("
					.. (themes.following_os_appearance() and "on" or "off")
					.. ")",
				icon = "md_theme_light_dark",
				action = wezterm.action_callback(themes.toggle_follow_os_appearance),
			},
		}
	end)
end

return M
