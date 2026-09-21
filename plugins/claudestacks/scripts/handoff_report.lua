-- Handoff report conformance checker.
--
-- Rules live in `lib/handoff_report.lua`. Prose mirror:
-- `skills/context-handoff/references/protocol.md`.
--
--   airsl run --policy confined --allow-read / \
--     scripts/handoff_report.lua <path-to-report>
--
-- The read grant must cover the directory the report sits in. `--allow-read .` does not: an
-- exception-tier report is a literal temp path outside the tree, and the denial surfaces as
-- `unreadable`, which is indistinguishable from a malformed report.
--
-- Prints nothing and exits 0 when the report conforms; otherwise prints one line per violation
-- to stdout and exits non-zero. Violations go to STDOUT rather than stderr because the hook
-- wrapper captures them as the reason text it hands back — a traceback on stderr would reach
-- the agent instead of the reason.

local report = require("lib.handoff_report")
local stdio = airsstack.stdio

local file = arg[1]
if not file or file == "" then
  stdio.error("usage: handoff_report.lua <path-to-report>\n")
  error("missing path", 0)
end

local violations = report.check(file)
if #violations == 0 then
  return
end

local lines = {}
for _, violation in ipairs(violations) do
  lines[#lines + 1] = violation.id .. ": " .. violation.line
end
stdio.write(table.concat(lines, "\n") .. "\n")
error("handoff report does not conform", 0)
