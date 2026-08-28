---
status: approved
created: 2026-08-26
---

# Intent: agent report shapes are specified twice and agree nowhere

## Problem

Both agents in `claudestacks-sdlc` specify their own output shape in two places, and the
two specifications neither agree nor defer to each other. Each agent is therefore free to
pick a shape per run, and both have.

`agents/chain-reader.md` pins a shape in its Output section (`:41-58`) — a bare path line,
then `  ## <heading>`, then the section body indented two spaces. Its Context handoff
section (`:66-74`) separately says to write one file wrapping the extraction in
`<summary>` and `<detail>`, and says nothing about what shape goes inside the tags.
Nothing states that the file's `<detail>` follows the Output block. Two runs of an
identical brief on 2026-08-26 produced two different files: the first used `### <path>`
markdown headings with unindented bodies and `---` separators between files, the second
used the fenced, two-space-indented form from the Output block. Both were faithful
extractions; they were not the same document.

`agents/artifact-reviewer.md` has the same split. Its Output section (`:51-69`) pins a
flat one-line-per-finding form (`spec.md §4: 🔴 blocking: …`); its Context handoff section
(`:76-84`) assigns the verdict line and blocking findings to `<summary>` and the
severity-ordered list to `<detail>`, again without pinning a shape inside either tag. The
report it produced on 2026-08-26 used `## 🔴 blocking` / `## 🟡 risk` / `## 🔵 nit`
sections holding bold-led prose paragraphs — not the flat lines its own Output block
shows.

Underneath both is a third gap, found while designing this chain. Both definitions
describe the report as "ONE file built from two literal tags" and cite
`plugins/claudestacks/skills/process-guidelines/references/context-handoff.md` as the full
protocol. That file's § File schema (`:29-48`) mandates more than two tags: every handoff
file opens with frontmatter carrying `agent:`, `session:`, `seq:`, `task:`, and
`created:`, and only then the tags. No report either agent has written carries it — all
three produced on 2026-08-26 begin at line 1 with `<summary>`. The single-subagent
exception does not excuse this: `:62-64` states the file schema and return contract "still
apply unchanged — only the *path* the report lands at differs." Neither agent is
disobeying its definition; each definition contradicts the protocol it points at.

**Why it matters now: a check written against one of these reports fails on shape before
it can test content.** This bit twice in a single session, both times while running this
plugin's own verification steps:

- `plans/03-distill-wiring.md` Task 2 step 3 requires diffing an extracted block against
  the source it came from. The extraction pattern was written against the first report's
  `### <path>` headings; the second report had none, so the diff returned an empty block
  and tested nothing. It reported no difference in content because it had reached no
  content.
- `plans/01-foundations.md` Task 6 step 2 asserts
  `grep -c "<summary>\|<detail>"` returns `2`. It returned `3` — the report discussed the
  `<summary>`/`<detail>` schema in a finding, and the unanchored pattern counted the prose
  alongside the tags.

Neither failure was in the agents' actual work: both extractions were verbatim, and the
review findings were sound. The checks could not see that, because what they were checking
had moved.

This is the same failure class the corpus already carries under
`self-contradicting-verification` (`2026-08-24-sdlc-plugin/plans/04-rollout.md`) and the
`Spec coverage` assertion fixed mid-flight in `2026-08-25-sdlc-agent-tier/plans/02-review-wiring.md`:
a check whose subject can shift underneath it. Left alone, it recurs every time a plan
tries to gate an agent's report.

A second cost is latent rather than observed. `distill` reads `chain-reader`'s `<detail>`
into the main thread by explicit instruction, and `design` and `plan` route off
`artifact-reviewer`'s summary but read its `<detail>` whenever they act on a finding
(`skills/design/SKILL.md:112-113`). Each skill's description of what it will find there is
accurate only for whichever shape the agent happens to emit that run, so those
instructions drift out of true without anyone editing them.

## Affected systems

- `plugins/claudestacks-sdlc/agents/chain-reader.md` — Output section (`:41-58`) against
  Context handoff (`:66-74`).
- `plugins/claudestacks-sdlc/agents/artifact-reviewer.md` — Output section (`:51-69`)
  against Context handoff (`:76-84`).
