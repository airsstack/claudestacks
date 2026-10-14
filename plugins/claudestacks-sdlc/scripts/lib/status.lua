-- The claudestacks-sdlc status board: scans the committed chain root,
-- parses artifact frontmatter, derives each chain's STATE and NEXT, and
-- renders the board, grouped under roadmaps and milestones when `roadmaps/`
-- holds at least one roadmap directory, and lists the rows that need
-- attention as the session-start text.
--
-- Code side of the rules whose prose mirror is `references/artifact-chain.md`
-- (spec §5.1 NEXT derivation, §2.3 frontmatter); the two MUST agree.

local fingerprint = require("lib.fingerprint")
local roadmap = require("lib.roadmap")

local fs = airsstack.fs
local path = airsstack.path

local M = {}

-- Chain root, relative to the consuming repository's root.
M.ROOT = ".claudestacks/sdlc"

-- Top-level entries that are not chains.
local SKIP = { prds = true, rfcs = true, [roadmap.DIR] = true }

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

-- The membership problem of an open chain's intent, or nil: its `milestone`
-- value resolves to no milestone, or to two (reference §11). A chain with
-- no `milestone` key is a simple chain and has no problem.
local function membership_problem(intent, roadmaps)
  local value = intent.milestone
  if value == nil then
    return nil
  end
  local milestone, why = roadmap.resolve(roadmaps, value)
  if milestone then
    return nil
  end
  return "intent.md: " .. why .. " milestone " .. (type(value) == "string" and value or "")
end

-- STATE and NEXT for one chain, per the NEXT-derivation and sync rules in
-- `references/artifact-chain.md` §9 and §10, and the membership rules of §11.
-- States and fingerprints only, no judgment. `roadmaps` is lib/roadmap's
-- scan; absent means none exist.
function M.derive(chain, roadmaps)
  if chain.invalid then
    return "INVALID (" .. chain.invalid .. ")", "fix " .. chain.name
  end
  roadmaps = roadmaps or {}

  local intent = chain.intent
  local tag = intent.source == "triage" and " (triage)" or ""

  if intent.status == "dropped" or intent.status == "done" then
    return intent.status, ""
  end
  if intent.status == "draft" then
    local problem = membership_problem(intent, roadmaps)
    if problem then
      return "INVALID (" .. problem .. ")", "fix " .. chain.name
    end
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

  -- A broken membership ranks after the results above and before I2-I5.
  local problem = membership_problem(intent, roadmaps)
  if problem then
    return "INVALID (" .. problem .. ")", "fix " .. chain.name
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

