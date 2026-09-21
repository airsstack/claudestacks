---
status: approved
created: 2026-09-21
---

# Handoff Report Validator Implementation Plan

**Goal:** A tested Lua validator reports, by stable identifier, every way a handoff report file violates the protocol's schema.

**Architecture:** `scripts/lib/handoff_report.lua` holds the rules and nothing else; `scripts/handoff_report.lua` is a thin CLI driver that prints one line per violation and exits non-zero — the same split `handoff.lua` and `lib/handoff.lua` already use, so the logic is exercised against fixtures without going through a process. The module requires `lib.handoff` for `HANDOFF_REL` rather than repeating the path segment, so the session-tier test can never drift from the tree the session manager actually mints. Tag detection anchors at both ends of a line, which is what lets a report discuss `<summary>` in prose without being counted as carrying one.

**Tech Stack:** Lua 5.4 on `airsl`, `airsl test` for the suite, `cargo make plugins-test` as the gate.

---

### Task 1 — Fail on a report with no frontmatter

**Files:**
- Create `plugins/claudestacks/scripts/handoff_report_test.lua`
- Create `plugins/claudestacks/scripts/lib/handoff_report.lua`

**Steps:**

1. Write the failing test in `plugins/claudestacks/scripts/handoff_report_test.lua`:

   ```lua
   -- Tests for lib/handoff_report — schema conformance of a written handoff report.
   --
   --   airsl test --allow-read "$TMPDIR" --allow-write "$TMPDIR" --allow-read . plugins/claudestacks/scripts

   local report = require("lib.handoff_report")
   local fs = airsstack.fs
   local path = airsstack.path

   -- Writes `body` to a fresh temp file and returns its path. The name matters only where a test
   -- is about the path, so every test that is not names it plainly.
   local function written(body, name)
     local file = path.join(fs.tempdir(), name or "report.md")
     fs.write(file, body)
     return file
   end

   -- The violation identifiers from `report.check`, sorted, as one comparable string.
   local function ids(file)
     local found = {}
     for _, violation in ipairs(report.check(file)) do
       found[#found + 1] = violation.id
     end
     table.sort(found)
     return table.concat(found, ",")
   end

   return {
     a_report_without_frontmatter_is_a_violation = function()
       local file = written("<summary>\nfine\n</summary>\n")
       assert(ids(file):find("frontmatter%-missing"), ids(file))
     end,
   }
   ```

2. Run it and confirm failure — the module does not exist yet:

   ```
   $ airsl test --allow-read "$TMPDIR" --allow-write "$TMPDIR" --allow-read . plugins/claudestacks/scripts/handoff_report_test.lua
   airsl: lua error in plugins/claudestacks/scripts/handoff_report_test.lua: module 'lib.handoff_report' not found
   ```

   The file cannot even load, so no test runs. That is the expected red state for this first task.

3. Write the minimal implementation in `plugins/claudestacks/scripts/lib/handoff_report.lua`:

   ```lua
   -- Schema conformance for a written handoff report.
   --
   -- The rules live here and only here. Prose mirror:
   -- `skills/context-handoff/references/protocol.md`. The two MUST agree — change one, change the
   -- other.
   --
   -- Split from the driver so every rule is exercised against a fixture file rather than through a
   -- process, and so the hook wrapper and a driver checking a report by hand run identical logic.

   local fs = airsstack.fs

   local M = {}

   -- Reads the frontmatter block: the lines between a leading `---` and the next `---`.
   --
   -- Returns the key/value table and the index of the line after the closing marker, or nil when
   -- the file does not open with a block. A file whose first line is not `---` has no frontmatter
   -- at all; there is no recovery to attempt, so the caller stops there.
   function M.frontmatter(lines)
     if lines[1] ~= "---" then
       return nil, 1
     end
     local keys = {}
     for index = 2, #lines do
       if lines[index] == "---" then
         return keys, index + 1
       end
       local key, value = lines[index]:match("^([%w_-]+):%s*(.-)%s*$")
       if key then
         keys[key] = value
       end
     end
     return nil, 1
   end

   -- Every way `file` violates the schema, as a list of `{ id = ..., line = ... }`.
   function M.check(file)
     local ok, lines = pcall(fs.read_lines, file)
     if not ok then
       return { { id = "unreadable", line = "cannot read " .. file } }
     end

     local violations = {}
     local function fail(id, line)
       violations[#violations + 1] = { id = id, line = line }
     end

     local keys = M.frontmatter(lines)
     if not keys then
       fail("frontmatter-missing", "the file does not open with a `---` block")
     end

     return violations
   end

   return M
   ```

