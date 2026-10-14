-- Tests for lib/roadmap — scanning `roadmaps/`, resolving a chain's
-- `milestone` key, progress, and the roadmap and milestone rows.
--
--   airsl test --policy confined --allow-read / \
--     --allow-write "${TMPDIR:-/tmp}" --allow-exec git \
--     plugins/claudestacks-sdlc/scripts

local roadmap = require("lib.roadmap")
local status = require("lib.status")

local fs = airsstack.fs
local path = airsstack.path

-- Builds a chain root in a temp dir; returns its path.
local function root()
  local dir = path.join(fs.tempdir(), "sdlc")
  fs.mkdir(dir)
  return dir
end

-- Creates `roadmaps/<name>` under a chain root; returns its path.
local function roadmap_dir(dir, name)
  fs.mkdir(path.join(dir, "roadmaps"))
  local rdir = path.join(dir, "roadmaps", name)
  fs.mkdir(rdir)
  return rdir
end

-- Writes one roadmap or milestone file with the given status.
local function artifact(dir, name, status_value)
  fs.write(path.join(dir, name),
    "---\nstatus: " .. status_value .. "\ncreated: 2026-08-24\n---\n# body\n")
end

local function scan(dir)
  return roadmap.scan(dir, status.read_artifact)
end

-- A milestone as the board hands it to the row functions: a status and the
-- intent statuses of its member chains. A `draft` or `approved` member is
-- still a board row, so it is open.
local function milestone(status_value, member_statuses)
  local item = { num = "01", ref = "platform/01", status = status_value, members = {} }
  for _, member in ipairs(member_statuses or {}) do
    item.members[#item.members + 1] =
      { status = member, open = member == "draft" or member == "approved" }
  end
  return item
end

-- A roadmap holding milestones of the given statuses; false stands for an
-- invalid milestone, which has no status.
local function roadmap_of(status_value, milestone_statuses)
  local item = { name = "platform", status = status_value, milestones = {} }
  for _, ms in ipairs(milestone_statuses or {}) do
    item.milestones[#item.milestones + 1] = { status = ms or nil, roadmap = item, members = {} }
  end
  return item
end

-- The row under test is the LAST argument, so both of its results arrive:
-- a call that is not last in an argument list is truncated to one value.
local function expect(want_state, want_next, state, nxt)
  assert(state == want_state and nxt == want_next,
    "want " .. want_state .. " / " .. want_next .. ", got " .. tostring(state) .. " / " .. tostring(nxt))
end

return {
  a_root_without_a_roadmaps_directory_scans_to_none = function()
    assert(#scan(root()) == 0)
  end,

  a_roadmap_and_its_milestones_are_scanned_in_number_order = function()
    local dir = root()
    local rdir = roadmap_dir(dir, "platform")
    artifact(rdir, "roadmap.md", "approved")
    artifact(rdir, "02-billing.md", "draft")
    artifact(rdir, "01-auth.md", "done")
    local found = scan(dir)
    assert(#found == 1 and found[1].name == "platform" and found[1].status == "approved")
    local first, second = found[1].milestones[1], found[1].milestones[2]
    assert(#found[1].milestones == 2, "want 2 milestones, got " .. #found[1].milestones)
    assert(first.num == "01" and first.stem == "01-auth" and first.ref == "platform/01"
      and first.status == "done", tostring(first.stem))
    assert(second.num == "02" and second.status == "draft", tostring(second.stem))
    assert(first.roadmap == found[1], "a milestone must point back at its roadmap")
  end,

  entries_that_are_not_milestone_files_are_ignored = function()
    local dir = root()
    local rdir = roadmap_dir(dir, "platform")
    artifact(rdir, "roadmap.md", "approved")
    artifact(rdir, "notes.md", "draft")
    artifact(rdir, "1-short.md", "draft")
    fs.mkdir(path.join(rdir, "attachments"))
    fs.write(path.join(dir, "roadmaps", "README.md"), "not a roadmap\n")
    local found = scan(dir)
    assert(#found == 1, "a file under roadmaps/ is not a roadmap")
    assert(#found[1].milestones == 0, "want no milestone, got " .. #found[1].milestones)
  end,

  a_reference_resolves_to_its_milestone = function()
    local dir = root()
    local rdir = roadmap_dir(dir, "platform")
    artifact(rdir, "roadmap.md", "approved")
    artifact(rdir, "01-auth.md", "approved")
    local found = scan(dir)
    assert(roadmap.resolve(found, "platform/01") == found[1].milestones[1])
  end,

  a_reference_that_names_nothing_is_unknown = function()
    local dir = root()
    local rdir = roadmap_dir(dir, "platform")
    artifact(rdir, "roadmap.md", "approved")
    artifact(rdir, "01-auth.md", "approved")
    local found = scan(dir)
    for _, value in ipairs({ "platform", "platform/1", "platform/01-auth", "platform/02", "mobile/01" }) do
      local milestone_found, why = roadmap.resolve(found, value)
      assert(milestone_found == nil and why == "unknown", value .. " -> " .. tostring(why))
    end
    local milestone_found, why = roadmap.resolve(found, {})
    assert(milestone_found == nil and why == "unknown", "an empty key must be unknown")
  end,

  a_reference_to_a_duplicated_number_is_ambiguous = function()
    local dir = root()
    local rdir = roadmap_dir(dir, "platform")
    artifact(rdir, "roadmap.md", "approved")
    artifact(rdir, "01-auth.md", "approved")
    artifact(rdir, "01-billing.md", "approved")
    local milestone_found, why = roadmap.resolve(scan(dir), "platform/01")
    assert(milestone_found == nil and why == "ambiguous", tostring(why))
  end,

  a_missing_roadmap_file_is_invalid = function()
    local dir = root()
    roadmap_dir(dir, "platform")
    expect("INVALID (roadmap.md: missing)", "fix platform", roadmap.roadmap_row(scan(dir)[1]))
  end,

  an_unparseable_roadmap_file_is_invalid = function()
    local dir = root()
    fs.write(path.join(roadmap_dir(dir, "platform"), "roadmap.md"), "# Roadmap: no frontmatter\n")
    expect("INVALID (roadmap.md: missing frontmatter)", "fix platform", roadmap.roadmap_row(scan(dir)[1]))
  end,

  an_unknown_roadmap_status_is_invalid = function()
    local dir = root()
    artifact(roadmap_dir(dir, "platform"), "roadmap.md", "executing")
    expect("INVALID (roadmap.md: unknown status executing)", "fix platform", roadmap.roadmap_row(scan(dir)[1]))
  end,

  a_roadmap_named_plans_is_invalid = function()
    local dir = root()
    artifact(roadmap_dir(dir, "plans"), "roadmap.md", "approved")
    expect("INVALID (reserved name)", "fix plans", roadmap.roadmap_row(scan(dir)[1]))
  end,

  an_unparseable_milestone_is_invalid = function()
    local dir = root()
    local rdir = roadmap_dir(dir, "platform")
    artifact(rdir, "roadmap.md", "approved")
    fs.write(path.join(rdir, "01-auth.md"), "---\ncreated: 2026-08-24\n---\n")
    expect("INVALID (01-auth.md: missing status)", "fix platform/01", roadmap.milestone_row(scan(dir)[1].milestones[1]))
  end,

  an_unknown_milestone_status_is_invalid = function()
    local dir = root()
    local rdir = roadmap_dir(dir, "platform")
    artifact(rdir, "roadmap.md", "approved")
    artifact(rdir, "01-auth.md", "superseded")
    expect("INVALID (01-auth.md: unknown status superseded)", "fix platform/01", roadmap.milestone_row(scan(dir)[1].milestones[1]))
  end,

  two_files_sharing_a_number_are_both_invalid = function()
    local dir = root()
    local rdir = roadmap_dir(dir, "platform")
    artifact(rdir, "roadmap.md", "approved")
    artifact(rdir, "01-auth.md", "approved")
    artifact(rdir, "01-billing.md", "approved")
    local milestones = scan(dir)[1].milestones
    expect("INVALID (01-auth.md: duplicate number 01)", "fix platform/01", roadmap.milestone_row(milestones[1]))
    expect("INVALID (01-billing.md: duplicate number 01)", "fix platform/01", roadmap.milestone_row(milestones[2]))
  end,

  an_unparseable_duplicate_shows_its_unparseable_reason = function()
    local dir = root()
    local rdir = roadmap_dir(dir, "platform")
    artifact(rdir, "roadmap.md", "approved")
    fs.write(path.join(rdir, "01-auth.md"), "---\ncreated: 2026-08-24\n---\n")
    artifact(rdir, "01-billing.md", "approved")
    local milestones = scan(dir)[1].milestones
    expect("INVALID (01-auth.md: missing status)", "fix platform/01", roadmap.milestone_row(milestones[1]))
    expect("INVALID (01-billing.md: duplicate number 01)", "fix platform/01", roadmap.milestone_row(milestones[2]))
  end,

  two_done_milestones_sharing_a_number_do_not_complete_their_roadmap = function()
    local dir = root()
    local rdir = roadmap_dir(dir, "platform")
    artifact(rdir, "roadmap.md", "approved")
    artifact(rdir, "01-auth.md", "done")
    artifact(rdir, "01-billing.md", "done")
    expect("approved, 0 of 2 milestones done", "", roadmap.roadmap_row(scan(dir)[1]))
  end,

  a_directory_named_like_a_milestone_file_is_ignored = function()
    local dir = root()
    local rdir = roadmap_dir(dir, "platform")
    artifact(rdir, "roadmap.md", "approved")
    fs.mkdir(path.join(rdir, "02-x.md"))
    local found = scan(dir)
    assert(#found[1].milestones == 0, "want no milestone, got " .. #found[1].milestones)
  end,

  progress_counts_done_members_out_of_those_not_dropped = function()
    local done, total = roadmap.progress(milestone("approved", { "done", "dropped", "draft", "approved" }))
    assert(done == 1 and total == 3, done .. " of " .. total)
  end,

  a_draft_milestone_asks_for_approval = function()
    expect("draft, 0 of 2 done", "approve or drop", roadmap.milestone_row(milestone("draft", { "draft", "draft" })))
  end,

  an_approved_milestone_with_no_scope_asks_for_scope = function()
    expect("approved, 0 of 0 done", "park scope", roadmap.milestone_row(milestone("approved")))
    expect("approved, 0 of 0 done", "park scope", roadmap.milestone_row(milestone("approved", { "dropped" })))
  end,

  an_approved_milestone_whose_work_is_finished_is_complete = function()
    expect("milestone complete", "roll up", roadmap.milestone_row(milestone("approved", { "done", "dropped", "done" })))
  end,

  an_approved_milestone_with_unstarted_work_is_not_complete = function()
    expect("approved, 1 of 3 done", "", roadmap.milestone_row(milestone("approved", { "done", "draft", "approved" })))
  end,

  a_done_milestone_shows_its_count = function()
    expect("done, 2 of 2 done", "", roadmap.milestone_row(milestone("done", { "done", "done", "dropped" })))
  end,

  a_done_milestone_with_an_open_chain_is_invalid = function()
    expect("INVALID (done with open chains)", "fix platform/01", roadmap.milestone_row(milestone("done", { "done", "approved" })))
  end,

  a_dropped_milestone_shows_only_its_status = function()
    expect("dropped", "", roadmap.milestone_row(milestone("dropped", { "draft" })))
  end,

  a_draft_roadmap_asks_for_approval = function()
    expect("draft, 0 of 2 milestones done", "approve or drop", roadmap.roadmap_row(roadmap_of("draft", { "draft", "draft" })))
  end,

  an_approved_roadmap_with_no_milestone_asks_for_one = function()
    expect("approved, 0 of 0 milestones done", "add milestone", roadmap.roadmap_row(roadmap_of("approved")))
    expect("approved, 0 of 0 milestones done", "add milestone", roadmap.roadmap_row(roadmap_of("approved", { "dropped" })))
  end,

  an_approved_roadmap_whose_milestones_are_finished_is_complete = function()
    expect("roadmap complete", "roll up", roadmap.roadmap_row(roadmap_of("approved", { "done", "dropped" })))
  end,

  an_approved_roadmap_with_an_open_milestone_shows_its_count = function()
    expect("approved, 1 of 2 milestones done", "", roadmap.roadmap_row(roadmap_of("approved", { "done", "approved" })))
  end,

  an_invalid_milestone_keeps_its_roadmap_open = function()
    expect("approved, 1 of 2 milestones done", "", roadmap.roadmap_row(roadmap_of("approved", { "done", false })))
  end,

  a_done_roadmap_shows_its_count = function()
    expect("done, 1 of 1 milestones done", "", roadmap.roadmap_row(roadmap_of("done", { "done", "dropped" })))
  end,

  a_done_roadmap_with_an_open_milestone_is_invalid = function()
    expect("INVALID (done with open milestones)", "fix platform", roadmap.roadmap_row(roadmap_of("done", { "done", "draft" })))
  end,

  a_dropped_roadmap_shows_only_its_status = function()
    expect("dropped", "", roadmap.roadmap_row(roadmap_of("dropped", { "approved" })))
  end,

  every_milestone_prints_under_an_open_roadmap = function()
    for _, parent in ipairs({ "draft", "approved" }) do
      local item = roadmap_of(parent, { "done", "dropped", "draft" })
      for _, ms in ipairs(item.milestones) do
        assert(roadmap.prints(ms), parent .. " roadmap must print a " .. ms.status .. " milestone")
      end
    end
  end,

  a_closed_roadmap_prints_only_milestones_that_are_still_open = function()
    for _, parent in ipairs({ "done", "dropped" }) do
      local item = roadmap_of(parent, { "done", "dropped", "draft", "approved", "done", false })
      item.milestones[5].members = { { status = "approved", open = true } }
      local printed = {}
      for i, ms in ipairs(item.milestones) do
        printed[i] = roadmap.prints(ms)
      end
      assert(not printed[1], parent .. ": a done milestone with no open chain must not print")
      assert(not printed[2], parent .. ": a dropped milestone with no open chain must not print")
      assert(printed[3] and printed[4], parent .. ": draft and approved milestones must print")
      assert(printed[5], parent .. ": a done milestone with an open chain must print")
      assert(printed[6], parent .. ": an invalid milestone must print")
    end
  end,
}
