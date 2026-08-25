-- The claudestacks-sdlc status board: scans the committed chain root,
-- parses artifact frontmatter, derives each chain's STATE and NEXT, and
-- renders the board.
--
-- Code side of the rules whose prose mirror is `references/artifact-chain.md`
-- (spec §5.1 NEXT derivation, §2.3 frontmatter); the two MUST agree.

local fs = airsstack.fs
local path = airsstack.path

local M = {}

-- Chain root, relative to the consuming repository's root.
M.ROOT = ".claudestacks/sdlc"

-- Top-level entries that are not chains.
local SKIP = { prds = true, rfcs = true }

-- Parses the YAML subset the skills write: `key: value` scalars (inline
-- `# comments` stripped) and block lists (`key:` followed by `- item`
-- lines). Returns the field table, or nil and a reason.
function M.parse_frontmatter(text)
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\r?\n") do
    lines[#lines + 1] = line
  end
  if lines[1] ~= "---" then
    return nil, "missing frontmatter"
  end
  local fields, current = {}, nil
  for i = 2, #lines do
    local line = lines[i]
    if line == "---" then
      return fields
    end
    local item = line:match("^%s*%-%s+(.-)%s*$")
    if item and current then
      fields[current][#fields[current] + 1] = item
    else
      local key, value = line:match("^([%w][%w%-]*):%s*(.-)%s*$")
      if key then
        value = value:gsub("%s*#.*$", "")
        if value == "" then
          fields[key] = {}
          current = key
        else
          fields[key] = value
          current = nil
        end
      end
    end
  end
  return nil, "unterminated frontmatter"
end

-- Reads one artifact's frontmatter; nil and a reason when unreadable,
-- unparseable, or missing the status field.
function M.read_artifact(file)
  local ok, text = pcall(fs.read, file)
  if not ok then
    return nil, "unreadable"
  end
  local fields, reason = M.parse_frontmatter(text)
  if not fields then
    return nil, reason
  end
  if not fields.status then
    return nil, "missing status"
  end
  return fields
end

-- Reads one chain directory into { name, intent, spec, plans, invalid }.
-- The first unparseable artifact marks the whole chain invalid: no state is
-- ever guessed.
function M.read_chain(dir, name)
  local chain = { name = name, plans = {} }

  local intent_file = path.join(dir, "intent.md")
  if not fs.exists(intent_file) then
    chain.invalid = "intent.md missing"
    return chain
  end
  local intent, reason = M.read_artifact(intent_file)
  if not intent then
    chain.invalid = "intent.md: " .. reason
    return chain
  end
  chain.intent = intent

  -- Only spec.md governs; spec-superseded-*.md files are history (§2.1).
  local spec_file = path.join(dir, "spec.md")
  if fs.exists(spec_file) then
    local spec, sreason = M.read_artifact(spec_file)
    if not spec then
      chain.invalid = "spec.md: " .. sreason
      return chain
    end
    chain.spec = spec
  end

  local plans_dir = path.join(dir, "plans")
  if fs.exists(plans_dir) and fs.is_dir(plans_dir) then
    for _, pname in ipairs(fs.list(plans_dir)) do
      local num = pname:match("^(%d%d)%-.+%.md$")
      if num then
        local plan, preason = M.read_artifact(path.join(plans_dir, pname))
        if not plan then
          chain.invalid = "plans/" .. pname .. ": " .. preason
          return chain
        end
        plan.num = num
        chain.plans[#chain.plans + 1] = plan
      end
    end
  end

  return chain
end

-- All chains under the root, in fs.list order (lexicographic, so the
-- YYYY-MM-DD prefix makes it chronological).
function M.scan(rootdir)
  local chains = {}
  if not (fs.exists(rootdir) and fs.is_dir(rootdir)) then
    return chains
  end
  for _, name in ipairs(fs.list(rootdir)) do
    local dir = path.join(rootdir, name)
    if fs.is_dir(dir) and not SKIP[name] then
      chains[#chains + 1] = M.read_chain(dir, name)
    end
  end
  return chains
end

-- Legal plan states (reference §7.1); anything else is refused, not guessed.
local PLAN_STATUSES = {
  draft = true, approved = true, executing = true, done = true, superseded = true,
}

-- True when the plan numbered `num` in `plans` is done.
local function plan_done(plans, num)
  for _, plan in ipairs(plans) do
    if plan.num == num then
      return plan.status == "done"
    end
  end
  return false
end

-- Normalises one dependency token (e.g. "1", "01", "  02 ") to the two-digit
-- form plan filenames use. Non-numeric tokens pass through unchanged so a
-- malformed entry still fails plan_done's lookup rather than vanishing.
local function normalize_dep(token)
  local digits = tostring(token):match("^%s*(%d+)%s*$")
  if digits then
    return string.format("%02d", tonumber(digits))
  end
  return tostring(token)
end

-- Normalises depends-on (absent, block list, or inline "[01, 02]" / "[1]")
-- to a list of two-digit strings, then checks every named plan is done.
-- `%d+` (not `%d%d`) so a single-digit token like "[1]" is not silently
-- dropped — that dropped the whole dependency list and let the plan report
-- executable while its dependency was still undone.
local function deps_met(chain, plan)
  local deps = plan["depends-on"]
  local list = {}
  if type(deps) == "table" then
    for _, item in ipairs(deps) do
      list[#list + 1] = normalize_dep(item)
    end
  elseif type(deps) == "string" then
    for num in deps:gmatch("%d+") do
      list[#list + 1] = normalize_dep(num)
    end
  end
  for _, dep in ipairs(list) do
    if not plan_done(chain.plans, dep) then
      return false
    end
  end
  return true
end

-- STATE and NEXT for one chain, per the NEXT-derivation rules in
-- `references/artifact-chain.md` (spec §5.1). States only, no judgment.
function M.derive(chain)
  if chain.invalid then
    return "INVALID (" .. chain.invalid .. ")", "fix " .. chain.name
  end

  local intent = chain.intent
  local tag = intent.source == "triage" and " (triage)" or ""

  if intent.status == "dropped" or intent.status == "done" then
    return intent.status, ""
  end
  if intent.status == "draft" then
    return "intent draft" .. tag,
      intent.source == "triage" and "review evidence" or "approve or drop"
  end
  if intent.status ~= "approved" then
    return "INVALID (intent.md: unknown status " .. tostring(intent.status) .. ")",
      "fix " .. chain.name
  end

  if #chain.plans > 0 then
    local parts = {}
    -- every_settled: every plan is done or superseded (no draft/approved/
    -- executing left). done_count: how many are actually done. Per spec
    -- §2.4:116 / reference §7.2, the walk-up needs BOTH — a chain that is
    -- all `superseded` with zero `done` has nothing to roll up.
    local every_settled, done_count = true, 0
    local next_exec, next_draft, blocked, any_executing = nil, nil, false, false
    for _, plan in ipairs(chain.plans) do
      if not PLAN_STATUSES[plan.status] then
        return "INVALID (plans/" .. plan.num .. ": unknown status " .. tostring(plan.status) .. ")",
          "fix " .. chain.name
      end
      parts[#parts + 1] = "plan " .. plan.num .. " " .. plan.status
      if plan.status == "done" then
        done_count = done_count + 1
      elseif plan.status ~= "superseded" then
        every_settled = false
      end
      if plan.status == "executing" then
        any_executing = true
      end
      if not next_exec and plan.status == "approved" then
        if deps_met(chain, plan) then
          next_exec = plan.num
        else
          blocked = true
        end
      end
      if not next_draft and plan.status == "draft" then
        next_draft = plan.num
      end
    end
    if every_settled and done_count > 0 then
      -- Reference §9:188 collapses this into the DONE/DROPPED tail (count
      -- only); M.render does that collapse by matching this exact state.
      return "chain complete" .. tag, "execute walk-up"
    end
    local nxt = next_exec and ("execute " .. next_exec)
      or (next_draft and ("approve plan " .. next_draft))
      or (blocked and "wait (dependencies pending)")
      -- plan `executing` -> "no further derivation; it is mid-flight"
      -- (reference §9:183): nothing to fabricate, NEXT stays empty.
      or (any_executing and "")
      -- Reached only when every plan is settled (`done` or `superseded`)
      -- but none is actually `done` — the all-superseded case.
      -- Unrecognised statuses are refused above, so this cannot be a typo
      -- falling through. Reference §9:187-188 names this case and requires
      -- the ≥1-`done` guard above before it collapses. Minimal defensible
      -- action: the chain needs a replacement plan, same as an approved
      -- spec with none yet.
      or "plan"
    return table.concat(parts, ", ") .. tag, nxt
  end

  if intent.spec == "skipped" then
    return "intent approved (spec skipped)" .. tag, "plan"
  end
  if not chain.spec then
    return "intent approved" .. tag, "design"
  end
  if chain.spec.status == "draft" then
    return "spec draft" .. tag, "approve spec"
  end
  if chain.spec.status == "approved" then
    return "spec approved" .. tag, "plan"
  end
  return "INVALID (spec.md: unknown status " .. tostring(chain.spec.status) .. ")",
    "fix " .. chain.name
end

-- The union of the intent's provenance lists, in prd-then-rfc order.
function M.inputs(chain)
  local out = {}
  for _, key in ipairs({ "derived-from-prd", "derived-from-rfc" }) do
    local value = chain.intent and chain.intent[key]
    if type(value) == "string" then
      out[#out + 1] = value
    elseif type(value) == "table" then
      for _, item in ipairs(value) do
        out[#out + 1] = item
      end
    end
  end
  return out
end

-- Space-pads to `width` (byte width; column text is ASCII).
local function pad(text, width)
  if #text >= width then
    return text .. "  "
  end
  return text .. string.rep(" ", width - #text)
end

-- The full board for one chain root.
function M.render(rootdir)
  local chains = M.scan(rootdir)
  if #chains == 0 then
    return "No chains under " .. rootdir .. ". Start one with the intent skill."
  end
  local lines = { pad("CHAIN", 34) .. pad("STATE", 30) .. "NEXT" }
  local done_count, dropped_count = 0, 0
  for _, chain in ipairs(chains) do
    local state, nxt = M.derive(chain)
    -- "chain complete" (with an optional trailing "(triage)" tag) is the
    -- every-plan-done-or-superseded-with->=1-done case; reference §9:188
    -- collapses it into the tail same as a dropped/done intent.
    if state == "done" or state:match("^chain complete") then
      done_count = done_count + 1
    elseif state == "dropped" then
      dropped_count = dropped_count + 1
    else
      lines[#lines + 1] = pad(chain.name, 34) .. pad(state, 30) .. nxt
      local ins = M.inputs(chain)
      if #ins > 0 then
        lines[#lines + 1] = "  ⤷ inputs: " .. table.concat(ins, " · ")
      end
    end
  end
  if done_count + dropped_count > 0 then
    lines[#lines + 1] = string.format(
      "DONE/DROPPED: %d done, %d dropped (not listed)", done_count, dropped_count)
  end
  return table.concat(lines, "\n")
end

return M
