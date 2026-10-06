---
status: approved
created: 2026-10-04
---

# Communication Report Validator Implementation Plan

**Goal:** A report that declares the communication protocol but breaks its additions is caught by a hook before the agent hands it back.

**Architecture:** `scripts/lib/comm_report.lua` holds the rules (spec §4) and the topic parser that plan 03 reuses; it requires `lib.handoff_report` for its frontmatter reader rather than writing a second one. `scripts/comm_check_hook.lua` is the hook driver: it finds the report with `lib.handoff_report.file_from_payload` and emits per event. `hooks/comm-check.sh` is a launcher copied from `hooks/handoff-check.sh`. All three live under `scripts/`/`hooks/` because `airsl` resolves `require` only beside the running script (spec P2). Reports without `protocol:` produce nothing, so every existing agent is untouched (spec P1).

**Tech Stack:** `airsl` Lua 5.4 (`airsstack.fs`, `airsstack.regex`, `airsstack.hook`, `airsstack.stdio`), POSIX `sh`, Claude Code `hooks.json`.

---

## File structure

```
plugins/claudestacks/scripts/lib/comm_report.lua   — [create] rules, topic parser, per-event hook output
plugins/claudestacks/scripts/comm_report_test.lua  — [create] tests for lib/comm_report
plugins/claudestacks/scripts/comm_check_hook.lua   — [create] hook driver
plugins/claudestacks/hooks/comm-check.sh           — [create] launcher; exit 2 only on violations
plugins/claudestacks/hooks/hooks.json              — [modify] register on PostToolUse Write, PreToolUse SubagentHandback, SubagentStop
```

Facts this plan encodes, each checked on 2026-10-04:

- `lib.handoff_report.frontmatter(lines)` returns `keys, body_from` or `nil, 1, reason` (`scripts/lib/handoff_report.lua:157-172`); a tag line is the tag alone on its line (`:206-209`).
- `lib.handoff_report.file_from_payload(payload)` returns the report path for `PostToolUse`, `PreToolUse`, `SubagentStop`, or nil (`:362-378`).
- `regex.compile(p).captures(s)` returns a table with `[1]`, `[2]` for a match (probe: `captures("12. hello world")` → `12`, `hello world`) and nil for none (`hooks/lib/concise.lua:61-62` relies on it).
- `airsstack.hook.emit({decision = "block", reason = …})` is the PostToolUse output (`scripts/handoff_check_hook.lua:59-60`); the gate events print to stdout and the launcher exits 2 (`hooks/handoff-check.sh:36-44`).
- Exit 2 blocks on `PreToolUse` and keeps the subagent running on `SubagentStop` (spec P11); a hook group with no `matcher` fires on every event (`hooks.md:293`).
- Test runs go through `cargo make plugins-test` (`Makefile.toml:143`).

### Task 1 — Parse a topics block

**Files:**
- Test `plugins/claudestacks/scripts/comm_report_test.lua`
- Create `plugins/claudestacks/scripts/lib/comm_report.lua`

**Steps:**

1. Write the failing test in `plugins/claudestacks/scripts/comm_report_test.lua`:

   ```lua
   -- Tests for lib/comm_report — the communication protocol's report additions.
   --
   --   cargo make plugins-test

   local comm = require("lib.comm_report")

   local function lines_of(text)
     local out = {}
     for line in (text .. "\n"):gmatch("(.-)\n") do
       out[#out + 1] = line
     end
     return out
   end

   return {
     topics_are_parsed_in_order_with_trailing_space_trimmed = function()
       local topics, malformed = comm.topics(lines_of("<topics>\n1. first \n\n2. second\n</topics>"), 1)
       assert(#topics == 2 and #malformed == 0)
       assert(topics[1].n == 1 and topics[1].title == "first")
       assert(topics[2].n == 2 and topics[2].title == "second")
     end,

     a_line_that_is_not_n_dot_title_is_malformed = function()
       local topics, malformed = comm.topics(lines_of("<topics>\n- first\n1. ok\n</topics>"), 1)
       assert(#topics == 1 and #malformed == 1 and malformed[1] == "- first")
     end,

     no_topics_block_means_nil = function()
       assert(comm.topics(lines_of("<summary>\nx\n</summary>"), 1) == nil)
     end,
   }
   ```

