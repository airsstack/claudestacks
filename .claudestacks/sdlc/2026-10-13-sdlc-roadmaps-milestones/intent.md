---
status: done
created: 2026-10-13
---

# Intent: chain artifacts drift apart unnoticed, and roadmap and milestone progress has no home in the chain

Amended 2026-10-13, the day it was written: the author widened the scope from roadmaps and
milestones alone to include keeping every related artifact in sync, and chose to carry both in
this one chain rather than a sibling.

## Problem

**Nothing checks that related artifacts still agree.** The plugin keeps artifacts in step only
through instructions inside each skill, which act only while that skill is running:

| What keeps artifacts in sync today | Enforced by |
|---|---|
| State gates — `design` refuses a `draft` intent, `plan` refuses an unapproved spec | skill text (`skills/design/SKILL.md:21-29`, `skills/plan/SKILL.md:38-48`) |
| Plan `done` rolls the intent up to `done` | skill text (`skills/execute/SKILL.md:325-332`); a missed one is not shown — the board counts such a chain as done and prints no row (`scripts/lib/status.lua:318-319`; probed 2026-10-13) |
| A disproven premise leads to amending the plan and spec | skill text, as a question to the author (`skills/execute/SKILL.md:261-274`) |
| Anything that changes between skill runs | nothing |

The plugin ships no hooks: `find plugins/claudestacks-sdlc -type d` lists `references`,
`agents`, `scripts`, `scripts/lib`, `.claude-plugin`, `skills` and the eight skill directories,
and no `hooks`; the same search finds `plugins/claudestacks/hooks` in the sibling plugin.

The board does not notice a disagreement either. A throwaway probe on 2026-10-13 (`airsl`
0.1.2, a byte-identical copy of `scripts/lib/status.lua`) rendered two deliberately broken
chains:

```
CHAIN                             STATE                         NEXT
2026-10-15-gap                    plan 01 approved              execute 01
2026-10-16-nospec                 plan 01 approved              execute 01
```

`2026-10-15-gap` holds an `approved` plan beside a `draft` spec; `2026-10-16-nospec` holds an
`approved` plan with no `spec.md` and no `spec: skipped` flag. In both the board tells an agent
to execute. Once a chain has plans, state derivation returns before it looks at the spec
(`status.lua:210-263`; the spec is read only from `:265`).

**The plugin has nothing above a single chain.** The largest unit is one chain holding one
intent (`references/artifact-chain.md:22`). The only dependency key, `depends-on`, links plans
inside one chain (`artifact-chain.md:112`); nothing relates one chain to another, or groups
chains under a larger goal.

**So progress above a chain has no home in the pipeline.** The status board computes each
chain's state from frontmatter every time it runs (`status.lua:190`), which is why chain state
has one answer. Anything larger — which chains make up a milestone, how far along it is, what
comes after it — has to be written down somewhere else, by hand, and kept in step by hand. The
board cannot help: it collapses finished chains into a bare count (`status.lua:330-333`), so
even "what has been delivered" is not readable from it. Roadmaps and milestones kept outside
the pipeline are the same drift as above, one level up.

**Why now.** The author reports several incidents in their own development caused by gaps
between artifacts, and one in another project that uses this plugin: roadmap and milestone
documents were kept outside the chain root, and AI agents asked about development progress gave
different answers. Asked on 2026-10-13 which kinds of gap they had met, the author named all
four offered: a plan left approved after its spec changed; an intent or spec edited in place
after the artifacts built on it were approved; a status never flipped after the work finished
or was abandoned; and execution that departed from the plan or disproved the spec without the
spec or sibling plans being updated. None of those projects was opened while writing this
intent; the incidents are recorded as reported, and the gaps proven here are the two above and
the unshown missed roll-up in the table.

## Affected systems

- `plugins/claudestacks-sdlc/` — the only plugin that changes:
  - `references/artifact-chain.md` and `references/templates.md` — the path, key, state and
    body-shape authorities every skill resolves against.
  - `scripts/lib/status.lua` and `scripts/status_test.lua` (31 tests) — the board. Probed on
    2026-10-13: a `roadmaps/` directory at the chain root renders
    `roadmaps  INVALID (intent.md missing)  fix roadmaps`, because only `prds` and `rfcs` are
    skipped (`status.lua:17`, `:80-82`); a plain file at the chain root produces no row; an
    intent carrying `milestone: platform/01` parses that value as the string `platform/01`
    and still derives normally. The scan is one level deep (`:128-133`).
  - The skills that read or flip chain state: `skills/intent/`, `skills/design/` (its redesign
    path, `SKILL.md:221-224`), `skills/plan/`, `skills/execute/` (the state walk-up,
    `SKILL.md:325-332`) and `skills/status/` (its no-`airsl` fallback restates the scan rules,
    `SKILL.md:15-23`).
  - New skills alongside the existing eight, and possibly a first hook.
  - `README.md` and `.claude-plugin/plugin.json` (version `0.1.2`, description).
