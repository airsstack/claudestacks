---
status: done
created: 2026-10-20
depends-on: [05, 06]
built-on: 9078f8c84ed0
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

## Review findings

Reviewer report: one round over Tasks 2–3, code 0🔴 2🟡 5🔵; blocking set: README.md:59-63.
Fix round re-verified with `claude plugin validate --strict plugins/claudestacks-sdlc` →
`✔ Validation passed`, and the Task 2 greps (`## Architecture decision records` :156,
`eleven skills` :189, no `ten skills`, `spec blocked (ADR` :121, :129).

- risk (blocking) — the `execute` Workflow bullet said the walk-up fires once no stale spec stands and nothing is disproven, omitting C5–C7 — `plugins/claudestacks-sdlc/README.md:59-63` — fixed: "and no ADR the spec cites is disproven, replaced, retired or not approved" (:62-65).
- risk — the intro and the artifact tree never mention ADRs or `adrs/` — `README.md:3-10`, `:76-93` — fixed: intro :10-11, tree entry :88-89.
- nit — C6 row said "after the spec was approved" — `README.md:116` — fixed: "has been replaced or retired" (:120).
- nit — `adr` missing from the skills that read the board first — `README.md:121` — fixed (:125).
- nit — the no-ADR condition was narrower than §13 — `README.md:154-155` — fixed (:158-159).
- nit — authority citation left out §10.3 and §11.7 — `README.md:171` — fixed (:175-176).
- nit — nothing pins the test count, version or descriptions against going stale — `CLAUDE.md:206` — declined: no such guard exists for any plugin; out of this plan's scope.

Plan-wide proof: `cargo make plugins` → `630 passed, 0 failed (23 files)` (the reviewer's
re-run; equals `CLAUDE.md:206`); `claude plugin validate --strict .` → exit 0; this
repository's board from its root prints no `ADRS:` line:

```
CHAIN                             STATE                         NEXT
2026-08-29-claudevs-plugin-cache-hygiene  intent draft (triage)         review evidence
2026-10-20-sdlc-adr-support       plan 01 done, plan 02 done, plan 03 done, plan 04 done, plan 05 executing, plan 06 executing, plan 07 executing  
DONE/DROPPED: 7 done, 2 dropped (not listed)
```

## Probe results

**Setup.** Throwaway root: a fresh directory under the session scratchpad, `git init` run in
it. Each skill step ran in a nested session started from that root as
`claude -p --plugin-dir <worktree>/plugins/claudestacks-sdlc --permission-mode acceptEdits …`,
continued turn by turn with `--resume <session-id>`. Boards were rendered from the root with
`sh <worktree>/plugins/claudestacks-sdlc/scripts/status.sh`. Chains were written by hand
(intent, approved spec with `built-on` and `adrs`, plans with `built-on`), by a scratch script
computing each fingerprint with `fingerprint.sh`; see Deviations.

