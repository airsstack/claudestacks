---
status: approved
created: 2026-08-26
---

# Spec: an agent tier for the claudestacks-sdlc workflow skills

This spec adds a delegation tier to `claudestacks-sdlc`: two leaf agents owned by this
plugin, plus wiring that routes three read-heavy skill steps and two artifact-review hops
through agents instead of the main thread. Read-heavy steps return compact results rather
than the file bodies they read, and a draft spec or draft plan set is judged by a reader
that did not hold the dialogue which produced it. No stage is delegated, no user approval
gate moves, and no chain artifact, frontmatter key, or state changes.

## 1. Design premises

Four premises govern every later section. Each traces to a constraint in `intent.md`.

**1.1 The tier is leaf-only.** Neither new agent declares the `Agent` tool. The skill
running on the main thread performs every spawn, receives every report, and holds every
user gate. This is `claudestacks:orchestrate`'s flat/leaf invariant, and it is the reason a
report can never bypass the user.

**1.2 Delegation applies to steps, never to stages.** A subagent receives one prompt and
returns one report; it never gets a user turn. `design`, `plan`, and `distill` are built on
multi-turn dialogue with approval gates, so each keeps its full dialogue contract: one
question at a time, confirmation after each non-trivial section, and a mandatory approval
stop. What moves into an agent is a bounded step within a stage.

**1.3 Both new agents are owned by `claudestacks-sdlc`.** `artifact-reviewer` must read
`${CLAUDE_PLUGIN_ROOT}/references/artifact-review.md` and
`${CLAUDE_PLUGIN_ROOT}/references/templates.md`, and that variable resolves per owning
plugin — an agent shipped in the `claudestacks` main plugin cannot reach this plugin's
references through it. `plugins/claudestacks-sdlc/agents/` is a new directory; the plugin
has none today.

**1.4 Cross-plugin reuse is soft-coupled; own-plugin use is not.** `claudestacks:explorer`
belongs to a separately-installed plugin and may be absent, so every call site carries a
degradation clause. The two new agents ship inside the plugin whose skills call them, so
their resolution is not a failure mode — but the criteria they apply live in a reference
file rather than inside agent prose, so an inline path remains possible and there is
exactly one copy of the criteria.

## 2. Why two agents rather than one

The delegated work splits into two jobs at different judgment tiers, and
`process-guidelines/references/model-routing.md` forbids one tier serving both.

Mechanical extraction from the chain corpus reads nothing to decide what to do — it
locates a heading and returns what is under it. That is inside the Haiku boundary, which
`model-routing.md:25` opens to work "where nothing turns on code logic, design, or review
judgment". Judging a draft artifact against its upstream authority is review work, and
`model-routing.md:33` states: "Never downgrade review, debug, analyze, or design below
Opus to save tokens."

A single agent with a `mode=` parameter cannot serve both, because `model:` and `effort:`
are frontmatter fields on the agent definition and `effort:` has no per-spawn override
(`model-routing.md:20-21`) — one frontmatter would have to run a grep-and-extract at Opus
or run review judgment at Haiku. Two jobs, two tiers, two agents.

A third candidate — code locating over the repository's source tree — needs no new agent
at all: `claudestacks:explorer` already does exactly that and is reused as-is.

`explorer` cannot, however, absorb the chain-corpus extraction. Its output contract is a
`file:line` table with "no commentary, no summary, no judgment"
(`plugins/claudestacks/agents/explorer.md:51`), so it can name where a
`## Review findings` heading sits but cannot return what is under it. `distill` would
still read every plan body on the main thread, which is the cost that grows with the
repository.

## 3. Component: `claudestacks-sdlc:chain-reader`

New file `plugins/claudestacks-sdlc/agents/chain-reader.md`.

**Dials.** `model: haiku`, `effort: low`.

**Tools.** `[Read, Grep, Glob, Bash, Write]`. `Bash` is read-only inspection (`ls`,
`git ls-files`, `git grep`); `Write` exists solely to write the report file of §6.

**Contract.** The brief names a glob and a heading. The agent returns each match's content
**verbatim**, tagged with the `chain/plan` path it came from, and nothing else. It does not
group, categorize, count, deduplicate, or judge. Holding it to verbatim extraction is what
keeps it inside the Haiku boundary; grouping findings into categories is semantic judgment
and stays on the main thread, where `distill`'s recurrence rule already lives.

