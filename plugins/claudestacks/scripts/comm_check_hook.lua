-- Communication protocol report conformance hook.
--
-- Rules live in `lib/comm_report.lua`. Prose mirror: `skills/discuss/references/protocol.md`.
-- Runs on the same three events as `handoff_check_hook.lua`, beside it; acts only on a report
-- carrying `protocol:`, so every other agent's report passes through untouched.
--
-- Violations go to STDOUT, never stderr: `hooks/comm-check.sh` captures this script's stdout to
-- decide whether to block and discards its stderr.

local report = require("lib.handoff_report")
local comm = require("lib.comm_report")

local payload = airsstack.hook.payload()
if type(payload) ~= "table" then
  return
end

local file = report.file_from_payload(payload)
if not file then
  return
end

local out = comm.hook_output(payload.hook_event_name, comm.check(file))
if not out then
  return
end
if out.kind == "emit" then
  airsstack.hook.emit(out.value)
else
  airsstack.stdio.write(out.value)
end
