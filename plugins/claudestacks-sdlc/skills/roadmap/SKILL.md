---
name: roadmap
description: Use when work is larger than one chain — creates a roadmap and its first milestones under .claudestacks/sdlc/roadmaps/, or approves, amends, drops or un-drops an existing one. Optional.
---

# Roadmap

## The rule

A roadmap is one file naming a direction; its milestones sit beside it. Nothing requires one. A
roadmap records no progress (no counts, percentages, or lists of milestones or chains); the board
derives all of it.

Paths, keys, transitions: `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`. Body shapes:
`${CLAUDE_PLUGIN_ROOT}/references/templates.md`. Lazy-create `.claudestacks/sdlc/roadmaps/` and the
roadmap directory (`setup` does not). Never commit. Flip `status` only as the last step of the
interaction, on the user's explicit word. Never delete or rename under `roadmaps/`.

```
.claudestacks/sdlc/roadmaps/<roadmap>/
├── roadmap.md
├── 01-<topic>.md      # one per milestone
└── 02-<topic>.md
```

Names are kebab-case. Both file kinds carry only `status` and `created` in frontmatter.

## Creating

Ask one question at a time:

1. **Name.** Refuse `plans` (`roadmaps/plans/NN-<topic>.md` reads as a chain plan to `distill`). If
   the directory already exists, this is a re-invocation.
2. **Vision:** where the work is going and why.
3. **Non-goals.**
4. **First milestones**, in numbering order: title, goal (state of the world when reached, never a
   date or estimate), non-goals each. "None yet" is valid (`milestone` `add` later).

Write `roadmap.md` (`status: draft`, `# Roadmap: <title>`, `## Vision`, `## Non-goals`) and one
`NN-<topic>.md` per milestone from `01` (`status: draft`, `# Milestone: <title>`, `## Goal`,
`## Non-goals`). Then ask whether to approve the roadmap now or leave `draft`; `draft → approved`
only on an explicit yes. Approving does not approve milestones (`milestone` skill does). After an
approval, re-render the board and tell the user the roadmap's row.

## Re-invocation

Render the board and read the roadmap's row (no output: derive by hand as `status` does); repeat
after every flip and tell the user:

    sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"

`INVALID (…)`: refuse, naming file and reason; the user fixes it.

| Operation | Does | Refused when |
|---|---|---|
| approve | `draft → approved`, then roll-up | not `draft` |
| amend | rewrites `## Vision` or `## Non-goals`; status unchanged | `done` |
| drop | `draft`/`approved → dropped` | `done` or already `dropped` |
| un-drop | `dropped → draft`; user approves again | not `dropped` |

Every refusal names the file and status found.

- **Dropping does not change milestones.** The board flags each open one `⤷ roadmap <roadmap> is
  dropped — drop this milestone`; tell the user which, and that `milestone` drops them.
- **`done` is final.** Later work belongs to a new roadmap or none.

## Roll-up

After approving, run the roll-up from `artifact-chain.md` for this roadmap as the last step: it
closes each `approved` milestone whose chains are all finished (at least one `done`), then the
roadmap likewise. Idempotent, no fresh approval question. Tell the user each thing it closed.
`approved, 0 of 0 milestones done` has NEXT `add milestone` (the `milestone` skill's `add`).
