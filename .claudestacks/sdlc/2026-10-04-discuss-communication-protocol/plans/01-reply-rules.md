---
status: done
created: 2026-10-04
---

# Reply Rules Delivery Implementation Plan

**Goal:** The four reply rules reach the model at every session start, and on every prompt unless the author turns that off.

**Architecture:** The rules live once, in the `## Reply rules` section of the new communication protocol `skills/discuss/references/protocol.md` (spec §3). `scripts/lib/style.lua` extracts that section and parses the `style_reinject` option; `scripts/style.lua` is the hook driver; `hooks/style.sh` is a launcher only. `SessionStart` (no matcher — every source, spec P9) always prints; `UserPromptSubmit` prints unless the option reads `false`/`0`. `concise-tracker.sh` stays registered until plan 05 removes it.

**Tech Stack:** `airsl` Lua 5.4 (`airsstack.fs`, `airsstack.env`, `airsstack.hook`), POSIX `sh`, Claude Code plugin `hooks.json` and `userConfig`.

---

## File structure

```
plugins/claudestacks/skills/discuss/references/protocol.md  — [create] the communication protocol; single source of the reply rules
plugins/claudestacks/scripts/lib/style.lua                  — [create] section extraction + option parsing (pure functions)
plugins/claudestacks/scripts/style_test.lua                 — [create] tests for lib/style and the shipped protocol.md
plugins/claudestacks/scripts/style.lua                      — [create] hook driver: read protocol.md, print the section
plugins/claudestacks/hooks/style.sh                         — [create] launcher: resolve airsl, grants, always exit 0
plugins/claudestacks/hooks/hooks.json                       — [modify] add the SessionStart and UserPromptSubmit entries
plugins/claudestacks/.claude-plugin/plugin.json             — [modify] add userConfig.style_reinject
```

Facts this plan encodes, each checked on 2026-10-04:

- `airsstack.hook.context(event, text)` prints `{"hookSpecificOutput":{"additionalContext":"<text>","hookEventName":"<event>"}}` and exits 0 (probe: `printf '{"hook_event_name":"SessionStart",…}' | airsl run --policy confined ctx.lua`).
- Script arguments arrive in `arg` (`plugins/claudestacks/hooks/enforce.lua:155-160`).
- A hook group with no `matcher` fires on every occurrence of the event (`hooks.md:293`).
- An unset `userConfig` option is absent from the hook environment (spec P3); the code applies the default.
- Test runs go through `cargo make plugins-test` (`Makefile.toml:143`), which runs `airsl test --policy confined --allow-read / --allow-write "${TMPDIR:-/tmp}" --allow-exec git plugins` from the repository root (`Makefile.toml:158-162`) and grants no environment variables.
- A failing test prints `  FAIL  <name>`; a test file whose `require` fails prints `module \`lib.<name>\` not found under \`<dir>\`` (probe of `airsl test`, 2026-10-04).

### Task 1 — Extract a named section from markdown

**Files:**
- Test `plugins/claudestacks/scripts/style_test.lua`
- Create `plugins/claudestacks/scripts/lib/style.lua`

**Steps:**

1. Write the failing test in `plugins/claudestacks/scripts/style_test.lua`:

   ```lua
   -- Tests for lib/style — the reply-rules section and the style_reinject option.
   --
   --   cargo make plugins-test

   local style = require("lib.style")

   local DOC = table.concat({
     "# Communication Protocol",
     "",
     "Intro.",
     "",
     "## Reply rules",
     "",
     "1. one",
     "2. two",
     "",
     "## Brief",
     "",
     "not this",
   }, "\n")

   return {
     the_reply_rules_section_is_extracted_with_its_heading = function()
       assert(style.reply_rules(DOC) == "## Reply rules\n\n1. one\n2. two")
     end,

     extraction_stops_at_a_top_level_heading_too = function()
       local doc = "## Reply rules\n\nkeep\n# Other\ndrop"
       assert(style.reply_rules(doc) == "## Reply rules\n\nkeep")
     end,

     a_subheading_inside_the_section_is_kept = function()
       local doc = "## Reply rules\n\nkeep\n### detail\nalso keep\n## Next\ndrop"
       assert(style.reply_rules(doc) == "## Reply rules\n\nkeep\n### detail\nalso keep")
     end,

     no_section_means_nothing_to_print = function()
       assert(style.reply_rules("# Title\n\n## Brief\n\ntext") == nil)
     end,

     an_empty_section_means_nothing_to_print = function()
       assert(style.reply_rules("## Reply rules\n\n\n## Brief\nx") == nil)
     end,
   }
   ```

