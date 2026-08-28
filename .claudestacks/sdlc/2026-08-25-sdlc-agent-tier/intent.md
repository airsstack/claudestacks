---
status: done
created: 2026-08-25
---

# Intent: an agent tier for the claudestacks-sdlc workflow skills

## Problem

Every `claudestacks-sdlc` skill except `execute` does all of its work on the main thread.
`execute` is the exception: it routes each task through `claudestacks:orchestrate`, which
runs the coder → reviewer pipeline (`skills/execute/SKILL.md:55-63`). The other seven —
`design`, `distill`, `intent`, `plan`, `setup`, `status`, `triage` — carry no delegation
at all: a grep for `agent|subagent|coder|reviewer|explorer|orchestrat`
across `skills/*/SKILL.md` and `references/*.md` returns hits only in `execute`, one
passing mention in `plan/SKILL.md:209`, and prose in `distill` and `review-policy.md`.

That costs two distinct things.

**Main context burns on read-heavy steps that produce small answers.** `design` step 3
explores project context (`skills/design/SKILL.md:56-57`), `plan` maps the file structure
before defining tasks, and `distill` scans every plan file under
`.claudestacks/sdlc/*/plans/*.md` for its `## Review findings` section
(`skills/distill/SKILL.md:36-40`). Each reads far more than it reports, and `distill`'s
scan grows with every chain the repo accumulates — the cost rises over the life of the
repo while the answer stays a short table.

**Artifact self-review is done by the thread that wrote the artifact.** `design` step 8
re-reads the spec it just produced "from the perspective of someone seeing it for the
first time" (`skills/design/SKILL.md:87-99`), checking for placeholders, internal
inconsistency, scope creep, ambiguity, and sections that do not root in the intent.
`plan`'s pre-save check does the same against the spec. But the thread performing that
check is the thread that made every decision under review, holding the whole dialogue that
produced them — it is anchored on its own reasoning and is structurally the weakest gate in
the chain. This is the same problem the code pipeline already solved elsewhere: a coder's
"DoD green" is treated as a claim, which is why the reviewer re-runs the DoD itself instead
of reading the receipt.

Neither cost is hypothetical for this repository — it dogfoods the plugin, so every chain
written here pays both.

## Affected systems

- `plugins/claudestacks-sdlc/skills/design/SKILL.md` — context exploration (step 3) and
  spec self-review (step 8).
- `plugins/claudestacks-sdlc/skills/plan/SKILL.md` — file-structure mapping and the
  pre-save spec-coverage check.
- `plugins/claudestacks-sdlc/skills/distill/SKILL.md` — the cross-chain findings scan.
- `plugins/claudestacks-sdlc/` — has no `agents/` directory today; the full file list is
  `.claude-plugin/`, `references/`, `scripts/`, `skills/`, plus `README.md` and `LICENSE`.
- `plugins/claudestacks/agents/explorer.md` — an existing agent in a *different* plugin of
  this suite, so anything depending on it is a cross-plugin reference.

## Desired outcome

The read-heavy steps return compact results to the main thread instead of the file bodies
they read, and artifact review at the intent→spec and spec→plan hops is performed by a
reader that does not carry the dialogue which produced the artifact. Every user approval
gate in the chain stays exactly where it is: an agent reports, the skill still stops and
asks.

## Constraints

- **Dialogue stages cannot be delegated.** A subagent receives one prompt and returns one
  report; it never gets a user turn. `intent`, `design`, `plan`, `triage`, and `distill`
  are each built on multi-turn dialogue with a user approval gate — `design` alone requires
  one question at a time (`skills/design/SKILL.md:60-65`), confirmation after each
  non-trivial section (`:72-78`), and a mandatory approval stop (`:101-106`). Running a
  whole stage inside an agent would delete the contract it exists to enforce. Delegation
  applies to steps within a stage, never to a stage.
- **The flat/leaf invariant holds.** No agent spawns another agent; every result routes
  through the thread that spawned it. This is `claudestacks:orchestrate`'s stated invariant
  and the reason the user gate can never be bypassed.
- **No agent commits, and no agent flips an artifact `status`.** Both remain where
  `artifact-chain.md` §7.3 puts them: the skill flips state after explicit in-dialogue
  approval, and committing stays the user's separate act.
- **Cross-plugin dependencies degrade, never fail.** Anything in `claudestacks-sdlc` that
  reaches for an agent owned by the `claudestacks` main plugin must carry the same
  soft-coupling clause `execute` already carries (`skills/execute/SKILL.md:59-63`): if it
  does not resolve, do the work inline on the main thread and tell the user the agent was
  unavailable.
- **`${CLAUDE_PLUGIN_ROOT}` resolves per owning plugin.** Any agent that must read
  `references/artifact-chain.md` or `references/templates.md` by that variable has to be
  owned by `claudestacks-sdlc` — an agent shipped in `claudestacks` cannot reach this
  plugin's references that way.
- Candidate direction, one line, for `design` to settle rather than this intent: wire the
  existing `claudestacks:explorer` into the read-heavy steps, and add one new
  `claudestacks-sdlc`-owned artifact-review agent for the two hops.

## Non-goals

- **A dedicated agent per workflow stage.** Ruled out by the dialogue constraint above.
- **Changing how `execute` runs.** It keeps routing code work through
  `claudestacks:orchestrate` → coder → reviewer. Nothing in this chain touches code-diff
  review or the Definition of Done.
- **Moving, renaming, or re-scoping `claudestacks:explorer`, `coder`, or `reviewer`.** They
  stay owned by the `claudestacks` main plugin as they are.
- **New chain artifacts, frontmatter keys, or states.** `artifact-chain.md` §6 and §7 are
  unchanged by this work.
- **Anything in `plugins/claudestacks-sdd/`.** Its deletion belongs to plan 04 of the
  `2026-08-24-sdlc-plugin` chain and is independent of this one.
