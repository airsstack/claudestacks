-- Tests for lib/status — frontmatter parsing, chain scanning, state derivation
-- and board rendering for the claudestacks-sdlc committed chain.
--
--   airsl test --policy confined --allow-read / \
--     --allow-write "${TMPDIR:-/tmp}" --allow-exec git \
--     plugins/claudestacks-sdlc/scripts

local status = require("lib.status")
local fingerprint = require("lib.fingerprint")

local fs = airsstack.fs
local path = airsstack.path

-- Unless a test sets a body, every fixture artifact carries the body
-- `# body`, so one fingerprint names the authority of every fixture spec and
-- plan. BUILT is the frontmatter
-- line that records it; STALE records an authority that has since changed.
local FP = fingerprint.of_text("---\n---\n# body\n")
local BUILT = "built-on: " .. FP
local STALE = "built-on: 000000000000"

-- Builds a chain root in a temp dir; returns its path.
local function root()
  local dir = path.join(fs.tempdir(), "sdlc")
  fs.mkdir(dir)
  return dir
end

-- Writes one artifact file from frontmatter lines (--- fences added here).
-- `body` is the one body line; it defaults to `# body`.
local function artifact(dir, name, fm, body)
  fs.mkdir(dir)
  fs.write(path.join(dir, name),
    "---\n" .. table.concat(fm, "\n") .. "\n---\n" .. (body or "# body") .. "\n")
end

-- The fingerprint of an artifact whose body is the one line `body`.
local function fp_of(body)
  return fingerprint.of_text("---\n---\n" .. body .. "\n")
end

