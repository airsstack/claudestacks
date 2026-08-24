-- Claude Code status line driver: stdin payload → git → two lines on stdout.
--
-- NOT plugin content. `statusLine` is a settings key, not a plugin component type; this file is
-- installed into ~/.claude/statusline/ by statusline-install.lua and invoked by Claude Code.
--
--   airsl run --fail-open --allow-exec git --allow-env HOME \
--     ~/.claude/statusline/statusline.lua
--
-- Every formatting decision lives in lib/statusline.lua; this file only gathers and prints.

local sl = require("lib.statusline")
local stdio = airsstack.stdio
local json = airsstack.json
local proc = airsstack.proc
local env = airsstack.env

-- Run git with optional locks skipped so a lockfile never blocks a render. Arguments are argv
-- elements, never a shell string: payload- and repo-derived values are untrusted, and
-- --allow-exec git only means something while nothing can turn an argument into a command.
local function git(cwd, ...)
  local argv = { "git", "-C", cwd, "--no-optional-locks", ... }
  local ok, result = pcall(proc.run, argv)
  if not ok or result.status ~= 0 then
    return nil
  end
  return result.stdout
end

local function git_info(cwd)
  if not cwd or cwd == "" then
    return {}
  end
  if not git(cwd, "rev-parse", "--is-inside-work-tree") then
    return {}
  end

  local branch = git(cwd, "branch", "--show-current")
  branch = branch and branch:gsub("%s+$", "") or ""
  if branch == "" then
    -- Detached HEAD: fall back to the short SHA.
    local sha = git(cwd, "rev-parse", "--short", "HEAD")
    branch = sha and sha:gsub("%s+$", "") or ""
  end
  if branch == "" then
    return {}
  end

  local counts = git(cwd, "rev-list", "--left-right", "--count", "@{upstream}...HEAD")
  local ahead, behind = sl.parse_ahead_behind(counts)
  return { branch = branch, ahead = ahead, behind = behind }
end

local payload = json.decode(stdio.read())
local workspace = payload.workspace or {}
local cwd = workspace.current_dir or payload.cwd or ""

for _, line in ipairs(sl.render(payload, git_info(cwd), env.get("HOME"))) do
  stdio.write(line .. "\n")
end
