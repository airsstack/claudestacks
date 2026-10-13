---
status: approved
created: 2026-10-13
---

# Intent: roadmap and milestone progress lives outside the chain, so agents report conflicting states

## Problem

**The plugin has nothing above a single chain.** The largest unit is one chain holding one
intent (`plugins/claudestacks-sdlc/references/artifact-chain.md:22`). The only dependency key,
`depends-on`, links plans inside one chain (`artifact-chain.md:112`); nothing relates one chain
to another, or groups chains under a larger goal.

**So progress above a chain has no home in the pipeline.** The status board computes each
chain's state from frontmatter every time it runs (`scripts/lib/status.lua:190`), which is why
chain state has one answer. Anything larger — which chains make up a milestone, how far along
it is, what comes after it — has to be written down somewhere else, by hand, and kept in step
by hand. The board cannot help: it collapses finished chains into a bare count
(`status.lua:330-333`), so even "what has been delivered" is not readable from it.

**Why now.** The author reports an incident in another project that uses this plugin: roadmap
and milestone documents were kept outside the chain root, and AI agents asked about development
progress gave different answers. The author's diagnosis is that those documents sat outside the
pipeline and its workflow. That project was not opened while writing this intent; the incident
is recorded as reported.

## Affected systems

- `plugins/claudestacks-sdlc/` — the only plugin that changes:
  - `references/artifact-chain.md` and `references/templates.md` — the path, key, state and
    body-shape authorities every skill resolves against.
  - `scripts/lib/status.lua` and `scripts/status_test.lua` — the board. Two details matter:
    any top-level directory other than `prds` and `rfcs` is read as a chain
    (`status.lua:17`) and renders `INVALID (intent.md missing)` (`:80-82`), and the scan is one
    level deep (`:128-133`).
  - `skills/intent/`, `skills/execute/` (the state walk-up, `SKILL.md:325-332`) and
    `skills/status/` (its no-`airsl` fallback restates the scan rules, `SKILL.md:15-23`).
  - New skills alongside the existing eight.
  - `README.md` and `.claude-plugin/plugin.json` (version `0.1.2`, description).
- Repository text describing the chain: `CLAUDE.md:229`, root `README.md:44`, and the Lua test
  count at `CLAUDE.md:200` if tests are added.

Not affected (assumed, overridable): the `design`, `plan`, `distill`, `triage` and `setup`
skills, and the three agents. `distill` globs `.claudestacks/sdlc/*/plans/*.md`
(`skills/distill/SKILL.md:50`), which stays valid only while chains stay where they are — see
Constraints. The nine chains already committed in this repository carry no milestone and must
render as they do today.

## Desired outcome

An engineer can describe a roadmap, the milestones inside it, and which chains belong to each
milestone, all inside the committed chain root. Asked how far along a milestone or roadmap is,
every agent gives the same answer, because that answer is computed from the chains' own states
and exists in one place only.

The chain is finished when a roadmap and its milestones can be created, amended and dropped
through the plugin; the status board shows each milestone's progress and the chains under it; a
milestone and its roadmap close themselves when their work is done; and a repository that uses
none of this behaves exactly as it does today.

## Constraints

- **Optional, never mandatory.** A single chain with no roadmap and no milestone is a complete,
  supported use of the plugin. A repository with no roadmap sees no new question, no new
  directory and no change to the board's output.
- **A roadmap is a file.** It contains milestones, and each milestone has its own chains. The
  engineer decides how many roadmaps a repository has and what they are called.
- **Chains stay flat at the chain root**, whether or not they belong to a milestone. A chain's
  path never changes when it joins, leaves or switches milestones. This repository's chains
  cite their own full paths 35 times across 15 files, and `distill` and the board both read one
  level deep.
- **Progress is never stored.** No file holds a progress number, a percentage, or a checklist
  of finished work. Progress is counted from the member chains at the moment it is asked for.
- **Unstarted work is visible to the count.** Work planned for a milestone but not yet begun is
  parked as a `draft` intent, which the intent skill already treats as an uncommitted idea
  (`skills/intent/SKILL.md:10-12`). A milestone with unstarted work must not read as complete.
- **A milestone closes by automatic roll-up**, the way an intent does
  (`artifact-chain.md:133`): when every member intent is `done` or `dropped`, with at least one
  `done`. A roadmap rolls up from its milestones the same way. These join the two existing
  transitions that fire without a fresh approval question (`artifact-chain.md:157-159`); every
  other flip still follows the flip rule (`artifact-chain.md:147-150`).
- **A stored state that disagrees with the chains is flagged, never trusted.** The board's
  existing rule holds: no state is ever guessed (`status.lua:74-75`).
- **Membership is a recorded fact, never an inference.** Whether a chain belongs to a milestone
  is not decided by matching topics or names; board derivation stays states-only, with no
  judgment call (`artifact-chain.md:173`).
- **Nothing is ever deleted** (`artifact-chain.md:57-58`), and no skill commits
  (`artifact-chain.md:149-150`).
- **The script and the no-`airsl` fallback produce the same board.**
- **A simple chain costs no question.** A chain created by the intent skill with no milestone
  mentioned is a simple chain; the skill does not ask whether it belongs to one, even in a
  repository that has milestones.
- **One file per milestone, and no other shape.** Each milestone carries its own `status` in
  its own frontmatter, as intents, specs and plans do; milestones are not sections inside the
  roadmap file. The engineer still decides how many milestones a roadmap has and what they
  are called.
- Candidate directions, one line each, for `design` to settle: roadmaps under
  `roadmaps/<name>/roadmap.md` with milestones as `NN-<topic>.md` beside it; an optional intent
  frontmatter key `milestone: <roadmap>/<NN>` as the only link; new `roadmap` and `milestone`
  skills; a board that groups chains under their milestone with an `UNASSIGNED` group.

## Non-goals

- **Nesting chains inside a milestone or roadmap directory.** Settled against, per Constraints.
- **Making roadmaps or milestones a required stage** before `intent`.
- **Dates, deadlines, estimates and velocity.** A milestone states a
  goal, not a schedule.
- **Syncing with GitHub milestones, issues or projects.**
- **Migrating existing material**: neither the other project's
  out-of-pipeline roadmap documents nor this repository's nine committed chains are converted
  by this chain.
- **Cross-chain dependencies.** `depends-on` stays a plan-only, within-chain key.
