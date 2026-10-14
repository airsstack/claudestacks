---
status: approved
created: 2026-10-14
depends-on: [04]
built-on: a5a235079e03
---

# Session-Start Hook Implementation Plan

**Goal:** Every session's agent is shown, at session start, the board rows that need
attention.

**Architecture:** `lib/status` gains `M.attention`, a second formatter over the `M.board` data
plan 04 introduced: a first line with two counts, then the rows that need attention, printed
exactly as the board prints them. A new entry point, `scripts/attention.lua`, takes the chain
root from the hook payload's `cwd` and prints that text; `scripts/attention.sh` launches it
the way `scripts/status.sh` launches the board. A new `hooks/hooks.json` — the plugin's first
hook — runs the launcher on `SessionStart` with no matcher. Every path of the launcher exits
0, so the hook cannot break a session.

**Tech Stack:** Lua 5.4 under `airsl` 0.1.2 (`airsstack.hook.payload`, `airsstack.stdio`),
POSIX `sh`, Claude Code plugin hooks (`hooks/hooks.json`).

**Content authority:** spec §9 (all of it), §10 last bullet, §11 (attention tests, the hook's
output and wall time), premises P6 to P9.

---

## File structure

```
plugins/claudestacks-sdlc/scripts/lib/status.lua     — [modify] M.needs_attention, M.attention
plugins/claudestacks-sdlc/scripts/status_test.lua    — [modify] 5 new tests
plugins/claudestacks-sdlc/scripts/attention.lua      — [create] hook entry point
plugins/claudestacks-sdlc/scripts/attention.sh       — [create] hook launcher
plugins/claudestacks-sdlc/hooks/hooks.json           — [create] SessionStart declaration
```

Every path below is relative to the repository root. The gate for every task is
`cargo make plugins`, run from the repository root: `plugins-check` compiles
`scripts/attention.lua`, which no test loads, and `plugins-test` runs the assertions. No Rust
changes, so the Rust Definition of Done does not apply.

Baseline, with plans 01, 02 and 04 done: `486 passed, 0 failed (22 files)` and
`fingerprint gate: 8 cases passed`.

**What the hook prints** (spec §9):

```
claudestacks-sdlc: 3 open, 1 need attention — full board: /claudestacks-sdlc:status
  2026-10-13-invoices             plan 01 approved: stale (spec changed)  plan
```

- No chain root: nothing.
- The first line is always printed when a chain root exists: the number of open chains, then
  the number of rows needing attention.
- A row needs attention when its STATE holds `INVALID`, `stale`, `blocked`, `disproven` or
  `complete`, when it names a plan as `executing`, or when it carries a `⤷ milestone …` or
  `⤷ roadmap …` line. Chain, milestone and roadmap rows all qualify.
- Each such row is printed exactly as the board prints it — so indented only where the board
  indents it — followed by its `⤷ milestone …` or `⤷ roadmap …` line. A `⤷ inputs:` line is
  not printed.
- Output is held under 9,000 bytes; when rows are left out, one last line says how many.

**External facts this plan depends on,** each re-checked against the local copies of the
Claude Code docs fetched on 2026-10-13 with `curl -sS -L '<url>.md'`
(`hooks.md`, 268,811 bytes; `plugins-reference.md`, 41,987 bytes):

| Fact | Source |
|---|---|
| Plain-text stdout of a `SessionStart` hook is added as context | `hooks.md:810` |
| Hook stdout is capped at 10,000 characters | `hooks.md:996` |
| A group with no matcher fires on every occurrence of the event | `hooks.md:207` |
| `SessionStart` fires for `startup`, `resume`, `clear`, `compact`, `fork` | `hooks.md:1190-1194` |
| The payload's `cwd` is the worktree root after Claude enters a worktree | `hooks.md:612-613` |
| `hooks/hooks.json` is merged when it exists | `plugins-reference.md:264` |
| The file wraps the event map in a top-level `"hooks"` key | `plugins-reference.md:262` |
| `${CLAUDE_PLUGIN_ROOT}` is the plugin's installed path | `plugins-reference.md:556` |

