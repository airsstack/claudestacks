-- Pure formatting for the Claude Code status line: paths, token counts, the context bar,
-- segment joining, and the full two-line render.
--
-- NOT plugin content. Claude Code cannot load a status line from a plugin — `statusLine` is a
-- settings key, and this file is installed into ~/.claude by statusline-install.lua. It lives
-- here for the same reason install-airsl.sh does: the repository is its source of truth.
--
-- Split from the driver so the parts where defects concentrate — bar fill, colour bands, and
-- segment joining — are testable against plain tables, with no stdin and no git repository.

local M = {}

-- Abbreviate `cwd` to `~/...` when it lies under `home`. The boundary check is a path check,
-- not a string-prefix check: "/Users/xfoo" is not under "/Users/x".
function M.abbreviate_path(cwd, home)
  if not cwd or cwd == "" then
    return ""
  end
  if not home or home == "" then
    return cwd
  end
  if cwd == home then
    return "~"
  end
  if cwd:sub(1, #home + 1) == home .. "/" then
    return "~" .. cwd:sub(#home + 1)
  end
  return cwd
end

-- 1_000_000+ → "1.0M", 1_000+ → "1.0k", else the integer. Mirrors the bash reference's awk block.
function M.format_tokens(n)
  n = tonumber(n) or 0
  if n >= 1000000 then
    return string.format("%.1fM", n / 1000000)
  end
  if n >= 1000 then
    return string.format("%.1fk", n / 1000)
  end
  return string.format("%d", math.floor(n))
end

M.BAR_WIDTH = 10

-- Dimmed (SGR 2) throughout, bira-like.
M.CYAN = "\27[2;36m"
M.YELLOW = "\27[2;33m"
M.GREEN = "\27[2;32m"
M.RED = "\27[2;31m"
M.DIM = "\27[2m"
M.RESET = "\27[0m"

-- Green below 50%, yellow below 80%, red at or above it.
function M.band(pct)
  pct = tonumber(pct) or 0
  if pct < 50 then
    return M.GREEN
  end
  if pct < 80 then
    return M.YELLOW
  end
  return M.RED
end

-- A proportional block bar. `string.rep` repeats the whole multi-byte character, so the
-- UTF-8 blocks survive intact.
function M.bar(pct, width)
  width = width or M.BAR_WIDTH
  pct = tonumber(pct) or 0
  local filled = math.floor((pct * width / 100) + 0.5)
  if filled < 0 then
    filled = 0
  end
  if filled > width then
    filled = width
  end
  return string.rep("▰", filled) .. string.rep("▱", width - filled)
end

-- Join with " · ". No empty-string filtering happens here: an empty segment is concatenated
-- like any other and produces a doubled separator around it. The caller is responsible for
-- omitting a segment that does not exist rather than passing an empty string for it.
function M.join(segments)
  return table.concat(segments, " " .. M.DIM .. "·" .. M.RESET .. " ")
end

-- Render the status line. `git_info` is {branch, ahead, behind}, any field nil; a nil branch
-- means "not in a repository" and suppresses the whole git segment. Returns a list of line
-- strings so the driver owns the trailing newline and tests can assert per line.
function M.render(payload, git_info, home)
  payload = payload or {}
  git_info = git_info or {}
  local workspace = payload.workspace or {}
  local cwd = workspace.current_dir or payload.cwd or ""

  local lines = {}

  local line1 = M.YELLOW .. M.abbreviate_path(cwd, home) .. M.RESET
  if git_info.branch and git_info.branch ~= "" then
    local git_segment = M.CYAN .. git_info.branch .. M.RESET
    if git_info.ahead and git_info.behind then
      git_segment = git_segment
        .. " " .. M.DIM .. "·" .. M.RESET
        .. " ↑" .. git_info.ahead .. " ↓" .. git_info.behind
    end
    line1 = line1 .. " " .. M.DIM .. "|" .. M.RESET .. " " .. git_segment
  end
  lines[1] = line1

  return lines
end

return M
