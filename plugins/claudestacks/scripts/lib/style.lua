-- The reply rules of the claudestacks communication protocol, and the option that controls
-- re-sending them each turn.
--
-- Split from the hook driver so both decisions can be tested against strings: the driver
-- reads stdin and runs at load time, so it cannot be required.

local M = {}

M.HEADING = "## Reply rules"

-- The `## Reply rules` section of `text`, heading included, trimmed — or nil when the
-- section is absent or empty. Ends at the next `#` or `##` heading; `###` and deeper stay in.
function M.reply_rules(text)
  local kept, inside = {}, false
  for line in (text .. "\n"):gmatch("(.-)\r?\n") do
    if line == M.HEADING then
      inside = true
    elseif inside and (line:match("^#%s") or line:match("^##%s")) then
      break
    elseif inside then
      kept[#kept + 1] = line
    end
  end
  if not inside then
    return nil
  end
  local body = table.concat(kept, "\n"):match("^%s*(.-)%s*$")
  if body == "" then
    return nil
  end
  return M.HEADING .. "\n\n" .. body
end

-- Whether to re-send the rules on every prompt, from the raw `CLAUDE_PLUGIN_OPTION_STYLE_REINJECT`
-- value. Only an explicit `false` or `0` turns it off: an unset option never reaches the
-- environment (spec P3), and the exact text a set boolean arrives as is unverified (spec P4).
function M.reinject_enabled(value)
  if value == nil then
    return true
  end
  local normalized = tostring(value):lower():match("^%s*(.-)%s*$")
  return not (normalized == "false" or normalized == "0")
end

return M
