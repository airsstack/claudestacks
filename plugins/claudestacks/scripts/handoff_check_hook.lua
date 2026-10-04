-- Handoff report conformance hook.
--
-- Rules live in `lib/handoff_report.lua`. Prose mirror:
-- `skills/context-handoff/references/protocol.md`.
--
-- Lives in `scripts/` rather than `hooks/` because airsl resolves `require` relative to the
-- script's own directory, and the validator is `scripts/lib/handoff_report.lua`. The launcher
-- in `hooks/handoff-check.sh` reaches across.
--
-- Three events arrive here, and the behaviour differs because only two of them can stop
-- anything:
--
--   PostToolUse(Write)           the file is already written; emit violations beside the tool
--                                result so the agent can rewrite. Cannot block.
--   PreToolUse(SubagentHandback) the report is about to be delivered; print violations to
--                                stdout so the launcher exits 2 and blocks the call.
--   SubagentStop                 the same gate where the hand-back tool is not in use.
--
-- Violations go to STDOUT, never stderr: `hooks/handoff-check.sh` captures this script's stdout
-- into `$VIOLATIONS` to decide whether to block, and sends this script's stderr to `/dev/null`
-- (`hooks/handoff-check.sh:34`) — so anything written there reaches nobody, agent included.

local report = require("lib.handoff_report")
local stdio = airsstack.stdio

local function violations_of(file)
  local lines = {}
  for _, violation in ipairs(report.check(file)) do
    lines[#lines + 1] = violation.id .. ": " .. violation.line
  end
  return lines
end

local payload = airsstack.hook.payload()
if type(payload) ~= "table" then
  return
end

-- `report.file_from_payload` is the one place that decides which file, if any, this payload
-- points at: it reads the right field for the event, applies the handoff-root test
-- (`report.under_handoff_root`) to reject a trailing citation, a documentation URL, or an
-- ordinary project file that merely sits in the report text, and resolves a relative path
-- against `payload.cwd`. No qualifying path is not a violation — an agent legitimately without
-- one (the standalone case the protocol's error handling allows) must never be held, and an
-- agent that owed a path and omitted it has already broken the return contract where the
-- orchestrator can see it.
local file = report.file_from_payload(payload)
if not file then
  return
end

local found = violations_of(file)
if #found == 0 then
  return
end

local reason = "handoff report does not conform to the protocol:\n" .. table.concat(found, "\n")

if payload.hook_event_name == "PostToolUse" then
  airsstack.hook.emit({ decision = "block", reason = reason })
else
  stdio.write(reason .. "\n")
end
