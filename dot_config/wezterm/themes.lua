-- color scheme handling: random roll per window, manual cycling, favorites
local wezterm = require("wezterm")
local flash = require("flash")

local M = {}

-- comment favorite themes out of the random arrays below
M.fav = { light = "Catppuccin Latte", dark = "Catppuccin Mocha" }
if wezterm.GLOBAL.follow_os_appearance == nil then
	wezterm.GLOBAL.follow_os_appearance = true
end

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

-- set (or clear, with nil) only the color_scheme override so unrelated
-- overrides survive. Clearing triggers window-config-reloaded, which rolls a
-- fresh random scheme.
function M.set_scheme_override(window, scheme)
	local overrides = window:get_config_overrides() or {}
	overrides.color_scheme = scheme
	window:set_config_overrides(overrides)
end

-- step delta places through active_schemes() from the current scheme, wrapping
-- at the ends, and flash the name. No stored index: the position is derived from
-- the current override each press, so it stays correct after a random roll. A
-- scheme that's in the list is preserved by the roller's guard, so this doesn't
-- get re-rolled out from under you.
local function cycle_scheme(window, delta)
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
	M.set_scheme_override(window, scheme)
	flash.scheme(window, scheme)
end

-- step forward/back through the active scheme list
M.scheme_next = wezterm.action_callback(function(window, _)
	cycle_scheme(window, 1)
end)
M.scheme_prev = wezterm.action_callback(function(window, _)
	cycle_scheme(window, -1)
end)

function M.following_os_appearance()
	return wezterm.GLOBAL.follow_os_appearance
end

function M.toggle_follow_os_appearance(window, _)
	wezterm.GLOBAL.follow_os_appearance = not wezterm.GLOBAL.follow_os_appearance
	M.set_scheme_override(window, nil)
end

function M.setup()
	wezterm.on("window-config-reloaded", function(window, _)
		local current = (window:get_config_overrides() or {}).color_scheme
		if current == M.fav.light or current == M.fav.dark then
			return
		end

		local schemes = active_schemes()
		for _, s in ipairs(schemes) do
			if s == current then
				return
			end
		end
		local scheme = schemes[math.random(#schemes)]
		M.set_scheme_override(window, scheme)
		flash.scheme(window, scheme)
	end)
end

return M
