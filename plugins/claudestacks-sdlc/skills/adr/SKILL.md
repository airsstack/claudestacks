---
name: adr
description: Use to record or change an architecture decision — write, approve, supersede, deprecate, amend, drop or un-drop an ADR, or finish a half-done supersede. Invoke with an ADR number or `new`.
---

# ADR

## The rule

An ADR is one decision in `.claudestacks/sdlc/adrs/NNNN-<topic>.md`, cited by specs via their
`adrs` key. This skill is the only writer of `adrs/` and of ADR status. ADRs are optional. An
approved ADR is sealed: its body never changes; a changed decision is a new ADR that supersedes.

Paths, keys, transitions: `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md` (§7, §13). Body
shape: `${CLAUDE_PLUGIN_ROOT}/references/templates.md`. Create `adrs/` on first write. Never
rename, delete, or commit. Flip `status` only per §7.2–§7.4, as the last step of the interaction.

## Input

`0003` or `3` normalises to four digits and resolves to one `adrs/NNNN-*.md`. No match: report the
pattern, ask. Two matches: refuse (board reads `INVALID (<file>: duplicate number NNNN)`).
`new` takes no number.

## Check before acting

For an existing ADR render the board and read its `ADR NNNN` row (no output: derive per §13.3 as
the `status` skill does; healthy `approved`/`superseded`/`deprecated`/`dropped` ADRs have none, so
read the file):

    sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"

`INVALID (…)`: refuse, naming file and reason as worded. Exception:
`INVALID (<file>: superseded by MMMM but still approved)` refuses everything except *finish
supersede*. After every flip re-render and tell the author the ADR's row and each affected chain's
row (`spec stale (ADR NNNN superseded by MMMM)`, `spec stale (ADR NNNN deprecated)`, `spec blocked
(ADR NNNN not approved)`, `ADR NNNN disproven by …`).

## Numbering

New number = highest `NNNN` among files in `adrs/` matching `^%d%d%d%d%-.+%.md$` (any status or
validity) plus one. Never reused. Other entries are ignored.

## Operations

| Operation | Does | Refused when |
|---|---|---|
| new | asks, writes `NNNN-<topic>.md` as `draft`, reviews, asks to approve | never |
| approve | `draft → approved` with `sealed`, then `approved → superseded` for each `supersedes` entry | not `draft`; a `supersedes` ADR is not `approved` |
| supersede N | new draft with `supersedes: [N]`, reviewed with `N` as authority, then approved | `N` not `approved` |
| deprecate N | `approved → deprecated` | `N` not `approved` |
| amend | rewrites a draft's body | not `draft` |
| drop | `draft → dropped` | not `draft` |
| un-drop | `dropped → draft` | not `dropped` |
| finish supersede | `approved → superseded` on a yes | not `approved`, or row is not `superseded by MMMM but still approved` |

Every refusal names the file and the status found. Approve, deprecate, drop, un-drop need the
author's explicit word.

- **new.** One question at a time: title, context, options (two or more, each with trade-offs),
  decision, consequences incl. costs. `<topic>` is the kebab-case title. Write `status: draft`,
  review, ask to approve.
- **approve.** Read each `supersedes` ADR (row, else file status); one with an `INVALID` row or no
  single matching file counts as not `approved` — refuse. Run
  `sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <file>` and write the 12 characters as
  `sealed` in the same edit as `draft → approved` (no output: stop, name the file). Then flip each
  superseded ADR with no new question. Render the board and name open chains now reading
  `spec stale (ADR NNNN superseded by MMMM)`.
- **supersede N.** Context states what in `N` no longer holds; if `N`'s row reads
  `disproven by <chain>/NN`, cite that plan's probe result. Review, ask, approve as above.
- **deprecate N.** Change only `status`. The reason is not recorded (sealed); tell the author to
  put it in the commit message.
- **amend.** Status stays `draft`. An approved ADR is never amended: name *supersede*.
- **finish supersede.** Show that `MMMM` lists this ADR in `supersedes`, ask whether `MMMM`
  replaces it; flip only on an explicit yes, else change nothing.

## Review

Once per draft, spawn `claudestacks-sdlc:artifact-reviewer`:

```
kind: adr
draft: <the ADR file>
authority: <none, or the replaced ADR file(s)>
handoff: <TMPDIR>/claudestacks-sdlc-adr-<NNNN>-01.md
handoff-protocol: <the path /claudestacks:context-handoff gave you>
```

Authority is none for *new*, the superseded file(s) for *supersede*. Use a literal expanded temp
path (`${TMPDIR:-/tmp}`), no session; report is always `01`.

- **One round, never a second.** Fix findings and go to the author; do not re-spawn, not after
  `amend` either. The agent never edits or commits.
- Show the author a table `# | Tier | Finding | Disposition` (`applied` or `declined — <reason>`)
  for every finding at every tier, alongside the approval question.
- Criteria: `${CLAUDE_PLUGIN_ROOT}/references/artifact-review.md` § *Reviewing a draft ADR*. If the
  agent is missing or useless, apply that section inline and say so.

## Never

- Commit, rename or delete anything.
- Edit the body of an approved, superseded or deprecated ADR.
- Ask whether something should be an ADR.
- Repair an `INVALID` row by editing; only *finish supersede* on a yes clears one.
