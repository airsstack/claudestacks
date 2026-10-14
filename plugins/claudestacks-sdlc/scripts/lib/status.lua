-- The claudestacks-sdlc status board: scans the committed chain root,
-- parses artifact frontmatter, derives each chain's STATE and NEXT, and
-- renders the board.
--
-- Code side of the rules whose prose mirror is `references/artifact-chain.md`
-- (spec §5.1 NEXT derivation, §2.3 frontmatter); the two MUST agree.

local fingerprint = require("lib.fingerprint")

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
-- unparseable, or missing the status field. The file's text is the second
-- result, so a caller that needs the body's fingerprint does not read twice.
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
  return fields, text
end

-- Reads one chain directory into { name, intent, spec, plans, invalid,
-- intent_fp, spec_fp }. The first unparseable artifact marks the whole chain
-- invalid: no state is ever guessed. The two fingerprints are computed only
-- for an `approved` intent, the only chains the sync rules read.
function M.read_chain(dir, name)
  local chain = { name = name, plans = {} }

  local intent_file = path.join(dir, "intent.md")
  if not fs.exists(intent_file) then
    chain.invalid = "intent.md missing"
    return chain
  end
  -- read_artifact's second result is the file's text on success and the
  -- reason on failure.
  local intent, intent_detail = M.read_artifact(intent_file)
  if not intent then
    chain.invalid = "intent.md: " .. intent_detail
    return chain
  end
  chain.intent = intent
  local checked = intent.status == "approved"
  if checked then
    chain.intent_fp = fingerprint.of_text(intent_detail)
  end

  -- Only spec.md governs; spec-superseded-*.md files are history (§2.1).
  local spec_file = path.join(dir, "spec.md")
  if fs.exists(spec_file) then
    local spec, spec_detail = M.read_artifact(spec_file)
    if not spec then
      chain.invalid = "spec.md: " .. spec_detail
      return chain
    end
    chain.spec = spec
    if checked then
      chain.spec_fp = fingerprint.of_text(spec_detail)
    end
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

-- A live plan still has work in it; a settled one (`done`, `superseded`)
-- does not. Rules I4, I5, C3 and C4 read only live plans; a `draft` plan is
-- not checked by them.
local function live(plan)
  return plan.status == "approved" or plan.status == "executing"
end

-- A frontmatter fingerprint value, or nil when the key is absent or empty
-- (an empty `key:` parses as an empty list).
local function fp_value(value)
  if type(value) == "string" then
    return value
  end
  return nil
end

-- The sync findings for a chain whose intent is `approved`, per the sync
-- rules in `references/artifact-chain.md` §10. Returns a table holding
-- either `invalid` (the reason, rules I2-I5 in order) or the conditions:
-- `c1` (spec stale), `c2` (the lowest plan number whose `disproves` still
-- matches), `plans` (plan -> "blocked" for C3 or "stale" for C4), `blocked`
-- and `stale` (whether any plan holds C3 / C4), and `word` — "spec" or
-- "intent", the artifact this chain's plans are written against, or nil when
-- there is no spec.md and no skip flag.
function M.sync(chain)
  local spec, intent = chain.spec, chain.intent
  local out = { plans = {} }

  if spec and spec.status ~= "draft" and spec.status ~= "approved" then
    out.invalid = "spec.md: unknown status " .. tostring(spec.status)
    return out
  end
  if spec and spec.status == "approved" and not fp_value(spec["built-on"]) then
    out.invalid = "spec.md: missing built-on"
    return out
  end

  local word, authority_fp
  if spec then
    word, authority_fp = "spec", chain.spec_fp
  elseif intent.spec == "skipped" then
    word, authority_fp = "intent", chain.intent_fp
  end
  out.word = word

  for _, plan in ipairs(chain.plans) do
    if live(plan) and not word then
      out.invalid = "plans/" .. plan.num .. ": no spec and no skip flag"
      return out
    end
  end
  for _, plan in ipairs(chain.plans) do
    if live(plan) and not fp_value(plan["built-on"]) then
      out.invalid = "plans/" .. plan.num .. ": missing built-on"
      return out
    end
  end

  out.c1 = spec ~= nil and spec.status == "approved"
    and fp_value(spec["built-on"]) ~= chain.intent_fp
  for _, plan in ipairs(chain.plans) do
    if not out.c2 and plan.status ~= "superseded"
      and authority_fp and fp_value(plan.disproves) == authority_fp then
      out.c2 = plan.num
    end
    if live(plan) then
      if word == "spec" and spec.status == "draft" then
        out.plans[plan] = "blocked"
        out.blocked = true
      elseif fp_value(plan["built-on"]) ~= authority_fp then
        out.plans[plan] = "stale"
        out.stale = true
      end
    end
  end
  return out
