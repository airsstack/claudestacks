-- claudestacks reply rules — SessionStart and UserPromptSubmit hook.
--
-- Prints the `## Reply rules` section of the communication protocol as context. SessionStart
-- always prints; a run given `--turn` (the UserPromptSubmit entry) prints unless the
-- `style_reinject` option is off. Never blocks: run it with --fail-open.
--
--   airsl run --fail-open --policy confined \
--     --allow-env CLAUDE_PLUGIN_OPTION_STYLE_REINJECT --allow-read <plugin-root> \
--     scripts/style.lua <protocol.md> [--turn]

local style = require("lib.style")

local protocol = arg[1]
local turn = arg[2] == "--turn"
if type(protocol) ~= "string" or protocol == "" then
  return
end

if turn then
  local read, value = pcall(airsstack.env.get, "CLAUDE_PLUGIN_OPTION_STYLE_REINJECT")
  if not style.reinject_enabled(read and value or nil) then
    return
  end
end

local ok, text = pcall(airsstack.fs.read, protocol)
if not ok or type(text) ~= "string" then
  return
end
local rules = style.reply_rules(text)
if not rules then
  return
end

local got, payload = pcall(airsstack.hook.payload)
local event = got and type(payload) == "table" and payload.hook_event_name
if type(event) ~= "string" then
  event = turn and "UserPromptSubmit" or "SessionStart"
end
airsstack.hook.context(event, rules)
