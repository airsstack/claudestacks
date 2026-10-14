---
status: executing
created: 2026-10-14
depends-on: [01]
built-on: a5a235079e03
---

# Sync Rules On The Board Implementation Plan

**Goal:** The status board reports every disagreement between a chain's intent, spec and plans
instead of offering the next step as if they agreed.

**Architecture:** `M.read_chain` computes the fingerprints of an approved chain's intent and
spec while it already holds their text. A new function, `M.sync`, turns those plus the
`built-on` and `disproves` keys into either one invalid result or a set of conditions.
`M.derive` asks it once, refuses on an invalid result, and otherwise leads the STATE cell and
decides NEXT from the conditions before falling back to today's states-only derivation.
`M.render` stops hiding a finished chain whose intent was never flipped. The same rules are
written into `references/artifact-chain.md`, which the skills and the no-`airsl` fallback read.

**Tech Stack:** Lua 5.4 under `airsl` 0.1.2, `lib/fingerprint` from plan 01, Markdown.

**Content authority:** spec §2 (the two keys, authority), §3 (all of it), §6 first paragraph
(what "complete" means for the walk-up), §7.1 first paragraph (a complete chain is a row),
§11 (sync rules tests, existing tests), §12 (references).

---

## File structure

```
plugins/claudestacks-sdlc/scripts/lib/status.lua         — [modify] fingerprints, M.sync, derive, render
plugins/claudestacks-sdlc/scripts/status_test.lua        — [modify] fixtures gain built-on; 32 new tests; 1 rewritten
plugins/claudestacks-sdlc/references/artifact-chain.md   — [modify] two keys, the sync rules, the complete-chain row
plugins/claudestacks-sdlc/references/templates.md        — [modify] built-on in the spec and plan frontmatter shapes
```

Every path below is relative to the repository root. The gate for every task is
`cargo make plugins-test`, run from the repository root. No Rust changes, so the Rust
Definition of Done does not apply.

Baseline, with plan 01 done: `409 passed, 0 failed (21 files)` and
`fingerprint gate: 8 cases passed`.

**Vocabulary used throughout.** A *live* plan has status `approved` or `executing`. A *settled*
plan has status `done` or `superseded`. A plan's *authority* is the chain's `spec.md`; when
there is no `spec.md` and the intent carries `spec: skipped`, it is the chain's `intent.md`. A
spec's authority is the chain's `intent.md`.

**The rules being built** (spec §3), for a chain whose intent is `approved`:

| # | Condition | Board |
|---|---|---|
| I2 | `spec.md` has a status other than `draft` or `approved` | `INVALID (spec.md: unknown status <status>)` |
| I3 | `spec.md` is `approved` and has no `built-on` | `INVALID (spec.md: missing built-on)` |
| I4 | a live plan exists, there is no `spec.md`, and the intent has no `spec: skipped` | `INVALID (plans/NN: no spec and no skip flag)` |
| I5 | a live plan has no `built-on` | `INVALID (plans/NN: missing built-on)` |
| C1 | `spec.md` is `approved` and its `built-on` differs from the intent's fingerprint | part `spec stale (intent changed)`; NEXT `design` |
| C2 | a plan that is not `superseded` carries `disproves` equal to its authority's current fingerprint | part `spec disproven by plan NN` (or `intent disproven by plan NN`); NEXT `design` (or `intent`) |
| C3 | a live plan's authority is `spec.md` and that spec is `draft` | part `plan NN <status>: blocked (spec not approved)`; NEXT `approve spec` |
| C4 | a live plan's `built-on` differs from its authority's fingerprint, and C3 does not hold for it | part `plan NN <status>: stale (spec changed)` (or `(intent changed)`); NEXT `plan` |

Invalid results are checked in the order I2, I3, I4, I5, after every result the board already
reports as invalid; within a rule the lowest plan number is named. NEXT is decided by the first
of C1, C2, C3, C4 that holds, and only then by today's derivation.

**Decisions this plan makes where the spec is silent.** Each is reported to the author at the
plan's approval gate:

- A `built-on:` key with no value counts as missing.
- The reference gains a NEXT bullet for a chain whose plans are all `superseded` with none
  `done` → `plan`. The code already does this (`status.lua:254-261`); the reference never
  said it.
- Every artifact of every chain is still read, as today (`status.lua:76-119`), whatever the
  intent's status; only the hashing is limited to `approved` intents. Spec §9 says a `done`
  or `dropped` chain "cost[s] one frontmatter read" while spec §3 says such a chain is
  "derived as today". The two differ in output: read as today, a `done` chain with an
  unparseable plan renders `INVALID`; read once, it renders `done`. This plan follows §3.
  **The author has not yet ruled on this.**

**Guard tests.** Some new tests pass before the code they sit beside is written, because they
pin behaviour that must *not* change. The spec requires every test to be seen failing (§11),
so each such test has a step that breaks the code on purpose, watches the test fail, and
restores the code. Each of those breaks was run against a prototype on 2026-10-14 and turned
its guard red.

### Task 1 — Give the existing fixtures their `built-on`

The new rules make an `approved` spec or a live plan without `built-on` invalid. Nineteen
fixture lines in the existing 31 tests hold one. They gain the key first, while the old code
still ignores it, so this task changes no behaviour and the suite stays green throughout.

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`

**Steps:**

1. Replace the opening of the file (`status_test.lua:8-11`):

   ```lua
   local status = require("lib.status")

   local fs = airsstack.fs
   local path = airsstack.path
   ```

   with:

   ```lua
   local status = require("lib.status")
   local fingerprint = require("lib.fingerprint")

   local fs = airsstack.fs
   local path = airsstack.path

   -- Every fixture artifact carries the body `# body`, so one fingerprint names
   -- the authority of every fixture spec and plan. BUILT is the frontmatter
   -- line that records it; STALE records an authority that has since changed.
   local FP = fingerprint.of_text("---\n---\n# body\n")
   local BUILT = "built-on: " .. FP
   local STALE = "built-on: 000000000000"
   ```

   The `artifact` helper writes `# body\n` after the frontmatter (`status_test.lua:23`), and
   that body's fingerprint is `7df83709971b` (plan 01, Task 2).

