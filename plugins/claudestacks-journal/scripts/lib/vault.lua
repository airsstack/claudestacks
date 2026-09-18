-- Shared vault helpers for the claudestacks-journal scripts.
--
-- Required by every script in this directory (`require("lib.vault")`), which the confined
-- `require` resolves against the script's own directory. Nothing here reaches outside the
-- capabilities the calling script was granted: each function raises the runtime's own denial
-- message when the policy did not grant what it needs.

local fs = airsstack.fs
local path = airsstack.path
local regex = airsstack.regex

local M = {}

-- Every character outside [A-Za-z0-9._-] becomes '-', matching `tr -c 'A-Za-z0-9._-' '-'`.
function M.sanitize(text)
  return regex.replace_all("[^A-Za-z0-9._-]", text or "", "-")
end

-- The working directory, as an absolute path. `path.absolute` needs no grant.
function M.cwd()
  return path.absolute(".")
end

-- The main repository's `.git`, found by reading rather than by running git, or nil outside a
-- repository.
--
-- Names the same directory `rev-parse --git-common-dir` does, without the `--allow-exec git`
-- grant — the same directory, not necessarily the same spelling: a relative `gitdir:` pointer
-- yields an uncanonicalised path here, which `project_base` canonicalises before it is used. A
-- worktree-isolated Claude Code session cannot pass that flag (the `claudestacks` plugin's
-- `skills/process-guidelines/references/context-handoff.md` has the full account). The answer is
-- on disk either way — `.git` is a directory in a plain checkout, and in a linked
-- worktree a file holding `gitdir: <main>/.git/worktrees/<name>`, whose `worktrees/<name>` tail is
-- dropped to reach the one `.git` every worktree of the repository shares.
--
-- Ascends to the root because a caller may stand in a subdirectory, which is the case git handled.
function M.common_dir(dir)
  local current = M.realpath(dir) or dir
  while true do
    local candidate = path.join(current, ".git")
    -- Guarded: the ascent leaves the granted read root on its first step whenever the caller is
    -- below it, and `--allow-read .` is exactly what this script is invoked with. A denial means
    -- "cannot see", so the walk continues and the caller falls back as it did before.
    local seen, present = pcall(fs.exists, candidate)
    if seen and present then
      -- A refused question is not an answer: without knowing whether `.git` is a directory or a
      -- pointer file, neither branch below is safe, so the caller is told nothing rather than
      -- told "plain checkout".
      local ok, is_file = pcall(fs.is_file, candidate)
      if not ok then
        return nil
      end
      if not is_file then
        return candidate
      end
      -- A `.git` file that is not a readable gitdir pointer ends the search rather than passing
      -- it upwards: git itself refuses here (`fatal: invalid gitfile format`, exit 128), and the
      -- repository above is a different repository from the one the caller stands in. Matches
      -- `lib/enforce.lua`'s `common_dir`.
      return M.gitdir_pointer(current, candidate)
    end
    local parent = path.dirname(current)
    if parent == current or parent == "" then
      return nil
    end
    current = parent
  end
end

-- The common `.git` a worktree's `.git` file points at, or nil when the file is not a pointer.
function M.gitdir_pointer(dir, file)
  local ok, text = pcall(fs.read, file)
  if not ok or not text then
    return nil
  end
  local target = text:match("^%s*gitdir:%s*(.-)%s*$")
  if not target or target == "" then
    return nil
  end
  if not path.is_absolute(target) then
    target = path.join(dir, target)
  end
  -- `<main>/.git/worktrees/<name>` is per-worktree; its grandparent `.git` is the shared one.
  local parent = path.dirname(target)
  if path.basename(parent) == "worktrees" then
    return path.dirname(parent)
  end
  return target
end

-- The repository basename, with linked worktrees collapsing onto the main repo.
--
-- `--git-common-dir` is what collapses them: it answers with the main repo's `.git` from every
-- linked worktree, so its grandparent is the one directory every worktree of a repo shares.
-- Outside a repository the working directory's own basename is the floor.
function M.project_base(dir)
  local base = dir or M.cwd()
  local common = M.common_dir(base)
  if not common then
    local absolute = M.realpath(base) or base
    return M.sanitize(path.basename(absolute)), absolute
  end

  if not path.is_absolute(common) then
    common = path.join(base, common)
  end
  -- Canonicalise the parent rather than the whole path: `.git` is a file rather than a directory
  -- in a linked worktree, and the shell original resolved the parent with `pwd -P` for the same
  -- reason. `absolute` is the main repository's `.git`, so its parent's name is the repo's.
  local parent = M.realpath(path.dirname(common)) or path.dirname(common)
  local absolute = path.join(parent, path.basename(common))
  return M.sanitize(path.basename(path.dirname(absolute))), absolute
end

-- `fs.canonicalize` where the policy allows it, nil where it does not or the path is absent.
function M.realpath(target)
  local ok, resolved = pcall(fs.canonicalize, target)
  if ok then
    return resolved
  end
  return nil
end