**Not verified, and nothing here depends on it:** whether the text also reaches subagents.

**Decisions this plan makes where the spec is silent.** Each is reported to the author at the
plan's approval gate:

- The limit is counted in bytes. Claude Code's cap is in characters, and a byte count is never
  smaller than a character count, so 9,000 bytes is always under 10,000 characters.
- The line that says how many rows were left out reads `  (<n> more rows not shown)`.

**Where this plan departs from the spec.** Reported to the author at the plan's approval gate:

- **"Open" in the first line follows plan 04's widened term.** Spec §9 cites §7.1 for the
  count, and §7.1 defines an open chain as one whose intent is `draft` or `approved`. The
  first line counts `M.board`'s `open` instead: every chain that has a row, so a chain that
  is `INVALID` for want of a readable intent is counted. By the spec's wording the third test
  of Task 1 would read `7 open`; it asserts `8 open`.
- **The build order is relaxed.** Spec §12 puts the hook after both the sync work and the
  roadmap work, which includes the two new skills. This plan depends on plan 04 only and may
  run beside plan 05, as the author agreed when approving the plan set. The two touch
  disjoint files: plan 05 edits `SKILL.md` files, this plan edits Lua, shell and
  `hooks/hooks.json`.
- **A `done` or `dropped` chain costs more than one read.** Spec §9 says it "cost[s] one
  frontmatter read"; plan 02 keeps today's reading of every artifact, following spec §3.
  The author has not yet ruled on which sentence stands (plan 02, decisions list). Measured
  on this repository, where eight of the ten chains are `done` or `dropped`, the hook took
  about 0.03 s, far inside the one-second requirement.

