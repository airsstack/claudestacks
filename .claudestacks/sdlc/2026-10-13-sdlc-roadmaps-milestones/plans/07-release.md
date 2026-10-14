---
status: executing
created: 2026-10-14
depends-on: [05, 06]
built-on: a5a235079e03
---

# Release 0.2.0 Implementation Plan

**Goal:** The plugin is published as version 0.2.0 with documentation that describes what it
now does.

**Architecture:** No behaviour changes here. Five documents that describe the plugin are
brought in line with plans 01 to 06, and the manifest version moves from `0.1.2` to `0.2.0`,
which is what makes a copied install pick the new skills, scripts and hook up. The version
bump is the last commit, so no installed copy ever claims 0.2.0 with stale documentation.

**Tech Stack:** Markdown, JSON, `jq`, `claude plugin validate`.

**Content authority:** spec §12 (documentation, version).

---

## File structure

```
plugins/claudestacks-sdlc/README.md                    — [modify] sync checks, roadmaps, the two new skills, the hook
plugins/claudestacks-sdlc/.claude-plugin/plugin.json   — [modify] description, version 0.2.0
.claude-plugin/marketplace.json                        — [modify] the plugin's description
CLAUDE.md                                              — [modify] the plugin table row, the Lua test count
README.md                                              — [modify] the plugin table row
```

Every path below is relative to the repository root. There is no test for prose; each step's
check is a `grep` for text absent before the edit and present after it. The closing gate is
`cargo make plugins` plus `claude plugin validate --strict plugins/claudestacks-sdlc`, which
printed `✔ Validation passed` on the unchanged plugin on 2026-10-14.

### Task 1 — Describe the new behaviour in the plugin README

**Files:**
- Modify `plugins/claudestacks-sdlc/README.md`

**Steps:**

1. Confirm the new text is absent:

   ```
   $ grep -c 'roadmap\|built-on\|SessionStart' plugins/claudestacks-sdlc/README.md
   0
   ```

2. Replace the opening paragraph (`README.md:3-8`):

   ```markdown
   AI-native SDLC workflow for Claude Code: a committed `intent → design → plan → execute`
   chain with `distill` and `triage` feedback loops and a deterministic status board. Six
   skills, guided one question at a time, implement Anthropic's
   [AI-native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook) at
   single-author scale — every stage gates on frontmatter state, and nothing in the chain is
   ever deleted.
   ```

   with:

   ```markdown
   AI-native SDLC workflow for Claude Code: a committed `intent → design → plan → execute`
   chain with `distill` and `triage` feedback loops and a deterministic status board. Six
   skills, guided one question at a time, implement Anthropic's
   [AI-native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook) at
   single-author scale — every stage gates on frontmatter state, and nothing in the chain is
   ever deleted. The board also checks that related artifacts still agree, and optional
   roadmaps and milestones sit above the chains with progress that is counted, never
   written down.
   ```

3. In the `execute` bullet, replace its last clause (`README.md:55-56`):

   ```markdown
     plan before flipping it `done`; rolls the intent up to `done` once every sibling plan is
     `done` or `superseded` with at least one `done`.
   ```

   with:

   ```markdown
     plan before flipping it `done`; walks the intent up to `done` once every sibling plan is
     `done` or `superseded` with at least one `done` and no stale or disproven spec stands,
     then rolls up the chain's milestone and roadmap if it has one.
   ```

4. In the layout block of `## Artifact chain`, replace (`README.md:73-75`):

   ```
   ├── rfcs/                                  # optional technical input docs (inbox)
   │   └── .gitkeep
   ├── REVIEW.md                              # review policy, from template
   ```

   with:

   ```
   ├── rfcs/                                  # optional technical input docs (inbox)
   │   └── .gitkeep
   ├── roadmaps/                              # optional; created by the roadmap skill
   │   └── platform/
   │       ├── roadmap.md
   │       └── 01-auth.md                     # one file per milestone
   ├── REVIEW.md                              # review policy, from template
   ```

