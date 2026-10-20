---
name: adr
description: Use to record or change an architecture decision — write a new ADR, approve a draft, supersede or deprecate an approved one, amend a draft, drop or un-drop it, or finish a supersede the board shows half done. Invoke with an ADR number such as 0003 or 3, or with new for a fresh record.
---

# ADR

An architecture decision record states one decision, why it was made and what it costs. It
is one file, `.claudestacks/sdlc/adrs/NNNN-<topic>.md`, in a series shared by the whole
repository. A chain cites the ADRs its design relies on in its spec's `adrs` key. This
skill is the only place an ADR is written or its status changes.

ADRs are optional. A repository with no `adrs/` directory needs nothing from this skill.

An approved ADR is sealed: its body never changes. A decision that changes is a new ADR
that supersedes the old one.

## Shared contract

Resolve every path, key, state and transition from
`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md` (§7 and §13), and write files in the
body shape `${CLAUDE_PLUGIN_ROOT}/references/templates.md` defines for `adrs/`. Create
`.claudestacks/sdlc/adrs/` on the first write; never assume `setup` ran. This skill is the
only writer of `adrs/`. It never renames or deletes a file there, and never edits an
approved ADR's body. Flip `status` only per `artifact-chain.md` §7.2–§7.4, only as the last
step of the interaction that earns it. Never commit.

## Input

An ADR is named `0003` or `3`; normalise it to four digits. It resolves to the one file
matching `.claudestacks/sdlc/adrs/NNNN-*.md`.

- **No match** — report the pattern you looked for and ask for a correction. Never guess a
  neighbouring ADR.
- **Two matches** — refuse. Two files share a number, the board reads
  `INVALID (<file>: duplicate number NNNN)` for each, and the author fixes the files.

`new` takes no number.

## Check before acting

For any operation on an existing ADR, render the board and read the `ADR NNNN` row:

    sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"

When that prints nothing, `airsl` is not installed: derive the row by hand from
`artifact-chain.md` §13.3, the way the `status` skill's fallback does. A healthy
`approved`, `superseded`, `deprecated` or `dropped` ADR has no row; with no row, read the
status from the file.

When the row reads `INVALID (…)`, refuse: name the file and the reason exactly as the
board words them. The author fixes the file. The one exception is
`INVALID (<file>: superseded by MMMM but still approved)`: refuse every other operation on
that ADR and offer *finish supersede*, below.

After every flip, render the board again and tell the author what the ADR's row reads, and
what each affected chain's row reads: a chain whose approved spec cites the ADR can now
read `spec stale (ADR NNNN superseded by MMMM)`, `spec stale (ADR NNNN deprecated)`,
`spec blocked (ADR NNNN not approved)` or `ADR NNNN disproven by …`.

## Numbering

A new ADR takes one more than the highest `NNNN` carried by any file in `adrs/` matching
`^%d%d%d%d%-.+%.md$`, whatever that file's status or validity. A number is never reused.
Any other entry in `adrs/` is ignored.

## Operations

| Operation | Does | Refused when |
|---|---|---|
| new | asks one question at a time, writes `NNNN-<topic>.md` as `draft`, reviews it, asks whether to approve | never |
| approve | `draft → approved` with `sealed` written, then `approved → superseded` for each ADR it supersedes | the ADR is not `draft`; an ADR in its `supersedes` is not `approved` |
| supersede N | writes a new draft with `supersedes: [N]`, reviews it with `N` as authority, then approves it | `N` is not `approved` |
| deprecate N | `approved → deprecated` | `N` is not `approved` |
| amend | rewrites a draft's body | the ADR is not `draft` |
| drop | `draft → dropped` | the ADR is not `draft` |
| un-drop | `dropped → draft` | the ADR is not `dropped` |
| finish supersede | `approved → superseded`, on the author's yes | the ADR is not `approved`, or its row does not read `superseded by MMMM but still approved` |

Every refusal names the ADR's file and the status it found.