**`--plugin-dir` probe (Risks).** A nested session in the throwaway root listed
`claudestacks-sdlc:adr` among its skills and quoted the worktree's new artifact-reviewer
description ("…a spec, a set of plans, or an ADR…"), so the directory copy replaced the
installed 0.2.0. This matches `plugins/loading.md:367` ("An enabled `--plugin-dir` … plugin. It
replaces a same-named installed marketplace plugin"), fetched with curl.

### Walkthrough step 1 — `/adr new` → reviewed → approved

`/claudestacks-sdlc:adr new` with the five answers given up front. The skill wrote
`adrs/0001-store-local-state-as-json-files.md` as `draft`, ran one artifact-reviewer round
(1🔴 3🟡, disposition table shown), amended on the author's word, then approved on an
explicit yes.

```
$ head -5 .claudestacks/sdlc/adrs/0001-store-local-state-as-json-files.md
---
status: approved
created: 2026-10-20
sealed: ec1e24f1cb1f
---
$ sh …/scripts/fingerprint.sh .claudestacks/sdlc/adrs/0001-store-local-state-as-json-files.md
ec1e24f1cb1f
$ sh …/scripts/status.sh
CHAIN                             STATE                         NEXT
ADRS: 1 approved
```

### Walkthrough step 2 — a body line edited by hand

```
$ sed -i '' 's/^Option 1/Option 2/' .claudestacks/sdlc/adrs/0001-store-local-state-as-json-files.md
$ sh …/scripts/status.sh
CHAIN                             STATE                         NEXT
ADRS: 1 invalid
  ADR 0001                        INVALID (0001-store-local-state-as-json-files.md: edited after approval)  fix adr 0001
```

The edit was reverted from a copy taken before it.

### Walkthrough step 3 — supersede with two citing chains; re-confirm one, redesign one

Chains `2026-10-20-alpha` and `2026-10-20-beta` written by hand, each with an approved spec
citing `adrs: [0001]` and one approved plan:

```
CHAIN                             STATE                         NEXT
2026-10-20-alpha                  plan 01 approved              execute 01
2026-10-20-beta                   plan 01 approved              execute 01
ADRS: 1 approved
```

`/claudestacks-sdlc:adr supersede 0001` wrote `0002-store-local-state-in-one-json-file.md`
with `supersedes: [0001]`, reviewed it with 0001 as authority (3🔴 3🟡 2🔵, table shown), and on
the author's yes approved it and flipped 0001 in the same turn:

```
$ head -5 .claudestacks/sdlc/adrs/0001-*.md            $ head -6 .claudestacks/sdlc/adrs/0002-*.md
status: superseded                                      status: approved
sealed: ec1e24f1cb1f                                    supersedes: [0001]
                                                        sealed: dc305666c834
$ sh …/scripts/status.sh
CHAIN                             STATE                         NEXT
2026-10-20-alpha                  spec stale (ADR 0001 superseded by 0002), plan 01 approved  design
2026-10-20-beta                   spec stale (ADR 0001 superseded by 0002), plan 01 approved  design
ADRS: 1 approved, 1 superseded
```

`/claudestacks-sdlc:design 2026-10-20-alpha` offered the ADR re-confirmation; on "yes" it
changed `adrs: [0001]` to `[0002]` and nothing else. Its own board render, as it reported
it (chain rows only):

```
2026-10-20-alpha                  plan 01 approved              execute 01
2026-10-20-beta                   spec stale (ADR 0001 superseded by 0002), plan 01 approved  design
```

`/claudestacks-sdlc:design 2026-10-20-beta`, answered "no" to the re-confirmation and asked
for the redesign: the approved spec was renamed `spec-superseded-2026-10-20.md` and flipped
`superseded`; a fresh draft citing `adrs: [0002]` was written, reviewed once, and approved on
an explicit yes.

```
$ grep built-on .claudestacks/sdlc/2026-10-20-*/plans/*.md
.claudestacks/sdlc/2026-10-20-alpha/plans/01-step-01.md:built-on: 38d8c5ec5186
.claudestacks/sdlc/2026-10-20-beta/plans/01-step-01.md:built-on: 1f33bee08262
$ sh …/scripts/fingerprint.sh .claudestacks/sdlc/2026-10-20-alpha/spec.md
38d8c5ec5186
$ sh …/scripts/status.sh
CHAIN                             STATE                         NEXT
2026-10-20-alpha                  plan 01 approved              execute 01
2026-10-20-beta                   plan 01 approved: stale (spec changed)  plan
ADRS: 1 approved, 1 superseded
```

### Walkthrough step 4 — a plan's execution disproves a cited ADR

Chain `2026-10-20-gamma` written by hand: approved spec citing `adrs: [0002]`, plan 01 `done`,
plans 02 and 03 `approved`. Plan 02's task relies on ADR 0002's statement that
`tools/count.sh` prints exactly one line, and its Risks name that as the probe. A
`tools/count.sh` printing two lines was written into the root. Alpha and beta (both citing
0002 after step 3) are the chains that only cite it, in place of a separate fixture chain.

```
$ sh …/scripts/status.sh
CHAIN                             STATE                         NEXT
2026-10-20-alpha                  plan 01 approved              execute 01
2026-10-20-beta                   plan 01 approved: stale (spec changed)  plan
2026-10-20-gamma                  plan 01 done, plan 02 approved, plan 03 approved  execute 02
ADRS: 1 approved, 1 superseded
```

`/claudestacks-sdlc:execute 2026-10-20-gamma/02` ran the probe before any coder, found
`sh tools/count.sh | wc -l` → `2`, attributed the break to ADR 0002 (the spec defers to it),
wrote `disproves-adr: [0002]` into `plans/02-step-02.md` before any further task, rendered the
board, and asked whether to amend now or build first:

```
$ sh …/scripts/status.sh
CHAIN                             STATE                         NEXT
2026-10-20-alpha                  ADR 0002 disproven by 2026-10-20-gamma/02, plan 01 approved  adr
2026-10-20-beta                   ADR 0002 disproven by 2026-10-20-gamma/02, plan 01 approved: stale (spec changed)  adr
2026-10-20-gamma                  ADR 0002 disproven by plan 02, plan 01 done, plan 02 approved, plan 03 approved  adr
ADRS: 1 approved, 1 superseded
  ADR 0002                        disproven by 2026-10-20-gamma/02  adr supersede 0002
```

`/claudestacks-sdlc:execute 2026-10-20-gamma/03` refused, naming
`plans/03-step-03.md`, the condition `ADR 0002 disproven by plan 02`, and the `adr` skill
as what clears it. `/claudestacks-sdlc:execute 2026-10-20-alpha/01` refused, naming the
condition `ADR 0002 disproven by 2026-10-20-gamma/02` ("no plan in alpha is allowed to start,
with no exception") and the `adr` skill. Neither changed a file.

Gamma's plans 02 and 03 were then flipped to `done` by hand so every plan is settled while
the disproof stands (see Deviations):

```
$ sh …/scripts/status.sh
CHAIN                             STATE                         NEXT
2026-10-20-alpha                  ADR 0002 disproven by 2026-10-20-gamma/02, plan 01 approved  adr
2026-10-20-beta                   ADR 0002 disproven by 2026-10-20-gamma/02, plan 01 approved: stale (spec changed)  adr
2026-10-20-gamma                  ADR 0002 disproven by plan 02, plan 01 done, plan 02 done, plan 03 done  adr
ADRS: 1 approved, 1 superseded
  ADR 0002                        disproven by 2026-10-20-gamma/02  adr supersede 0002
```

`/claudestacks-sdlc:execute 2026-10-20-gamma` (bare chain) reported the chain not complete,
named `ADR 0002 disproven by gamma/02` and the `adr` skill as what holds it open, and left
the intent `approved`.

`/claudestacks-sdlc:adr supersede 0002` wrote `0003-read-state-counts-from-a-two-line-count-sh.md`
(`supersedes: [0002]`), its context citing the probe, reviewed it with 0002 as authority
(1🔴 3🟡 2🔵, table shown), and on the author's yes approved it (`sealed: 775aa8d97314`) and
flipped 0002 to `superseded` in the same turn. C5 and the ADR row cleared; C6 appeared:

```
$ sh …/scripts/status.sh
CHAIN                             STATE                         NEXT
2026-10-20-alpha                  spec stale (ADR 0002 superseded by 0003), plan 01 approved  design
2026-10-20-beta                   spec stale (ADR 0002 superseded by 0003), plan 01 approved: stale (spec changed)  design
2026-10-20-gamma                  spec stale (ADR 0002 superseded by 0003), plan 01 done, plan 02 done, plan 03 done  design
ADRS: 1 approved, 2 superseded
```

`/claudestacks-sdlc:design 2026-10-20-gamma` offered the ADR re-confirmation; on "yes" it
changed `adrs: [0002]` to `[0003]` and nothing else, and reported the row as `chain complete`.
`/claudestacks-sdlc:execute 2026-10-20-gamma` then walked the intent up to `done`:

```
$ head -3 .claudestacks/sdlc/2026-10-20-gamma/intent.md
---
status: done
$ sh …/scripts/status.sh
CHAIN                             STATE                         NEXT
2026-10-20-alpha                  spec stale (ADR 0002 superseded by 0003), plan 01 approved  design
2026-10-20-beta                   spec stale (ADR 0002 superseded by 0003), plan 01 approved: stale (spec changed)  design
ADRS: 1 approved, 2 superseded
DONE/DROPPED: 1 done, 0 dropped (not listed)
```

### Walkthrough step 5 — deprecate an approved ADR a chain cites

Chain `2026-10-20-epsilon` written by hand, its approved spec citing `adrs: [0003]`.
`/claudestacks-sdlc:adr deprecate 0003`, on the author's explicit word, flipped
`approved → deprecated`, changed nothing else in the file, and said the reason belongs in the
commit message:

```
$ head -6 .claudestacks/sdlc/adrs/0003-*.md
---
status: deprecated
created: 2026-10-20
supersedes: [0002]
sealed: 775aa8d97314
---
$ sh …/scripts/status.sh
CHAIN                             STATE                         NEXT
2026-10-20-alpha                  spec stale (ADR 0002 superseded by 0003), plan 01 approved  design
2026-10-20-beta                   spec stale (ADR 0002 superseded by 0003), plan 01 approved: stale (spec changed)  design
2026-10-20-epsilon                spec stale (ADR 0003 deprecated), plan 01 approved  design
ADRS: 2 superseded, 1 deprecated
DONE/DROPPED: 1 done, 0 dropped (not listed)
```

### Walkthrough step 6 — `adrs` written by hand into an intent

`adrs: [0001]` added to `2026-10-20-epsilon/intent.md`'s frontmatter:

```
$ sh …/scripts/status.sh
CHAIN                             STATE                         NEXT
2026-10-20-alpha                  spec stale (ADR 0002 superseded by 0003), plan 01 approved  design
2026-10-20-beta                   spec stale (ADR 0002 superseded by 0003), plan 01 approved: stale (spec changed)  design
2026-10-20-epsilon                INVALID (intent.md: adrs not allowed here)  fix 2026-10-20-epsilon
ADRS: 2 superseded, 1 deprecated
DONE/DROPPED: 1 done, 0 dropped (not listed)
```

### Walkthrough step 7 — the session-start hook

With no ADR row standing after step 6, one line was appended to 0003's sealed body to give
the board a problem ADR row, then `attention.sh` ran from the root with stdin from
`/dev/null`:

```
$ echo "Edited after approval." >> .claudestacks/sdlc/adrs/0003-read-state-counts-from-a-two-line-count-sh.md
$ sh …/scripts/attention.sh </dev/null
claudestacks-sdlc: 3 open, 6 need attention — full board: /claudestacks-sdlc:status
2026-10-20-alpha                  spec blocked (ADR 0002 not approved), plan 01 approved  adr
2026-10-20-beta                   spec blocked (ADR 0002 not approved), plan 01 approved: stale (spec changed)  adr
2026-10-20-epsilon                INVALID (intent.md: adrs not allowed here)  fix 2026-10-20-epsilon
  ADR 0001                        INVALID (0001-store-local-state-as-json-files.md: superseded by nothing)  fix adr 0001
  ADR 0002                        INVALID (0002-store-local-state-in-one-json-file.md: superseded by nothing)  fix adr 0002
  ADR 0003                        INVALID (0003-read-state-counts-from-a-two-line-count-sh.md: edited after approval)  fix adr 0003
$ sh …/scripts/status.sh
CHAIN                             STATE                         NEXT
2026-10-20-alpha                  spec blocked (ADR 0002 not approved), plan 01 approved  adr
2026-10-20-beta                   spec blocked (ADR 0002 not approved), plan 01 approved: stale (spec changed)  adr
2026-10-20-epsilon                INVALID (intent.md: adrs not allowed here)  fix 2026-10-20-epsilon
ADRS: 3 invalid
  ADR 0001                        INVALID (0001-store-local-state-as-json-files.md: superseded by nothing)  fix adr 0001
  ADR 0002                        INVALID (0002-store-local-state-in-one-json-file.md: superseded by nothing)  fix adr 0002
  ADR 0003                        INVALID (0003-read-state-counts-from-a-two-line-count-sh.md: edited after approval)  fix adr 0003
DONE/DROPPED: 1 done, 0 dropped (not listed)
```

The hook lists the problem ADR rows and chain rows and not the `ADRS:` heading. The cascade
is the §13.3 lister rule: 0003, invalid, lists nothing; so 0002, `superseded` with no lister,
is invalid; so 0001 likewise; and alpha and beta, citing an invalid ADR, read C7
(`artifact-chain.md` §10.4: "A superseded ADR that no lister lists is invalid … so a chain
citing it reads C7, not C6").

**Comparison with `artifact-chain.md`.** Every STATE and NEXT in the boards above is a
wording `artifact-chain.md` §10.3, §10.4 and §13.3–§13.4 states: `edited after approval` /
`fix adr NNNN`; `spec stale (ADR NNNN superseded by MMMM)` / `design`; `spec stale (ADR NNNN
deprecated)` / `design`; `ADR NNNN disproven by plan NN` and `ADR NNNN disproven by
<chain>/NN` / `adr`; `disproven by <chain>/NN` / `adr supersede NNNN`; `superseded by nothing`
/ `fix adr NNNN`; `spec blocked (ADR NNNN not approved)` / `adr`; `INVALID (intent.md: adrs not
allowed here)` (§11.7); the `ADRS:` heading's order and zero-omission. No wording differed.

## Deviations

- 2026-10-20 — **Non-interactive sessions.** The walkthrough drove each skill through
  `claude -p … --resume <id>` turns rather than an interactive terminal, and gave the
  answers to a skill's dialogue questions up front in one message instead of one at a time.
  The board, the files, the reviews and every approval question ran as in an interactive
  session; one-question-at-a-time pacing was not exercised.
- 2026-10-20 — **Hand-written chains.** Every chain (alpha, beta, gamma, epsilon) was
  written by a scratch script — approved intent, approved spec with a computed `built-on`
  and `adrs`, plans with a computed `built-on` — rather than through `intent`, `design` and
  `plan`. The flows under test are the ADR ones; beta's redesign did run through `design`.
- 2026-10-20 — **Step 4's second chain.** Alpha and beta, citing ADR 0002 after step 3,
  served as the chains that only cite the disproven ADR, in place of a separate fixture.
  Alpha's `execute 01` was the recorded refusal.
- 2026-10-20 — **Step 4's walk-up.** Gamma's plans 02 and 03 were flipped to `done` by hand
  after the disproof and the refusals were recorded, so that every plan was settled while
  C5 stood. Plan 02's run had stopped at the probe (before any coder) on the author's
  instruction; building its task adds nothing to the ADR behaviour under test.
- 2026-10-20 — **Step 7's problem ADR row.** No ADR row stood after step 6, so one line was
  appended to ADR 0003's sealed body to raise `edited after approval` before running
  `attention.sh`.
- 2026-10-20 — **`git init` path.** Run as `git init -q <dir>` from the worktree, since the
  worktree guard refused a compound `cd … && git init`.
- 2026-10-20 — **Wording.** No board wording in the walkthrough differed from
  `artifact-chain.md`. One nested session's prose summary misquoted the heading as
  `ADRS: 2 superseded, 1 deprecated, 0 approved`; the board itself printed
  `ADRS: 2 superseded, 1 deprecated` (step 5), so the defect is in that session's paraphrase,
  not the renderer.
- 2026-10-20 — **README beyond the plan.** The fix round named ADRs in the README's intro and
  added `adrs/` to its artifact tree, which the plan's Task 2 did not list (review finding).
