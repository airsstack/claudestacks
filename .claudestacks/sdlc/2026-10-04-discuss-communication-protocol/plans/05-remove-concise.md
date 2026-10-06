---
status: approved
created: 2026-10-04
depends-on: [01, 02, 03, 04]
---

# Remove Concise Implementation Plan

**Goal:** Nothing in the repository runs, ships or names the `concise` skill any more.

**Architecture:** Plan 01's reply-rules hook already does what `concise`'s per-turn re-injection did, so `concise` can go without a gap: its skill, tracker, library, tests and hook entry are deleted, and every other mention (spec §9, plus two the review found) is reworded to the communication protocol. `CLAUDE.md` stops telling sessions to load a skill that no longer exists. One version bump (`0.1.7 → 0.2.0`) ships all five plans in one PR (spec P16; landing agreed in planning). A `git grep` closes the plan, run first as a control.

**Tech Stack:** Markdown, JSON, POSIX `sh`, `airsl` Lua 5.4 (comments only), `git grep`.

---

## File structure

```
plugins/claudestacks/skills/concise/                    — [delete]
plugins/claudestacks/hooks/concise-tracker.sh           — [delete]
plugins/claudestacks/hooks/concise-tracker.lua          — [delete]
plugins/claudestacks/hooks/lib/concise.lua              — [delete]
plugins/claudestacks/hooks/concise_test.lua             — [delete] (18 tests)
plugins/claudestacks/hooks/hooks.json                   — [modify] drop the concise-tracker entry
plugins/claudestacks/hooks/preflight.sh                 — [modify] lines 12, 41
plugins/claudestacks/hooks/enforce_test.lua             — [modify] comments at lines 65, 125-126
plugins/claudestacks/skills/snapshot-save/SKILL.md      — [modify] line 45
plugins/claudestacks/README.md                          — [modify] lines 40, 49-50, 54-57, 65, 81, 225-229
plugins/claudestacks/.claude-plugin/plugin.json         — [modify] description, version
.claude-plugin/marketplace.json                         — [modify] line 12 description
README.md                                               — [modify] lines 43, 61-62
CLAUDE.md                                               — [modify] lines 103-104, 200, 228
```

Every line number above was read on 2026-10-04 with `git grep -n -i concise -- . ':!crates' ':!.claudestacks'`, which listed 18 files. Plans 01–04 do not touch these lines, so they still hold; the Task 1 step 1 check re-reads them before anything is edited — use its output if any moved. (After plan 01 the plain word grep also finds rule 4 of the protocol and its test; those stay, spec §11.) `.claude-plugin/marketplace.json` carries no plugin version; only `plugins/claudestacks/.claude-plugin/plugin.json:3` does (`grep -n '"version"'`, 2026-10-04).

### Task 1 — Delete the skill and its hook

**Files:**
- Delete `plugins/claudestacks/skills/concise/`, `plugins/claudestacks/hooks/concise-tracker.sh`, `plugins/claudestacks/hooks/concise-tracker.lua`, `plugins/claudestacks/hooks/lib/concise.lua`, `plugins/claudestacks/hooks/concise_test.lua`
- Modify `plugins/claudestacks/hooks/hooks.json`

**Steps:**

1. Run the closing check as a control and keep its output (the red state). It targets references
   to the skill, not the English word (spec §11 as amended):

   ```
   $ git grep -n -i -E 'claudestacks:concise|concise-tracker|concise tracker|concise hook|concise (output|response) mode|lib/concise|concise_test|skills/concise|`concise`' -- . ':!crates' ':!.claudestacks' | cut -d: -f1,2
   .claude-plugin/marketplace.json:12
   CLAUDE.md:103
   CLAUDE.md:228
   README.md:43
   README.md:61
   plugins/claudestacks/.claude-plugin/plugin.json:4
   plugins/claudestacks/README.md:40
   plugins/claudestacks/README.md:49
   plugins/claudestacks/README.md:54
   plugins/claudestacks/README.md:65
   plugins/claudestacks/README.md:81
   plugins/claudestacks/README.md:225
   plugins/claudestacks/README.md:227
   … (lines in the files this task deletes)
   plugins/claudestacks/hooks/enforce_test.lua:65
   plugins/claudestacks/hooks/enforce_test.lua:125
   plugins/claudestacks/hooks/hooks.json:38
   plugins/claudestacks/hooks/preflight.sh:12
   plugins/claudestacks/hooks/preflight.sh:41
   plugins/claudestacks/skills/snapshot-save/SKILL.md:45
   ```

2. Delete the files:

   ```
   $ git rm -r plugins/claudestacks/skills/concise plugins/claudestacks/hooks/concise-tracker.sh plugins/claudestacks/hooks/concise-tracker.lua plugins/claudestacks/hooks/lib/concise.lua plugins/claudestacks/hooks/concise_test.lua
   ```

3. In `plugins/claudestacks/hooks/hooks.json`, remove this object from the `UserPromptSubmit` group's `hooks` array, leaving plan 01's `style.sh --turn` entry as the only one:

   ```json
             {
               "type": "command",
               "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/concise-tracker.sh\""
             },
   ```