4. Run it and confirm green:

   ```
   $ airsl test --allow-read "$TMPDIR" --allow-write "$TMPDIR" --allow-read . plugins/claudestacks/scripts/handoff_report_test.lua
   plugins/claudestacks/scripts/handoff_report_test.lua
     ok    a_report_without_frontmatter_is_a_violation

   1 passed, 0 failed (1 files)
   ```

5. Commit `feat(repo): detect a handoff report written without frontmatter`.

---

### Task 2 — Fail on a missing or empty `agent:` or `task:`

**Files:**
- Modify `plugins/claudestacks/scripts/handoff_report_test.lua`
- Modify `plugins/claudestacks/scripts/lib/handoff_report.lua`

**Steps:**

1. Add the failing tests, inside the returned table:

   ```lua
     an_absent_agent_key_is_a_violation = function()
       local file = written("---\ntask: something\n---\n<summary>\nx\n</summary>\n")
       assert(ids(file):find("agent%-missing"), ids(file))
     end,

     an_empty_task_value_is_a_violation = function()
       local file = written("---\nagent: coder\ntask:\n---\n<summary>\nx\n</summary>\n")
       assert(ids(file):find("task%-missing"), ids(file))
     end,

     both_required_keys_present_is_clean_of_those_two = function()
       local file = written("---\nagent: coder\ntask: build the thing\n---\n<summary>\nx\n</summary>\n")
       local found = ids(file)
       assert(not found:find("agent%-missing"), found)
       assert(not found:find("task%-missing"), found)
     end,
   ```

2. Run and confirm the two new failures:

   ```
   $ airsl test --allow-read "$TMPDIR" --allow-write "$TMPDIR" --allow-read . plugins/claudestacks/scripts/handoff_report_test.lua
     FAIL  an_absent_agent_key_is_a_violation
     FAIL  an_empty_task_value_is_a_violation

   2 passed, 2 failed (1 files)
   ```

   `both_required_keys_present_is_clean_of_those_two` passes already — it asserts the absence of
   two identifiers that do not yet exist. It is a guard against over-strictness, not a red-first
   test, and is the only one in this task that does not go red.

3. In `M.check`, inside the `if not keys` … `else` branch, add the required-key rules:

   ```lua
     local keys = M.frontmatter(lines)
     if not keys then
       fail("frontmatter-missing", "the file does not open with a `---` block")
     else
       for _, key in ipairs({ "agent", "task" }) do
         if not keys[key] or keys[key] == "" then
           fail(key .. "-missing", "frontmatter is missing a non-empty `" .. key .. ":`")
         end
       end
     end
   ```

4. Run and confirm green:

   ```
   $ airsl test --allow-read "$TMPDIR" --allow-write "$TMPDIR" --allow-read . plugins/claudestacks/scripts/handoff_report_test.lua
   4 passed, 0 failed (1 files)
   ```

5. Commit `feat(repo): require agent and task in a handoff report's frontmatter`.

---

### Task 3 — Scope `session:` and `seq:` to the session tier

**Files:**
- Modify `plugins/claudestacks/scripts/handoff_report_test.lua`
- Modify `plugins/claudestacks/scripts/lib/handoff_report.lua`

**Steps:**

