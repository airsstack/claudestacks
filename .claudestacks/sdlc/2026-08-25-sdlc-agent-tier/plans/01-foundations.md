---
status: approved
created: 2026-08-26
---

# Agent Tier Foundations Implementation Plan

**Goal:** Establish the foundations the claudestacks-sdlc agent tier rests on — the criteria reference, the two agent definitions, and the context-handoff amendment that legitimizes their report path.

**Architecture:** Three new Markdown files under `plugins/claudestacks-sdlc/` (one reference, two agent definitions in a new `agents/` directory the plugin does not have today), plus a one-paragraph amendment to a reference owned by the `claudestacks` main plugin. The two agents are **leaves**: neither declares the `Agent` tool, so neither can spawn anything, and every report routes back to the skill on the main thread that spawned it. The criteria the reviewer applies live in the reference rather than inside the agent's own prose, so a skill can apply the identical criteria inline when the agent is unavailable — one copy, two consumers.

**Tech Stack:** Markdown with YAML frontmatter. Agent definitions are loaded by Claude Code's plugin agent loader from `<plugin>/agents/*.md`; `model:` and `effort:` are frontmatter-only dials. No code, no Lua, no Cargo changes.

**Content authority:** `.claudestacks/sdlc/2026-08-25-sdlc-agent-tier/spec.md` §1–§6 and §9. Each task below is a binding contract: the named elements MUST appear in the file, and the spec section named is the authority on their exact semantics.

**Verification convention, repeated at every task:** after the file change, run

```
$ cargo run -q -p claudevs-cli -- check plugins/claudestacks-sdlc
```

and confirm exit 0 with no `  FAIL  ` stage line. This wraps `claude plugin validate --strict` as its validate stage when the `claude` binary is present, and carries the deterministic checkers when it is not. Spec §9 check 1.

---

## File structure

```
plugins/claudestacks/skills/process-guidelines/references/context-handoff.md
    — [modify] the single-subagent exception admits round-numbered sequential re-spawns (spec §6.3)
plugins/claudestacks-sdlc/references/artifact-review.md
    — [create]  severity tiers + the two criteria sets, spec and plan-set (spec §5)
plugins/claudestacks-sdlc/agents/chain-reader.md
    — [create]  haiku/low verbatim section extractor over chain artifacts (spec §3)
plugins/claudestacks-sdlc/agents/artifact-reviewer.md
    — [create]  opus/high draft-artifact judge (spec §4)
plugins/claudestacks-sdlc/README.md
    — [modify] document the new agents/ directory and its two agents
```

`plugins/claudestacks-sdlc/agents/` does not exist; Task 3 creates it.

---

### Task 1 — Amend the context-handoff single-subagent exception

**Files:**
- Modify `plugins/claudestacks/skills/process-guidelines/references/context-handoff.md`

**Steps:**

1. Assert the amendment is absent — this is the failing-first check:

   ```
   $ grep -c "round" plugins/claudestacks/skills/process-guidelines/references/context-handoff.md
   0
   ```

   Exit status 1, count `0`. If this prints anything else, the file has already been amended; stop and re-read it before continuing.

2. The exception's closing sentence currently reads, at lines 59–61:

   ```
   below still apply unchanged — only the *path* the report lands at differs. A pipeline
   that spawns more than one subagent, or spawns them across turns, still MUST use the
   session tree; this exception does not extend to those cases.
   ```

   Replace the text from `A pipeline` through `does not extend to those cases.` with:

   ```
   A single-subagent flow may also re-spawn **sequentially** — a review repeated over a
   revised draft, say — provided the caller assigns each round its own path, for example a
   zero-padded round counter in the filename. The rounds do not overlap, so there is still
   nothing for a lease to arbitrate. What still MUST use the session tree is a pipeline
   that holds more than one subagent in flight at once, or that interleaves spawns of
   different agents whose reports refer to each other; this exception does not extend to
   those cases.
   ```

   Leave the preceding sentence (`below still apply unchanged — only the *path* the report lands at differs.`) exactly as it is.

3. Confirm green:

   ```
   $ grep -c "round counter" plugins/claudestacks/skills/process-guidelines/references/context-handoff.md
   1
   ```

