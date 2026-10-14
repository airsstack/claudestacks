---
status: done
created: 2026-10-14
depends-on: [02]
built-on: a5a235079e03
---

# Roadmaps And Milestones On The Board Implementation Plan

**Goal:** The status board shows each roadmap, each milestone's progress counted from its
member chains, the chains grouped under their milestone, and every broken membership.

**Architecture:** A new module, `scripts/lib/roadmap.lua`, scans `roadmaps/`, resolves an
intent's `milestone` value, counts progress, and derives the STATE and NEXT of roadmap and
milestone rows. It does not require `lib/status`; the frontmatter reader is passed in, so
`lib/status` can require it without a cycle. `lib/status` gains `M.board`, which returns the
board as rows of data, and `M.render` becomes a formatter over it; plan 06 reuses `M.board`
for the session-start text. `M.derive` takes the scanned roadmaps so a broken `milestone`
value ranks among the invalid results. Nothing is stored: progress is counted on every render.
The rules are written into `references/artifact-chain.md` and the two body shapes into
`references/templates.md`.

**Tech Stack:** Lua 5.4 under `airsl` 0.1.2 (`airsstack.fs`, `airsstack.path`), Markdown.

**Content authority:** spec §4 (layout, frontmatter, body shapes, states, transitions), §5
(membership, progress), §6 (the roll-up procedure, as reference text), §7 (all of it), §10
first bullet, §11 (roadmaps and milestones tests), §12 (references).

---

## File structure

```
plugins/claudestacks-sdlc/scripts/lib/roadmap.lua        — [create] scan, resolve, progress, roadmap and milestone rows
plugins/claudestacks-sdlc/scripts/roadmap_test.lua       — [create] 31 tests for lib/roadmap
plugins/claudestacks-sdlc/scripts/lib/status.lua         — [modify] skip roadmaps/, M.board, M.row_lines, M.render, membership in M.derive
plugins/claudestacks-sdlc/scripts/status_test.lua        — [modify] 14 new tests and three fixture helpers
plugins/claudestacks-sdlc/references/artifact-chain.md   — [modify] layout, milestone key, states, board rules, roll-up
plugins/claudestacks-sdlc/references/templates.md        — [modify] roadmap and milestone body shapes, parked intent
```

Every path below is relative to the repository root. The gate for every task is
`cargo make plugins-test`, run from the repository root. No Rust changes, so the Rust
Definition of Done does not apply.

Baseline, with plans 01 and 02 done: `441 passed, 0 failed (21 files)` and
`fingerprint gate: 8 cases passed`.

**What a roadmap is on disk** (spec §4):

```
.claudestacks/sdlc/
├── roadmaps/                        # optional
│   └── <roadmap>/                   # one directory per roadmap
│       ├── roadmap.md               # status: draft | approved | done | dropped
│       ├── 01-<topic>.md            # one file per milestone, same four statuses
│       └── 02-<topic>.md
└── 2026-10-13-<topic>/              # chains stay flat at the chain root
    └── intent.md                    # may carry `milestone: <roadmap>/<NN>`
```

A milestone is referred to as `<roadmap>/<NN>`, for example `platform/01`. A chain's intent
names its milestone with the one key `milestone`; a chain with no such key is a simple chain.

**Where this plan departs from the spec.** Both are reported to the author at the plan's
approval gate, and neither is settled until the author accepts it:

- **"Open chain" is widened.** Spec §7.1 defines it: "one whose intent is `draft` or
  `approved`". This plan counts a chain as open whenever it has a row — whenever it is not
  collapsed into the `DONE/DROPPED` tail — so a chain that is `INVALID` because its
  `intent.md` is missing, unparseable or of unknown status is open too. Under the spec's
  wording such a chain is not open and so has no stated place in the grouped layout, where
  `UNASSIGNED` lists "every open simple chain, and every chain made invalid by its
  `milestone` value". The widened term gives it one, and plan 06's first line counts it.
- **The build order is relaxed.** Spec §12 builds the sync skill changes (§8.3–8.6) before
  roadmaps and milestones. This plan depends on plan 02 only and may run beside plan 03, as
  the author agreed when approving the plan set. The two touch disjoint files: plan 03 edits
  five `SKILL.md` files, this plan edits Lua and the two references.

**Decisions this plan makes where the spec is silent.** Each is reported to the author at the
plan's approval gate:

- A root holding a roadmap and no chain renders the board, not the "No chains" hint.
- Under a roadmap whose `roadmap.md` is invalid, every milestone row prints.
- A chain whose `milestone` value resolves is listed under that milestone whatever its own
  state; only a chain whose value does not resolve is listed under `UNASSIGNED`.
- When a milestone file is both unparseable and shares its number, the unparseable reason is
  shown.

**Guard tests.** Two new tests pass before the code beside them is written. As in plan 02,
each has a step that breaks the code on purpose and watches the test fail; both breaks were
run against a prototype on 2026-10-14 and turned their guard red.

### Task 1 — Scan `roadmaps/` and resolve a milestone reference

**Files:**
- Create `plugins/claudestacks-sdlc/scripts/roadmap_test.lua`
- Create `plugins/claudestacks-sdlc/scripts/lib/roadmap.lua`

**Steps:**

1. Write `plugins/claudestacks-sdlc/scripts/roadmap_test.lua` with its helpers and six tests:

   ```lua
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
   }
   ```

   The `milestone` and `roadmap_of` helpers and `expect` are used from Task 2 on.

2. Run and confirm failure:

   ```
   $ cargo make plugins-test
   ```

   Expected: `441 passed, 1 failed (22 files)`, the failure being the test file not loading:
   ``module `lib.roadmap` not found under `<repo>/plugins/claudestacks-sdlc/scripts` ``,
   where `<repo>` is the repository's absolute path.