-- The board for one chain root, as data: { rows, done, dropped, open,
-- empty }. `done` and `dropped` are the tail counts, `open` the number of
-- chain rows, and `empty` is true when the root holds neither a chain nor a
-- roadmap. Each row is { kind, label, state, next, indent, notes }: `kind`
-- is "chain", "milestone", "roadmap" or "heading" (a heading has a label
-- only), and `notes` are its `⤷` annotation lines in print order.
--
-- With no roadmap directory the rows are the open chains, flat. With one,
-- they are grouped: each roadmap, its milestones, each milestone's open
-- member chains indented, then `UNASSIGNED` over every other open chain.
function M.board(rootdir)
  local chains = M.scan(rootdir)
  local roadmaps = roadmap.scan(rootdir, M.read_artifact)
  local board = {
    rows = {}, done = 0, dropped = 0, open = 0,
    empty = #chains == 0 and #roadmaps == 0,
  }

  local unassigned, by_milestone = {}, {}
  for _, chain in ipairs(chains) do
    local state, nxt = M.derive(chain, roadmaps)
    local intent = chain.intent
    local milestone = intent and intent.milestone ~= nil
      and roadmap.resolve(roadmaps, intent.milestone) or nil
    -- Only a `done` or `dropped` intent collapses into the tail. A chain
    -- whose plans are complete but whose intent was never flipped is a row,
    -- so a missed walk-up is visible.
    local open = state ~= "done" and state ~= "dropped"
    if state == "done" then
      board.done = board.done + 1
    elseif state == "dropped" then
      board.dropped = board.dropped + 1
    end
    if milestone then
      milestone.members[#milestone.members + 1] = { status = intent.status, open = open }
    end
    if open then
      board.open = board.open + 1
      local row = { kind = "chain", label = chain.name, state = state, next = nxt, indent = 0, notes = {} }
      local ins = M.inputs(chain)
      if #ins > 0 then
        row.notes[#row.notes + 1] = "⤷ inputs: " .. table.concat(ins, " · ")
      end
      if milestone and milestone.status == "dropped"
        and (intent.status == "draft" or intent.status == "approved") then
        row.notes[#row.notes + 1] = "⤷ milestone " .. milestone.ref
          .. " is dropped — release this chain"
      end
      if milestone then
        by_milestone[milestone] = by_milestone[milestone] or {}
        table.insert(by_milestone[milestone], row)
      else
        unassigned[#unassigned + 1] = row
      end
    end
  end

  if #roadmaps == 0 then
    board.rows = unassigned
    return board
  end

  local rows = board.rows
  for _, item in ipairs(roadmaps) do
    local state, nxt = roadmap.roadmap_row(item)
    rows[#rows + 1] = {
      kind = "roadmap", label = "ROADMAP " .. item.name,
      state = state, next = nxt, indent = 0, notes = {},
    }
    for _, milestone in ipairs(item.milestones) do
      if roadmap.prints(milestone) then
        local mstate, mnext = roadmap.milestone_row(milestone)
        local row = {
          kind = "milestone", label = "MILESTONE " .. item.name .. "/" .. milestone.stem,
          state = mstate, next = mnext, indent = 0, notes = {},
        }
        if item.status == "dropped"
          and (milestone.status == "draft" or milestone.status == "approved") then
          row.notes[1] = "⤷ roadmap " .. item.name .. " is dropped — drop this milestone"
        end
        rows[#rows + 1] = row
        for _, member in ipairs(by_milestone[milestone] or {}) do
          member.indent = 2
          rows[#rows + 1] = member
        end
      end
    end
  end
  if #unassigned > 0 then
    rows[#rows + 1] = { kind = "heading", label = "UNASSIGNED", indent = 0, notes = {} }
    for _, row in ipairs(unassigned) do
      row.indent = 2
      rows[#rows + 1] = row
    end
  end
  return board
end

-- The printed lines of one board row: the row itself, then its notes, each
-- note indented two spaces past the row.
function M.row_lines(row)
  local indent = string.rep(" ", row.indent)
  if row.kind == "heading" then
    return { indent .. row.label }
  end
  local lines = { indent .. pad(row.label, 34 - row.indent) .. pad(row.state, 30) .. row.next }
  for _, note in ipairs(row.notes) do
    lines[#lines + 1] = indent .. "  " .. note
  end
  return lines
end

-- The full board for one chain root.
function M.render(rootdir)
  local board = M.board(rootdir)
  if board.empty then
    return "No chains under " .. rootdir .. ". Start one with the intent skill."
  end
  local lines = { pad("CHAIN", 34) .. pad("STATE", 30) .. "NEXT" }
  for _, row in ipairs(board.rows) do
    for _, line in ipairs(M.row_lines(row)) do
      lines[#lines + 1] = line
    end
  end
  if board.done + board.dropped > 0 then
    lines[#lines + 1] = string.format(
      "DONE/DROPPED: %d done, %d dropped (not listed)", board.done, board.dropped)
  end
  return table.concat(lines, "\n")
end

-- Words in a STATE cell that mean the row needs someone's attention.
local ATTENTION_WORDS = { "INVALID", "stale", "blocked", "disproven", "complete" }

-- The session-start text is held under this many bytes: Claude Code caps a
-- hook's stdout at 10,000 characters, and a byte count never undercounts.
M.ATTENTION_LIMIT = 9000

-- Bytes kept free for the line that says how many rows were left out.
local ATTENTION_RESERVE = 64

-- True for a `⤷ milestone …` or `⤷ roadmap …` note; a `⤷ inputs:` note is
-- provenance, not a problem.
local function is_problem_note(note)
  return note:find("⤷ milestone ", 1, true) == 1 or note:find("⤷ roadmap ", 1, true) == 1
end

-- Whether a board row needs attention: its STATE holds one of the attention
-- words, it names a plan as `executing`, or it carries a problem note.
function M.needs_attention(row)
  if row.kind == "heading" then
    return false
  end
  for _, word in ipairs(ATTENTION_WORDS) do
    if row.state:find(word, 1, true) then
      return true
    end
  end
  if row.state:find("plan %d%d executing") then
    return true
  end
  for _, note in ipairs(row.notes) do
    if is_problem_note(note) then
      return true
    end
  end
  return false
end

-- The session-start text for one chain root: a first line counting the open
-- chains and the rows needing attention, then those rows exactly as the
-- board prints them, each followed by its problem notes. The text is held
-- under M.ATTENTION_LIMIT bytes; when rows are left out, a last line says how
-- many. Empty when the chain root does not exist.
function M.attention(rootdir)
  if not (fs.exists(rootdir) and fs.is_dir(rootdir)) then
    return ""
  end
  local board = M.board(rootdir)

  local blocks = {}
  for _, row in ipairs(board.rows) do
    if M.needs_attention(row) then
      local lines = { M.row_lines(row)[1] }
      for _, note in ipairs(row.notes) do
        if is_problem_note(note) then
          lines[#lines + 1] = string.rep(" ", row.indent) .. "  " .. note
        end
      end
      blocks[#blocks + 1] = table.concat(lines, "\n")
    end
  end

  local out = { string.format(
    "claudestacks-sdlc: %d open, %d need attention — full board: /claudestacks-sdlc:status",
    board.open, #blocks) }
  local size = #out[1]
  for i, block in ipairs(blocks) do
    if size + 1 + #block > M.ATTENTION_LIMIT - ATTENTION_RESERVE then
      out[#out + 1] = string.format("  (%d more rows not shown)", #blocks - i + 1)
      break
    end
    out[#out + 1] = block
    size = size + 1 + #block
  end
  return table.concat(out, "\n")
end

return M
