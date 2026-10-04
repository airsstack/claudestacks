-- Schema conformance for a written handoff report.
--
-- The rules live here and only here. Prose mirror:
-- `skills/context-handoff/references/protocol.md`. The two MUST agree — change one, change the
-- other.
--
-- Split from the driver so every rule is exercised against a fixture file rather than through a
-- process, and so the hook wrapper and a driver checking a report by hand run identical logic.

local fs = airsstack.fs
local env = airsstack.env
local path = airsstack.path
local handoff = require("lib.handoff")

local M = {}

-- Rewrites a leading `/private/tmp` to `/tmp`. macOS makes `/tmp` a symlink to `/private/tmp`
-- (`readlink /tmp` -> `private/tmp`, checked 2026-10-04 on this machine) and a real hook
-- payload can carry either spelling depending on what the writing process's own environment
-- held. Pure string handling rather than `fs.canonicalize`: resolving the symlink for real would
-- need a read grant this check must not require.
local function tmp_alias(candidate)
  local private_tmp = "/private/tmp"
  if candidate == private_tmp then
    return "/tmp"
  end
  local prefix = private_tmp .. "/"
  if candidate:sub(1, #prefix) == prefix then
    return "/tmp/" .. candidate:sub(#prefix + 1)
  end
  return candidate
end

-- Whether `candidate` is `root` or sits inside it, after both pass through `tmp_alias` and
-- `root`'s own trailing slash (`$TMPDIR` usually carries one) is stripped.
local function under(candidate, root)
  root = root:gsub("/+$", "")
  if root == "" then
    return false
  end
  local c, r = tmp_alias(candidate), tmp_alias(root)
  return c == r or c:sub(1, #r + 1) == r .. "/"
end

-- Whether `candidate` sits DIRECTLY in `root`, with no intervening directory.
--
-- `under` is too loose for the temp tiers. The exception tier is `${TMPDIR}/<driver>-<slug>.md`
-- — a direct child by construction — whereas `under` admits anything at any depth below `/tmp`,
-- which is where every session's scratchpad lives. That cost a live false positive: a `.txt`
-- commit-message file written to `<scratch>/msgs3/9.txt` was validated as a handoff report and
-- its violations attached to the write.
local function direct_child(candidate, root)
  root = root:gsub("/+$", "")
  if root == "" then
    return false
  end
  local c, r = tmp_alias(candidate), tmp_alias(root)
  if c:sub(1, #r + 1) ~= r .. "/" then
    return false
  end
  local rest = c:sub(#r + 2)
  return rest ~= "" and not rest:find("/", 1, true)
end

-- Makes `file` absolute, resolving a relative path against `cwd` first, or nil when there is
-- nothing to resolve it against.
--
-- A relative path with no `cwd` is refused rather than falling back to the process's own working
-- directory: that fallback is defect C — the same relative handoff path validated from one
-- directory and failed to open from another, because nothing passed the payload's `cwd` through.
-- `protocol.md:90-92` requires a session-tree path to be returned relative to the worktree root,
-- so resolving against the caller's own notion of "here" is the specified normal case, not an
-- edge case to approximate.
local function resolve_against(file, cwd)
  if type(file) ~= "string" or file == "" then
    return nil
  end
  if path.is_absolute(file) then
    return path.normalize(file)
  end
  if type(cwd) ~= "string" or cwd == "" then
    return nil
  end
  return path.normalize(path.join(cwd, file))
end

-- Whether `file` lies under a handoff root: the session tree, or the temp root the exception
-- and `init`-refused tiers use. A relative `file` is resolved against `cwd` first. Non-string or
-- empty `file` is false, never an error — `resolve_against` already answers nil for both, and
-- for a relative path with no `cwd` to resolve against.
--
-- This is the fix for defects A and B. The hooks previously matched on shape (the last `.md`
-- path in the text, or a `.md` extension alone) rather than location, so a trailing citation
-- (`hooks.md:1011`), a documentation URL, or an ordinary project file (a plan, a spec,
-- `CLAUDE.md`) was taken for a report path or validated as one. Location, unlike name shape,
-- covers both tiers: the session tree is a known relative segment and the exception tier is by
-- definition a temp path, so neither a citation nor a project file qualifies under either.
function M.under_handoff_root(file, cwd)
  local resolved = resolve_against(file, cwd)
  if not resolved then
    return false
  end

  -- A report is a Markdown file in every tier the protocol defines, so the extension is part of
  -- the root test rather than a separate filter at one call site. `M.path_in_root` only ever
  -- offers `.md` candidates, so this is a no-op for the two gate legs; it is load-bearing for
  -- `PostToolUse`, which is handed an arbitrary `tool_input.file_path`. Dropping it there was
  -- defect B's second half: the fix round replaced the `%.md$` filter with the root test instead
  -- of requiring both, so every file written anywhere under `/tmp` was checked as a report.
  if resolved:sub(-3) ~= ".md" then
    return false
  end

  -- Session tree: the segment `handoff.lua` itself mints. Unambiguous — nothing but reports is
  -- written there.
  if resolved:find(handoff.HANDOFF_REL, 1, true) then
    return true
  end

  -- `init`-refused fallback: `<session-scratch>/handoff/<NN>-<agent>-<slug>.md`. The segment is
  -- what distinguishes it from the rest of a session scratchpad, which is not reports.
  if resolved:find("/handoff/", 1, true) then
    return true
  end

  -- Exception tier: `${TMPDIR}/<driver>-<slug>.md`, a DIRECT child. Not `under`, which would
  -- re-admit every nested scratchpad file — see `direct_child`.
  --
  -- `pcall`ed: `env.get` is a capability like any other, and this suite's own test grant
  -- (`cargo make plugins-test`) does not include `--allow-env TMPDIR`. A denial here falls back
  -- to the `/tmp` check below rather than raising, so the function keeps the "never an error"
  -- contract its own doc comment promises for a bad path and extends it to a withheld grant.
  local ok, tmpdir = pcall(env.get, "TMPDIR")
  if ok and tmpdir and tmpdir ~= "" and direct_child(resolved, tmpdir) then
    return true
  end
  return direct_child(resolved, "/tmp")
end

-- `file`, resolved and root-qualified, or nil. Shared by `M.path_in_root` and
-- `M.file_from_payload` so both apply exactly the same test to exactly the same resolved path.
local function qualifying(candidate, cwd)
  local resolved = resolve_against(candidate, cwd)
  if resolved and M.under_handoff_root(resolved, nil) then
    return resolved
  end
  return nil
end

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

-- The report path stated in an agent's return text: the LAST `.md` path in it, with leading
-- wrapper punctuation (a backtick, a bracket, a quote) stripped.
--
-- Not a shaped name. An exception-tier report is named by its driver, with no
-- `NN-agent-slug` prefix and no `handoff/` segment, so a shape-keyed matcher would miss every
-- single-subagent driver and leave the gate silently off for four of the six.
--
-- There is no matching strip for trailing punctuation: `(%S+%.md)` captures a run ending in the
-- literal characters `md`, and Lua's greedy-then-backtrack matching already stops the capture at
-- the earliest point where `.md` closes it — so a token like `a-report.md.` or `` `a-report.md` ``
-- never leaves trailing punctuation inside the match for a second pass to remove. Confirmed by
-- deleting the gsub this comment used to sit above and watching this function's own six fixture
-- tests (`a_trailing_period_is_not_part_of_the_path` among them) stay green.
--
-- This is a raw tokeniser, nothing more — it does not know where a handoff root is, which is why
-- defect A (a trailing citation like `hooks.md:1011` winning over the real path) lived here.
-- `M.path_in_root` is the root-aware replacement the hook entry calls; this stays only because
-- its own behaviour and tests are unchanged by that fix.
function M.path_in(text)
  if type(text) ~= "string" then
    return nil
  end
  local found = nil
  for candidate in text:gmatch("(%S+%.md)") do
    found = candidate
  end
  if not found then
    return nil
  end
  return (found:gsub("^[%(%[`\"']+", ""))
end

-- The LAST `.md` path in `text` that lies under a handoff root (`M.under_handoff_root`), or nil.
--
-- Walks every `.md` candidate in order rather than taking the raw last one and then testing it:
-- a report that correctly states its handoff path and then cites unrelated evidence —
-- `hooks.md:1011`, a documentation URL, `CLAUDE.md` — has those candidates appear later in the
-- text, and each is rejected by the root test in turn, leaving the real path as the last
-- survivor. "Nothing qualifies" is the standalone case and returns nil, never held as a
-- violation.
function M.path_in_root(text, cwd)
  if type(text) ~= "string" then
    return nil
  end
  local found = nil
  for raw in text:gmatch("(%S+%.md)") do
    local candidate = (raw:gsub("^[%(%[`\"']+", ""))
    local resolved = qualifying(candidate, cwd)
    if resolved then
      found = resolved
    end
  end
  return found
end

-- The handoff report path a hook payload points at, root-aware, or nil.
--
-- One entry point for all three events `handoff_check_hook.lua` fires on, so the "which file
-- does this payload name" decision is exercised directly by this suite rather than only through
-- the shell launcher end to end.
--
--   PostToolUse(Write)           `tool_input.file_path` (always absolute per `hooks.md:2004`),
--                                 tested against the handoff root directly — this is the fix for
--                                 defect B, which matched any `.md` extension instead.
--   PreToolUse(SubagentHandback) the LAST qualifying `.md` path in `tool_input.message`.
--   SubagentStop                 the LAST qualifying `.md` path in `last_assistant_message`.
--
-- `payload.cwd` is threaded through to the root test and the path resolution for both tiers:
-- `tool_input.file_path` is already absolute so it is unaffected, but a session-tree path
-- returned relative to the worktree root (the specified normal case, `protocol.md:90-92`) needs
-- it to resolve to the right file rather than to whatever directory the hook process happens to
-- be standing in.
function M.file_from_payload(payload)
  if type(payload) ~= "table" then
    return nil
  end
  local tool_input = type(payload.tool_input) == "table" and payload.tool_input or {}
  local cwd = type(payload.cwd) == "string" and payload.cwd or nil
  local event = payload.hook_event_name

  if event == "PostToolUse" then
    return qualifying(tool_input.file_path, cwd)
  elseif event == "PreToolUse" then
    return M.path_in_root(tool_input.message, cwd)
  elseif event == "SubagentStop" then
    return M.path_in_root(payload.last_assistant_message, cwd)
  end
  return nil
end

return M