4. Run the gate and validation:

   ```
   $ cargo make plugins
   … 0 failed …
   $ claude plugin validate plugins/claudestacks
   ✔ Validation passed
   ```

   `airsl check` would fail here if anything still required `lib.concise`; nothing does (`git grep -n 'lib.concise' -- plugins` after the delete returns only the comment at `hooks/enforce_test.lua:125`, fixed in Task 2).

5. Commit `refactor(repo): remove the concise skill and its prompt tracker`.

### Task 2 — Reword the plugin's own mentions

**Files:**
- Modify `plugins/claudestacks/hooks/preflight.sh`, `plugins/claudestacks/hooks/enforce_test.lua`, `plugins/claudestacks/skills/snapshot-save/SKILL.md`, `plugins/claudestacks/README.md`, `plugins/claudestacks/.claude-plugin/plugin.json`

**Steps:**

1. `plugins/claudestacks/hooks/preflight.sh` — replace line 12

   ```
   # enforcement, the concise tracker, SDD layout provisioning and the journal orientation card — all
   ```

   with

   ```
   # enforcement, the reply rules, SDD layout provisioning and the journal orientation card — all
   ```

   and line 41

   ```
     echo 'Disabled: rule enforcement, the concise tracker, SDD layout provisioning, and the'
   ```

   with

   ```
     echo 'Disabled: rule enforcement, the reply rules, SDD layout provisioning, and the'
   ```

2. `plugins/claudestacks/hooks/enforce_test.lua` — replace line 65

   ```
   -- Splits `text` into lines. Every driver under `plugins/` (`enforce.lua`, `concise-tracker.lua`,
   ```

   with

   ```
   -- Splits `text` into lines. Every driver under `plugins/` (`enforce.lua`, `style.lua`,
   ```

   and lines 125-126

   ```
   -- not hypothetical: `lib/concise.lua` builds its patterns with them (`regex.compile([[\bnormal
   -- mode\b]])` and seven more), so a `--` inside one would truncate a real line of this suite.
   ```

   with

   ```
   -- not hypothetical: `scripts/lib/comm_report.lua` builds its topic pattern with one
   -- (`regex.compile([[^(\d+)\. (\S.*)$]])`), so a `--` inside one would truncate a real line.
   ```

3. `plugins/claudestacks/skills/snapshot-save/SKILL.md` — replace line 45

   ```
   Keeping them in `~/.airsstack` (same root the `concise` hook uses) gives one user-global state
   ```

   with

   ```
   Keeping them in `~/.airsstack` (same root the `discuss` archive uses) gives one user-global state
   ```

4. `plugins/claudestacks/README.md`:
   - line 40, replace the `concise` row with

     ```
     | `discuss` | `/claudestacks:discuss` opens, browses and closes a topic-indexed discussion: agents hand back a short summary plus numbered topics, the detail stays on disk until a topic is opened, and closed discussions are archived per project. Its `references/protocol.md` is the communication protocol, reply rules included. |
     ```

   - lines 49-50, replace

     ```
     - `UserPromptSubmit` → re-inject the active `concise` level each turn (persistent concise mode; no-op
       when no level is active).
     ```

     with

     ```
     - `SessionStart` (every source) and `UserPromptSubmit` → print the communication protocol's reply
       rules (per prompt unless the `style_reinject` option is off).
     - `PostToolUse` `Write`, `PreToolUse` `SubagentHandback`, `SubagentStop` → check communication
       protocol reports, beside the Context Handoff check.
     ```

   - lines 54-57, replace

     ```
     ### Concise hook runtime

     The `UserPromptSubmit` hook — like every other airsl-backed hook in the suite (`enforce.lua`,
     `rearm.lua`, SDD layout provisioning, the journal orientation card) — runs on
     ```

     with

     ```
     ### Hook runtime

     The reply-rules hook — like every other airsl-backed hook in the suite (`enforce.lua`,
     `rearm.lua`, SDD layout provisioning, the journal orientation card) — runs on
     ```

   - line 65, replace `with a user-visible effect (rule enforcement, the concise tracker, SDD layout provisioning, the` with `with a user-visible effect (rule enforcement, the reply rules, SDD layout provisioning, the`
   - line 81, replace `user-global root the \`concise\` hook uses), with a custom \`index.md\`. \`<project-key>\` is derived from` with `user-global root the \`discuss\` archive uses), with a custom \`index.md\`. \`<project-key>\` is derived from`
   - lines 225-229, replace the whole `## Attribution` section body (heading at 223 stays) (from `The \`concise\` skill is` through `is claudestacks's own.`) with

     ```
     The reply rules in the `discuss` skill's communication protocol replace an earlier terseness
     mode that was inspired by the [caveman](https://github.com/juliusbrussee/caveman) plugin.
     That earlier mode kept its state in `~/.airsstack/cc/concise.json`. Nothing reads that file any
     more; it can be deleted.
     ```