2. Apply these five literal replacements to every occurrence in the file. Each adds `, BUILT`
   before the closing `})`:

   | Occurrences | Find | Replace with |
   |---|---|---|
   | 12 | `"spec.md", { "status: approved", "created: 2026-08-24" })` | `"spec.md", { "status: approved", "created: 2026-08-24", BUILT })` |
   | 1 | `{ "status: approved", "created: 2026-08-25" })` | `{ "status: approved", "created: 2026-08-25", BUILT })` |
   | 2 | `{ "status: approved", "created: 2026-08-25", "depends-on: [01]" })` | `{ "status: approved", "created: 2026-08-25", "depends-on: [01]", BUILT })` |
   | 1 | `{ "status: approved", "created: 2026-08-25", "depends-on: [1]" })` | `{ "status: approved", "created: 2026-08-25", "depends-on: [1]", BUILT })` |
   | 3 | `{ "status: executing", "created: 2026-08-25" })` | `{ "status: executing", "created: 2026-08-25", BUILT })` |

   Intent fixtures, `draft` spec fixtures, and `draft`, `done` and `superseded` plan fixtures
   are left alone: the rules do not read them.

3. Verify the count, then the suite:

   ```
   $ grep -c 'BUILT })' plugins/claudestacks-sdlc/scripts/status_test.lua
   19
   $ cargo make plugins-test
   409 passed, 0 failed (21 files)
   ```

   `STALE` is unused until Task 5; `cargo make plugins-check` still exits 0.

4. Commit `test(repo): record built-on in the sdlc status fixtures`.

### Task 2 — Checkpoint before any rule lands

**Steps:**

1. **Stop and report to the author.** State that the 31 existing tests pass with their
   fixtures migrated and no board behaviour has changed yet, and that the next four tasks
   change what the board prints for existing chains: an approved spec or a live plan with no
   `built-on` becomes `INVALID`. Wait for the author's word before continuing.