1. Confirm the constant this task keys off is where the spec says:

   ```
   $ grep -n 'HANDOFF_REL' plugins/claudestacks/scripts/lib/handoff.lua
   17:M.HANDOFF_REL = ".airsstack/cc/plugins/claudestacks/handoff"
   ```

2. Add the failing tests. The session-tier fixture puts the file under a path containing that
   segment; the other two tiers do not:

   ```lua
     a_session_tier_report_needs_session_and_seq = function()
       local handoff = require("lib.handoff")
       local dir = path.join(fs.tempdir(), handoff.HANDOFF_REL, "20260101-000000-ab")
       fs.mkdir(dir)
       local file = path.join(dir, "01-coder-thing.md")
       fs.write(file, "---\nagent: coder\ntask: t\n---\n<summary>\nx\n</summary>\n")
       local found = ids(file)
       assert(found:find("session%-missing"), found)
       assert(found:find("seq%-missing"), found)
     end,

     a_temp_path_report_must_not_carry_session_or_seq = function()
       local file = written(
         "---\nagent: chain-reader\ntask: t\nsession: 20260101-000000-ab\nseq: 01\n---\n<summary>\nx\n</summary>\n"
       )
       local found = ids(file)
       assert(found:find("session%-unexpected"), found)
       assert(found:find("seq%-unexpected"), found)
     end,

     an_init_refused_report_is_classified_with_the_exception = function()
       -- `<session-scratch>/handoff/` keeps the naming but mints no session, so neither key belongs.
       local dir = path.join(fs.tempdir(), "handoff")
       fs.mkdir(dir)
       local file = path.join(dir, "01-coder-thing.md")
       fs.write(file, "---\nagent: coder\ntask: t\n---\n<summary>\nx\n</summary>\n")
       local found = ids(file)
       assert(not found:find("session%-missing"), found)
       assert(not found:find("seq%-missing"), found)
     end,
   ```

3. Run and confirm the first two fail and the third passes vacuously:

   ```
   $ airsl test --allow-read "$TMPDIR" --allow-write "$TMPDIR" --allow-read . plugins/claudestacks/scripts/handoff_report_test.lua
     FAIL  a_session_tier_report_needs_session_and_seq
     FAIL  a_temp_path_report_must_not_carry_session_or_seq

   5 passed, 2 failed (1 files)
   ```

   `an_init_refused_report_is_classified_with_the_exception` passes vacuously here, for the same
   reason as the guard in Task 2: it asserts the absence of identifiers not yet implemented. It
   earns its keep in step 5, where it is the only test that would catch a tier check keyed on the
   `handoff/` directory name rather than on the full `HANDOFF_REL` segment.

4. Add the tier test and the two scoped rules. Require `lib.handoff` at the top of the module,
   beside the `fs` local:

   ```lua
   local handoff = require("lib.handoff")
   ```

   then, above `M.check`:

   ```lua
   -- Whether `file` sits under a minted session tree.
   --
   -- Keyed off the segment the session manager actually mints rather than a copy of the string, so
   -- the two can never disagree. Both other tiers — a literal temp path, and the
   -- `<session-scratch>/handoff/` fallback when `init` is refused — answer false, which is what
   -- makes `session:`/`seq:` forbidden in each.
   function M.session_tier(file)
     return file:find(handoff.HANDOFF_REL, 1, true) ~= nil
   end
   ```

   and inside the `else` branch of `M.check`, after the required-key loop:

   ```lua
       local session_tier = M.session_tier(file)
       for _, key in ipairs({ "session", "seq" }) do
         local present = keys[key] and keys[key] ~= ""
         if session_tier and not present then
           fail(key .. "-missing", "a session-tier report must carry `" .. key .. ":`")
         elseif not session_tier and present then
           fail(key .. "-unexpected", "`" .. key .. ":` belongs only to a session-tier report")
         end
       end
   ```

5. Run and confirm green:

   ```
   $ airsl test --allow-read "$TMPDIR" --allow-write "$TMPDIR" --allow-read . plugins/claudestacks/scripts/handoff_report_test.lua
   7 passed, 0 failed (1 files)
   ```