5. Insert three sections between the paragraph that ends "resolve against it rather than
   restating the rules locally." (`README.md:84-86`) and the heading `## Operational skills`:

   ```markdown
   ## Keeping artifacts in sync

   A spec is written from an intent and a plan from a spec, and each can change after the
   other was approved. Every spec and plan therefore records, in a `built-on` frontmatter
   key, a fingerprint of the text it was written against: the first 12 hex characters of
   the SHA-256 of that artifact's body. The board compares the two on every render and
   reports a disagreement instead of offering the next step:

   | The board says | It means | Cleared by |
   |---|---|---|
   | `spec stale (intent changed)` | the intent was edited after its spec was approved | `design` |
   | `plan NN approved: stale (spec changed)` | the spec was edited or replaced after the plan was approved | `plan` |
   | `plan NN approved: blocked (spec not approved)` | a live plan sits beside a draft spec | `design` |
   | `spec disproven by plan NN` | executing that plan showed a claim of the spec to be wrong | `design` |
   | `INVALID (… missing built-on)` | an approved artifact carries no fingerprint | `design` or `plan` |
   | `chain complete` | every plan is finished and the intent was never flipped | `execute` |

   Nothing is repaired automatically: the owning skill asks whether the artifact still
   holds and records the answer. `design`, `plan` and `execute` read the board before they
   act, and `execute` refuses to run a plan on a chain that is out of sync. A chain approved before version
   0.2.0 carries no `built-on` and reads `INVALID` until `design` or `plan` re-confirms it.

   ## Roadmaps and milestones

   Both are optional. A repository that never creates one sees no new question and no new
   directory, and a single chain remains a complete use of the plugin.

   - **`roadmap`** — creates `roadmaps/<name>/roadmap.md` with its first milestones, and
     approves, amends, drops or un-drops a roadmap. A repository may hold any number.
   - **`milestone`** — works on one milestone, `roadmaps/<name>/NN-<topic>.md`: add,
     approve, amend, drop, un-drop, park scope as `draft` intents, adopt or release a chain,
     and roll up.

   A chain joins a milestone through one intent frontmatter key, `milestone:
   <roadmap>/<NN>`, and stays where it is at the chain root. No file stores a progress
   figure: the board counts each milestone's member chains every time it renders, so every
   agent gives the same answer. A milestone closes by roll-up when every member chain is
   `done` or `dropped` with at least one `done`, and a roadmap closes the same way from its
   milestones. A closed milestone takes no new work.

   ## Session-start hook

   `hooks/hooks.json` declares one `SessionStart` hook. It prints one line counting the
   open chains and the rows that need attention, then those rows: anything invalid, stale,
   blocked, disproven or complete, any plan still marked `executing`, and any dropped
   milestone or roadmap that still has open work under it. It needs the `airsl` runtime,
   prints nothing without it, and never fails a session.

   ```

6. In `## Operational skills`, the opening paragraph counts the skills above it, and the new
   section adds two. Replace (`README.md:90-91`):

   ```markdown
   Two more skills serve the chain rather than advance it. They ship under `skills/` like
   the six above; nothing here uses a `commands/` directory.
   ```

   with:

   ```markdown
   Two more skills serve the chain rather than advance it. They ship under `skills/` like
   the six pipeline skills and the two roadmap skills above — ten skills in all; nothing
   here uses a `commands/` directory.
   ```

   The "Six skills" of the opening paragraph (`README.md:4`) stays: it counts the pipeline
   stages and loops, which are still six.

   In the same section, replace the `status` bullet's first sentence
   (`README.md:93-94`):

   ```markdown
   - **`/claudestacks-sdlc:status`** — a deterministic board over every chain: state per
     artifact and a derived NEXT action. Runs `scripts/status.lua` under the `airsl` runtime
   ```

   with:

   ```markdown
   - **`/claudestacks-sdlc:status`** — a deterministic board over every chain, roadmap and
     milestone: state per artifact, every sync disagreement, each milestone's progress, and
     a derived NEXT action. Runs `scripts/status.lua` under the `airsl` runtime
   ```

