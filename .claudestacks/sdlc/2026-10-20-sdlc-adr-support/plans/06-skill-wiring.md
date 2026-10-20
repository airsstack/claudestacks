---
status: approved
created: 2026-10-20
depends-on: [03, 04]
built-on: c2d88a3e18f4
---

# ADR Conditions in Existing Skills Implementation Plan

**Goal:** The `design`, `execute`, `plan` and `status` skills each act on every ADR
condition the board reports, as spec §7.2–§7.5 assigns.

**Architecture:** Each skill already reads the board before acting and refuses or clears
by an explicit table of board wordings (`skills/design/SKILL.md:44-49`,
`skills/execute/SKILL.md:48-55`, `skills/plan/SKILL.md:89-96`). This plan adds the ADR
wordings to those tables and the few ADR steps spec §7 names, in the board's exact words
from `references/artifact-chain.md` (plan 04). No skill gains a question about ADRs.
Prose only; no Lua change.

**Tech Stack:** Markdown (Claude Code skill definitions).

**Content authority:** spec §6.2, §6.3, §7.2, §7.3, §7.4, §7.5, §10.

---

## Files that change

```
plugins/claudestacks-sdlc/skills/design/SKILL.md   — [modify] ADR reading, sync rows, approval refusal, hand-off
plugins/claudestacks-sdlc/skills/execute/SKILL.md  — [modify] ADR refusals, ADR disproof, walk-up holds
plugins/claudestacks-sdlc/skills/plan/SKILL.md     — [modify] ADR refusal rows
plugins/claudestacks-sdlc/skills/status/SKILL.md   — [modify] the fallback scans adrs/
```

Every path is relative to the repository root. Skill behaviour has no unit test (spec
§11); plan 07 runs the recorded walkthrough. The gate for each task is
`claude plugin validate --strict plugins/claudestacks-sdlc` exiting 0, the named `grep`
checks, and `cargo make plugins` still passing. The four tasks touch four different
files and may run in any order.

The installed copies these skills run from in this session are 0.2.0 under the plugin
cache; edits land in the worktree's `plugins/claudestacks-sdlc/` only.

## Order of work

### Task 1 — `design` reads ADRs, clears C5–C7, and refuses unapproved citations

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/design/SKILL.md`

**Change:**

- **Sync table** (:44-49) gains three rows (spec §7.2):
  `ADR NNNN disproven by …` (either form) → tell the author the cited ADR is disproven and
  that the `adr` skill supersedes or deprecates it; `spec stale (ADR NNNN superseded by
  MMMM)` and `spec stale (ADR NNNN deprecated)` → the ADR re-confirmation below;
  `spec blocked (ADR NNNN not approved)` → tell the author the cited ADR is not approved
  and that the `adr` skill approves it. The sentence above the table (:41) stops saying
  "Four of them".
- **ADR re-confirmation**, a paragraph beside *Re-confirmation* (spec §6.2): ask one
  question — does this spec still hold under the successor as it reads, or without the
  deprecated decision? On an explicit yes, replace the number with its successor(s) in
  the spec's `adrs`, or remove it when deprecated, and change nothing else — the key is
  frontmatter, so the spec's fingerprint and its plans are untouched. On a no, offer the
  redesign path (step 11) and follow it only on the author's word.
- **Step 3** (:139-151): when `.claudestacks/sdlc/adrs/` exists, read the title of every
  `approved` ADR and the body of each that bears on the intent. Reading is not asking.
- **Step 6** (:188-192): approved ADRs are settled decisions; an approach that
  contradicts one says so and names it, and taking it means superseding that ADR through
  the `adr` skill, on the author's word.
- **Hand-off**: one paragraph — the skill never asks whether a choice should be an ADR;
  when the author asks for one to be recorded, hand off to the `adr` skill's *new*
  operation, then write the new number into the draft spec's `adrs`.
- **Step 10** (:269-287): before asking for approval, refuse to approve a spec whose
  `adrs` names an ADR that is unknown, ambiguous, invalid, disproven, or not `approved`,
  naming the ADR and its status. A draft spec's citations raise no C5, C6 or C7 part, and a
  healthy `superseded` or `deprecated` ADR has no ADR row (spec §4.3, §5.1), so for each
  cited number read the ADR's row when it has one and the status from its file when it
  has none — the rule the `adr` skill follows (plan 05).
- **Step 11** (:288-295): a redesign writes `adrs` afresh in the new spec.

**Proof:** run from the repository root with `D=plugins/claudestacks-sdlc/skills/design/SKILL.md` —
- `claude plugin validate --strict plugins/claudestacks-sdlc` exits 0.
- `grep -nF 'spec stale (ADR NNNN superseded by MMMM)' "$D"`, `grep -nF 'spec blocked (ADR NNNN not approved)' "$D"`, `grep -nF 'ADR NNNN disproven by' "$D"` and `grep -nF 'adrs/' "$D"` each print at least one line.
- `grep -nF 'Four of them' "$D"` prints nothing.

**Done when:** every check holds. Commit
`feat(repo): read and clear ADR conditions in claudestacks-sdlc design`.

### Task 2 — `execute` refuses under ADR conditions and records an ADR disproof

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/execute/SKILL.md`