### Task 1 — List the rows that need attention

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`
- Modify `plugins/claudestacks-sdlc/scripts/lib/status.lua`

**Steps:**

1. Add four tests at the end of the returned table in `status_test.lua`. They use the
   `INTENT`, `SPEC`, `BUILT`, `STALE` and `FP` fixtures and the `member`, `roadmap_file` and
   `trimmed` helpers written in plans 02 and 04:

   ```lua
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

     attention_lists_roadmap_rows_and_problem_notes_but_not_inputs = function()
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
   ```

   The third test holds one chain per trigger word plus two that must not be listed
   (`2026-10-07-ready`, a plan ready to execute, and `2026-10-08-idea`, a draft intent). The
   fourth holds a milestone row and a chain row that qualify only through their notes.

2. Run and confirm failure:

   ```
   $ cargo make plugins-test
   ```

   Expected: `486 passed, 4 failed (22 files)`, each failing with
   `attempt to call a nil value (field 'attention')`.

3. In `plugins/claudestacks-sdlc/scripts/lib/status.lua`, insert the following between the
   end of `M.render` and the final `return M`:

   ```lua
   -- Words in a STATE cell that mean the row needs someone's attention.
   local ATTENTION_WORDS = { "INVALID", "stale", "blocked", "disproven", "complete" }

   -- True for a `⤷ milestone …` or `⤷ roadmap …` note; a `⤷ inputs:` note is
   -- provenance, not a problem.
   local function is_problem_note(note)
     return note:find("⤷ milestone ", 1, true) == 1 or note:find("⤷ roadmap ", 1, true) == 1
   end

   -- Whether a board row needs attention: its STATE holds one of the attention
   -- words, it names a plan as `executing`, or it carries a problem note.
   function M.needs_attention(row)
     if row.kind == "heading" then
       return false
     end
     for _, word in ipairs(ATTENTION_WORDS) do
       if row.state:find(word, 1, true) then
         return true
       end
     end
     if row.state:find("plan %d%d executing") then
       return true
     end
     for _, note in ipairs(row.notes) do
       if is_problem_note(note) then
         return true
       end
     end
     return false
   end

   -- The session-start text for one chain root: a first line counting the open
   -- chains and the rows needing attention, then those rows exactly as the
   -- board prints them, each followed by its problem notes. Empty when the
   -- chain root does not exist.
   function M.attention(rootdir)
     if not (fs.exists(rootdir) and fs.is_dir(rootdir)) then
       return ""
     end
     local board = M.board(rootdir)

     local blocks = {}
     for _, row in ipairs(board.rows) do
       if M.needs_attention(row) then
         local lines = { M.row_lines(row)[1] }
         for _, note in ipairs(row.notes) do
           if is_problem_note(note) then
             lines[#lines + 1] = string.rep(" ", row.indent) .. "  " .. note
           end
         end
         blocks[#blocks + 1] = table.concat(lines, "\n")
       end
     end

     local out = { string.format(
       "claudestacks-sdlc: %d open, %d need attention — full board: /claudestacks-sdlc:status",
       board.open, #blocks) }
     for _, block in ipairs(blocks) do
       out[#out + 1] = block
     end
     return table.concat(out, "\n")
   end

   ```

   `M.row_lines(row)[1]` is the row's own line; its notes are re-added here so only the
   problem notes are kept. Every state the board prints for a finished milestone, roadmap or
   chain contains the word `complete`, and no other state does.

4. Run and confirm green:

   ```
   $ cargo make plugins-test
   490 passed, 0 failed (22 files)
   ```

5. Commit `feat(repo): list the sdlc board rows that need attention`.

### Task 2 — Hold the text under its size limit

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`
- Modify `plugins/claudestacks-sdlc/scripts/lib/status.lua`

**Steps:**

1. Add one test at the end of the returned table in `status_test.lua`:

   ```lua
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
   ```

   Two hundred chain directories with no `intent.md` each render an `INVALID` row of 104
   bytes plus a newline (a 34-character name padded to 36, a state padded to 30, a 38-character
   NEXT), about 21,000 bytes in all — more than twice the limit.

2. Run and confirm failure:

   ```
   $ cargo make plugins-test
   ```

   Expected: `490 passed, 1 failed (22 files)`, failing with
   `attempt to compare number with nil` because `status.ATTENTION_LIMIT` does not exist yet.

3. In `lib/status.lua`, insert directly after the `ATTENTION_WORDS` line written in Task 1:

   ```lua

   -- The session-start text is held under this many bytes: Claude Code caps a
   -- hook's stdout at 10,000 characters, and a byte count never undercounts.
   M.ATTENTION_LIMIT = 9000

   -- Bytes kept free for the line that says how many rows were left out.
   local ATTENTION_RESERVE = 64
   ```

4. In `M.attention`, replace the loop written in Task 1:

   ```lua
     for _, block in ipairs(blocks) do
       out[#out + 1] = block
     end
     return table.concat(out, "\n")
   ```

   with:

   ```lua
     local size = #out[1]
     for i, block in ipairs(blocks) do
       if size + 1 + #block > M.ATTENTION_LIMIT - ATTENTION_RESERVE then
         out[#out + 1] = string.format("  (%d more rows not shown)", #blocks - i + 1)
         break
       end
       out[#out + 1] = block
       size = size + 1 + #block
     end
     return table.concat(out, "\n")
   ```

   The first line still counts every row that needs attention, shown or not. The reserve is
   larger than the longest possible trailer, so the total stays under the limit.

5. Run and confirm green:

   ```
   $ cargo make plugins-test
   491 passed, 0 failed (22 files)
   ```

6. Commit `feat(repo): cap the sdlc session-start text below the hook limit`.

### Task 3 — Add the hook entry point and its launcher

**Files:**
- Create `plugins/claudestacks-sdlc/scripts/attention.lua`
- Create `plugins/claudestacks-sdlc/scripts/attention.sh`

**Steps:**

1. Confirm the launcher does not exist yet. Run from the repository root:

   ```
   $ sh plugins/claudestacks-sdlc/scripts/attention.sh; echo "exit=$?"
   sh: plugins/claudestacks-sdlc/scripts/attention.sh: No such file or directory
   exit=127
   ```

2. Write `plugins/claudestacks-sdlc/scripts/attention.lua`:

   ```lua
   -- SessionStart hook for claudestacks-sdlc: prints the board rows that need
   -- attention, which Claude Code adds to the session's context.
   --
   --   airsl run --fail-open --policy confined --allow-read / scripts/attention.lua
   --
   -- The chain root is taken from the hook payload's `cwd` — the session's
   -- directory, which in a worktree is the worktree root — and from the process
   -- directory when no payload arrives.

   local status = require("lib.status")
   local path = airsstack.path

   local ok, payload = pcall(airsstack.hook.payload)
   local cwd = ok and type(payload) == "table"
     and type(payload.cwd) == "string" and payload.cwd ~= "" and payload.cwd
     or path.absolute(".")

   local text = status.attention(path.join(cwd, status.ROOT))
   if text ~= "" then
     airsstack.stdio.write(text .. "\n")
   end
   ```

   The sibling plugin reads the payload the same way
   (`plugins/claudestacks/hooks/enforce.lua:116`, `:128-129`).

3. Write `plugins/claudestacks-sdlc/scripts/attention.sh`:

   ```sh
   #!/bin/sh
   # claudestacks-sdlc SessionStart launcher. Resolves airsl without relying on
   # PATH (hooks are spawned by the CLI, not a login shell, so a cargo-installed
   # binary under ~/.cargo/bin can be present but invisible). Every path exits
   # 0 and prints nothing when airsl is missing: a hook must never break a
   # session, and deliberately no `exec` — that would hand airsl's status back
   # to Claude Code.

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

   # Read anywhere: the chain root comes from the payload's `cwd`, which need
   # not be the directory this script is launched from.
   "$AIRSL" run --fail-open --policy confined \
     --allow-read / \
     "$DIR/attention.lua" || exit 0

   exit 0
   ```

   The `airsl` resolution is the one `scripts/status.sh:9-24` uses. The grant differs:
   `status.sh` grants `--allow-read .` because it reads the directory it is launched from,
   while a hook is told its directory in the payload, so this grants `--allow-read /` as the
   sibling plugin's hook does (`plugins/claudestacks/hooks/enforce.sh:36-39`).

4. Confirm both Lua files compile:

   ```
   $ cargo make plugins-check
   ```

   Expected: exit 0. `attention.lua` is loaded by no test, so this is the only gate that reads
   it.

5. Run the launcher four ways, from the repository root. With a payload naming this
   repository:

   ```
   $ printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}' "$PWD" | sh plugins/claudestacks-sdlc/scripts/attention.sh; echo "exit=$?"
   ```

   Expected: a first line of the form
   `claudestacks-sdlc: <n> open, <k> need attention — full board: /claudestacks-sdlc:status`,
   then `<k>` rows, then `exit=0`. While this plan is being executed, this chain's row is one
   of them, because it names a plan as `executing`. Every row printed must appear, character
   for character, in the output of `sh plugins/claudestacks-sdlc/scripts/status.sh`.

   With no payload, so the process directory is used:

   ```
   $ sh plugins/claudestacks-sdlc/scripts/attention.sh </dev/null; echo "exit=$?"
   ```

   Expected: the same text as the first run, then `exit=0`.

   With a payload naming a directory that has no chain root:

   ```
   $ printf '{"hook_event_name":"SessionStart","cwd":"/tmp"}' | sh plugins/claudestacks-sdlc/scripts/attention.sh; echo "exit=$?"
   exit=0
   ```

   With `airsl` out of reach:

   ```
   $ printf '{"cwd":"%s"}' "$PWD" | env -i HOME=/nonexistent PATH=/usr/bin:/bin sh plugins/claudestacks-sdlc/scripts/attention.sh; echo "exit=$?"
   exit=0
   ```

   The last two print nothing but the `exit=0` line.

6. Commit `feat(repo): add the sdlc session-start attention script`.

### Task 4 — Declare the hook

**Files:**
- Create `plugins/claudestacks-sdlc/hooks/hooks.json`

**Steps:**

1. Confirm the plugin ships no hooks today:

   ```
   $ ls plugins/claudestacks-sdlc/hooks
   ls: plugins/claudestacks-sdlc/hooks: No such file or directory
   ```

2. Write `plugins/claudestacks-sdlc/hooks/hooks.json`:

   ```json
   {
     "hooks": {
       "SessionStart": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "sh \"${CLAUDE_PLUGIN_ROOT}/scripts/attention.sh\""
             }
           ]
         }
       ]
     }
   }
   ```

   No `matcher`: the group must fire for every way a session starts, including `compact`,
   after which the earlier attention text is gone from context. The shape — the top-level
   `"hooks"` key, the group, the command quoting — is the one the sibling plugin already ships
   in `plugins/claudestacks/hooks/hooks.json`.

3. Confirm it parses and declares exactly one event:

   ```
   $ jq -r '.hooks | keys | join(",")' plugins/claudestacks-sdlc/hooks/hooks.json
   SessionStart
   $ jq -r '.hooks.SessionStart[0].hooks[0].command' plugins/claudestacks-sdlc/hooks/hooks.json
   sh "${CLAUDE_PLUGIN_ROOT}/scripts/attention.sh"
   $ jq -r '.hooks.SessionStart[0] | has("matcher")' plugins/claudestacks-sdlc/hooks/hooks.json
   false
   ```

4. Confirm the command resolves when the variable is set the way Claude Code sets it:

   ```
   $ printf '{"cwd":"%s"}' "$PWD" | CLAUDE_PLUGIN_ROOT="$PWD/plugins/claudestacks-sdlc" sh -c 'sh "${CLAUDE_PLUGIN_ROOT}/scripts/attention.sh"'; echo "exit=$?"
   ```

   Expected: the same text as Task 3 step 5's first run, then `exit=0`.

5. Commit `feat(repo): run the sdlc attention script at session start`.

### Task 5 — Record the hook's output and wall time

**Steps:**

1. Time the hook on this repository's chain root. Run from the repository root:

   ```
   $ time (printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}' "$PWD" | sh plugins/claudestacks-sdlc/scripts/attention.sh >/dev/null)
   ```

   Expected: `real` under one second (spec §9). A prototype of this code measured
   `real 0m0.031s` on this repository on 2026-10-14, with ten chains under the chain root. If
   the measurement is one second or more, stop and report it: the spec makes that a
   requirement, not a target.

2. Run the hook on a throwaway chain root that holds rows needing attention. This
   repository's own root has almost none, so it is the only run in which the real entry
   point — `attention.sh` into `attention.lua` — prints stale, complete and annotated rows;
   the tests reach `M.attention` through the library, not through the launcher. Write this
   script to a temp path outside the repository, e.g. `${TMPDIR:-/tmp}/sdlc-hook-walk.sh`:

   ```sh
   #!/bin/sh
   # Hook walkthrough for plan 06 of 2026-10-13-sdlc-roadmaps-milestones.
   #   sh sdlc-hook-walk.sh <absolute path of the repository root>
   # Builds one throwaway chain root holding rows that need attention and rows
   # that do not, then runs the SessionStart launcher against it and times it.
   set -eu
   REPO=$1
   P="$REPO/plugins/claudestacks-sdlc"

   fp() { sh "$P/scripts/fingerprint.sh" "$1"; }

   # art <file> <body> <frontmatter line>... — writes one artifact.
   art() {
     f=$1; body=$2; shift 2
     mkdir -p "$(dirname "$f")"
     {
       echo '---'
       for line in "$@"; do echo "$line"; done
       echo '---'
       printf '%s\n' "$body"
     } > "$f"
   }

   WT=$(mktemp -d)
   R="$WT/.claudestacks/sdlc"

   # A plan left approved after its spec changed.
   C="$R/2026-10-15-stale"
   art "$C/intent.md" "# Intent: stale" "status: approved" "created: 2026-10-15"
   art "$C/spec.md" "# Spec: stale" \
     "status: approved" "created: 2026-10-15" "built-on: $(fp "$C/intent.md")"
   art "$C/plans/01-core.md" "# Core Implementation Plan" \
     "status: approved" "created: 2026-10-15" "built-on: 000000000000"

   # A finished chain whose intent was never flipped.
   C="$R/2026-10-16-missed"
   art "$C/intent.md" "# Intent: missed" \
     "status: approved" "created: 2026-10-16" "spec: skipped"
   art "$C/plans/01-core.md" "# Core Implementation Plan" \
     "status: done" "created: 2026-10-16"

   # A chain still naming a dropped milestone.
   art "$R/roadmaps/platform/roadmap.md" "# Roadmap: platform" \
     "status: approved" "created: 2026-10-14"
   art "$R/roadmaps/platform/01-auth.md" "# Milestone: auth" \
     "status: dropped" "created: 2026-10-14"
   art "$R/2026-10-17-parked/intent.md" "# Intent: parked" \
     "status: draft" "created: 2026-10-17" "milestone: platform/01"

   # Two chains that need nothing.
   art "$R/2026-10-18-idea/intent.md" "# Intent: idea" "status: draft" "created: 2026-10-18"
   art "$R/2026-10-19-old/intent.md" "# Intent: old" "status: done" "created: 2026-10-19"

   payload() { printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}' "$WT"; }

   printf '%s\n' '-- the board'
   ( cd "$WT" && sh "$P/scripts/status.sh" )
   printf '\n%s\n' '-- the hook'
   payload | sh "$P/scripts/attention.sh"
   printf '\n%s\n' '-- its wall time'
   time ( payload | sh "$P/scripts/attention.sh" >/dev/null )
   ```

   Run it with the repository root's absolute path:

   ```
   $ sh "${TMPDIR:-/tmp}/sdlc-hook-walk.sh" "$(git rev-parse --show-toplevel)"
   ```

   Expected, apart from trailing spaces on rows whose NEXT is empty:

   ```
   -- the board
   CHAIN                             STATE                         NEXT
   ROADMAP platform                  approved, 0 of 0 milestones done  add milestone
   MILESTONE platform/01-auth        dropped
     2026-10-17-parked               intent draft                  approve or drop
       ⤷ milestone platform/01 is dropped — release this chain
   UNASSIGNED
     2026-10-15-stale                plan 01 approved: stale (spec changed)  plan
     2026-10-16-missed               chain complete                execute walk-up
     2026-10-18-idea                 intent draft                  approve or drop
   DONE/DROPPED: 1 done, 0 dropped (not listed)

   -- the hook
   claudestacks-sdlc: 4 open, 3 need attention — full board: /claudestacks-sdlc:status
     2026-10-17-parked               intent draft                  approve or drop
       ⤷ milestone platform/01 is dropped — release this chain
     2026-10-15-stale                plan 01 approved: stale (spec changed)  plan
     2026-10-16-missed               chain complete                execute walk-up

   -- its wall time
   ```

   followed by `time`'s three lines, with `real` under one second. This is the output a
   prototype of this code printed on 2026-10-14, where `real` was `0m0.012s`. The hook's
   three rows are in board order and each is character for character a row of the board
   above it; `2026-10-18-idea` and the roadmap and milestone rows are on the board and not in
   the hook, because nothing about them needs attention.

3. Paste into this plan's `## Probe results`: the full output of Task 3 step 5's first run,
   the three `exit=0` lines of the other runs, the `time` output of step 1, and the full
   output of step 2.

4. **Checkpoint — stop and report to the author:** the four commits, the hook's output for
   this repository and for the throwaway root, and both wall times. Say plainly that the hook has been run by hand and by
   its declared command line, and that it has **not** been observed firing inside a live
   Claude Code session: that needs the plugin installed from this working tree and a session
   restart, which is the author's to do. Offer the check: after reinstalling, start a session
   in this repository and ask the agent what the first line beginning `claudestacks-sdlc:` in
   its context says.

---

## Verification summary (plan-level)

- `cargo make plugins-check` exits 0 with `scripts/attention.lua` compiled.
- `cargo make plugins-test` prints `491 passed, 0 failed (22 files)` and
  `fingerprint gate: 8 cases passed`.
- The launcher exits 0 and prints nothing with no chain root and with `airsl` out of reach.
- Every row the hook prints appears unchanged in the board from `scripts/status.sh`.
- The hook's output and wall time are recorded for this repository and for a throwaway root
  holding stale, complete and annotated rows; both times are under one second.
- Not verified by this plan: the hook firing inside a live session, and its text reaching
  subagents.