3. Write `plugins/claudestacks-sdlc/scripts/lib/roadmap.lua`:

   ```lua
   -- Roadmaps and milestones for the claudestacks-sdlc status board: scans
   -- `roadmaps/`, resolves a chain's `milestone` key, counts progress, and
   -- derives each roadmap's and milestone's STATE and NEXT.
   --
   -- Code side of the rules whose prose mirror is the "Roadmaps and
   -- milestones" section of `references/artifact-chain.md`; the two MUST agree.
   -- Nothing here is stored: progress is counted from the member chains each
   -- time the board is rendered.

   local fs = airsstack.fs
   local path = airsstack.path

   local M = {}

   -- Directory under the chain root that holds every roadmap.
   M.DIR = "roadmaps"

   -- Roadmap names that are refused: `roadmaps/plans/NN-<topic>.md` would match
   -- the glob the distill skill reads plans through.
   local RESERVED = { plans = true }

   -- Legal roadmap and milestone states; anything else is refused, not guessed.
   local STATUSES = { draft = true, approved = true, done = true, dropped = true }

   -- Reads one roadmap directory into { name, status, invalid, milestones }.
   -- Each milestone is { num, file, stem, ref, roadmap, status, invalid,
   -- members }, where `ref` is `<roadmap>/<NN>`, `roadmap` is the parent table
   -- and `members` is filled by the board. `read_artifact` is lib/status's
   -- frontmatter reader, passed in so this module does not require lib/status.
   function M.read_roadmap(dir, name, read_artifact)
     local roadmap = { name = name, milestones = {} }

     local file = path.join(dir, "roadmap.md")
     if RESERVED[name] then
       roadmap.invalid = "reserved name"
     elseif not fs.exists(file) then
       roadmap.invalid = "roadmap.md: missing"
     else
       local fields, reason = read_artifact(file)
       if not fields then
         roadmap.invalid = "roadmap.md: " .. reason
       elseif not STATUSES[fields.status] then
         roadmap.invalid = "roadmap.md: unknown status " .. tostring(fields.status)
       else
         roadmap.status = fields.status
       end
     end

     -- Every entry that is not `NN-<topic>.md` is ignored, roadmap.md included.
     local count = {}
     for _, fname in ipairs(fs.list(dir)) do
       local num = fname:match("^(%d%d)%-.+%.md$")
       if num then
         local milestone = {
           num = num,
           file = fname,
           stem = fname:sub(1, -4),
           ref = name .. "/" .. num,
           roadmap = roadmap,
           members = {},
         }
         local fields, reason = read_artifact(path.join(dir, fname))
         if not fields then
           milestone.invalid = fname .. ": " .. reason
         elseif not STATUSES[fields.status] then
           milestone.invalid = fname .. ": unknown status " .. tostring(fields.status)
         else
           milestone.status = fields.status
         end
         roadmap.milestones[#roadmap.milestones + 1] = milestone
         count[num] = (count[num] or 0) + 1
       end
     end
     for _, milestone in ipairs(roadmap.milestones) do
       if count[milestone.num] > 1 and not milestone.invalid then
         milestone.invalid = milestone.file .. ": duplicate number " .. milestone.num
         milestone.status = nil
       end
     end

     return roadmap
   end

   -- All roadmaps under the chain root, in fs.list order. Empty when the
   -- `roadmaps/` directory is absent, which is the common case.
   function M.scan(rootdir, read_artifact)
     local roadmaps = {}
     local base = path.join(rootdir, M.DIR)
     if not (fs.exists(base) and fs.is_dir(base)) then
       return roadmaps
     end
     for _, name in ipairs(fs.list(base)) do
       local dir = path.join(base, name)
       if fs.is_dir(dir) then
         roadmaps[#roadmaps + 1] = M.read_roadmap(dir, name, read_artifact)
       end
     end
     return roadmaps
   end

   -- Resolves an intent's `milestone` value against the scanned roadmaps.
   -- Returns the milestone, or nil and "unknown" (not `<roadmap>/<NN>`, or no
   -- milestone file has that roadmap and number) or "ambiguous" (two files
   -- share the number).
   function M.resolve(roadmaps, value)
     if type(value) ~= "string" then
       return nil, "unknown"
     end
     local name, num = value:match("^([^/]+)/(%d%d)$")
     if not name then
       return nil, "unknown"
     end
     local found, count = nil, 0
     for _, roadmap in ipairs(roadmaps) do
       if roadmap.name == name then
         for _, milestone in ipairs(roadmap.milestones) do
           if milestone.num == num then
             found = found or milestone
             count = count + 1
           end
         end
       end
     end
     if count == 0 then
       return nil, "unknown"
     end
     if count > 1 then
       return nil, "ambiguous"
     end
     return found
   end

   return M
   ```

   `read_artifact` is `lib/status`'s `M.read_artifact`, which after plan 02 returns the fields
   and the file's text on success, or `nil` and a reason on failure. Only the first result is
   used on success here.

4. Run and confirm green:

   ```
   $ cargo make plugins-test
   447 passed, 0 failed (22 files)
   ```

5. Commit `feat(repo): scan sdlc roadmaps and resolve milestone references`.

