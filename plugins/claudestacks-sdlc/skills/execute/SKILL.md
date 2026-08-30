---
name: execute
description: Use when a chain has an approved plan to carry out — drives it through parallel claudestacks coder/explorer/reviewer spawns with filesystem context handoff, proves each task's premises with throwaway tests before building on them, and walks chain states up on completion. Invoke by chain/plan reference (e.g. "execute 2026-08-24-webhook-reliability/01") once a plan is approved and before any of its code is written.
---

# Execute

Drive a written plan to a reviewed, presentable state. This skill does not design and does
not plan — those are the `design` and `plan` skills. It works with any plan in the chain's
documented on-disk format, whether written by `plan` or by hand.

You are the orchestrator. Agents are leaves: none of them can spawn another, so every
result routes through you, and the user's commit gate is never bypassed.

Paths, naming, frontmatter, and state transitions all come from
`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`; artifact body shapes come from
`${CLAUDE_PLUGIN_ROOT}/references/templates.md`.

## Input

A chain/plan reference, e.g. `2026-08-24-webhook-reliability/01`, resolving to
`.claudestacks/sdlc/2026-08-24-webhook-reliability/plans/01-<topic>.md`. Given a bare chain
name with no plan number, ask which plan, offering the chain's `approved` plans as choices.

## State gate

Read the plan's **frontmatter only** — not its body — before anything else:

- `status` other than `approved` — refuse. Name the file, its current state, and the
  command that advances it (`draft` → the `plan` skill's approval gate; `executing` → you
  are presumably resuming, so continue rather than refuse; `done` or `superseded` → the work
  already happened or was replaced, so a new round is a new plan).
- `depends-on` names a plan that is not yet `done` — warn and ask before proceeding. The
  dependency may be irrelevant to the tasks about to run, so this is the user's call, not an
  automatic block.

## Safety guard

If the current branch is `main` or `master`, stop. Name the branch and get explicit consent
before any implementation. Never execute a plan on a protected branch without the user
saying so.

## Load the plan through the briefer, not into your context

A plan is a construction manual, often tens of kilobytes of code blocks. Reading it whole
spends the main thread's context on material only the coder will ever type.

Spawn `claudestacks-sdlc:task-briefer` in `ledger` mode:

```
mode: ledger
plan: <chain>/plans/NN-<topic>.md
handoff: <session-dir>/01-task-briefer-ledger.md
```

It returns one row per task — number, title, files, verification commands — plus the goal,
`depends-on`, and any checkpoint boundaries the plan marks. That table is your execution
ledger; write it to `TodoWrite`, one item per task.

Read the plan file directly only for a passage you must personally judge — an ambiguity you
are about to raise with the user, or a step whose wording decides how you batch. Never read
it end to end.

If `task-briefer` does not resolve, build the ledger inline with
`grep -n '^### Task' <plan>` and read only the task headers. Tell the user the agent was
unavailable. Never fail hard for want of an agent.

Then assess the ledger critically: ambiguous tasks, unclear dependencies, an unspecified
branch, anything contradicting project conventions. Surface concerns NOW and resolve every
blocking one — do not guess through an ambiguity and find the mistake three tasks later.

## Mechanical state flip

The instant task 1 begins, flip the plan's frontmatter `status: approved → executing`. This
is one of the two transitions that fires without a fresh approval question — a consequence
of the plan approval already earned, not a new decision.

## Context handoff

Subagent detail stays on disk; only summaries reach you. The protocol — file schema, return
contract, retention — is the `claudestacks` plugin's
`skills/process-guidelines/references/context-handoff.md`. Drive it:

1. **Once, at the top of the run:** `handoff.lua init`. It prints the session dir and id,
   prunes stale sessions, and writes the `.active` lease. Keep both values.
2. **Per spawn:** assign `<NN>-<agent>-<slug>.md` under the session dir and pass that **full
   write-path** in the brief. Call `handoff.lua beat <session-dir>` so a long run is never
   pruned by a concurrent session.
3. **On return:** the agent gives you its `<summary>` plus the path. Route off the summary.
   Open the `<detail>` only when you personally must judge it.
4. **Downstream needs upstream detail:** pass the upstream `handoff:` path plus a targeted
   `need:` pointer. The next agent reads its own slice; the detail never transits you.
5. **At close:** `handoff.lua end <session-dir>`.

This run holds several agents in flight at once, so it uses the session tree — the
single-subagent exception in that reference does not apply here.

## The agents

