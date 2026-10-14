---
name: plan
description: Use when a chain's spec is approved (or its intent carries spec: skipped) and implementation plans are needed — decomposes the objective into plans naming the files that change, the order of the work, the risks, and the tests that prove it, without writing any code; derives the plan fan-out and dependencies from the spec without asking, writes them to the chain's plans directory, and asks once for the whole set to be accepted. Invoke once a spec is approved (or skipped) and before any code is written.
---

# Plan

Turn an approved spec (or a spec-skipped intent) into one or more implementation plans, in the
shape of the `plan.md` from Anthropic's AI-native SDLC playbook (Stage 3, the plan mode play):
**the files that change, the order of the work, the risks, and the tests that prove it.**

A plan stands alone. Iterate until an engineer who has never seen the conversation could
implement the change from the plan alone — whoever picks it up may not know the codebase, may
not have read the spec, and shares no context with you.

## Hard gate — a plan carries no code

This stage is plan mode: read the codebase, change nothing. The playbook puts design review
"before any code is generated, when changing course is still a matter of editing a document",
and implementation starts only once the plan is accepted. Writing the code here means
`execute` writes it a second time.

So, in this skill:

- **Write no implementation code and no test code** — not in the plan, not in a scratch file,
  not as a prototype to check the plan works. No function bodies, no test bodies, no diff.
  `execute`'s coder writes the tests and the implementation, test-first.
- **Run nothing that builds or exercises new code.** Reading files, `grep`, `git log`, a
  binary's `--help`, and fetching documentation to a local file are the whole toolset.
- **Name, don't write.** A task names the files, the types or functions it introduces (by
  name and one-line purpose; their shape belongs to the spec), the behaviour that changes,
  and each test by name with what it asserts in prose.

A question that only running new code could answer is a risk, not a reason to prototype:
write it under the plan's `## Risks` and let `execute` settle it with a probe.

Three principles bind the content:

- **Test-first, named here, written in `execute`.** Every behavioural change has its proving
  tests named in the task that makes it — what each asserts, and the command that runs them.
  The coder writes them first, watches them fail, then writes the code.
- **Honor the active stack's guidelines.** Detect the stack from repo markers (`Cargo.toml` →
  Rust) and load the matching guideline skill (`claudestacks-guideline-rust:rust-guidelines`).
  Every file placement, module boundary, and named interface must already conform to its
  architecture rules, and each task's done-check must include its Definition of Done.
- **DRY / YAGNI.** No abstraction the objective does not require.

Paths, naming, frontmatter, and state transitions all come from
`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`; artifact body shapes come from
`${CLAUDE_PLUGIN_ROOT}/references/templates.md`. Lazy-create the chain's `plans/` directory
before first write — never assume `/claudestacks-sdlc:setup` ran.

## State gate

This skill requires one of:

- a chain whose `spec.md` is `status: approved`; or
- a chain with no `spec.md`, whose `intent.md` is `status: approved` and carries
  `spec: skipped` in its frontmatter.

Anything else is refused, naming the file, its current state, and the command that advances it:

- `spec.md` is `draft` — refuse; the `design` skill's review gate is what flips it to
  `approved`.
- no `spec.md` and the intent has no `spec: skipped` flag — refuse; either the `design` skill
  runs first, or the user sets the skip flag by re-invoking the `intent` skill.
- `intent.md` is not `approved` — refuse; the `intent` skill is what advances it.

This skill never sets `spec: skipped` itself — it only reads the flag.

## Sync check

Before acting, render the board and read this chain's row:

    sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"

When that prints nothing, `airsl` is not installed: derive the row by hand, the way the
`status` skill's fallback does. Do the same again after every `status` flip this skill
makes, and tell the user what the row reads then.

The row's wording comes from the sync rules in
`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`. A plan's **authority** is the
chain's `spec.md`, or the chain's `intent.md` when the intent carries `spec: skipped`
and no `spec.md` exists.

Refuse — naming the file, the condition exactly as the board words it, and what clears
it — when the row reads any of:

