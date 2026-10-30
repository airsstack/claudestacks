---
status: done
created: 2026-10-29
depends-on: [01]
built-on: fd450d45d88d
---

# Repository Text Implementation Plan

**Goal:** Every place the repository lists its plugins names `claudestacks-guideline-python`.

**Architecture:** Text-only edits to the four files spec §2.3 names beyond the marketplace (which
plan 01 already changed). Depends on plan 01 so the text never names a plugin that does not yet
exist.

**Tech Stack:** Markdown; JSON.

**Content authority:** spec §2.3.

---

## Files that change

```
README.md                         — [modify] plugin count, plugin table, dependency diagram, install list
CLAUDE.md                         — [modify] plugin table row
plugins/claudestacks/README.md    — [modify] line 8, name both guideline plugins as examples
.claude/settings.json             — [modify] enabledPlugins entry for the new plugin
```

## Order of work

### Task 1 — Update the root README

**Files:**
- Modify `README.md`

**Change:** four edits, each beside its Rust counterpart:
- `:120` "Five plugins" becomes "Six plugins".
- after the table row at `:127`, a row `| \`claudestacks-guideline-python\` | Python guidelines and
  a Definition of Done the agents check against |`.
- after the dependency line at `:153`, `claudestacks-guideline-python ── no runtime needs; read by
  claudestacks` aligned with the Rust line.
- after the install line at `:168`, `/plugin install claudestacks-guideline-python@claudestacks`.

**Proof:** written first, seen failing, then passing —
- `readme_names_python_plugin_three_times` — `grep -c 'claudestacks-guideline-python' README.md`
  is 0 before and 3 after.
- `readme_count_is_six` — `grep -c 'Six plugins' README.md` is 1 and `grep -c 'Five plugins'
  README.md` is 0.

**Done when:** both checks pass. Commit with the remaining tasks.

### Task 2 — Update `CLAUDE.md` and the claudestacks README

**Files:**
- Modify `CLAUDE.md` — new row after `:236`
- Modify `plugins/claudestacks/README.md:8`

**Change:** `CLAUDE.md` gains `| \`claudestacks-guideline-python\` | Python engineering guidelines
and the Definition of Done |` after the Rust row at `:236`. `CLAUDE.md:173` is left as it is (spec
§2.3). In `plugins/claudestacks/README.md:8`, "(e.g. `claudestacks-guideline-rust`)" becomes
"(e.g. `claudestacks-guideline-rust`, `claudestacks-guideline-python`)", rewrapping the paragraph
only if the line exceeds the file's existing width.

**Proof:** written first, seen failing, then passing —
- `claude_md_lists_python_plugin` — `grep -c 'claudestacks-guideline-python' CLAUDE.md` is 0
  before and 1 after.
- `claude_md_gate_line_unchanged` — `sed -n 173p CLAUDE.md` is byte-identical before and after.
- `claudestacks_readme_names_both` — `grep -n 'claudestacks-guideline-python'
  plugins/claudestacks/README.md` finds the example line.

**Done when:** the three checks pass.

### Task 3 — List the plugin in project settings

**Files:**
- Modify `.claude/settings.json` — `enabledPlugins` block (`:7-13`)

**Change:** add `"claudestacks-guideline-python@claudestacks": false` after the Rust entry at
`:10`, matching how every other marketplace plugin is listed there.

**Proof:** written first, seen failing, then passing —
- `settings_lists_python_plugin` — `python3 -I -c` loading the file prints the
  `enabledPlugins` value for `claudestacks-guideline-python@claudestacks` as `False` (raises
  `KeyError` before).
- `settings_is_valid_json` — `python3 -I -m json.tool .claude/settings.json` exits 0.

**Done when:** both checks pass. Commit `docs(repo): list claudestacks-guideline-python across
the repository` with all three tasks' changes.

## Risks

- **Line numbers drift** if plan 05 or another change edits the same files first; locate each
  insertion beside its Rust counterpart by text, not by number.
- **`.claude/settings.json` is project-shared.** The entry is `false`, as every sibling entry is,
  so no session enables the plugin by surprise.

## Proof

- `git grep -n 'claudestacks-guideline-python' -- README.md CLAUDE.md plugins/claudestacks/README.md .claude/settings.json .claude-plugin/marketplace.json`
  finds each file (the marketplace from plan 01).
- `git grep -n -i 'five plugins' -- README.md CLAUDE.md plugins` finds nothing.

## Review findings

Batch with plans 04 and 05, report `20261030-095405-ef9d/02-reviewer-plans-04-06.md`: plan 06
compliant.
- drift, accepted — `README.md` Rust dependency line padded with two `─` so its arrow aligns
  with the longer Python line (`README.md:154-155`).
- compliant — `plugins/claudestacks/README.md:8` paragraph rewrapped; unwrapped it ran about
  134 columns against a paragraph wrapped at 100 or less, the case the plan allows.

## Probe results

No throwaway probe: every insertion point was located by text before editing. Proving checks,
red before, green after (scratchpad `p06/check.sh`):
- `readme_names_python_plugin_three_times` — before `0`, after `3`.
- `readme_count_is_six` — before Six=0 Five=1, after Six=1 Five=0.
- `claude_md_lists_python_plugin` — before `0`, after `1`.
- `claude_md_gate_line_unchanged` — PASS before and after (`cmp` against `HEAD`'s line 173).
- `claudestacks_readme_names_both` — before FAIL, after PASS.
- `settings_lists_python_plugin` — before `KeyError`, after `False`.
- `settings_is_valid_json` — PASS.
- Plan Proof `git grep -c` — `.claude-plugin/marketplace.json:2`, `.claude/settings.json:1`,
  `CLAUDE.md:1`, `README.md:3`, `plugins/claudestacks/README.md:1`; `five plugins` finds nothing.

## Deviations

- 2026-10-30 — Re-confirmed against spec `fd450d45d88d` on the author's instruction to execute
  plans 04-06; the amendments do not touch §2.3.
- 2026-10-30 — Started while plan 01 is built but not yet `done` (author's goal named 04-06).
- 2026-10-30 — The Rust dependency line in `README.md` changed (two `─` added) to align the new
  line, beyond "aligned with the Rust line".
- 2026-10-30 — Executed inline by the orchestrator, reviewed by the batch reviewer. Not committed.
