# Artifact Templates — body shapes for intent, spec, and plan

The body-shape authority for the `claudestacks-sdlc` skills. When `intent`, `design`,
or `plan` writes a new artifact, it reproduces the shape shown here: frontmatter plus
the body sections below it. Bracketed text is guidance for the writing skill, not
content to leave in the file.

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
---

# Spec: <title>

[one paragraph: what this spec delivers and why, no design detail yet]

## 1. <section title>

[as many numbered `##` sections as the design needs — one per concern: design
premises, data model, component structure, error handling, testing, rollout, whatever
the shape of the thing calls for]

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
---

# <name> Implementation Plan

**Goal:** [one sentence, no "and" — a goal needing "and" splits the plan]

**Architecture:** [key structural decisions and how the pieces fit together]

**Tech Stack:** [languages, frameworks, and tools this plan touches]

**Content authority:** [optional: the spec section(s) this plan implements, cited by
number; on the spec-skip path, cite the approved intent instead — omit the whole line
when the goal statement already names the authority]

---

## File structure

```
<path>   — [create|modify] <one-line description>
<path>   — [create|modify] <one-line description>
```

[optional: one paragraph naming a verification approach repeated at every task, e.g. a
single command invoked the same way throughout]

### Task 1 — <imperative title>

**Files:** [omit this line entirely for a task with no file changes of its own, e.g. a
closing commit task]
- Create/Modify <path>

**Steps:**

1. [a concrete step — failing test, code, or command]
2. [...]
3. Verify:
   ```
   $ <command>
   ```
   Expected: [what confirms this step worked]

### Task N — <imperative title>

[same shape, repeated per task]

---

## Verification summary (plan-level)

- [the plan-wide checks that prove every task's work holds together]
````

Provenance keys per `artifact-chain.md` §6 may also appear in a plan's frontmatter.

Once `execute` runs this plan, it appends two more sections directly to the file —
`## Review findings` (durable reviewer output) and `## Deviations` (departures from the
plan) — before flipping it `done`. Neither is authored by the `plan` skill; both are
appended by `execute`.

---

`references/artifact-chain.md` owns paths, naming, frontmatter key semantics, and the
state machine; this file owns body shapes — change one, check the other.