**Output shape.**

```
.claudestacks/sdlc/2026-08-24-sdlc-plugin/plans/03-workflow-skills.md
  ## Review findings
  <verbatim section content>

.claudestacks/sdlc/2026-07-10-auth-token/plans/02-refresh.md
  ## Review findings
  <verbatim section content>
```

**Hard refusals.** Asked to categorize, rank, judge, or recommend, it replies with a fixed
refusal line and stops, in the pattern `explorer.md:36` establishes. It never edits a file,
never flips a `status`, never commits, and never spawns an agent.

**Callers.** `distill` only. The contract is stated generally because a heading-extractor
is simpler to specify generally than to special-case, not because a second caller is
anticipated.

## 4. Component: `claudestacks-sdlc:artifact-reviewer`

New file `plugins/claudestacks-sdlc/agents/artifact-reviewer.md`.

**Dials.** `model: opus`, `effort: high`.

**Tools.** `[Read, Grep, Glob, Bash, Write]`. Same read-only `Bash` restriction and same
report-only use of `Write` as §3.

**Brief.** Four values, all assigned by the calling skill:

| Field | Value |
|---|---|
| kind | `spec` or `plan-set` |
| draft | path(s) to the draft artifact(s) under review |
| authority | `intent.md` for `kind: spec`; `spec.md`, or `intent.md` on the spec-skip path, for `kind: plan-set` |
| report | the full write-path of §6 |

**Behavior.** It loads `${CLAUDE_PLUGIN_ROOT}/references/artifact-review.md` and applies
the criteria section matching `kind`, plus `${CLAUDE_PLUGIN_ROOT}/references/templates.md`
for body-shape conformance. It reads the authority artifact to judge the draft against what
was actually asked for. It returns severity-tagged findings.

**Severity tiers.** The suite's existing tiers from
`plugins/claudestacks/agents/reviewer.md`, remapped to artifact defects:

| Emoji | Tier | Use for |
|---|---|---|
| 🔴 | blocking | a placeholder, a requirement with no coverage, a forward reference, or a contradiction that would produce wrong work |
| 🟡 | risk | an ambiguity with a likely-but-unconfirmed reading, or a section whose root in the authority is weak |
| 🔵 | nit | wording, ordering, body-shape deviation that changes nothing material |
| ❓ | question | needs the author's intent before it can be judged |

`REVIEW.md` (`references/review-policy.md`) is deliberately not used here: that policy
governs review of a code diff in the consuming repository, not review of a chain artifact
in this plugin.

**Set-level review.** Spec coverage is a property of the plan *set* — "every in-scope spec
requirement maps to a task across the plan set". So `plan` spawns one reviewer over the
whole draft set, not one per plan. Per-plan approval gates are unchanged.

**Hard refusals.** It never edits the artifact it reviews, never flips a `status`, never
commits, and never spawns an agent. The skill fixes the draft, which keeps the fix — like
the approval — on the thread the user is talking to.

## 5. Component: `references/artifact-review.md`

New file `plugins/claudestacks-sdlc/references/artifact-review.md`. It is the single
source of the artifact-review criteria, read by `artifact-reviewer` and by the inline
fallback path of §8. It holds two sections, because the two hops check different things.

**5.1 Reviewing a draft spec** (moved verbatim in substance from
`skills/design/SKILL.md:87-99`, then deleted from that file):

- **Placeholders** — no `TBD`, `TODO`, "to be determined", or vague deferral language.
- **Internal consistency** — component names, data shapes, and behavioral descriptions
  agree throughout the document.
- **Scope** — one coherent implementation cycle; independent objectives woven together are
  a finding.
- **Ambiguity** — anywhere the spec reads two ways.
- **Intent tracing** — every section roots in the intent's problem or desired outcome;
  anything without a root is scope creep.

**5.2 Reviewing a draft plan set** (moved from `skills/plan/SKILL.md:186-210` — the
`## No placeholders` block at `:186-196` and the `## Before saving` block at `:198-210` —
then
deleted from that file):

- **Spec coverage** — every in-scope spec requirement (or, on the spec-skip path, every
  requirement in the intent) maps to a task across the set, or is explicitly deferred with
  a justification.
