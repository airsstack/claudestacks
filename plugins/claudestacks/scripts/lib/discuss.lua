-- The per-session topic index behind /claudestacks:discuss.
--
-- Prose authority: `skills/discuss/references/protocol.md` and this chain's spec. Every value a
-- test varies arrives as an argument; `scripts/discuss.lua` alone reads the environment.

local comm = require("lib.comm_report")
local handoff = require("lib.handoff_report")
local fs = airsstack.fs
local hash = airsstack.hash
local json = airsstack.json
local path = airsstack.path
local regex = airsstack.regex

local M = {}

M.DEFAULT_KEEP = 20

-- The archive size from `--keep`. Anything that is not a positive integer — including the
-- literal `${user_config.archive_keep}` an unset option leaves in skill text — is the default.
function M.keep(value)
  local number = tonumber(value)
  if number and number >= 1 and number == math.floor(number) then
    return number
  end
  return M.DEFAULT_KEEP
end

-- The per-repository key, ported from `hooks/lib/enforce.lua:35-174`, whose reference form is
-- the shell block in `skills/snapshot-save/SKILL.md`. A port rather than a `require` because
-- `airsl` resolves `require` only beside the running script. Keep the copies in sync.

-- Every character outside [A-Za-z0-9._-] becomes '-'.
function M.sanitize(text)
  return (regex.replace_all("[^A-Za-z0-9._-]", text or "", "-"))
end

local function realpath(target)
  local ok, resolved = pcall(fs.canonicalize, target)
  return ok and resolved or nil
end

-- The nearest ancestor holding `.git`, and that `.git` — or nil outside a repository.
local function dot_git(cwd)
  local current = realpath(cwd) or cwd
  while true do
    local candidate = path.join(current, ".git")
    local seen, present = pcall(fs.exists, candidate)
    if seen and present then
      return current, candidate
    end
    local parent = path.dirname(current)
    if parent == current or parent == "" then
      return nil, nil
    end
    current = parent
  end
end

-- The main repository's `.git`, without running git.
function M.common_dir(cwd)
  local top, candidate = dot_git(cwd)
  if not top then
    return nil
  end
  local ok, is_file = pcall(fs.is_file, candidate)
  if not ok then
    return nil
  end
  if not is_file then
    return candidate
  end
  local read, text = pcall(fs.read, candidate)
  if not read or not text then
    return nil
  end
  local target = text:match("^%s*gitdir:%s*(.-)%s*$")
  if not target or target == "" then
    return nil
  end
  if not path.is_absolute(target) then
    target = path.join(top, target)
  end
  local parent = path.dirname(target)
  if path.basename(parent) == "worktrees" then
    return path.dirname(parent)
  end
  return target
end

-- `<sanitized base>-<first 8 hex of sha1(absolute)>` — the reference block's last three lines.
function M.key_for(base, absolute)
  return M.sanitize(base) .. "-" .. hash.sha1(absolute):sub(1, 8)
end

-- The key of the repository `cwd` sits in, over its physical common dir; outside a repository,
-- over the physical working directory.
function M.project_key(cwd)
  local common = M.common_dir(cwd)
  local absolute, base
  if common then
    if not path.is_absolute(common) then
      common = path.join(cwd, common)
    end
    local parent = realpath(path.dirname(common)) or path.dirname(common)
    absolute = path.join(parent, path.basename(common))
    base = path.basename(path.dirname(absolute))
  else
    absolute = realpath(cwd)
    if not absolute then
      return nil
    end
    base = path.basename(absolute)
  end
  return M.key_for(base, absolute)
end

-- The storage directory for this project's discussions.
function M.project_dir(root, cwd)
  return path.join(root, "discussions", M.project_key(cwd) or "unknown")
end

-- A session id may name a directory and nothing else.
function M.check_session(session)
  if type(session) ~= "string" or not session:match("^[%w-]+$") then
    error("invalid session id: " .. tostring(session), 0)
  end
  return session
end

-- The index in `dir`, or nil when there is none or it cannot be read.
function M.load(dir)
  local ok, text = pcall(fs.read, path.join(dir, "index.json"))
  if not ok then
    return nil
  end
  local decoded, index = pcall(json.decode, text)
  if not decoded or type(index) ~= "table" then
    return nil
  end
  if type(index.topics) ~= "table" then
    index.topics = {}
  end
  return index
