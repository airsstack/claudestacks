---
status: done
created: 2026-09-21
depends-on: [02, 04, 05]
---

# Handoff Hook Wiring Implementation Plan

**Goal:** A non-conforming handoff report is caught automatically, by a hook, rather than by a reader noticing.

**Architecture:** The hook entry lives at `scripts/handoff_check_hook.lua`, beside `scripts/lib/` — `airsl` resolves `require` relative to the script's own directory, so an entry placed under `hooks/` could not reach `lib/handoff_report.lua` at all. A launcher at `hooks/handoff-check.sh` resolves `airsl` and its own directory from `$0`, the pattern `enforce.sh` already uses, and maps non-empty validator output to exit 2. Three registrations use it: `PostToolUse` on `Write` cannot block, so it attaches violations to the write result as an early signal; the gate is `PreToolUse` on `SubagentHandback`, which can block and sees the report as `tool_input.message`, with `SubagentStop` covering sessions where that tool is not in play. The path matcher takes the last `.md` path in the report text rather than a shaped name, because an exception-tier report is named by its driver and carries neither an `NN-agent-slug` prefix nor a `handoff/` segment.

**Tech Stack:** POSIX shell, Lua 5.4 on `airsl`, Claude Code hook JSON.

**Amended during execution, 2026-10-04.** This plan was corrected while being executed; the text
below is the corrected text, not what was originally approved. Two of its steps implemented a spec
premise that execution disproved, two of its expected outputs were wrong, and its final task could
not be verified from the worktree that ran it — only after the branch reached `main`, and then in
one of its two modes.

- **Tasks 1 and 2 faithfully implemented a wrong rule, and spec §8 was amended rather than the
  plan's reasoning.** The entry's `%.md$` filter on the `PostToolUse` leg, and `path_in`'s
  "last `.md` token" rule, both come straight from §8:456 and §8:462 as approved. Measured against
  the delivered tree: a `Write` of this plan's own file emitted
  `{"decision":"block","reason":"…agent-missing…task-missing…summary-missing…"}`, so every markdown
  write in every session gained a false nonconformance notice; and a hand-back stating its handoff
  path correctly and then citing `hooks.md:1011` — the `file:line` evidence `CLAUDE.md` mandates —
  yielded `unreadable: cannot read hooks.md` and exit 2, blocking a conforming report with a
  violation no agent can satisfy. §8 now specifies a handoff-root test instead, under four dated
  amendment notes, and the author took that decision. The fix round implements it.
- **A relative handoff path was never resolved.** `protocol.md:90-92` requires a session-tree path
  to be returned *relative to the worktree root*, so the specified normal case is relative, while
  `hooks.md:597` and `:607` between them decline to guarantee the hook process's cwd and state that
  in a worktree session the worktree path reaches a hook only as the payload's `cwd` field.
  Measured: the same relative path yields `frontmatter-missing` from the worktree root and
  `unreadable: cannot read .airsstack/…` from anywhere else, both exit 2 — a conforming report
  refused. Neither this plan nor §8 had noticed; both now say to resolve against `cwd`.
- **Task 1 step 1's expected output is incomplete.** `airsl run … handoff.lua` with no subcommand
  prints its usage line and then exits 1 with a Lua traceback, because the usage path calls
  `error`. The usage line is still the evidence the step wants — `require("lib.handoff")` resolved
  — but the step as written implies a clean run.
- **Task 1 step 3 and Task 2 step 4's `airsl check` expectation is wrong.** The plan says "No
  output, exit 0". `airsl` 0.1.2 prints `1 file(s) compiled, 0 failed`. The exit code matches.
