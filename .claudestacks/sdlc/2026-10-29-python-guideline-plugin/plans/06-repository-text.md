---
status: approved
created: 2026-10-29
depends-on: [01]
built-on: 80fae45ab510
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
