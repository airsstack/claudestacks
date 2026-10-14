-- Body fingerprints for claudestacks-sdlc artifacts: the first 12 hex
-- characters of the SHA-256 of an artifact's body.
--
-- Code side of the definition whose prose mirror is the "Fingerprints"
-- section of `references/artifact-chain.md`, and whose shell mirror is
-- `scripts/fingerprint.sh`; the three MUST agree.

local fs = airsstack.fs
local hash = airsstack.hash

local M = {}

-- Hex characters kept from the digest.
M.LENGTH = 12

-- The body of an artifact: every line after the line that closes the
-- frontmatter, each stripped of one trailing carriage return and terminated
-- by exactly one "\n". Returns the body, or nil and a reason.
function M.body(text)
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\r?\n") do
    lines[#lines + 1] = line
  end
  -- `text .. "\n"` yields one spurious empty last line when the text
  -- already ends with a newline.
  if text:sub(-1) == "\n" then
    lines[#lines] = nil
  end
  if lines[1] ~= "---" then
    return nil, "missing frontmatter"
  end
  local close
  for i = 2, #lines do
    if lines[i] == "---" then
      close = i
      break
    end
  end
  if not close then
    return nil, "unterminated frontmatter"
  end
  local body = {}
  for i = close + 1, #lines do
    body[#body + 1] = lines[i] .. "\n"
  end
  return table.concat(body)
end

-- The fingerprint of an artifact's text, or nil and a reason.
function M.of_text(text)
  local body, reason = M.body(text)
  if not body then
    return nil, reason
  end
  return hash.sha256(body):sub(1, M.LENGTH)
end

-- The fingerprint of an artifact file, or nil and a reason.
function M.of_file(file)
  local ok, text = pcall(fs.read, file)
  if not ok then
    return nil, "unreadable"
  end
  return M.of_text(text)
end

return M