### Task 3 — Read fingerprints with the chain

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`
- Modify `plugins/claudestacks-sdlc/scripts/lib/status.lua`

**Steps:**

1. Add the shared fixtures and builder to `status_test.lua`, directly after the `derive_only`
   function (`status_test.lua:27-31` before Task 1) and before `return {`:

   ```lua
   -- Frontmatter of the fixtures the sync tests share.
   local INTENT = { "status: approved", "created: 2026-08-24" }
   local SKIPPED = { "status: approved", "created: 2026-08-24", "spec: skipped" }
   local SPEC = { "status: approved", "created: 2026-08-24", BUILT }

   -- Builds a root holding the one chain `2026-08-24-a` from an intent's
   -- frontmatter, a spec's (nil for no spec.md) and a list of
   -- { file name, frontmatter } plans; returns the root.
   local function chain_root(intent_fm, spec_fm, plans)
     local dir = root()
     local chain = path.join(dir, "2026-08-24-a")
     artifact(chain, "intent.md", intent_fm)
     if spec_fm then
       artifact(chain, "spec.md", spec_fm)
     end
     for _, plan in ipairs(plans or {}) do
       artifact(path.join(chain, "plans"), plan[1], plan[2])
     end
     return dir
   end
   ```

2. Add two failing tests at the end of the returned table, after
   `an_empty_root_renders_a_starter_hint`:

   ```lua
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
   ```

3. Run and confirm failure:

   ```
   $ cargo make plugins-test
   ```

   Expected: `410 passed, 1 failed (21 files)`, the failure being
   `an_approved_chain_carries_the_fingerprints_of_its_intent_and_spec` with the message `nil`.
   The second test passes already and stays as a guard: it pins that a chain the rules do not
   read costs no hashing.

4. In `plugins/claudestacks-sdlc/scripts/lib/status.lua`, require the library. Replace
   (`status.lua:8-9`):

   ```lua
   local fs = airsstack.fs
   local path = airsstack.path
   ```

   with:

   ```lua
   local fingerprint = require("lib.fingerprint")

   local fs = airsstack.fs
   local path = airsstack.path
   ```

5. Make `M.read_artifact` hand back the text it read. Replace (`status.lua:56-71`):

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
   ```

   with:

   ```lua
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
   ```

6. Compute the two fingerprints in `M.read_chain`. Replace its header comment and its intent
   and spec blocks (`status.lua:73-100`):

   ```lua
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
   ```

   with:

   ```lua
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
   ```

   The plans loop below it (`status.lua:102-116`) is unchanged: it already reads
   `M.read_artifact`'s first two results as `plan, preason`, and a plan's own body is never
   hashed.

7. Run and confirm green:

   ```
   $ cargo make plugins-test
   411 passed, 0 failed (21 files)
   ```

8. See the guard fail. In `M.read_chain`, temporarily change
   `local checked = intent.status == "approved"` to `local checked = true`, and run
   `cargo make plugins-test`.

   Expected: `410 passed, 1 failed (21 files)`, the failure being
   `a_chain_whose_intent_is_not_approved_is_not_fingerprinted`. Restore the line and confirm
   `411 passed, 0 failed (21 files)` again.

9. Commit `feat(repo): read intent and spec fingerprints with the sdlc chain`.

### Task 4 — Report the invalid results I2 to I5

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`
- Modify `plugins/claudestacks-sdlc/scripts/lib/status.lua`

**Steps:**

1. Add eleven tests at the end of the returned table in `status_test.lua`:

   ```lua
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
   ```

2. Run and confirm failure:

   ```
   $ cargo make plugins-test
   ```

   Expected: `414 passed, 8 failed (21 files)`. Eight of the eleven fail:
   `a_spec_with_an_unknown_status_is_invalid_even_with_plans`,
   `an_approved_spec_without_built_on_is_invalid`, `an_empty_built_on_key_counts_as_missing`,
   `a_live_plan_with_no_spec_and_no_skip_flag_is_invalid`,
   `a_live_plan_without_built_on_is_invalid`,
   `a_missing_spec_built_on_outranks_a_missing_plan_built_on`,
   `a_missing_authority_outranks_a_missing_plan_built_on` and
   `the_lowest_plan_number_is_named_first`. Three pass already and are guards, seen failing
   in step 7: `an_unknown_plan_status_outranks_a_missing_spec_built_on`,
   `draft_and_settled_plans_are_not_checked` and
   `a_chain_whose_intent_is_not_approved_is_not_checked`.

3. In `plugins/claudestacks-sdlc/scripts/lib/status.lua`, insert the following directly above
   the comment `-- STATE and NEXT for one chain, per the NEXT-derivation rules in`
   (`status.lua:188` before Task 3):

   ```lua
   -- A live plan still has work in it; a settled one (`done`, `superseded`)
   -- does not, and a `draft` is checked only when it is approved.
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
   -- `invalid`, the reason of the first of rules I2-I5 that holds, and
   -- `word` — "spec" or "intent", the artifact this chain's plans are written
   -- against (nil when there is none).
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

     return out
   end

   ```

   `authority_fp` is assigned and not yet read; Task 5 reads it.

4. Wire it into `M.derive`. Replace (`status.lua:205-223` before Task 3):

   ```lua
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
   ```

   with:

   ```lua
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

     if #chain.plans > 0 then
       local parts = {}
       -- every_settled: every plan is done or superseded (no draft/approved/
       -- executing left). done_count: how many are actually done. Per spec
       -- §2.4:116 / reference §7.2, the walk-up needs BOTH — a chain that is
       -- all `superseded` with zero `done` has nothing to roll up.
       local every_settled, done_count = true, 0
       local next_exec, next_draft, blocked, any_executing = nil, nil, false, false
       for _, plan in ipairs(chain.plans) do
         parts[#parts + 1] = "plan " .. plan.num .. " " .. plan.status
   ```

5. `M.sync` now refuses every spec status but `draft` and `approved`, so the last branch of
   `M.derive` can no longer be reached. Replace the end of the function (`status.lua:274-279`
   before Task 3):

   ```lua
     if chain.spec.status == "approved" then
       return "spec approved" .. tag, "plan"
     end
     return "INVALID (spec.md: unknown status " .. tostring(chain.spec.status) .. ")",
       "fix " .. chain.name
   end
   ```

   with:

   ```lua
     -- M.sync refused every status but `draft` and `approved`.
     return "spec approved" .. tag, "plan"
   end
   ```

6. Run and confirm green:

   ```
   $ cargo make plugins-test
   422 passed, 0 failed (21 files)
   ```

7. See the three guards fail. Make each change below on its own, run
   `cargo make plugins-test`, confirm the named test is among the failures, and restore the
   line before the next. Other tests fail alongside; that is expected.

   | Temporary change in `lib/status.lua` | Guard that must fail |
   |---|---|
   | in `M.derive`, `if not PLAN_STATUSES[plan.status] then` → `if false then` | `an_unknown_plan_status_outranks_a_missing_spec_built_on` |
   | in `live`, the `return plan.status == "approved" or plan.status == "executing"` line → `return true` | `draft_and_settled_plans_are_not_checked` |
   | in `M.derive`, `if intent.status == "draft" then` → `if intent.status == "drafted" then` | `a_chain_whose_intent_is_not_approved_is_not_checked` |

   After the last restore, confirm `422 passed, 0 failed (21 files)` again.

8. Commit `feat(repo): report unsynced sdlc chains as invalid on the board`.

### Task 5 — Report the conditions C1 to C4

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`
- Modify `plugins/claudestacks-sdlc/scripts/lib/status.lua`

**Steps:**

1. Add nineteen tests at the end of the returned table in `status_test.lua`:

   ```lua
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
   ```

2. Run and confirm failure:

   ```
   $ cargo make plugins-test
   ```

   Expected: `425 passed, 16 failed (21 files)`. Three of the nineteen pass already and are
   guards, seen failing in step 10:
   `a_plan_on_the_skip_path_built_on_the_intent_is_executable`,
   `a_disproves_value_that_no_longer_matches_raises_nothing` and
   `a_superseded_plan_does_not_raise_disproven`.

3. In `plugins/claudestacks-sdlc/scripts/lib/status.lua`, replace the whole of `M.sync` and
   its comment, as written in Task 4, with:

   ```lua
   -- The sync findings for a chain whose intent is `approved`, per the sync
   -- rules in `references/artifact-chain.md` §10. Returns a table holding
   -- either `invalid` (the reason, rules I2-I5 in order) or the conditions:
   -- `c1` (spec stale), `c2` (the lowest plan number whose `disproves` still
   -- matches), `plans` (plan -> "blocked" for C3 or "stale" for C4), `blocked`
   -- and `stale` (whether any plan holds C3 / C4), and `word` — "spec" or
   -- "intent", the artifact this chain's plans are written against.
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
   ```

   `out.plans` is keyed by the plan table itself, not its number, so two files sharing a number
   cannot be confused.

4. Update `M.derive`'s header comment. Replace:

   ```lua
   -- STATE and NEXT for one chain, per the NEXT-derivation rules in
   -- `references/artifact-chain.md` (spec §5.1). States only, no judgment.
   ```

   with:

   ```lua
   -- STATE and NEXT for one chain, per the NEXT-derivation and sync rules in
   -- `references/artifact-chain.md` §9 and §10. States and fingerprints only,
   -- no judgment.
   ```

5. Build the leading parts and the sync NEXT. In `M.derive`, replace the lines written in
   Task 4:

   ```lua
     local sync = M.sync(chain)
     if sync.invalid then
       return "INVALID (" .. sync.invalid .. ")", "fix " .. chain.name
     end

     if #chain.plans > 0 then
       local parts = {}
   ```

   with:

   ```lua
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
   ```

6. Give each plan its part. Replace the line:

   ```lua
         parts[#parts + 1] = "plan " .. plan.num .. " " .. plan.status
   ```

   with:

   ```lua
         local part = "plan " .. plan.num .. " " .. plan.status
         if sync.plans[plan] == "blocked" then
           part = part .. ": blocked (spec not approved)"
         elseif sync.plans[plan] == "stale" then
           part = part .. ": stale (" .. sync.word .. " changed)"
         end
         parts[#parts + 1] = part
   ```

7. Keep a chain open while C1 or C2 stands, and let the sync NEXT win. Replace
   (`status.lua:243-249` before Task 3):

   ```lua
       if every_settled and done_count > 0 then
         -- Reference §9:188 collapses this into the DONE/DROPPED tail (count
         -- only); M.render does that collapse by matching this exact state.
         return "chain complete" .. tag, "execute walk-up"
       end
       local nxt = next_exec and ("execute " .. next_exec)
         or (next_draft and ("approve plan " .. next_draft))
   ```

   with:

   ```lua
       if every_settled and done_count > 0 and not sync.c1 and not sync.c2 then
         -- The chain's work is finished and only the walk-up is owed. A
         -- standing C1 or C2 keeps the chain open: the debt outlives the plans.
         return "chain complete" .. tag, "execute walk-up"
       end
       local nxt = sync_next
         or next_exec and ("execute " .. next_exec)
         or (next_draft and ("approve plan " .. next_draft))
   ```

8. Report a stale spec on a chain with no plans. Replace:

   ```lua
     if intent.spec == "skipped" then
       return "intent approved (spec skipped)" .. tag, "plan"
     end
   ```

   with:

   ```lua
     if sync.c1 then
       -- `spec approved` is left out: the stale part already says it.
       return table.concat(parts, ", ") .. tag, sync_next
     end
     if intent.spec == "skipped" then
       return "intent approved (spec skipped)" .. tag, "plan"
     end
   ```

9. Run and confirm green:

   ```
   $ cargo make plugins-test
   441 passed, 0 failed (21 files)
   ```

10. See the three guards fail. Make each change below on its own, run
    `cargo make plugins-test`, confirm the named test is among the failures, and restore the
    line before the next.

    | Temporary change in `M.sync` | Guard that must fail |
    |---|---|
    | `word, authority_fp = "intent", chain.intent_fp` → `word, authority_fp = "intent", nil` | `a_plan_on_the_skip_path_built_on_the_intent_is_executable` |
    | `fp_value(plan.disproves) == authority_fp` → `fp_value(plan.disproves) ~= nil` | `a_disproves_value_that_no_longer_matches_raises_nothing` |
    | delete ` and plan.status ~= "superseded"` from the `if not out.c2` line | `a_superseded_plan_does_not_raise_disproven` |

    After the last restore, confirm `441 passed, 0 failed (21 files)` again.

11. Commit `feat(repo): report stale, blocked and disproven sdlc artifacts on the board`.

### Task 6 — Show a finished chain whose intent was never flipped

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`
- Modify `plugins/claudestacks-sdlc/scripts/lib/status.lua`

**Steps:**

1. In `status_test.lua`, replace the whole test
   `all_plans_done_derives_chain_complete_and_collapses_to_the_tail` together with the
   seven-line comment above it that begins `-- Deviation from plan 02's own literal`
   (`status_test.lua:218-237` before Task 1) with:

   ```lua
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
   ```

2. Run and confirm failure:

   ```
   $ cargo make plugins-test
   ```

   Expected: `440 passed, 1 failed (21 files)`, the failure being
   `a_complete_chain_is_a_row_and_is_not_counted_in_the_tail` with the message
   `a complete chain must be a row, got:` followed by a board that holds only the header and
   `DONE/DROPPED: 1 done, 0 dropped (not listed)`.

3. In `M.render` in `lib/status.lua`, replace (`status.lua:315-318` before Task 3):

   ```lua
       -- "chain complete" (with an optional trailing "(triage)" tag) is the
       -- every-plan-done-or-superseded-with->=1-done case; reference §9:188
       -- collapses it into the tail same as a dropped/done intent.
       if state == "done" or state:match("^chain complete") then
   ```

   with:

   ```lua
       -- Only a `done` or `dropped` intent collapses into the tail. A chain
       -- whose plans are complete but whose intent was never flipped is a row,
       -- so a missed walk-up is visible.
       if state == "done" then
   ```

4. Three comments still describe the collapse that no longer happens, with line numbers of
   the reference that Task 7 moves. Bring them up to date; none changes behaviour. In
   `M.derive` in `lib/status.lua`, replace (`status.lua:251-260` before Task 3):

   ```lua
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
   ```

   with:

   ```lua
         -- plan `executing` -> "no further derivation; it is mid-flight"
         -- (reference §9): nothing to fabricate, NEXT stays empty.
         or (any_executing and "")
         -- Reached only when every plan is settled (`done` or `superseded`)
         -- but none is actually `done` — the all-superseded case, which
         -- reference §9 sends to `plan`. Unrecognised statuses are refused
         -- above, so this cannot be a typo falling through. The chain needs a
         -- replacement plan, same as an approved spec with none yet.
   ```

   In `status_test.lua`, replace the comment above
   `an_all_superseded_chain_with_no_done_plan_is_not_complete` (`status_test.lua:239-245`
   before Task 1):

   ```lua
     -- Reference §9:187-188 names this case ("every plan is `done`/`superseded`")
     -- and now carries the ≥1-`done` guard §7.2:133 already required, so a
     -- chain whose plans are ALL `superseded` and NONE `done` stays off the
     -- collapsed tail — it is neither "chain complete" (no done plan to roll
     -- up) nor any of the other named branches. Minimal defensible NEXT:
     -- "plan" — the chain needs a replacement plan, same action as an
     -- approved spec with no plans yet.
   ```

   with:

   ```lua
     -- A chain whose plans are ALL `superseded` and NONE `done` is not
     -- complete: there is no done plan to walk up. Reference §9 sends it to
     -- "plan" — the chain needs a replacement plan, same action as an
     -- approved spec with no plans yet.
   ```

5. Run and confirm green:

   ```
   $ cargo make plugins-test
   441 passed, 0 failed (21 files)
   ```

6. Commit `feat(repo): show a missed sdlc walk-up as a board row`.

### Task 7 — Write the rules into the references

The skills and the no-`airsl` fallback read `references/artifact-chain.md`, not the Lua. This
task makes the two say the same thing. There is no test for prose; each step's check is a
`grep` for text that is absent before the edit and present after it.

**Files:**
- Modify `plugins/claudestacks-sdlc/references/artifact-chain.md`
- Modify `plugins/claudestacks-sdlc/references/templates.md`

**Steps:**

1. Confirm the new text is absent:

   ```
   $ grep -c 'built-on' plugins/claudestacks-sdlc/references/artifact-chain.md plugins/claudestacks-sdlc/references/templates.md
   plugins/claudestacks-sdlc/references/artifact-chain.md:0
   plugins/claudestacks-sdlc/references/templates.md:0
   ```

2. In `references/artifact-chain.md` §6, replace (`artifact-chain.md:86-102`):

   ````markdown
   Every chain artifact (`intent.md`, `spec.md`, each `plans/NN-<topic>.md`) opens with
   YAML frontmatter. The full schema, all seven keys:

   ```yaml
   ---
   status: draft                 # per-artifact state, §7
   created: 2026-08-24
   derived-from-prd:             # optional, list-valued, provenance only
     - prds/payment-v2.md
   derived-from-rfc:             # optional, list-valued, provenance only
     - rfcs/webhooks-v2.md
     - rfcs/retry-budget-notes.md
   source: triage                # optional; absent = human-originated
   spec: skipped                 # optional, intent only; §8
   depends-on: [01]              # optional, plan only; empty/absent = independent
   ---
   ```
   ````

   with:

   ````markdown
   Every chain artifact (`intent.md`, `spec.md`, each `plans/NN-<topic>.md`) opens with
   YAML frontmatter. The full schema, all nine keys:

   ```yaml
   ---
   status: draft                 # per-artifact state, §7
   created: 2026-08-24
   derived-from-prd:             # optional, list-valued, provenance only
     - prds/payment-v2.md
   derived-from-rfc:             # optional, list-valued, provenance only
     - rfcs/webhooks-v2.md
     - rfcs/retry-budget-notes.md
   source: triage                # optional; absent = human-originated
   spec: skipped                 # optional, intent only; §8
   depends-on: [01]              # optional, plan only; empty/absent = independent
   built-on: 7df83709971b        # spec and plan; §10
   disproves: 7df83709971b       # optional, plan only; §10
   ---
   ```
   ````

3. In the table below it, add two rows after the `depends-on` row (`artifact-chain.md:112`):

   ```markdown
   | `built-on` | fingerprint (12 hex characters, §10) | required on an `approved` spec and on an `approved` or `executing` plan; written when the artifact is drafted |
   | `disproves` | fingerprint (12 hex characters, §10) | optional; plan only; written by `execute`, never removed |
   ```

4. In §7.2, replace the intent's walk-up row (`artifact-chain.md:133`):

   ```markdown
   | intent `approved → done` | all the chain's plans are `done` or `superseded`, with at least one `done` | `execute` (walk-up) |
   ```

   with:

   ```markdown
   | intent `approved → done` | the chain is complete (§10.4): all its plans are `done` or `superseded`, with at least one `done`, and no stale or disproven spec stands | `execute` (walk-up) |
   ```

   In the same table, replace `execute`'s approval row (`artifact-chain.md:140`):

   ```markdown
   | plan `draft → approved` | user names the plan and asks for it to be executed — the instruction is the approval, so the gate is satisfied rather than bypassed | `execute` |
   ```

   with:

   ```markdown
   | plan `draft → approved` | user names the plan and asks for it to be executed, and the plan's `built-on` equals its authority's current fingerprint (§10.2) — the instruction is the approval, so the gate is satisfied rather than bypassed | `execute` |
   ```

5. In §9, replace the opening paragraph and the last bullet. Replace
   (`artifact-chain.md:171-173`):

   ```markdown
   These are the rules the status board's NEXT column executes — by `scripts/status.lua`
   when `airsl` is installed, and by hand, from this file, when it is not (the fallback
   tier of `/claudestacks-sdlc:status`). Derivation is states-only, no judgment call:
   ```

   with:

   ```markdown
   These are the rules the status board's NEXT column executes — by `scripts/status.lua`
   when `airsl` is installed, and by hand, from this file, when it is not (the fallback
   tier of `/claudestacks-sdlc:status`). The board scans the chain root one level deep:
   every directory is a chain except `prds/` and `rfcs/`, and a plain file is not a row.
   Derivation reads states and fingerprints only, no judgment call. For a chain whose
   intent is `approved`, the sync rules of §10 are applied first; the list below decides
   NEXT only when none of them does:
   ```

   and replace the last bullet (`artifact-chain.md:185`):

   ```markdown
   - all plans in the chain `done` or `superseded`, with at least one `done` → chain complete
   ```

   with:

   ```markdown
   - the chain is complete (§10.4) → STATE `chain complete`, NEXT `execute walk-up`
   - every plan `superseded` and none `done` → `plan`
   ```

6. Replace the collapse rule (`artifact-chain.md:187-191`):

   ```markdown
   Triage-sourced intents (`source: triage`) are tagged `(triage)` in the STATE column
   alongside their derived state. Chains whose intent is `dropped`, or whose every plan
   is `done`/`superseded` with at least one `done`, are listed under a collapsed
   `DONE/DROPPED` tail section (count only), unless a verbose flag in the status skill's
   dialogue asks for the detail.
   ```

   with:

   ```markdown
   Triage-sourced intents (`source: triage`) are tagged `(triage)` in the STATE column,
   after every other part of the cell. Chains whose intent is `done` or `dropped` are
   listed under a collapsed `DONE/DROPPED` tail section (count only), unless a verbose
   flag in the status skill's dialogue asks for the detail. A complete chain whose intent
   is still `approved` is **not** collapsed: it is a row reading `chain complete` →
   `execute walk-up`, so a walk-up that was never performed stays visible.
   ```

7. Insert a new section between the end of §9 (after the paragraph ending "this annotation
   is their only appearance on the board.", `artifact-chain.md:196`) and the `---` line that
   precedes "This file owns paths, naming…":

   ````markdown
   ## 10. Fingerprints and sync rules

   Related artifacts must still agree: a spec with the intent it was written from, a plan
   with the spec it was written from. The board checks that mechanically, for every chain
   whose intent is `approved`. A chain whose intent is `draft`, `dropped` or `done` is not
   checked.

   ### 10.1 Fingerprints

   The **fingerprint** of an artifact is the first 12 hexadecimal characters of the
   SHA-256 of its body. The body is every line after the line that closes the frontmatter
   (the first line equal to `---` after line 1), with one trailing carriage return removed
   from each line and each line terminated by exactly one `\n`. The frontmatter is
   excluded, so a `status` flip never changes a fingerprint and any edit to the text does.
   A file whose first line is not `---`, or whose frontmatter is never closed, has no
   fingerprint.

   `scripts/lib/fingerprint.lua` computes it for the board. Without `airsl`, compute it
   with `sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <file>`, which prints the 12
   characters and exits 0, or prints nothing and exits 2 when the file has no fingerprint.

   ### 10.2 The two keys

   An artifact's **authority** is what it was written from. A spec's authority is the
   chain's `intent.md`. A plan's authority is the chain's `spec.md`; when the intent
   carries `spec: skipped` and no `spec.md` exists (§8), it is the chain's `intent.md`.

   - `built-on` holds the fingerprint of the authority the artifact was written against,
     or last re-confirmed against. It is written when the artifact is drafted. The skill
     that owns the artifact — `design` for a spec, `plan` for a plan — compares it with
     the authority's current fingerprint before flipping `draft → approved`, says so when
     they differ, and writes the current fingerprint in the same edit as the flip.
     `execute` may approve a `draft` plan by being asked to run it (§7.2) only when that
     plan's `built-on` already equals its authority's current fingerprint; otherwise it
     refuses and names `plan`, because nobody has read the plan against the changed text.
     **Re-confirmation** rewrites the key on an approved artifact: the owning skill asks
     whether the artifact still holds against its authority as that authority now reads,
     and on an explicit yes writes the current fingerprint and changes nothing else. It is
     never inferred, and never performed by `execute`.
   - `disproves` holds the fingerprint of the authority whose claim a plan's execution
     showed to be wrong. `execute` writes it on the plan it is running. It holds one
     fingerprint, a later disproof by the same plan overwrites it, and it is never
     removed: it stops matching, and so stops having any effect, once the authority's text
     changes.

   A **live plan** is `approved` or `executing`. A **settled plan** is `done` or
   `superseded`.

   ### 10.3 Invalid results

   An invalid result replaces the whole STATE cell and its NEXT is `fix <chain>`. When
   several hold, the cell shows the first in this order; within a rule, the lowest plan
   number.

   | # | Condition | STATE |
   |---|---|---|
   | I1 | an artifact is missing, unreadable or unparseable, or carries an unknown status | `INVALID (<file>: <reason>)` |
   | I2 | `spec.md` has a status other than `draft` or `approved` | `INVALID (spec.md: unknown status <status>)` |
   | I3 | `spec.md` is `approved` and has no `built-on` | `INVALID (spec.md: missing built-on)` |
   | I4 | a live plan exists, there is no `spec.md`, and the intent has no `spec: skipped` | `INVALID (plans/NN: no spec and no skip flag)` |
   | I5 | a live plan has no `built-on` | `INVALID (plans/NN: missing built-on)` |

   A superseded spec is renamed (§4), so `spec.md` itself is never legitimately
   `superseded`.

   ### 10.4 Conditions, STATE and NEXT

   | # | Condition | STATE part | NEXT |
   |---|---|---|---|
   | C1 | `spec.md` is `approved` and its `built-on` differs from the intent's fingerprint | `spec stale (intent changed)` | `design` |
   | C2 | a plan that is not `superseded` carries `disproves` equal to the current fingerprint of its authority | `spec disproven by plan NN`; on the spec-skip path `intent disproven by plan NN` | `design`; on the spec-skip path `intent` |
   | C3 | a live plan's authority is `spec.md` and that spec is `draft` | `plan NN <status>: blocked (spec not approved)` | `approve spec` |
   | C4 | a live plan's `built-on` differs from its authority's fingerprint, and C3 does not hold for it | `plan NN <status>: stale (spec changed)`; on the spec-skip path `plan NN <status>: stale (intent changed)` | `plan` |

   `<status>` is the plan's own status. C3 and C4 read live plans only. C2 reads every plan
   except `superseded` ones, because a plan can finish its run with the debt still owed;
   when several plans satisfy it, the part names the lowest number.

   **STATE.** When no invalid result holds, the cell is built in this order,
   comma-separated, with the `(triage)` tag last:

   1. the C1 part, if C1 holds;
   2. the C2 part, if C2 holds;
   3. for a chain with plans, one part per plan in number order: `plan NN <status>`, or the
      C3 or C4 form for a plan they hold for;
   4. for a chain without plans, the single state of §9 (`intent approved`,
      `intent approved (spec skipped)`, `spec draft`, `spec approved`), except that
      `spec approved` is omitted when C1 holds.

   **NEXT.** The first of C1, C2, C3, C4 that holds decides it, per the table. Only when
   none holds does the list in §9 apply. A chain with a standing C2 therefore never offers
   `execute NN`.

   **A chain is complete** when every plan is settled, at least one is `done`, and neither
   C1 nor C2 holds. Only a complete chain reads `chain complete` and only a complete chain
   is walked up to `done` (§7.2). While C1 or C2 stands the cell is built by the list
   above and the intent stays `approved`.

   ````

8. In `references/templates.md`, add the key to the two frontmatter shapes. Replace
   (`templates.md:53-58`):

   ```markdown
   ---
   status: draft
   created: <YYYY-MM-DD>
   ---

   # Spec: <title>
   ```

   with:

   ```markdown
   ---
   status: draft
   created: <YYYY-MM-DD>
   built-on: <fingerprint>          # of intent.md — see artifact-chain §10
   ---

   # Spec: <title>
   ```

   and replace (`templates.md:82-86`):

   ```markdown
   ---
   status: draft
   created: <YYYY-MM-DD>
   depends-on: [01]                 # optional — see artifact-chain §6
   ---
   ```

   with:

   ```markdown
   ---
   status: draft
   created: <YYYY-MM-DD>
   depends-on: [01]                 # optional — see artifact-chain §6
   built-on: <fingerprint>          # of the plan's authority — see artifact-chain §10
   ---
   ```

9. Verify the edits landed and nothing still describes the old collapse:

   ```
   $ grep -c 'built-on' plugins/claudestacks-sdlc/references/artifact-chain.md plugins/claudestacks-sdlc/references/templates.md
   ```

   Expected: a non-zero count for each file.

   ```
   $ grep -n 'all seven keys\|whose every plan' plugins/claudestacks-sdlc/references/artifact-chain.md
   ```

   Expected: no output.

   ```
   $ grep -n '^## \|^### 10' plugins/claudestacks-sdlc/references/artifact-chain.md
   ```

   Expected: sections `## 1.` to `## 10.` in order, and `### 10.1` to `### 10.4`.

10. Check each board string in the reference against the code that prints it. For every STATE
    and NEXT string in the tables of §10.3 and §10.4, confirm it appears in
    `plugins/claudestacks-sdlc/scripts/lib/status.lua`:

    ```
    $ grep -n 'missing built-on\|no spec and no skip flag\|spec stale (intent changed)\|disproven by plan\|blocked (spec not approved)\|: stale (\|approve spec' plugins/claudestacks-sdlc/scripts/lib/status.lua
    ```

    Expected: at least one line for each of the seven alternatives.

11. Commit `docs(repo): write the sdlc sync rules into the artifact chain reference`.

### Task 8 — Read the new board on this repository

**Steps:**

1. Render the board for this repository with the changed code:

   ```
   $ sh plugins/claudestacks-sdlc/scripts/status.sh
   ```

   Expected: this chain, `2026-10-13-sdlc-roadmaps-milestones`, is a row that does **not**
   read `INVALID`. Its spec and every plan carry `built-on` (spec §12), so neither I3 nor I5
   applies. The row lists every plan with its status; the plan being executed reads
   `executing`.

   Any other chain that now reads `INVALID (… missing built-on)` is one approved before this
   change. That is intended (spec §3.5): the author decided no compatibility with earlier
   chains is required, and none is back-filled. Report each such row to the author by name;
   do not edit those chains.

2. Paste the board printed in step 1 into this plan's `## Probe results`.

3. **Checkpoint — stop and report to the author:** the four commits of Tasks 3 to 6, the
   reference commit, the board from step 1, and any earlier chain that now reads `INVALID`.

---

## Verification summary (plan-level)

- `cargo make plugins-check` exits 0.
- `cargo make plugins-test` prints `441 passed, 0 failed (21 files)` and
  `fingerprint gate: 8 cases passed`.
- Every row I2 to I5 and C1 to C4 has a test named for it, and each new test was seen failing
  or is named above as a guard that passed before the change.
- `references/artifact-chain.md` holds §10 and no longer describes a complete chain as
  collapsed; every board string in it appears in `lib/status.lua`.
- The board for this repository shows this chain without `INVALID`.

## Review findings

One `claudestacks:reviewer` round over Tasks 1 and 3–7 (report
`.airsstack/cc/plugins/claudestacks/handoff/20261014-094648-c59e/26-reviewer-plan02.md`, git-ignored).
Verdict: code and reference text match this plan's blocks exactly (§10 diffs clean against Task 7
step 7); DoD green on re-run; code 0🔴 2🟡 9🔵, spec 0🔴 1🟡 2🔵 1❓; blocking set empty. The
reviewer ran 25 mutations on a scratch copy: all eight plan-named guard breaks went red, 7 others
survived. One fix round followed; the reviewer was not re-run.

- test teeth — every fixture body is `# body`, so the intent's and spec's fingerprints are equal and the tests cannot tell which artifact is the authority; mutants m09 (authority read from the intent), m10 (C1 compares the spec with itself) and m11 (`spec_fp` hashed from the intent) survived — `status_test.lua:14-31` — fixed: fixture helpers take an optional body; tests `a_plan_built_on_the_intent_text_is_stale_under_a_spec`, `a_spec_built_on_its_own_text_is_stale`, `a_plan_built_on_the_spec_text_is_not_stale_when_the_bodies_differ`; each seen failing under its mutant (Probe results).
- test teeth — no test pins C3 ignoring draft and settled plans under a draft spec (spec §11); mutant m14 survived — `status_test.lua` — fixed: `draft_and_settled_plans_under_a_draft_spec_are_not_blocked`, seen failing under m14.
- test teeth — an empty `built-on:` on a plan (m12), I2 outranking I5 (m13) and `spec.md` outranking the skip flag (m15) were unpinned — `status_test.lua` — fixed: `an_empty_built_on_key_on_a_live_plan_counts_as_missing`, `an_unknown_spec_status_outranks_a_missing_plan_built_on`, `a_spec_file_outranks_the_skip_flag_for_authority`; each seen failing under its mutant. m13 and m15 were written from the reviewer's descriptions, not exact edits.
- comment vs code — the `live` comment said a `draft` is checked only when approved; C2 does read draft plans — `lib/status.lua:200-202` — fixed: limited to I4, I5, C3 and C4.
- comment vs code — the `M.sync` doc omitted that `word` is nil with no spec and no skip flag — `lib/status.lua:216-224` — fixed.
- reference accuracy — the walk-up row said "no stale or disproven spec stands"; on the skip path `intent disproven` also keeps the chain open — `references/artifact-chain.md:137` — fixed: "neither C1 nor C2 holds (§10.4)". The same old wording remains in plan 07's README text (`07-release.md:88`).
- reference/code agreement — the I1 template `INVALID (<file>: <reason>)` does not cover `INVALID (intent.md missing)` — `artifact-chain.md:264` — fixed: the exception is named.
- doc discipline — the header cites an earlier chain's spec sections — `lib/status.lua:6` — not fixed; pre-existing.
- naming — on success `preason` holds the plan's text — `lib/status.lua:120` — not fixed; this plan keeps the loop unchanged.
- doc discipline — a line-number citation `spec §2.4:116`, and "nothing to roll up" now collides with milestone roll-up — `lib/status.lua:330-332` — not fixed.
- spec conformance — skip flag plus an approved, stale `spec.md` with no plans renders only `spec stale (intent changed)`, where spec §3.3 item 4 would append `intent approved (spec skipped)` — `lib/status.lua:383-386` — not fixed; open, author's call (record as an amendment or change the code).
- question — every artifact of a `done` or `dropped` chain is still read, so a done intent with an unparseable plan renders `INVALID` (probe P3); spec §3 and §9 disagree — this plan's decisions list — open, author's call (the same question raised at plan approval).

## Probe results

- Task 1: `grep -c 'BUILT })'` → `19`; `cargo make plugins-test` → `409 passed, 0 failed (21 files)`; `plugins-check` → `69 file(s) compiled, 0 failed`.
- Task 3: red `410 passed, 1 failed (21 files)` (`an_approved_chain_carries_the_fingerprints_of_its_intent_and_spec`); green `411 passed, 0 failed`; guard break `checked = true` → `410 passed, 1 failed` (`a_chain_whose_intent_is_not_approved_is_not_fingerprinted`); restored green.
- Task 4: red `414 passed, 8 failed (21 files)`, the eight tests this plan lists; green `422 passed, 0 failed`. Guard breaks: `PLAN_STATUSES` check off → `419 passed, 3 failed` (named guard plus two); `live` → `true` → `417 passed, 5 failed` (named guard plus four); `"drafted"` → `419 passed, 3 failed` (named guard plus two). Restored green at 422.
- Task 5: red `425 passed, 16 failed (21 files)`; green `441 passed, 0 failed`. Guard breaks: skip-path authority nil → `439 passed, 2 failed` (the named guard and `a_disproven_intent_on_the_skip_path_goes_to_intent`; the plan names only the first); `disproves ~= nil` → `440 passed, 1 failed`; superseded clause dropped → `440 passed, 1 failed`. Restored green at 441.
- Task 6: red `440 passed, 1 failed (21 files)` (`a_complete_chain_is_a_row_and_is_not_counted_in_the_tail`); green `441 passed, 0 failed`; `plugins-check` `69 file(s) compiled, 0 failed`. Test functions in `status_test.lua` after Task 6: 63 (31 + 2 + 11 + 19; Task 6 rewrote one).
- Task 7: `grep -c 'built-on'` → `artifact-chain.md:9`, `templates.md:2`; no `all seven keys|whose every plan`; sections `## 1.`–`## 10.` and `### 10.1`–`### 10.4` in order; step 10's grep finds all seven alternatives in `lib/status.lua` (lines 232, 246, 252, 317, 320, 324, 338, 340, 394).
- Fix round, each new test seen passing and then failing under its mutant: m09 → A1, A3 fail; m10 → A1, A2, A3; m11 → A1, A3; m12 → A5; m13 → A6; m14 → A4; m15 → A7. Each restored.
- Gate after the fix round, run by the orchestrator:

  ```
  69 file(s) compiled, 0 failed
  448 passed, 0 failed (21 files)
  fingerprint gate: 8 cases passed
  fingerprint gate: 8 cases passed with sha256sum
  ```

- Task 8, the board for this repository with the changed code:

  ```
  CHAIN                             STATE                         NEXT
  2026-08-29-claudevs-plugin-cache-hygiene  intent draft (triage)         review evidence
  2026-10-13-sdlc-roadmaps-milestones  plan 01 executing, plan 02 executing, plan 03 executing, plan 04 approved, plan 05 approved, plan 06 approved, plan 07 approved  wait (dependencies pending)
  DONE/DROPPED: 6 done, 2 dropped (not listed)
  ```

  This chain does not read `INVALID`. No earlier open chain reads `INVALID`: the only other
  row is a `draft` intent, which the sync rules do not check.

## Deviations

- **2026-10-14 — Task 2's checkpoint and Task 8's checkpoint not paused at.** The author's
  goal for the session was to execute plans 01 to 03 and directed execution to continue.
- **2026-10-14 — started before plan 01 was `done`.** Plan 01's code (Tasks 1–3) was in place
  and green; its Linux proof (Task 4) is still outstanding.
- **2026-10-14 — Task 7 ran in parallel with Task 3**, its files being disjoint; its step 10
  grep was run after Task 6.
- **2026-10-14 — no per-task briefs and no per-task commits.** Coders read their task from
  this plan's line ranges; committing is the author's act.
- **2026-10-14 — fix round adds seven tests: the suite is 448, not 441.** Every literal count
  in plan 04 (baseline 441; then 447, 472, 482, 486) and plan 06 (486, 490, 491) is now 7 low,
  and both plans were written against 441. Plan 07 reads its counts from the run. Plans 04 and
  06 are approved and not amended here; amending them is the `plan` skill's, on the author's
  word.
- **2026-10-14 — fix round edits text this plan gave verbatim**: two comments in
  `lib/status.lua`, two lines of `references/artifact-chain.md` (§7.2 walk-up row, §10.3 I1
  row), and the header comment above `FP` in `status_test.lua`.
