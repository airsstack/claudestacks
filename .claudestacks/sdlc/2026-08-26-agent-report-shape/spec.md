---
status: draft
created: 2026-08-28
---

# Spec: one report shape per agent, derived from the handoff protocol

Both `claudestacks-sdlc` agents specify their own report file twice — once in an Output
section, once in a Context handoff section — and the two specifications neither agree nor
defer to each other, so each agent picks a shape per run and both have. This spec replaces
those two sections in each definition with one `## Report` section that pins what is
specific to that agent and defers everything common to
`plugins/claudestacks/skills/process-guidelines/references/context-handoff.md`, the
protocol both definitions already cite and neither fully follows. Two files change. No new
file is created, no skill's spawn brief changes, and no agent gains a tool.

## 1. Design premises

**The protocol is the authority; the definitions bend to it.** Where an agent definition
and `context-handoff.md` disagree, the protocol is right by construction — it is the
suite-wide contract seven other agents answer to. Nothing in this spec resolves a
disagreement by relaxing the protocol.

**The protocol already owns everything common.** Its § File schema (`:29-48`) fixes the
frontmatter block and the two tags; its § Return & routing contract (`:68-74`) fixes what
the agent returns and what stays on disk; its § Error handling (`:109-116`) fixes write
failure, missing-path reads, and standalone runs. An agent definition that restates any of
this creates the second copy that caused this chain.

**The protocol deliberately does not own the layout inside each tag.** It says `<summary>`
is "the verdict / index — cheap, scannable" and `<detail>` is "full findings, file:line
tables, rationale" (`:40-46`) — what belongs in each tag, not how it is laid out. That
gap is the agent definition's job, and doing it exactly once is the whole of this change.

**Single source by deletion, not relocation.** The previous chain moved review criteria
into `references/artifact-review.md` and deleted them from the two skills. The same
discipline applies here, with a different destination: the common half already has a home
in `context-handoff.md`, so this spec deletes rather than relocates. Adding a third file
to hold a shared template was considered and rejected — it would mostly re-point at the
protocol, and the two agents share almost nothing inside the tags.

## 2. Files this spec changes

| File | Change |
|---|---|
| `plugins/claudestacks-sdlc/agents/chain-reader.md` | Replace `## Output` (`:41-58`) and the shape language in `## Context handoff` (`:66-74`) with one `## Report`. Widen `## Boundaries` (`:59-65`) per §6. |
| `plugins/claudestacks-sdlc/agents/artifact-reviewer.md` | Replace `## Output` (`:51-69`) and the shape language in `## Context handoff` (`:76-84`) with one `## Report`. Widen `## Boundaries` (`:70-75`) per §6. |
| `.claudestacks/sdlc/2026-08-25-sdlc-agent-tier/plans/01-foundations.md` | Re-anchor the tag-count assertion at `:564` per §8.1. |
| `.claudestacks/sdlc/2026-08-25-sdlc-agent-tier/plans/03-distill-wiring.md` | Re-point the verbatim diff at `:198-206` to the §4 shape. |

`## Output` is **replaced, not deleted**: the rules inside it that are about behavior rather
than layout have named destinations in §4 and §5, and no rule currently in either file is
dropped by this chain.

No skill is edited. `skills/distill/SKILL.md`, `skills/design/SKILL.md`, and
`skills/plan/SKILL.md` keep their spawn briefs and their consumption instructions verbatim,
because neither the brief shape nor the return contract changes.

The two plan files are in scope because the intent names them as affected systems, and
because §8's three rules would otherwise bind future checks while the two checks that
motivated this chain stayed broken in the tree. Both plans are `status: approved`; this is
a correction to an assertion, not a redesign, so neither state changes.

## 3. The `## Report` section contract

Each agent's `## Report` section carries exactly three things, in this order:

1. **A pointer, not a restatement,** for the common half: the frontmatter block, which tag
   holds what, the return contract, and error handling all come from `context-handoff.md`,
   cited by section name. The section states no rule that file already states.
2. **The `<summary>` shape** for this agent, as a literal template.
3. **The `<detail>` shape** for this agent, as a literal template.

A definition may not describe its file shape anywhere outside this section. That is the
invariant §8 check 2 tests.

## 4. `chain-reader`'s report

`<summary>` is exactly one line:

```
Glob <glob> matched <N> files; <M> carried <heading>.
```

`<detail>` is one block per matched file, in glob order, separated by a single blank line:

```
<path>
  ## <heading>

  <every line beneath the heading, indented two spaces, blank lines preserved>
```