- **Task 2's trailing-punctuation strip is dead code.** `(%S+%.md)` captures a run ending in the
  literal characters `md`, so the second `gsub`'s `[%)%]`"'.,]+$` can never match, and
  `a_trailing_period_is_not_part_of_the_path` passes for a reason other than the one it names.
- **Task 7 passed once the branch reached the main checkout, in one of its two modes.** After the
  merge and a `/reload-plugins` reporting `9 hooks` (up from `6`), a probe subagent wrote a
  deliberately frontmatter-less report under the session tree and reported:

  ```
  post-write-notice:   frontmatter-missing: the file does not open with a `---` block
  handback-attempt-1:  BLOCKED — handoff report does not conform to the protocol:
                       frontmatter-missing: the file does not open with a `---` block
  handback-attempt-2:  BLOCKED — same text
  conforming-handback: PASSED
  ```

  So the `PostToolUse` early signal fires, the `PreToolUse` gate blocks and states a reason the
  agent can act on, and the hand-back succeeded only after the file was made conforming. The
  orchestrator received that hand-back, which is the proof of the last line rather than the
  agent's word for it, and the validator reads the final file as `exit 0`.

  **The `SubagentStop` leg remains unverified, and step 5 requires that to be written down rather
  than reported as working.** Every subagent in the verifying session delivered through
  `SubagentHandback`, so that leg never fired. It is proven at the launcher — the exception-tier
  payload exits 2 with the right reason — and unproven through Claude Code's own dispatch. Closing
  it needs a session where the hand-back tool is not in play.

- **Step 1's premise about reloading is wrong, and cost one failed verification round.** Step 1 says
  "This marketplace is a local directory, so edits take effect at the next session start or
  `/reload-plugins`, with no version bump needed for in-place development." That holds for the
  checkout the marketplace points at and fails for every worktree of it.
  `~/.claude/plugins/known_marketplaces.json` registers `claudestacks` as
  `{"source": "directory", "path": "/Users/hiraq/Projects/airsstack/claudestacks"}` — the main
  checkout. A worktree's `plugins/` tree is never read, so no reload can make a change made here
  live.

  Measured after a `/reload-plugins` that reported `5 plugins · 27 skills · 16 agents · 6 hooks`:
  a probe subagent wrote a deliberately frontmatter-less report under the session tree and
  reported `post-write-notice: NONE`, `handback-attempt-1: NOT BLOCKED`; a `Write` of the same
  shape from the main thread produced no notice either. The cause is not the hook — the main
  checkout lacks `hooks/handoff-check.sh` and `scripts/handoff_check_hook.lua` entirely, and its
  `hooks.json` contains zero occurrences of `handoff-check.sh`.

  The control is what separated "the gate is broken" from "the gate is absent": the same payloads
  fed to `hooks/handoff-check.sh` in this worktree by hand exited 2 with the right reason, and all
  seven launcher cases behaved as specified.

  Closing Task 7 therefore required the branch to reach the checkout the marketplace points at —
  not a reload, not a version bump, and not anything a session in a worktree can do to itself. It
  was merged to `main` as `f43766f` and verified from there, as the Task 7 bullet above records.
  Step 1 should say that a worktree cannot verify this task.
- **Task 8's condition was wrong, and the version it left in place shipped stale.** `git tag
  --list` is empty, so the task read `0.1.6` as unpublished and changed nothing. But a tag is not
  what publishes this plugin: the marketplace entry's `source` is `./plugins/claudestacks`, so
  whatever `main` carries is the release. `0.1.6` reached `main` with `f43766f` (#9), and the
  false-positive fix below reached it afterwards with `399895b` (#10) — a change to
  `scripts/lib/handoff_report.lua` under a version consumers already had. Task 8's other premise,
  that every plan lands before the release ships, failed the same way: the chain merged in two
  PRs. Corrected after the fact to `0.1.7`; Task 8 below now keys the bump on `main`, not tags.
- **The live gate found a false positive in itself within minutes of Task 7 passing, and that is
  the strongest evidence in this record that it works.** Writing a commit-message `.txt` to
  `<session-scratch>/msgs3/9.txt` produced
  `frontmatter-missing … summary-missing`, attached to the write. Two causes, both now fixed with
  red-before-green tests: the fix round had *replaced* the `%.md$` filter with the root test
  rather than requiring both, so `PostToolUse` validated any file whatever its extension; and the
  temp branch tested `under(path, "/tmp")` at any depth, which is where every session's scratchpad
  lives. The temp root is now the two shapes the protocol actually mints — a direct child of
  `$TMPDIR`, or a path carrying a `/handoff/` segment — and `.md` is part of the root test in
  every tier. Spec §8 is corrected too; its residual-gap paragraph had described the risk as
  `.md`-scoped when the code scoped nothing.

---

### Task 1 — Write the Lua hook entry

**Files:**
- Create `plugins/claudestacks/scripts/handoff_check_hook.lua`

**Steps:**

1. Confirm the two facts this task rests on. First, that `require` resolves relative to the
   script's own directory — run an existing script that requires from a sibling `lib/`, from the
   repository root:

   ```
   $ airsl run --policy confined --allow-read . plugins/claudestacks/scripts/handoff.lua
   usage: handoff.lua {init [--root <dir>]|beat <dir>|end <dir>}
   ```

   The usage line means `require("lib.handoff")` resolved. This is why the entry goes in
   `scripts/` and not in `hooks/`.

   Second, the emit shape. `airsstack.hook.emit(t)` writes `t` to stdout as one JSON object;
   running `airsstack.hook.emit({ decision = "block", reason = "why" })` prints exactly
   `{"decision":"block","reason":"why"}`.

2. Write the entry:

   ```lua
   -- Handoff report conformance hook.
   --
   -- Rules live in `lib/handoff_report.lua`. Prose mirror:
   -- `skills/context-handoff/references/protocol.md`.
   --
   -- Lives in `scripts/` rather than `hooks/` because airsl resolves `require` relative to the
   -- script's own directory, and the validator is `scripts/lib/handoff_report.lua`. The launcher
   -- in `hooks/handoff-check.sh` reaches across.
   --
   -- Three events arrive here, and the behaviour differs because only two of them can stop
   -- anything:
   --
   --   PostToolUse(Write)           the file is already written; emit violations beside the tool
   --                                result so the agent can rewrite. Cannot block.
   --   PreToolUse(SubagentHandback) the report is about to be delivered; print violations to
   --                                stdout so the launcher exits 2 and blocks the call.
   --   SubagentStop                 the same gate where the hand-back tool is not in use.
   --
   -- Violations go to STDOUT, never stderr: the launcher reads stdout to decide whether to block,
   -- and an airsl traceback on stderr would reach the agent in place of a readable reason.

   local report = require("lib.handoff_report")
   local stdio = airsstack.stdio

   -- The report path stated in an agent's return text.
   --
   -- The LAST `.md` path in the text, not a shaped name. An exception-tier report is named by its
   -- driver — `journal-curator-review.md`, `claudestacks-sdlc-<chain>-spec-01.md` — with no
   -- `NN-agent-slug` prefix and no `handoff/` segment, so a matcher keyed on either shape would
   -- leave the gate silently off for all four single-subagent drivers. Last rather than first
   -- because the return contract puts the path after the summary text.
   local function path_in(text)
     if type(text) ~= "string" then
       return nil
     end
     local found = nil
     for candidate in text:gmatch("(%S+%.md)") do
       found = candidate
     end
     if not found then
       return nil
     end
     -- Strip punctuation a sentence may wrap the path in.
     return (found:gsub("^[%(%[`\"']+", ""):gsub("[%)%]`\"'.,]+$", ""))
   end

   local function violations_of(file)
     local lines = {}
     for _, violation in ipairs(report.check(file)) do
       lines[#lines + 1] = violation.id .. ": " .. violation.line
     end
     return lines
   end

   local payload = airsstack.hook.payload()
   if type(payload) ~= "table" then
     return
   end

   local event = payload.hook_event_name
   local tool_input = type(payload.tool_input) == "table" and payload.tool_input or {}

   local file
   if event == "PostToolUse" then
     file = type(tool_input.file_path) == "string" and tool_input.file_path or nil
   elseif event == "PreToolUse" then
     file = path_in(tool_input.message)
   elseif event == "SubagentStop" then
     file = path_in(payload.last_assistant_message)
   end

   -- No `.md` path at all is not a violation. An agent legitimately without one — the standalone
   -- case the protocol's error handling allows — must never be held, and an agent that owed a path
   -- and omitted it has already broken the return contract where the orchestrator can see it.
   if not file or file == "" then
     return
   end

   -- A `Write` to anything that is not Markdown is the overwhelming majority of calls this hook
   -- sees. Leave before touching the filesystem.
   if event == "PostToolUse" and not file:match("%.md$") then
     return
   end

   local found = violations_of(file)
   if #found == 0 then
     return
   end

   local reason = "handoff report does not conform to the protocol:\n" .. table.concat(found, "\n")

   if event == "PostToolUse" then
     airsstack.hook.emit({ decision = "block", reason = reason })
   else
     stdio.write(reason .. "\n")
   end
   ```

3. Confirm it compiles:

   ```
   $ airsl check plugins/claudestacks/scripts/handoff_check_hook.lua
   ```

   No output, exit 0.

4. Commit `feat(repo): add the handoff report hook entry`.

---

### Task 2 — Cover the path matcher with tests

**Files:**
- Modify `plugins/claudestacks/scripts/handoff_report_test.lua`

**Steps:**

1. `path_in` is the part of this plan most able to fail silently — a matcher that finds nothing
   makes the gate a no-op that reports success. Move it into the tested module so it can be
   exercised. In `plugins/claudestacks/scripts/lib/handoff_report.lua`, add:

   ```lua
   -- The report path stated in an agent's return text: the LAST `.md` path in it.
   --
   -- Not a shaped name. An exception-tier report is named by its driver, with no
   -- `NN-agent-slug` prefix and no `handoff/` segment, so a shape-keyed matcher would miss every
   -- single-subagent driver and leave the gate silently off for four of the six.
   function M.path_in(text)
     if type(text) ~= "string" then
       return nil
     end
     local found = nil
     for candidate in text:gmatch("(%S+%.md)") do
       found = candidate
     end
     if not found then
       return nil
     end
     return (found:gsub("^[%(%[`\"']+", ""):gsub("[%)%]`\"'.,]+$", ""))
   end
   ```

   and have `handoff_check_hook.lua` call `report.path_in` instead of its own local copy.

2. Add the failing tests:

   ```lua
     an_exception_tier_path_is_found = function()
       -- The case a shape-keyed matcher misses: no NN- prefix, no handoff/ segment.
       assert(report.path_in("done. report at /tmp/journal-curator-review.md")
         == "/tmp/journal-curator-review.md")
     end,

     a_session_tier_path_is_found = function()
       assert(report.path_in("blocking: none\n.airsstack/cc/plugins/claudestacks/handoff/s/03-reviewer-diff.md")
         == ".airsstack/cc/plugins/claudestacks/handoff/s/03-reviewer-diff.md")
     end,

     a_trailing_period_is_not_part_of_the_path = function()
       assert(report.path_in("written to /tmp/a-report.md.") == "/tmp/a-report.md")
     end,

     a_backticked_path_is_unwrapped = function()
       assert(report.path_in("see `/tmp/a-report.md`") == "/tmp/a-report.md")
     end,

     text_with_no_markdown_path_yields_nil = function()
       assert(report.path_in("no handoff path was given, receipt inline") == nil)
     end,

     the_last_path_wins = function()
       -- The summary may cite a source file; the handoff path comes after it.
       assert(report.path_in("read plans/01-foo.md; report at /tmp/out.md") == "/tmp/out.md")
     end,
   ```

3. Run and confirm six failures — `M.path_in` does not exist yet, so each raises rather than
   asserting:

   ```
   $ airsl test --allow-read "$TMPDIR" --allow-write "$TMPDIR" --allow-read . plugins/claudestacks/scripts/handoff_report_test.lua
     FAIL  an_exception_tier_path_is_found
     FAIL  a_session_tier_path_is_found
     FAIL  a_trailing_period_is_not_part_of_the_path
     FAIL  a_backticked_path_is_unwrapped
     FAIL  text_with_no_markdown_path_yields_nil
     FAIL  the_last_path_wins

   23 passed, 6 failed (1 files)
   ```

4. Add the function from step 1, run again, and confirm green:

   ```
   $ airsl test --allow-read "$TMPDIR" --allow-write "$TMPDIR" --allow-read . plugins/claudestacks/scripts/handoff_report_test.lua
   29 passed, 0 failed (1 files)
   ```

5. Commit `feat(repo): find a report path in an agent's return text, whatever its tier`.

---

### Task 3 — Write the shell launcher

**Files:**
- Create `plugins/claudestacks/hooks/handoff-check.sh`

**Steps:**

1. Confirm the launcher pattern being followed, particularly the directory and `airsl` resolution:

   ```
   $ sed -n '14,32p' plugins/claudestacks/hooks/enforce.sh
   ```

2. Confirm the available flags before using any. `airsl run` takes `--fail-open`, `--policy`,
   `--memory-limit`, `--instruction-limit`, `--allow-read`, `--allow-write`, `--allow-env` and
   `--allow-exec`, and nothing else:

   ```
   $ airsl run --help | grep "^      --"
         --fail-open
         --policy <POLICY>
         --memory-limit <BYTES|none>
         --instruction-limit <COUNT|none>
         --allow-read <DIR>
         --allow-write <DIR>
         --allow-env <NAME>
         --allow-exec <PROGRAM>
   ```

   There is no path-resolution flag, which is why Task 1 places the entry beside `lib/`.

3. Write the launcher. It differs from `enforce.sh` in one decisive way: `enforce.sh` ends every
   path in `exit 0` because its matcher covers `Read` and a propagated failure would block every
   file read. Here blocking is the point for two of the three events:

   ```sh
   #!/bin/sh
   # claudestacks handoff report conformance launcher.
   #
   # Unlike `enforce.sh`, this one DOES exit 2 — that is the point for the two gate events, where
   # exit 2 blocks the call. It exits 2 only when the Lua wrote violations to stdout; any other
   # failure (airsl missing, script error, unreadable file) exits 0 and lets the work proceed,
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

   # The entry sits in scripts/, beside the lib/ it requires. `--allow-read /` because the report
   # path is handed in by the call being inspected and may be anywhere, including TMPDIR.
   VIOLATIONS=$("$AIRSL" run --fail-open --policy confined \
     --allow-env HOME --allow-env TMPDIR \
     --allow-read / \
     "$DIR/../scripts/handoff_check_hook.lua" 2>/dev/null) || exit 0

   [ -n "$VIOLATIONS" ] || exit 0

   # PostToolUse emits a JSON object on stdout and blocks nothing; pass it through untouched.
   case "$VIOLATIONS" in
     '{'*) printf '%s\n' "$VIOLATIONS"; exit 0 ;;
   esac

   printf '%s\n' "$VIOLATIONS" >&2
   exit 2
   ```

4. Make it executable:

   ```
   $ chmod +x plugins/claudestacks/hooks/handoff-check.sh
   $ test -x plugins/claudestacks/hooks/handoff-check.sh && echo EXECUTABLE
   EXECUTABLE
   ```

5. Commit `feat(repo): add the handoff report hook launcher`.

---

### Task 4 — Prove the launcher's four behaviours

**Files:**
- None — verification only.

**Steps:**

1. Write one non-conforming report and one conforming report:

   ```
   $ printf '<summary>\nx\n</summary>\n' > "${TMPDIR:-/tmp}/01-coder-bad.md"
   $ printf -- '---\nagent: coder\ntask: t\n---\n<summary>\nx\n</summary>\n' > "${TMPDIR:-/tmp}/01-coder-good.md"
   ```

2. **Gate blocks a bad report.** Feed a `PreToolUse` payload and confirm exit 2 with a readable
   reason and no traceback:

   ```
   $ printf '{"hook_event_name":"PreToolUse","tool_name":"SubagentHandback","tool_input":{"message":"done, report at %s/01-coder-bad.md"}}' "${TMPDIR:-/tmp}" \
       | plugins/claudestacks/hooks/handoff-check.sh
   handoff report does not conform to the protocol:
   frontmatter-missing: the file does not open with a `---` block
   $ echo "exit=$?"
   ```

   The `exit=` line must read `2`. Note it reports the exit status of `echo`'s predecessor only
   when the hook is the last command in the pipeline — run the hook alone, then `echo "exit=$?"`
   as a separate command, or the pipeline's status masks it.

3. **Gate passes a good report:**

   ```
   $ printf '{"hook_event_name":"PreToolUse","tool_name":"SubagentHandback","tool_input":{"message":"done, report at %s/01-coder-good.md"}}' "${TMPDIR:-/tmp}" \
       | plugins/claudestacks/hooks/handoff-check.sh
   $ echo "exit=$?"
   exit=0
   ```

4. **Early signal emits JSON and does not block.** `PostToolUse` cannot block, and an exit 2 here
   would be ignored:

   ```
   $ printf '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"%s/01-coder-bad.md"}}' "${TMPDIR:-/tmp}" \
       | plugins/claudestacks/hooks/handoff-check.sh
   {"decision":"block","reason":"handoff report does not conform to the protocol:\nframontmatter-missing: ..."}
   $ echo "exit=$?"
   exit=0
   ```

   The exact `reason` string is whatever the validator produced in step 2; what matters is that the
   output is a single JSON object and the status is 0.

5. **An exception-tier report is seen.** This is the case a shape-keyed matcher would miss, and the
   reason Task 2 exists:

   ```
   $ printf '<summary>\nx\n</summary>\n' > "${TMPDIR:-/tmp}/journal-curator-review.md"
   $ printf '{"hook_event_name":"SubagentStop","last_assistant_message":"tidied 4 notes; report at %s/journal-curator-review.md"}' "${TMPDIR:-/tmp}" \
       | plugins/claudestacks/hooks/handoff-check.sh
   handoff report does not conform to the protocol:
   frontmatter-missing: the file does not open with a `---` block
   $ echo "exit=$?"
   ```

   Must read `2`. An exit of `0` means the matcher did not find the path and the gate is off for
   every single-subagent driver.

6. **No path is not a violation:**

   ```
   $ printf '{"hook_event_name":"SubagentStop","last_assistant_message":"no handoff path was given, receipt inline"}' \
       | plugins/claudestacks/hooks/handoff-check.sh
   $ echo "exit=$?"
   exit=0
   ```

7. Commit nothing. Any deviation is fixed in Task 1, 2 or 3 before continuing.

---

**CHECKPOINT — stop here and present.** The launcher is proven against all five cases but nothing
is registered, so no session is affected yet. Registration makes the gate live for every spawn in
every session. Do not start Task 5 until the author says continue.

---

### Task 5 — Confirm every agent already emits the new frontmatter

**Files:**
- None — verification only.

**Steps:**

1. Registration must not precede conformance, or the gate refuses correct work. Confirm plan `04`
   landed for all seven writer agents:

   ```
   $ grep -rlc "write ONE file there" plugins/*/agents/ | wc -l
          7
   ```

2. Confirm no agent still carries the retired `created:` key:

   ```
   $ grep -rn "^created: " plugins/*/agents/
   $ echo "exit=$?"
   exit=1
   ```

3. If either check fails, stop — plan `04` is incomplete and registering now would block every
   spawn.

4. Commit nothing.

---

### Task 6 — Register the three hooks

**Files:**
- Modify `plugins/claudestacks/hooks/hooks.json`

**Steps:**

1. Confirm the current shape: four event keys holding five groups, none about handoff:

   ```
   $ python3 -c "import json; d=json.load(open('plugins/claudestacks/hooks/hooks.json'))['hooks']; print(sorted(d), sum(len(v) for v in d.values()))"
   ['PreToolUse', 'SessionEnd', 'SessionStart', 'UserPromptSubmit'] 5
   ```

2. Add a second group to `PreToolUse` matching the hand-back tool, and two new event keys:

   ```json
       "PreToolUse": [
         {
           "matcher": "Read|Edit|Write",
           "hooks": [
             {
               "type": "command",
               "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/enforce.sh\""
             }
           ]
         },
         {
           "matcher": "SubagentHandback",
           "hooks": [
             {
               "type": "command",
               "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/handoff-check.sh\""
             }
           ]
         }
       ],
       "PostToolUse": [
         {
           "matcher": "Write",
           "hooks": [
             {
               "type": "command",
               "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/handoff-check.sh\""
             }
           ]
         }
       ],
       "SubagentStop": [
         {
           "matcher": "^claudestacks:(coder|explorer|reviewer)$|^claudestacks-sdlc:(task-briefer|chain-reader|artifact-reviewer)$|^claudestacks-journal:journal-curator$",
           "hooks": [
             {
               "type": "command",
               "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/handoff-check.sh\""
             }
           ]
         }
       ]
   ```

   The `SubagentStop` matcher is the anchored plugin-scoped form: a scoped name contains a colon
   and is evaluated as an unanchored regular expression, so each alternative carries `^` and `$`.

3. Confirm the file is valid JSON and now holds six event keys and eight groups:

   ```
   $ python3 -c "import json; d=json.load(open('plugins/claudestacks/hooks/hooks.json'))['hooks']; print(sorted(d), sum(len(v) for v in d.values()))"
   ['PostToolUse', 'PreToolUse', 'SessionEnd', 'SessionStart', 'SubagentStop', 'UserPromptSubmit'] 8
   ```

4. Confirm the existing enforcement hook was not displaced by the added `PreToolUse` group:

   ```
   $ grep -c "enforce.sh" plugins/claudestacks/hooks/hooks.json
   1
   ```

5. Commit `feat(repo): register the handoff report conformance hooks`.

---

### Task 7 — Prove the gate fires end to end, in both modes

**Files:**
- None — verification only.

**Steps:**

1. Reload so the registrations take effect. This marketplace is a local directory, so edits take
   effect at the next session start or `/reload-plugins`, with no version bump needed for in-place
   development.

2. In a session where subagents use `SubagentHandback`, spawn one real reporting agent with a
   handoff path and confirm its report conforms:

   ```
   $ airsl run --policy confined --allow-read / \
       plugins/claudestacks/scripts/handoff_report.lua <the report the agent wrote>
   $ echo "exit=$?"
   exit=0
   ```

3. Delete that report's frontmatter and spawn again; confirm the `PostToolUse` reason appears in
   the transcript and the hand-back is refused. A hook that has never fired is not known to work.

4. Repeat in a session where the hand-back tool is not in use, so the `SubagentStop` leg is the one
   exercised.

5. If only one mode is reachable, record the untested leg as unverified in the execution record.
   Do not report it as working.

6. Commit nothing.

---

### Task 8 — Bump the plugin version

**Files:**
- Modify `plugins/claudestacks/.claude-plugin/plugin.json`

**Steps:**

1. Plan `01` Task 6 set `claudestacks` to `0.1.6` for the protocol move. This plan adds hooks to
   the same plugin, in the same release. Read what is there:

   ```
   $ grep '"version"' plugins/claudestacks/.claude-plugin/plugin.json
     "version": "0.1.6",
   ```

2. One version covers one release, and the marketplace publishes whatever `main` carries — its
   entry's `source` is `./plugins/claudestacks`, and no tag is involved. Check whether `main`
   already has `0.1.6`:

   ```
   $ git show main:plugins/claudestacks/.claude-plugin/plugin.json | grep '"version"'
   ```

   `0.1.6` there means it shipped, and this plan needs `0.1.7`. Anything older means plan `01`'s
   bump has not reached `main` yet and covers this plan too; leave it.

3. If the version changed, commit `chore(repo): bump claudestacks for the hook wiring`; otherwise
   commit nothing.
