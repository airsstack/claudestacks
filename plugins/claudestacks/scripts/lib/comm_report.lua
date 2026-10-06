-- The communication protocol's additions to a Context Handoff report.
--
-- Prose authority: `skills/discuss/references/protocol.md`. The base schema (frontmatter,
-- one <summary>, at most one <detail>) is `lib/handoff_report.lua`'s and is not re-checked
-- here; this module only checks what the communication protocol adds.

local report = require("lib.handoff_report")
local fs = airsstack.fs
local regex = airsstack.regex

local M = {}

M.VERSION = "discuss/1"
M.MAX_SUMMARY_LINES = 6

local TOPIC = regex.compile([[^([0-9]+)\. (\S.*)$]])

-- The lines between the first `<name>` and its `</name>`, each tag alone on its line — or nil
-- when the block never opens. An unclosed block returns what it holds to the end of the file.
-- The base validator reports a missing close for <summary> and <detail>; nothing reports it
-- for <topics>.
function M.block(lines, name, from)
  local inner
  for index = from or 1, #lines do
    local line = lines[index]
    if not inner and line == "<" .. name .. ">" then
      inner = {}
    elseif inner and line == "</" .. name .. ">" then
      return inner
    elseif inner then
      inner[#inner + 1] = line
    end
  end
  return inner
end

-- The topics in a report's <topics> block as `{ n, title }`, plus the non-blank lines that are
-- not `N. <title>`. Nil when there is no <topics> block.
function M.topics(lines, from)
  local inner = M.block(lines, "topics", from)
  if not inner then
    return nil
  end
  local found, malformed = {}, {}
  for _, line in ipairs(inner) do
    if line:match("%S") then
      local parts = TOPIC.captures(line)
      if parts then
        found[#found + 1] = { n = tonumber(parts[1]), title = parts[2]:match("^(.-)%s*$") }
      else
        malformed[#malformed + 1] = line
      end
    end
  end
  return found, malformed
end

-- Every way `lines` breaks the communication protocol's additions, as `{ id, line }`.
--
-- A report with no `protocol:` key is not a communication-protocol report and returns nothing,
-- unless `opts.require_protocol` is set — `discuss.lua add` sets it, the hook never does.
function M.check_lines(lines, opts)
  opts = opts or {}
  local violations = {}
  local function fail(id, line)
    violations[#violations + 1] = { id = id, line = line }
  end

  local keys, body_from = report.frontmatter(lines)
  local declared = keys and keys.protocol
  if not declared or declared == "" then
    if opts.require_protocol then
      fail("protocol-missing", "no `protocol:` key in the frontmatter")
    end
    return violations
  end
  if declared ~= M.VERSION then
    fail("protocol-unknown", "`protocol: " .. declared .. "` is not `" .. M.VERSION .. "`")
    return violations
  end

  local summary = M.block(lines, "summary", body_from)
  if summary then
    local count = 0
    for _, line in ipairs(summary) do
      if line:match("%S") then
        count = count + 1
      end
    end
    if count > M.MAX_SUMMARY_LINES then
      fail("summary-too-long", "<summary> has " .. count .. " lines; at most "
        .. M.MAX_SUMMARY_LINES)
    end
  end

  local detail = M.block(lines, "detail", body_from)
  local topics, malformed = M.topics(lines, body_from)
  if detail and not topics then
    fail("topics-missing", "<detail> is present but there is no <topics> block")
  end
  if topics and not detail then
    fail("topics-without-detail", "<topics> is present but there is no <detail> block")
  end
  if not topics then
    return violations
  end

  for _, line in ipairs(malformed) do
    fail("topics-malformed", "not `N. <title>`: " .. line)
  end
  for index, topic in ipairs(topics) do
    if topic.n ~= index then
      fail("topics-numbering", "topic " .. index .. " is numbered " .. topic.n)
      break
    end
  end
  if detail then
    local present = {}
    for _, line in ipairs(detail) do
      present[line:match("^(.-)%s*$")] = true
    end
    for _, topic in ipairs(topics) do
      local heading = "## " .. topic.n .. ". " .. topic.title
      if not present[heading] then
        fail("topic-heading-missing", "no `" .. heading .. "` line in <detail>")
      end
    end
  end
  return violations
end

-- `check_lines` over a file. An unreadable file returns nothing: the base validator owns
-- that report, and both run on the same file.
function M.check(file, opts)
  local ok, lines = pcall(fs.read_lines, file)
  if not ok then
    return {}
  end
  return M.check_lines(lines, opts)
end

-- What the hook driver does about `violations` on `event`: nil for nothing, `{ kind = "emit" }`
-- for PostToolUse (the file is written; attach the reason so the agent rewrites it), or
-- `{ kind = "stdout" }` for the gate events, which the launcher turns into exit 2.
function M.hook_output(event, violations)
  if #violations == 0 then
    return nil
  end
  local found = {}
  for _, violation in ipairs(violations) do
    found[#found + 1] = violation.id .. ": " .. violation.line
  end
  local reason = "communication protocol report does not conform:\n" .. table.concat(found, "\n")
  if event == "PostToolUse" then
    return { kind = "emit", value = { decision = "block", reason = reason } }
  end
  return { kind = "stdout", value = reason .. "\n" }
end

return M