### Task 2 — Derive roadmap and milestone rows

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/roadmap_test.lua`
- Modify `plugins/claudestacks-sdlc/scripts/lib/roadmap.lua`

**Steps:**

1. Add twenty-five tests at the end of the returned table in `roadmap_test.lua`, after
   `a_reference_to_a_duplicated_number_is_ambiguous`:

   ```lua
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
   ```

2. Run and confirm failure:

   ```
   $ cargo make plugins-test
   ```

   Expected: `447 passed, 25 failed (22 files)`. All twenty-five fail on a call to a function
   that does not exist yet (`roadmap_row`, `milestone_row`, `progress` or `prints`).

3. In `plugins/claudestacks-sdlc/scripts/lib/roadmap.lua`, insert the following between the
   end of `M.resolve` and the final `return M`:

   ```lua
   -- A milestone's progress: how many members are `done`, out of the members
   -- that are not `dropped`. Each member is { status, open }.
   function M.progress(milestone)
     local done, total = 0, 0
     for _, member in ipairs(milestone.members) do
       if member.status ~= "dropped" then
         total = total + 1
         if member.status == "done" then
           done = done + 1
         end
       end
     end
     return done, total
   end

   -- True when a milestone has a member chain that is still a board row.
   function M.has_open_member(milestone)
     for _, member in ipairs(milestone.members) do
       if member.open then
         return true
       end
     end
     return false
   end

   -- STATE and NEXT for one milestone row.
   function M.milestone_row(milestone)
     if milestone.invalid then
       return "INVALID (" .. milestone.invalid .. ")", "fix " .. milestone.ref
     end
     local done, total = M.progress(milestone)
     local count = string.format("%d of %d done", done, total)
     local status = milestone.status
     if status == "dropped" then
       return "dropped", ""
     end
     if status == "draft" then
       return "draft, " .. count, "approve or drop"
     end
     if status == "done" then
       if done < total then
         return "INVALID (done with open chains)", "fix " .. milestone.ref
       end
       return "done, " .. count, ""
     end
     -- approved
     if total == 0 then
       return "approved, " .. count, "park scope"
     end
     if done == total then
       return "milestone complete", "roll up"
     end
     return "approved, " .. count, ""
   end

   -- A roadmap's progress: how many milestones are `done`, out of the
   -- milestones that are not `dropped`. An invalid milestone has no status, so
   -- it counts as neither and keeps the roadmap open.
   function M.roadmap_progress(roadmap)
     local done, total = 0, 0
     for _, milestone in ipairs(roadmap.milestones) do
       if milestone.status ~= "dropped" then
         total = total + 1
         if milestone.status == "done" then
           done = done + 1
         end
       end
     end
     return done, total
   end

   -- STATE and NEXT for one roadmap row.
   function M.roadmap_row(roadmap)
     if roadmap.invalid then
       return "INVALID (" .. roadmap.invalid .. ")", "fix " .. roadmap.name
     end
     local done, total = M.roadmap_progress(roadmap)
     local count = string.format("%d of %d milestones done", done, total)
     local status = roadmap.status
     if status == "dropped" then
       return "dropped", ""
     end
     if status == "draft" then
       return "draft, " .. count, "approve or drop"
     end
     if status == "done" then
       if done < total then
         return "INVALID (done with open milestones)", "fix " .. roadmap.name
       end
       return "done, " .. count, ""
     end
     -- approved
     if total == 0 then
       return "approved, " .. count, "add milestone"
     end
     if done == total then
       return "roadmap complete", "roll up"
     end
     return "approved, " .. count, ""
   end

   -- Whether a milestone gets a board row. Under a `done` or `dropped` roadmap
   -- a milestone that is itself `done` or `dropped` is printed only while it
   -- still has an open member chain, so every open member has a row above it.
   function M.prints(milestone)
     local parent = milestone.roadmap.status
     if parent ~= "done" and parent ~= "dropped" then
       return true
     end
     if milestone.status ~= "done" and milestone.status ~= "dropped" then
       return true
     end
     return M.has_open_member(milestone)
   end

   ```

   "Every member `done` or `dropped`, with at least one `done`" is `done == total` with
   `total > 0`: `total` counts the members that are not dropped, so `total > 0` and
   `done == total` together mean nothing is unfinished and something was delivered.

4. Run and confirm green:

   ```
   $ cargo make plugins-test
   472 passed, 0 failed (22 files)
   ```

5. Commit `feat(repo): derive sdlc roadmap and milestone rows`.

### Task 3 — Group the board under roadmaps and milestones

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`
- Modify `plugins/claudestacks-sdlc/scripts/lib/status.lua`

**Steps:**

1. Add three helpers to `status_test.lua`, directly after the `chain_root` function written in
   plan 02 and before `return {`:

   ```lua
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
   ```

2. Add ten tests at the end of the returned table:

   ```lua
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
   ```

3. Run and confirm failure:

   ```
   $ cargo make plugins-test
   ```

   Expected: `473 passed, 9 failed (22 files)`. Nine of the ten fail; the first of them fails
   with `roadmaps must not scan as a chain`. One passes already and stays as a guard:
   `unassigned_is_omitted_when_every_open_chain_is_a_member`.

4. In `plugins/claudestacks-sdlc/scripts/lib/status.lua`, require the module and skip its
   directory. Replace the lines written in plan 02 and the skip list below them:

   ```lua
   local fingerprint = require("lib.fingerprint")

   local fs = airsstack.fs
   local path = airsstack.path

   local M = {}

   -- Chain root, relative to the consuming repository's root.
   M.ROOT = ".claudestacks/sdlc"

   -- Top-level entries that are not chains.
   local SKIP = { prds = true, rfcs = true }
   ```

   with:

   ```lua
   local fingerprint = require("lib.fingerprint")
   local roadmap = require("lib.roadmap")

   local fs = airsstack.fs
   local path = airsstack.path

   local M = {}

   -- Chain root, relative to the consuming repository's root.
   M.ROOT = ".claudestacks/sdlc"

   -- Top-level entries that are not chains.
   local SKIP = { prds = true, rfcs = true, [roadmap.DIR] = true }
   ```

5. Replace the whole of `M.render` — from its comment `-- The full board for one chain root.`
   to its closing `end`, the last function before `return M` — with:

   ```lua
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
   ```

   `M.board` passes the roadmaps to `M.derive`, which ignores a second argument until Task 4
   gives it one. Progress is filled into `milestone.members` in the first loop, before the
   second loop reads it. A milestone's members arrive in directory-listing order because the
   chains are scanned in that order.

6. Run and confirm green:

   ```
   $ cargo make plugins-test
   482 passed, 0 failed (22 files)
   ```

7. See the guard fail. In `M.board`, temporarily change `if #unassigned > 0 then` to
   `if true then`, and run `cargo make plugins-test`.

   Expected: `unassigned_is_omitted_when_every_open_chain_is_a_member` is among the failures
   (other layout tests fail alongside). Restore the line and confirm
   `482 passed, 0 failed (22 files)` again.

