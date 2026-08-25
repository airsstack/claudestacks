-- Tests for lib/status — frontmatter parsing, chain scanning, state derivation
-- and board rendering for the claudestacks-sdlc committed chain.
--
--   airsl test --policy confined --allow-read / \
--     --allow-write "${TMPDIR:-/tmp}" --allow-exec git \
--     plugins/claudestacks-sdlc/scripts

local status = require("lib.status")

local fs = airsstack.fs
local path = airsstack.path

-- Builds a chain root in a temp dir; returns its path.
local function root()
  local dir = path.join(fs.tempdir(), "sdlc")
  fs.mkdir(dir)
  return dir
end

-- Writes one artifact file from frontmatter lines (--- fences added here).
local function artifact(dir, name, fm)
  fs.mkdir(dir)
  fs.write(path.join(dir, name), "---\n" .. table.concat(fm, "\n") .. "\n---\n# body\n")
end

-- Scans a one-chain root and derives that chain.
local function derive_only(dir)
  local chains = status.scan(dir)
  assert(#chains == 1, "fixture must hold exactly one chain")
  return status.derive(chains[1])
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
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24" })
    artifact(path.join(chain, "plans"), "01-core.md", { "status: approved", "created: 2026-08-25" })
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
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24" })
    local state, nxt = derive_only(dir)
    assert(state == "spec approved" and nxt == "plan", state .. " / " .. nxt)
  end,

  an_approved_plan_with_deps_met_is_executable = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24" })
    artifact(path.join(chain, "plans"), "01-core.md",
      { "status: done", "created: 2026-08-25" })
    artifact(path.join(chain, "plans"), "02-extras.md",
      { "status: approved", "created: 2026-08-25", "depends-on: [01]" })
    local state, nxt = derive_only(dir)
    assert(state == "plan 01 done, plan 02 approved", state)
    assert(nxt == "execute 02", nxt)
  end,

  an_unmet_dependency_blocks_execution = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24" })
    artifact(path.join(chain, "plans"), "01-core.md",
      { "status: executing", "created: 2026-08-25" })
    artifact(path.join(chain, "plans"), "02-extras.md",
      { "status: approved", "created: 2026-08-25", "depends-on: [01]" })
    local state, nxt = derive_only(dir)
    assert(nxt == "wait (dependencies pending)", nxt)
  end,

  a_draft_plan_asks_for_plan_approval = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24" })
    artifact(path.join(chain, "plans"), "01-core.md", { "status: draft", "created: 2026-08-25" })
    local state, nxt = derive_only(dir)
    assert(nxt == "approve plan 01", nxt)
  end,

  a_lone_executing_plan_has_no_further_derivation = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24" })
    artifact(path.join(chain, "plans"), "01-core.md", { "status: executing", "created: 2026-08-25" })
    local state, nxt = derive_only(dir)
    assert(state == "plan 01 executing", state)
    assert(nxt == "", "mid-flight plan must derive no NEXT, got " .. tostring(nxt))
  end,

  -- Deviation from plan 02's own literal (02-status-board.md:445-446), which
  -- asserted this chain renders a full row with STATE "plans complete" and
  -- NEXT "chain complete; run execute walk-up". Reference §9:188 requires
  -- "all plans done → chain complete" chains to collapse into the DONE/DROPPED
  -- tail (count only), same as a dropped/done intent, not render as a row —
  -- and the two strings the plan literal asserted appear in neither spec §5.1
  -- nor reference §9, so the fallback tier could never reproduce them.
  all_plans_done_derives_chain_complete_and_collapses_to_the_tail = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24" })
    artifact(path.join(chain, "plans"), "01-core.md", { "status: done", "created: 2026-08-25" })
    local state = derive_only(dir)
    assert(state == "chain complete", state)

    local board = status.render(dir)
    assert(not board:find("2026-08-24-a", 1, true), "chain-complete chains are not rows, got:\n" .. board)
    assert(board:find("DONE/DROPPED: 1 done, 0 dropped", 1, true), board)
  end,

  -- Reference §9:187-188 names this case ("every plan is `done`/`superseded`")
  -- and now carries the ≥1-`done` guard §7.2:133 already required, so a
  -- chain whose plans are ALL `superseded` and NONE `done` stays off the
  -- collapsed tail — it is neither "chain complete" (no done plan to roll
  -- up) nor any of the other named branches. Minimal defensible NEXT:
  -- "plan" — the chain needs a replacement plan, same action as an
  -- approved spec with no plans yet.
  an_all_superseded_chain_with_no_done_plan_is_not_complete = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24" })
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
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24" })
    artifact(path.join(chain, "plans"), "01-core.md", { "status: pending", "created: 2026-08-25" })
    local state, nxt = derive_only(dir)
    assert(state == "INVALID (plans/01: unknown status pending)", state)
    assert(nxt == "fix 2026-08-24-a", nxt)
  end,

  an_unrecognised_plan_status_is_invalid_even_alongside_a_done_plan = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24" })
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
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24" })
    artifact(path.join(chain, "plans"), "01-core.md",
      { "status: executing", "created: 2026-08-25" })
    artifact(path.join(chain, "plans"), "02-extras.md",
      { "status: approved", "created: 2026-08-25", "depends-on: [1]" })
    local state, nxt = derive_only(dir)
    assert(nxt == "wait (dependencies pending)",
      "single-digit depends-on must still be recognised, got " .. tostring(nxt))
  end,

  a_triage_tag_persists_once_the_spec_is_approved = function()
    local dir = root()
    local chain = path.join(dir, "2026-08-24-a")
    artifact(chain, "intent.md",
      { "status: approved", "created: 2026-08-24", "source: triage" })
    artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24" })
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
}
