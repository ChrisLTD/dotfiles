-- right part of the top bar: git branch (preferred) or cwd, per-window mode
local wezterm = require("wezterm")

local M = {}

-- glyphs: powerline branch + nerdfont folder
local BRANCH_GLYPH = utf8.char(0xe0a0)
local FOLDER_GLYPH = wezterm.nerdfonts.md_folder

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

-- truncate to at most n characters without splitting a UTF-8 sequence
-- (string.sub counts bytes and can cut a multi-byte character in half)
local function utf8_truncate(s, n)
	local byte_after = utf8.offset(s, n + 1)
	return byte_after and s:sub(1, byte_after - 1) or s
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
			-- detached HEAD: keep the HEAD marker so the state is obvious, and
			-- append the short hash so it also says where you are
			local ok_sha, sha = wezterm.run_child_process({
				"git", "-C", path, "rev-parse", "--short", "HEAD",
			})
			branch = ok_sha and "HEAD@" .. sha:gsub("%s+$", "") or "HEAD"
		else
			branch = branch:gsub("^chrisltd/", ""):gsub("^feature/eng%-", "")
			branch = utf8_truncate(branch, 25)
		end
	end
	branch_cache[path] = { branch = branch, expires_at = now + BRANCH_TTL }
	return branch
end

-- per-window right-status mode, cycled by mod+SHIFT+I:
--   "branch" (default, cwd fallback) -> "cwd" -> "both" (cwd + branch)
local right_status_modes = { "branch", "cwd", "both" }
local right_status_mode = {}

-- the mode the window would switch to next
function M.next_mode_for(window)
	local mode = right_status_mode[window:window_id()] or "branch"
	for i, m in ipairs(right_status_modes) do
		if m == mode then
			return right_status_modes[i % #right_status_modes + 1]
		end
	end
	return right_status_modes[1]
end

function M.toggle(window, _)
	right_status_mode[window:window_id()] = M.next_mode_for(window)
end

-- evict stale cache entries so long-running sessions don't accumulate state
-- for closed panes/windows: expired branch results and right-status modes for
-- windows that no longer exist. Throttled to once per SWEEP_INTERVAL; called
-- from the status hot path, which is why it stays cheap.
local SWEEP_INTERVAL = 60
local next_sweep = 0
local function sweep_caches()
	local now = os.time()
	if now < next_sweep then
		return
	end
	next_sweep = now + SWEEP_INTERVAL
	for path, entry in pairs(branch_cache) do
		if now >= entry.expires_at then
			branch_cache[path] = nil
		end
	end
	local live = {}
	for _, w in ipairs(wezterm.gui.gui_windows()) do
		live[w:window_id()] = true
	end
	for id in pairs(right_status_mode) do
		if not live[id] then
			right_status_mode[id] = nil
		end
	end
end

function M.setup()
	wezterm.on("update-right-status", function(window, pane)
		sweep_caches()

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
			text = " " .. FOLDER_GLYPH .. " " .. dir .. " " .. BRANCH_GLYPH .. " " .. utf8_truncate(branch, 13) .. " "
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
end

return M