2. Run it and confirm failure:

   ```
   $ cargo make plugins-test
   …/plugins/claudestacks/scripts/comm_report_test.lua: lua error in …/comm_report_test.lua: module `lib.comm_report` not found under `…/plugins/claudestacks/scripts`
   ```

3. Write the minimal implementation in `plugins/claudestacks/scripts/lib/comm_report.lua`:

   ```lua
   -- The communication protocol's additions to a Context Handoff report.
   --
   -- Prose authority: `skills/discuss/references/protocol.md`. The base schema (frontmatter,
   -- one <summary>, at most one <detail>) is `lib/handoff_report.lua`'s and is not re-checked
   -- here; this module only checks what the communication protocol adds.

   local report = require("lib.handoff_report")
   local fs = airsstack.fs
   local regex = airsstack.regex

   local M = {}

   M.VERSION = "discuss/1"
   M.MAX_SUMMARY_LINES = 6

   local TOPIC = regex.compile([[^(\d+)\. (\S.*)$]])

   -- The lines between the first `<name>` and its `</name>`, each tag alone on its line — or nil
   -- when the block never opens. An unclosed block returns what it holds; the base validator
   -- reports the missing close.
   function M.block(lines, name, from)
     local inner
     for index = from or 1, #lines do
       local line = lines[index]
       if not inner and line == "<" .. name .. ">" then
         inner = {}
       elseif inner and line == "</" .. name .. ">" then
         return inner
       elseif inner then
         inner[#inner + 1] = line
       end
     end
     return inner
   end

   -- The topics in a report's <topics> block as `{ n, title }`, plus the non-blank lines that are
   -- not `N. <title>`. Nil when there is no <topics> block.
   function M.topics(lines, from)
     local inner = M.block(lines, "topics", from)
     if not inner then
       return nil
     end
     local found, malformed = {}, {}
     for _, line in ipairs(inner) do
       if line:match("%S") then
         local parts = TOPIC.captures(line)
         if parts then
           found[#found + 1] = { n = tonumber(parts[1]), title = parts[2]:match("^(.-)%s*$") }
         else
           malformed[#malformed + 1] = line
         end
       end
     end
     return found, malformed
   end

   return M
   ```

4. Run it and confirm green:

   ```
   $ cargo make plugins-test
     ok    topics_are_parsed_in_order_with_trailing_space_trimmed
     ok    a_line_that_is_not_n_dot_title_is_malformed
     ok    no_topics_block_means_nil
   ```

   Break it: change `if line:match("%S") then` to `if true then` (blank lines now count as malformed), rerun, confirm `FAIL  topics_are_parsed_in_order_with_trailing_space_trimmed`. Restore.

5. Commit `feat(repo): parse the communication protocol's topics block`.

### Task 2 — Check the additions

**Files:**
- Test `plugins/claudestacks/scripts/comm_report_test.lua`
- Modify `plugins/claudestacks/scripts/lib/comm_report.lua`

**Steps:**

