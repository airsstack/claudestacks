-- SessionStart hook for claudestacks-sdlc: prints the board rows that need
-- attention, which Claude Code adds to the session's context.
--
--   airsl run --fail-open --policy confined --allow-read / scripts/attention.lua
--
-- The chain root is taken from the hook payload's `cwd` — the session's
-- directory, which in a worktree is the worktree root — and from the process
-- directory when no payload arrives.

local status = require("lib.status")
local path = airsstack.path

local ok, payload = pcall(airsstack.hook.payload)
local cwd = ok and type(payload) == "table"
  and type(payload.cwd) == "string" and payload.cwd ~= "" and payload.cwd
  or path.absolute(".")

local text = status.attention(path.join(cwd, status.ROOT))
if text ~= "" then
  airsstack.stdio.write(text .. "\n")
end