6. Commit `feat(repo): scope session and seq to session-tier handoff reports`.

---

### Task 4 — Require exactly one well-formed `<summary>` pair

**Files:**
- Modify `plugins/claudestacks/scripts/handoff_report_test.lua`
- Modify `plugins/claudestacks/scripts/lib/handoff_report.lua`

**Steps:**

1. Add the failing tests. The fourth is the one that matters most — it is the
   `01-foundations.md:564` failure, where an unanchored count saw prose as a tag:

   ```lua
     a_report_with_no_summary_pair_is_a_violation = function()
       local file = written("---\nagent: coder\ntask: t\n---\nbody with no tags\n")
       assert(ids(file):find("summary%-missing"), ids(file))
     end,

     two_summary_pairs_are_a_violation = function()
       local file = written(
         "---\nagent: coder\ntask: t\n---\n<summary>\na\n</summary>\n<summary>\nb\n</summary>\n"
       )
       assert(ids(file):find("summary%-repeated"), ids(file))
     end,

     an_unclosed_summary_is_a_violation = function()
       local file = written("---\nagent: coder\ntask: t\n---\n<summary>\na\n")
       assert(ids(file):find("summary%-unclosed"), ids(file))
     end,

     prose_discussing_the_tags_is_not_a_tag = function()
       -- The failure this rule exists for: an unanchored count returned 3 where 2 was expected,
       -- because a finding discussed the `<summary>`/`<detail>` schema in prose.
       local file = written(
         "---\nagent: artifact-reviewer\ntask: t\n---\n"
           .. "<summary>\nthe file wraps its halves in <summary> and <detail> tags\n</summary>\n"
       )
       assert(ids(file) == "", ids(file))
     end,

     a_tag_with_trailing_text_is_not_a_tag = function()
       local file = written("---\nagent: coder\ntask: t\n---\n<summary>text on the same line\n</summary>\n")
       assert(ids(file):find("summary%-missing"), ids(file))
     end,

     an_empty_summary_is_a_violation = function()
       local file = written("---\nagent: coder\ntask: t\n---\n<summary>\n\n  \n</summary>\n")
       assert(ids(file):find("summary%-empty"), ids(file))
     end,
   ```

2. Run and confirm five of the six go red. The sixth,
   `prose_discussing_the_tags_is_not_a_tag`, passes before the rule exists — it asserts that a
   conforming report produces no violations, and no summary rule is there to produce one. It is
   the regression guard for the anchoring decision in step 3, not a red-first test:

   ```
   $ airsl test --allow-read "$TMPDIR" --allow-write "$TMPDIR" --allow-read . plugins/claudestacks/scripts/handoff_report_test.lua
     FAIL  a_report_with_no_summary_pair_is_a_violation
     FAIL  two_summary_pairs_are_a_violation
     FAIL  an_unclosed_summary_is_a_violation
     FAIL  a_tag_with_trailing_text_is_not_a_tag
     FAIL  an_empty_summary_is_a_violation

   8 passed, 5 failed (1 files)
   ```