1. Add to `comm_report_test.lua`, above `return {`:

   ```lua
   local VALID = table.concat({
     "---",
     "agent: reviewer",
     "task: review x",
     "protocol: discuss/1",
     "---",
     "<summary>",
     "Two findings; one blocks.",
     "</summary>",
     "<topics>",
     "1. classifier false triggers",
     "2. machine-wide flag",
     "</topics>",
     "<detail>",
     "## 1. classifier false triggers",
     "body",
     "## 2. machine-wide flag",
     "body",
     "</detail>",
   }, "\n")

   local function ids(violations)
     local out = {}
     for _, v in ipairs(violations) do
       out[#out + 1] = v.id
     end
     return table.concat(out, ",")
   end

   local function with(old, new)
     local text = VALID:gsub(old, new, 1)
     return lines_of(text)
   end
   ```

   and these entries inside the returned table:

   ```lua
     a_conforming_report_has_no_violations = function()
       assert(ids(comm.check_lines(lines_of(VALID))) == "")
     end,

     a_report_without_protocol_is_not_ours = function()
       assert(ids(comm.check_lines(with("protocol: discuss/1\n", ""))) == "")
     end,

     add_requires_protocol = function()
       local lines = with("protocol: discuss/1\n", "")
       assert(ids(comm.check_lines(lines, { require_protocol = true })) == "protocol-missing")
     end,

     an_unknown_protocol_version_is_named = function()
       assert(ids(comm.check_lines(with("discuss/1", "discuss/2"))) == "protocol-unknown")
     end,

     a_summary_over_six_lines_is_too_long = function()
       local lines = with("Two findings; one blocks.", "a\nb\nc\nd\ne\nf\ng")
       assert(ids(comm.check_lines(lines)) == "summary-too-long")
     end,

     detail_without_topics_is_missing_topics = function()
       local lines = with("<topics>\n1%. classifier false triggers\n2%. machine%-wide flag\n</topics>\n", "")
       assert(ids(comm.check_lines(lines)) == "topics-missing")
     end,

     topics_without_detail_are_named = function()
       local lines = with("<detail>.*</detail>", "")
       assert(ids(comm.check_lines(lines)) == "topics-without-detail")
     end,

     a_malformed_topic_line_is_named = function()
       assert(ids(comm.check_lines(with("2%. machine%-wide flag\n</topics>", "two. machine-wide flag\n</topics>")))
         == "topics-malformed")
     end,

     out_of_order_numbers_are_named = function()
       local lines = with("2%. machine%-wide flag\n</topics>", "3. machine-wide flag\n</topics>")
       assert(ids(comm.check_lines(lines)):find("topics-numbering", 1, true))
     end,

     a_topic_without_its_heading_is_named = function()
       assert(ids(comm.check_lines(with("## 2%. machine%-wide flag", "## 2. other title")))
         == "topic-heading-missing")
     end,
   ```

2. Run it and confirm failure:

   ```
   $ cargo make plugins-test
     FAIL  a_conforming_report_has_no_violations
     …
   ```

   (each new test with `attempt to call a nil value (field 'check_lines')`).

3. Add to `plugins/claudestacks/scripts/lib/comm_report.lua`, above `return M`:

   ```lua
   -- Every way `lines` breaks the communication protocol's additions, as `{ id, line }`.
   --
   -- A report with no `protocol:` key is not a communication-protocol report and returns nothing,
   -- unless `opts.require_protocol` is set — `discuss.lua add` sets it, the hook never does.
   function M.check_lines(lines, opts)
     opts = opts or {}
     local violations = {}
     local function fail(id, line)
       violations[#violations + 1] = { id = id, line = line }
     end

     local keys, body_from = report.frontmatter(lines)
     local declared = keys and keys.protocol
     if not declared or declared == "" then
       if opts.require_protocol then
         fail("protocol-missing", "no `protocol:` key in the frontmatter")
       end
       return violations
     end
     if declared ~= M.VERSION then
       fail("protocol-unknown", "`protocol: " .. declared .. "` is not `" .. M.VERSION .. "`")
       return violations
     end

     local summary = M.block(lines, "summary", body_from)
     if summary then
       local count = 0
       for _, line in ipairs(summary) do
         if line:match("%S") then
           count = count + 1
         end
       end
       if count > M.MAX_SUMMARY_LINES then
         fail("summary-too-long", "<summary> has " .. count .. " lines; at most "
           .. M.MAX_SUMMARY_LINES)
       end
     end

     local detail = M.block(lines, "detail", body_from)
     local topics, malformed = M.topics(lines, body_from)
     if detail and not topics then
       fail("topics-missing", "<detail> is present but there is no <topics> block")
     end
     if topics and not detail then
       fail("topics-without-detail", "<topics> is present but there is no <detail> block")
     end
     if not topics then
       return violations
     end

     for _, line in ipairs(malformed) do
       fail("topics-malformed", "not `N. <title>`: " .. line)
     end
     for index, topic in ipairs(topics) do
       if topic.n ~= index then
         fail("topics-numbering", "topic " .. index .. " is numbered " .. topic.n)
         break
       end
     end
     if detail then
       local present = {}
       for _, line in ipairs(detail) do
         present[line] = true
       end
       for _, topic in ipairs(topics) do
         local heading = "## " .. topic.n .. ". " .. topic.title
         if not present[heading] then
           fail("topic-heading-missing", "no `" .. heading .. "` line in <detail>")
         end
       end
     end
     return violations
   end

   -- `check_lines` over a file. An unreadable file returns nothing: the base validator owns
   -- that report, and both run on the same file.
   function M.check(file, opts)
     local ok, lines = pcall(fs.read_lines, file)
     if not ok then
       return {}
     end
     return M.check_lines(lines, opts)
   end
   ```

