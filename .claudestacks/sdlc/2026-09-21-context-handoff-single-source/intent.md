---
status: approved
created: 2026-09-21
---

# Intent: the context handoff protocol is restated in thirteen files and checked in none

## Problem

The Context Handoff protocol has one written authority —
`plugins/claudestacks/skills/process-guidelines/references/context-handoff.md`, 164 lines —
and thirteen other files that restate parts of it. Seven agent definitions restate the
report contract, six driver skills restate the session lifecycle, and no two of them agree
on the vocabulary. Nothing anywhere verifies that a report conforms.

**The duplication has already produced a defect.** `agents/coder.md:96-105`,
`agents/explorer.md:67-76`, and `agents/reviewer.md:108-117` are byte-identical (confirmed
by `diff`), which means `explorer` — a read-only agent — carries the clause *"(and, for the
coder, source within task scope)"* at `explorer.md:72`. It grants a scope `explorer` does
not have, in a file that exists to deny it one. The same clause sits at `coder.md:101` and
`reviewer.md:113`.

**The pointer that would make restating unnecessary cannot be opened.** Five agents end
their section by citing the authority; two do not cite it at all. No spelling resolves:

| Agent | Cites it as |
|---|---|
| `claudestacks`: `coder`, `explorer`, `reviewer` | `process-guidelines/references/context-handoff.md` |
| `claudestacks-sdlc`: `chain-reader`, `artifact-reviewer` | "the `claudestacks` plugin's `skills/process-guidelines/references/context-handoff.md`" |
| `claudestacks-sdlc`: `task-briefer` | no citation; schema inlined at `:99-120` |
| `claudestacks-journal`: `journal-curator` | no citation; schema inlined at `:76-86` |

Neither form is resolvable from a subagent's working directory, and the cross-plugin case
has no correct spelling at all: `skills/journal-review/SKILL.md:70-74` already records why —
the sibling plugin's install path carries that plugin's version, a value no environment
variable exposes, so any path written down is wrong the moment either plugin is bumped. So
restating is not laziness; it is the only thing that currently works.

**The same split runs through the driver half.** Two drivers mint a session
(`claudestacks:orchestrate` SKILL.md:103-122, `claudestacks-sdlc:execute` SKILL.md:94-116);
four take the single-subagent exception (`:51-66`) and hand-rolled their own temp-path
prose — `design/SKILL.md:159-168`, `plan/SKILL.md:219-228`, `distill/SKILL.md:47-52`,
`journal-review/SKILL.md:64-80`. The exception is now the majority path, and the field name
for the same payload differs per plugin: `handoff:` in `orchestrate` and `execute`,
`report:` in `design`, `plan` and `distill`, `handoff_path:` in `journal-review`.

**Nothing checks any of it.** `plugins/claudestacks/hooks/hooks.json` registers five hook
groups — `SessionStart` twice, `SessionEnd`, `UserPromptSubmit`, and `PreToolUse` on
`Read|Edit|Write` — and none concerns handoff. `scripts/handoff.lua` manages directories, leases and pruning; it never
opens a report. Its 29 tests in `handoff_test.lua` all exercise session mechanics. So every
rule in the file schema and the return contract is model obedience, unverified by
construction.

That absence has a measured cost. `2026-08-26-agent-report-shape/spec.md:146-148` records
that the file schema at `context-handoff.md:29-48` mandates frontmatter — `agent:`,
`session:`, `seq:`, `task:`, `created:` — and that every report produced on 2026-08-26 began
at line 1 with `<summary>`. That chain's intent documents two checks that failed on report
shape rather than report content (`plans/03-distill-wiring.md` Task 2 step 3, and
`plans/01-foundations.md` Task 6 step 2). The gap went unnoticed for as long as it did
because there was nothing that could notice it.

**Why now.** `2026-08-26-agent-report-shape` reached an approved intent and a drafted spec
by fixing two of the seven agents, then stopped at a boundary it could not cross: its §6
had to *interpret* the mandated frontmatter to proceed — omit `session:` under the
single-subagent exception, derive `task:` from existing brief fields, read `seq:` as the
round counter — and closed by recording that amending the protocol "is its own chain"
(`spec.md:190-192`). This is that chain, and it absorbs the earlier one: settling the
schema for two agents while five carry a different reading would install the same
disagreement one level up.

## Affected systems

- `plugins/claudestacks/skills/process-guidelines/references/context-handoff.md` — the
  authority. Its file schema (`:29-48`), return contract (`:68-74`), single-subagent
  exception (`:51-66`), session lifecycle (`:91-155`) and error handling (`:157-164`) are
  all in scope.