- **Type consistency** — every type, signature, and constant used in task N+1 was defined
  in an earlier task or already exists. A forward reference is a defect.
- **Guideline conformance** — every code block scanned against the active stack guideline's
  architecture rules. If no guideline matches the stack, say so rather than skipping
  silently.
- **No placeholders** — the plan-specific list: `TBD`/`TODO`/"implement later"; "add
  appropriate error handling" without naming it and showing the code; "write tests for the
  above" without the test code; a step saying *what* without showing *how*; a reference to
  a type, function, or constant defined neither earlier in the plan nor in the codebase.

## 6. Data flow and report paths

Each skill invocation spawns at most one agent at a time. An agent returns its `<summary>`
plus the report path; the skill pulls `<detail>` only when it must act on the findings.
The `<summary>`/`<detail>` file schema and the return contract of
`plugins/claudestacks/skills/process-guidelines/references/context-handoff.md` apply
unchanged.

**6.1 Wiring.**

```
design  step 3 (explore project context)
          ──▶ claudestacks:explorer            (soft-coupled)  file:line tables
        step 8 (was: self-review the spec)
          ──▶ claudestacks-sdlc:artifact-reviewer
                kind: spec        draft: spec.md        authority: intent.md

plan    §"File structure first"
          ──▶ claudestacks:explorer            (soft-coupled)  file:line tables
        §"Before saving"
          ──▶ claudestacks-sdlc:artifact-reviewer
                kind: plan-set    draft: plans/NN-*.md  authority: spec.md | intent.md

distill §"Input"
          ──▶ claudestacks-sdlc:chain-reader
                glob: .claudestacks/sdlc/*/plans/*.md   heading: "## Review findings"
```

**6.2 Report path.** Reports land at

```
${TMPDIR:-/tmp}/claudestacks-sdlc-<chain>-<kind>-<NN>.md
```

where `<chain>` is the chain directory name, `<kind>` is `spec`, `plan-set`, or
`findings`, and `<NN>` is a zero-padded round counter the calling skill assigns and
increments on each re-spawn within the same chain and kind.

`distill`'s scan is not chain-scoped — it spans every chain in the root — so it
substitutes the literal `corpus` for `<chain>`, giving
`claudestacks-sdlc-corpus-findings-01.md`. The four-part shape is preserved rather than
gaining a second form.

The calling skill expands `${TMPDIR:-/tmp}` itself before the path enters an agent's
brief. An agent receives its brief as literal text and runs no shell over it, so an
unexpanded variable would reach it as a filename.

This extends the single-subagent exception at `context-handoff.md:51-61` rather than
minting a handoff session. The exception as written stops short of a flow that spawns
across turns, which `design` does when step 9 re-reviews a revised spec. The round counter
supplies what the session tree's lease and pruning exist to supply — collision-free paths
for sequential reports — without a dependency on
`plugins/claudestacks/scripts/lib/handoff.lua`, which lives in a separately-installed
plugin and is not reachable through this plugin's `${CLAUDE_PLUGIN_ROOT}`.