-- Scans a one-chain root and derives that chain.
local function derive_only(dir)
  local chains = status.scan(dir)
  assert(#chains == 1, "fixture must hold exactly one chain")
  return status.derive(chains[1])
end

-- Frontmatter of the fixtures the sync tests share.
local INTENT = { "status: approved", "created: 2026-08-24" }
local SKIPPED = { "status: approved", "created: 2026-08-24", "spec: skipped" }
local SPEC = { "status: approved", "created: 2026-08-24", BUILT }

-- Builds a root holding the one chain `2026-08-24-a` from an intent's
-- frontmatter, a spec's (nil for no spec.md) and a list of
-- { file name, frontmatter } plans; returns the root. `bodies` optionally
-- sets the body line of the intent (`intent`) and of the spec (`spec`), so a
-- test can give the two different fingerprints.
local function chain_root(intent_fm, spec_fm, plans, bodies)
  bodies = bodies or {}
  local dir = root()
  local chain = path.join(dir, "2026-08-24-a")
  artifact(chain, "intent.md", intent_fm, bodies.intent)
  if spec_fm then
    artifact(chain, "spec.md", spec_fm, bodies.spec)
  end
  for _, plan in ipairs(plans or {}) do
    artifact(path.join(chain, "plans"), plan[1], plan[2])
  end
  return dir
end

-- Writes `roadmaps/<name>/<file>` (a roadmap.md or a milestone) with the
-- given status, creating the directories on first use.
local function roadmap_file(dir, name, file, status_value)
  fs.mkdir(path.join(dir, "roadmaps"))
  artifact(path.join(dir, "roadmaps", name), file,
    { "status: " .. status_value, "created: 2026-10-01" })
end

-- Writes a chain holding only an intent with the given status and, unless
-- nil, the given `milestone` value.
local function member(dir, name, status_value, milestone)
  local fm = { "status: " .. status_value, "created: 2026-10-01" }
  if milestone then
    fm[#fm + 1] = "milestone: " .. milestone
  end
  artifact(path.join(dir, name), "intent.md", fm)
end

-- A board with the trailing spaces of each line removed: a row whose NEXT
-- is empty is padded out to the NEXT column.
local function trimmed(board)
  return (board:gsub("[ ]+\n", "\n"):gsub("[ ]+$", ""))
end

return {
  a_scalar_and_a_block_list_parse = function()
    local fields = status.parse_frontmatter(table.concat({
      "---",
      "status: draft",
      "created: 2026-08-24",
      "derived-from-rfc:",
      "  - rfcs/a.md",
      "  - rfcs/b.md",
      "---",
      "# body",
    }, "\n"))
    assert(fields.status == "draft", "scalar must parse")
    assert(fields["derived-from-rfc"][2] == "rfcs/b.md", "list must parse in order")
  end,

  an_inline_comment_is_stripped_from_a_scalar = function()
    local fields = status.parse_frontmatter("---\nstatus: draft # pending\n---\n")
    assert(fields.status == "draft", "comment must not join the value, got " .. tostring(fields.status))
  end,

  missing_frontmatter_reports_a_reason = function()
    local fields, reason = status.parse_frontmatter("# just a heading\n")
    assert(fields == nil and reason == "missing frontmatter", tostring(reason))
  end,

  unterminated_frontmatter_reports_a_reason = function()
    local fields, reason = status.parse_frontmatter("---\nstatus: draft\n")
    assert(fields == nil and reason == "unterminated frontmatter", tostring(reason))
  end,

  a_column_zero_block_list_item_still_parses = function()
    local fields = status.parse_frontmatter(table.concat({
      "---",
      "status: draft",
      "derived-from-prd:",
      "- prds/p.md",
      "---",
      "# body",
    }, "\n"))
    assert(fields["derived-from-prd"][1] == "prds/p.md",
      "an unindented list item must still parse, got " .. tostring(fields["derived-from-prd"]))
  end,

  an_empty_root_scans_to_no_chains = function()
    assert(#status.scan(root()) == 0)
  end,

  prds_and_rfcs_are_not_chains = function()
    local dir = root()
    fs.mkdir(path.join(dir, "prds"))
    fs.mkdir(path.join(dir, "rfcs"))
    artifact(path.join(dir, "2026-08-24-a"), "intent.md", { "status: draft", "created: 2026-08-24" })
    local chains = status.scan(dir)
    assert(#chains == 1 and chains[1].name == "2026-08-24-a")
  end,

  a_chain_without_intent_is_invalid = function()
    local dir = root()
    fs.mkdir(path.join(dir, "2026-08-24-a"))
    local chains = status.scan(dir)
    assert(chains[1].invalid == "intent.md missing", tostring(chains[1].invalid))
  end,

  a_missing_status_field_is_invalid = function()
    local dir = root()
    artifact(path.join(dir, "2026-08-24-a"), "intent.md", { "created: 2026-08-24" })
    assert(status.scan(dir)[1].invalid == "intent.md: missing status")
  end,

  plans_are_collected_with_their_numbers = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24", BUILT })
    artifact(path.join(chain, "plans"), "01-core.md", { "status: approved", "created: 2026-08-25", BUILT })
    artifact(path.join(chain, "plans"), "02-extras.md", { "status: draft", "created: 2026-08-25" })
    local plans = status.scan(dir)[1].plans
    assert(#plans == 2 and plans[1].num == "01" and plans[2].num == "02")
  end,

  a_superseded_spec_file_is_ignored = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec-superseded-2026-08-25.md", { "status: superseded", "created: 2026-08-24" })
    assert(status.scan(dir)[1].spec == nil, "only spec.md governs")
  end,

  a_draft_intent_asks_for_approval = function()
    local dir = root()
    artifact(path.join(dir, "2026-08-24-a"), "intent.md", { "status: draft", "created: 2026-08-24" })
    local state, nxt = derive_only(dir)
    assert(state == "intent draft" and nxt == "approve or drop", state .. " / " .. nxt)
  end,

  a_triage_intent_is_tagged_and_asks_for_evidence_review = function()
    local dir = root()
    artifact(path.join(dir, "2026-08-24-a"), "intent.md",
      { "status: draft", "created: 2026-08-24", "source: triage" })
    local state, nxt = derive_only(dir)
    assert(state == "intent draft (triage)" and nxt == "review evidence", state .. " / " .. nxt)
  end,

  an_approved_intent_without_spec_goes_to_design = function()
    local dir = root()
    artifact(path.join(dir, "2026-08-24-a"), "intent.md", { "status: approved", "created: 2026-08-24" })
    local state, nxt = derive_only(dir)
    assert(nxt == "design", state .. " / " .. nxt)
  end,

  a_skipped_spec_goes_straight_to_plan = function()
    local dir = root()
    artifact(path.join(dir, "2026-08-24-a"), "intent.md",
      { "status: approved", "created: 2026-08-24", "spec: skipped" })
    local state, nxt = derive_only(dir)
    assert(state == "intent approved (spec skipped)" and nxt == "plan", state .. " / " .. nxt)
  end,

  a_draft_spec_asks_for_spec_approval = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: draft", "created: 2026-08-24" })
    local state, nxt = derive_only(dir)
    assert(state == "spec draft" and nxt == "approve spec", state .. " / " .. nxt)
  end,

  an_approved_spec_without_plans_goes_to_plan = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24", BUILT })
    local state, nxt = derive_only(dir)
    assert(state == "spec approved" and nxt == "plan", state .. " / " .. nxt)
  end,

  an_approved_plan_with_deps_met_is_executable = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24", BUILT })
    artifact(path.join(chain, "plans"), "01-core.md",
      { "status: done", "created: 2026-08-25" })
    artifact(path.join(chain, "plans"), "02-extras.md",
      { "status: approved", "created: 2026-08-25", "depends-on: [01]", BUILT })
    local state, nxt = derive_only(dir)
    assert(state == "plan 01 done, plan 02 approved", state)
    assert(nxt == "execute 02", nxt)
  end,

  an_unmet_dependency_blocks_execution = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24", BUILT })
    artifact(path.join(chain, "plans"), "01-core.md",
      { "status: executing", "created: 2026-08-25", BUILT })
    artifact(path.join(chain, "plans"), "02-extras.md",
      { "status: approved", "created: 2026-08-25", "depends-on: [01]", BUILT })
    local state, nxt = derive_only(dir)
    assert(nxt == "wait (dependencies pending)", nxt)
  end,

  a_draft_plan_asks_for_plan_approval = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24", BUILT })
    artifact(path.join(chain, "plans"), "01-core.md", { "status: draft", "created: 2026-08-25" })
    local state, nxt = derive_only(dir)
    assert(nxt == "approve plan 01", nxt)
  end,

  a_lone_executing_plan_has_no_further_derivation = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24", BUILT })
    artifact(path.join(chain, "plans"), "01-core.md", { "status: executing", "created: 2026-08-25", BUILT })
    local state, nxt = derive_only(dir)
    assert(state == "plan 01 executing", state)
    assert(nxt == "", "mid-flight plan must derive no NEXT, got " .. tostring(nxt))
  end,

  -- A chain whose plans are finished but whose intent was never flipped to
  -- `done` is a missed walk-up. It is a row, not a tail count, so the board
  -- shows it (reference §9).
  a_complete_chain_is_a_row_and_is_not_counted_in_the_tail = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24", BUILT })
    artifact(path.join(chain, "plans"), "01-core.md", { "status: done", "created: 2026-08-25" })
    local state, nxt = derive_only(dir)
    assert(state == "chain complete" and nxt == "execute walk-up", state .. " / " .. nxt)

    local board = status.render(dir)
    assert(board:find("2026-08-24-a                      chain complete                execute walk-up", 1, true),
      "a complete chain must be a row, got:\n" .. board)
    assert(not board:find("DONE/DROPPED", 1, true), "the tail must not count it, got:\n" .. board)
  end,

  -- A chain whose plans are ALL `superseded` and NONE `done` is not
  -- complete: there is no done plan to walk up. Reference §9 sends it to
  -- "plan" — the chain needs a replacement plan, same action as an
  -- approved spec with no plans yet.
  an_all_superseded_chain_with_no_done_plan_is_not_complete = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24", BUILT })
    artifact(path.join(chain, "plans"), "01-core.md", { "status: superseded", "created: 2026-08-25" })
    artifact(path.join(chain, "plans"), "02-core.md", { "status: superseded", "created: 2026-08-25" })
    local state, nxt = derive_only(dir)
    assert(state ~= "chain complete", state)
    assert(nxt == "plan", nxt)
  end,

  -- Second-pass finding A: intent (status.lua:200-203) and spec
  -- (status.lua:265-266) already refuse an unrecognised status with an
  -- INVALID row; plans must do the same, not fall through to `or "plan"`.
  an_unrecognised_plan_status_derives_an_INVALID_row = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24", BUILT })
    artifact(path.join(chain, "plans"), "01-core.md", { "status: pending", "created: 2026-08-25" })
    local state, nxt = derive_only(dir)
    assert(state == "INVALID (plans/01: unknown status pending)", state)
    assert(nxt == "fix 2026-08-24-a", nxt)
  end,

  an_unrecognised_plan_status_is_invalid_even_alongside_a_done_plan = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24", BUILT })
    artifact(path.join(chain, "plans"), "01-core.md", { "status: done", "created: 2026-08-25" })
    artifact(path.join(chain, "plans"), "02-extras.md", { "status: pending", "created: 2026-08-25" })
    local state, nxt = derive_only(dir)
    assert(state == "INVALID (plans/02: unknown status pending)", state)
    assert(nxt == "fix 2026-08-24-a", nxt)
  end,

  a_single_digit_depends_on_still_blocks_execution = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24", BUILT })
    artifact(path.join(chain, "plans"), "01-core.md",
      { "status: executing", "created: 2026-08-25", BUILT })
    artifact(path.join(chain, "plans"), "02-extras.md",
      { "status: approved", "created: 2026-08-25", "depends-on: [1]", BUILT })
    local state, nxt = derive_only(dir)
    assert(nxt == "wait (dependencies pending)",
      "single-digit depends-on must still be recognised, got " .. tostring(nxt))
  end,

  a_triage_tag_persists_once_the_spec_is_approved = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md",
      { "status: approved", "created: 2026-08-24", "source: triage" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24", BUILT })
    local state, nxt = derive_only(dir)
    assert(state == "spec approved (triage)", state)
    assert(nxt == "plan", nxt)
  end,

  an_invalid_chain_derives_to_an_INVALID_row = function()
    local dir = root()
    fs.mkdir(path.join(dir, "2026-08-24-a"))
    local state, nxt = derive_only(dir)
    assert(state == "INVALID (intent.md missing)", state)
    assert(nxt == "fix 2026-08-24-a", nxt)
  end,

  provenance_lists_become_the_inputs_line = function()
    local dir = root()
    artifact(path.join(dir, "2026-08-24-a"), "intent.md", {
      "status: approved", "created: 2026-08-24",
      "derived-from-prd:", "  - prds/p.md",
      "derived-from-rfc:", "  - rfcs/r1.md", "  - rfcs/r2.md",
    })
    local board = status.render(dir)
    assert(board:find("inputs: prds/p.md · rfcs/r1.md · rfcs/r2.md", 1, true), board)
  end,

  done_and_dropped_chains_collapse_to_a_tail_count = function()
    local dir = root()
    artifact(path.join(dir, "2026-08-24-a"), "intent.md", { "status: done", "created: 2026-08-24" })
    artifact(path.join(dir, "2026-08-25-b"), "intent.md", { "status: dropped", "created: 2026-08-25" })
    artifact(path.join(dir, "2026-08-26-c"), "intent.md", { "status: draft", "created: 2026-08-26" })
    local board = status.render(dir)
    assert(not board:find("2026-08-24-a", 1, true), "done chains are not rows")
    assert(not board:find("2026-08-25-b", 1, true), "dropped chains are not rows")
    assert(board:find("DONE/DROPPED: 1 done, 1 dropped", 1, true), board)
  end,

  an_empty_root_renders_a_starter_hint = function()
    local board = status.render(root())
    assert(board:find("No chains", 1, true), board)
  end,

  -- Fingerprints read with the chain (reference §10).

  an_approved_chain_carries_the_fingerprints_of_its_intent_and_spec = function()
    local chain = status.scan(chain_root(INTENT, SPEC))[1]
    assert(chain.intent_fp == FP, tostring(chain.intent_fp))
    assert(chain.spec_fp == FP, tostring(chain.spec_fp))
  end,

  a_chain_whose_intent_is_not_approved_is_not_fingerprinted = function()
    local chain = status.scan(chain_root({ "status: draft", "created: 2026-08-24" }, SPEC))[1]
    assert(chain.intent_fp == nil and chain.spec_fp == nil,
      tostring(chain.intent_fp) .. " / " .. tostring(chain.spec_fp))
  end,

  -- Sync rules (reference §10): invalid results I2-I5.

  a_spec_with_an_unknown_status_is_invalid_even_with_plans = function()
    local state, nxt = derive_only(chain_root(INTENT,
      { "status: superseded", "created: 2026-08-24", BUILT },
      { { "01-core.md", { "status: approved", "created: 2026-08-25", BUILT } } }))
    assert(state == "INVALID (spec.md: unknown status superseded)", state)
    assert(nxt == "fix 2026-08-24-a", nxt)
  end,

  an_approved_spec_without_built_on_is_invalid = function()
    local state, nxt = derive_only(chain_root(INTENT,
      { "status: approved", "created: 2026-08-24" }))
    assert(state == "INVALID (spec.md: missing built-on)", state)
    assert(nxt == "fix 2026-08-24-a", nxt)
  end,

  an_empty_built_on_key_counts_as_missing = function()
    local state = derive_only(chain_root(INTENT,
      { "status: approved", "created: 2026-08-24", "built-on:" }))
    assert(state == "INVALID (spec.md: missing built-on)", state)
  end,

  a_live_plan_with_no_spec_and_no_skip_flag_is_invalid = function()
    local state, nxt = derive_only(chain_root(INTENT, nil,
      { { "01-core.md", { "status: approved", "created: 2026-08-25", BUILT } } }))
    assert(state == "INVALID (plans/01: no spec and no skip flag)", state)
    assert(nxt == "fix 2026-08-24-a", nxt)
  end,

  a_live_plan_without_built_on_is_invalid = function()
    local state, nxt = derive_only(chain_root(INTENT, SPEC,
      { { "01-core.md", { "status: executing", "created: 2026-08-25" } } }))
    assert(state == "INVALID (plans/01: missing built-on)", state)
    assert(nxt == "fix 2026-08-24-a", nxt)
  end,

  an_unknown_plan_status_outranks_a_missing_spec_built_on = function()
    local state = derive_only(chain_root(INTENT,
      { "status: approved", "created: 2026-08-24" },
      { { "01-core.md", { "status: pending", "created: 2026-08-25" } } }))
    assert(state == "INVALID (plans/01: unknown status pending)", state)
  end,

  a_missing_spec_built_on_outranks_a_missing_plan_built_on = function()
    local state = derive_only(chain_root(INTENT,
      { "status: approved", "created: 2026-08-24" },
      { { "01-core.md", { "status: approved", "created: 2026-08-25" } } }))
    assert(state == "INVALID (spec.md: missing built-on)", state)
  end,

  a_missing_authority_outranks_a_missing_plan_built_on = function()
    local state = derive_only(chain_root(INTENT, nil,
      { { "01-core.md", { "status: approved", "created: 2026-08-25" } } }))
    assert(state == "INVALID (plans/01: no spec and no skip flag)", state)
  end,

  the_lowest_plan_number_is_named_first = function()
    local state = derive_only(chain_root(INTENT, SPEC, {
      { "01-core.md", { "status: approved", "created: 2026-08-25" } },
      { "02-extras.md", { "status: approved", "created: 2026-08-25" } },
    }))
    assert(state == "INVALID (plans/01: missing built-on)", state)
  end,

  draft_and_settled_plans_are_not_checked = function()
    local state, nxt = derive_only(chain_root(INTENT, nil, {
      { "01-core.md", { "status: draft", "created: 2026-08-25" } },
      { "02-extras.md", { "status: done", "created: 2026-08-25" } },
      { "03-old.md", { "status: superseded", "created: 2026-08-25" } },
    }))
    assert(state == "plan 01 draft, plan 02 done, plan 03 superseded", state)
    assert(nxt == "approve plan 01", nxt)
  end,

  a_chain_whose_intent_is_not_approved_is_not_checked = function()
    local state, nxt = derive_only(chain_root(
      { "status: draft", "created: 2026-08-24" },
      { "status: approved", "created: 2026-08-24" },
      { { "01-core.md", { "status: approved", "created: 2026-08-25" } } }))
    assert(state == "intent draft" and nxt == "approve or drop", state .. " / " .. nxt)
  end,

  -- Sync rules: conditions C1-C4, STATE composition and the NEXT order.

  a_spec_built_on_another_intent_text_is_stale = function()
    local state, nxt = derive_only(chain_root(INTENT,
      { "status: approved", "created: 2026-08-24", STALE }))
    assert(state == "spec stale (intent changed)", state)
    assert(nxt == "design", nxt)
  end,

  a_stale_spec_leads_the_plan_parts = function()
    local state, nxt = derive_only(chain_root(INTENT,
      { "status: approved", "created: 2026-08-24", STALE },
      { { "01-core.md", { "status: approved", "created: 2026-08-25", BUILT } } }))
    assert(state == "spec stale (intent changed), plan 01 approved", state)
    assert(nxt == "design", nxt)
  end,

  a_live_plan_under_a_draft_spec_is_blocked = function()
    local state, nxt = derive_only(chain_root(INTENT,
      { "status: draft", "created: 2026-08-24" },
      { { "01-core.md", { "status: approved", "created: 2026-08-25", BUILT } } }))
    assert(state == "plan 01 approved: blocked (spec not approved)", state)
    assert(nxt == "approve spec", nxt)
  end,

  blocked_takes_a_plan_over_stale = function()
    local state, nxt = derive_only(chain_root(INTENT,
      { "status: draft", "created: 2026-08-24" },
      { { "01-core.md", { "status: approved", "created: 2026-08-25", STALE } } }))
    assert(state == "plan 01 approved: blocked (spec not approved)", state)
    assert(nxt == "approve spec", nxt)
  end,

  a_plan_built_on_another_spec_text_is_stale = function()
    local state, nxt = derive_only(chain_root(INTENT, SPEC,
      { { "01-core.md", { "status: approved", "created: 2026-08-25", STALE } } }))
    assert(state == "plan 01 approved: stale (spec changed)", state)
    assert(nxt == "plan", nxt)
  end,

  an_executing_stale_plan_keeps_its_status_in_the_row = function()
    local state, nxt = derive_only(chain_root(INTENT, SPEC,
      { { "01-core.md", { "status: executing", "created: 2026-08-25", STALE } } }))
    assert(state == "plan 01 executing: stale (spec changed)", state)
    assert(nxt == "plan", nxt)
  end,

  a_stale_plan_on_the_skip_path_names_the_intent = function()
    local state, nxt = derive_only(chain_root(SKIPPED, nil,
      { { "01-core.md", { "status: approved", "created: 2026-08-25", STALE } } }))
    assert(state == "plan 01 approved: stale (intent changed)", state)
    assert(nxt == "plan", nxt)
  end,

  a_plan_on_the_skip_path_built_on_the_intent_is_executable = function()
    local state, nxt = derive_only(chain_root(SKIPPED, nil,
      { { "01-core.md", { "status: approved", "created: 2026-08-25", BUILT } } }))
    assert(state == "plan 01 approved" and nxt == "execute 01", state .. " / " .. nxt)
  end,

  a_disproven_spec_is_reported_from_a_done_plan_and_never_offers_execute = function()
    local state, nxt = derive_only(chain_root(INTENT, SPEC, {
      { "01-core.md", { "status: done", "created: 2026-08-25", BUILT, "disproves: " .. FP } },
      { "02-extras.md", { "status: approved", "created: 2026-08-25", BUILT } },
    }))
    assert(state == "spec disproven by plan 01, plan 01 done, plan 02 approved", state)
    assert(nxt == "design", nxt)
  end,

  a_disproven_intent_on_the_skip_path_goes_to_intent = function()
    local state, nxt = derive_only(chain_root(SKIPPED, nil, {
      { "01-core.md", { "status: done", "created: 2026-08-25", BUILT, "disproves: " .. FP } },
      { "02-extras.md", { "status: approved", "created: 2026-08-25", BUILT } },
    }))
    assert(state == "intent disproven by plan 01, plan 01 done, plan 02 approved", state)
    assert(nxt == "intent", nxt)
  end,

  a_disproves_value_that_no_longer_matches_raises_nothing = function()
    local state, nxt = derive_only(chain_root(INTENT, SPEC, {
      { "01-core.md", { "status: done", "created: 2026-08-25", BUILT, "disproves: 000000000000" } },
      { "02-extras.md", { "status: approved", "created: 2026-08-25", BUILT } },
    }))
    assert(state == "plan 01 done, plan 02 approved", state)
    assert(nxt == "execute 02", nxt)
  end,

  a_superseded_plan_does_not_raise_disproven = function()
    local state, nxt = derive_only(chain_root(INTENT, SPEC, {
      { "01-core.md", { "status: superseded", "created: 2026-08-25", BUILT, "disproves: " .. FP } },
      { "02-extras.md", { "status: approved", "created: 2026-08-25", BUILT } },
    }))
    assert(state == "plan 01 superseded, plan 02 approved", state)
    assert(nxt == "execute 02", nxt)
  end,

  the_lowest_disproving_plan_is_named = function()
    local state = derive_only(chain_root(INTENT, SPEC, {
      { "01-core.md", { "status: done", "created: 2026-08-25", BUILT, "disproves: " .. FP } },
      { "02-extras.md", { "status: done", "created: 2026-08-25", BUILT, "disproves: " .. FP } },
    }))
    assert(state == "spec disproven by plan 01, plan 01 done, plan 02 done", state)
  end,

  a_stale_spec_and_a_disproven_spec_are_both_shown = function()
    local state, nxt = derive_only(chain_root(INTENT,
      { "status: approved", "created: 2026-08-24", STALE },
      { { "01-core.md", { "status: done", "created: 2026-08-25", BUILT, "disproves: " .. FP } } }))
    assert(state == "spec stale (intent changed), spec disproven by plan 01, plan 01 done", state)
    assert(nxt == "design", nxt)
  end,

  disproven_outranks_a_stale_plan = function()
    local state, nxt = derive_only(chain_root(INTENT, SPEC, {
      { "01-core.md", { "status: done", "created: 2026-08-25", BUILT, "disproves: " .. FP } },
      { "02-extras.md", { "status: approved", "created: 2026-08-25", STALE } },
    }))
    assert(state == "spec disproven by plan 01, plan 01 done, plan 02 approved: stale (spec changed)", state)
    assert(nxt == "design", nxt)
  end,

  disproven_outranks_a_blocked_plan = function()
    local state, nxt = derive_only(chain_root(INTENT,
      { "status: draft", "created: 2026-08-24" }, {
      { "01-core.md", { "status: executing", "created: 2026-08-25", BUILT, "disproves: " .. FP } },
      { "02-extras.md", { "status: approved", "created: 2026-08-25", BUILT } },
    }))
    assert(state == "spec disproven by plan 01, plan 01 executing: blocked (spec not approved), "
      .. "plan 02 approved: blocked (spec not approved)", state)
    assert(nxt == "design", nxt)
  end,

  a_standing_disproof_keeps_a_finished_chain_open = function()
    local dir = chain_root(INTENT, SPEC,
      { { "01-core.md", { "status: done", "created: 2026-08-25", BUILT, "disproves: " .. FP } } })
    local state, nxt = derive_only(dir)
    assert(state == "spec disproven by plan 01, plan 01 done", state)
    assert(nxt == "design", nxt)
  end,

  a_stale_spec_keeps_a_finished_chain_open = function()
    local state, nxt = derive_only(chain_root(INTENT,
      { "status: approved", "created: 2026-08-24", STALE },
      { { "01-core.md", { "status: done", "created: 2026-08-25", BUILT } } }))
    assert(state == "spec stale (intent changed), plan 01 done", state)
    assert(nxt == "design", nxt)
  end,

  the_triage_tag_follows_the_sync_parts = function()
    local triage = { "status: approved", "created: 2026-08-24", "source: triage" }
    local state = derive_only(chain_root(triage,
      { "status: approved", "created: 2026-08-24", STALE }))
    assert(state == "spec stale (intent changed) (triage)", state)

    state = derive_only(chain_root(triage, SPEC,
      { { "01-core.md", { "status: approved", "created: 2026-08-25", STALE } } }))
    assert(state == "plan 01 approved: stale (spec changed) (triage)", state)
  end,

  -- Authority tests: the intent and the spec carry different bodies, so a
  -- fingerprint can only match the artifact it was taken from.

  a_plan_built_on_the_intent_text_is_stale_under_a_spec = function()
    local intent_fp = fp_of("# intent body")
    local state, nxt = derive_only(chain_root(INTENT,
      { "status: approved", "created: 2026-08-24", "built-on: " .. intent_fp },
      { { "01-core.md", { "status: approved", "created: 2026-08-25", "built-on: " .. intent_fp } } },
      { intent = "# intent body", spec = "# spec body" }))
    assert(state == "plan 01 approved: stale (spec changed)", state)
    assert(nxt == "plan", nxt)
  end,

  a_spec_built_on_its_own_text_is_stale = function()
    local state, nxt = derive_only(chain_root(INTENT,
      { "status: approved", "created: 2026-08-24", "built-on: " .. fp_of("# spec body") },
      nil,
      { intent = "# intent body", spec = "# spec body" }))
    assert(state == "spec stale (intent changed)", state)
    assert(nxt == "design", nxt)
  end,

  a_plan_built_on_the_spec_text_is_not_stale_when_the_bodies_differ = function()
    local state, nxt = derive_only(chain_root(INTENT,
      { "status: approved", "created: 2026-08-24", "built-on: " .. fp_of("# intent body") },
      { { "01-core.md", { "status: approved", "created: 2026-08-25", "built-on: " .. fp_of("# spec body") } } },
      { intent = "# intent body", spec = "# spec body" }))
    assert(state == "plan 01 approved" and nxt == "execute 01", state .. " / " .. nxt)
  end,

  -- Sync rules: the cases the plain fixtures could not tell apart.

  draft_and_settled_plans_under_a_draft_spec_are_not_blocked = function()
    local state, nxt = derive_only(chain_root(INTENT,
      { "status: draft", "created: 2026-08-24" }, {
      { "01-core.md", { "status: draft", "created: 2026-08-25" } },
      { "02-extras.md", { "status: done", "created: 2026-08-25" } },
    }))
    assert(state == "plan 01 draft, plan 02 done", state)
    assert(nxt == "approve plan 01", nxt)
  end,

  an_empty_built_on_key_on_a_live_plan_counts_as_missing = function()
    local state = derive_only(chain_root(INTENT, SPEC,
      { { "01-core.md", { "status: approved", "created: 2026-08-25", "built-on:" } } }))
    assert(state == "INVALID (plans/01: missing built-on)", state)
  end,

  an_unknown_spec_status_outranks_a_missing_plan_built_on = function()
    local state, nxt = derive_only(chain_root(INTENT,
      { "status: superseded", "created: 2026-08-24", BUILT },
      { { "01-core.md", { "status: approved", "created: 2026-08-25" } } }))
    assert(state == "INVALID (spec.md: unknown status superseded)", state)
    assert(nxt == "fix 2026-08-24-a", nxt)
  end,

  a_spec_file_outranks_the_skip_flag_for_authority = function()
    local state, nxt = derive_only(chain_root(SKIPPED,
      { "status: draft", "created: 2026-08-24" },
      { { "01-core.md", { "status: approved", "created: 2026-08-25", BUILT } } }))
    assert(state == "plan 01 approved: blocked (spec not approved)", state)
    assert(nxt == "approve spec", nxt)
  end,

  -- Roadmaps and milestones on the board (reference §11).

  the_roadmaps_directory_is_not_a_chain = function()
    local dir = root()
    roadmap_file(dir, "platform", "roadmap.md", "approved")
    artifact(path.join(dir, "2026-10-13-mfa"), "intent.md", { "status: approved", "created: 2026-10-13" })
    local chains = status.scan(dir)
    assert(#chains == 1 and chains[1].name == "2026-10-13-mfa", "roadmaps must not scan as a chain")
    assert(not status.render(dir):find("fix roadmaps", 1, true), status.render(dir))
  end,

  a_root_without_a_roadmap_keeps_the_flat_layout = function()
    local dir = root()
    fs.mkdir(path.join(dir, "roadmaps"))
    artifact(path.join(dir, "2026-10-13-mfa"), "intent.md", { "status: approved", "created: 2026-10-13" })
    artifact(path.join(dir, "2026-10-14-typo"), "intent.md", { "status: draft", "created: 2026-10-14" })
    artifact(path.join(dir, "2026-10-15-old"), "intent.md", { "status: done", "created: 2026-10-15" })
    assert(trimmed(status.render(dir)) == table.concat({
      "CHAIN                             STATE                         NEXT",
      "2026-10-13-mfa                    intent approved               design",
      "2026-10-14-typo                   intent draft                  approve or drop",
      "DONE/DROPPED: 1 done, 0 dropped (not listed)",
    }, "\n"), status.render(dir))
  end,

  chains_are_grouped_under_their_milestone_and_the_rest_under_unassigned = function()
    local dir = root()
    roadmap_file(dir, "platform", "roadmap.md", "approved")
    roadmap_file(dir, "platform", "01-auth.md", "done")
    roadmap_file(dir, "platform", "02-billing.md", "approved")
    roadmap_file(dir, "mobile", "roadmap.md", "draft")
    member(dir, "2026-10-01-login", "done", "platform/01")
    member(dir, "2026-10-12-ledger", "done", "platform/02")
    member(dir, "2026-10-14-refunds", "draft", "platform/02")
    local invoices = path.join(dir, "2026-10-13-invoices")
    artifact(invoices, "intent.md",
      { "status: approved", "created: 2026-10-13", "milestone: platform/02" })
    artifact(invoices, "spec.md", SPEC)
    artifact(path.join(invoices, "plans"), "01-core.md",
      { "status: approved", "created: 2026-10-13", STALE })
    member(dir, "2026-10-15-fix-typo", "approved", nil)
    member(dir, "2026-09-01-old", "dropped", nil)
    assert(trimmed(status.render(dir)) == table.concat({
      "CHAIN                             STATE                         NEXT",
      "ROADMAP mobile                    draft, 0 of 0 milestones done approve or drop",
      "ROADMAP platform                  approved, 1 of 2 milestones done",
      "MILESTONE platform/01-auth        done, 1 of 1 done",
      "MILESTONE platform/02-billing     approved, 1 of 3 done",
      "  2026-10-13-invoices             plan 01 approved: stale (spec changed)  plan",
      "  2026-10-14-refunds              intent draft                  approve or drop",
      "UNASSIGNED",
      "  2026-10-15-fix-typo             intent approved               design",
      "DONE/DROPPED: 2 done, 1 dropped (not listed)",
    }, "\n"), status.render(dir))
  end,

  unassigned_is_omitted_when_every_open_chain_is_a_member = function()
    local dir = root()
    roadmap_file(dir, "platform", "roadmap.md", "approved")
    roadmap_file(dir, "platform", "01-auth.md", "approved")
    member(dir, "2026-10-01-login", "draft", "platform/01")
    assert(not status.render(dir):find("UNASSIGNED", 1, true), status.render(dir))
  end,

  a_root_with_a_roadmap_and_no_chain_renders_the_roadmap = function()
    local dir = root()
    roadmap_file(dir, "platform", "roadmap.md", "approved")
    assert(trimmed(status.render(dir)) == table.concat({
      "CHAIN                             STATE                         NEXT",
      "ROADMAP platform                  approved, 0 of 0 milestones done  add milestone",
    }, "\n"), status.render(dir))
  end,

  a_chain_naming_a_dropped_milestone_is_annotated_after_its_inputs = function()
    local dir = root()
    roadmap_file(dir, "platform", "roadmap.md", "approved")
    roadmap_file(dir, "platform", "01-auth.md", "dropped")
    artifact(path.join(dir, "2026-10-13-mfa"), "intent.md", {
      "status: approved", "created: 2026-10-13", "milestone: platform/01",
      "derived-from-prd:", "  - prds/p.md",
    })
    assert(trimmed(status.render(dir)) == table.concat({
      "CHAIN                             STATE                         NEXT",
      "ROADMAP platform                  approved, 0 of 0 milestones done  add milestone",
      "MILESTONE platform/01-auth        dropped",
      "  2026-10-13-mfa                  intent approved               design",
      "    ⤷ inputs: prds/p.md",
      "    ⤷ milestone platform/01 is dropped — release this chain",
    }, "\n"), status.render(dir))
  end,

  a_live_milestone_under_a_dropped_roadmap_is_annotated = function()
    local dir = root()
    roadmap_file(dir, "platform", "roadmap.md", "dropped")
    roadmap_file(dir, "platform", "01-auth.md", "approved")
    roadmap_file(dir, "platform", "02-billing.md", "done")
    assert(trimmed(status.render(dir)) == table.concat({
      "CHAIN                             STATE                         NEXT",
      "ROADMAP platform                  dropped",
      "MILESTONE platform/01-auth        approved, 0 of 0 done         park scope",
      "  ⤷ roadmap platform is dropped — drop this milestone",
    }, "\n"), status.render(dir))
  end,

  a_done_milestone_under_a_dropped_roadmap_is_not_told_to_drop = function()
    local dir = root()
    roadmap_file(dir, "platform", "roadmap.md", "dropped")
    roadmap_file(dir, "platform", "02-billing.md", "done")
    member(dir, "2026-10-02-late", "approved", "platform/02")
    local board = status.render(dir)
    assert(board:find("MILESTONE platform/02-billing", 1, true), board)
    assert(not board:find("drop this milestone", 1, true), board)
  end,

  a_chain_invalid_by_status_is_not_told_to_release_a_dropped_milestone = function()
    local dir = root()
    roadmap_file(dir, "platform", "roadmap.md", "approved")
    roadmap_file(dir, "platform", "01-auth.md", "dropped")
    member(dir, "2026-10-13-mfa", "executing", "platform/01")
    local board = status.render(dir)
    assert(board:find("2026-10-13-mfa", 1, true) and board:find("INVALID (intent.md: unknown status executing)", 1, true), board)
    assert(not board:find("release this chain", 1, true), board)
  end,

  an_empty_milestone_key_is_an_unknown_milestone_and_the_board_still_renders = function()
    local dir = root()
    member(dir, "2026-10-13-mfa", "approved", "")
    local state = status.derive(status.scan(dir)[1], {})
    assert(state:find("^INVALID %(intent.md: unknown milestone"), state)
    local ok, board = pcall(status.render, dir)
    assert(ok, tostring(board))
    assert(board:find("INVALID (intent.md: unknown milestone", 1, true), board)
  end,

  a_finished_milestone_under_a_closed_roadmap_prints_while_it_has_an_open_chain = function()
    local dir = root()
    roadmap_file(dir, "platform", "roadmap.md", "done")
    roadmap_file(dir, "platform", "01-auth.md", "done")
    roadmap_file(dir, "platform", "02-billing.md", "done")
    member(dir, "2026-10-01-login", "done", "platform/01")
    member(dir, "2026-10-02-late", "approved", "platform/02")
    assert(trimmed(status.render(dir)) == table.concat({
      "CHAIN                             STATE                         NEXT",
      "ROADMAP platform                  done, 2 of 2 milestones done",
      "MILESTONE platform/02-billing     INVALID (done with open chains)  fix platform/02",
      "  2026-10-02-late                 intent approved               design",
      "DONE/DROPPED: 1 done, 0 dropped (not listed)",
    }, "\n"), status.render(dir))
  end,

  a_finished_milestone_and_roadmap_ask_for_the_roll_up = function()
    local dir = root()
    roadmap_file(dir, "platform", "roadmap.md", "approved")
    roadmap_file(dir, "platform", "01-auth.md", "approved")
    roadmap_file(dir, "next", "roadmap.md", "approved")
    roadmap_file(dir, "next", "01-only.md", "done")
    member(dir, "2026-10-01-login", "done", "platform/01")
    member(dir, "2026-10-02-sso", "dropped", "platform/01")
    assert(trimmed(status.render(dir)) == table.concat({
      "CHAIN                             STATE                         NEXT",
      "ROADMAP next                      roadmap complete              roll up",
      "MILESTONE next/01-only            done, 0 of 0 done",
      "ROADMAP platform                  approved, 0 of 1 milestones done",
      "MILESTONE platform/01-auth        milestone complete            roll up",
      "DONE/DROPPED: 1 done, 1 dropped (not listed)",
    }, "\n"), status.render(dir))
  end,

  the_board_counts_its_open_chains = function()
    local dir = root()
    roadmap_file(dir, "platform", "roadmap.md", "approved")
    roadmap_file(dir, "platform", "01-auth.md", "approved")
    member(dir, "2026-10-01-login", "done", "platform/01")
    member(dir, "2026-10-02-sso", "draft", "platform/01")
    member(dir, "2026-10-03-typo", "approved", nil)
    fs.mkdir(path.join(dir, "2026-10-04-broken"))
    local board = status.board(dir)
    assert(board.open == 3 and board.done == 1 and board.dropped == 0,
      board.open .. " open, " .. board.done .. " done, " .. board.dropped .. " dropped")
    assert(not board.empty)
  end,

  a_milestone_key_without_any_roadmap_is_invalid = function()
    local dir = root()
    member(dir, "2026-10-13-mfa", "approved", "platform/01")
    local state, nxt = status.derive(status.scan(dir)[1], {})
    assert(state == "INVALID (intent.md: unknown milestone platform/01)", state)
    assert(nxt == "fix 2026-10-13-mfa", nxt)
    assert(status.render(dir):find("2026-10-13-mfa                    INVALID (intent.md: unknown milestone platform/01)", 1, true),
      status.render(dir))
  end,

  a_broken_milestone_key_lists_the_chain_under_unassigned = function()
    local dir = root()
    roadmap_file(dir, "platform", "roadmap.md", "approved")
    roadmap_file(dir, "platform", "01-auth.md", "approved")
    roadmap_file(dir, "platform", "02-a.md", "approved")
    roadmap_file(dir, "platform", "02-b.md", "approved")
    member(dir, "2026-10-13-none", "draft", "platform/09")
    member(dir, "2026-10-14-form", "approved", "platform")
    member(dir, "2026-10-15-twice", "approved", "platform/02")
    local board = trimmed(status.render(dir))
    local tail = board:sub(board:find("UNASSIGNED", 1, true), -1)
    assert(tail == table.concat({
      "UNASSIGNED",
      "  2026-10-13-none                 INVALID (intent.md: unknown milestone platform/09)  fix 2026-10-13-none",
      "  2026-10-14-form                 INVALID (intent.md: unknown milestone platform)  fix 2026-10-14-form",
      "  2026-10-15-twice                INVALID (intent.md: ambiguous milestone platform/02)  fix 2026-10-15-twice",
    }, "\n"), board)
  end,

  a_broken_milestone_key_ranks_between_an_unknown_plan_status_and_the_sync_rules = function()
    local dir = root()
    local chain = path.join(dir, "2026-10-13-mfa")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-10-13", "milestone: platform/01" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-10-13" })
    local state = derive_only(dir)
    assert(state == "INVALID (intent.md: unknown milestone platform/01)", state)

    artifact(path.join(chain, "plans"), "01-core.md", { "status: pending", "created: 2026-10-13" })
    state = derive_only(dir)
    assert(state == "INVALID (plans/01: unknown status pending)", state)
  end,

  a_closed_chain_with_a_broken_milestone_key_is_not_checked = function()
    local dir = root()
    member(dir, "2026-10-13-mfa", "done", "platform/01")
    local state = derive_only(dir)
    assert(state == "done", state)
  end,

  -- The session-start text printed by the SessionStart hook.

  attention_is_empty_without_a_chain_root = function()
    local text = status.attention(path.join(fs.tempdir(), "absent"))
    assert(text == "", "want nothing, got: " .. text)
  end,

  attention_is_one_line_when_nothing_needs_it = function()
    local dir = root()
    member(dir, "2026-10-13-mfa", "approved", nil)
    member(dir, "2026-10-14-typo", "draft", nil)
    member(dir, "2026-10-15-old", "done", nil)
    local chain = path.join(dir, "2026-10-16-ready")
    artifact(chain, "intent.md", INTENT)
    artifact(chain, "spec.md", SPEC)
    artifact(path.join(chain, "plans"), "01-core.md",
      { "status: approved", "created: 2026-10-16", BUILT })
    assert(status.attention(dir)
      == "claudestacks-sdlc: 3 open, 0 need attention — full board: /claudestacks-sdlc:status",
      status.attention(dir))
  end,

  attention_lists_each_chain_row_that_needs_it = function()
    local dir = root()
    fs.mkdir(path.join(dir, "2026-10-01-invalid"))
    local function chain(name, spec_fm, plan_fm)
      local cdir = path.join(dir, name)
      artifact(cdir, "intent.md", INTENT)
      artifact(cdir, "spec.md", spec_fm)
      artifact(path.join(cdir, "plans"), "01-core.md", plan_fm)
    end
    chain("2026-10-02-stale", SPEC, { "status: approved", "created: 2026-10-02", STALE })
    chain("2026-10-03-blocked", { "status: draft", "created: 2026-10-03" },
      { "status: approved", "created: 2026-10-03", BUILT })
    chain("2026-10-04-disproven", SPEC,
      { "status: done", "created: 2026-10-04", BUILT, "disproves: " .. FP })
    chain("2026-10-05-complete", SPEC, { "status: done", "created: 2026-10-05", BUILT })
    chain("2026-10-06-running", SPEC, { "status: executing", "created: 2026-10-06", BUILT })
    chain("2026-10-07-ready", SPEC, { "status: approved", "created: 2026-10-07", BUILT })
    member(dir, "2026-10-08-idea", "draft", nil)
    assert(trimmed(status.attention(dir)) == table.concat({
      "claudestacks-sdlc: 8 open, 6 need attention — full board: /claudestacks-sdlc:status",
      "2026-10-01-invalid                INVALID (intent.md missing)   fix 2026-10-01-invalid",
      "2026-10-02-stale                  plan 01 approved: stale (spec changed)  plan",
      "2026-10-03-blocked                plan 01 approved: blocked (spec not approved)  approve spec",
      "2026-10-04-disproven              spec disproven by plan 01, plan 01 done  design",
      "2026-10-05-complete               chain complete                execute walk-up",
      "2026-10-06-running                plan 01 executing",
    }, "\n"), status.attention(dir))
  end,

  attention_lists_milestone_rows_and_problem_notes_but_not_inputs = function()
    local dir = root()
    roadmap_file(dir, "old", "roadmap.md", "dropped")
    roadmap_file(dir, "old", "01-left.md", "approved")
    roadmap_file(dir, "platform", "roadmap.md", "approved")
    roadmap_file(dir, "platform", "01-auth.md", "approved")
    roadmap_file(dir, "platform", "02-billing.md", "dropped")
    member(dir, "2026-10-01-login", "done", "platform/01")
    artifact(path.join(dir, "2026-10-02-refunds"), "intent.md", {
      "status: draft", "created: 2026-10-02", "milestone: platform/02",
      "derived-from-prd:", "  - prds/p.md",
    })
    assert(trimmed(status.attention(dir)) == table.concat({
      "claudestacks-sdlc: 1 open, 3 need attention — full board: /claudestacks-sdlc:status",
      "MILESTONE old/01-left             approved, 0 of 0 done         park scope",
      "  ⤷ roadmap old is dropped — drop this milestone",
      "MILESTONE platform/01-auth        milestone complete            roll up",
      "  2026-10-02-refunds              intent draft                  approve or drop",
      "    ⤷ milestone platform/02 is dropped — release this chain",
    }, "\n"), status.attention(dir))
  end,

  -- A finished roadmap is a ROADMAP row that qualifies; the UNASSIGNED
  -- heading above the unassigned chain never does and has no STATE to read.
  attention_lists_a_roadmap_row_and_skips_the_unassigned_heading = function()
    local dir = root()
    roadmap_file(dir, "next", "roadmap.md", "approved")
    roadmap_file(dir, "next", "01-only.md", "done")
    fs.mkdir(path.join(dir, "2026-10-01-broken"))
    assert(trimmed(status.attention(dir)) == table.concat({
      "claudestacks-sdlc: 1 open, 2 need attention — full board: /claudestacks-sdlc:status",
      "ROADMAP next                      roadmap complete              roll up",
      "  2026-10-01-broken               INVALID (intent.md missing)   fix 2026-10-01-broken",
    }, "\n"), status.attention(dir))
  end,

  -- 100 rows of 98 bytes each: the rows fill the limit to within 1 byte, so
  -- the "more rows" line only fits under the limit if the reserve held space
  -- for it.
  attention_keeps_room_for_the_line_that_says_what_it_left_out = function()
    local dir = root()
    for i = 1, 100 do
      fs.mkdir(path.join(dir, string.format("2026-10-01-broken-chain-nr-%03d", i)))
    end
    local text = status.attention(dir)
    assert(#text <= status.ATTENTION_LIMIT, "want at most " .. status.ATTENTION_LIMIT .. " bytes, got " .. #text)
    assert(text:find("  (11 more rows not shown)", 1, true), text:sub(-60))
  end,

  attention_stays_under_its_size_limit_and_says_what_it_left_out = function()
    local dir = root()
    for i = 1, 200 do
      fs.mkdir(path.join(dir, string.format("2026-10-01-broken-chain-number-%03d", i)))
    end
    local text = status.attention(dir)
    assert(#text < status.ATTENTION_LIMIT, "want under " .. status.ATTENTION_LIMIT .. " bytes, got " .. #text)
    assert(text:find("claudestacks-sdlc: 200 open, 200 need attention", 1, true), text:sub(1, 120))
    local shown = select(2, text:gsub("\n2026%-10%-01%-broken", ""))
    assert(shown > 0 and shown < 200, "want some rows shown, got " .. shown)
    assert(text:sub(-#string.format("  (%d more rows not shown)", 200 - shown))
      == string.format("  (%d more rows not shown)", 200 - shown), text:sub(-60))
  end,
}