3. Add the tag scanner above `M.check`:

   ```lua
   -- Counts opening and closing tag lines for `name`, and whether any enclosed line has content.
   --
   -- A tag line is the tag ALONE on its line — anchored at both ends. A line reading
   -- `<summary>text` is body, not a tag. That is what lets a report discuss the schema in prose
   -- without the discussion being counted as structure, which an unanchored count got wrong.
   function M.tags(lines, name, from)
     local opens, closes, content = 0, 0, false
     local inside = false
     for index = from, #lines do
       local line = lines[index]
       if line == "<" .. name .. ">" then
         opens = opens + 1
         inside = true
       elseif line == "</" .. name .. ">" then
         closes = closes + 1
         inside = false
       elseif inside and line:match("%S") then
         content = true
       end
     end
     return opens, closes, content
   end
   ```

   and inside `M.check`, after the frontmatter rules (using the `body_from` index the frontmatter
   reader returns, so a `<summary>` line inside the frontmatter block is never counted):

   ```lua
     local opens, closes, content = M.tags(lines, "summary", body_from)
     if opens == 0 then
       fail("summary-missing", "no `<summary>` line of its own")
     elseif opens > 1 then
       fail("summary-repeated", "more than one `<summary>` pair")
     elseif closes < opens then
       fail("summary-unclosed", "`<summary>` with no matching `</summary>`")
     elseif not content then
       fail("summary-empty", "`<summary>` encloses only whitespace")
     end
   ```

   Capture the body index when reading the frontmatter, replacing the earlier single-value call:

   ```lua
     local keys, body_from = M.frontmatter(lines)
   ```

4. Run and confirm green:

   ```
   $ airsl test --allow-read "$TMPDIR" --allow-write "$TMPDIR" --allow-read . plugins/claudestacks/scripts/handoff_report_test.lua
   13 passed, 0 failed (1 files)
   ```

5. Commit `feat(repo): require exactly one well-formed summary pair`.

---

### Task 5 — Apply the same shape rules to `<detail>`, which is optional

**Files:**
- Modify `plugins/claudestacks/scripts/handoff_report_test.lua`
- Modify `plugins/claudestacks/scripts/lib/handoff_report.lua`

**Steps:**

1. Add the failing tests. `<detail>` is gated — absent is legal, malformed is not:

   ```lua
     an_absent_detail_is_legal = function()
       local file = written("---\nagent: coder\ntask: t\n---\n<summary>\nx\n</summary>\n")
       assert(ids(file) == "", ids(file))
     end,

     two_detail_pairs_are_a_violation = function()
       local file = written(
         "---\nagent: coder\ntask: t\n---\n<summary>\nx\n</summary>\n"
           .. "<detail>\na\n</detail>\n<detail>\nb\n</detail>\n"
       )
       assert(ids(file):find("detail%-repeated"), ids(file))
     end,

     an_unclosed_detail_is_a_violation = function()
       local file = written(
         "---\nagent: coder\ntask: t\n---\n<summary>\nx\n</summary>\n<detail>\na\n"
       )
       assert(ids(file):find("detail%-unclosed"), ids(file))
     end,
   ```

2. Run and confirm the two new failures:

   ```
   $ airsl test --allow-read "$TMPDIR" --allow-write "$TMPDIR" --allow-read . plugins/claudestacks/scripts/handoff_report_test.lua
     FAIL  two_detail_pairs_are_a_violation
     FAIL  an_unclosed_detail_is_a_violation

   14 passed, 2 failed (1 files)
   ```

   `an_absent_detail_is_legal` passes already — `<detail>` is gated, so its absence was never a
   violation. It is the guard that keeps step 3 from making the optional section mandatory.

3. Add the `<detail>` rules in `M.check`, directly after the `<summary>` block. There is no
   `detail-missing` and no `detail-empty`: the protocol gates the section, so absent is correct
   and an author who opened one with nothing in it has a formatting slip the summary rules do not
   model:

   ```lua
     local detail_opens, detail_closes = M.tags(lines, "detail", body_from)
     if detail_opens > 1 then
       fail("detail-repeated", "more than one `<detail>` pair")
     elseif detail_closes < detail_opens then
       fail("detail-unclosed", "`<detail>` with no matching `</detail>`")
     end
   ```

4. Run and confirm green:

   ```
   $ airsl test --allow-read "$TMPDIR" --allow-write "$TMPDIR" --allow-read . plugins/claudestacks/scripts/handoff_report_test.lua
   16 passed, 0 failed (1 files)
   ```

5. Commit `feat(repo): check the optional detail section's shape`.

---

### Task 6 — Add one clean fixture per tier

**Files:**
- Modify `plugins/claudestacks/scripts/handoff_report_test.lua`