- Repository text describing the chain: `CLAUDE.md:229`, root `README.md:44`, and the Lua test
  count at `CLAUDE.md:200` (`cargo make plugins-test` reported `399 passed, 0 failed (20
  files)` on 2026-10-13).

Not affected (assumed, overridable): the `distill`, `triage` and `setup` skills, and the three
agents. `distill` globs `.claudestacks/sdlc/*/plans/*.md` (`skills/distill/SKILL.md:50`), which
stays valid only while chains stay where they are — see Constraints.

## Desired outcome

**Related artifacts cannot disagree unnoticed.** When two artifacts that depend on each other
stop agreeing — a plan and the spec it was written against, a spec and its intent, a milestone
and its chains — every agent sees that disagreement in the same place, and no skill acts on
such a chain without saying so.

**Roadmaps and milestones live in the chain.** An engineer can describe a roadmap, the
milestones inside it, and which chains belong to each milestone, all inside the committed chain
root. Asked how far along a milestone or roadmap is, every agent gives the same answer, because
that answer is computed from the chains' own states and exists in one place only.

The chain is finished when the two probed gaps above are reported by the board instead of
rendered as `execute 01`; a roadmap and its milestones can be created, amended and dropped
through the plugin; the status board shows each milestone's progress and the chains under it; a
milestone and its roadmap close themselves when their work is done; and a repository that uses
no roadmap sees no roadmap or milestone behaviour at all.

## Constraints

Keeping artifacts in sync:

- **One mechanism for every relation.** Each relation between two artifacts is declared in
  frontmatter and checked by the script. Roadmap and milestone relations use that same
  mechanism rather than one of their own, so the sync mechanism is built first.
- **A disagreement is reported, never repaired silently.** It appears as a board row. Every
  status flip still follows the flip rule (`artifact-chain.md:147-150`).
- **No state is ever guessed.** The board's existing rule holds (`status.lua:74-75`), and
  derivation stays states-only, with no judgment call (`artifact-chain.md:173`).
- **Skills check before they act and after they flip a state.**
- **No compatibility with existing chains is required.** The author's decision, 2026-10-13:
  the rules apply to chains written from here on. A chain written before this change need not
  keep rendering as it did, and none is migrated.
- **The script and the no-`airsl` fallback produce the same board.**

Roadmaps and milestones:

- **Optional, never mandatory.** A single chain with no roadmap and no milestone is a complete,
  supported use of the plugin. A repository with no roadmap sees no new question and no new
  directory.
- **A roadmap is a file.** It contains milestones, and each milestone has its own chains. The
  engineer decides how many roadmaps a repository has and what they are called.
- **One file per milestone, and no other shape.** Each milestone carries its own `status` in
  its own frontmatter, as intents, specs and plans do; milestones are not sections inside the
  roadmap file. The engineer still decides how many milestones a roadmap has and what they
  are called.
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
  transitions that fire without a fresh approval question (`artifact-chain.md:157-159`).
- **Membership is a recorded fact, never an inference.** Whether a chain belongs to a milestone
  is not decided by matching topics or names.
- **A simple chain costs no question.** A chain created by the intent skill with no milestone
  mentioned is a simple chain; the skill does not ask whether it belongs to one, even in a
  repository that has milestones.

Both:

- **Nothing is ever deleted** (`artifact-chain.md:57-58`), and no skill commits
  (`artifact-chain.md:149-150`).
- Candidate directions, one line each, for `design` to settle: consistency rules in the board
  for spec-against-plans, intent-against-spec, milestone-against-chains and
  roadmap-against-milestones; a way to record that an artifact was amended after the artifacts
  built on it were approved; a session-start hook that puts the computed state in front of
  every agent; roadmaps under `roadmaps/<name>/roadmap.md` with milestones as `NN-<topic>.md`
  beside it; an optional intent frontmatter key `milestone: <roadmap>/<NN>` as the only link;
  new `roadmap` and `milestone` skills; a board that groups chains under their milestone with
  an `UNASSIGNED` group.

## Non-goals

- **Nesting chains inside a milestone or roadmap directory.** Settled against, per Constraints.
- **Making roadmaps or milestones a required stage** before `intent`.
- **Dates, deadlines, estimates and velocity.** A milestone states a goal, not a schedule.
- **Syncing with GitHub milestones, issues or projects.**
- **Migrating existing material**: neither the other project's out-of-pipeline roadmap
  documents nor this repository's committed chains are converted by this chain.
- **Cross-chain dependencies.** `depends-on` stays a plan-only, within-chain key.
- **Judging whether two artifacts agree in meaning.** The check compares
  recorded states and declared relations; whether a plan's prose still matches its spec's prose
  stays with `artifact-reviewer`.
- **Repairing a disagreement automatically.**