**Change:**

- **Refusal table** (:48-55) gains (spec §7.3): `spec stale (ADR …)` → the `design`
  skill; `spec blocked (ADR …)` → the `adr` skill; `ADR NNNN disproven by
  <chain>/NN` → the `adr` skill, with no exception. Beside the existing paragraph on
  `spec disproven by plan NN` (:61-66), one paragraph: while the row reads `ADR NNNN
  disproven by plan NN`, refuse every plan of the chain except plan `NN` itself, which
  may finish its run; the `adr` skill clears it.
- **Disproof** (:323-357): the question asks which claim broke — the plan's, the spec's,
  a cited ADR's, or several — and whether to amend now or after this run. When a cited
  ADR's claim broke, add its number to the running plan's `disproves-adr` before any
  further task, whatever the author answers; numbers are added, never removed; only ADRs
  the spec's `adrs` cites may be named, since the board reports any other as `INVALID
  (plans/NN: disproves uncited ADR NNNN)`. Then render the board again and say what the
  row reads.
- **Walk-up** (:406-…): the bullet for a settled chain held open adds `ADR NNNN disproven
  by …` (the `adr` skill), `spec stale (ADR …)` (`design`) and `spec blocked (ADR …)`
  (the `adr` skill) to the conditions that hold it open.

**Proof:** run from the repository root with `E=plugins/claudestacks-sdlc/skills/execute/SKILL.md` —
- `claude plugin validate --strict plugins/claudestacks-sdlc` exits 0.
- `grep -nF 'disproves-adr' "$E"`, `grep -nF 'ADR NNNN disproven by plan NN' "$E"`, `grep -nF 'ADR NNNN disproven by <chain>/NN' "$E"`, `grep -nF 'spec blocked (ADR' "$E"` and `grep -nF 'disproves uncited ADR' "$E"` each print at least one line.

**Done when:** every check holds. Commit
`feat(repo): honour ADR conditions in claudestacks-sdlc execute`.

### Task 3 — `plan` refuses under ADR conditions

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/plan/SKILL.md`

**Change:** the refusal table (:89-96) gains `ADR NNNN disproven by …` (either form) →
the `adr` skill; `spec stale (ADR …)` → the `design` skill; `spec blocked (ADR …)` → the
`adr` skill (spec §7.4).

**Proof:** run from the repository root with `P=plugins/claudestacks-sdlc/skills/plan/SKILL.md` —
- `claude plugin validate --strict plugins/claudestacks-sdlc` exits 0.
- `grep -nF 'spec stale (ADR' "$P"`, `grep -nF 'spec blocked (ADR' "$P"` and `grep -nF 'ADR NNNN disproven by' "$P"` each print at least one line.

**Done when:** every check holds. Commit
`feat(repo): refuse planning under ADR conditions in claudestacks-sdlc`.

### Task 4 — The `status` fallback renders the ADR block

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/status/SKILL.md`

**Change:** the fallback paragraph (:15-24) also scans `.claudestacks/sdlc/adrs/`, reads
each ADR file's frontmatter, derives every ADR's row and every chain's ADR conditions by
`artifact-chain.md` §10 and §13, computes each sealed ADR's fingerprint with
`fingerprint.sh` (as the existing paragraph at :26-31 already requires for any
fingerprint), and prints the `ADRS:` block after the chain rows and before the
`DONE/DROPPED` line (spec §7.5).

**Proof:** run from the repository root with `T=plugins/claudestacks-sdlc/skills/status/SKILL.md` —
- `claude plugin validate --strict plugins/claudestacks-sdlc` exits 0.
- `grep -nF 'adrs/' "$T"` and `grep -nF 'ADRS:' "$T"` each print at least one line.

**Done when:** every check holds. Commit
`feat(repo): render ADRs in the claudestacks-sdlc status fallback`.

---

## Risks

- **A refusal row that does not match the board's wording** is never triggered. Each row
  is copied from `artifact-chain.md` (plan 04), which copies the spec; plan 07's
  walkthrough drives each skill into each condition and records the refusal.
- **The C6 re-confirmation must not touch the spec's body**, or the spec's fingerprint
  changes and every plan reads `stale (spec changed)`. The paragraph says "change nothing
  else", as the existing re-confirmation does.
- Not changed, per spec §7.6: `intent`, `roadmap`, `milestone`, `distill`, `triage`,
  `setup`, `chain-reader`, `task-briefer`.

## Proof

- `claude plugin validate --strict plugins/claudestacks-sdlc` exits 0.
- Every board wording from spec §4.3 appears in each skill table spec §7 assigns it to,
  by the `grep` checks above.
- Plan 07's walkthrough drives each skill through each condition.
