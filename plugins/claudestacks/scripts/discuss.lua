-- /claudestacks:discuss command line.
--
--   airsl run --policy confined --allow-env HOME --allow-env AIRSSTACK_HOME \
--     --allow-read / --allow-write <airsstack-home> \
--     scripts/discuss.lua <command> [argument] --session <id> [--keep <n>] [--archive]
--
-- Commands: start · add <report> · list [--archive] · show <id|sid8/id> · done ·
-- report-path <slug>. Prints results on stdout. On failure prints the reason on stdout (one line
-- per violation for `add`) and exits non-zero; a runtime error raised by airsl or fs prints only
-- the traceback on stderr. The only file that reads the environment; `lib/discuss.lua` takes
-- arguments.

local discuss = require("lib.discuss")
local env = airsstack.env
local path = airsstack.path
local stdio = airsstack.stdio

local function fail(message)
  stdio.write(message .. "\n")
  error(message, 0)
end

local function say(text)
  if text and text ~= "" then
    stdio.write(text .. "\n")
  end
end

local positional, flags = {}, {}
local index = 1
while arg[index] do
  local value = arg[index]
  if value == "--archive" then
    flags.archive = true
  elseif value == "--session" or value == "--keep" then
    flags[value:sub(3)] = arg[index + 1]
    index = index + 1
  else
    positional[#positional + 1] = value
  end
  index = index + 1
end

local command = positional[1]
if not command then
  fail("usage: discuss.lua <start|add|list|show|done|report-path> [argument] --session <id>")
end
local ok_session = pcall(discuss.check_session, flags.session)
if not ok_session then
  fail("invalid or missing --session: " .. tostring(flags.session))
end

local function read_env(name)
  local ok, value = pcall(env.get, name)
  return ok and value ~= "" and value or nil
end
local root = read_env("AIRSSTACK_HOME") or path.join(read_env("HOME") or "", ".airsstack")
local project = discuss.project_dir(root, path.absolute("."))
local session = flags.session
local now = airsstack.time.now()
local dir = path.join(project, session)

if command == "start" then
  local opened, resumed = discuss.start(project, session, discuss.keep(flags.keep), now)
  say((resumed and "resumed" or "started") .. " discussion " .. session:sub(1, 8)
    .. " (" .. #opened.topics .. " topics)")
  say(discuss.list_lines(opened))
elseif command == "add" then
  local file = positional[2] or fail("usage: discuss.lua add <report> --session <id>")
  local current = discuss.load(dir)
  if not current or current.state ~= "open" then
    fail("no open discussion for this session")
  end
  local added, violations = discuss.add(current, path.absolute(file))
  if not added then
    local lines = {}
    for _, violation in ipairs(violations) do
      lines[#lines + 1] = violation.id .. ": " .. violation.line
    end
    fail(table.concat(lines, "\n"))
  end
  discuss.save(dir, current, now)
  for _, topic in ipairs(added) do
    say(string.format("%3d  %s", topic.id, topic.title))
  end
elseif command == "list" and flags.archive then
  say(discuss.archive_lines(project, session))
elseif command == "list" then
  local current = discuss.load(dir)
  if not current then
    fail("no discussion for this session; try: list --archive")
  end
  say(discuss.list_lines(current))
elseif command == "show" then
  local text, err = discuss.show(project, session, positional[2] or "", now)
  say(text or fail(err))
elseif command == "done" then
  local missing, err = discuss.done(project, session, now)
  if not missing then
    fail(err)
  end
  for _, file in ipairs(missing) do
    say("missing: " .. file)
  end
  say("closed discussion " .. session:sub(1, 8))
elseif command == "report-path" then
  local file, err = discuss.report_path(project, session, positional[2])
  say(file or fail(err))
else
  fail("unknown command: " .. command)
end