7. Verify:

   ```
   $ grep -c 'roadmap\|built-on\|SessionStart' plugins/claudestacks-sdlc/README.md
   ```

   Expected: a non-zero count.

   ```
   $ grep -n '^## ' plugins/claudestacks-sdlc/README.md
   ```

   Expected, in order: `## Install`, `## Workflow`, `## Artifact chain`,
   `## Keeping artifacts in sync`, `## Roadmaps and milestones`, `## Session-start hook`,
   `## Operational skills`, `## Agents`, `## Attribution`, `## License`.

8. Check every board string quoted in the new table against the code that prints it:

   ```
   $ grep -n 'spec stale (intent changed)\|: stale (\|blocked (spec not approved)\|disproven by plan\|missing built-on\|chain complete' plugins/claudestacks-sdlc/scripts/lib/status.lua
   ```

   Expected: at least one line for each of the six alternatives.

9. Commit `docs(repo): describe sdlc sync checks, roadmaps and the session hook`.

### Task 2 — Update the descriptions outside the plugin

**Files:**
- Modify `.claude-plugin/marketplace.json`
- Modify `CLAUDE.md`
- Modify `README.md`

**Steps:**

1. In `.claude-plugin/marketplace.json`, replace the description of the `claudestacks-sdlc`
   entry (`marketplace.json:17`):

   ```json
         "description": "AI-native SDLC workflow: a committed intent → spec → plan → execute chain with distill and triage feedback loops and a deterministic status board. Implements Anthropic's AI-native SDLC playbook; execution discipline descends from the superpowers plugin (superpowers@claude-plugins-official) via the retired claudestacks-sdd."
   ```

   with:

   ```json
         "description": "AI-native SDLC workflow: a committed intent → spec → plan → execute chain with distill and triage feedback loops, optional roadmaps and milestones, and a deterministic status board that reports artifacts drifting out of sync. Implements Anthropic's AI-native SDLC playbook; execution discipline descends from the superpowers plugin (superpowers@claude-plugins-official) via the retired claudestacks-sdd."
   ```

2. In `CLAUDE.md`, replace the plugin table row (`CLAUDE.md:229`):

   ```markdown
   | `claudestacks-sdlc` | AI-native SDLC workflow: committed intent → spec → plan → execute chain with distill/triage loops (`.claudestacks/sdlc/`) |
   ```

   with:

   ```markdown
   | `claudestacks-sdlc` | AI-native SDLC workflow: committed intent → spec → plan → execute chain with distill/triage loops, artifact sync checks, and optional roadmaps and milestones (`.claudestacks/sdlc/`) |
   ```

3. In `README.md`, replace the plugin table row (`README.md:44`):

   ```markdown
   | **`claudestacks-sdlc`** | AI-native SDLC workflow: a committed `intent` → `design` → `plan` → `execute` chain under `.claudestacks/sdlc/`, with `distill`/`triage` feedback loops and a `status` board. |
   ```

   with:

   ```markdown
   | **`claudestacks-sdlc`** | AI-native SDLC workflow: a committed `intent` → `design` → `plan` → `execute` chain under `.claudestacks/sdlc/`, with `distill`/`triage` feedback loops, optional `roadmap`s and `milestone`s, and a `status` board that reports artifacts drifting out of sync. |
   ```

4. Read the Lua test count from a run rather than from this plan:

   ```
   $ cargo make plugins-test
   ```

   Expected: a summary line `<N> passed, 0 failed (<F> files)` — `491` and `22` if plans 01
   to 06 landed exactly as written — followed by `fingerprint gate: 8 cases passed`.

   In `CLAUDE.md`, replace (`CLAUDE.md:200`) `399 tests across 20 files` with
   `<N> tests across <F> files`, using the two numbers the run printed. If they are not `491`
   and `22`, record the difference in this plan's `## Deviations`.