5. `plugins/claudestacks/.claude-plugin/plugin.json` — replace the `description` value with

   ```
   Execution engine: a TDD coder, a merged code+spec reviewer, and a read-only explorer, plus an orchestration driver, process guidelines, project-local memory, and /claudestacks:discuss — a communication protocol that keeps agent detail on disk behind numbered topics.
   ```

6. Check the plugin is clean:

   ```
   $ git grep -n -i -E 'claudestacks:concise|concise-tracker|concise tracker|concise hook|concise (output|response) mode|lib/concise|concise_test|skills/concise|`concise`' -- plugins/claudestacks
   ```

   No output. (`git grep -i concise` would still show rule 4 of the protocol, its test, the
   `concise.json` note and `snapshot-load/SKILL.md:64` — all intended.)

7. Commit `docs(repo): reword the claudestacks plugin's concise mentions`.

### Task 3 — Reword the repository's mentions

**Files:**
- Modify `.claude-plugin/marketplace.json`, `README.md`, `CLAUDE.md`

**Steps:**

1. `.claude-plugin/marketplace.json` line 12 — set `description` to the same text as Task 2 step 5.

2. `README.md`:
   - line 43, replace `project-local snapshot memory, and a \`concise\` output mode. |` with `project-local snapshot memory, and \`/claudestacks:discuss\`, a communication protocol with topic-indexed agent output. |`
   - lines 61-62, replace

     ```
     [superpowers](https://github.com/obra/superpowers) plugin. The `concise` skill in `claudestacks`
     is inspired by [caveman](https://github.com/juliusbrussee/caveman).
     ```

     with

     ```
     [superpowers](https://github.com/obra/superpowers) plugin. The reply rules in `claudestacks`'s
     communication protocol replace an earlier terseness mode inspired by
     [caveman](https://github.com/juliusbrussee/caveman).
     ```

3. `CLAUDE.md`:
   - lines 103-104, replace

     ```
     **Load the `claudestacks:concise` skill before answering if it is not already loaded this session.**
     Its level and rules govern reply style; the guidance in this section sits on top of it.
     ```

     with

     ```
     **The `claudestacks` plugin's hooks deliver the communication protocol's reply rules every
     session; there is nothing to load.** The guidance in this section sits on top of them.
     ```

   - line 228, replace `project-local snapshot memory; concise output mode |` with `project-local snapshot memory; /discuss communication protocol |`
   - line 200, replace `266 assertions across 16 files` with the totals `cargo make plugins-test` prints now, in the form `<passed> tests across <files> files`. Expected: `387 tests across 20 files` (346 before this chain − 18 `concise_test.lua` + 10 `style_test.lua` + 17 `comm_report_test.lua` + 28 `discuss_test.lua` + 4 `discuss_skill_test.lua`; 17 files − 1 + 4). Use the gate's numbers if they differ, and say why in the commit body.

4. Commit `docs(repo): reword the repository's concise mentions`.

### Task 4 — Bump the version and close

**Files:**
- Modify `plugins/claudestacks/.claude-plugin/plugin.json`

**Steps:**

1. In `plugins/claudestacks/.claude-plugin/plugin.json`, change `"version": "0.1.7"` to `"version": "0.2.0"`.

2. Run the closing check:

   ```
   $ git grep -n -i -E 'claudestacks:concise|concise-tracker|concise tracker|concise hook|concise (output|response) mode|lib/concise|concise_test|skills/concise|`concise`' -- . ':!crates' ':!.claudestacks'; echo "exit=$?"
   exit=1
   ```

   No output (`git grep` exits 1 when nothing matches). Any line printed is a missed reference.

3. Run the full gate and validation:

   ```
   $ cargo make plugins
   387 passed, 0 failed (20 files)
   $ claude plugin validate plugins/claudestacks
   ✔ Validation passed
   ```

4. Commit `chore(repo): bump claudestacks to 0.2.0 for the discuss protocol`.

### Task 5 — Live acceptance (by hand, after the change is installable)

The installed `claudestacks` is read from the marketplace's checkout, not this worktree, so this runs once that checkout holds this branch (merged, or the branch checked out there), followed by `claude plugin update claudestacks@claudestacks` and a new session.

1. In a new session, confirm the reply rules arrived: the first prompt's context carries `## Reply rules`.
2. `/claudestacks:discuss` → `started discussion <sid8> (0 topics)`.
3. Ask for something that spawns one subagent under the protocol; confirm the reply shows its summary and `<id> <title>` lines, and `<detail>` is not pasted.
4. `/claudestacks:discuss list` → the topics; `/claudestacks:discuss 1` → that section only.
5. `/claudestacks:discuss done` → `closed discussion <sid8>`.
6. In another worktree of the repository, a new session: `/claudestacks:discuss list archive` → the closed discussion's topics as `<sid8>/<id>`.
7. Record the transcript's outcome in the PR body. Any step that fails is a defect against plans 01–04, fixed there.

## Verification summary (plan-level)

- The closing `git grep` (skill references, spec §11 as amended) returns nothing, after listing every §9 mention as the control.
- `cargo make plugins` green with the expected totals; `claude plugin validate` passes.
- Version `0.2.0` in `plugin.json`.
- Live acceptance (Task 5) passes once installable.