end

-- Writes `index` to `dir`, stamping `touched`.
function M.save(dir, index, now)
  index.touched = now
  fs.mkdir(dir)
  fs.write(path.join(dir, "index.json"), json.encode_pretty(index) .. "\n")
end

-- Opens, resumes or reopens this session's discussion, then prunes the project's others.
-- Returns the index and whether one already existed.
function M.start(project, session, keep, now)
  M.check_session(session)
  local dir = path.join(project, session)
  local index = M.load(dir)
  local resumed = index ~= nil
  if not index then
    index = { state = "open", opened = now, topics = {} }
  end
  index.state, index.closed = "open", nil
  M.save(dir, index, now)
  M.prune(project, session, keep)
  return index, resumed
end

-- The discussions under `project` other than `current`, as `{ name, index }`, newest first.
function M.others(project, current)
  local found = {}
  local ok, names = pcall(fs.list, project)
  if not ok then
    return found
  end
  for _, name in ipairs(names) do
    local dir = path.join(project, name)
    local read, is_dir = pcall(fs.is_dir, dir)
    if name ~= current and read and is_dir then
      found[#found + 1] = { name = name, index = M.load(dir) or { touched = 0, topics = {} } }
    end
  end
  table.sort(found, function(a, b)
    return (a.index.touched or 0) > (b.index.touched or 0)
  end)
  return found
end

-- Removes every discussion except `current` and the newest `keep` others. Open ones count:
-- a session that ended without `done` still ages out. Returns the names removed.
function M.prune(project, current, keep)
  local removed = {}
  for position, other in ipairs(M.others(project, current)) do
    if position > keep and pcall(fs.remove_dir, path.join(project, other.name)) then
      removed[#removed + 1] = other.name
    end
  end
  return removed
end

-- Validates `file` with both validators and appends its topics to `index` (the caller saves).
-- A report is identified by its physical path. Returns the topics added, or nil plus the
-- violations.
function M.add(index, file)
  file = realpath(file) or file
  for _, topic in ipairs(index.topics) do
    if topic.report == file then
      return nil, { { id = "already-added", line = "already in this discussion: " .. file } }
    end
  end
  local violations = handoff.check(file)
  for _, violation in ipairs(comm.check(file, { require_protocol = true })) do
    violations[#violations + 1] = violation
  end
  if #violations > 0 then
    return nil, violations
  end
  local topics = comm.topics(fs.read_lines(file), 1) or {}
  local added = {}
  for _, topic in ipairs(topics) do
    local entry = {
      id = #index.topics + 1,
      title = topic.title,
      report = file,
      heading = "## " .. topic.n .. ". " .. topic.title,
      read = false,
    }
    index.topics[#index.topics + 1] = entry
    added[#added + 1] = entry
  end
  return added
end

-- This discussion's topics, one per line: id, `*` once read, title.
function M.list_lines(index)
  local lines = {}
  for _, topic in ipairs(index.topics) do
    lines[#lines + 1] = string.format("%3d  %s %s", topic.id, topic.read and "*" or " ", topic.title)
  end
  return table.concat(lines, "\n")
end

-- Every other discussion's topics, newest discussion first: `<sid8>/<id>  <state>  <title>`.
function M.archive_lines(project, current)
  local lines = {}
  for _, other in ipairs(M.others(project, current)) do
    for _, topic in ipairs(other.index.topics or {}) do
      lines[#lines + 1] = string.format("%s/%d  %s  %s", other.name:sub(1, 8), topic.id,
        other.index.state or "unknown", topic.title)
    end
  end
  return table.concat(lines, "\n")
end

-- The `heading` section of `file`'s <detail>: from that heading up to the next topic heading
-- (`## N. `) or `</detail>`, trailing blank lines dropped. Any other `## ` line inside a topic
-- stays in it. Lines are compared without trailing whitespace, as `lib.comm_report` reads them,
-- and kept as written. Nil plus a reason when it cannot be read.
function M.section(file, heading)
  local ok, lines = pcall(fs.read_lines, file)
  if not ok then
    return nil, "report gone: " .. file
  end
  local kept
  local in_detail = false
  for _, raw in ipairs(lines) do
    local line = raw:gsub("%s+$", "")
    if kept and (line:match("^## %d+%. ") or line == "</detail>") then
      break
    elseif kept then
      kept[#kept + 1] = raw
    elseif line == "<detail>" then
      in_detail = true
    elseif in_detail and line == heading then
      kept = { line }
    end
  end
  if not kept then
    return nil, "section not found: " .. heading .. " in " .. file
  end
  while #kept > 1 and not kept[#kept]:match("%S") do
    kept[#kept] = nil
  end
  return table.concat(kept, "\n")
end

-- The discussion directory and topic that `ref` names: `<id>` in this session, or
-- `<sid8>/<id>` in another. Nil plus a reason otherwise.
function M.resolve(project, session, ref)
  local prefix, number = tostring(ref):match("^([%w-]+)/(%d+)$")
  local dir
  if prefix then
    for _, other in ipairs(M.others(project, session)) do
      if other.name:sub(1, #prefix) == prefix then
        dir = path.join(project, other.name)
        break
      end
    end
  else
    number = tostring(ref):match("^(%d+)$")
    dir = path.join(project, session)
  end
  local index = dir and number and M.load(dir)
  local topic = index and index.topics[tonumber(number)]
  if not topic then
    return nil, nil, "unknown topic: " .. tostring(ref)
  end
  return dir, index, topic
end

-- The section `ref` names, marked read. Nil plus a reason otherwise.
function M.show(project, session, ref, now)
  local dir, index, topic = M.resolve(project, session, ref)
  if not dir then
    return nil, topic
  end
  local text, err = M.section(topic.report, topic.heading)
  if not text then
    return nil, err
  end
  topic.read = true
  M.save(dir, index, now)
  return text
end

-- One past the highest two-digit `NN-` prefix in `dir`.
function M.next_number(dir)
  local highest = 0
  local ok, names = pcall(fs.list, dir)
  for _, name in ipairs(ok and names or {}) do
    local number = tonumber(name:match("^(%d%d)%-") or "")
    if number and number > highest then
      highest = number
    end
  end
  return highest + 1
end

-- Copies every cited report into `<dir>/reports/` (reports already there stay), repoints the
-- index at the copies, and closes the discussion. Returns the report paths that had vanished,
-- or nil plus a reason when there is no open discussion.
function M.done(project, session, now)
  local dir = path.join(project, M.check_session(session))
  local index = M.load(dir)
  if not index or index.state ~= "open" then
    return nil, "no open discussion for this session"
  end
  local reports = path.join(dir, "reports")
  fs.mkdir(reports)
  reports = realpath(reports) or reports
  local copied, missing = {}, {}
  for _, topic in ipairs(index.topics) do
    local source = topic.report
    if path.dirname(source) ~= reports and copied[source] == nil then
      local ok, text = pcall(fs.read, source)
      if ok then
        local target = path.join(reports, string.format("%02d-%s", M.next_number(reports),
          path.basename(source)))
        fs.write(target, text)
        copied[source] = target
      else
        copied[source] = false
        missing[#missing + 1] = source
      end
    end
    if copied[source] then
      topic.report = copied[source]
    end
  end
  index.state, index.closed = "closed", now
  M.save(dir, index, now)
  return missing
end

-- The next free `<dir>/reports/NN-main-<slug>.md` for a main-thread report, creating
-- `reports/`. Nil plus a reason when the slug is bad or no discussion is open.
function M.report_path(project, session, slug)
  if type(slug) ~= "string" or not slug:match("^[a-z0-9-]+$") then
    return nil, "slug must match [a-z0-9-]+: " .. tostring(slug)
  end
  local dir = path.join(project, M.check_session(session))
  local index = M.load(dir)
  if not index or index.state ~= "open" then
    return nil, "no open discussion for this session"
  end
  local reports = path.join(dir, "reports")
  fs.mkdir(reports)
  return path.join(reports, string.format("%02d-main-%s.md", M.next_number(reports), slug))
end

return M