4. Run it and confirm green:

   ```
   $ cargo make plugins-test
     ok    a_conforming_report_has_no_violations
     ok    a_report_without_protocol_is_not_ours
     ok    add_requires_protocol
     ok    an_unknown_protocol_version_is_named
     ok    a_summary_over_six_lines_is_too_long
     ok    detail_without_topics_is_missing_topics
     ok    topics_without_detail_are_named
     ok    a_malformed_topic_line_is_named
     ok    out_of_order_numbers_are_named
     ok    a_topic_without_its_heading_is_named
   ```

   Break it: change `count > M.MAX_SUMMARY_LINES` to `count > M.MAX_SUMMARY_LINES + 1`, rerun, confirm `FAIL  a_summary_over_six_lines_is_too_long`. Restore.

5. Commit `feat(repo): check the communication protocol's report additions`.

### Task 3 — A conforming report stays a valid handoff report

**Files:**
- Test `plugins/claudestacks/scripts/comm_report_test.lua`

**Steps:**

1. Add `local fs = airsstack.fs`, `local path = airsstack.path` and `local handoff = require("lib.handoff_report")` under the existing `require` at the top, and this entry to the returned table:

   ```lua
     the_conforming_fixture_passes_both_validators_from_disk = function()
       local file = path.join(fs.tempdir(), "01-reviewer-x.md")
       fs.write(file, VALID .. "\n")
       assert(#handoff.check(file) == 0, "base validator rejected a communication report")
       assert(#comm.check(file) == 0)
     end,
   ```

2. Run it:

   ```
   $ cargo make plugins-test
     ok    the_conforming_fixture_passes_both_validators_from_disk
   ```

   This test pins spec P1 rather than new code, so its red step is a mutation: change `"---",` (the first line of `VALID`) to `"--",`, rerun, confirm `FAIL  the_conforming_fixture_passes_both_validators_from_disk`. Restore.

3. Commit `test(repo): pin that a communication report stays a valid handoff report`.

### Task 4 — Per-event hook output

**Files:**
- Test `plugins/claudestacks/scripts/comm_report_test.lua`
- Modify `plugins/claudestacks/scripts/lib/comm_report.lua`

**Steps:**

1. Add to the returned table in `comm_report_test.lua`:

   ```lua
     post_tool_use_emits_a_block_decision = function()
       local out = comm.hook_output("PostToolUse", { { id = "topics-missing", line = "x" } })
       assert(out.kind == "emit" and out.value.decision == "block")
       assert(out.value.reason:find("topics-missing: x", 1, true))
     end,

     the_gate_events_write_to_stdout = function()
       for _, event in ipairs({ "PreToolUse", "SubagentStop" }) do
         local out = comm.hook_output(event, { { id = "topics-missing", line = "x" } })
         assert(out.kind == "stdout" and out.value:find("topics-missing: x", 1, true), event)
       end
     end,

     no_violations_means_no_output = function()
       assert(comm.hook_output("PreToolUse", {}) == nil)
     end,
   ```

2. Run it and confirm failure:

   ```
   $ cargo make plugins-test
     FAIL  post_tool_use_emits_a_block_decision
     FAIL  the_gate_events_write_to_stdout
     FAIL  no_violations_means_no_output
   ```