8. Commit `feat(repo): group the sdlc board under roadmaps and milestones`.

### Task 4 — Report a broken `milestone` value

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`
- Modify `plugins/claudestacks-sdlc/scripts/lib/status.lua`

**Steps:**

1. Add four tests at the end of the returned table in `status_test.lua`:

   ```lua
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
   ```

2. Run and confirm failure:

   ```
   $ cargo make plugins-test
   ```

   Expected: `483 passed, 3 failed (22 files)`. One passes already and stays as a guard:
   `a_closed_chain_with_a_broken_milestone_key_is_not_checked`.

3. In `plugins/claudestacks-sdlc/scripts/lib/status.lua`, replace the opening of `M.derive`
   as plan 02 left it:

   ```lua
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
   ```

   with:

   ```lua
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
   -- `references/artifact-chain.md` §9 and §10. States and fingerprints only,
   -- no judgment. `roadmaps` is lib/roadmap's scan; absent means none exist.
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
   ```

4. Rank it after an unknown plan status and before the sync rules. Replace the lines plan 02
   wrote:

   ```lua
         "fix " .. chain.name
       end
     end

     local sync = M.sync(chain)
   ```

   with:

   ```lua
         "fix " .. chain.name
       end
     end

     -- A broken membership ranks after the results above and before I2-I5.
     local problem = membership_problem(intent, roadmaps)
     if problem then
       return "INVALID (" .. problem .. ")", "fix " .. chain.name
     end

     local sync = M.sync(chain)
   ```

5. Run and confirm green:

   ```
   $ cargo make plugins-test
   486 passed, 0 failed (22 files)
   ```

6. See the guard fail. In `M.derive`, temporarily change
   `if intent.status == "dropped" or intent.status == "done" then` to
   `if intent.status == "dropped" then`, and run `cargo make plugins-test`.

   Expected: `a_closed_chain_with_a_broken_milestone_key_is_not_checked` is among the
   failures (other tests fail alongside). Restore the line and confirm
   `486 passed, 0 failed (22 files)` again.

7. Commit `feat(repo): report a broken sdlc milestone reference on the board`.

### Task 5 — Write roadmaps and milestones into the references

There is no test for prose; each step's check is a `grep` for text that is absent before the
edit and present after it.

**Files:**
- Modify `plugins/claudestacks-sdlc/references/artifact-chain.md`
- Modify `plugins/claudestacks-sdlc/references/templates.md`

**Steps:**

1. Confirm the new text is absent:

   ```
   $ grep -c 'milestone' plugins/claudestacks-sdlc/references/artifact-chain.md plugins/claudestacks-sdlc/references/templates.md
   plugins/claudestacks-sdlc/references/artifact-chain.md:0
   plugins/claudestacks-sdlc/references/templates.md:0
   ```

2. In `references/artifact-chain.md` §3, replace the layout block and the bullets below it
   (`artifact-chain.md:27-46` before plan 02):

   ````markdown
   ```
   .claudestacks/sdlc/                        # committed; provisioned by the setup skill
   ├── prds/                                  # optional product input docs (inbox)
   │   └── .gitkeep
   ├── rfcs/                                  # optional technical input docs (inbox)
   │   └── .gitkeep
   ├── REVIEW.md                              # review policy, from template
   └── 2026-08-24-webhook-reliability/        # one chain = one intent
       ├── intent.md
       ├── spec.md                            # absent until design runs; may be skipped
       └── plans/
           ├── 01-retry-core.md               # NN- prefix orders plans within a chain
           └── 02-dlq.md
   ```

   - `prds/` and `rfcs/` are top-level inboxes, siblings of the chain directories, not
     nested inside any chain.
   - `REVIEW.md` lives directly under `.claudestacks/sdlc/`, one copy per repository.
   - Within a chain directory: `intent.md` and `spec.md` are singular files; `plans/`
     holds one file per plan.
   ````

   with:

   ````markdown
   ```
   .claudestacks/sdlc/                        # committed; provisioned by the setup skill
   ├── prds/                                  # optional product input docs (inbox)
   │   └── .gitkeep
   ├── rfcs/                                  # optional technical input docs (inbox)
   │   └── .gitkeep
   ├── roadmaps/                              # optional; created on first use by the roadmap skill
   │   └── platform/                          # one directory per roadmap; the engineer names it
   │       ├── roadmap.md
   │       ├── 01-auth.md                     # one file per milestone; NN orders them
   │       └── 02-billing.md
   ├── REVIEW.md                              # review policy, from template
   └── 2026-08-24-webhook-reliability/        # one chain = one intent
       ├── intent.md
       ├── spec.md                            # absent until design runs; may be skipped
       └── plans/
           ├── 01-retry-core.md               # NN- prefix orders plans within a chain
           └── 02-dlq.md
   ```

   - `prds/` and `rfcs/` are top-level inboxes, siblings of the chain directories, not
     nested inside any chain.
   - `roadmaps/` is optional and is never created by `setup`. Chains stay flat at the
     chain root whether or not they belong to a milestone (§11).
   - `REVIEW.md` lives directly under `.claudestacks/sdlc/`, one copy per repository.
   - Within a chain directory: `intent.md` and `spec.md` are singular files; `plans/`
     holds one file per plan.
   ````

3. In §6, as plan 02 left it, replace the sentence `YAML frontmatter. The full schema, all
   nine keys:` with `YAML frontmatter. The full schema, all ten keys:`; add this line to the
   YAML block directly after the `spec: skipped` line:

   ```yaml
   milestone: platform/01        # optional, intent only; §11
   ```

   and add this row to the table directly after the `spec` row:

   ```markdown
   | `milestone` | string (`<roadmap>/<NN>`) | optional; intent only (§11); absent means a simple chain |
   ```

   Then add one sentence after the paragraph that ends "when nothing seeded the artifact.":

   ```markdown
   A roadmap file and a milestone file carry `status` and `created` and no other key
   (§11).
   ```

4. In §7.1, add two rows to the states table after the `plan` row:

   ```markdown
   | roadmap | `draft → approved → done`; `dropped` from `draft` or `approved`; `dropped → draft` |
   | milestone | `draft → approved → done`; `dropped` from `draft` or `approved`; `dropped → draft` |
   ```

   In §7.2, add ten rows to the transitions table after the `plan → superseded` row:

   ```markdown
   | roadmap `— → draft` | file written | `roadmap` |
   | roadmap `draft → approved` | the author approves it | `roadmap` |
   | roadmap `approved → done` | roll-up (§12) | the skill running the roll-up |
   | roadmap `→ dropped` | the author's instruction | `roadmap` |
   | roadmap `dropped → draft` | the author un-drops it | `roadmap` |
   | milestone `— → draft` | file written | `roadmap` (first milestones) or `milestone` |
   | milestone `draft → approved` | the author approves it | `milestone` |
   | milestone `approved → done` | roll-up (§12) | the skill running the roll-up |
   | milestone `→ dropped` | the author's instruction | `milestone` |
   | milestone `dropped → draft` | the author un-drops it | `milestone` |
   ```

5. In §7.4, replace the last sentence (`artifact-chain.md:157-159` before plan 02):

   ```markdown
   artifact's life. The only transitions that fire without a fresh approval question are
   the mechanical pair: plan `approved → executing` and the intent's `done` roll-up —
   both are consequences of state already earned elsewhere, not new decisions.
   ```

   with:

   ```markdown
   artifact's life. The only transitions that fire without a fresh approval question are
   the mechanical ones: plan `approved → executing`, the intent's `done` walk-up, and the
   milestone's and roadmap's `done` roll-up (§12) — all are consequences of state already
   earned elsewhere, not new decisions.

   Two things differ for roadmaps and milestones. Un-dropping one always returns it to
   `draft`, and the author approves it again. And `done` is final: a closed milestone or
   roadmap is not reopened, amended or dropped; work that arrives after one closed becomes
   a simple chain or belongs to a new milestone. Amending a roadmap's or milestone's body
   leaves its status as it was.
   ```

6. In §9, as plan 02 left it, replace:

   ```markdown
   every directory is a chain except `prds/` and `rfcs/`, and a plain file is not a row.
   ```

   with:

   ```markdown
   every directory is a chain except `prds/`, `rfcs/` and `roadmaps/`, and a plain file is
   not a row. Roadmaps, milestones and the grouped layout are in §11.
   ```

7. Insert two new sections after §10, before the `---` line that precedes "This file owns
   paths, naming…":

   ````markdown
   ## 11. Roadmaps and milestones

   Both are optional. A repository with no `roadmaps/` directory and no intent carrying a
   `milestone` key has no roadmap or milestone behaviour of any kind.

   ### 11.1 Files

   - A roadmap is the directory `roadmaps/<roadmap>/` holding `roadmap.md`. A milestone is
     a file `NN-<topic>.md` beside it. `<roadmap>` and `<topic>` are kebab-case. A
     repository may hold any number of roadmaps.
   - A roadmap may not be named `plans`: `roadmaps/plans/NN-<topic>.md` would match the
     glob `distill` reads plans through.
   - A milestone is identified by the reference `<roadmap>/<NN>`, for example
     `platform/01`. A number is never reused within a roadmap; a new milestone takes the
     next free `NN`, as plans do (§4).
   - Nothing in `roadmaps/` is ever deleted or renamed; a milestone that is no longer
     wanted is `dropped`.
   - Within a roadmap directory, any entry other than `roadmap.md` and files matching
     `NN-<topic>.md` is ignored. A plain file directly under `roadmaps/` is ignored.
   - Neither body holds a list of milestones, a list of chains, a progress figure or a
     checklist of finished work. A roadmap's milestones are the files beside it; a
     milestone's chains are the intents that name it.
   - A milestone's or roadmap's status does not gate chain work: a member chain moves
     through `design`, `plan` and `execute` whatever its milestone's status.

   ### 11.2 Membership and progress

   The only link is the optional intent key `milestone: <roadmap>/<NN>` (§6). A chain
   belongs to at most one milestone; a chain with no `milestone` key is a **simple
   chain**. A chain's directory never moves. No skill infers membership from a topic or a
   name: `intent` writes the key only when the author names a milestone, and `milestone`
   writes it when parking scope or adopting a chain and removes it when releasing one.

   Progress is counted every time the board is rendered and is never written down.

   - A milestone's **members** are every chain whose intent names it. Its progress is
     `N of M done`: `M` is the members whose intent is not `dropped`, `N` the members
     whose intent is `done`.
   - A roadmap's progress is `N of M milestones done`: `M` is its milestone files whose
     status is not `dropped`, `N` those whose status is `done`.
   - Work planned for a milestone and not yet begun is a parked `draft` intent, so it is
     in `M` from the moment it is parked.

   ### 11.3 Board layout

   An **open chain** is one that has a row: every chain not collapsed into the
   `DONE/DROPPED` tail. That is every chain whose intent is `draft` or `approved`, and
   every chain that renders `INVALID`.

   With no roadmap directory under `roadmaps/`, the board keeps the flat layout of §9.
   With at least one, the same three columns are kept and the rows are grouped:

   ```
   CHAIN                             STATE                         NEXT
   ROADMAP platform                  approved, 1 of 2 milestones done
   MILESTONE platform/01-auth        done, 4 of 4 done
   MILESTONE platform/02-billing     approved, 1 of 3 done
     2026-10-13-invoices             plan 01 approved: stale (spec changed)  plan
     2026-10-14-refunds              intent draft                  approve or drop
   UNASSIGNED
     2026-10-15-fix-typo             intent approved               design
   DONE/DROPPED: 6 done, 2 dropped (not listed)
   ```

   - A roadmap row's first column is `ROADMAP <roadmap>`; a milestone row's is
     `MILESTONE <roadmap>/<file name without .md>`.
   - Roadmaps print in directory-listing order, each followed by its milestones in number
     order, each milestone followed by its open member chains in directory-listing order,
     indented two spaces.
   - Under a `draft` or `approved` roadmap, and under one whose `roadmap.md` is invalid,
     every milestone prints. Under a `done` or `dropped` roadmap, a milestone prints only
     when it is not `done` or `dropped` itself, or has an open member chain.
   - Members that are not open are counted in their milestone's progress and in the tail,
     and not listed.
   - `UNASSIGNED` heads every open chain that is not listed under a milestone: every
     simple chain and every chain whose `milestone` value does not resolve. The line is
     omitted when there is none.
   - Under a row, its `⤷ inputs:` line comes first, then any `⤷ milestone …` line; a
     milestone's `⤷ roadmap …` line follows its row. Each is indented two spaces past its
     row.
   - A root holding a roadmap and no chain renders the board, not the starter hint.

   ### 11.4 Milestone rows

   | Milestone status | Condition | STATE | NEXT |
   |---|---|---|---|
   | `draft` | — | `draft, N of M done` | `approve or drop` |
   | `approved` | `M` is 0 | `approved, 0 of 0 done` | `park scope` |
   | `approved` | every member `done` or `dropped`, at least one `done` | `milestone complete` | `roll up` |
   | `approved` | otherwise | `approved, N of M done` | empty |
   | `done` | every member `done` or `dropped` | `done, N of M done` | empty |
   | `done` | any member neither `done` nor `dropped` | `INVALID (done with open chains)` | `fix <roadmap>/<NN>` |
   | `dropped` | — | `dropped` | empty |
   | file unparseable, or any other status | — | `INVALID (<file>: <reason>)` | `fix <roadmap>/<NN>` |
   | two files in one roadmap share a number | each of them | `INVALID (<file>: duplicate number NN)` | `fix <roadmap>/<NN>` |

   ### 11.5 Roadmap rows

   | Roadmap status | Condition | STATE | NEXT |
   |---|---|---|---|
   | `draft` | — | `draft, N of M milestones done` | `approve or drop` |
   | `approved` | `M` is 0 (no milestone file, or all `dropped`) | `approved, 0 of 0 milestones done` | `add milestone` |
   | `approved` | every milestone `done` or `dropped`, at least one `done` | `roadmap complete` | `roll up` |
   | `approved` | otherwise | `approved, N of M milestones done` | empty |
   | `done` | every milestone `done` or `dropped` | `done, N of M milestones done` | empty |
   | `done` | any milestone neither `done` nor `dropped` | `INVALID (done with open milestones)` | `fix <roadmap>` |
   | `dropped` | — | `dropped` | empty |
   | `roadmap.md` missing or unparseable, or any other status | — | `INVALID (roadmap.md: <reason>)` | `fix <roadmap>` |
   | the directory is named `plans` | — | `INVALID (reserved name)` | `fix plans` |

   A milestone that is invalid has no status: it counts in `M` and never in `N`, so it
   keeps its roadmap open.

   ### 11.6 Membership problems

   These apply to every chain whose intent is `draft` or `approved`, in either layout.

   | Condition | Reported as |
   |---|---|
   | the `milestone` value is not of the form `<roadmap>/<NN>`, or no milestone file has that roadmap and number | the chain renders `INVALID (intent.md: unknown milestone <value>)` → `fix <chain>` |
   | the value matches two milestone files (duplicate number) | the chain renders `INVALID (intent.md: ambiguous milestone <value>)` → `fix <chain>` |
   | the chain names a `dropped` milestone | under the chain's row: `⤷ milestone <roadmap>/<NN> is dropped — release this chain` |
   | a `draft` or `approved` milestone sits under a `dropped` roadmap | under the milestone's row: `⤷ roadmap <roadmap> is dropped — drop this milestone` |

   The two invalid results rank after I1 and before I2 (§10.3). In a repository with no
   roadmap directory, a chain carrying a `milestone` key therefore renders the first row
   of this table in the flat layout.

   ## 12. Roll-up

   The roll-up closes milestones, and then their roadmap, when their work is finished. It
   takes a roadmap name, and it is idempotent: running it when nothing is ready changes
   nothing.

   1. For each milestone of the roadmap whose status is `approved`, in number order: if
      every member's intent is `done` or `dropped`, with at least one `done`, flip the
      milestone `approved → done` and tell the author it closed.
   2. If the roadmap's status is `approved`, and every milestone's status is `done` or
      `dropped`, with at least one `done`, flip the roadmap `approved → done` and tell the
      author it closed.

   It runs as the last step of any interaction that could have made either condition
   true, for the roadmap concerned:

   | Event | Skill |
   |---|---|
   | a member's intent flips to `done` (chain walk-up) | `execute` |
   | a member's intent is dropped | `intent` |
   | a chain is released; a milestone is approved or dropped | `milestone` |
   | a roadmap is approved | `roadmap` |
   | the author asks for it, or the board's NEXT reads `roll up` | `milestone`, operation `roll up`, given a roadmap name or a milestone reference |

   A roll-up that was missed is visible: the board reads `milestone complete` or
   `roadmap complete` with NEXT `roll up` (§11.4, §11.5).

   ````

8. In `references/templates.md`, add the key to the intent frontmatter shape. Replace
   (`templates.md:19-20`):

   ```markdown
   spec: skipped                    # optional — see artifact-chain §6
   ---
   ```

   with:

   ```markdown
   spec: skipped                    # optional — see artifact-chain §6
   milestone: <roadmap>/<NN>        # optional — see artifact-chain §11
   ---
   ```

9. In `references/templates.md`, replace the title line (`templates.md:1`):

   ```markdown
   # Artifact Templates — body shapes for intent, spec, and plan
   ```

   with:

   ```markdown
   # Artifact Templates — body shapes for intent, spec, plan, roadmap, and milestone
   ```

   and the paragraph below it (`templates.md:3-6`):

   ```markdown
   The body-shape authority for the `claudestacks-sdlc` skills. When `intent`, `design`,
   or `plan` writes a new artifact, it reproduces the shape shown here: frontmatter plus
   the body sections below it. Bracketed text is guidance for the writing skill, not
   content to leave in the file.
   ```

   with:

   ```markdown
   The body-shape authority for the `claudestacks-sdlc` skills. When `intent`, `design`,
   `plan`, `roadmap`, or `milestone` writes a new artifact, it reproduces the shape shown
   here: frontmatter plus the body sections below it. Bracketed text is guidance for the
   writing skill, not content to leave in the file.
   ```

   Then insert the following between the paragraph that ends "all three are appended by
   `execute`." (`templates.md:141-146`) and the `---` line above the closing paragraph. The
   block below is fenced with five backticks only so this plan can show the four-backtick
   fences inside it; copy what is between the five-backtick lines:

   `````markdown
   ## `roadmaps/<roadmap>/roadmap.md`

   ````markdown
   ---
   status: draft
   created: <YYYY-MM-DD>
   ---

   # Roadmap: <title>

   ## Vision

   [where this body of work is going and why]

   ## Non-goals

   [what this roadmap deliberately leaves out]
   ````

   ## `roadmaps/<roadmap>/NN-<topic>.md`

   ````markdown
   ---
   status: draft
   created: <YYYY-MM-DD>
   ---

   # Milestone: <title>

   ## Goal

   [the state of the world when this milestone is reached]

   ## Non-goals

   [what this milestone deliberately leaves out]
   ````

   Both carry `status` and `created` and no other frontmatter key. Neither body lists
   milestones, chains, progress or finished work: `artifact-chain.md` §11 says where
   those come from.

   ## A parked intent

   Work planned for a milestone and not yet begun is parked by the `milestone` skill as an
   ordinary `intent.md` with `status: draft` and the `milestone` key. `Problem` holds what
   the author said about that piece of work. `Affected systems`, `Desired outcome`,
   `Constraints` and `Non-goals` each hold exactly this sentence:

   ```
   Not explored yet — parked by milestone <roadmap>/<NN>.
   ```

   The author completes it later through the `intent` skill's amend mode.

   `````

   In `templates.md` the two shapes are each fenced with four backticks, as the existing
   shapes are (`templates.md:10`, `:44`), and the surrounding prose is unfenced.

10. Verify:

    ```
    $ grep -c 'milestone' plugins/claudestacks-sdlc/references/artifact-chain.md plugins/claudestacks-sdlc/references/templates.md
    ```

    Expected: a non-zero count for each file.

    ```
    $ grep -n '^## ' plugins/claudestacks-sdlc/references/artifact-chain.md
    ```

    Expected: sections `## 1.` to `## 12.` in order.

    ```
    $ grep -n 'all nine keys\|the mechanical pair' plugins/claudestacks-sdlc/references/artifact-chain.md
    ```

    Expected: no output.

