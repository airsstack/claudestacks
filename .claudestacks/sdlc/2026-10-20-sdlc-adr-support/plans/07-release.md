---
status: approved
created: 2026-10-20
depends-on: [05, 06]
built-on: c2d88a3e18f4
---

# claudestacks-sdlc 0.3.0 Release Implementation Plan

**Goal:** claudestacks-sdlc 0.3.0 ships its ADR support.

**Architecture:** No code. One recorded walkthrough drives the finished skills and board
through every ADR flow of spec §11 on a throwaway repository and pastes the real board
output into this plan. The plugin's own README gains an ADR section, every place that
describes the plugin is updated, the measured Lua test count replaces the old one, and
the plugin version moves to 0.3.0.

**Tech Stack:** Markdown, JSON, the `claude` CLI (`--plugin-dir`), `airsl`, cargo-make.

**Content authority:** spec §11 (walkthrough), §12 (Documentation, Version).

---

## Files that change

```
plugins/claudestacks-sdlc/README.md                   — [modify] ADR section; sync table rows; skill count; hook paragraph
plugins/claudestacks-sdlc/.claude-plugin/plugin.json  — [modify] version 0.3.0; description names ADRs
.claude-plugin/marketplace.json                       — [modify] the claudestacks-sdlc description
CLAUDE.md                                             — [modify] the plugin table row; the Lua test count
README.md                                             — [modify] the plugin table row
.claudestacks/sdlc/2026-10-20-sdlc-adr-support/plans/07-release.md — [modify] the walkthrough record, appended by execute
```

Every path is relative to the repository root.

## Order of work

### Task 1 — Record the walkthrough

