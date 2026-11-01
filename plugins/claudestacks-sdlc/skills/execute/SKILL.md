---
name: execute
description: Use when a chain has an approved plan to carry out — builds it through parallel claudestacks coder/reviewer spawns, never asks the author anything, re-proves nothing, and reports once at the end. Invoke by chain/plan reference (e.g. "execute 2026-08-24-webhook-reliability/01").
---

# Execute

## The rule

An accepted plan is ready to build. All discussion and all proof happened at intent and
spec. The author is not watching this run.

- **Never ask.** No questions, no "accept?", no "open decisions", no waiting — not mid-run,
  not at the end.
- **Never re-prove.** No probes, doc fetches or assumption checks. Run only the tests the
  plan names and the stack's Definition of Done.
- **Never refuse.** Board conditions, draft status, TODOs, fingerprint mismatches: note them
  and run.
- **Say nothing until the end.** One completion report is the only message.

When something is unclear or the spec is silent, decide — pick what is closest to the
spec's stated intent — and write the call in the plan's `## Deviations`. That is never a
question.

Paths, frontmatter and states: `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`.

## Start

1. **Which plans.** A plan reference runs that plan. A bare chain name runs every plan not
   `done`/`superseded`, in `depends-on` order. A plan whose `depends-on` is not `done` runs
   after that dependency. A `done`/`superseded` plan: say so in one line, run nothing.
2. **Board.** `sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"`. Whatever the row says, copy
   it into `## Deviations` if it is not clean, and carry on.
3. **Branch.** On `main`/`master`, create `sdlc/<chain>-<NN>` and work there.
4. **Status.** Flip the plan to `executing` (a `draft` plan goes `draft → approved →
   executing`; running it is its approval).
5. **Handoff.** Invoke `/claudestacks:context-handoff` once; use the session tier.
6. **Ledger.** Spawn `claudestacks-sdlc:task-briefer` with `mode: ledger`, `plan: <path>`,
   `handoff: <session-dir>/01-task-briefer-ledger.md`, `handoff-protocol: <path>`. Put one
   TodoWrite item per task. Never read the plan end to end. If the agent is missing, use
   `grep -n '^### Task' <plan>`.

## Build, batch by batch

Batch consecutive tasks whose file sets are disjoint and that do not use a symbol another
task in the batch creates. A plan checkpoint just ends a batch.

Per batch:

1. **Brief** — one `task-briefer` (`mode: brief`, `task: <N>`) per task, in one message.
2. **Implement** — one `claudestacks:coder` per task, in one message. Each gets its own
   `handoff:` path, the `handoff-protocol:` path, `need: <briefer handoff>`, the stack
   guideline skill to load, the plan's verification commands, and: write the named tests
   first, see them fail, then implement. Never two coders on one file.
3. **Verify** — run the plan's verifications and the Definition of Done once for the batch
   (scoped to the touched crate/package; workspace-wide once at the end).
4. **Review once** — one `claudestacks:reviewer` over the batch diff. Brief: judge the diff
   against this plan only; do not open or compare with the spec. Drop any plan-vs-spec
   finding.
5. **Fix once** — send the reviewer's `blocking:` set (or every 🔴 if none is named) to a
   fresh `coder`, re-run only the verification it touches. No second review. Anything still
   unresolved goes to `## Review findings` as open.
6. Mark the tasks `completed`, keep the evidence for the report, start the next batch.

A task whose verification fails is incomplete; skip only batches that depend on it.

**When the build contradicts the plan, spec or an ADR** (a named test, the compiler or the
DoD shows a claim wrong): build to what the code showed, add a `## Deviations` entry (claim,
stage it came from, command + real output, what was built instead), and continue. If the
claim was the spec's or intent's, set `disproves: <fingerprint>` in this plan's frontmatter
(`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <authority>`); if a cited ADR's, add its
number to `disproves-adr: [NNNN]`. Never edit `spec.md`, `intent.md` or an ADR.

**When a task is blocked** (missing dependency, a failure nothing explains, a destructive
step the plan does not name): do not run it, record it in `## Deviations`, keep running
everything that does not depend on it.

## Finish

1. Append to the plan: `## Review findings` (one line per finding; a "fixed" line carries
   its command and real output) and `## Deviations` (dated entries; omit if none).
2. Flip the plan to `done` if every task completed; otherwise leave it `executing`.
3. Render the board. If the row reads `chain complete`, flip the chain's `intent.md` to
   `done`; if that intent has a `milestone` key, run the roll-up from `artifact-chain.md`.
4. Send the **completion report** — the one message of the run:
   - blocked tasks and contradicted claims first, each with the skill that clears it;
   - what was built, verification results, reviewer verdicts;
   - the board row.
   No questions, no open decisions, no "accept?".

Do not commit, merge or push unless the instruction to execute said to.