4. Confirm the amendment did not disturb the other plugin's validity:

   ```
   $ cargo run -q -p claudevs-cli -- check plugins/claudestacks
   ```

   Exit 0, no `  FAIL  ` line.

5. Commit `docs(repo): admit round-numbered sequential re-spawns in the handoff exception`.

---

### Task 2 — Create the artifact-review criteria reference

**Files:**
- Create `plugins/claudestacks-sdlc/references/artifact-review.md`

**Steps:**

1. Assert absence:

   ```
   $ test -e plugins/claudestacks-sdlc/references/artifact-review.md; echo $?
   1
   ```

2. Write the file, complete:

   ````markdown
   # Artifact review criteria

   What a review of a draft chain artifact checks, by hop. Read by
   `claudestacks-sdlc:artifact-reviewer`, and by the calling skill directly when that agent
   is unavailable — this file is the single source, so the two can never drift.

   The reviewer reports; it never edits the artifact, never flips a `status`, never commits.
   The skill that spawned it fixes the draft and holds the user's approval gate.

   ## Severity

   | Emoji | Tier | Use for |
   |---|---|---|
   | 🔴 | blocking | a placeholder, a requirement with no coverage, a forward reference, or a contradiction that would produce wrong work |
   | 🟡 | risk | an ambiguity with a likely-but-unconfirmed reading, or a section whose root in the authority is weak |
   | 🔵 | nit | wording, ordering, or a body-shape deviation that changes nothing material |
   | ❓ | question | needs the author's intent before it can be judged |

   Report every finding at every tier, nits included. Completeness is the reviewer's job;
   deciding what is worth acting on belongs to the skill and the user.

   `.claudestacks/sdlc/REVIEW.md` does not govern here. That policy is for a code diff in the
   consuming repository, not for a chain artifact in this plugin.

   ## Reviewing a draft spec

   Authority: the chain's `intent.md`. Body shape: `templates.md` § `spec.md`.

   - **Placeholders** — no `TBD`, `TODO`, "to be determined", or vague deferral language.
     Either the gap is filled or the decision is made explicit.
   - **Internal consistency** — component names, data shapes, and behavioral descriptions
     agree throughout. A component described one way in the architecture section must match
     its description in the error-handling section.
   - **Scope** — focused enough to map to one coherent implementation cycle. Independent
     objectives woven together are a finding: they want decomposing before planning starts.
   - **Ambiguity** — anywhere the spec reads two ways. Name both readings.
   - **Intent tracing** — every section roots in the intent's problem or desired outcome. A
     section with no root is scope creep: it gets cut, or the intent itself has to grow.

   ## Reviewing a draft plan set

   Authority: the chain's `spec.md`, or its `intent.md` on the spec-skip path. Body shape:
   `templates.md` § `plans/NN-<topic>.md`. Review the **set**, not each plan alone — spec
   coverage is a property of the set: a requirement satisfied in plan `03` is covered even
   though plan `01` says nothing about it.

   - **Spec coverage** — every in-scope spec requirement (on the spec-skip path, every
     requirement stated in the intent) maps to a task somewhere across the set, or is
     explicitly deferred with a justification.
   - **Type consistency** — every type, signature, and constant used in Task N+1 was defined
     in an earlier task or already exists. A forward reference is a defect: reorder, or add
     the definition.
   - **Guideline conformance** — every code block scanned against the active stack
     guideline's architecture rules. If no guideline matches the stack, say so rather than
     skipping silently.
   - **No placeholders** — `TBD`, `TODO`, `implement later`; "add appropriate error handling
     / validation / edge cases" without naming them and showing the code; "write tests for
     the above" without the test code; a step saying *what* without showing *how*, with no
     code block, command, or expected output; a reference to a type, function, or constant
     defined neither earlier in the plan nor in the codebase.
   ````

3. Confirm every binding element is present:

   ```
   $ grep -c "^## Severity$\|^## Reviewing a draft spec$\|^## Reviewing a draft plan set$" plugins/claudestacks-sdlc/references/artifact-review.md
   3
   $ grep -c "Intent tracing\|Spec coverage\|Type consistency\|Guideline conformance" plugins/claudestacks-sdlc/references/artifact-review.md
   4
   ```

4. Run the verification convention:

   ```
   $ cargo run -q -p claudevs-cli -- check plugins/claudestacks-sdlc
   ```

   Exit 0, no `  FAIL  ` line.

