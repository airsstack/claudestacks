---
status: approved
created: 2026-10-20
---

# Intent: architecture decisions have no home that outlives one chain, so they vanish, drift and break unnoticed

## Problem

**A decision lives only inside one chain's spec.** The largest unit the plugin has is one
chain holding one intent (`references/artifact-chain.md:20-23`), and the only place a design
choice is written down is that chain's `spec.md` (`artifact-chain.md:52-53`). The `design`
skill picks between two or three approaches at step 6 and records the outcome in the spec
(`skills/design/SKILL.md:188-191`). The plugin has no other record of a decision:
`grep -rniE '\badrs?\b|architecture decision' plugins/claudestacks-sdlc` returns 0 lines,
while the same search for `\broadmaps?\b` returns 334.

Asked on 2026-10-20 which problems this causes, the author named all four offered:

| Problem | Why the plugin allows it today |
|---|---|
| **Decisions vanish with specs.** | A redesign renames the spec `spec-superseded-YYYY-MM-DD.md` and writes a new `spec.md` (`artifact-chain.md:57-60`); the reasoning behind the old choice survives only inside an archived file nobody is pointed at. |
| **Cross-chain decisions drift.** | A choice several chains rely on is restated in each chain's spec, and nothing ties those restatements together, so they can diverge or contradict each other. |
| **Agents re-litigate decisions.** | There is no single place an agent can look up what was decided and why, so a later chain re-derives or overrides an earlier decision. |
| **Broken decisions go unnoticed.** | When execution disproves a claim, the plan records it with `disproves`, which names only that plan's own authority — the chain's spec, or its intent on the spec-skip path (`artifact-chain.md:263-265`, `:279-283`). Other chains built on the same decision are never told. |

**Why now.** The author did not name a triggering incident; asked, they restated that this
must be optional in the way roadmaps and milestones are.

## Affected systems

- `plugins/claudestacks-sdlc/` — the only plugin that changes (version `0.2.1`,
  `.claude-plugin/plugin.json`):
  - `references/artifact-chain.md`, `references/templates.md`, `references/artifact-review.md`
    — the path, key, state, body-shape and review-criteria authorities.
  - `scripts/lib/status.lua` and its tests — the board, including the chain-scan skip list
    (`status.lua:22`) and the session hook's attention words (`status.lua:588`).
  - `skills/design/`, `skills/execute/`, `skills/status/` (its no-`airsl` fallback), and a new
    skill beside the existing ten (`ls plugins/claudestacks-sdlc/skills`).
  - `agents/artifact-reviewer.md`.
  - `README.md` and `.claude-plugin/plugin.json`.
- Repository text describing the plugin: root `README.md:44`, `CLAUDE.md:235`,
  `.claude-plugin/marketplace.json:17`, and the Lua test count at `CLAUDE.md:206`.

Not affected (assumed, overridable): the `intent`, `plan`, `distill`, `triage`, `setup`,
`roadmap` and `milestone` skills, and the `chain-reader` and `task-briefer` agents.

## Desired outcome

**A decision that outlives one chain has one durable home in the chain root.** An engineer can
record an architecture decision once, every chain that relies on it says so, and an agent asked
"what was decided about X, and why" finds one answer.

**A decision cannot go stale unnoticed.** When a decision is replaced, retired, or disproven by
execution, every open chain built on it sees that on the board — the same board, and the same
session-start hook, that already report every other disagreement — and no skill acts on such a
chain without saying so.

The chain is finished when a decision can be recorded, accepted, superseded and retired through
the plugin; a chain's spec can cite decisions; replacing or disproving a decision is reported on
every open chain that cites it; and a repository that records no decision sees no new behaviour
at all.

## Constraints

Settled by the author in discussion on 2026-10-20:

- **Optional, like roadmaps and milestones.** A repository with no decision records sees no new
  question, no new directory and no new board row. A chain that cites no decision is a complete,
  supported use of the plugin.
- **One repository-wide series of records**, not records kept inside each chain.
- **One writer.** A new dedicated skill is the only thing that creates or changes a decision
  record. `design` hands off to it when a choice outlives the chain; it does not write records
  itself.
- **`design` never asks about decision records.** It hands off to the decision-record skill
  only when the author asks for a choice to be recorded as one — in any repository, including
  one that already holds records — the way `intent` writes `milestone` only when the author
  names one. Settled by the author on 2026-10-20 as the arrangement to try first.
- **An accepted record is never edited.** It is replaced by a later record or retired, and the
  board detects an edit to an accepted record mechanically.
- **Only a spec cites decisions.** A chain that needs one does not take the spec-skip path
  (`artifact-chain.md:198-202`); the intent cannot cite one, because it holds no solution
  content (`plugins/claudestacks-sdlc/README.md:37`).
- **Every relation is declared in frontmatter and checked by the board**, the mechanism the
  existing sync rules use (`artifact-chain.md:240-245`). The script and the no-`airsl` fallback
  produce the same board.
- **Only open chains are checked.** A chain whose intent is `done` or `dropped` is history and is
  not flagged when a decision it cited later changes, matching the existing rule
  (`artifact-chain.md:242-245`).
- **A disproof flags the decision itself**, not only the citing chain, so every other chain citing
  it learns it broke; it blocks the disproving chain's further plans and its walk-up until the
  decision is replaced or retired, as a disproven spec does today
  (`skills/execute/SKILL.md:323-350`).
- **`artifact-reviewer` reviews a draft decision record**, as it reviews specs and plans.
- **A disagreement is reported, never repaired silently**; nothing is ever deleted
  (`artifact-chain.md:64-65`), and no skill commits (`artifact-chain.md:175-178`).

Candidate directions, one line each, for `design` to settle and prove:

- records at `.claudestacks/sdlc/adrs/NNNN-<topic>.md`, created on first use, left out of the chain scan;
- states `draft → approved → superseded | deprecated`, `draft → dropped`;
- body: context, options considered, decision, consequences;
- keys: `sealed` (fingerprint of the record's own body, written at approval) and `supersedes` on a
  record; `adrs: [..]` on a spec; `disproves-adr: [..]` on a plan, naming only records its spec cites;
- skill `adr` with operations new, supersede (flips the replaced record in the same step), deprecate, drop;
- board rules for: edited accepted record, unknown cited record, cited record superseded or
  deprecated, cited record not approved, supersession halves disagreeing, record disproven;
- record problem rows worded with the existing attention words, so the session hook needs no change;
- an `adrs` key on an intent or a plan reported as invalid (not verified whether the board checks
  key placement today).

## Non-goals

- **Making decision records a required stage**, or any skill prompting the author to create one.
- **Citing decisions from an intent or from a spec-skip chain's plans.**
- **Re-checking finished chains** against decisions that changed after they closed.
- **Importing existing ADRs** from another location or tool (assumed, overridable).
- **Migrating existing chains** to cite decisions.
- **Judging whether a spec's prose agrees with a decision it cites.** The board compares recorded
  states and declared relations; meaning stays with `artifact-reviewer`.
- **Cross-chain dependencies between plans.** `depends-on` stays a plan-only, within-chain key.
- **Repairing a disagreement automatically.**