11. Check each board string in §11 against the code that prints it:

    ```
    $ grep -n 'park scope\|add milestone\|roll up\|milestone complete\|roadmap complete\|done with open chains\|done with open milestones\|reserved name\|duplicate number\|UNASSIGNED\|release this chain\|drop this milestone\|unknown\|ambiguous' plugins/claudestacks-sdlc/scripts/lib/roadmap.lua plugins/claudestacks-sdlc/scripts/lib/status.lua
    ```

    Expected: at least one line for each of the fourteen alternatives.

12. Commit `docs(repo): write sdlc roadmaps and milestones into the references`.

### Task 6 — Read the new board on this repository

**Steps:**

1. Render the board for this repository:

   ```
   $ sh plugins/claudestacks-sdlc/scripts/status.sh
   ```

   Expected: the same flat layout as at the end of plan 02 — no `ROADMAP`, `MILESTONE` or
   `UNASSIGNED` line — because this repository has no `roadmaps/` directory. Compare it line
   for line with the board pasted into plan 02's `## Probe results`; the only differences
   allowed are plan statuses that have changed since.

2. Paste the board into this plan's `## Probe results`.

3. **Checkpoint — stop and report to the author:** the four code commits, the reference
   commit, and the board from step 1.

---

## Verification summary (plan-level)