5. Commit `feat(repo): add the artifact-review criteria reference to claudestacks-sdlc`.

---

> **CHECKPOINT — pause after Task 2.**
> The amendment and the criteria reference are both in the tree. Tasks 3 and 4 forward-reference this file by path and cite the round-numbered report path this amendment admits, so a defect here costs two agent-file rewrites if it is found later. Surface both diffs for review before continuing.

---

### Task 3 — Create the `chain-reader` agent

**Files:**
- Create `plugins/claudestacks-sdlc/agents/chain-reader.md` (creates the `agents/` directory)

**Steps:**

1. Assert absence:

   ```
   $ test -d plugins/claudestacks-sdlc/agents; echo $?
   1
   ```

2. Create the directory and write the file, complete:

   ````markdown
   ---
   name: chain-reader
   description: >
     Mechanical section extractor over claudestacks-sdlc chain artifacts. Given a
     glob and a heading, returns each match's content VERBATIM, tagged with the file
     it came from, and nothing else. Does not group, categorize, count, deduplicate,
     or judge. Use to pull one named section out of many chain files without loading
     their bodies into the main context.
   tools: [Read, Grep, Glob, Bash, Write]
   model: haiku
   effort: low
   ---

   You extract named sections from files. You return what is written, never what it means.

   ## What you do

   Your brief names two things: a **glob** and a **heading**. For every file the glob
   matches, find that heading and return the content beneath it — verbatim, unedited,
   un-summarized — tagged with the file's path. Stop at the next heading of the same or a
   higher level.

   Use `Glob` to enumerate, `Grep` to locate the heading, `Read` to pull the exact lines.
   `Bash` is read-only inspection (`ls`, `git ls-files`, `git grep`) only — never a mutating
   command.

   ## What you HARD-REFUSE

   You do not group, categorize, count, rank, deduplicate, summarize, or judge. That
   constraint is what keeps you cheap, and what keeps the semantic work on the thread that
   holds the user's dialogue. If asked to:

   - group extracted content into categories or themes,
   - count how often something recurs,
   - rank, prioritize, or recommend, or
   - assess whether anything you extracted is good, correct, or important,

   reply exactly: `Out of scope — I extract, I don't interpret. The calling skill does that.`
   and stop.

   ## Output (compact, no preamble, no prose)

   One block per match, in glob order, separated by a blank line:

   ```
   .claudestacks/sdlc/2026-08-24-sdlc-plugin/plans/03-workflow-skills.md
     ## Review findings
     <verbatim content beneath the heading>

   .claudestacks/sdlc/2026-07-10-auth-token/plans/02-refresh.md
     ## Review findings
     <verbatim content beneath the heading>
   ```

   If the glob matches files but none carries the heading, say so in one line and list
   nothing. If the glob matches no files at all, say that instead — those are different
   answers and the caller acts on them differently.

   ## Boundaries

   - Read-only toward the corpus: you have no `Edit`, and your `Write` is for your report
     file alone. You never modify a file you were pointed at.
   - You never flip an artifact `status` and you never run `git commit`.
   - You are a leaf: you have no `Agent` tool; do not attempt to spawn agents.

   ## Context handoff

   Your brief gives you a report write-path. Write your report there as ONE file built from
   two literal tags: `<summary>…</summary>` wrapping the cheap, scannable index — how many
   files the glob matched and how many carried the heading — and `<detail>…</detail>`
   wrapping the verbatim extraction itself. Return ONLY the `<summary>` plus that path, never
   the `<detail>`. Write ONLY that one file. If no path is given, or the write fails (say so),
   return the full extraction inline. The full protocol is the `claudestacks` plugin's
   `skills/process-guidelines/references/context-handoff.md`.
   ````

3. Confirm the frontmatter dials and the refusal line are present:

   ```
   $ grep -c "^model: haiku$\|^effort: low$" plugins/claudestacks-sdlc/agents/chain-reader.md
   2
   $ grep -c "I extract, I don't interpret" plugins/claudestacks-sdlc/agents/chain-reader.md
   1
   ```

