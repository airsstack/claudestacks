# Artifact Templates — body shapes for intent, spec, plan, roadmap, milestone, and ADR

The body-shape authority for the `claudestacks-sdlc` skills. When `intent`, `design`,
`plan`, `roadmap`, `milestone`, or `adr` writes a new artifact, it reproduces the shape
shown here: frontmatter plus the body sections below it. Bracketed text is guidance for
the writing skill, not content to leave in the file.

## `intent.md`

````markdown
---
status: draft                    # per-artifact state
created: <YYYY-MM-DD>
derived-from-prd:                # optional — see artifact-chain §6
  - prds/<file>.md
derived-from-rfc:                # optional — see artifact-chain §6
  - rfcs/<file>.md
source: triage                   # optional — see artifact-chain §6
spec: skipped                    # optional — see artifact-chain §6
milestone: <roadmap>/<NN>        # optional — see artifact-chain §11
---

# Intent: <title>

## Problem

[what's broken or missing, and why it matters now — in the user's language, not a
solution]

## Affected systems

[the code, plugins, or repos this problem touches]

## Desired outcome

[the target state once this is solved]

## Constraints

[hard limits on the solution space — technical, scope, or process]

## Non-goals

[explicitly out of scope, so the next stage doesn't drift into it]
````

A triage-sourced intent (`source: triage` in frontmatter) adds one more section after
`## Non-goals`: `## Evidence`, holding the pasted evidence — exact error text, exact
commands — at full precision.

## `spec.md`

````markdown
---
status: draft
created: <YYYY-MM-DD>
built-on: <fingerprint>          # of intent.md — see artifact-chain §10
---

# Spec: <title>

[one paragraph: what this spec delivers and why, no design detail yet]

## 1. <section title>

[as many numbered `##` sections as the design needs — one per concern: design
premises, data model, component structure, error handling, testing, rollout, whatever
the shape of the thing calls for. Every sentence that asserts behaviour or an external
fact carries its recorded probe run or citation beside it]

## 2. <section title>

[...]

## N. Non-goals

[explicitly out-of-scope items — present in every spec]
````

Provenance keys per `artifact-chain.md` §6 may also appear in a spec's frontmatter.

## `plans/NN-<topic>.md`

````markdown
---
status: draft
created: <YYYY-MM-DD>
depends-on: [01]                 # optional — see artifact-chain §6
built-on: <fingerprint>          # of the plan's authority — see artifact-chain §10
---

# <name> Implementation Plan

**Goal:** [one sentence, no "and" — a goal needing "and" splits the plan]

**Architecture:** [key structural decisions and how the pieces fit together]

**Tech Stack:** [languages, frameworks, and tools this plan touches]

**Content authority:** [optional: the spec section(s) this plan implements, cited by
number; on the spec-skip path, cite the approved intent instead — omit the whole line
when the goal statement already names the authority]

---

## Files that change

```
<path>   — [create|modify] <one-line description>
<path>   — [create|modify] <one-line description>
```

## Order of work

### Task 1 — <imperative title>

**Files:** [omit this line entirely for a task with no file changes of its own]
- Create/Modify/Test <path> — <what changes in it>

**Change:** [the behaviour this task adds or changes, in prose; types or functions it
introduces by name and one-line purpose]

**Proof:** [each test by name, and what it asserts, in prose — written first by `execute`]
- `<test name>` — <what it asserts>

**Done when:** `<command>` passes and the stack's Definition of Done is green. Commit
`<conventional commit subject>`.

### Task N — <imperative title>

[same shape, repeated per task]

---

## Risks

- [what the change could break, which step is most risky, and options not taken — never an
  unproven premise for `execute` to settle; that goes back to the spec]

## Proof

- [the plan-wide checks that prove every task's work holds together]
````

A plan carries no implementation or test code: no function bodies, no test bodies, no
diff. A command the implementer runs is fine. The shape follows the `plan.md` in Anthropic's
AI-native SDLC playbook — files that change, order of work, risks, proof — and `execute`
writes the code.

Provenance keys per `artifact-chain.md` §6 may also appear in a plan's frontmatter.

Once `execute` runs this plan, it appends three more sections directly to the file, in
this order — `## Review findings` (durable reviewer output), `## Probe results` (each
throwaway test run to prove a claim the task asserted but did not create: the claim, the
command, its real output, and whether it came out against the plan), and `## Deviations`
(departures from the plan) — before flipping it `done`. None is authored by the `plan`
skill; all three are appended by `execute`.

## `roadmaps/<roadmap>/roadmap.md`

````markdown
---
status: draft
created: <YYYY-MM-DD>
---

# Roadmap: <title>

## Vision

[where this body of work is going and why]

## Non-goals

[what this roadmap deliberately leaves out]
````

## `roadmaps/<roadmap>/NN-<topic>.md`

````markdown
---
status: draft
created: <YYYY-MM-DD>
---

# Milestone: <title>

## Goal

[the state of the world when this milestone is reached]

## Non-goals

[what this milestone deliberately leaves out]
````

Both carry `status` and `created` and no other frontmatter key. Neither body lists
milestones, chains, progress or finished work: `artifact-chain.md` §11 says where
those come from.

## `adrs/NNNN-<topic>.md`

````markdown
---
status: draft
created: <YYYY-MM-DD>
supersedes: [0003]               # optional — the ADRs this one replaces
---

# ADR <NNNN>: <title>

## Context

[the forces at play and why a decision is needed now]

## Options considered

[at least two real options, each with its trade-offs]

## Decision

[what was decided]

## Consequences

[what follows from the decision, the costs included]
````

`sealed` is written by the `adr` skill at approval and never by hand. The body is never
edited after approval (`artifact-chain.md` §13.2).

## A parked intent

Work planned for a milestone and not yet begun is parked by the `milestone` skill as an
ordinary `intent.md` with `status: draft` and the `milestone` key. `Problem` holds what
the author said about that piece of work. `Affected systems`, `Desired outcome`,
`Constraints` and `Non-goals` each hold exactly this sentence:

```
Not explored yet — parked by milestone <roadmap>/<NN>.
```

The author completes it later through the `intent` skill's amend mode.

---

`references/artifact-chain.md` owns paths, naming, frontmatter key semantics, and the
state machine; this file owns body shapes — change one, check the other.