| Agent | Use for |
|---|---|
| `claudestacks-sdlc:task-briefer` | the ledger, and each task's verbatim brief |
| `claudestacks:explorer` | locating — where a symbol lives, what calls it, mapping a tree |
| `claudestacks:coder` | implementing one task, test-first, to the stack's Definition of Done |
| `claudestacks:reviewer` | one combined report: re-runs the DoD, reviews the diff, checks it against the plan |

If any does not resolve, degrade to inline work on the main thread under the same
discipline, and say which agent was unavailable.

## Batch the ledger, then run each batch in parallel

Sequential-by-default wastes the plan's own structure: a plan that touches four disjoint
files in four tasks can build all four at once.

Walk the ledger and cut it into batches. A run of consecutive tasks belongs in one batch
when **both** hold:

- their file sets are pairwise disjoint — no two tasks in the batch write the same path; and
- no task in the batch names a type, function, constant, or module that another task in the
  same batch creates.

The ledger gives you the file sets directly. For the second test, the briefs' **Asserted
facts** lists give you the named symbols; where the ledger alone cannot settle it, spawn
`claudestacks:explorer` once over the batch's symbols and let its `file:line` table answer
whether each already exists.

Anything failing either test starts a new batch. A checkpoint boundary the plan marks always
ends a batch. A batch of one is normal and fine — most plans are genuinely sequential
because task N+1 uses what task N defined.

Within a batch, spawn one `coder` per task, all in a single message so they run
concurrently. Each gets its own handoff file. Never give two concurrent coders the same
file.

## Per-batch loop

For each batch, in order:

1. Mark its tasks `in_progress`.

2. **Brief.** Spawn `task-briefer` in `brief` mode, once per task in the batch, in one
   message:

   ```
   mode: brief
   plan: <chain>/plans/NN-<topic>.md
   task: <N>
   handoff: <session-dir>/<NN>-task-briefer-task<N>.md
   ```

   You get back each task's files, verifications, and Asserted facts. You do not get the
   code blocks, and you do not need them.

3. **Prove what the task assumes.** See below. Do this before the coder builds on it, not
   after.

4. **Implement.** Spawn one `coder` per task, concurrently. Each brief carries:
   - `handoff: <session-dir>/<NN>-coder-<slug>.md` — its own report path;
   - `need: <the task-briefer handoff path>` — it reads its task's verbatim `<detail>`
     itself, and builds from that text, not from your paraphrase;
   - the stack guideline to load (e.g. `claudestacks-guideline-rust:rust-guidelines`) and
     the instruction that its architecture rules bind, not only its Definition of Done;
   - the exact verification commands the plan names for that task;
   - the results of step 3, where a probe changed what the task should do.

5. **Verify.** Run the verifications the plan names for this batch, and the stack's
   Definition of Done once for the batch. Show the output. A task is complete only when its
   named verification ran and its output is shown — not merely described.

6. **Review — once.** One `reviewer` spawn over the batch's whole diff, with the plan path
   as the intent authority. See the review budget below.

7. **Present and mark complete.** Surface: files changed and the behaviour they change, each
   verification's outcome with its evidence, and the reviewer's own report — not your summary
   of it. Only then mark the tasks `completed`.

A task that fails verification is not complete; do not start the next batch. Where the plan
marks a checkpoint, that is a hard stop: present the batch and wait for "continue".

## Prove what the task assumes, with a throwaway test

Every fact a task asserts about something it does not create is a place the plan can be
wrong, and the plan is not evidence for itself. The `task-briefer` hands you that list —
work it before the coder starts.

Sort each asserted fact into one of three:

| Kind | What settles it |
|---|---|
| **The task creates it** | nothing to prove — it does not exist yet by design. |
| **Structural — a symbol, path, or signature the task says already exists** | one `explorer` spawn over the whole batch's symbols, returning `file:line` or NOT FOUND. Cheap; batch them. |
| **Behavioural, or a fact about an outside system** | a **throwaway test you actually run**. Write the smallest probe that would come out differently if the claim were false, run it, keep the real output, delete the probe. |

Reading the source is not proof of behaviour. Neither is the plan saying so, nor the spec it
came from, nor your own recollection — those are precisely the paths that put the wrong fact
there. Run it.

For a claim about a documented external system, the artifact is the authority: fetch the raw
source to a local file and grep it —
`curl -sS -L '<doc-url>.md' -o "$TMPDIR/<name>.md"` — never through a summarizing fetch
tool, which truncates a long page and hands the remainder to a small model that emits
plausible invented content instead of an error.