- `cargo make plugins-check` exits 0 with `lib/roadmap.lua` and `roadmap_test.lua` compiled.
- `cargo make plugins-test` prints `486 passed, 0 failed (22 files)` and
  `fingerprint gate: 8 cases passed`.
- Every row of the milestone, roadmap and membership tables has a test, and each new test was
  seen failing or is named above as a guard that passed before the change.
- A repository with no `roadmaps/` directory renders exactly as it did after plan 02.
- `references/artifact-chain.md` holds §11 and §12, and every board string in §11 appears in
  the Lua.

## Review findings

One `claudestacks:reviewer` spawn over the whole diff, 2026-10-14. Verdict:
`SPEC: COMPLIANT-WITH-AMENDMENTS`, blocking set none. The reviewer re-ran `cargo make plugins`
(`71 file(s) compiled, 0 failed`, `493 passed, 0 failed (22 files)`,
`fingerprint gate: 8 cases passed`). It diffed Tasks 1–4 against the plan's code with an
empty result, and rendered this repository's chain root with HEAD's `lib/status.lua` and with
the new one; the two outputs were byte-identical. One fix round by a fresh coder followed,
and each mutation in it was run through `cargo make plugins-test` and then restored. The gate
after the round read `71 file(s) compiled, 0 failed`, `499 passed, 0 failed (22 files)`,
`fingerprint gate: 8 cases passed`.

