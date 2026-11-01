---
name: plan
description: Use when a chain's spec is approved (or its intent carries spec: skipped) — refuses a spec with unproven claims, derives a plan set covering every spec requirement (files, order of work, risks, named tests) without asking or writing code, and asks once for the whole set to be accepted.
---

# Plan

## The rule

All discussion and all proof happened at intent and spec. An accepted plan is ready to build,
and `execute` builds it without asking or re-proving.

- **Ask nothing** but the one acceptance question for the whole set.
- **Write no code** — no implementation, no test bodies, no diff, no prototype. `execute`'s coder
  writes tests and code, test-first.
- **Run nothing new** — no probe, fetch or verification. Read files, `grep`, `git log`: to map
  files and name work, not to check the spec.
- **Refuse an unproven spec.** **Cover every spec requirement** across the set.

Paths, frontmatter, states: `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`. Body shapes:
`${CLAUDE_PLUGIN_ROOT}/references/templates.md`. Lazy-create `plans/`.

## Gates

**State.** Proceed only with `spec.md` `approved`, or no `spec.md` and an `approved` `intent.md`
carrying `spec: skipped`. Otherwise refuse, naming file, state and what advances it: spec
`draft` → `design`; no spec, no flag → `design`, or the author sets the flag via `intent`;
intent not `approved` → `intent`. Never set `spec: skipped` yourself.

**Board.** `sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"`, read the chain's row; empty output
means no `airsl` — derive it as the `status` skill's fallback does. Repeat after every `status`
flip and tell the author the row. The **authority** is `spec.md`, or `intent.md` on the
spec-skip path. Refuse, naming the file, the condition in the board's words, and what clears it:

| The row reads | Cleared by |
|---|---|
| `spec stale (intent changed)`, `spec disproven by plan NN`, `spec stale (ADR NNNN superseded by MMMM)`, `spec stale (ADR NNNN deprecated)`, `plan NN <status>: blocked (spec not approved)`, `INVALID (spec.md: missing built-on)` | `design` |
| `intent disproven by plan NN` | `intent` |
| `ADR NNNN disproven by plan NN`, `ADR NNNN disproven by <chain>/NN`, `spec blocked (ADR NNNN not approved)` | `adr` |
| any other `INVALID (…)` except `INVALID (plans/NN: missing built-on)` | the author, in the named file |

**Own conditions** — `plan NN <status>: stale (spec changed)`, `… stale (intent changed)`,
`INVALID (plans/NN: missing built-on)`. Per plan, in number order, offer: **re-confirm** (*does
plan `NN` still hold against its authority as it now reads?* — on explicit yes write the 12
characters of `sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <authority file>` as its
`built-on`, nothing else, status kept) or **supersede** (flip `superseded`; the replacement takes
the next free `NN`). Never inferred; one plan's yes covers no other. Re-render after clearing.

**Proven spec.** List every spec claim a task depends on; each must carry its recorded proof
beside it (probe command + real output, `<file>:<line>`, or the command behind a count). Check
presence only. If a claim lacks proof, or the spec leaves open what a plan must decide (an edge
case, an error path, which file owns a behaviour, where a boundary falls, which of two readings),
write no plan: name the gap in one line and send the spec back to `design`. Never plan around it,
park it in `## Risks`, assume it, or ask the author. Spec-skip: tasks encode only what the intent
states; anything more means run `design`.

## Derive the set

- **Fan-out:** derive the plans and their `depends-on` yourself; do not propose first. One
  objective per plan — a Goal needing "and" means split. Tasks are not objectives.
- **Coverage:** map every spec requirement, edge case and error rule to a plan and task. One in
  no plan is a defect.
- **Files first:** one line of responsibility per changed file (prefer a new focused file); each
  file in exactly the tasks touching it. `claudestacks:explorer` locates what exists (unresolved:
  inline, say so); deciding what changes stays here.
- **Tasks** are the order of work: one sitting, a handful of named tests, ends in a commit.
- **Guideline:** detect the stack (`Cargo.toml` → Rust), load its skill
  (`claudestacks-guideline-rust:rust-guidelines`), conform to its architecture rules, put its
  Definition of Done in every done-check. DRY / YAGNI.
- **Checkpoints** only where the spec asks; `execute` ends a batch there and never stops.
- A fact living in a type being built is read from there, never copied into a task.

Write `plans/NN-<kebab-topic>.md` (siblings differ by topic; never renumber) in the templates.md
plan shape (Goal, Architecture, Tech Stack each on its own line):

```markdown
---
status: draft
created: <YYYY-MM-DD>
depends-on: [01]          # optional; absent/empty = independent
built-on: <fingerprint>   # 12 chars of fingerprint.sh <authority>; empty → stop, name the file
---
# [Feature Name] Implementation Plan
**Goal:** [one sentence, no "and"] · **Architecture:** · **Tech Stack:** (see templates.md)

### Task N — [Short imperative title]
**Files:** Create/Modify/Test `<path>` — <purpose>
**Change:** <behaviour; new types/functions by name and one-line purpose>
**Proof:** written first, seen failing, then passing — `<test_name>` — <assertion in prose>
**Done when:** `<command>` passes and the Definition of Done is green. Commit `<message>`.
```

No code block holds implementation or test code; command lines are fine. Tasks sharing a
structure each say so — never "similar to Task N". Close with **`## Risks`** (what could break,
riskiest step, what was not done — never an unproven premise) and **`## Proof`** (plan-wide checks).

## Review — one agent, one round, the whole set

`/claudestacks:context-handoff` for the protocol path (one subagent: literal temp path, no
session, expand `${TMPDIR:-/tmp}` yourself). Spawn `claudestacks-sdlc:artifact-reviewer` once for
the set, never per plan: `kind: plan-set`, `draft: <chain>/plans/NN-*.md` (every draft),
`authority: <chain>/spec.md` (or `intent.md` on spec-skip),
`handoff: <TMPDIR>/claudestacks-sdlc-<chain>-plan-set-01.md`, `handoff-protocol: <path>`.

- One round; never re-spawn after fixes or author changes. Route off the summary; read
  `<detail>` only to act. You fix every finding; the agent never edits, flips or commits.
- Criteria: `${CLAUDE_PLUGIN_ROOT}/references/artifact-review.md` § *Reviewing a draft plan set*;
  meet its no-placeholder list while drafting. Agent fails: apply inline, say so.
- Every finding at every tier (not only 🔴) gets a row:
  `| # | Plan | Tier | Finding | Disposition (applied / declined — reason) |`. A plan whose mtime
  predates the report was not revisited.

## Acceptance — one question

Recompute the authority fingerprint; if it differs from the plans' `built-on`, say so and ask
whether the set holds against the authority as it now reads. In one message show each plan's
path, Goal and `depends-on`, and the full disposition table, declined rows included. Ask once:
*accept the plan set?* Yes → flip every plan `draft → approved` and write the current fingerprint
as `built-on`, one edit per file; re-render, report the row. Changes → revise, present the set
again, no new review.

Plans are never deleted; a superseded plan keeps its file and flips `status: superseded`.
Recommend committing approved plans before execution (the author's act). Next: `execute`.