2. Run it and confirm failure:

   ```
   $ cargo make plugins-test
   …/plugins/claudestacks/scripts/style_test.lua: lua error in …/style_test.lua: module `lib.style` not found under `…/plugins/claudestacks/scripts`
   ```

3. Write the minimal implementation in `plugins/claudestacks/scripts/lib/style.lua`:

   ```lua
   -- The reply rules of the claudestacks communication protocol, and the option that controls
   -- re-sending them each turn.
   --
   -- Split from the hook driver so both decisions can be tested against strings: the driver
   -- reads stdin and runs at load time, so it cannot be required.

   local M = {}

   M.HEADING = "## Reply rules"

   -- The `## Reply rules` section of `text`, heading included, trimmed — or nil when the
   -- section is absent or empty. Ends at the next `#` or `##` heading; `###` and deeper stay in.
   function M.reply_rules(text)
     local kept, inside = {}, false
     for line in (text .. "\n"):gmatch("(.-)\r?\n") do
       if line == M.HEADING then
         inside = true
       elseif inside and (line:match("^#%s") or line:match("^##%s")) then
         break
       elseif inside then
         kept[#kept + 1] = line
       end
     end
     if not inside then
       return nil
     end
     local body = table.concat(kept, "\n"):match("^%s*(.-)%s*$")
     if body == "" then
       return nil
     end
     return M.HEADING .. "\n\n" .. body
   end

   return M
   ```

4. Run it and confirm green:

   ```
   $ cargo make plugins-test
     ok    the_reply_rules_section_is_extracted_with_its_heading
     ok    extraction_stops_at_a_top_level_heading_too
     ok    a_subheading_inside_the_section_is_kept
     ok    no_section_means_nothing_to_print
     ok    an_empty_section_means_nothing_to_print
   ```

   Then break it to see the suite catch it: change `line:match("^##%s")` to `line:match("^###%s")`, rerun, and confirm `FAIL  the_reply_rules_section_is_extracted_with_its_heading`. Restore it.

5. Commit `feat(repo): extract the reply-rules section for the claudestacks style hook`.

### Task 2 — Parse the `style_reinject` option

**Files:**
- Test `plugins/claudestacks/scripts/style_test.lua`
- Modify `plugins/claudestacks/scripts/lib/style.lua`

**Steps:**

1. Add these entries to the table returned by `plugins/claudestacks/scripts/style_test.lua`:

   ```lua
     an_absent_option_means_reinject = function()
       assert(style.reinject_enabled(nil) == true)
     end,

     true_and_one_mean_reinject = function()
       assert(style.reinject_enabled("true") == true)
       assert(style.reinject_enabled("1") == true)
     end,

     false_and_zero_turn_it_off_whatever_the_case_or_spacing = function()
       assert(style.reinject_enabled("false") == false)
       assert(style.reinject_enabled("0") == false)
       assert(style.reinject_enabled(" FALSE ") == false)
     end,

     an_unreadable_value_keeps_the_default = function()
       -- A placeholder or junk is not an instruction to stop; on is the default (spec §8).
       assert(style.reinject_enabled("${user_config.style_reinject}") == true)
       assert(style.reinject_enabled("") == true)
     end,
   ```

2. Run it and confirm failure:

   ```
   $ cargo make plugins-test
     FAIL  an_absent_option_means_reinject
     FAIL  true_and_one_mean_reinject
     FAIL  false_and_zero_turn_it_off_whatever_the_case_or_spacing
     FAIL  an_unreadable_value_keeps_the_default
   ```

   (each with `attempt to call a nil value (field 'reinject_enabled')`).

3. Add to `plugins/claudestacks/scripts/lib/style.lua`, above `return M`:

   ```lua
   -- Whether to re-send the rules on every prompt, from the raw `CLAUDE_PLUGIN_OPTION_STYLE_REINJECT`
   -- value. Only an explicit `false` or `0` turns it off: an unset option never reaches the
   -- environment (spec P3), and the exact text a set boolean arrives as is unverified (spec P4).
   function M.reinject_enabled(value)
     if value == nil then
       return true
     end
     local normalized = tostring(value):lower():match("^%s*(.-)%s*$")
     return not (normalized == "false" or normalized == "0")
   end
   ```

4. Run it and confirm green:

   ```
   $ cargo make plugins-test
     ok    an_absent_option_means_reinject
     ok    true_and_one_mean_reinject
     ok    false_and_zero_turn_it_off_whatever_the_case_or_spacing
     ok    an_unreadable_value_keeps_the_default
   ```

   Break it: change `normalized == "0"` to `normalized == "00"`, rerun, confirm `FAIL  false_and_zero_turn_it_off_whatever_the_case_or_spacing`. Restore.

5. Commit `feat(repo): parse the style_reinject option`.

### Task 3 — Write the communication protocol

**Files:**
- Test `plugins/claudestacks/scripts/style_test.lua`
- Create `plugins/claudestacks/skills/discuss/references/protocol.md`

**Steps:**

1. Add this entry to the table returned by `style_test.lua`, and add `local fs = airsstack.fs` under the `require` line at the top:

   ```lua
     the_shipped_protocol_carries_the_four_rules_verbatim = function()
       -- Path relative to the repository root, where `cargo make plugins-test` runs.
       local text = fs.read("plugins/claudestacks/skills/discuss/references/protocol.md")
       local rules = assert(style.reply_rules(text), "no ## Reply rules section")
       for _, rule in ipairs({
         "1. Reduce agent verbosity output.",
         "2. Do not over-explain everything; only explain what matters.",
         "3. Use ASCII visualizations to replace long narratives or text.",
         "4. Be concise but precise; only tell what matters and is important.",
         "- The outcome comes first.",
         "- Anything that would run past a short paragraph becomes an ASCII diagram, table or tree.",
         "- While a discussion is open, a reply ends with its topic list.",
       }) do
         assert(rules:find(rule, 1, true), "missing: " .. rule)
       end
       assert(not rules:find("comm-protocol:", 1, true), "the section ran into ## Brief")
     end,
   ```

2. Run it and confirm failure:

   ```
   $ cargo make plugins-test
     FAIL  the_shipped_protocol_carries_the_four_rules_verbatim
   ```

   (`read failed on \`/…/plugins/claudestacks/skills/discuss/references/protocol.md\`: No such file or directory (os error 2)` — the runtime prints the absolute path).

