---
status: done
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

## Review findings

- stale-cross-reference — `snapshot-save`'s shell key-derivation block claimed to be "byte-identical
  to `claudestacks-sdd/hooks/ensure-layout.sh`", a file that never contained the derivation; the
  claim was false before the deletion and dangling after it. Rewritten twice more before landing on
  a verified form — the second attempt named `README.md`/`snapshot-load` as byte-identical copies
  (they only describe the key in prose), the third called it the single normative copy (a real Lua
  port exists). Three consecutive wrong versions of one sentence — `plugins/claudestacks/skills/snapshot-save/SKILL.md:72`
- undetected-duplication — the derivation is ported to `hooks/lib/enforce.lua`'s `M.project_key`
  (identical formula, same `sanitize` class per `enforce.lua:34`, same 8-hex hash) and its
  worktree-collapsing half again to `claudestacks-journal`'s `scripts/lib/vault.lua` `M.project_base`.
  The original sentence's sync obligation was pointing at real duplication; only its citation was
  wrong, and two rewrites discarded the obligation along with it — `plugins/claudestacks/hooks/lib/enforce.lua:78-95`
- stale-doc-count — `cargo make plugins` was documented as "177 assertions across 14 files" while the
  suite ran 278 across 17; this change moved it to 266 across 16. Wrong before the change, wronger
  after — `CLAUDE.md:136`
- incomplete-inventory — the plan's own verified inventory named one plugin-enablement file and
  missed a second tracked one, plus two live cross-references inside the surviving `claudestacks`
  plugin. Task 3's sweep is what caught them, which is what it is for — `.claudestacks/sdlc/2026-08-24-sdlc-plugin/plans/04-rollout.md:15`
- self-contradicting-verification — Task 3 expects `grep "claudestacks-sdd"` to return no matches,
  but Task 1 of the same plan dictates a marketplace description containing that exact string.
  A verification that the plan's own earlier task guarantees will fail — `.claudestacks/sdlc/2026-08-24-sdlc-plugin/plans/04-rollout.md:86`
- migration-ordering (unverified) — the sdlc README tells the user to uninstall `claudestacks-sdd`
  first, but reaching the sdlc entry requires a marketplace refresh that removes the sdd entry.
  Whether `/plugin uninstall` accepts an id the refreshed marketplace no longer lists was not
  tested; flagged as a risk, not asserted — `plugins/claudestacks-sdlc/README.md:19-26`
- naming-inconsistency — the pipeline is written `intent → design → plan → execute` in one plugin
  table and `intent → spec → plan → execute` in the other. Both are plan-dictated verbatim (skills
  chain vs artifact chain), so both were reproduced faithfully rather than silently reconciled —
  `README.md:52` and `CLAUDE.md:165`
- residual-phrasing — "spec-driven, review-gated development methodology" survives in the intro above
  the rewritten attribution; it is sdd-era framing — `README.md:37`
- imprecision — the re-pointed blockquote says superseded artifacts are "only marked superseded or
  dropped"; a superseded spec is also renamed per `artifact-chain.md` §4 —
  `plugins/claudestacks/skills/process-guidelines/SKILL.md:11-13`

## Deviations

- **2026-08-25 — inventory extended by three files.** The plan's reference inventory (`:15`) was
  verified on the day it was written but missed `crates/clauders/.claude/settings.json:9` (a second
  tracked plugin-enablement file), `plugins/claudestacks/skills/process-guidelines/SKILL.md:12`, and
  `plugins/claudestacks/skills/snapshot-save/SKILL.md:72`. All three were edited. Without them the
  deletion would have left two dangling cross-references and one worktree still enabling a plugin
  that no longer exists.
- **2026-08-25 — Task 3's expectation corrected rather than met.** "Expected: no matches" is
  unachievable: five deliberate mentions survive, all name-only, none a path or skill namespace —
  the uninstall migration step (`plugins/claudestacks-sdlc/README.md:19,23`), two attribution
  lineages (`README.md:60`, `plugins/claudestacks-sdlc/README.md:104`), and the marketplace
  description Task 1 dictates verbatim (`:45`). The check actually run was
  `grep -rn "plugins/claudestacks-sdd\|claudestacks-sdd:"` — dangling paths and namespaces — which
  returned exit 1, no matches.
- **2026-08-25 — Task 4's test-count expectation was stale.** It expected "the 24 status-board
  tests"; plan 02 grew that suite to 31. The full suite shrank 278/17 files → 266/16 files. The
  shrink was proven rather than assumed: `git show HEAD:plugins/claudestacks-sdd/hooks/layout_test.lua`
  holds exactly 12 test functions and 278 − 266 = 12, so the loss is precisely the deleted plugin's
  own tests with no collateral damage.
- **2026-08-25 — Task 4 step 3 (commit) not performed.** The `execute` skill contract
  (`plugins/claudestacks-sdlc/skills/execute/SKILL.md:113-114`) reserves the commit gate to the user
  and overrides a plan step instructing an agent to commit. The change was presented instead.
- **2026-08-25 — `CLAUDE.md`'s assertion count fixed, beyond the plan's stated purpose for that
  file.** The plan authorises editing `CLAUDE.md` for the plugin-table row and a methodology-section
  sweep. The stale `177 assertions across 14 files` sits in the Commands section instead, but this
  change moved the real number, so it was corrected to `266 assertions across 16 files` rather than
  left further from true.