| The row reads | Cleared by |
|---|---|
| `spec stale (intent changed)` | the `design` skill |
| `spec disproven by plan NN` | the `design` skill |
| `intent disproven by plan NN` | the `intent` skill |
| `plan NN <status>: blocked (spec not approved)` | the `design` skill |
| `INVALID (spec.md: missing built-on)` | the `design` skill |
| any other `INVALID (…)`, except `INVALID (plans/NN: missing built-on)` | the user, in the file the row names |

Two conditions are this skill's own to clear. When the row reads
`plan NN <status>: stale (spec changed)`, `plan NN <status>: stale (intent changed)`, or
`INVALID (plans/NN: missing built-on)`, take each such plan in number order and offer
the user two ways out:

- **Re-confirm it.** Ask one question: *does plan `NN` still hold against its authority
  as that authority now reads?* On an explicit yes, compute the authority's current
  fingerprint,

      sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <authority file>

  write the 12 characters it prints as `built-on` in that plan's frontmatter, and
  change nothing else in the file. The plan keeps its status.
- **Supersede it.** Flip it `superseded` and write its replacement under the next free
  `NN` (Lifecycle, below).

Re-confirmation is never inferred, and one plan's yes does not cover another. After
clearing a condition, render the board again: an `INVALID` result replaces the whole
row, so another condition may have been standing behind it.

## No dialogue — the questions were answered upstream

By the time this skill runs, the intent and the spec have been discussed and approved, open
questions included. Planning asks the author nothing more. The plan set, its dependency
shape, the order of work and the risks are all derived from the spec, the repo and the
loaded guideline, and the author sees them once, at the acceptance gate below.

The one exception is a spec that cannot be planned as written: it contradicts the artifact
(see *Re-verify*, below), or it leaves open something a plan must decide — which file owns a
behaviour, where a boundary falls, which of two readings it means. That is a defect in the
spec, not a planning question. Do not resolve it as an assumption, and do not ask the author
to settle it here. Stop before writing any plan, name the gap in one line, and send it back to
the `design` skill, which owns the spec.

## Fan-out is first-class

A spec usually yields several plans, not one. Derive the plan set and its dependency shape
yourself and write it; do not propose it first. Mark a checkpoint inside a plan only where
the spec asks for one — `execute` treats each as a hard stop, so a checkpoint nobody asked for
is a question in disguise.

Plans live at `plans/NN-<kebab-topic>.md` inside the chain directory — the `NN` prefix orders
plans within the chain, and sibling plans are disambiguated by topic, not renumbering. Each
plan's frontmatter carries `status`, `created`, `built-on`, and `depends-on` (a list of plan
numbers this plan needs `done` first; absent or empty means independent — visibly
parallelizable across worktrees).

`built-on` is the fingerprint of the plan's authority (Sync check, above)
as it reads when the plan is written. Run

    sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <authority file>

and write the 12 characters it prints into every plan of the set. If it prints nothing, the
authority has no fingerprint: stop and name the file rather than write a plan against it.

## Scope check — one objective per plan

Each individual plan covers **exactly one objective**: one outcome stateable in a single
sentence without an "and". If a plan's goal sentence needs an "and", split it into sibling
plans. Tasks are not objectives — three tasks implementing parts of one feature belong in one
plan.

## Re-verify the spec's external claims before they become code

A plan turns the spec's prose into the facts a test will assert — values, exhaustive lists, field
names — the exact forms that are painful to correct once written. **This is the last gate before
someone writes code, and the spec is not a trustworthy source for facts about outside systems.**
Checking a fact means reading the artifact, never building code to see what happens.

Before writing a task that encodes such a fact, check it against the artifact — not against the spec
that supplied it. Fetch documentation as raw source into a local file and grep it (`curl -sS -L
'<doc-url>.md' -o "${TMPDIR:-/tmp}/<name>.md"`); never through a summarizing fetch tool, which
truncates long pages and invents plausible content past the cutoff. Prefer the shipped artifact —
type declarations, the binary's `--help` — over documentation about it.