3. Create `plugins/claudestacks/skills/discuss/references/protocol.md` with exactly this content:

   ````markdown
   # Communication Protocol

   How the main thread, and the agents it briefs under `/claudestacks:discuss`, talk to the
   author. It sits on top of the Context Handoff protocol and changes nothing in it.

   **It inherits.** Every rule in the `claudestacks` plugin's
   `skills/context-handoff/references/protocol.md` applies unchanged: report paths, tiers, the
   session lifecycle, the `<summary>`/`<detail>` file schema, the return contract, error
   handling, and its validator. This file only adds. If the two ever seem to disagree, Context
   Handoff wins and this file has a defect.

   ## Reply rules

   1. Reduce agent verbosity output.
   2. Do not over-explain everything; only explain what matters.
   3. Use ASCII visualizations to replace long narratives or text.
   4. Be concise but precise; only tell what matters and is important.

   Applied as:

   - The outcome comes first.
   - Anything that would run past a short paragraph becomes an ASCII diagram, table or tree.
   - While a discussion is open, a reply ends with its topic list.

   ## Brief

   A `/claudestacks:discuss` brief carries the two Context Handoff fields plus one:

   ```
   handoff: <write-path>
   handoff-protocol: <context-handoff protocol path>
   comm-protocol: <this file's path>
   ```

   ## Report additions

   A report written under this protocol is a valid Context Handoff report with three additions:

   ```
   ---
   agent: reviewer
   task: …
   protocol: discuss/1            ← required
   ---
   <summary>
   at most 6 non-empty lines, outcome first
   </summary>
   <topics>
   1. <title>
   2. <title>
   </topics>
   <detail>
   ## 1. <title>                  ← one heading per topic, same number and title
   …
   ## 2. <title>
   …
   </detail>
   ```

   A report with no `<detail>` carries no `<topics>`.

   ## Return contract

   The agent returns its `<summary>`, its `<topics>` lines verbatim, and the report path. It does
   not return `<detail>`.

   ## Main-thread reports

   During an open discussion, a main-thread answer that would exceed about 15 lines is written as
   a report under this protocol with `agent: main`, at the path
   `scripts/discuss.lua report-path <slug>` prints, then added with `scripts/discuss.lua add`.

   ## What enforces this

   `scripts/lib/comm_report.lua` checks the additions. The plugin's hooks run it on the same three
   events as the Context Handoff validator, and it acts only on a report carrying `protocol:`, so
   reports from every other agent are untouched. `scripts/discuss.lua add` runs it too, with
   `protocol:` required.

   | id | fails when |
   |---|---|
   | `protocol-unknown` | `protocol:` is not `discuss/1` |
   | `summary-too-long` | more than 6 non-empty lines inside `<summary>` |
   | `topics-missing` | `<detail>` present and no `<topics>` pair |
   | `topics-malformed` | a non-blank line inside `<topics>` is not `N. <title>` |
   | `topics-numbering` | topic numbers are not `1..n` in order |
   | `topic-heading-missing` | no line `## N. <title>` inside `<detail>` for topic `N` |
   | `topics-without-detail` | `<topics>` present and no `<detail>` pair |
   | `protocol-missing` | no `protocol:` key — raised only by `discuss.lua add` |
   ````

