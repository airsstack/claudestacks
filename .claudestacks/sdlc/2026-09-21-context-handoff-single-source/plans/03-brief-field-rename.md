---
status: approved
created: 2026-09-21
---

# Brief Field Rename Implementation Plan

**Goal:** Every brief in all three plugins names the handoff write-path `handoff:`.

**Architecture:** Three spellings exist today for one thing: `handoff:` (orchestrate, execute, task-briefer), `report:` (design, plan, distill, artifact-reviewer, chain-reader) and `handoff_path:` (journal-review, journal-curator). A driver and the agent it spawns must agree, so each pair is renamed in the same commit; this plan holds all of them so no half-renamed pair can exist between plans. Some of the lines it touches sit inside sections that plans `04` and `05` later replace wholesale — `chain-reader.md:68`, `journal-curator.md:78` and `:85`, and the three driver briefs. That overlap is deliberate and ordered-safe: this plan runs first and leaves the tree consistent at every commit, and the later plans write the new name into their replacements. The alternative — renaming only the lines no later plan touches — would leave a driver and its agent disagreeing until `04` and `05` both landed.

**Tech Stack:** Markdown.

---

### Task 1 — Establish the baseline

**Files:**
- None — measurement only.

**Steps:**

1. Record every occurrence of the two names being retired:

   ```
   $ grep -rn "^report:\|^   report:\|\`report\` |" plugins/claudestacks-sdlc/
   plugins/claudestacks-sdlc/agents/artifact-reviewer.md:32:| `report` | the full write-path for your report |
   plugins/claudestacks-sdlc/skills/design/SKILL.md:165:   report: <TMPDIR>/claudestacks-sdlc-<chain>-spec-<NN>.md
   plugins/claudestacks-sdlc/skills/plan/SKILL.md:225:report: <TMPDIR>/claudestacks-sdlc-<chain>-plan-set-<NN>.md
   plugins/claudestacks-sdlc/skills/distill/SKILL.md:52:report: <TMPDIR>/claudestacks-sdlc-corpus-findings-<NN>.md
   ```

   ```
   $ grep -rn "handoff_path" plugins/
   plugins/claudestacks-journal/agents/journal-curator.md:29
   plugins/claudestacks-journal/agents/journal-curator.md:78
   plugins/claudestacks-journal/agents/journal-curator.md:85
   plugins/claudestacks-journal/skills/journal-review/SKILL.md:79
   ```

2. Confirm `task-briefer` already uses the target name, so it needs no change:

   ```
   $ grep -n '^| `handoff`' plugins/claudestacks-sdlc/agents/task-briefer.md
   30:| `handoff` | full write-path for your report — assigned by the orchestrator, never computed by you |
   ```

3. Commit nothing.

---

### Task 2 — Rename the `artifact-reviewer` pair

**Files:**
- Modify `plugins/claudestacks-sdlc/agents/artifact-reviewer.md`
- Modify `plugins/claudestacks-sdlc/skills/design/SKILL.md`
- Modify `plugins/claudestacks-sdlc/skills/plan/SKILL.md`

**Steps:**

1. In `artifact-reviewer.md`, change the brief-table row at `:32`:

   ```markdown
   | `handoff` | the full write-path for your report |
   ```

2. In `design/SKILL.md`, change the spawn brief line at `:165`:

   ```
   handoff: <TMPDIR>/claudestacks-sdlc-<chain>-spec-<NN>.md
   ```

3. In `plan/SKILL.md`, change the spawn brief line at `:225`. Keep the `<chain>` segment — only
   the field name changes:

   ```
   handoff: <TMPDIR>/claudestacks-sdlc-<chain>-plan-set-<NN>.md
   ```

4. Confirm the agent and both its callers now agree, and that no `report:` line survives in either
   skill:

   ```
   $ grep -n '^| `handoff`' plugins/claudestacks-sdlc/agents/artifact-reviewer.md
   32:| `handoff` | the full write-path for your report |
   $ grep -rn "^report:\|^   report:" plugins/claudestacks-sdlc/skills/design/SKILL.md plugins/claudestacks-sdlc/skills/plan/SKILL.md
   $ echo "exit=$?"
   exit=1
   ```

5. Commit `refactor(repo): name the artifact-reviewer brief field handoff`.

---

### Task 3 — Rename the `chain-reader` pair