end

-- STATE and NEXT for one chain, per the NEXT-derivation and sync rules in
-- `references/artifact-chain.md` §9 and §10. States and fingerprints only,
-- no judgment.
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

  -- An unknown plan status is refused before the sync rules read the plans.
  for _, plan in ipairs(chain.plans) do
    if not PLAN_STATUSES[plan.status] then
      return "INVALID (plans/" .. plan.num .. ": unknown status " .. tostring(plan.status) .. ")",
        "fix " .. chain.name
    end
  end

  local sync = M.sync(chain)
  if sync.invalid then
    return "INVALID (" .. sync.invalid .. ")", "fix " .. chain.name
  end

  -- The sync parts lead the cell, and the first standing condition decides
  -- NEXT ahead of the states-only derivation below.
  local parts = {}
  if sync.c1 then
    parts[#parts + 1] = "spec stale (intent changed)"
  end
  if sync.c2 then
    parts[#parts + 1] = sync.word .. " disproven by plan " .. sync.c2
  end
  local sync_next = (sync.c1 and "design")
    or (sync.c2 and (sync.word == "intent" and "intent" or "design"))
    or (sync.blocked and "approve spec")
    or (sync.stale and "plan")
    or nil

  if #chain.plans > 0 then
    -- every_settled: every plan is done or superseded (no draft/approved/
    -- executing left). done_count: how many are actually done. Per spec
    -- §2.4:116 / reference §7.2, the walk-up needs BOTH — a chain that is
    -- all `superseded` with zero `done` has nothing to roll up.
    local every_settled, done_count = true, 0
    local next_exec, next_draft, blocked, any_executing = nil, nil, false, false
    for _, plan in ipairs(chain.plans) do
      local part = "plan " .. plan.num .. " " .. plan.status
      if sync.plans[plan] == "blocked" then
        part = part .. ": blocked (spec not approved)"
      elseif sync.plans[plan] == "stale" then
        part = part .. ": stale (" .. sync.word .. " changed)"
      end
      parts[#parts + 1] = part
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
    if every_settled and done_count > 0 and not sync.c1 and not sync.c2 then
      -- The chain's work is finished and only the walk-up is owed. A
      -- standing C1 or C2 keeps the chain open: the debt outlives the plans.
      return "chain complete" .. tag, "execute walk-up"
    end
    local nxt = sync_next
      or next_exec and ("execute " .. next_exec)
      or (next_draft and ("approve plan " .. next_draft))
      or (blocked and "wait (dependencies pending)")
      -- plan `executing` -> "no further derivation; it is mid-flight"
      -- (reference §9): nothing to fabricate, NEXT stays empty.
      or (any_executing and "")
      -- Reached only when every plan is settled (`done` or `superseded`)
      -- but none is actually `done` — the all-superseded case, which
      -- reference §9 sends to `plan`. Unrecognised statuses are refused
      -- above, so this cannot be a typo falling through. The chain needs a
      -- replacement plan, same as an approved spec with none yet.
      or "plan"
    return table.concat(parts, ", ") .. tag, nxt
  end

  if sync.c1 then
    -- `spec approved` is left out: the stale part already says it.
    return table.concat(parts, ", ") .. tag, sync_next
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
  -- M.sync refused every status but `draft` and `approved`.
  return "spec approved" .. tag, "plan"
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
    -- Only a `done` or `dropped` intent collapses into the tail. A chain
    -- whose plans are complete but whose intent was never flipped is a row,
    -- so a missed walk-up is visible.
    if state == "done" then
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
