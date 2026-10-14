---
name: roadmap
description: Use when work is larger than one chain and needs a named direction above it — creates a roadmap and its first milestones under .claudestacks/sdlc/roadmaps/, or revisits an existing roadmap to approve, amend, drop, or un-drop it. Optional; a single chain never needs a roadmap.
---

# Roadmap

Give a body of work a home above the chain. A roadmap is one file saying where the work
is going; its milestones are the files beside it; the chains that belong to a milestone
say so in their own intent. Nothing here is required: a repository can run every chain it
ever has without a roadmap, and no other skill asks for one.

A roadmap never records progress. No file holds a count, a percentage, a list of
milestones, a list of chains, or a checklist of finished work. The status board counts
all of that from the chains each time it runs, which is why every reader gets the same
answer.

## Shared contract

Resolve every path, key, state and transition from
`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`, and write files in the body shapes
`${CLAUDE_PLUGIN_ROOT}/references/templates.md` defines for a roadmap and a milestone.
Lazy-create `.claudestacks/sdlc/roadmaps/` and the roadmap's own directory before the
first write; `/claudestacks-sdlc:setup` does not create them. Never commit. Flip `status`
only per the transitions in `artifact-chain.md`, only as the last step of the interaction
that earns it, only on the user's explicit word. Nothing under `roadmaps/` is ever
deleted or renamed.

## Layout

```
.claudestacks/sdlc/roadmaps/
└── <roadmap>/                 # one directory per roadmap; the user names it
    ├── roadmap.md
    ├── 01-<topic>.md          # one file per milestone; NN orders them
    └── 02-<topic>.md
```

`<roadmap>` and `<topic>` are kebab-case. A repository may hold any number of roadmaps.
Both kinds of file carry `status` and `created` in frontmatter, and no other key.

## Creating a roadmap

Ask one question at a time, never a battery:

1. **Its name.** Kebab-case. Refuse `plans`, and say why: `roadmaps/plans/NN-<topic>.md`
   would be read as a chain's plan by the `distill` skill. If
   `.claudestacks/sdlc/roadmaps/<name>/` already exists, this is a re-invocation (below),
   not a creation.
2. **Its vision** — where this body of work is going and why.
3. **Its non-goals** — what it deliberately leaves out.
4. **Its first milestones**, in the order they should be numbered. For each one, ask its
   title, its goal — the state of the world when it is reached — and what it leaves out.
   "None yet" is a valid answer: milestones can be added later with the `milestone`
   skill.

A milestone states a goal, never a date, a deadline or an estimate.

Then write:

- `roadmaps/<name>/roadmap.md`, with `status: draft`, a `# Roadmap: <title>` heading,
  and the `## Vision` and `## Non-goals` sections;
- one `roadmaps/<name>/NN-<topic>.md` per milestone named, numbered `01` upward in the
  order given, each with `status: draft`, a `# Milestone: <title>` heading, and the
  `## Goal` and `## Non-goals` sections.

Then ask the user directly whether to approve the roadmap now or leave it `draft`.
`draft → approved` happens only on an explicit yes. Approving a roadmap does not approve
its milestones: each is approved through the `milestone` skill. After an approval, render
the board again and tell the user what the roadmap's row reads.

## Re-invocation

Before acting on an existing roadmap, render the board and read that roadmap's row:

    sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"

When that prints nothing, `airsl` is not installed: derive the row by hand, the way the
`status` skill's fallback does. Do the same again after every `status` flip this skill
makes, and tell the user what the row reads then.

When the row reads `INVALID (…)`, refuse: name the file and the reason exactly as the
board words them. The user fixes the file; this skill does not repair it.

| Operation | Does | Refused when |
|---|---|---|
| approve | `draft → approved`, then the roll-up (below) | the roadmap is not `draft` |
| amend | rewrites `## Vision` or `## Non-goals`; the status stays as it was | the roadmap is `done` |
| drop | `draft → dropped` or `approved → dropped` | the roadmap is `done` or already `dropped` |
| un-drop | `dropped → draft`; the user approves it again | the roadmap is not `dropped` |

Every refusal names the file and the status it found.

**Dropping a roadmap does not change its milestones.** The board flags each one still
`draft` or `approved` with `⤷ roadmap <roadmap> is dropped — drop this milestone`. After
the drop, tell the user which milestones those are, and that the `milestone` skill is
what drops them.

**`done` is final.** A closed roadmap is not reopened, amended or dropped. Work that
arrives after it closed belongs to a new roadmap, or needs none.

## Roll-up

After approving a roadmap, run the roll-up for it as the last step of the interaction.
The procedure is defined once, in `artifact-chain.md`: it closes each `approved`
milestone whose chains are all finished, with at least one `done`, then the roadmap once
its milestones are, again with at least one `done`. It is idempotent — when nothing is
ready it changes nothing — and it flips without a fresh approval question, because each
flip is a consequence of state already earned on the chains. Tell the user each thing it
closed.

A roadmap the board shows as `approved, 0 of 0 milestones done` has NEXT `add milestone`:
that is the `milestone` skill's `add` operation.