4. Run it and confirm green:

   ```
   $ cargo make plugins-test
     ok    the_shipped_protocol_carries_the_four_rules_verbatim
   ```

   Break it: delete the line `4. Be concise but precise; …` from `protocol.md`, rerun, confirm `FAIL  the_shipped_protocol_carries_the_four_rules_verbatim`. Restore it.

5. Commit `docs(repo): add the claudestacks communication protocol`.

### Task 4 — Hook driver and launcher

**Files:**
- Create `plugins/claudestacks/scripts/style.lua`
- Create `plugins/claudestacks/hooks/style.sh`

**Steps:**

1. Confirm the launcher does not exist yet (the red step for an untestable-by-suite driver):

   ```
   $ printf '{"hook_event_name":"SessionStart","session_id":"s1","source":"startup"}' | sh plugins/claudestacks/hooks/style.sh
   sh: plugins/claudestacks/hooks/style.sh: No such file or directory
   ```

2. Create `plugins/claudestacks/scripts/style.lua`:

   ```lua
   -- claudestacks reply rules — SessionStart and UserPromptSubmit hook.
   --
   -- Prints the `## Reply rules` section of the communication protocol as context. SessionStart
   -- always prints; a run given `--turn` (the UserPromptSubmit entry) prints unless the
   -- `style_reinject` option is off. Never blocks: run it with --fail-open.
   --
   --   airsl run --fail-open --policy confined \
   --     --allow-env CLAUDE_PLUGIN_OPTION_STYLE_REINJECT --allow-read <plugin-root> \
   --     scripts/style.lua <protocol.md> [--turn]

   local style = require("lib.style")

   local protocol = arg[1]
   local turn = arg[2] == "--turn"
   if type(protocol) ~= "string" or protocol == "" then
     return
   end

   if turn then
     local read, value = pcall(airsstack.env.get, "CLAUDE_PLUGIN_OPTION_STYLE_REINJECT")
     if not style.reinject_enabled(read and value or nil) then
       return
     end
   end

   local ok, text = pcall(airsstack.fs.read, protocol)
   if not ok or type(text) ~= "string" then
     return
   end
   local rules = style.reply_rules(text)
   if not rules then
     return
   end

   local got, payload = pcall(airsstack.hook.payload)
   local event = got and type(payload) == "table" and payload.hook_event_name
   if type(event) ~= "string" then
     event = turn and "UserPromptSubmit" or "SessionStart"
   end
   airsstack.hook.context(event, rules)
   ```

3. Create `plugins/claudestacks/hooks/style.sh`:

   ```sh
   #!/bin/sh
   # claudestacks reply-rules launcher.
   #
   # Prints the communication protocol's reply rules as context. Always exits 0: a hook on
   # SessionStart or UserPromptSubmit must never block the session or the prompt. Deliberately
   # no `exec`, which would hand airsl's status straight back to Claude Code.

   DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || exit 0
   [ -n "$DIR" ] || exit 0
   PLUGIN=$(CDPATH= cd -- "$DIR/.." 2>/dev/null && pwd) || exit 0

   # Resolve airsl without relying on PATH. Hooks are spawned by the CLI rather than a login shell,
   # so a cargo-installed binary under ~/.cargo/bin can be present but invisible.
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
     --allow-env CLAUDE_PLUGIN_OPTION_STYLE_REINJECT \
     --allow-read "$PLUGIN" \
     "$PLUGIN/scripts/style.lua" "$PLUGIN/skills/discuss/references/protocol.md" "$@" || exit 0

   exit 0
   ```

4. Confirm all three behaviours:

   ```
   $ printf '{"hook_event_name":"SessionStart","session_id":"s1","source":"startup"}' | sh plugins/claudestacks/hooks/style.sh; echo " exit=$?"
   {"hookSpecificOutput":{"additionalContext":"## Reply rules\n\n1. Reduce agent verbosity output.\n…","hookEventName":"SessionStart"}} exit=0

   $ printf '{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"hi"}' | sh plugins/claudestacks/hooks/style.sh --turn; echo " exit=$?"
   {"hookSpecificOutput":{"additionalContext":"## Reply rules\n\n…","hookEventName":"UserPromptSubmit"}} exit=0

   $ printf '{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"hi"}' | CLAUDE_PLUGIN_OPTION_STYLE_REINJECT=false sh plugins/claudestacks/hooks/style.sh --turn; echo " exit=$?"
    exit=0
   ```

   The third prints nothing. Then break the grant: remove the `--allow-env` line, rerun the third command, and confirm the rules print — whether `env.get` on an ungranted name raises or returns nil is not verified, and the driver's `pcall` treats both as absent, which means on. Restore it.

5. Commit `feat(repo): add the reply-rules hook driver and launcher`.

### Task 5 — Register the hook and declare the option

**Files:**
- Modify `plugins/claudestacks/hooks/hooks.json`
- Modify `plugins/claudestacks/.claude-plugin/plugin.json`

**Steps:**

1. In `plugins/claudestacks/hooks/hooks.json`, append a third group to the `SessionStart` array, after the `compact` group:

   ```json
         {
           "hooks": [
             {
               "type": "command",
               "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/style.sh\""
             }
           ]
         }
   ```

   and add a second hook to the existing `UserPromptSubmit` group's `hooks` array, after the `concise-tracker.sh` entry (plan 05 removes that entry):

   ```json
             {
               "type": "command",
               "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/style.sh\" --turn"
             }
   ```

2. In `plugins/claudestacks/.claude-plugin/plugin.json`, add after the `"keywords"` array:

   ```json
     "userConfig": {
       "style_reinject": {
         "type": "boolean",
         "title": "Re-send reply rules every prompt",
         "description": "Re-send the communication protocol's reply rules with every prompt. When off, they are still sent at every session start, /clear and compaction.",
         "default": true
       }
     }
   ```

   (Fields per `manifest-reference.md:431-435`.)

3. Validate both files:

   ```
   $ claude plugin validate plugins/claudestacks
   ✔ Validation passed
   ```

   If it reports warnings that were already present before this task, they are not this task's; any new error is.

4. Run the full gate:

   ```
   $ cargo make plugins
   … 0 failed …
   ```

5. Commit `feat(repo): register the reply-rules hook and its style_reinject option`.

## Verification summary (plan-level)

- `cargo make plugins` green, with the ten `style_test.lua` tests among the passes, each seen failing first.
- The three launcher runs in Task 4 step 4 produce the shown output.
- `claude plugin validate plugins/claudestacks` passes.
- Checkpoint: stop here for the author's review before plan 02.

## Review findings

One `claudestacks:reviewer` pass, 2026-10-06. Verdict: spec compliant, blocking set empty. DoD re-run by the reviewer: `cargo make plugins` → `356 passed, 0 failed (18 files)`; `claude plugin validate plugins/claudestacks` → `✔ Validation passed`.

- test-coverage — removing the `--allow-env` grant or the `--turn` check fails no test or DoD step (spec §11 accepts it) — `hooks/style.sh:30`, `scripts/style.lua:19`
- forward-reference — protocol names `discuss.lua`, `comm_report.lua` and a comm-check hook that plans 02/03 create — `skills/discuss/references/protocol.md:71-89`
- consistency — `style.sh` is mode 644 where most sibling launchers are 755; harmless, since `hooks.json` runs it through `sh` — `hooks/style.sh`
- test-coverage — CRLF line handling has no test — `scripts/lib/style.lua`
- robustness — the heading must match `## Reply rules` exactly — `scripts/lib/style.lua`
- robustness — a `#` line inside a code fence in the section would end it early — `scripts/lib/style.lua`
- comment-accuracy — the comment claims more than spec P3 checked — `scripts/lib/style.lua:35`
- spec — `concise-tracker.sh` and `style.sh` both inject on UserPromptSubmit until plan 05 removes the former — `hooks/hooks.json`