**Change:** none to the plugin. In a fresh directory under the session scratchpad, run
`git init` and start a new Claude session there with
`claude --plugin-dir <worktree>/plugins/claudestacks-sdlc` (the flag "Load a plugin from
a directory", per `claude --help`), so the session reads this worktree's skills and the
agent definition plan 05 changed. Drive each step through the skills, then run
`sh <worktree>/plugins/claudestacks-sdlc/scripts/status.sh` from the throwaway
repository's root, and paste the board it prints, unedited, under this plan's
`## Probe results` with the step it belongs to (spec §11):

1. `/adr new` → reviewed → approved: the file carries `sealed` equal to
   `fingerprint.sh` of it; the board shows `ADRS: 1 approved` and no ADR row.
2. One body line of that ADR edited by hand: the row reads
   `INVALID (<file>: edited after approval)` → `fix adr NNNN`. Revert the edit.
3. Two chains whose approved specs cite the ADR, then `/adr supersede NNNN` → approved:
   both chains read `spec stale (ADR NNNN superseded by MMMM)` → `design`; `design`
   clears one by re-confirmation (its plans stay as they were) and one by redesign (its
   plans read `stale (spec changed)`).
4. A chain citing an approved ADR whose plan `02` execution disproves it, beside a second
   chain that only cites it: `execute` asks the three-way question and writes
   `disproves-adr`; the first chain reads `ADR NNNN disproven by plan 02` and refuses its
   plan `03`; the second reads `ADR NNNN disproven by <chain>/02` and refuses its plan;
   the walk-up of the first is held open; the ADR row reads `disproven by <chain>/02` →
   `adr supersede NNNN`. Then `/adr supersede NNNN`: C5 and the ADR row clear, C6
   appears, and after `design` clears it the first chain completes and walks up.
5. `/adr deprecate` on an approved ADR a chain cites: that chain reads
   `spec stale (ADR NNNN deprecated)`.
6. `adrs: [0001]` written by hand into one chain's `intent.md`: the row reads
   `INVALID (intent.md: adrs not allowed here)`.
7. `sh <worktree>/plugins/claudestacks-sdlc/scripts/attention.sh`, run from the throwaway
   root with no payload, so `attention.lua` falls back to the process directory (`scripts/attention.lua:13-16`): its output lists the problem ADR and
   chain rows and not the `ADRS:` heading.

For each step, compare the pasted board with `references/artifact-chain.md` §10 and §13
as plan 04 wrote them, and record any wording that differs under `## Deviations`.

Record each step under `## Probe results` as a heading `### Walkthrough step N — <title>`
(N from 1 to 7) followed by the commands run and the board pasted in a fenced block.

**Proof:** every step above has its real board pasted under `## Probe results`, and each
STATE and NEXT it shows is a wording `artifact-chain.md` states, or a `## Deviations`
entry names the difference.

**Done when:** `grep -cE '^### Walkthrough step [1-7] ' .claudestacks/sdlc/2026-10-20-sdlc-adr-support/plans/07-release.md`,
run from the repository root, prints `7`. Commit nothing for this task beyond the
plan's appended record, which is committed with Task 3.

### Task 2 — Describe ADR support in the plugin README

**Files:**
- Modify `plugins/claudestacks-sdlc/README.md`

**Change:**

- A new `## Architecture decision records` section after `## Roadmaps and milestones`
  (:128-144), in the voice of that section: optional; `adrs/NNNN-<topic>.md`, one
  repository-wide series; written only by the `adr` skill; cited only from a spec's
  `adrs` key; an approved ADR is sealed and never edited, replaced by supersession or
  retired by deprecation; a plan's execution can disprove one, which every open chain
  citing it then shows.
- `## Keeping artifacts in sync`'s table (:107-115) gains rows for `ADR NNNN disproven by
  …` (→ `adr`), `spec stale (ADR …)` (→ `design`) and `spec blocked (ADR NNNN not
  approved)` (→ `adr`), and its `execute` paragraph (:117-123) names the ADR conditions
  among the refusals.
- `## Operational skills` (:154-157): "ten skills in all" becomes "eleven skills in
  all", with the `adr` skill named among the skills the README lists.
- `## Session-start hook` (:146-152) names problem ADR rows among what it prints.

**Proof:** run from the repository root with `R=plugins/claudestacks-sdlc/README.md` —
- `grep -nF '## Architecture decision records' "$R"` prints one line.
- `grep -nF 'eleven skills' "$R"` prints one line; `grep -nF 'ten skills' "$R"` prints nothing.
- `grep -nF 'spec blocked (ADR' "$R"` prints at least one line.

**Done when:** every check holds. Commit
`docs(repo): describe claudestacks-sdlc ADR support`.

### Task 3 — Bump the version and update every description and count

**Files:**
- Modify `plugins/claudestacks-sdlc/.claude-plugin/plugin.json`
- Modify `.claude-plugin/marketplace.json`
- Modify `CLAUDE.md`
- Modify `README.md`
- Modify `.claudestacks/sdlc/2026-10-20-sdlc-adr-support/plans/07-release.md` (the record from Task 1)

**Change:**

- `plugins/claudestacks-sdlc/.claude-plugin/plugin.json:3` — `"version": "0.2.1"` →
  `"version": "0.3.0"`; its description (:4) names optional architecture decision
  records beside "optional roadmaps and milestones".
- `.claude-plugin/marketplace.json:17` — the same addition to the claudestacks-sdlc
  description, keeping its trailing attribution clause.
- `CLAUDE.md:235` — the claudestacks-sdlc table row names architecture decision records.
- `README.md:44` — the claudestacks-sdlc table row names them.
- `CLAUDE.md:206` — `506 tests across 22 files` becomes the counts `cargo make
  plugins-test` prints on this branch after plans 01–03, read from its summary line
  `<n> passed, 0 failed (<m> files)`, never computed by hand.

`plugins/claudestacks/.claude-plugin/plugin.json` also reads `0.2.1` and is a different
plugin; it is not touched.

**Proof:**
- `cargo make plugins` passes; the numbers written at `CLAUDE.md:206` equal its summary line.
- `claude plugin validate --strict plugins/claudestacks-sdlc` exits 0, and `claude plugin validate --strict .` exits 0 for the marketplace.
- `grep -nF '"version": "0.3.0"' plugins/claudestacks-sdlc/.claude-plugin/plugin.json` prints one line.
- `grep -niF 'decision record' .claude-plugin/marketplace.json CLAUDE.md README.md plugins/claudestacks-sdlc/.claude-plugin/plugin.json` prints one line per file.

**Done when:** every check holds. Commit
`feat(repo): release claudestacks-sdlc 0.3.0 with ADR support`.

---

## Risks

- **`--plugin-dir` beside the installed 0.2.0 plugin of the same name** — whether the
  directory copy wins over, or conflicts with, the installed `claudestacks-sdlc` is not
  verified. Probe it first in the throwaway session (`/claudestacks-sdlc:adr` resolving
  is the sign); if the installed copy wins, run the walkthrough with the installed plugin
  disabled for that session and record how under `## Deviations`.
- **The walkthrough is the only proof of skill behaviour** (spec §11). A step that
  cannot be driven as written is recorded as a deviation with what was run instead,
  never marked done on reasoning.
- **The test count** must come from the run, after every Lua plan is done; a count
  written before plan 03 lands would be wrong.
- Not done here: publishing or tagging. Releasing a plugin is not the `/release <crate>`
  skill's job, and committing stays the author's act.

## Proof

- `cargo make plugins` passes and `claude plugin validate --strict` exits 0 on the
  plugin and on the marketplace.
- `sh plugins/claudestacks-sdlc/scripts/status.sh` from the repository root still prints
  this repository's board without an `ADRS:` line (it holds no `adrs/`).
- `## Probe results` holds the seven recorded boards.