4. Confirm the agent declares no `Agent` tool — the leaf invariant:

   ```
   $ grep "^tools:" plugins/claudestacks-sdlc/agents/chain-reader.md
   tools: [Read, Grep, Glob, Bash, Write]
   ```

5. Run the verification convention:

   ```
   $ cargo run -q -p claudevs-cli -- check plugins/claudestacks-sdlc
   ```

   Exit 0, no `  FAIL  ` line.

6. Commit `feat(repo): add the chain-reader agent to claudestacks-sdlc`.

---

### Task 4 — Create the `artifact-reviewer` agent

**Files:**
- Create `plugins/claudestacks-sdlc/agents/artifact-reviewer.md`

**Steps:**

1. Assert absence:

   ```
   $ test -e plugins/claudestacks-sdlc/agents/artifact-reviewer.md; echo $?
   1
   ```

2. Write the file, complete:

   ````markdown
   ---
   name: artifact-reviewer
   description: >
     Reviews a draft claudestacks-sdlc chain artifact — a spec, or a set of plans —
     against its upstream authority and the plugin's artifact-review criteria.
     Severity-tagged findings, report-only: never edits the artifact, never flips a
     status, never commits. Spawned by the design and plan skills at the intent→spec
     and spec→plan hops.
   tools: [Read, Grep, Glob, Bash, Write]
   model: opus
   effort: high
   ---

   You review a draft chain artifact. Judgment tier: read the authority yourself, judge the
   draft against it, report what you find. You never edit and you never decide — the skill
   that spawned you fixes the draft and holds the user's approval gate.

   ## First, load the criteria

   Read `${CLAUDE_PLUGIN_ROOT}/references/artifact-review.md` and apply the section matching
   your brief's `kind`. Read `${CLAUDE_PLUGIN_ROOT}/references/templates.md` for the body
   shape the artifact is supposed to have. Those files are the authority on what you check —
   do not substitute a checklist of your own.

   ## Your brief

   | Field | Meaning |
   |---|---|
   | `kind` | `spec` or `plan-set` |
   | `draft` | path(s) to the draft artifact(s) under review |
   | `authority` | `intent.md` for `kind: spec`; `spec.md`, or `intent.md` on the spec-skip path, for `kind: plan-set` |
   | `report` | the full write-path for your report |

   Read the authority in full before you read the draft. You are judging whether the draft
   answers what the authority asked for, and you cannot do that from the draft alone.

   For `kind: plan-set`, review the **set**. Spec coverage is a property of the set: a
   requirement satisfied in plan `03` is covered even though plan `01` says nothing about it.

   ## What you HARD-REFUSE

   - Editing the artifact you review. You report; the skill fixes.
   - Flipping any `status` frontmatter. `references/artifact-chain.md` §7.3 assigns that to
     the skill, after the user's explicit approval.
   - Running `git add`, `git commit`, or any other mutating command.
   - Spawning an agent. You are a leaf and have no `Agent` tool.

   Asked to do any of these, reply exactly:
   `Out of scope — I report on artifacts, I don't change them or their state.` and stop.

   ## Output (compressed, no preamble, no praise)

   Verdict line first, then findings, most severe first:

   ```
   SPEC: 2 blocking, 1 risk, 1 nit
   spec.md §4: 🔴 blocking: "error handling TBD" is a placeholder; the intent names three failure modes this section has to decide.
   spec.md §6: 🔴 blocking: the intent's constraint on cross-plugin degradation has no section.
   spec.md §3: 🟡 risk: "returns compact results" reads two ways — verbatim extraction, or a summary. Name which.
   spec.md §2: 🔵 nit: numbered §2 but referenced as §3 from §5.
   ```

   Cite every finding by artifact section — `spec.md §4`, `plans/02-foo.md Task 3`. A finding
   with no location is not actionable. Report every tier, nits included: completeness is your
   job, triage belongs to the skill and the user.

   If the draft is clean, say so in one line and report nothing further. Never invent findings
   to justify the spawn.

   ## Boundaries

   - `Bash` is read-only inspection (`ls`, `git ls-files`, `git grep`, `git log`) only.
   - `Write` exists solely to write your report file — never to touch the artifact.
   - You are a leaf: you have no `Agent` tool; do not attempt to spawn agents.

   ## Context handoff

   Your brief gives you a report write-path. Write your report there as ONE file built from
   two literal tags: `<summary>…</summary>` wrapping the verdict line plus the blocking
   findings — what the skill routes on — and `<detail>…</detail>` wrapping the full
   severity-ordered list with rationale. Return ONLY the `<summary>` plus that path, never the
   `<detail>`. Write ONLY that one file. If no path is given, or the write fails (say so),
   return the full report inline. The full protocol is the `claudestacks` plugin's
   `skills/process-guidelines/references/context-handoff.md`.
   ````