- reversion guard — reverting `(type(value) == "string" and value or "")` to `value` failed
  nothing; an empty `milestone:` key would then crash the board — `scripts/lib/status.lua:293`
  — fixed: test `an_empty_milestone_key_is_an_unknown_milestone_and_the_board_still_renders`.
  Reverted: `498 passed, 1 failed`, with `status.lua:293: attempt to concatenate a table value (local 'value')`.
- reversion guard — deleting `milestone.status = nil` failed nothing; two `done` files sharing
  a number would complete their roadmap — `scripts/lib/roadmap.lua:77` — fixed: test
  `two_done_milestones_sharing_a_number_do_not_complete_their_roadmap`. Reverted:
  `498 passed, 1 failed`, `want approved, 0 of 2 milestones done / , got roadmap complete / roll up`.
- reversion guard — the decision "an unparseable duplicate shows its unparseable reason" had no
  test — `scripts/lib/roadmap.lua:75` — fixed: test
  `an_unparseable_duplicate_shows_its_unparseable_reason`. Reverted: `498 passed, 1 failed`,
  `want INVALID (01-auth.md: missing status) / fix platform/01, got INVALID (01-auth.md: duplicate number 01) / fix platform/01`.
- reversion guard — the `⤷ roadmap … drop this milestone` note's status clause was unguarded;
  reverted, it would tell the author to drop a `done` milestone — `scripts/lib/status.lua`
  (`M.board`) — fixed: test `a_done_milestone_under_a_dropped_roadmap_is_not_told_to_drop`.
  Reverted: `498 passed, 1 failed`.