**Steps:**

1. Add three tests asserting a conforming report of each tier produces no violations at all. These
   are the ones that catch a rule that is too strict, which the per-violation tests cannot:

   ```lua
     a_conforming_session_tier_report_is_clean = function()
       local handoff = require("lib.handoff")
       local dir = path.join(fs.tempdir(), handoff.HANDOFF_REL, "20260101-000000-ab")
       fs.mkdir(dir)
       local file = path.join(dir, "03-reviewer-diff.md")
       fs.write(
         file,
         "---\nagent: reviewer\ntask: review the batch diff\nsession: 20260101-000000-ab\nseq: 03\n---\n"
           .. "<summary>\nblocking: none\n</summary>\n<detail>\nthe full list\n</detail>\n"
       )
       assert(ids(file) == "", ids(file))
     end,

     a_conforming_exception_tier_report_is_clean = function()
       local file = written(
         "---\nagent: artifact-reviewer\ntask: review spec.md against intent.md\n---\n"
           .. "<summary>\nSPEC: none blocking\n</summary>\n<detail>\nthe findings\n</detail>\n",
         "claudestacks-sdlc-chain-spec-01.md"
       )
       assert(ids(file) == "", ids(file))
     end,

     a_conforming_init_refused_report_is_clean = function()
       local dir = path.join(fs.tempdir(), "handoff")
       fs.mkdir(dir)
       local file = path.join(dir, "02-explorer-map.md")
       fs.write(
         file,
         "---\nagent: explorer\ntask: map the transport module\n---\n<summary>\n12 files\n</summary>\n"
       )
       assert(ids(file) == "", ids(file))
     end,
   ```

2. Run and confirm green. **These three are deliberately not red-first, and that is the only
   exception in this plan.** A clean-report fixture asserts the absence of violations, which is
   trivially true before any rule exists, so a red state for it is unobtainable rather than
   skipped. What they catch is the opposite failure — a rule stricter than the schema — and they
   catch it the moment such a rule is added. Record them in the execution record as guards, not as
   red-green cycles; claiming a red state nobody saw is the thing the discipline exists to stop.

   If any of the three fails, a rule added above is stricter than the schema and the rule is wrong,
   not the fixture:

   ```
   $ airsl test --allow-read "$TMPDIR" --allow-write "$TMPDIR" --allow-read . plugins/claudestacks/scripts/handoff_report_test.lua
   19 passed, 0 failed (1 files)
   ```

3. Commit `test(repo): assert a conforming report of each tier validates clean`.

---

### Task 7 — Add the CLI driver

**Files:**
- Create `plugins/claudestacks/scripts/handoff_report.lua`

**Steps:**

1. Write the driver:

   ```lua
   -- Handoff report conformance checker.
   --
   -- Rules live in `lib/handoff_report.lua`. Prose mirror:
   -- `skills/context-handoff/references/protocol.md`.
   --
   --   airsl run --policy confined --allow-read / \
   --     scripts/handoff_report.lua <path-to-report>
   --
   -- The read grant must cover the directory the report sits in. `--allow-read .` does not: an
   -- exception-tier report is a literal temp path outside the tree, and the denial surfaces as
   -- `unreadable`, which is indistinguishable from a malformed report.
   --
   -- Prints nothing and exits 0 when the report conforms; otherwise prints one line per violation
   -- to stdout and exits non-zero. Violations go to STDOUT rather than stderr because the hook
   -- wrapper captures them as the reason text it hands back — a traceback on stderr would reach
   -- the agent instead of the reason.

   local report = require("lib.handoff_report")
   local stdio = airsstack.stdio

   local file = arg[1]
   if not file or file == "" then
     stdio.error("usage: handoff_report.lua <path-to-report>\n")
     error("missing path", 0)
   end

   local violations = report.check(file)
   if #violations == 0 then
     return
   end

   local lines = {}
   for _, violation in ipairs(violations) do
     lines[#lines + 1] = violation.id .. ": " .. violation.line
   end
   stdio.write(table.concat(lines, "\n") .. "\n")
   error("handoff report does not conform", 0)
   ```