- `plugins/claudestacks/scripts/handoff.lua` (95 lines), `scripts/lib/handoff.lua`
  (220 lines), `scripts/handoff_test.lua` (29 tests) — the code half, including the
  documented `init` fragility at `context-handoff.md:117-131`.
- **Seven writer agents**, all of which restate the contract:
  `claudestacks`: `coder`, `explorer`, `reviewer`;
  `claudestacks-sdlc`: `task-briefer`, `chain-reader`, `artifact-reviewer`;
  `claudestacks-journal`: `journal-curator`.
- **Six driver skills**: `claudestacks:orchestrate`; `claudestacks-sdlc:execute`, `design`,
  `plan`, `distill`; `claudestacks-journal:journal-review`.
- `.claudestacks/sdlc/2026-08-26-agent-report-shape/` — absorbed by this chain; its intent
  and drafted spec are inputs, and its two plan-file corrections
  (`2026-08-25-sdlc-agent-tier/plans/01-foundations.md:564`,
  `plans/03-distill-wiring.md:198-206`) carry over rather than being dropped.

Not affected: `journal-capture`, `journal-note`, `journal-recall`. None takes a handoff
path or mentions the protocol — assumed out of scope on that basis, overridable.

## Desired outcome

Every rule of the protocol is written in exactly one place, every file that must obey it can
reach that place at runtime, and a report that violates it is caught by something other than
a reader noticing.

Concretely, the chain is finished when: an agent definition states only what is specific to
that agent, and obtains the rest from a path it can actually open; a driver names one thing
to start, heartbeat and close a session rather than restating the procedure; the same payload
has the same field name in every brief across all three plugins; the frontmatter question
`2026-08-26-agent-report-shape` §6 had to interpret is settled once, for all seven agents;
and a written report can be verified against the schema mechanically.

## Constraints

- **The `<summary>`/`<detail>` split is not in question.** It is the suite-wide protocol and
  it works — every report written so far returned the summary and left the detail on disk.
  This chain changes where the rules live and whether they are checked, not what they are.
- **No agent gains a tool, and no agent stops being a leaf.** In particular, the obvious
  dedup route is closed for most agents: only `coder` and `reviewer` carry `Skill`;
  `explorer`, `task-briefer`, `chain-reader`, `artifact-reviewer` and `journal-curator` do
  not (verified from each definition's `tools:` frontmatter). Whatever delivers the rules to
  an agent must work with `Read`.
- **The flat/leaf topology and every user approval gate are untouched.** No agent spawns an
  agent; no agent commits; the user remains the commit gate.
- **Backward compatibility with a standalone run.** `context-handoff.md:163` already
  guarantees an agent run without a handoff path returns its receipt inline. Nothing here
  may make an agent's core contract depend on a file or field being present.
- **A change to the authority reaches all seven agents and all six drivers at once.** That
  is why the earlier chain declined it, and it is the reason this one exists — but it means
  no rule may be settled for a subset.
- **Absorbing `2026-08-26-agent-report-shape` may not silently drop its work.** Its two
  agents, its `## Report` contract, its §6 interpretation and its two plan-file corrections
  are carried forward or explicitly overruled with a reason — never lost.
- Candidate directions, one line each, for `design` to settle rather than this intent: a
  `/context-handoff` skill owning the driver half including the `airsl` invocation; a
  resolved `protocol:` path passed in the brief so agents keep only an unconditional stub;
  a schema checker as the thing that makes conformance verifiable.

## Non-goals

- **A machine-readable report format.** The question here is whether a report *conforms*,
  not whether it should be parsed instead of read. The tags and the prose inside them stay
  human-first.
- **Retrofitting reports already written.** Handoff files are ephemeral by design — pruned
  at `init`, or living in `TMPDIR` under the exception.
- **Changing what any agent extracts, implements or judges.** `explorer`'s refusal to
  evaluate, `chain-reader`'s refusal to interpret, `coder`'s test-first discipline,
  `reviewer`'s independent Definition-of-Done run, `artifact-reviewer`'s criteria and
  severity tiers: all correct, all untouched.
- **The snapshot store and the journal vault.** Both are separate persistence mechanisms
  with their own roots and lifecycles; `context-handoff.md:25-27` already distinguishes
  handoff from the snapshot store deliberately.
- **Making the worktree-isolation guard itself behave differently.** The guard's refusal of
  `--allow-exec git` and of runtime-computed variables is Claude Code's, not this
  repository's. This chain may contain or work around it; it cannot fix it.