**6.3 Amendment to `context-handoff.md`.** The exception's closing sentence
(`context-handoff.md:59-61`, "A pipeline that spawns more than one subagent, or spawns
them across turns, still MUST use the session tree; this exception does not extend to
those cases.") is amended to admit sequential re-spawns of a single-subagent flow when the caller assigns a
round-numbered path, and to keep requiring the session tree for concurrent multi-agent
pipelines. This edits a file owned by the `claudestacks` main plugin; the change is
in-scope because the round-numbered path is otherwise a silent divergence from a protocol
this plugin claims to follow.

## 7. Skill edits

| File | Edit |
|---|---|
| `skills/design/SKILL.md` | Step 3 gains the `explorer` delegation and its degradation clause. Step 8 is rewritten to spawn `artifact-reviewer`; its inline criteria list moves to `references/artifact-review.md` §5.1 and is deleted here. |
| `skills/plan/SKILL.md` | §"File structure first" gains the `explorer` delegation and its degradation clause. §"Before saving" is rewritten to spawn `artifact-reviewer` over the draft set; its three-axis criteria and the "No placeholders" list move to `references/artifact-review.md` §5.2 and are deleted here. |
| `skills/distill/SKILL.md` | §"Input" is rewritten to spawn `chain-reader` for the corpus scan. The recurrence rule, the two-chain threshold, and the per-proposal dialogue are untouched — they operate on the extraction, on the main thread. |
| `README.md` | Documents the new `agents/` directory and the two agents. |

`skills/execute/SKILL.md`, `skills/intent/SKILL.md`, `skills/setup/SKILL.md`,
`skills/status/SKILL.md`, and `skills/triage/SKILL.md` are not edited.

## 8. Error handling

| Failure | Behavior |
|---|---|
| `claudestacks:explorer` does not resolve | Do the locating inline on the main thread and tell the user the agent was unavailable. Never fail hard. Matches `skills/execute/SKILL.md:55-64`. |
| `artifact-reviewer` returns nothing usable | The skill applies the §5 criteria inline and states that the review ran inline. The reference file is what makes this possible. |
| An agent's report write fails | The agent returns its full report inline and says the write failed. Already the rule at `context-handoff.md:106`. |
| `chain-reader` matches no heading anywhere | It returns an empty extraction; `distill` reports that there is no findings corpus yet — unchanged from its behavior on an empty scan today. |
| An agent is asked to edit, flip a `status`, or commit | Hard-refuse with a fixed line and stop, in the pattern of `explorer.md:36`. |

The invariant beneath all five: an agent's report is input to the skill's dialogue, never a
substitute for it. Every transition in `artifact-chain.md` §7.2 fires exactly where it
fires today, after the same explicit user approval, flipped by the same skill.

## 9. Verification

The deliverable is Markdown, so the Rust Definition of Done does not apply to it. Three
checks do.

All three are **development-time gates run in this repository**, not anything the plugin
ships or asks of a consumer. `claudevs-cli` is a workspace member here and is never
invoked by a hook, script, or skill in `plugins/claudestacks-sdlc`; the plugin's only
binary dependency at runtime is `airsl`, and `scripts/status.sh` degrades to the `status`
skill's model fallback when even that is absent. Installing the plugin requires no Rust
toolchain.

1. **Plugin validity.** `cargo run -q -p claudevs-cli -- check plugins/claudestacks-sdlc`
   must exit 0. This exercises the validate stage (`claude plugin validate --strict`, when
   `claude` is present), the wiring stage, and the deterministic checkers over the plugin,
   including the frontmatter of both new agent files. Invocation shape per
   `Makefile.toml:209`.
2. **The criteria moved rather than duplicated.** Grep assertions: the placeholder,
   internal-consistency, scope, ambiguity, and intent-tracing criteria appear in
   `references/artifact-review.md` and no longer in `skills/design/SKILL.md`; the spec-
   coverage, type-consistency, guideline-conformance, and no-placeholders criteria appear
   in `references/artifact-review.md` and no longer in `skills/plan/SKILL.md`.
3. **Dogfood, manual.** Run `/claudestacks-sdlc:design` and `/claudestacks-sdlc:distill` in
   this repository and confirm the spawns occur, the reports land at the §6.2 path, and the
   user gates still stop. This check is manual and is recorded as manual — it is not
   automated by this chain.

No Lua is added, so `cargo make plugins` is unaffected.

## 10. Non-goals

- **An agent per workflow stage.** Ruled out by premise 1.2.
- **Changing how `execute` runs.** It keeps routing code work through
  `claudestacks:orchestrate` → coder → reviewer. Nothing here touches code-diff review or
  the Definition of Done.
- **Moving, renaming, or re-scoping `claudestacks:explorer`, `coder`, or `reviewer`.** They
  stay owned by the `claudestacks` main plugin as they are. The only edit to that plugin is
  the `context-handoff.md` amendment of §6.3.
- **Reviewing `intent.md` drafts.** The two hops are intent→spec and spec→plan; the
  `intent` skill is not edited.
- **New chain artifacts, frontmatter keys, or states.** `artifact-chain.md` §6 and §7 are
  unchanged.
- **A retention or pruning story for the §6.2 report path.** Reports are ephemeral files
  under `${TMPDIR}`; the operating system's temp cleanup is the retention policy.
- **A second caller for `chain-reader`.** `distill` is the only wired caller.
- **Anything in `plugins/claudestacks-sdd/`.** Its deletion belongs to plan 04 of the
  `2026-08-24-sdlc-plugin` chain.