Two properties of this template are load-bearing and must be stated as such in the
definition:

- **The blank line after the heading is preserved.** The superseded Output block placed the
  first body line directly beneath the heading, dropping the blank line the source carries.
  A shape rule that silently edits the extracted text contradicts this agent's entire
  reason to exist.
- **The two-space indent is the only transform.** Every other byte, interior blank lines
  included, appears as it does in the source. A verbatim check is written by stripping this
  indent and diffing; nothing else may need undoing.

Two rules currently inside `## Output` (`:55-57`) are about what to report when there is
nothing to extract, not about layout. They move into `## Report`, immediately after the
`<summary>` template, unchanged in wording: a glob that matches files but no heading is
said in one line with nothing listed; a glob that matches nothing says that instead,
because the caller acts on the two differently.

## 5. `artifact-reviewer`'s report

`<summary>` is the verdict line followed by the blocking findings only:

```
SPEC: <B> blocking, <R> risk, <N> nit
<artifact> §<S>: 🔴 blocking: <one line>
```

`<detail>` is every finding at every tier, severity-ordered, **one line each**, in the form
the superseded Output block already showed:

```
<artifact> §<S>: 🔴 blocking: <one line>
<artifact> §<S>: 🟡 risk: <one line>
<artifact> §<S>: 🔵 nit: <one line>
<artifact> §<S>: ❓ question: <one line>
```

One line per finding is what makes two rounds of the same review diffable. Step 8 of
`design` re-runs this agent over a revised draft with an incremented `<NN>`, and the
question that round asks — what did my revision fix, and what did it not — is answerable by
`diff` only if a finding occupies one line both times. The report this agent actually
produced used `## 🔴 blocking` sections of bold-led prose paragraphs, which is not
diffable and is not what its own Output block specified.

Four rules currently inside `## Output` (`:63-68`) survive the replacement with named
destinations, unchanged in wording. Cite every finding by artifact section, and report every
tier including nits, are content rules for `<detail>` and move into `## Report` beside its
template. Say so in one line when the draft is clean moves there too, as the `<summary>`
form for a clean verdict. Never invent findings to justify the spawn is a boundary, not a
shape rule, and moves into `## Boundaries`.

## 6. Handoff frontmatter

Both agents currently write no frontmatter at all; every report produced on 2026-08-26
begins at line 1 with `<summary>`. The schema mandates it, and the single-subagent
exception does not excuse it — `:62-64` states the file schema and return contract "still
apply unchanged — only the *path* the report lands at differs."

Both agents therefore emit:

```markdown
---
agent: <chain-reader|artifact-reviewer>
seq: <NN>
task: <derived — see below>
created: <YYYY-MM-DD HH:MM:SS>
---
```

**`task:` is derived from the brief's existing fields, not from a new one.** No brief
carries a task field today — `distill/SKILL.md`, `design/SKILL.md`, and `plan/SKILL.md`
each pass only the fields their agent needs — and §2 changes no skill, so nothing may
depend on one appearing. Each agent composes the line from what it already receives:
`chain-reader` writes `extract "<heading>" from <glob>`; `artifact-reviewer` writes
`review <draft> against <authority>`. Both are functions of the brief as it stands.

**`created:` requires a clock, so `## Boundaries` is widened to permit one.** Both
Boundaries sections enumerate the allowed Bash exhaustively and close with "only" —
`chain-reader.md:24` permits `ls`, `git ls-files`, `git grep`; `artifact-reviewer.md:72`
adds `git log`. `date` is in neither, so as written the schema mandates a value the agent
is forbidden to obtain. Each Boundaries section gains `date` to that list, named
explicitly. This widens no capability that matters: `date` mutates nothing, reads no
repository state, and is required by the protocol this chain exists to conform to. The
alternative — dropping `created:` — would relax the schema, which §1 forbids.

**`session:` is omitted, as a stated interpretation.** The schema lists it, but
`context-handoff.md:93-95` says a flow taking the single-subagent exception "calls none of
`init`/`beat`/`end` and mints no session dir". Both agents take that exception. Omitting a
key whose referent does not exist is the only reading that neither invents an identifier
nor relaxes the schema; the alternative — writing `session: none` — asserts a value the
protocol never defines.

**`seq:` is the `<NN>` round counter already carried in the brief's report path.** The
exception (`:64-66`) has the caller assign each sequential round its own zero-padded path
counter; that number is the sequence this key names.