3. Add to `plugins/claudestacks/scripts/lib/comm_report.lua`, above `return M`:

   ```lua
   -- What the hook driver does about `violations` on `event`: nil for nothing, `{ kind = "emit" }`
   -- for PostToolUse (the file is written; attach the reason so the agent rewrites it), or
   -- `{ kind = "stdout" }` for the gate events, which the launcher turns into exit 2.
   function M.hook_output(event, violations)
     if #violations == 0 then
       return nil
     end
     local found = {}
     for _, violation in ipairs(violations) do
       found[#found + 1] = violation.id .. ": " .. violation.line
     end
     local reason = "communication protocol report does not conform:\n" .. table.concat(found, "\n")
     if event == "PostToolUse" then
       return { kind = "emit", value = { decision = "block", reason = reason } }
     end
     return { kind = "stdout", value = reason .. "\n" }
   end
   ```

4. Run it and confirm green:

   ```
   $ cargo make plugins-test
     ok    post_tool_use_emits_a_block_decision
     ok    the_gate_events_write_to_stdout
     ok    no_violations_means_no_output
   ```

   Break it: change `event == "PostToolUse"` to `event == "PreToolUse"`, rerun, confirm both event tests fail. Restore.

5. Commit `feat(repo): choose the communication check's output per hook event`.

### Task 5 — Hook driver, launcher, registration

**Files:**
- Create `plugins/claudestacks/scripts/comm_check_hook.lua`
- Create `plugins/claudestacks/hooks/comm-check.sh`
- Modify `plugins/claudestacks/hooks/hooks.json`

**Steps:**