- reversion guard — the `⤷ milestone … is dropped` note's status clause was unguarded —
  `scripts/lib/status.lua` (`M.board`) — fixed: test
  `a_chain_invalid_by_status_is_not_told_to_release_a_dropped_milestone`. Reverted:
  `498 passed, 1 failed`.
- correctness — a directory named like `02-x.md` was read as a milestone; spec §4 ignores
  anything but files — `scripts/lib/roadmap.lua:51-52` — fixed: `fs.is_file` check, test
  `a_directory_named_like_a_milestone_file_is_ignored`, red before the fix:
  `498 passed, 1 failed`, `want no milestone, got 1`.
- comment-matches-code — the header said "when the root holds a `roadmaps/` directory", but an
  empty `roadmaps/` renders flat — `scripts/lib/status.lua:3-4` — fixed.
- comment-matches-code — the derive comment cited §9 and §10 only — `scripts/lib/status.lua:297-298`
  — fixed: it also cites the membership rules of §11.
- rendering — an empty `milestone:` key renders `INVALID (intent.md: unknown milestone )` with a
  dangling space — `scripts/lib/status.lua:293` — not changed: the spec does not say whether an
  empty key is absent or unknown.
- rendering — labels longer than the 34-column CHAIN cell push STATE out of line, which the
  `MILESTONE <roadmap>/` prefix makes more common — `M.row_lines` — not changed: the behaviour
  predates this plan.
- parser — `milestone: "platform/01"` keeps its quotes and reads as an unknown milestone —
  `scripts/lib/roadmap.lua:109`, `parse_frontmatter` — not changed: the frontmatter parser's
  existing YAML subset.
- spec amendment — "open chain" is widened to every chain with a row, `INVALID` included; spec
  §7.1 still says `draft` or `approved`, and plan 06 counts the widened term — open for the
  author: amend the spec now or after the plan set.
- spec amendment — this plan ran beside plan 03, against spec §12's order — recorded in the plan,
  agreed at approval; spec text unchanged.
- spec drift — under a closed roadmap, a milestone prints when it is not `done` or `dropped`
  (so an `INVALID` one prints too); spec §7.1 says "when it is draft or approved" — not changed;
  test `a_closed_roadmap_prints_only_milestones_that_are_still_open` asserts the wider reading.

## Probe results

- Task 5 step 11, the board strings of `references/artifact-chain.md` §11 against the Lua, run
  after Task 4: all 14 strings present in `lib/roadmap.lua` or `lib/status.lua`.
- Guard break, Task 3 step 7: `if #unassigned > 0 then` → `if true then` gave
  `483 passed, 6 failed`, the guard `unassigned_is_omitted_when_every_open_chain_is_a_member`
  among them; restored.
- Guard break, Task 4: dropping `or intent.status == "done"` gave `486 passed, 7 failed`,
  `a_closed_chain_with_a_broken_milestone_key_is_not_checked` failing with
  `INVALID (intent.md: unknown status done)`; restored.
- Task 6, the board for this repository, rendered from the worktree root after Task 4:

  ```
  CHAIN                             STATE                         NEXT
  2026-08-29-claudevs-plugin-cache-hygiene  intent draft (triage)         review evidence
  2026-10-13-sdlc-roadmaps-milestones  plan 01 executing, plan 02 executing, plan 03 executing, plan 04 executing, plan 05 approved, plan 06 approved, plan 07 approved  wait (dependencies pending)
  DONE/DROPPED: 6 done, 2 dropped (not listed)
  ```

  Flat layout, no `ROADMAP`, `MILESTONE` or `UNASSIGNED` line. The reviewer's render of the same
  root under HEAD's `lib/status.lua` was byte-identical to it.

## Deviations

- 2026-10-14 — Test counts run 7 higher than the plan states throughout, because plan 03 added
  7 tests after this plan was written: the baseline was `448 passed`, not 441, and the end
  state `493 passed, 0 failed (22 files)`, not 486. After the review fix round it is `499`.
- 2026-10-14 — No commit was made after any task; each task's commit step was skipped and the
  commit gate left with the author, per the `execute` skill.
- 2026-10-14 — Task 5 ran in parallel with Task 1, since the two write different files. So its
  step 11 cross-check could not pass when Task 5 finished, and was run again after Task 4
  instead.
- 2026-10-14 — Task 3 added one clause to the `lib/status.lua` header comment that is not in the
  plan's text; the review fix round reworded it.
- 2026-10-14 — The review fix round added six tests and the `fs.is_file` check, which are not
  in the plan. They are listed under Review findings.
- 2026-10-14 — No `claudestacks-sdlc:task-briefer` was spawned. Each coder read its own task
  section of this plan by line range.