3. Confirm the frontmatter dials, the criteria load, and the refusal line:

   ```
   $ grep -c "^model: opus$\|^effort: high$" plugins/claudestacks-sdlc/agents/artifact-reviewer.md
   2
   $ grep -c 'references/artifact-review.md' plugins/claudestacks-sdlc/agents/artifact-reviewer.md
   1
   $ grep -c "I report on artifacts, I don't change them" plugins/claudestacks-sdlc/agents/artifact-reviewer.md
   1
   ```

4. Confirm the leaf invariant:

   ```
   $ grep "^tools:" plugins/claudestacks-sdlc/agents/artifact-reviewer.md
   tools: [Read, Grep, Glob, Bash, Write]
   ```

5. Run the verification convention:

   ```
   $ cargo run -q -p claudevs-cli -- check plugins/claudestacks-sdlc
   ```

   Exit 0, no `  FAIL  ` line.

6. Commit `feat(repo): add the artifact-reviewer agent to claudestacks-sdlc`.

---

> **CHECKPOINT — pause after Task 4.**
> Both agent definitions exist and the plugin still validates. Surface the two agent files for review before the README documents them and before the smoke test exercises them.

---

### Task 5 — Document the agent tier in the README

**Files:**
- Modify `plugins/claudestacks-sdlc/README.md`

**Steps:**

1. Assert absence:

   ```
   $ grep -c "artifact-reviewer" plugins/claudestacks-sdlc/README.md
   0
   ```

2. Insert a new `## Agents` section immediately **after** the `## Operational skills` section and **before** `## Attribution`:

   ```markdown
   ## Agents

   Two leaf agents ship under `agents/`, namespaced `claudestacks-sdlc:<name>`. Neither
   declares the `Agent` tool, so neither can spawn anything: the skill on the main thread
   does every spawn, receives every report, and holds every user gate. No agent flips an
   artifact `status` and no agent commits — `references/artifact-chain.md` §7.3 keeps both
   where they were.

   - **`chain-reader`** (haiku · low) — mechanical section extractor. Given a glob and a
     heading, returns each match's content verbatim, tagged with its file. It does not
     group, count, or judge; the calling skill does that. `distill` spawns it to pull
     `## Review findings` out of every plan in the chain root without loading the plan
     bodies into the main context.
   - **`artifact-reviewer`** (opus · high) — judges a draft `spec.md`, or a draft plan set,
     against its upstream authority and the criteria in `references/artifact-review.md`.
     Report-only, severity-tagged. `design` and `plan` spawn it in place of self-reviewing
     an artifact they just wrote themselves.

   The read-heavy locating steps in `design` and `plan` reuse `claudestacks:explorer` from
   the main plugin. That is a cross-plugin dependency, so it degrades: if the agent does not
   resolve, the skill does the work inline and says the agent was unavailable.
   ```

3. Confirm green:

   ```
   $ grep -c "chain-reader" plugins/claudestacks-sdlc/README.md
   1
   $ grep -c "artifact-reviewer" plugins/claudestacks-sdlc/README.md
   1
   $ grep -n "^## " plugins/claudestacks-sdlc/README.md | grep -A1 "Operational skills"
   ```

   The line after `## Operational skills` in that listing must be `## Agents`, and the line
   after `## Agents` must be `## Attribution`.

4. Run the verification convention:

   ```
   $ cargo run -q -p claudevs-cli -- check plugins/claudestacks-sdlc
   ```

   Exit 0, no `  FAIL  ` line.

5. Commit `docs(repo): document the claudestacks-sdlc agent tier in the README`.

---

### Task 6 — Smoke-test both agents against this chain's own artifacts

**Files:** none — this task changes no file and produces no commit.

**This task runs on the main thread, not inside a coder agent.** Plugin agents are leaves with no `Agent` tool, so a delegated implementer physically cannot perform a spawn. Whoever is driving the plan does these two spawns directly.