Every count, exhaustive list, field name, and negative existence claim that reaches a task carries a
citation to what you read: `<file>:<line>`. **Check exhaustive lists for completeness, not just for
correctness** — a list where every entry is right but three entries are missing reads as verified and
is not. Where a fact already lives in a type the plan is building, have the task read it from there
rather than restating it; a second copy in a task is a copy that drifts.

When the artifact contradicts the spec, do not quietly plan around it. Stop, tell the author which
claim failed and what the artifact says, and fix the spec — a plan that faithfully implements a wrong
spec still produces wrong code, and the sibling plans are still quoting the same wrong text.

## File structure first

Before defining tasks, map the file changes, one sentence of responsibility each. Prefer a new
focused file over expanding an existing one.

```
src/auth/token.rs          — [create] token validation logic and unit tests
src/auth/mod.rs            — [modify] re-export the new token module
tests/auth_integration.rs  — [create] integration test for the token round-trip
```

Then assign each file to exactly the tasks that touch it. A task listing files it does not
touch is a defect; a file in no task is a dangling artefact.

Delegate the locating. Working out which files exist, what they export, and which one
owns the behavior the spec describes is exactly `claudestacks:explorer`'s job — spawn it
and build the file map from the `file:line` tables it returns, rather than reading the
tree into this thread. Deciding what *should* change stays here; the agent only reports
what is there, and refuses judgment if you ask for more. If `claudestacks:explorer` does
not resolve — the `claudestacks` main plugin is not installed — map the files inline here
and tell the user the agent was unavailable. Never fail hard for want of the main plugin.

## Order of work — task granularity

The tasks are the plan's order of work. Each is one step of it — doable, testable, and
committable in one sitting, ending in a commit. A task too large to prove with a handful of
named tests is too coarse; break it down.

## Header template

Frontmatter and header follow the body shape in
`${CLAUDE_PLUGIN_ROOT}/references/templates.md`:

```markdown
---
status: draft
created: <YYYY-MM-DD>
depends-on: [01]                 # optional
built-on: <fingerprint>          # the authority's fingerprint when written
---

# [Feature Name] Implementation Plan

**Goal:** [one sentence — no "and" joining two distinct objectives]

**Architecture:** [2-3 sentences on the structural decisions this plan makes]

**Tech Stack:** [key technologies, libraries, frameworks]

---
```

The Goal line is the scope guard. If you cannot write it without "and", stop and split.

## Task template

Each task names its files, the change in behaviour, and the proof. Substitute your actual
language and names:

````markdown
### Task N — [Short imperative title]

**Files:**
- Create `src/math/add.py` — integer addition
- Modify `src/math/__init__.py` — export `add`
- Test `tests/test_add.py`

**Change:** add `add(a, b)`, returning the sum of two integers, exported from `src.math`.

**Proof:** written first, seen failing, then passing —
- `test_add_two_positive_integers` — `add(2, 3)` is `5`
- `test_add_negative_and_positive` — `add(-2, 3)` is `1`

**Done when:** `pytest tests/test_add.py` passes and the stack's Definition of Done is green.
Commit `feat(math): add integer addition function`.
````

No code block in a task holds implementation or test code. A command line the implementer
runs is fine; a function body is not. Where two tasks touch the same structure, say so in
both — a plan that says only "similar to Task N" is no longer standalone.

After the last task, the plan closes with the playbook's two plan-wide sections:

- **`## Risks`** — what the change could break, which step is most risky, what the plan
  chose not to do, and any question only running code can settle (for `execute` to probe).
- **`## Proof`** — the plan-wide checks that show every task's work holds together.

## Before saving — review by an agent

You wrote these plans, so you are the weakest available reader of them. Spawn
`claudestacks-sdlc:artifact-reviewer` over the whole draft set:

```
kind: plan-set
draft: <chain>/plans/NN-*.md      — every draft plan in the set
authority: <chain>/spec.md        — or <chain>/intent.md on the spec-skip path
handoff: <TMPDIR>/claudestacks-sdlc-<chain>-plan-set-<NN>.md
handoff-protocol: <the path /claudestacks:context-handoff gave you>
```