All non-blocking; none fixed in this run.

## Probe results

- Claim (plan Task 4, marked unverified there): `airsstack.env.get` on an ungranted name raises or returns nil. Probe `airsl run --policy confined --allow-read . probe4.lua` with `pcall(airsstack.env.get, "CLAUDE_PLUGIN_OPTION_STYLE_REINJECT")`, no grant → `ok=false v=env.get denied: `CLAUDE_PLUGIN_OPTION_STYLE_REINJECT` is not granted — no environment variables are…`. With `--allow-env CLAUDE_PLUGIN_OPTION_STYLE_REINJECT` and the var set to `false` → `ok=true v=false`. It raises. The driver's `pcall` treats that as absent (on), so the plan's mutation step holds — not against the plan.
- Claim: `airsstack.hook.context(event, text)` prints `{"hookSpecificOutput":{"additionalContext":…,"hookEventName":…}}` and exits 0; `arg[1]`/`arg[2]` carry script arguments. Same probe → `{"hookSpecificOutput":{"additionalContext":"env.get ok=true v=false arg1=p.md arg2=--turn","hookEventName":"UserPromptSubmit"}} exit=0`. Confirmed.
- Claim: `airsl run` accepts `--fail-open`. `airsl run --help | grep -n -i fail-open` → `15:      --fail-open`. Confirmed.

## Deviations

- 2026-10-06 — One `coder` ran all five tasks in order instead of one per task: each task builds on the previous one (tasks 1–3 share `style_test.lua`, task 4 requires `lib.style`, task 5 registers task 4's launcher), so no batch could run in parallel. Each task still went red → green → mutation.
- 2026-10-06 — The per-task commit steps were not run; the author holds the commit gate. Messages, in order: `feat(repo): extract the reply-rules section for the claudestacks style hook`, `feat(repo): parse the style_reinject option`, `docs(repo): add the claudestacks communication protocol`, `feat(repo): add the reply-rules hook driver and launcher`, `feat(repo): register the reply-rules hook and its style_reinject option`.