**Files:**
- Modify `plugins/claudestacks-sdlc/agents/chain-reader.md`
- Modify `plugins/claudestacks-sdlc/skills/distill/SKILL.md`

**Steps:**

1. In `chain-reader.md`, change the sentence at `:68` from "Your brief gives you a report
   write-path" to name the field:

   ```markdown
   Your brief gives you a `handoff` write-path.
   ```

2. In `distill/SKILL.md`, change the spawn brief line at `:52`:

   ```
   handoff: <TMPDIR>/claudestacks-sdlc-corpus-findings-<NN>.md
   ```

3. Confirm the pair agrees:

   ```
   $ grep -n "handoff. write-path" plugins/claudestacks-sdlc/agents/chain-reader.md
   68:Your brief gives you a `handoff` write-path.
   $ grep -n "^handoff:" plugins/claudestacks-sdlc/skills/distill/SKILL.md
   52:handoff: <TMPDIR>/claudestacks-sdlc-corpus-findings-<NN>.md
   ```

4. Commit `refactor(repo): name the chain-reader brief field handoff`.

---

### Task 4 — Rename the `journal-curator` pair

**Files:**
- Modify `plugins/claudestacks-journal/agents/journal-curator.md`
- Modify `plugins/claudestacks-journal/skills/journal-review/SKILL.md`

**Steps:**

1. Rename every occurrence in both files. All four sites are the same identifier, so one
   substitution covers them:

   ```
   $ sed -i '' 's/handoff_path/handoff/g' \
       plugins/claudestacks-journal/agents/journal-curator.md \
       plugins/claudestacks-journal/skills/journal-review/SKILL.md
   ```

2. Confirm nothing is left and the four sites read correctly:

   ```
   $ grep -rn "handoff_path" plugins/
   $ echo "exit=$?"
   exit=1
   $ grep -n "handoff" plugins/claudestacks-journal/agents/journal-curator.md | head -3
   29:- `handoff` — the exact file you write your report to. You do NOT compute
   78:Write exactly one file at `handoff` with a `<summary>` and a `<detail>`:
   85:Return only the `<summary>` text plus the `handoff` you were given. If the
   ```

3. Commit `refactor(repo): name the journal-curator brief field handoff`.

---

### Task 5 — Assert the rename is complete across all three plugins

**Files:**
- None — verification only.

**Steps:**

1. Neither retired name may appear anywhere under `plugins/`:

   ```
   $ grep -rn "handoff_path" plugins/
   $ echo "exit=$?"
   exit=1
   $ grep -rn "^report:\|^   report:\|\`report\` |" plugins/
   $ echo "exit=$?"
   exit=1
   ```

2. Prove the search method would have found something. Without a control the two empty results
   above prove nothing — they are equally consistent with a broken pattern. Run the same `grep -rn`
   machinery against the target name, which is present:

   ```
   $ grep -rln "handoff:" plugins/ | wc -l
   ```

   Before this plan that count is 8 (`execute/SKILL.md`, `orchestrate/SKILL.md`, `agents/coder.md`,
   `agents/explorer.md`, `agents/reviewer.md`, `scripts/handoff.lua`,
   `skills/context-handoff/SKILL.md`, and the protocol reference). Plan `01` raised it from 7 to 8
   by adding the driver skill, which carries the field name; this plan was written before `01`
   landed. After this plan it must be strictly greater, and the measured value is 11: of the seven
   files Tasks 2–4 touch, three gain a line matching `handoff:` with the colon
   (`design/SKILL.md`, `plan/SKILL.md`, `distill/SKILL.md` — the spawn-brief lines). The other
   four rename a bare `handoff_path` or a table cell, which this pattern does not match. A count
   that did not grow means the renames in Tasks 2–4 did not land.

3. Commit nothing.

---

### Task 6 — Bump the plugin versions this plan changed

**Files:**
- Modify `plugins/claudestacks-sdlc/.claude-plugin/plugin.json`

**Steps:**

1. Bump the patch component from `0.1.1` to `0.1.2`. `claudestacks-journal` is also changed by
   this plan, but plan `01` already bumps it to `0.1.2`; bumping twice for one release would be
   wrong, so this task bumps only the plugin plan `01` does not touch.

2. Confirm:

   ```
   $ grep '"version"' plugins/claudestacks-sdlc/.claude-plugin/plugin.json
     "version": "0.1.2",
   ```

3. Commit `chore(repo): bump claudestacks-sdlc for the brief field rename`.
