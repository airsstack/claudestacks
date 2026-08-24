---
status: approved
created: 2026-08-25
depends-on: [01]
---

# claudestacks-sdlc Status Board Implementation Plan

**Goal:** Ship the deterministic status board — the `lib/status.lua` module, its `airsl` test file, the run driver, the shell launcher, and the `status` command.

**Architecture:** Mirrors the sdd Lua convention exactly: pure logic in `scripts/lib/status.lua` (a module returning `M`, testable against temp fixtures), a thin driver `scripts/status.lua` that requires it and prints, a POSIX launcher `scripts/status.sh` that resolves the `airsl` binary defensively and exits 0 silently when it is missing, and a command markdown that shells the launcher and falls back to a model-driven scan when the launcher printed nothing. State derivation implements spec §5.1; parsing implements the frontmatter subset of spec §2.3.

**Tech Stack:** Lua 5.4 on the `airsl` runtime (`airsstack.fs/path/stdio` — API verified against the installed binary: `fs.list` returns a sorted array of entry names), `airsl test` for the suite, POSIX sh for the launcher. Covered by `cargo make plugins` with no Makefile change (`airsl check plugins` / `airsl test … plugins` sweep the whole tree — Makefile.toml:140,158).

**Content authority:** `.claudestacks/sdlc/2026-08-24-sdlc-plugin/spec.md` §§2.3, 2.4, 5.1, 8. Refinement over spec §3's tree: the module lives in `scripts/lib/` (not flat in `scripts/`) and a `scripts/status.sh` launcher is added — the sdd `hooks/` + `hooks/lib/` pattern, needed so the logic is requireable by both the driver and the test.

---

## File structure

```
plugins/claudestacks-sdlc/scripts/lib/status.lua   — [create] parse, scan, derive, render (pure logic)
plugins/claudestacks-sdlc/scripts/status_test.lua  — [create] airsl test suite over temp fixtures
plugins/claudestacks-sdlc/scripts/status.lua       — [create] driver: require lib, print board for cwd
plugins/claudestacks-sdlc/scripts/status.sh        — [create] airsl resolver/launcher, silent when absent
plugins/claudestacks-sdlc/commands/status.md       — [create] command: run launcher, model fallback
```

Test invocation used throughout (same grants as `cargo make plugins-test`, Makefile.toml:158):

```
$ airsl test --policy confined --allow-read / --allow-write "${TMPDIR:-/tmp}" --allow-exec git plugins/claudestacks-sdlc/scripts
```

### Task 1 — Frontmatter parser (red → green)

**Files:**
- Create `plugins/claudestacks-sdlc/scripts/status_test.lua`
- Create `plugins/claudestacks-sdlc/scripts/lib/status.lua`

**Steps:**

1. Write the failing tests in `plugins/claudestacks-sdlc/scripts/status_test.lua`:

   ```lua
   -- Tests for lib/status — frontmatter parsing, chain scanning, state derivation
   -- and board rendering for the claudestacks-sdlc committed chain.
   --
   --   airsl test --policy confined --allow-read / \
   --     --allow-write "${TMPDIR:-/tmp}" --allow-exec git \
   --     plugins/claudestacks-sdlc/scripts

   local status = require("lib.status")

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
   }
   ```

2. Run and confirm failure (the module does not exist yet):

   ```
   $ airsl test --policy confined --allow-read / --allow-write "${TMPDIR:-/tmp}" --allow-exec git plugins/claudestacks-sdlc/scripts
   ```

   Expected: the run fails on `require("lib.status")` — module not found.

3. Write `plugins/claudestacks-sdlc/scripts/lib/status.lua`:

   ```lua
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
       local item = line:match("^%s+%-%s+(.-)%s*$")
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

   return M
   ```

4. Run and confirm green:

   ```
   $ airsl test --policy confined --allow-read / --allow-write "${TMPDIR:-/tmp}" --allow-exec git plugins/claudestacks-sdlc/scripts
   ```

   Expected: all 4 tests pass.