2. Check it against a deliberately broken report and confirm the output shape:

   ```
   $ printf '<summary>\nx\n</summary>\n' > "${TMPDIR:-/tmp}/bad-report.md"
   $ airsl run --policy confined --allow-read / \
       plugins/claudestacks/scripts/handoff_report.lua "${TMPDIR:-/tmp}/bad-report.md"
   frontmatter-missing: the file does not open with a `---` block
   airsl: lua error in plugins/claudestacks/scripts/handoff_report.lua: runtime error: handoff report does not conform
   stack traceback:
   	[C]: in ?
   	[C]: in function 'error'
   	...plugins/claudestacks/scripts/handoff_report.lua:NN: in main chunk
   ```

   The violations go to stdout; the error line and its traceback go to stderr. That separation is
   what plan `06`'s launcher depends on — it reads stdout to decide whether to block, so a
   traceback can never reach an agent in place of a readable reason.

3. Check it against a conforming report and confirm silence:

   ```
   $ printf -- '---\nagent: coder\ntask: t\n---\n<summary>\nx\n</summary>\n' > "${TMPDIR:-/tmp}/good-report.md"
   $ airsl run --policy confined --allow-read / \
       plugins/claudestacks/scripts/handoff_report.lua "${TMPDIR:-/tmp}/good-report.md"
   $ echo "exit=$?"
   exit=0
   ```

4. Commit `feat(repo): add the handoff report checker CLI`.

---

### Task 8 — Re-anchor the assertions the absorbed chain left broken

**Files:**
- Modify `.claudestacks/sdlc/2026-08-25-sdlc-agent-tier/plans/01-foundations.md`
- Modify `.claudestacks/sdlc/2026-08-25-sdlc-agent-tier/plans/03-distill-wiring.md`

**Steps:**

1. Read the assertion that returned 3 where 2 was expected:

   ```
   $ sed -n '562,566p' .claudestacks/sdlc/2026-08-25-sdlc-agent-tier/plans/01-foundations.md
   ```

2. Replace its unanchored `grep -c` with the checker this plan just built. The assertion was
   counting tags as a proxy for conformance; there is now a thing that checks conformance
   directly:

   ```
   airsl run --policy confined --allow-read / \
     plugins/claudestacks/scripts/handoff_report.lua <the report path>
   ```

   with expected output: no output, exit 0.

3. Read the verbatim-diff step:

   ```
   $ sed -n '196,208p' .claudestacks/sdlc/2026-08-25-sdlc-agent-tier/plans/03-distill-wiring.md
   ```

   It compares two sides. The **source** side —
   `sed -n '/^## Review findings/,/^## /p' <source plan>` — is the reference and is correct;
   leave it exactly as it is. The **report** side is the one written against a shape that has
   since changed. **Add** the report-side extraction as its counterpart rather than replacing the
   source-side sed, which would destroy the comparison:

   ```
   sed -n '/^<detail>$/,/^<\/detail>$/p' <report> | sed '1d;$d'
   ```

   The two outputs are then diffed against each other. If the existing step already has a
   report-side command, replace that one and only that one.

4. `01-foundations.md` carries the same unanchored count a **third** time, at the
   `chain-reader` step — the plan's Task 1 pointer named only `:562-566`. Re-anchor that one
   the same way as step 2; step 4's assertion below covers the whole directory and fails
   otherwise.

5. Confirm neither plan still carries the unanchored count:

   ```
   $ grep -rn 'grep -c "<summary>' .claudestacks/sdlc/2026-08-25-sdlc-agent-tier/plans/
   $ echo "exit=$?"
   exit=1
   ```

6. Both plans are `status: approved` and stay so — this corrects an assertion, it does not
   redesign the plan. Commit `fix(repo): re-anchor the handoff assertions in the sdlc-agent-tier plans`.