Invoke `/claudestacks:context-handoff` for the tier rules and the protocol path. This flow
spawns exactly one subagent, so it takes a literal temp path and mints no session. Expand
`${TMPDIR:-/tmp}` yourself before the path enters the brief. The report is always `01`.

**Exactly one review round over the set. Never a second.** Fix the findings and take the
plans to the author. Do not re-spawn the reviewer over the revised set, and do not spawn
it again when the author asks for changes — revise and present.

Rounds beyond the first return progressively smaller findings about the plan's internal
reasoning, while the defects that actually reach code are wrong external facts. No round
can catch those, because every criterion but the grounding ones compares documents to each
other — grounding against the artifact is what replaces them. A plan set that would need a
second round needs rewriting, not re-reviewing.

One spawn for the set, never one per plan. Spec coverage is a property of the *set*: a
requirement satisfied in plan `03` is covered even though plan `01` says nothing about
it, and a reviewer shown one plan at a time cannot see that. The acceptance gate below
takes the set the same way: once, as a whole.

The agent returns a verdict summary plus that path. Route off the summary; read the
`<detail>` only when you must act on a finding. Fix every finding in the drafts
yourself. The agent never edits a plan, never flips a `status`, and never commits.

**Every finding gets a disposition, and the author sees it.** Not only the blocking ones.
Build a table as you work the report — one row per finding, at every tier, naming which
plan it lands in:

| # | Plan | Tier | Finding | Disposition |
|---|---|---|---|---|
| 1 | 03 | 🔴 | <one line> | applied |
| 2 | 02 | 🟡 | <one line> | declined — <reason> |

Carry it to the approval gate below. A finding you decided not to act on is the author's
call to confirm, not yours to make silently — `artifact-review.md` assigns completeness to
the reviewer and the decision to this skill *and the user*.

Work the tiers in order but do not stop at the end of 🔴. The risk tier is where a dropped
finding hides: nothing about the plan looks unfinished afterwards, and a plan whose only
findings were non-blocking never gets reopened at all. Check the file mtimes against the
report's if you are unsure whether a plan was revisited after the review — a plan older
than the report that reviewed it was not.

The criteria it applies live in `${CLAUDE_PLUGIN_ROOT}/references/artifact-review.md`
§ *Reviewing a draft plan set*: spec coverage, type consistency, guideline conformance,
the two that ground the set's claims outside it, no implementation code, and the
no-placeholder list. Hold yourself to that no-placeholder list while drafting
rather than waiting for the agent to find them — a plan that reaches the reviewer full
of `TBD` has wasted the spawn. If the agent does not resolve, or returns nothing you can
act on, apply that same file's criteria inline yourself and tell the user the review ran
inline; never skip the review for want of the agent.

## Acceptance gate — one question for the whole set

This is the only question this skill asks. Present the set in one message: each plan's path
and Goal line, its `depends-on`, and the whole disposition table, declined rows included. An
acceptance given without sight of them is not an acceptance of them. Then ask once: *accept
the plan set?*

Before you ask, compute the authority's fingerprint again and compare it with the plans'
`built-on`. If they differ, the authority changed while the set was a draft: say so, and the
question becomes whether the set still holds against the authority as it now reads.

On an explicit yes, flip every plan in the set `status: draft → approved` and write the
authority's current fingerprint as each plan's `built-on`, in the same edit per file, as the
last step of this interaction. If the author asks for changes instead, revise and present the
set again — still one question, not one per plan. Then render the board again (Sync check) and
tell the user what the chain's row reads.

## Lifecycle

Plans are never deleted. A superseded plan keeps its original file and `NN-<topic>.md` name and
flips `status: superseded` in its frontmatter; a replacement plan does not reuse that number — it
takes the next free `NN` in the chain. Nothing is ever removed from the chain: git history plus
the `status` field is the complete record.

## Execution handoff

Recommend committing approved plans before execution starts, so a worktree picking up a plan
reads it from git rather than an uncommitted working tree — committing remains the user's act.
The `execute` skill is the next step once a plan is `approved`.