- `plugins/claudestacks-sdlc/skills/distill/SKILL.md` — the one reader instructed to take
  `<detail>` into the main thread rather than routing off the summary.
- `plugins/claudestacks-sdlc/skills/design/SKILL.md` and `skills/plan/SKILL.md` — spawn
  `artifact-reviewer` and describe what its report contains.
- `.claudestacks/sdlc/2026-08-25-sdlc-agent-tier/plans/01-foundations.md` and
  `plans/03-distill-wiring.md` — carry the two checks that failed on shape.
- `plugins/claudestacks/skills/process-guidelines/references/context-handoff.md` — owns the
  file schema (`:29-48`) and return contract (`:68-74`) both agents cite and neither fully
  follows. It is the authority this chain conforms to, not a file this chain edits; see
  Non-goals.

## Desired outcome

Each agent emits one report shape, reproducible across runs and sessions, and its
definition states that shape once. A plan can then write a check against an agent's report
and have it mean the same thing on every run — so a failing check indicates the agent's
work is wrong, never that its formatting moved.

The reports also conform to the handoff protocol both definitions already cite: the
mandated frontmatter block is present, and what each definition says about its own file is
derived from that protocol rather than restated independently of it.

## Constraints

- **The single-source rule this plugin already applies to criteria applies here.** The
  `2026-08-25-sdlc-agent-tier` chain's whole point at §5.1 was that review criteria live in
  exactly one place; a shape specified in two sections of one file is the same defect in a
  different register. Whatever settles this cannot leave two copies behind.
- **The `<summary>`/`<detail>` split itself is not in question.** It is the suite-wide
  handoff protocol, owned by the `claudestacks` plugin, and it works — every report written
  so far returned the summary and left the detail on disk, exactly as intended.
- **Conformance runs one way: the definitions bend to the protocol.** Where an agent
  definition and `context-handoff.md` disagree, the protocol is right by construction — it
  is the suite-wide contract seven other agents already answer to. Nothing here may resolve
  a disagreement by relaxing the protocol to match what the two agents happen to emit.
- **`chain-reader`'s output must stay verbatim.** Any shape it adopts has to preserve the
  extracted text byte-for-byte, including interior blank lines. The current Output block's
  two-space indent already drops the blank line between a heading and its first body line,
  which is a shape decision quietly editing content.
- **No agent gains a tool, and neither stops being a leaf.** Nothing here touches the
  flat/leaf invariant or any user approval gate.
- Candidate direction, one line, for `design` to settle rather than this intent: give each
  agent definition one Output section that specifies the whole file including the tags, and
  delete the shape language from Context handoff — or the reverse — but not both.

## Non-goals

- **Changing what either agent extracts or judges.** `chain-reader`'s refusal to group,
  count, or rank, and `artifact-reviewer`'s severity tiers and criteria, are correct and
  out of scope.
- **Editing `context-handoff.md` or the suite-wide protocol.** The protocol is sound on
  both counts: it pins the file schema, and it deliberately leaves the layout *inside*
  each tag to the agent — `<summary>` is "the verdict / index", `<detail>` is "full
  findings, file:line tables, rationale" (`:40-46`). Those say what belongs in each tag,
  not how it is laid out, which is exactly the job the two agent definitions are supposed
  to do and currently do twice. A change to the protocol would reach `coder`, `reviewer`,
  `explorer`, and the four journal agents; this chain changes none of them.
- **A machine-readable schema for agent reports.** Whether these reports should be parsed
  rather than read is a larger question than the one this intent raises, and nothing
  currently parses them.
- **Retrofitting past reports.** The two files written on 2026-08-26 live in `TMPDIR` and
  are disposable.
- **The `claudestacks` plugin's own agents.** `coder`, `reviewer`, `explorer`, and the four
  journal agents cite the same protocol and may share either gap — the frontmatter omission
  especially, since nothing in this repository has checked their reports for it. That is a
  reason to look, in its own chain, not a reason to widen this one; no divergence has been
  observed in any of them, and asserting one without evidence is what this repository's
  guidance forbids.
