---
status: approved
created: 2026-10-29
built-on: 80fae45ab510
---

# Stack-Neutral Agent Wording Implementation Plan

**Goal:** The `claudestacks` coder and reviewer take test placement and stack-specific review
checks from whichever guideline skill is loaded.

**Architecture:** Two single-line rewrites in the agent definitions, verbatim from spec §6, and a
patch version bump of the `claudestacks` plugin so installed copies pick them up. Independent of
every other plan in the chain: it touches only `plugins/claudestacks/`.

**Tech Stack:** Markdown agent definitions; plugin manifest JSON; `claudevs` 0.1.0; `airsl` for
the plugin suite's Lua tests.

**Content authority:** spec §6.

---

## Files that change

```
plugins/claudestacks/agents/coder.md            — [modify] line 32, test placement
plugins/claudestacks/agents/reviewer.md         — [modify] line 24, review checklist
plugins/claudestacks/.claude-plugin/plugin.json — [modify] version 0.2.1 → 0.2.2 (line 3)
```

## Order of work

### Task 1 — Rewrite the two agent lines

**Files:**
- Modify `plugins/claudestacks/agents/coder.md:32`
- Modify `plugins/claudestacks/agents/reviewer.md:24`

**Change:** replace each line with its "After" text from spec §6, character for character. No
other line in either file changes. The worked examples the spec keeps
(`reviewer.md:84-85`, and the skill files it lists) are not touched.

**Proof:** written first, seen failing, then passing —
- `coder_no_longer_says_colocated` — `grep -c colocated plugins/claudestacks/agents/coder.md` is
  1 before and 0 after.
- `coder_line_matches_spec` — line 32 of `coder.md` equals the spec §6 `coder.md:32` "After"
  text (`sed -n 32p` compared with `diff`).
- `reviewer_line_matches_spec` — line 24 of `reviewer.md` equals the spec §6 `reviewer.md:24`
  "After" text.
- `only_two_lines_changed` — `git diff --numstat` on the two files shows `1 1` for each.

**Done when:** the four checks pass. Commit with the next task.

### Task 2 — Bump the plugin version

**Files:**
- Modify `plugins/claudestacks/.claude-plugin/plugin.json:3`

**Change:** `"version": "0.2.1"` becomes `"version": "0.2.2"`. The reason (spec §6, citing
`https://code.claude.com/docs/en/plugins/loading.md` :298, :326) goes in the commit body.

**Proof:** written first, seen failing, then passing —
- `version_is_bumped` — `python3 -I -c` reading the manifest prints `0.2.2` (prints `0.2.1`
  before).
- `claudevs_check_passes` — `claudevs check plugins/claudestacks` exits 0.
- `plugin_suite_still_green` — `cargo make plugins` (`airsl check` then `airsl test` over
  `plugins/`) exits 0; no Lua file changes, so this guards against an accidental edit.

**Done when:** the three checks pass. Commit
`fix(repo): make the claudestacks agents defer test placement to the loaded guideline` with both
tasks' changes.

## Risks

- **Line numbers drift.** If another change lands in `coder.md` or `reviewer.md` first, lines 32
  and 24 move; locate the lines by their current text (spec §6 "Line" column) before replacing.
- **Not done here:** anything in the Python plugin, and the repository text (plan 06).

## Proof

- `grep -rn colocated plugins/claudestacks/agents` finds nothing.
- `claudevs check plugins/claudestacks` exits 0 and `cargo make plugins` exits 0.
