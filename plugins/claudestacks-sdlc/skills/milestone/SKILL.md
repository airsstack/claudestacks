---
name: milestone
description: Use to work on one milestone of a roadmap — add it, approve, amend, drop or un-drop it, park its unstarted work as draft intents, adopt or release a chain, or roll finished milestones and their roadmap up to done. Invoke with a milestone reference such as platform/01, or with a roadmap name for add and roll up.
---

# Milestone

A milestone is a goal inside a roadmap, reached through chains. It is one file,
`roadmaps/<roadmap>/NN-<topic>.md`, stating the goal. The chains working toward it say so
in their own intent, with the frontmatter key `milestone: <roadmap>/<NN>`. This skill is
the only place a milestone's status changes by hand and, with `intent`, the only place
that key is written or removed.

Milestones are optional. A chain with no `milestone` key is a simple chain and needs
nothing from this skill.

A milestone never records progress: its file holds no list of chains, no count and no
checklist. The board counts `N of M done` from the member intents each time it runs.

## Shared contract

Resolve every path, key, state and transition from
`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`, and write files in the body shapes
`${CLAUDE_PLUGIN_ROOT}/references/templates.md` defines. Never commit. Flip `status` only
per the transitions in `artifact-chain.md`, only as the last step of the interaction that
earns it, only on the user's explicit word — the roll-up below is the one exception.
Nothing under `roadmaps/` is ever deleted or renamed, and no chain directory ever moves:
joining, leaving or switching milestones changes one frontmatter key and nothing else.

## Input

A milestone reference `<roadmap>/<NN>`, for example `platform/01`. It resolves to the one
file matching `.claudestacks/sdlc/roadmaps/<roadmap>/<NN>-*.md`.

- **No match** — report the pattern you looked for and ask for a correction. Never guess
  a neighbouring milestone.
- **Two matches** — refuse. Two files share a number, the board reads
  `INVALID (<file>: duplicate number NN)` for each, and the user fixes the files.

`add` and `roll up` take a roadmap name instead; `roll up` also accepts a milestone
reference and uses its roadmap.

## Check before acting

Render the board and read two rows — the milestone's, and its roadmap's:

    sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"

When that prints nothing, `airsl` is not installed: derive the rows by hand, the way the
`status` skill's fallback does. Do the same again after every `status` flip or
membership change this skill makes, and tell the user what the rows read then.

When either row reads `INVALID (…)`, refuse every operation except `roll up`: name the
file and the reason exactly as the board words them. The user fixes the file. The
exception is `INVALID (done with open chains)`: the milestone file is correct, and the way
out is removing the `milestone` key from each open member's intent by hand, as `release`
would. This skill does not reopen a `done` milestone, so `release` refuses it. A line
under the milestone's row reading `⤷ roadmap <roadmap> is dropped — drop this milestone`
means its roadmap was dropped while it stayed open: say so, and offer `drop`.

## Operations

| Operation | Does | Refused when |
|---|---|---|
| add | writes the next `NN-<topic>.md` in the roadmap, `status: draft` | the roadmap is `done` or `dropped` |
| approve | `draft → approved`, then the roll-up | the milestone is not `draft` |
| amend | rewrites `## Goal` or `## Non-goals`; the status stays as it was | the milestone is `done` |
| drop | `→ dropped`, then the roll-up | the milestone is `done` or already `dropped` |
| un-drop | `dropped → draft`; the user approves it again | the milestone is not `dropped`; the roadmap is `done` |
| park scope | writes one new chain per piece of work the user lists, each a `draft` intent carrying the `milestone` key | the milestone is `done` or `dropped` |
| adopt | adds the `milestone` key to an existing chain's intent | the milestone is `done` or `dropped`; the chain already has a `milestone` key; the chain's intent is not `draft` or `approved` |
| release | removes the `milestone` key from a member's intent, then the roll-up | the milestone is `done` |
| roll up | runs the roll-up for the roadmap | never |

Every refusal names the milestone's or the roadmap's file and the status it found.
Moving a chain from one milestone to another is a `release` followed by an `adopt`.

**add.** Ask, one question at a time, the milestone's title, its goal — the state of the
world when it is reached — and what it leaves out. A milestone states a goal, never a
date, a deadline or an estimate. The new file takes the next free number in the roadmap:
one more than the highest `NN` any file there carries, whatever that file's status. A
number is never reused.

**approve, drop, un-drop.** Each needs the user's explicit word. A milestone's status
does not gate chain work: a member chain moves through `design`, `plan` and `execute`
whatever its milestone's status.

## Parking scope

Work planned for a milestone and not yet begun is parked as a `draft` intent, so the
board counts it from the moment it is named and the milestone cannot read as finished
while it waits. Ask the user for the pieces of work, then for each one write a new chain
directory, named `YYYY-MM-DD-<kebab-topic>` with today's date as `artifact-chain.md`
prescribes, holding this `intent.md`:

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

The four parked sections hold that one sentence exactly, with the real reference in
place of `<roadmap>/<NN>`. Do not explore the problem here and do not approve the
intent: the user completes and approves it later through the `intent` skill's amend
mode. If a chain directory of that name already exists, ask for a different topic rather
than write into it.

## Membership

- A chain belongs to at most one milestone. `adopt` refuses a chain that already has
  the key; release it first.
- Membership is a recorded fact. Never adopt a chain because its topic or name looks
  related — only on the user naming the chain.
- `adopt` and `release` edit frontmatter only. A fingerprint covers an artifact's body,
  so neither marks a spec or a plan stale.
- A line under a chain's row reading
  `⤷ milestone <roadmap>/<NN> is dropped — release this chain` is cleared by `release`.

## Roll-up

The roll-up closes milestones, and then their roadmap, when their work is finished. Its
procedure is defined once, in `artifact-chain.md`; follow it there. It takes a roadmap,
it is idempotent — when nothing is ready it changes nothing — and it flips without a
fresh approval question, because each flip is a consequence of state already earned on
the chains. Tell the user each thing it closed.

Run it for the milestone's roadmap as the last step of `approve`, `drop` and `release`,
and whenever the user asks or the board's NEXT reads `roll up`. A milestone the board
shows as `milestone complete`, or a roadmap it shows as `roadmap complete`, is waiting
for exactly this.

## Closed is final

A `done` milestone is not reopened, amended, dropped or given new work: `amend`, `drop`,
`park scope`, `adopt` and `release` all refuse it. Say so plainly, and name the way
forward: work that arrives after a milestone closed becomes a simple chain, or belongs
to a new milestone added with `add`.