**Where the plan's own red-green cycle already proves the claim, that IS the probe — do not
write a second one.** A task whose step 2 says "run it and confirm this exact failure" has
its probe built in; the coder running that step settles it. Only claims the plan never puts
under a test of its own need one of yours. Probes are for the load-bearing and unproven, not
for every literal in the file.

## Verification budget — do not over-verify

Run each verification exactly once, at the point it is meaningful, and then trust it:

- The stack's Definition of Done runs **once per batch**, not once per task. A green gate is
  not re-run to confirm it is still green.
- A file you just wrote through `Edit` or `Write` is not read back to confirm the write
  landed — the tool would have failed.
- The reviewer re-runs the DoD as its independent check. That is the one deliberate
  duplication in the flow, and it replaces any auditing pass of your own over the coder's
  receipt. Do not add a third run.
- Scope the gate to the touched crate or package while a plan is mid-flight; run the
  workspace-wide form once, at completion.

A verification that cannot change what you do next is not a verification. Skip it.

## Review budget — do not over-review

**One `reviewer` spawn per batch. One fix round. Then you are done.**

- Route the reviewer's findings to a **fresh** `coder` spawn — the reviewer never edits and
  never calls the coder.
- After that fix round, re-run only the specific verification the fix touches. **Do not
  re-spawn the reviewer over the fixed diff.**
- If the fix round leaves something genuinely unresolved, that is an escalation to the user,
  not a second review. Say what is unresolved and ask.

Rounds beyond the first return progressively smaller findings about code the compiler has
already accepted, while the defects that actually matter are wrong premises — which no
review round can catch, because a reviewer checks the diff against the plan and a wrong plan
is exactly what it will confirm. The probe step above is what replaces the extra rounds.

## When execution disproves the plan or the spec

Execution is the first time a plan's claims meet the artifact they describe, so this is where
a wrong premise surfaces. When a probe comes back against the plan, the code fix is only half
the work — the other half is that the chain now lies to whoever executes the next plan.

Stop and put it to the author as **its own question**: *the plan's premise is disproven —
amend the plan and the spec now, or after this run?* Do not fold it into a question about the
implementation and read the answer as covering both. Approving a code change is not approving
the record.

Sibling plans were written against the old text and cannot see the commit that corrected it.
A commit body is not where the next plan's author looks. Amending a `draft` plan is the `plan`
skill's; superseding an approved `spec.md` is the `design` skill's, and the author authorizes
it.

## When to stop and ask

Stop immediately when a dependency is missing or ambiguous, a verification fails repeatedly
in a way the plan does not explain, the plan has a gap where guessing would be risky, or an
unexpected conflict appears — a naming collision, a changed API, a test suite in a state the
plan did not anticipate.

Ask the one focused question that unblocks you, not every concern at once.

## Completion

Present the whole run: what was built batch by batch, the verifications and their evidence,
the reviewer reports, every probe whose result contradicted the plan, and any deviation from
the plan and how it was resolved.

Before flipping the plan to `done`, append three sections to the plan file, in this order:

1. **`## Review findings`** — one line per reviewer finding, `category — description —
   where`. On the inline-degraded path, write `inline execution, no independent reviewer`
   plus anything the verifications surfaced. This is what keeps findings durable past the
   session; `distill` reads it later, across chains, to catch a mistake recurring.
2. **`## Probe results`** — one line per throwaway test that was run: the claim, the command,
   and the real output, at full precision. Mark any that came out against the plan. This is
   the record that a premise was checked rather than assumed, and it is what a later reader
   needs to know which claims are still only plausible.
3. **`## Deviations`** — a dated entry for every departure from the plan as written, what
   changed and why. Omit only if execution followed the plan exactly.

Then wait. The user decides whether to commit, merge, or open a pull request. Do not
auto-commit, do not auto-merge, do not auto-push — the commit gate belongs to the user, and
no agent in this flow runs `git commit` either.

Only once the user accepts the completion report, flip the plan's frontmatter
`status: executing → done`.

## State walk-up

After a plan flips to `done`, check the rest of the chain. If every plan is now `done` or
`superseded`, with at least one `done`, flip the chain's `intent.md`
`status: approved → done` and tell the user the chain is complete — the second transition
that fires without a fresh approval question, a consequence of state already earned on the
individual plans. If other plans remain `draft`, `approved`, or `executing`, leave the intent
as is and say what is still open.