5. Verify:

   ```
   $ jq -r '.plugins[] | select(.name == "claudestacks-sdlc") | .description' .claude-plugin/marketplace.json | grep -c 'roadmaps and milestones'
   1
   $ grep -c 'artifact sync checks' CLAUDE.md
   1
   $ grep -c '399 tests across 20 files' CLAUDE.md
   0
   $ grep -c 'drifting out of sync' README.md
   1
   ```

6. Commit `docs(repo): describe the sdlc 0.2.0 scope in the marketplace and repo docs`.

### Task 3 — Bump the plugin to 0.2.0

**Files:**
- Modify `plugins/claudestacks-sdlc/.claude-plugin/plugin.json`

**Steps:**

1. Confirm the current version:

   ```
   $ jq -r '.version' plugins/claudestacks-sdlc/.claude-plugin/plugin.json
   0.1.2
   ```

2. In `plugins/claudestacks-sdlc/.claude-plugin/plugin.json`, replace (`plugin.json:3-4`):

   ```json
     "version": "0.1.2",
     "description": "AI-native SDLC workflow: a committed intent → spec → plan → execute chain with distill and triage feedback loops and a deterministic status board. Implements Anthropic's AI-native SDLC playbook.",
   ```

   with:

   ```json
     "version": "0.2.0",
     "description": "AI-native SDLC workflow: a committed intent → spec → plan → execute chain with distill and triage feedback loops, optional roadmaps and milestones, and a deterministic status board that reports artifacts drifting out of sync. Implements Anthropic's AI-native SDLC playbook.",
   ```

   The minor version moves, not the patch: 0.2.0 adds two skills, three frontmatter keys and
   a hook, and an approved chain written under 0.1.x reads `INVALID` until re-confirmed.

3. Verify the manifest and the whole suite:

   ```
   $ jq -r '.version' plugins/claudestacks-sdlc/.claude-plugin/plugin.json
   0.2.0
   $ claude plugin validate --strict plugins/claudestacks-sdlc
   ```

   Expected: the last line reads `✔ Validation passed`.

   ```
   $ cargo make plugins
   ```

   Expected: exit 0, the summary line of Task 2 step 4, and
   `fingerprint gate: 8 cases passed`.

4. Confirm no document still names the old version, and that the skill count matches the
   directories:

   ```
   $ grep -rn '0\.1\.2' plugins/claudestacks-sdlc .claude-plugin
   ```

   Expected: no output.

   ```
   $ ls -d plugins/claudestacks-sdlc/skills/*/ | wc -l
   $ grep -c 'ten skills in all' plugins/claudestacks-sdlc/README.md
   ```

   Expected: `10`, then `1`.

5. Commit `feat(repo): release claudestacks-sdlc 0.2.0`.

### Task 4 — Close out

**Steps:**

1. Render the board one last time:

   ```
   $ sh plugins/claudestacks-sdlc/scripts/status.sh
   ```

   Expected: this chain's row lists plans 01 to 06 as `done` and plan 07 as `executing`, with
   no `INVALID`, `stale`, `blocked` or `disproven` part.

2. **Checkpoint — stop and report to the author:** the three commits, the board, and the two
   things this chain leaves for the author: pushing the branch so the Ubuntu job runs the
   fingerprint gate again on the final tree, and reinstalling the plugin to see the hook fire
   in a live session (plan 06, Task 5).

---

## Verification summary (plan-level)

- `claude plugin validate --strict plugins/claudestacks-sdlc` prints `✔ Validation passed`.
- `cargo make plugins` exits 0.
- `plugin.json` reads `0.2.0`, and no file under `plugins/claudestacks-sdlc` or
  `.claude-plugin` still reads `0.1.2`.
- The Lua test count in `CLAUDE.md` is the count the suite printed.
- Every board string quoted in the plugin README appears in `lib/status.lua`.

## Review findings