1. Build the fixtures and a check script, then confirm the launcher is absent (red). The worktree guard refuses fixture `printf`s and pipelines carrying `$PWD` inline, so they go through files. Resolve the temp directory with the plain command `echo "$TMPDIR"`; `<TMP>` below is its output pasted as a literal, without the trailing `/`.

   Create `<TMP>/01-reviewer-comm-bad.md` with the Write tool (declares the protocol, has `<detail>`, no `<topics>`):

   ```
   ---
   agent: reviewer
   task: t
   protocol: discuss/1
   ---
   <summary>
   s
   </summary>
   <detail>
   d
   </detail>
   ```

   Create `<TMP>/01-reviewer-comm-plain.md` with the Write tool (no `protocol:` key — any other agent's report):

   ```
   ---
   agent: reviewer
   task: t
   ---
   <summary>
   s
   </summary>
   <detail>
   d
   </detail>
   ```

   Create `<TMP>/plan02-hook.sh` with the Write tool:

   ```sh
   # Run from the repository root.
   T='<TMP>'
   for name in 01-reviewer-comm-bad.md 01-reviewer-comm-plain.md; do
     printf '{"hook_event_name":"PreToolUse","tool_name":"SubagentHandback","tool_input":{"message":"done, report at %s/%s"},"cwd":"%s"}' "$T" "$name" "$PWD" \
       | sh plugins/claudestacks/hooks/comm-check.sh
     echo "exit=$?"
   done
   printf '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"%s/01-reviewer-comm-bad.md"},"cwd":"%s"}' "$T" "$PWD" \
     | sh plugins/claudestacks/hooks/comm-check.sh
   echo "exit=$?"
   ```

   ```
   $ sh <TMP>/plan02-hook.sh
   sh: plugins/claudestacks/hooks/comm-check.sh: No such file or directory
   exit=127
   sh: plugins/claudestacks/hooks/comm-check.sh: No such file or directory
   exit=127
   sh: plugins/claudestacks/hooks/comm-check.sh: No such file or directory
   exit=127
   ```

2. Create `plugins/claudestacks/scripts/comm_check_hook.lua`:

   ```lua
   -- Communication protocol report conformance hook.
   --
   -- Rules live in `lib/comm_report.lua`. Prose mirror: `skills/discuss/references/protocol.md`.
   -- Runs on the same three events as `handoff_check_hook.lua`, beside it; acts only on a report
   -- carrying `protocol:`, so every other agent's report passes through untouched.
   --
   -- Violations go to STDOUT, never stderr: `hooks/comm-check.sh` captures this script's stdout to
   -- decide whether to block and discards its stderr.

   local report = require("lib.handoff_report")
   local comm = require("lib.comm_report")

   local payload = airsstack.hook.payload()
   if type(payload) ~= "table" then
     return
   end

   local file = report.file_from_payload(payload)
   if not file then
     return
   end

   local out = comm.hook_output(payload.hook_event_name, comm.check(file))
   if not out then
     return
   end
   if out.kind == "emit" then
     airsstack.hook.emit(out.value)
   else
     airsstack.stdio.write(out.value)
   end
   ```

3. Create `plugins/claudestacks/hooks/comm-check.sh`:

   ```sh
   #!/bin/sh
   # claudestacks communication-protocol report conformance launcher.
   #
   # Same exit rules as `handoff-check.sh`: exit 2 only when the Lua wrote violations to stdout
   # on a gate event; any other failure (airsl missing, script error, unreadable file) exits 0,
   # because a broken checker must never hold a correct report.

   DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || exit 0
   [ -n "$DIR" ] || exit 0

   # Resolve airsl without relying on PATH. Hooks are spawned by the CLI rather than a login
   # shell, so a cargo-installed binary under ~/.cargo/bin can be present but invisible.
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

   # `--allow-read /` because the report path is handed in by the call being inspected and may be
   # anywhere, including TMPDIR.
   VIOLATIONS=$("$AIRSL" run --fail-open --policy confined \
     --allow-env HOME --allow-env TMPDIR \
     --allow-read / \
     "$DIR/../scripts/comm_check_hook.lua" 2>/dev/null) || exit 0

   [ -n "$VIOLATIONS" ] || exit 0

   # PostToolUse emits a JSON object on stdout and blocks nothing; pass it through untouched.
   case "$VIOLATIONS" in
     '{'*) printf '%s\n' "$VIOLATIONS"; exit 0 ;;
   esac

   printf '%s\n' "$VIOLATIONS" >&2
   exit 2
   ```

4. Rerun the check script:

   ```
   $ sh <TMP>/plan02-hook.sh
   communication protocol report does not conform:
   topics-missing: <detail> is present but there is no <topics> block
   exit=2
   exit=0
   {"decision":"block","reason":"communication protocol report does not conform:\ntopics-missing: <detail> is present but there is no <topics> block"}
   exit=0
   ```

   Gate event on the bad report → exit 2 with the violation. The plain report has no `protocol:` key, so it passes — the "other agents are untouched" property. `PostToolUse` → the block decision as JSON, exit 0. Delete both fixtures and the script afterwards.

5. In `plugins/claudestacks/hooks/hooks.json`:
   - add to the `PostToolUse` `Write` group's `hooks` array, after `handoff-check.sh`:

     ```json
               {
                 "type": "command",
                 "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/comm-check.sh\""
               }
     ```

   - add the same object to the `PreToolUse` `^SubagentHandback$` group's `hooks` array, after `handoff-check.sh`;
   - append a new group to the `SubagentStop` array, with no matcher (a `/discuss` brief may go to any agent type):

     ```json
         {
           "hooks": [
             {
               "type": "command",
               "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/comm-check.sh\""
             }
           ]
         }
     ```

6. Validate and run the gate:

   ```
   $ claude plugin validate plugins/claudestacks
   ✔ Validation passed
   $ cargo make plugins
   … 0 failed …
   ```

7. Commit `feat(repo): register the communication protocol report hook`.

## Verification summary (plan-level)

- `cargo make plugins` green, with the seventeen `comm_report_test.lua` tests among the passes, each seen failing first.
- Task 5 step 4: a non-conforming protocol report exits 2 with `topics-missing` on the gate event and yields the block JSON on `PostToolUse`; a report without `protocol:` exits 0.
- `claude plugin validate plugins/claudestacks` passes.
- Checkpoint: stop here for the author's review before plan 03.