**new.** Ask, one question at a time: the title, the context, the options considered (two
or more, each with its trade-offs), the decision, and the consequences, costs included.
Write the file with `status: draft` and the body `templates.md` shows, then run the review
below and ask whether to approve. `<topic>` is the title in kebab-case.

**approve.** Needs the author's explicit word. Before sealing, read each ADR in this ADR's
`supersedes` as *Check before acting* does, its row when it has one and its file's status
when not; it counts as not `approved` when its row reads `INVALID (…)` or when no single
file matches its number. Refuse on any that is not `approved`. Then compute

    sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <file>

and write the 12 characters it prints as `sealed`, in the same edit that flips
`draft → approved`. If it prints nothing, the body has no fingerprint: stop and name the
file. Then, in the same interaction and with no fresh question, flip each ADR listed in
this ADR's `supersedes` from `approved → superseded` — the flip is a consequence of this
approval, not a new decision. Render the board and name the open chains whose rows now
read `spec stale (ADR NNNN superseded by MMMM)`.

**supersede N.** Write a new draft, numbered per *Numbering*, with `supersedes: [N]`. Its
context states what in `N` no longer holds. When `N`'s row reads
`disproven by <chain>/NN`, read that plan's probe result and cite it there. Review the
draft with `N`'s file as authority, ask whether to approve, and on the author's word
approve it as above.

**deprecate N.** Needs the author's explicit word. Flip `approved → deprecated` and change
nothing else in the file. The reason is not recorded there, because the body is sealed; it
belongs in the author's commit message, so say so.

**amend.** Rewrite the draft's body as the author directs; the status stays `draft`. An
approved ADR is never amended: say so, and name *supersede*.

**drop, un-drop.** Each needs the author's explicit word. `draft → dropped` and
`dropped → draft`; each is refused from any other status. An un-dropped ADR is a draft the
author approves again.

**finish supersede.** The row `superseded by MMMM but still approved` is reachable only
through an approval that was interrupted between sealing `MMMM` and flipping this ADR, or
through a hand-edited `supersedes`, which the seal does not cover. So this skill asks.
Show the author that `MMMM` lists this ADR in its `supersedes`, and ask whether `MMMM`
replaces it. Only on an explicit yes, flip `approved → superseded`. On a no, change nothing
and leave the row for the author.

## Review

Each draft is reviewed once, by an agent. Spawn `claudestacks-sdlc:artifact-reviewer` over
it:

```
kind: adr
draft: <the ADR file>
authority: <none, or the replaced ADR file(s)>
handoff: <TMPDIR>/claudestacks-sdlc-adr-<NNNN>-01.md
handoff-protocol: <the path /claudestacks:context-handoff gave you>
```

`authority` is none for *new*, and the file of every ADR the draft supersedes for
*supersede*. Invoke `/claudestacks:context-handoff` for the tier rules and the protocol
path. This flow spawns exactly one subagent, so it takes a literal temp path and mints no
session. Expand `${TMPDIR:-/tmp}` yourself before the path enters the brief. The report is
always `01`.

**Exactly one round. Never a second.** Fix the findings and go to the author. Do not
re-spawn the reviewer over the revised draft, and do not spawn it again after `amend`.
The agent never edits the draft, flips a `status` or commits; you fix the draft.

Every finding gets a disposition, at every tier, and the author sees it. Build a table as
you work the report:

| # | Tier | Finding | Disposition |
|---|---|---|---|
| 1 | 🔴 | <one line> | applied |
| 2 | 🟡 | <one line> | declined — <reason> |

Show it with the approval question. An approval given without sight of the declined
findings is not an approval of them.

The criteria live in `${CLAUDE_PLUGIN_ROOT}/references/artifact-review.md` § *Reviewing a
draft ADR*. If the agent does not resolve, or returns nothing you can act on, apply that
section inline yourself and tell the author the review ran inline — never skip the review
for want of the agent.

## Never

- Commit, rename or delete anything.
- Edit the body of an approved, superseded or deprecated ADR.
- Ask the author whether something should be an ADR. The author asks for one.
- Repair an `INVALID` row by editing the file. Only *finish supersede*, on an explicit yes,
  clears one.
