local wezterm = require("wezterm")
local platform = require("platform")

local SCHEME_GLYPH = wezterm.nerdfonts.md_palette

local M = {}

-- flash bold text in the left status for a few seconds. Drawn in-window rather
-- than via toast_notification, which depends on macOS notification permissions.
-- Per-window generation token so a later flash isn't cleared by an earlier timer.
local flash_gen = {}
function M.text(window, text)
	window:set_left_status(wezterm.format({
		{ Attribute = { Intensity = "Bold" } },
		{ Text = text },
	}))
	local id = window:window_id()
	flash_gen[id] = (flash_gen[id] or 0) + 1
	local gen = flash_gen[id]
	wezterm.time.call_after(5, function()
		if flash_gen[id] == gen then
			-- no newer flash superseded this one, so the entry can go too
			flash_gen[id] = nil
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
local LEFT_PAD = platform.is_mac and "     " or " "
function M.scheme(window, scheme)
	M.text(window, LEFT_PAD .. SCHEME_GLYPH .. " " .. scheme .. "  ")
end

return M
