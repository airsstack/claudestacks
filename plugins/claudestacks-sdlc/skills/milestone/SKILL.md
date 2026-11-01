---
name: milestone
description: Use to work on one milestone of a roadmap — add, approve, amend, drop, un-drop, park scope, adopt or release a chain, or roll finished work up to done. Invoke with `<roadmap>/<NN>` or a roadmap name.
---

# Milestone

## The rule

A milestone is a goal in `roadmaps/<roadmap>/NN-<topic>.md`; member chains declare it with
`milestone: <roadmap>/<NN>` in their intent. This skill is the only place milestone status
changes by hand and, with `intent`, the only place that key is written. Milestones are optional.
A milestone records no progress; the board counts `N of M done`.

Paths, keys, transitions: `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`. Body shapes:
`${CLAUDE_PLUGIN_ROOT}/references/templates.md`. Never commit. Flip `status` only as the last step
of the interaction, on the user's explicit word (the roll-up is the one exception). Never delete or
rename under `roadmaps/`, never move a chain directory; joining or leaving edits one frontmatter key.

## Input

`<roadmap>/<NN>` resolves to one `.claudestacks/sdlc/roadmaps/<roadmap>/<NN>-*.md`. No match:
report the pattern, ask. Two matches: refuse (`INVALID (<file>: duplicate number NN)`). `add` and
`roll up` take a roadmap name (`roll up` also accepts a reference).

## Check before acting

Render the board and read the milestone's row and its roadmap's (no output: derive by hand as the
`status` skill does); repeat after every flip or membership change and tell the user:

    sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"

`INVALID (…)` on either row: refuse everything except `roll up`, naming file and reason. For
`INVALID (done with open chains)` the way out is removing `milestone` from each open member's
intent by hand (`release` refuses a `done` milestone). `⤷ roadmap <roadmap> is dropped — drop this
milestone`: say so and offer `drop`.

## Operations

| Operation | Does | Refused when |
|---|---|---|
| add | writes next `NN-<topic>.md`, `status: draft` | roadmap is `done` or `dropped` |
| approve | `draft → approved`, then roll-up | not `draft` |
| amend | rewrites `## Goal` or `## Non-goals`; status unchanged | `done` |
| drop | `→ dropped`, then roll-up | `done` or already `dropped` |
| un-drop | `dropped → draft` | not `dropped`; roadmap `done` |
| park scope | one `draft` intent per piece of work, with `milestone` key | `done` or `dropped` |
| adopt | adds `milestone` to an existing chain's intent | milestone `done`/`dropped`; chain already has the key; intent not `draft`/`approved` |
| release | removes `milestone` from a member's intent, then roll-up | `done` |
| roll up | runs the roll-up for the roadmap | never |

Every refusal names the file and status found. Moving a chain is `release` then `adopt`.

- **add.** Ask one at a time: title, goal (state of the world when reached), non-goals. Goal, never
  a date or estimate. Number = highest `NN` in the roadmap (any status) plus one; never reused.
- **approve, drop, un-drop** need the user's explicit word. Milestone status does not gate chain
  work.

## Parking scope

Ask for the pieces of work. For each, write a new chain directory `YYYY-MM-DD-<kebab-topic>`
(today's date); if it exists, ask for another topic.

````markdown
---
status: draft
created: <YYYY-MM-DD>
milestone: <roadmap>/<NN>
---

# Intent: <title>

## Problem

[what the user said about this piece of work]

## Affected systems

Not explored yet — parked by milestone <roadmap>/<NN>.

## Desired outcome

Not explored yet — parked by milestone <roadmap>/<NN>.

## Constraints

Not explored yet — parked by milestone <roadmap>/<NN>.

## Non-goals

Not explored yet — parked by milestone <roadmap>/<NN>.
````

The four sections hold that one sentence exactly, with the real reference. Do not explore or
approve; the user finishes it via `intent` amend.

## Membership

- At most one milestone per chain; release before adopting elsewhere.
- Adopt only a chain the user names; never infer from topic.
- `adopt` and `release` edit frontmatter only; neither makes a spec or plan stale.
- `⤷ milestone <roadmap>/<NN> is dropped — release this chain` is cleared by `release`.

## Roll-up

Follow the procedure in `artifact-chain.md`. It takes a roadmap, is idempotent, and flips without a
fresh approval question. Tell the user each thing it closed. Run it as the last step of `approve`,
`drop` and `release`, and when asked or the board's NEXT reads `roll up` (`milestone complete` /
`roadmap complete`).

## Closed is final

A `done` milestone is not reopened, amended, dropped or given work; `amend`, `drop`, `park scope`,
`adopt`, `release` refuse it. Say so; later work becomes a simple chain or a new milestone via `add`.