---

### Task 9 — Run the plugin gate

**Files:**
- None — verification only.

**Steps:**

1. Compile every Lua file in the tree, including the two new ones:

   ```
   $ cargo make plugins-check
   [cargo-make] INFO - Running Task: plugins-check
   ...
   [cargo-make] INFO - Build Done
   ```

2. Run the whole Lua suite, not only the new file — the new module requires `lib.handoff`, and a
   mistake there would surface in `handoff_test.lua`:

   ```
   $ cargo make plugins-test
   [cargo-make] INFO - Running Task: plugins-test
   ...
   [cargo-make] INFO - Build Done
   ```

3. Confirm the new file joins the directory's suite rather than only passing in isolation. Before
   this plan `plugins/claudestacks/scripts/` held three test files totalling 99 assertions; this
   plan adds a fourth with 19:

   ```
   $ airsl test --allow-read "$TMPDIR" --allow-write "$TMPDIR" --allow-read . plugins/claudestacks/scripts
   ...
   118 passed, 0 failed (4 files)
   ```

   If the file count is 3, `handoff_report_test.lua` is not being discovered — check the name
   matches `*_test.lua`. Task 10 adds four more assertions on top, taking this to 122 and the
   whole tree to 313 — run this task again after it.

4. Commit nothing — this task changes no files. If either command is red, the failure belongs to
   an earlier task in this plan and is fixed there.

---

### Task 10 — Report the two failures the schema table left conflated

**Files:**
- Modify `plugins/claudestacks/scripts/lib/handoff_report.lua`
- Modify `plugins/claudestacks/scripts/handoff_report_test.lua`

**Why this task exists:** review of Tasks 1–9 found the validator emitting a sentence that is false
of its input, and one identifier covering two unrelated causes. `spec.md` §7's table was amended
on 2026-09-21 to add the four rows this task implements; it is the authority, not this plan's
earlier tasks. Both matter because plan `06`'s hook hands this text to an agent as the reason its
report was blocked — a wrong reason sends it to hunt the wrong defect.

**Steps:**

1. Write the failing tests first and confirm each is red before touching the module:

   - `an_absent_file_is_unreadable` — a path that does not exist yields `unreadable`.
   - `a_denied_read_classifies_separately_from_an_absent_file` — the classifier, called directly on
     the two real `airsl` error strings. The suite runs with `--allow-read /`, so a genuine
     confinement refusal cannot be provoked from inside it; the classifier is tested against the
     literal strings instead.
   - `an_unterminated_frontmatter_is_not_reported_as_missing`
   - `a_missing_frontmatter_is_not_reported_as_unterminated` — the control. Without it the third
     test passes just as well against a module that reports everything as unterminated.

2. Split the read failure. `M.check`'s `pcall(fs.read_lines, file)` classifies its error through a
   new `M.classify_read_error`, which matches on `outside the granted read roots` — the phrase
   specific to a confinement denial, probed against `airsl` 0.1.2 on 2026-09-21:

   ```
   fs.read_lines denied: `/private/etc/hosts` is outside the granted read roots: /private/tmp/claude-501
   read_lines failed on `/private/tmp/claude-501/absent-file.md`: No such file or directory (os error 2)
   ```

   Match that phrase rather than the bare word `denied`, which an OS-level permission error could
   carry without being a confinement decision. Anything unmatched stays `unreadable`.

3. Give `M.frontmatter` a third return value so `M.check` can tell its two failures apart:
   `"missing"` when line 1 is not `---`, `"unterminated"` when a block opened and the loop ran out
   of lines. Report `frontmatter-unterminated` for the second, with a line that is true of it.

4. Confirm green, and that the counts rose by exactly four:

   ```
   $ cargo make plugins-check
   59 file(s) compiled, 0 failed
   $ cargo make plugins-test
   313 passed, 0 failed (17 files)
   ```

5. Commit `fix(repo): tell a denied read and an unterminated block from what they are not`.