-- The vault root: `$AIRSSTACK_HOME/journal`, defaulting to `~/.airsstack/journal`.
function M.root()
  local home = airsstack.env.get("AIRSSTACK_HOME")
  if not home or home == "" then
    home = path.join(airsstack.env.get("HOME") or "", ".airsstack")
  end
  return path.join(home, "journal")
end

-- Splits a note into its frontmatter table and its body.
--
-- Returns nil plus a reason when the leading fence is unterminated, which is the one malformed
-- shape the index builder has to report rather than guess at. A note with no leading `---` is not
-- malformed — it simply has no frontmatter.
function M.frontmatter(text)
  if text:sub(1, 3) ~= "---" then
    return {}, text
  end
  local lines = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line
  end

  local closing
  for i = 2, #lines do
    if lines[i]:match("^%s*(.-)%s*$") == "---" then
      closing = i
      break
    end
  end
  if not closing then
    return nil, "unterminated frontmatter fence"
  end

  local fields = {}
  local pending
  for i = 2, closing - 1 do
    local line = lines[i]
    if line:match("^%s*$") then
      pending = nil
    else
      local item = line:match("^%s*%-%s+(.*)$")
      if item and pending then
        -- Block-style list continuation, which is what Obsidian's Properties UI emits.
        local list = fields[pending]
        list[#list + 1] = M.unquote(item)
      else
        local key, value = line:match("^([^:]+):%s*(.*)$")
        if not key then
          return nil, "frontmatter line without ':' -> " .. line
        end
        key = key:match("^%s*(.-)%s*$")
        if value == "" then
          -- Either an empty scalar or the header of a block list; the next line decides.
          fields[key] = {}
          pending = key
        else
          fields[key] = M.parse_value(value)
          pending = nil
        end
      end
    end
  end

  local body = {}
  for i = closing + 1, #lines do
    body[#body + 1] = lines[i]
  end
  return fields, table.concat(body, "\n")
end

-- One surrounding pair of single or double quotes removed.
function M.unquote(value)
  local text = value:match("^%s*(.-)%s*$")
  local inner = text:match('^"(.*)"$') or text:match("^'(.*)'$")
  return inner or text
end

-- A frontmatter scalar, or an inline `[a, b, c]` flow list as a table.
function M.parse_value(value)
  local text = value:match("^%s*(.-)%s*$")
  local inner = text:match("^%[(.*)%]$")
  if not inner then
    return M.unquote(text)
  end
  if inner:match("^%s*$") then
    return {}
  end
  local items = {}
  for item in (inner .. ","):gmatch("([^,]*),") do
    items[#items + 1] = M.unquote(item)
  end
  return items
end

-- A frontmatter value as a list of strings, whatever shape it arrived in.
function M.as_list(value)
  if value == nil then
    return {}
  end
  if type(value) == "table" then
    local out = {}
    for _, item in ipairs(value) do
      out[#out + 1] = tostring(item)
    end
    return out
  end
  return { tostring(value) }
end

-- A frontmatter value as one string; a list joins with ", " the way the shell scripts render it.
function M.scalar(value)
  if value == nil then
    return ""
  end
  if type(value) == "table" then
    local parts = {}
    for _, item in ipairs(value) do
      parts[#parts + 1] = tostring(item)
    end
    return table.concat(parts, ", ")
  end
  return tostring(value)
end

-- A table that encodes as a JSON array even when it is empty.
--
-- Lua cannot tell an empty sequence from an empty map, so `airsstack.json` encodes `{}` as an
-- object. Decoding `[]` hands back a table the encoder has already marked as a sequence, and it
-- stays marked as elements are added — which is the only way to emit `"orphans": []` rather than
-- `"orphans": {}` from a script.
function M.array(items)
  local out = airsstack.json.decode("[]")
  for index, item in ipairs(items or {}) do
    out[index] = item
  end
  return out
end

-- Sorts a list of lists, comparing element by element like Python's tuple ordering.
function M.sort_rows(rows)
  table.sort(rows, function(left, right)
    for index = 1, math.max(#left, #right) do
      local a, b = left[index], right[index]
      if a == nil then
        return true
      end
      if b == nil then
        return false
      end
      if a ~= b then
        return a < b
      end
    end
    return false
  end)
  return rows
end

-- The keys of `map`, sorted.
function M.sorted_keys(map)
  local keys = {}
  for key in pairs(map) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

-- Writes `message` to stderr and fails the script, which the CLI turns into exit 1.
--
-- `error` with level 0 so the runtime's own trailer does not repeat a position the message
-- already carries.
function M.die(message)
  airsstack.stdio.error(message .. "\n")
  error(message, 0)
end

-- Creates `directory` and every missing parent, like `mkdir -p`.
function M.mkdir(directory)
  fs.mkdir(directory)
end

-- Whether `target` exists, answering false where the policy refuses the question.
--
-- Only for paths a script may legitimately not be granted; anywhere the grant is part of the
-- contract, let the denial raise.
function M.exists(target)
  local ok, found = pcall(fs.exists, target)
  return ok and found
end

return M