This interpretation is recorded here and flagged for the protocol's owner. Amending
`context-handoff.md` to settle it is out of scope (§10) — the protocol reaches seven other
agents, and a change there is its own chain.

## 7. What does not change

- The `<summary>`/`<detail>` split, the return contract, and the flat/leaf topology.
- What either agent extracts or judges: `chain-reader`'s refusal to group, count, rank, or
  interpret; `artifact-reviewer`'s criteria, severity tiers, and report-only boundary.
- Every user approval gate. No agent flips a `status` or commits, before or after.
- Every spawn brief in `distill`, `design`, and `plan`.

## 8. Verification

The deliverable is Markdown, so the Rust Definition of Done does not apply — the active
stack's guideline declares `match: ["**/*.rs", "**/Cargo.toml"]` and this chain touches
neither. Four checks apply.

1. **Plugin validity.** `cargo run -q -p claudevs-cli -- check plugins/claudestacks-sdlc`
   exits 0 with no `FAIL` line. Note what this does *not* cover: `claudevs` contains no
   agent-aware code beyond one doc comment at `crates/claudevs/src/wiring/refs.rs:6`, so it
   reads no agent frontmatter and validates no report. It catches a broken plugin, not a
   broken report shape.
2. **The shape is specified once per file.** For each agent definition, exactly one section
   describes its report file: `grep -c '^## Report$'` returns `1`, and `grep -c '^## Output'`
   returns `0`.
3. **The frontmatter is emitted.** A report produced by a live spawn opens with the block in
   §6: `sed -n '1p'` returns `---`, and `agent:`, `seq:`, `task:`, `created:` are all present
   before the first `<summary>`.
4. **The extraction is still verbatim.** `chain-reader`'s `<detail>` block for a known file,
   with the two-space indent stripped, `diff`s clean against
   `sed -n '/^## <heading>/,/^## /p'` over the source, minus that command's trailing
   boundary heading.

Three rules bind every check written against these reports, in this chain and in any later
one. They exist because the checks this chain was born from failed on shape before they
could test content:

- **Anchor structural greps.** `grep -c '^<summary>$\|^<detail>$'`, never the unanchored
  form — the unanchored one returned `3` against a report that discussed the schema in a
  finding.
- **Name the transform inside the check.** A verbatim check strips the mandated indent as an
  explicit step, so that a change to the indent fails the check rather than silently
  passing it.
- **Prove red before green.** Every check runs against a deliberately malformed report and is
  observed to fail before it is trusted green.

5. **The two checks this chain was born from are fixed, and discriminate.**
   `2026-08-25-sdlc-agent-tier/plans/01-foundations.md:564` asserts the anchored form
   (`grep -c '^<summary>$\|^<detail>$'` → `2`), and `plans/03-distill-wiring.md:198-206`
   diffs against the §4 shape rather than a `### <path>` heading that §4 does not produce.
   Each is run against a report known to be malformed and observed to fail before it is
   trusted — the rule below, applied to the two checks that motivated the rule.

Checks 3, 4, and the red half of 5 need a live spawn and are manual, recorded as manual.
Nothing here automates them and nothing claims to.

## 9. Rollout

The two agent edits are independent of each other — neither agent reads the other's
definition, and no skill changes — so they may land in one plan or two, in either order.

The two plan-file corrections depend on the agent edits, because `03-distill-wiring.md`'s
diff must be re-pointed at the shape §4 actually produces; re-pointing it first would leave
a check asserting a shape nothing emits yet. Order: agent definitions, then plan
corrections, then the manual checks.

Because the `## Report` sections are what the agents read at spawn time, the first spawn
after the edit is the first evidence it took — which is what checks 3, 4, and 5 are for.

## 10. Non-goals

- **Editing `context-handoff.md` or the suite-wide protocol.** It is sound on both counts
  that matter here: it pins the file schema, and it deliberately leaves the layout inside
  each tag to the agent. §6's `session:` reading is recorded as an interpretation for its
  owner, not applied as an edit.
- **The `claudestacks` plugin's agents** — `coder`, `reviewer`, `explorer`, and the four
  journal agents. They cite the same protocol and may share the frontmatter omission;
  nothing here has checked, and asserting it without evidence is what this repository's
  guidance forbids. A reason to look, in its own chain.
- **A machine-readable schema, or a parser, for agent reports.** Nothing parses them today.
  §5's one-line-per-finding rule serves `diff`, which is not the same commitment.
- **Changing what either agent extracts or judges.** §7.
- **Retrofitting the reports already written.** They live in `TMPDIR` and are disposable.