One `claudestacks:reviewer` spawn over the five files, 2026-10-14. Verdict:
`SPEC: COMPLIANT-WITH-AMENDMENTS`, blocking set none. It re-ran `cargo make plugins`
(`72 file(s) compiled, 0 failed`, `506 passed, 0 failed (22 files)`,
`fingerprint gate: 8 cases passed`) and `claude plugin validate --strict` (`✔ Validation passed`),
and found no `0.1.2` under `plugins/claudestacks-sdlc` or `.claude-plugin`. It checked the
README's claims about the hook, the fingerprint, the roll-up and the skills against the code,
and confirmed that commit 99eaddf's `plan` bullet and Attribution section survive. One fix round
by a fresh coder followed, on the plugin README only, and applied all nine findings marked
"sent to the fix round" below. Each board string the README now quotes was found by grep in
`lib/status.lua` (`:349`, `:352`, `:370`, `:372`, `:397`, `:237`, `:257`). After the round,
`cargo make plugins` read `506 passed, 0 failed (22 files)` with the fingerprint gate passed,
and `claude plugin validate --strict` read `✔ Validation passed`.

- correctness — the `execute` bullet omits that `intent disproven by plan NN` also holds the
  walk-up on spec-skip chains — `plugins/claudestacks-sdlc/README.md:59-61` — sent to the fix round.
- correctness — the sync table omits `intent disproven by plan NN`, which `intent` clears —
  `README.md:110` — sent to the fix round. The plan's own table drops the spec-skip forms of
  spec §3.2, so the defect starts in this plan's Task 1 text.
- wording — rows hard-code `approved` and miss `stale (intent changed)` — `README.md:108-109`
  — sent to the fix round.
- wording — `chain complete` is called a disagreement with no next step — `README.md:103,112`
  — sent to the fix round.
- wording — the list of skills that read the board omits `intent` — `README.md:115` — sent to
  the fix round.
- wording — "refuses … out of sync" overstates the gate — `README.md:116` — sent to the fix
  round.
- wording — a pre-0.2.0 chain reads `INVALID` only with an approved spec or a live plan —
  `README.md:116-117` — sent to the fix round.
- wording — the hook prints the open row under a dropped parent, not the dropped row —
  `README.md:141-142` — sent to the fix round.
- wording, pre-existing — "Refuses a plan that isn't `approved`" contradicts execute's
  draft-as-approval rule — `README.md:49-50` — sent to the fix round.
- unguarded — nothing checks the test count in `CLAUDE.md:200` — not changed.
- record — the 506 against 491 count was not yet under Deviations — fixed below.

## Probe results

- Task 3: `jq -r '.version'` printed `0.1.2` before the edit and `0.2.0` after;
  `grep -rn '0\.1\.2' plugins/claudestacks-sdlc .claude-plugin` printed nothing (exit 1);
  `claude plugin validate --strict plugins/claudestacks-sdlc` printed `✔ Validation passed`.
- Task 4 step 1, the board, rendered from the worktree root after Task 3:

  ```
  CHAIN                             STATE                         NEXT
  2026-08-29-claudevs-plugin-cache-hygiene  intent draft (triage)         review evidence
  2026-10-13-sdlc-roadmaps-milestones  plan 01 executing, plan 02 executing, plan 03 executing, plan 04 executing, plan 05 executing, plan 06 executing, plan 07 executing  
  DONE/DROPPED: 6 done, 2 dropped (not listed)
  ```

  No `INVALID`, `stale`, `blocked` or `disproven` part. Plans 01–06 read `executing`, not `done`,
  because each flips to `done` only when the author accepts its completion report.

## Deviations

- 2026-10-14 — `CLAUDE.md` reads `506 tests across 22 files`, the count the suite printed, not
  the 491 the plan expected. Plan 03 added 7 tests, and the review fix rounds of plans 04 and 06
  added 6 and 2.
- 2026-10-14 — No commit was made after any task; each task's commit step was skipped and the
  commit gate left with the author, per the `execute` skill. So the version bump is not a
  separate last commit yet.
- 2026-10-14 — Tasks 2 and 3 ran in parallel, since they write different files.
- 2026-10-14 — Task 4 found plans 01–06 at `executing`, not `done` as it expects. Their
  completion reports wait for the author.
- 2026-10-14 — No `claudestacks-sdlc:task-briefer` was spawned. Each coder read its own task
  section of this plan by line range.