**Steps:**

0. Resolve the report directory first. An agent receives its brief as literal text and does
   not run a shell over it, so `${TMPDIR:-/tmp}` must be expanded by you before it goes into
   the brief:

   ```
   $ echo "${TMPDIR:-/tmp}"
   /var/folders/…/T/
   ```

   Use that expanded value wherever the briefs below write `<TMPDIR>`.

1. Spawn `claudestacks-sdlc:artifact-reviewer` with this brief:

   ```
   kind: spec
   draft: .claudestacks/sdlc/2026-08-25-sdlc-agent-tier/spec.md
   authority: .claudestacks/sdlc/2026-08-25-sdlc-agent-tier/intent.md
   report: <TMPDIR>/claudestacks-sdlc-2026-08-25-sdlc-agent-tier-spec-01.md
   ```

2. Confirm three things about what comes back:
   - it returned a `<summary>` plus the report path, **not** the full detail;
   - the report file exists and contains both a `<summary>` and a `<detail>` tag:

     ```
     $ grep -c "<summary>\|<detail>" "${TMPDIR:-/tmp}/claudestacks-sdlc-2026-08-25-sdlc-agent-tier-spec-01.md"
     2
     ```

   - the findings cite artifact sections (`spec.md §N`), not bare line numbers.

   The spec being reviewed here is already `approved`, so a clean verdict or a handful of
   nits are both correct outcomes. What is under test is the agent's contract, not the spec.

3. Spawn `claudestacks-sdlc:chain-reader` with this brief:

   ```
   glob: .claudestacks/sdlc/*/plans/*.md
   heading: ## Review findings
   report: <TMPDIR>/claudestacks-sdlc-corpus-findings-01.md
   ```

4. Confirm the extraction is verbatim and untransformed:

   ```
   $ grep -c "<summary>\|<detail>" "${TMPDIR:-/tmp}/claudestacks-sdlc-corpus-findings-01.md"
   2
   ```

   Then read the `<detail>` and check it against the source by hand for one matched file:

   ```
   $ sed -n '/^## Review findings/,/^## /p' .claudestacks/sdlc/2026-08-24-sdlc-plugin/plans/03-workflow-skills.md
   ```

   The extracted text must match this output. If the agent grouped, summarized, or
   re-worded anything, the definition's HARD-REFUSE section is not binding hard enough —
   fix `agents/chain-reader.md` and re-run before moving on.

   If no plan in the chain root carries a `## Review findings` heading yet, the agent must
   say so in one line rather than returning an empty extraction silently. That is the
   correct result and satisfies this step.

5. No commit — this task verifies, it does not change the tree.

---

## Verification summary (plan-level)

| Check | Command | Expected |
|---|---|---|
| Plugin validity, claudestacks-sdlc | `cargo run -q -p claudevs-cli -- check plugins/claudestacks-sdlc` | exit 0, no `  FAIL  ` line |
| Plugin validity, claudestacks | `cargo run -q -p claudevs-cli -- check plugins/claudestacks` | exit 0, no `  FAIL  ` line |
| Amendment landed | `grep -c "round counter" plugins/claudestacks/skills/process-guidelines/references/context-handoff.md` | `1` |
| Both agents leaf | `grep -h "^tools:" plugins/claudestacks-sdlc/agents/*.md` | neither line contains `Agent` |
| Criteria reference complete | `grep -c "Intent tracing\|Spec coverage\|Type consistency\|Guideline conformance" plugins/claudestacks-sdlc/references/artifact-review.md` | `4` |
| Agents spawnable | Task 6 | both return a `<summary>` plus a path |

No Lua is added, so `cargo make plugins` is unaffected. The Rust Definition of Done does
not apply — this plan touches no Rust.

**Deferred to sibling plans, by design:** every skill-file edit. `design` and `plan`
wiring is plan `02`; `distill` wiring is plan `03`. Until those land, the criteria in
`references/artifact-review.md` are duplicated by the still-inline checklists in
`skills/design/SKILL.md` and `skills/plan/SKILL.md`. That duplication is expected at the
end of this plan and is removed by plan `02` — spec §9 check 2 is that plan's assertion,
not this one's.
