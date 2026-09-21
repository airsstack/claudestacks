-- Schema conformance for a written handoff report.
--
-- The rules live here and only here. Prose mirror:
-- `skills/context-handoff/references/protocol.md`. The two MUST agree — change one, change the
-- other.
--
-- Split from the driver so every rule is exercised against a fixture file rather than through a
-- process, and so the hook wrapper and a driver checking a report by hand run identical logic.

local fs = airsstack.fs
local handoff = require("lib.handoff")

local M = {}

-- Reads the frontmatter block: the lines between a leading `---` and the next `---`.
--
-- Returns the key/value table and the index of the line after the closing marker. On failure
-- returns `nil, 1, reason` where `reason` is `"missing"` when the first line is not `---` (no
-- block was ever opened, so there is no recovery to attempt) or `"unterminated"` when a block
-- opened but the loop ran out of lines before finding the closing `---`. The two are distinct
-- failures with distinct causes, so `M.check` needs the reason to report the true one.
function M.frontmatter(lines)
  if lines[1] ~= "---" then
    return nil, 1, "missing"
  end
  local keys = {}
  for index = 2, #lines do
    if lines[index] == "---" then
      return keys, index + 1
    end
    local key, value = lines[index]:match("^([%w_-]+):%s*(.-)%s*$")
    if key then
      keys[key] = value
    end
  end
  return nil, 1, "unterminated"
end

-- Distinguishes an absent file from a confinement refusal in a `fs.read_lines` pcall error.
--
-- Matches on `outside the granted read roots`, the phrase specific to a confinement denial
-- (probed against `airsl` 0.1.2, 2026-09-21: `fs.read_lines denied: ... is outside the granted
-- read roots: ...`) rather than on the bare word `denied`, which would also catch an OS-level
-- refusal — a mode-000 file returns `Permission denied (os error 13)`, probed the same day. Everything
-- else classifies as `unreadable`: an absent file or broken symlink (`No such file or
-- directory (os error 2)`), a directory (`Is a directory (os error 21)`), that permission
-- refusal, and non-UTF-8 bytes (`stream did not contain valid UTF-8`).
--
-- The phrase is a literal copy of what this version of the runtime emits, and `airsl-cli` is
-- installed unpinned, so an upstream rewording would silently route refusals back to
-- `unreadable` with the suite still green. Re-probe it when the runtime moves.
function M.classify_read_error(err)
  if tostring(err):find("outside the granted read roots", 1, true) then
    return "read-denied"
  end
  return "unreadable"
end

-- Whether `file` sits under a minted session tree.
--
-- Keyed off the segment the session manager actually mints rather than a copy of the string, so
-- the two can never disagree. Both other tiers — a literal temp path, and the
-- `<session-scratch>/handoff/` fallback when `init` is refused — answer false, which is what
-- makes `session:`/`seq:` forbidden in each.
function M.session_tier(file)
  return file:find(handoff.HANDOFF_REL, 1, true) ~= nil
end

-- Counts opening and closing tag lines for `name`, and whether any enclosed line has content.
--
-- A tag line is the tag ALONE on its line — anchored at both ends. A line reading
-- `<summary>text` is body, not a tag. That is what lets a report discuss the schema in prose
-- without the discussion being counted as structure, which an unanchored count got wrong.
function M.tags(lines, name, from)
  local opens, closes, content = 0, 0, false
  local inside = false
  for index = from, #lines do
    local line = lines[index]
    if line == "<" .. name .. ">" then
      opens = opens + 1
      inside = true
    elseif line == "</" .. name .. ">" then
      closes = closes + 1
      inside = false
    elseif inside and line:match("%S") then
      content = true
    end
  end
  return opens, closes, content
end

-- Every way `file` violates the schema, as a list of `{ id = ..., line = ... }`.
function M.check(file)
  local ok, lines_or_err = pcall(fs.read_lines, file)
  if not ok then
    local id = M.classify_read_error(lines_or_err)
    local line = id == "read-denied"
        and "the read was refused by the confinement policy: " .. file
      or "cannot read " .. file
    return { { id = id, line = line } }
  end
  local lines = lines_or_err

  local violations = {}
  local function fail(id, line)
    violations[#violations + 1] = { id = id, line = line }
  end

  local keys, body_from, reason = M.frontmatter(lines)
  if not keys then
    if reason == "unterminated" then
      fail("frontmatter-unterminated", "the file opens with `---` but never closes the block")
    else
      fail("frontmatter-missing", "the file does not open with a `---` block")
    end
  else
    for _, key in ipairs({ "agent", "task" }) do
      if not keys[key] or keys[key] == "" then
        fail(key .. "-missing", "frontmatter is missing a non-empty `" .. key .. ":`")
      end
    end

    local session_tier = M.session_tier(file)
    for _, key in ipairs({ "session", "seq" }) do
      local present = keys[key] and keys[key] ~= ""
      if session_tier and not present then
        fail(key .. "-missing", "a session-tier report must carry `" .. key .. ":`")
      elseif not session_tier and present then
        fail(key .. "-unexpected", "`" .. key .. ":` belongs only to a session-tier report")
      end
    end
  end

  local opens, closes, content = M.tags(lines, "summary", body_from)
  if opens == 0 then
    fail("summary-missing", "no `<summary>` line of its own")
  elseif opens > 1 then
    fail("summary-repeated", "more than one `<summary>` pair")
  elseif closes < opens then
    fail("summary-unclosed", "`<summary>` with no matching `</summary>`")
  elseif not content then
    fail("summary-empty", "`<summary>` encloses only whitespace")
  end

  local detail_opens, detail_closes = M.tags(lines, "detail", body_from)
  if detail_opens > 1 then
    fail("detail-repeated", "more than one `<detail>` pair")
  elseif detail_closes < detail_opens then
    fail("detail-unclosed", "`<detail>` with no matching `</detail>`")
  end

  return violations
end

return M