### Task 2 — Artifact reading and chain scanning (red → green)

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`
- Modify `plugins/claudestacks-sdlc/scripts/lib/status.lua`

**Steps:**

1. Append fixture helpers and scanning tests to the table in `status_test.lua`. Add the helpers above the `return {`:

   ```lua
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
   ```

   And these tests inside the returned table:

   ```lua
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
   ```

2. Run and confirm failure: `status.scan` is not defined — the new tests error.

3. Add to `lib/status.lua`, above the final `return M`:

   ```lua
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
   ```

4. Run and confirm green: all 10 tests pass.

### Task 3 — STATE and NEXT derivation (red → green)

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`
- Modify `plugins/claudestacks-sdlc/scripts/lib/status.lua`

**Steps:**

1. Append derivation tests (a `derive` helper first, above `return {`):

   ```lua
   -- Scans a one-chain root and derives that chain.
   local function derive_only(dir)
     local chains = status.scan(dir)
     assert(#chains == 1, "fixture must hold exactly one chain")
     return status.derive(chains[1])
   end
   ```

   Tests:

   ```lua
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

     all_plans_done_reports_the_chain_complete = function()
       local dir = root()
       local chain = path.join(dir, "2026-08-24-a")
       artifact(chain, "intent.md", { "status: approved", "created: 2026-08-24" })
       artifact(chain, "spec.md", { "status: approved", "created: 2026-08-24" })
       artifact(path.join(chain, "plans"), "01-core.md", { "status: done", "created: 2026-08-25" })
       local state, nxt = derive_only(dir)
       assert(state == "plans complete", state)
       assert(nxt == "chain complete; run execute walk-up", nxt)
     end,

     an_invalid_chain_derives_to_an_INVALID_row = function()
       local dir = root()
       fs.mkdir(path.join(dir, "2026-08-24-a"))
       local state, nxt = derive_only(dir)
       assert(state == "INVALID (intent.md missing)", state)
       assert(nxt == "fix 2026-08-24-a", nxt)
     end,
   ```

2. Run and confirm failure: `status.derive` is not defined.

3. Add to `lib/status.lua`, above `return M`:

   ```lua
   -- True when the plan numbered `num` in `plans` is done.
   local function plan_done(plans, num)
     for _, plan in ipairs(plans) do
       if plan.num == num then
         return plan.status == "done"
       end
     end
     return false
   end

   -- Normalises depends-on (absent, block list, or inline "[01, 02]") to a
   -- list of two-digit strings, then checks every named plan is done.
   local function deps_met(chain, plan)
     local deps = plan["depends-on"]
     local list = {}
     if type(deps) == "table" then
       list = deps
     elseif type(deps) == "string" then
       for num in deps:gmatch("%d%d") do
         list[#list + 1] = num
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
       local parts, all_done = {}, true
       local next_exec, next_draft
       for _, plan in ipairs(chain.plans) do
         parts[#parts + 1] = "plan " .. plan.num .. " " .. plan.status
         if plan.status ~= "done" and plan.status ~= "superseded" then
           all_done = false
         end
         if not next_exec and plan.status == "approved" and deps_met(chain, plan) then
           next_exec = plan.num
         end
         if not next_draft and plan.status == "draft" then
           next_draft = plan.num
         end
       end
       if all_done then
         return "plans complete", "chain complete; run execute walk-up"
       end
       local nxt = next_exec and ("execute " .. next_exec)
         or (next_draft and ("approve plan " .. next_draft))
         or "wait (dependencies pending)"
       return table.concat(parts, ", "), nxt
     end

     if intent.spec == "skipped" then
       return "intent approved (spec skipped)", "plan"
     end
     if not chain.spec then
       return "intent approved" .. tag, "design"
     end
     if chain.spec.status == "draft" then
       return "spec draft", "approve spec"
     end
     if chain.spec.status == "approved" then
       return "spec approved", "plan"
     end
     return "INVALID (spec.md: unknown status " .. tostring(chain.spec.status) .. ")",
       "fix " .. chain.name
   end
   ```

4. Run and confirm green: all 21 tests pass.

### Task 4 — Inputs line and board rendering (red → green)

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`
- Modify `plugins/claudestacks-sdlc/scripts/lib/status.lua`

**Steps:**

1. Append rendering tests:

   ```lua
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
   ```

2. Run and confirm failure: `status.render` is not defined.

3. Add to `lib/status.lua`, above `return M`:

   ```lua
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
   ```

4. Run and confirm green: all 24 tests pass.

### Task 5 — Driver and launcher

**Files:**
- Create `plugins/claudestacks-sdlc/scripts/status.lua`
- Create `plugins/claudestacks-sdlc/scripts/status.sh`

**Steps:**

1. Write the driver `plugins/claudestacks-sdlc/scripts/status.lua`:

   ```lua
   -- Renders the claudestacks-sdlc status board for the current repository.
   --
   --   airsl run --fail-open --policy confined --allow-read . scripts/status.lua

   local status = require("lib.status")
   local path = airsstack.path

   airsstack.stdio.write(
     status.render(path.join(path.absolute("."), status.ROOT)) .. "\n")
   ```

2. Write the launcher `plugins/claudestacks-sdlc/scripts/status.sh` (the sdd `ensure-layout.sh` resolver pattern, read-only grants, silent exit 0 on every failure path so the command's model fallback takes over):

   ```sh
   #!/bin/sh
   # claudestacks-sdlc status launcher. Resolves airsl without relying on PATH
   # (hooks and commands are spawned by the CLI, not a login shell, so a
   # cargo-installed binary under ~/.cargo/bin can be present but invisible).
   # Every path exits 0: when airsl is missing the command's model fallback
   # derives the board instead, and deliberately no `exec` — that would hand
   # airsl's status back to Claude Code.

   DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || exit 0
   [ -n "$DIR" ] || exit 0
   AIRSL=""
   if [ -n "${AIRSL_BIN:-}" ] && [ -x "${AIRSL_BIN:-}" ]; then
     AIRSL="$AIRSL_BIN"
   elif command -v airsl >/dev/null 2>&1; then
     AIRSL=airsl
   else
     for candidate in "${CARGO_HOME:-$HOME/.cargo}/bin/airsl" "$HOME/.cargo/bin/airsl"; do
       if [ -x "$candidate" ]; then
         AIRSL="$candidate"
         break
       fi
     done
   fi
   [ -n "$AIRSL" ] || exit 0

   "$AIRSL" run --fail-open --policy confined \
     --allow-read . \
     "$DIR/status.lua" || exit 0

   exit 0
   ```

3. Verify by hand from the repo root (this repository already has chain #1):

   ```
   $ sh plugins/claudestacks-sdlc/scripts/status.sh
   ```

   Expected: a board whose first row is `2026-08-24-sdlc-plugin` with the state reflecting this chain's current frontmatter, and no error output.

4. Verify the compile gate the CI runs:

   ```
   $ airsl check plugins/claudestacks-sdlc
   ```

   Expected: no output, exit 0 (every file compiles, driver included).

### Task 6 — `commands/status.md`

**Files:**
- Create `plugins/claudestacks-sdlc/commands/status.md`

**Steps:**

1. Write the command:

   ````markdown
   ---
   description: Render the claudestacks-sdlc chain status board — deterministic via airsl, model fallback otherwise.
   ---

   ## Board

   !`sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"`

   ## Task

   If the board above is non-empty, present it to the user exactly as printed
   and stop — the derivation has already happened; run nothing else.

   If it is empty, the airsl binary is not installed: derive the same board by
   hand. Scan `.claudestacks/sdlc/` per the rules in
   `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`: skip `prds/`, `rfcs/`
   and non-directories; read each chain's `intent.md`, `spec.md`, and
   `plans/NN-*.md` frontmatter; derive STATE and NEXT exactly per that file's
   NEXT-derivation rules; render an unparseable chain as
   `INVALID (<file>: <reason>)`; collapse done/dropped chains to a count line.
   Same columns, same output shape.
   ````

2. Verify:

   ```
   $ claude plugin validate plugins/claudestacks-sdlc --strict
   ```

   Expected: passes.

### Task 7 — Full suite and commit

**Steps:**

1. Run the whole plugin gate the CI runs:

   ```
   $ cargo make plugins
   ```

   Expected: `airsl check plugins` clean, `airsl test` green including the 24 status tests plus the pre-existing suite.

2. Commit:

   ```
   $ git add plugins/claudestacks-sdlc
   $ git commit -m "feat(repo): deterministic status board for claudestacks-sdlc"
   ```

---

## Verification summary (plan-level)

- 24 `airsl test` cases green; suite run via the exact `cargo make plugins-test` grants.
- `airsl check plugins/claudestacks-sdlc` compiles driver and module.
- Manual launcher run against this repository's real chain renders a board.
- `claude plugin validate plugins/claudestacks-sdlc --strict` passes.
