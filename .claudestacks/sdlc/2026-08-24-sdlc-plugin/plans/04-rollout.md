---
status: approved
created: 2026-08-25
depends-on: [01, 02, 03]
---

# claudestacks-sdlc Rollout Implementation Plan

**Goal:** Swap the marketplace to the new plugin by retiring claudestacks-sdd everywhere the repository references it.

**Architecture:** Hard replace in one change (spec §9): delete the sdd plugin directory, swap the marketplace entry, re-point every repo doc, and flip the local plugin enablement. Git history remains the archive of the old plugin; the HOME-global sdd store is abandoned in place — not read, not migrated, not deleted.

**Tech Stack:** JSON edits, markdown edits, `git rm`. No code.

**Reference inventory (verified against the tree on 2026-08-25):** `.claude-plugin/marketplace.json` (sdd plugin entry), `README.md:44` (plugin table row), `README.md:57` (attribution paragraph), `README.md:94` (install example), `README.md:101` (namespacing example), `CLAUDE.md:165` (plugin table row), `.claude/settings.json:9` (`"claudestacks-sdd@claudestacks": true`). Re-run the Task 3 grep on the day in case new references appeared since.

---

## File structure

```
plugins/claudestacks-sdd/            — [delete] entire plugin
.claude-plugin/marketplace.json      — [modify] swap the sdd entry for the sdlc entry
README.md                            — [modify] table row, attribution, install, namespacing
CLAUDE.md                            — [modify] plugin table row and workflow references
.claude/settings.json                — [modify] plugin enablement
```

### Task 1 — Delete the sdd plugin and swap the marketplace entry

**Steps:**

1. Delete the plugin:

   ```
   $ git rm -r plugins/claudestacks-sdd
   ```

2. In `.claude-plugin/marketplace.json`, replace the whole `claudestacks-sdd` object in `plugins` with:

   ```json
   {
     "name": "claudestacks-sdlc",
     "source": "./plugins/claudestacks-sdlc",
     "description": "AI-native SDLC workflow: a committed intent → spec → plan → execute chain with distill and triage feedback loops and a deterministic status board. Implements Anthropic's AI-native SDLC playbook; execution discipline descends from the superpowers plugin (superpowers@claude-plugins-official) via the retired claudestacks-sdd."
   }
   ```

3. Verify:

   ```
   $ python3 -m json.tool .claude-plugin/marketplace.json > /dev/null && echo OK
   OK
   $ test ! -d plugins/claudestacks-sdd && echo GONE
   GONE
   ```

### Task 2 — Re-point the repo docs

**Steps:**

1. `README.md` — four edits:
   - Line 44 table row → `| **claudestacks-sdlc** | AI-native SDLC workflow: intent → design → plan → execute chain committed under .claudestacks/sdlc/, with distill/triage loops and a status board. |` (match the table's actual formatting conventions on the day).
   - The attribution paragraph around line 57 → rewrite to the two-lineage form (spec §11): the stage model and loops implement Anthropic's AI-native SDLC playbook; the design/plan/execute discipline descends from the retired claudestacks-sdd, itself adapted from the superpowers plugin.
   - Line 94 install example → `/plugin install claudestacks-sdlc@claudestacks`.
   - Line 101 namespacing example → `claudestacks-sdlc:<name>`.
2. `CLAUDE.md` — plugin table row at line 165 → `| \`claudestacks-sdlc\` | AI-native SDLC workflow: committed intent → spec → plan → execute chain with distill/triage loops (\`.claudestacks/sdlc/\`) |`; sweep the surrounding "AI methodology" section for any brainstorm/write-plan/execute-plan workflow mention and update it to the six-skill pipeline.
3. `.claude/settings.json` line 9 → replace `"claudestacks-sdd@claudestacks": true` with `"claudestacks-sdlc@claudestacks": true`.
4. Verify:

   ```
   $ python3 -m json.tool .claude/settings.json > /dev/null && echo OK
   OK
   ```

### Task 3 — Sweep for stragglers

**Steps:**

1. Search the whole tree (excluding this chain's own artifacts, which legitimately narrate the history):

   ```
   $ grep -rn "claudestacks-sdd" --exclude-dir=.git --exclude-dir=.claudestacks .
   ```

   Expected: no matches. Any hit is a missed reference — fix it and re-run until clean. (References in `.claudestacks/sdlc/` are the audit trail and stay.)

2. Confirm the other plugins' READMEs did not reference sdd (they did not at plan-writing time; the grep above proves it either way).

### Task 4 — Gates and commit

**Steps:**

1. The Lua suite still passes without the sdd tests (the suite shrinks — sdd's layout tests are deleted with it; that is expected, not a regression):

   ```
   $ cargo make plugins
   ```

   Expected: `airsl check plugins` clean; `airsl test` green, including the 24 status-board tests.

2. Plugin validation on the survivor:

   ```
   $ claude plugin validate plugins/claudestacks-sdlc --strict
   ```

   Expected: passes.

3. Commit:

   ```
   $ git add -A
   $ git commit -m "feat(repo): replace claudestacks-sdd with claudestacks-sdlc"
   ```

   Body: name the hard replace, the playbook provenance, the abandoned HOME store, and the per-machine migration (`/plugin uninstall claudestacks-sdd@claudestacks`, `/plugin install claudestacks-sdlc@claudestacks`).

---

## Verification summary (plan-level)

- `grep -rn "claudestacks-sdd"` (excluding `.git` and `.claudestacks`) returns nothing.
- Both JSON files parse; `claude plugin validate … --strict` passes.
- `cargo make plugins` green after the deletion.
