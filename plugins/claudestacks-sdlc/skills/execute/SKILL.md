---
name: execute
description: Use when a chain has an approved plan to carry out — executes it task by task with review checkpoints and walks chain states up on completion. Invoke by chain/plan reference (e.g. "execute 2026-08-24-webhook-reliability/01") once a plan is approved and before any of its code is written.
---

# Execute

Drive a written plan to a reviewed, presentable state, task by task. This skill does not design
and does not plan — those are the `design` and `plan` skills. It works with any plan in the
chain's documented on-disk format, whether written by `plan` or by hand.

Paths, naming, frontmatter, and state transitions all come from
`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`; artifact body shapes come from
`${CLAUDE_PLUGIN_ROOT}/references/templates.md`.

## Input

Take a chain/plan reference, e.g. `2026-08-24-webhook-reliability/01`, resolving to
`.claudestacks/sdlc/2026-08-24-webhook-reliability/plans/01-<topic>.md`. If the user gives a bare
chain name with no plan number, ask which plan (or offer the chain's `approved` plans as
choices).

## State gate

Read the plan's frontmatter before anything else:

- `status` other than `approved` — refuse. Name the file, its current state, and the command
  that advances it (`draft` → the `plan` skill's approval gate; `executing` → this skill is
  presumably already resuming it, so continue rather than refuse; `done` or `superseded` → the
  work already happened or was replaced, so a new round is a new plan).
- `depends-on` names a plan that is not yet `done` — do not refuse, but warn and ask before
  proceeding: the dependency may be irrelevant to the tasks about to run, so this is the user's
  call, not an automatic block.

## Load and review

Read the plan fully before a line changes. Note each task, its acceptance criteria, and the
verifications it specifies. Then assess it critically: ambiguous tasks, unclear dependencies, an
unspecified branch, anything contradicting project conventions. Surface concerns NOW and resolve
every blocking one — do not guess through an ambiguity and find the mistake three tasks later.

Once settled, create a `TodoWrite` list of every task. That list is the execution ledger.

## Safety guard

If the current branch is `main` or `master`, stop. Name the branch and get explicit consent
before any implementation. Never execute a plan on a protected branch without the user saying so.

## Mechanical state flip

The instant task 1 begins, flip the plan's frontmatter `status: approved → executing`. This is
one of the two transitions that fires without a fresh approval question — it is a consequence of
the plan approval already earned, not a new decision.

## Execution engine — soft coupling to `claudestacks:orchestrate`

Drive each task through `claudestacks:orchestrate`: it runs the coder → reviewer pipeline,
handles the fix loop, and holds a per-task commit gate. Hand it one scoped task; it returns a
reviewed result.

If it does not resolve — the `claudestacks` main plugin is not installed — degrade to **guided
inline execution** on the main thread, applying the same discipline the plan specifies (test
first, confirm it fails, implement, run every verification the plan names). Tell the user the
agent pipeline was unavailable. Never fail hard for want of the main plugin.

## Per-task loop

For each task in the ledger, in order:

1. Mark it `in_progress`.
2. Drive the implementation through `claudestacks:orchestrate` (or inline), giving it the task
   description, acceptance criteria, and named verifications.
3. Run every verification the plan specifies for this task. A task is complete only when its
   named verification ran and its output is shown — not merely described.
4. Pause and surface the result: which files changed and what behavior, each verification's
   outcome with evidence, and — when driven through orchestrate — the reviewer's own report, not
   a summary of it.
5. Only once it passes review and verification, mark it `completed`.

A task that fails verification is not complete; do not start the next one. Where the plan
designates checkpoint boundaries ("pause for review after tasks 1–3"), treat them as hard stops:
present the whole batch and wait for "continue".

## When to stop and ask

Stop immediately when a dependency is missing or ambiguous, a verification fails repeatedly in a
way the plan does not explain, the plan has a gap where guessing would be risky, or an
unexpected conflict appears (naming collision, changed API, a test suite in a state the plan did
not anticipate).

Ask the one focused question that unblocks you — not every concern at once.

## Completion

Present the whole run: what was built task by task, the verifications and their evidence, the
full reviewer report (or inline evidence, on the degraded path), and any deviation from the plan
and how it was resolved.

Before flipping the plan to `done`, append two sections directly to the plan file, in this
order:

1. **`## Review findings`.** One line per finding from the reviewer's Important findings,
   formatted `category — description — where`. On the inline-degraded path (no independent
   reviewer ran), write `inline execution, no independent reviewer` plus anything the
   verifications themselves surfaced. This section is what keeps findings durable past the
   session — the `distill` skill reads it later, across chains, to catch the same mistake
   recurring.
2. **`## Deviations`.** A dated entry for every departure from the plan as written — what
   changed and why. Omit the section only if execution followed the plan exactly with zero
   deviations. This keeps plan-vs-diff review meaningful even when reality diverged from the
   plan.

Then wait. The user decides whether to commit, merge, or open a pull request. Do not auto-commit,
do not auto-merge, do not auto-push — the commit gate belongs to the user.

Only once the user accepts the completion report, flip the plan's frontmatter
`status: executing → done` — the second and last mechanical-adjacent flip, though this one still
waits on the user's acceptance of the report rather than firing automatically.

## State walk-up

After a plan flips to `done`, check the rest of the chain: if every plan in the chain is now
`done` or `superseded`, with at least one `done`, flip the chain's `intent.md`
`status: approved → done` and tell the user the chain is complete. This is the second
transition that fires without a fresh approval question — a consequence of state already earned
on the individual plans, not a new decision. If other plans remain `draft`, `approved`, or
`executing`, leave the intent as is and say what is still open.
