---
status: done
created: 2026-08-25
depends-on: [01]
---

# claudestacks-sdlc Workflow Skills Implementation Plan

**Goal:** Ship the six workflow skill files — intent, design, plan, execute, distill, triage.

**Architecture:** One `SKILL.md` per skill under `plugins/claudestacks-sdlc/skills/<name>/`. Three of the six adapt the retired sdd skills (design ← `brainstorm`, plan ← `write-plan`, execute ← `execute-plan`) — this plan runs BEFORE plan 04 deletes `plugins/claudestacks-sdd/`, so the source files are still in the tree to adapt from; the other three (intent, distill, triage) are written fresh. Every skill resolves paths from `references/artifact-chain.md` (shipped by plan 01) and follows the common contract of spec §4.1.

**Tech Stack:** Markdown skill files with YAML frontmatter (`name`, `description`). No code.

**Content authority:** `.claudestacks/sdlc/2026-08-24-sdlc-plugin/spec.md` §4 (all subsections). Each task below is a binding contract: the named elements MUST appear in the file; the spec section named is the authority on their exact semantics. Where a task says "carry over from sdd", it means adapt the named sdd file's prose, keeping its discipline while applying the listed changes.

---

## File structure

```
plugins/claudestacks-sdlc/skills/intent/SKILL.md   — [create] problem capture, chain creation (spec §4.2)
plugins/claudestacks-sdlc/skills/design/SKILL.md   — [create] intent → spec dialogue (spec §4.3)
plugins/claudestacks-sdlc/skills/plan/SKILL.md     — [create] spec → NN plans with depends-on (spec §4.4)
plugins/claudestacks-sdlc/skills/execute/SKILL.md  — [create] plan → verified diff, state walk-up (spec §4.5)
plugins/claudestacks-sdlc/skills/distill/SKILL.md  — [create] findings → config edits (spec §4.6)
plugins/claudestacks-sdlc/skills/triage/SKILL.md   — [create] failure → intent (spec §4.7)
```

**Shared boilerplate every skill must carry** (spec §4.1) — write it in each file, tuned to that skill; do not factor it into a shared reference, because a skill file must instruct on its own when loaded:

- Resolve all paths from `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`; write artifacts in the body shapes of `${CLAUDE_PLUGIN_ROOT}/references/templates.md` (shipped by plan 01); lazy-create target directories before first write; never assume `/claudestacks-sdlc:setup` ran.
- Never auto-commit; the user commits.
- Flip frontmatter states only per the transitions table in `artifact-chain.md`, only as the last step of the interaction that earns the flip, only after explicit user approval in-dialogue.
- Guided dialogue: one question at a time, never a battery, multiple-choice where natural, lead with a recommendation, flexible on redirect. Ask only when the answer changes the artifact about to be written; derive the rest and state it as an overridable assumption. Every gate is a real stop presented as an explicit question.
- State-gate refusals name the file, its current state, and the command that advances it.

### Task 1 — `skills/intent/SKILL.md`

**Steps:**

1. Write the file, fresh. Frontmatter `name: intent`; `description` triggering on starting any new piece of work, capturing an idea, converting a PRD/RFC, or revisiting a parked intent ("use BEFORE designing or building anything new; also for parking ideas without committing to build them"). Body must carry, in this order:
   - Purpose: one chain per intent; an intent is a parked idea until picked up.
   - Input modes: rough idea; existing file conversion; re-invocation on an existing intent to approve / amend / drop / un-drop (state flips per the transitions table).
   - Input-doc scan: list `prds/` and `rfcs/`, surface relevant docs as a question; named-but-missing file → report path and ask, never guess; record seeds in the list-valued `derived-from-prd` / `derived-from-rfc` frontmatter.
   - Dialogue: 3–5 questions — problem, affected systems, desired outcome, constraints, why-now.
   - **Hard refusal — no solution content**: "how" drift (architecture, tech choices, file layouts) is cut to at most a one-line "candidate direction" note in the body, then steered back. Verbatim rule heading in the file: `## Hard gate — no solution content`.
   - Multi-scope check: a problem spanning independent subsystems is split into sibling chains before anything is written.
   - Spec-skip: on the user's choice, set `spec: skipped` in frontmatter plus a one-line reason in the body; the skill never proposes it for problems that plainly need design.
   - Output template: `intent.md` with frontmatter (`status`, `created`, optional provenance lists, optional `source`, optional `spec: skipped`) and body sections Problem / Affected systems / Desired outcome / Constraints / Non-goals.
   - Approval gate: explicit question; `draft → approved` only on yes; committing is the user's call.
2. Verify: file exists; frontmatter parses (`claude plugin validate plugins/claudestacks-sdlc --strict` passes); every bolded element above present on re-read.

### Task 2 — `skills/design/SKILL.md`

**Steps:**

1. Write the file by carrying over `plugins/claudestacks-sdd/skills/brainstorm/SKILL.md` with these changes (spec §4.3):
   - Frontmatter `name: design`; description re-targeted: "use when a chain's intent is approved and the design is not yet settled — turns an approved intent into an approved spec".
   - **Remove** problem-capture and idea-shaping language (intent owns it) and the sdd RFC-scan step; **replace** with: read the chain's `intent.md` (required input), load provenance-named docs, scan `rfcs/` for additional relevant input.
   - **State gate at the top**: refuse when intent is `draft` (name file, state, and that the intent skill advances it), `dropped`, or `done`.
   - **Keep**: explore project context; active-stack guideline loading via `enforcement.json` detection (the paragraph in brainstorm's "Honor the active stack's guidelines" carries over verbatim in substance); one-question-at-a-time dialogue; 2–3 approaches with recommendation; section-by-section presentation with per-section agreement; design-for-isolation; YAGNI; write-then-self-review; mandatory user review gate; no auto-commit.
   - **Self-review gains intent tracing**: every spec section roots in the intent's problem/outcome; rootless content is scope creep — cut it or take it back to the user.
   - **Output**: `spec.md` in the chain dir with `status: draft` frontmatter, flipped to `approved` at the gate. Redesign path: rename the governing spec to `spec-superseded-YYYY-MM-DD.md`, write a fresh `spec.md`.
   - **Hand-off**: the plan skill is the only next step.
2. Verify: as Task 1, plus: no reference to sdd paths (`.airsstack`, HOME store, `artifact-paths.md`) survives in the file.

### Task 3 — `skills/plan/SKILL.md`

**Steps:**

1. Write the file by carrying over `plugins/claudestacks-sdd/skills/write-plan/SKILL.md` with these changes (spec §4.4):
   - Frontmatter `name: plan`; description: "use when a chain's spec is approved (or its intent carries spec: skipped) and implementation plans are needed".
   - **Keep intact**: the TDD task format (failing test → confirm red → minimal code → confirm green → commit line), exact-paths/complete-code/no-forward-references/no-placeholders rules, file-structure-first mapping, 2–5 minute task granularity, standalone-plan property, one-objective scope guard ("a goal sentence needing 'and' splits the plan"), guideline conformance per code block, the before-saving three-axis check (spec coverage, type consistency, guideline conformance).
   - **State gate**: input is a chain whose `spec.md` is `approved`, or whose intent is `approved` with `spec: skipped`; refuse anything else, naming file/state/advancing command. The skill never sets `spec: skipped` itself.
   - **Fan-out is first-class**: propose the plan set and dependency shape in dialogue before writing ("N plans: 01 …, 02 …; 02 independent of 01 — agree?"); ask where checkpoint boundaries go. Files are `plans/NN-<kebab-topic>.md`; frontmatter carries `status`, `created`, `depends-on` (list of plan numbers, absent/empty = independent).
   - **Lifecycle**: plans are superseded, never deleted; a replacement takes the next free `NN`. Remove every reference to sdd's `artifact-lifecycle.md`, the `_archive/` directory, and plan deletion.
   - **Naming**: chain-relative, replacing sdd's `YYYY-MM-DD-<topic>.md` plan naming.
   - **Execution handoff**: recommend committing approved plans before execution so worktrees read them from git; the execute skill is the next step.
2. Verify: as Task 1, plus no sdd-path or deletion-lifecycle reference survives.

### Task 4 — `skills/execute/SKILL.md`

**Steps:**

1. Write the file by carrying over `plugins/claudestacks-sdd/skills/execute-plan/SKILL.md` with these changes (spec §4.5):
   - Frontmatter `name: execute`; description: "use when a chain has an approved plan to carry out — executes it task by task with review checkpoints and walks chain states up on completion".
   - **Keep intact**: load-and-critique before any change; TodoWrite ledger; protected-branch safety guard (stop on `main`/`master` without explicit consent); soft-coupling to `claudestacks:orchestrate` with graceful inline degradation ("never fail hard for want of the main plugin"); per-task loop with verifications and evidence; checkpoint boundaries as hard stops; when-to-stop-and-ask rules; user commit gate at completion.
   - **Input by reference**: `<chain>/<NN>` (e.g. `2026-08-24-sdlc-plugin/01`). State gate: refuse a plan not `approved` (name file/state/advancing command); when `depends-on` names a plan not `done`, warn and ask before proceeding.
   - **State flips**: plan `approved → executing` at task 1 (mechanical, no question); `executing → done` only after the completion report is accepted by the user.
   - **Findings durability**: before flipping `done`, append `## Review findings` to the plan file — the reviewer's Important findings, one line each (`category — description — where`); on the inline-degraded path write `inline execution, no independent reviewer` plus anything verification surfaced.
   - **Deviation record**: departures from the plan are appended as a dated `## Deviations` section before `done`.
   - **Walk-up**: after the plan flips `done`, check the chain: all plans `done`/`superseded` with at least one `done` → flip the intent to `done` and tell the user the chain is complete.
2. Verify: as Task 1, plus the four new behaviors (reference input, findings section, deviations section, walk-up) each present.

### Task 5 — `skills/distill/SKILL.md`

**Steps:**

1. Write the file, fresh (spec §4.6). Frontmatter `name: distill`; description: "use after chains complete to turn recurring review findings into agent-config edits — the same-mistake-twice loop". Body must carry:
   - Input: the `## Review findings` sections of plan files across chains under `.claudestacks/sdlc/` — durable, no session memory needed.
   - Recurrence rule: propose only findings whose category appears in **≥ 2 chains**; every proposal cites both occurrences (`chain/plan` each).
   - Per-proposal dialogue: the finding, where it recurred, one concrete minimal edit (a line in the target repo's `CLAUDE.md`, or a change to a skill file) — accept / edit / skip, one at a time.
   - On accept: apply the edit; the user commits. When the edit touches a plugin in this suite, remind the user to run `cargo make claudevs-check` and `cargo make plugins` before committing.
   - Hard rules: never edit config without a per-proposal accept; never propose from a single occurrence; nothing else in the repo is touched.
2. Verify: as Task 1.

### Task 6 — `skills/triage/SKILL.md`

**Steps:**

1. Write the file, fresh (spec §4.7). Frontmatter `name: triage`; description: "use when something broke and there is evidence — a CI log, an advisory, a backtrace — to convert into a triaged intent entering the normal pipeline". Body must carry:
   - Input: pasted log, file path, or description. Manual invocation only (headless CI wiring is explicitly out of scope; say so in the file).
   - Deterministic correlation first: check what is checkable before asking anything — `git log` for whether relevant paths changed, the file/command the evidence names. State conclusions as overridable assumptions.
   - Short evidence-seeded dialogue: usually 1–2 questions to shape the desired outcome.
   - Output: a normal chain (`YYYY-MM-DD-<topic>/intent.md`) with `source: triage`, `status: draft`, and the **evidence quoted verbatim in the body at full precision** — exact error text, exact commands, never paraphrased. Body sections as the intent skill's template, plus an Evidence section.
   - Downstream: none — the intent enters the same queue; the intent skill handles approval later.
2. Verify: as Task 1.

### Task 7 — Validate and commit

**Steps:**

1. Validate the plugin end to end:

   ```
   $ claude plugin validate plugins/claudestacks-sdlc --strict
   ```

   Expected: passes with six skills, two commands.

2. Cross-check: grep the six new files for leftovers of the old workflow —

   ```
   $ grep -rn "airsstack\|artifact-paths\|write-plan\|execute-plan\|brainstorm\|_archive" plugins/claudestacks-sdlc/skills/
   ```

   Expected: no matches (the skills reference `artifact-chain.md` and each other by their new names only).

3. Commit:

   ```
   $ git add plugins/claudestacks-sdlc/skills
   $ git commit -m "feat(repo): six workflow skills for claudestacks-sdlc"
   ```

---

## Verification summary (plan-level)

- `claude plugin validate … --strict` passes with all six skills present.
- Contract re-read per file: every element the task names appears.
- The leftovers grep returns nothing.

---

## Review findings

Two independent `claudestacks:reviewer` passes, 2026-08-25. All six skills delivered
against their task contracts; three defects found, all fixed and re-verified. Final
gates: `claude plugin validate --strict` passed · `cargo make plugins` 278 passed,
0 failed (17 files) · leftovers grep across all eight skills exit 1, no matches.

**Important — fixed.**

1. compliance — `skills/plan/SKILL.md` carried **none** of this plan's binding
   guided-dialogue boilerplate (:30-35): no one-question-at-a-time, no never-a-battery,
   no multiple-choice, no overridable-assumption rule. Every other workflow skill
   carried it. It also lacked spec §4.1:202's sharpening specific to `plan` — raise
   every spec ambiguity as a question, never resolve one as an assumption. Both added,
   and confirmed on re-review as genuinely tuned to `plan` rather than pasted from a
   sibling.
2. correctness — `skills/design/SKILL.md` renamed a superseded spec to
   `spec-superseded-YYYY-MM-DD.md` per `artifact-chain.md` §4 but never flipped its
   frontmatter, so the archived file would have read `status: approved` forever. §7.2
   assigns that transition to `design`.
3. correctness — `skills/distill/SKILL.md` cited `artifact-chain.md` and `templates.md`
   as owning the `## Review findings` line shape. Neither defines it; the only
   definition is in `execute/SKILL.md`, the skill that writes it (spec §4.5.3). Since
   those sections are distill's entire input, it now cites where the shape is actually
   defined, and states positively what each reference does and does not own.

**Clean on both passes.** `intent`, `execute`, `triage` — every contract element
present, including the verbatim `## Hard gate — no solution content` heading. All eight
skills cross-reference each other by the new names only; no sdd path, `_archive/`, or
plan-deletion language survives anywhere.

**Nit — accepted, not fixed.** One design hand-off item judged not trivially safe to
change late; the rest batched. `claude plugin validate --strict` was demoted as evidence
throughout: its output is a single line naming `plugin.json`, so it opens no skill file
and vouches for none of this plan's prose. The real gate was per-element contract
re-reading.

## Deviations

- **Task 7's expected result was stale on arrival.** It predicted validate "passes with
  six skills, two commands". No `commands/` directory exists in this plugin — `setup`
  and `status` are skills, per the amendment to spec §3 and §5 made the day plan 01
  closed. The gate passes; only the prediction was written against the old layout.
- **Task 7's leftovers grep was run scoped, then whole-directory.** Its literal form
  sweeps all of `skills/`, but three coders were writing there concurrently, so each ran
  it over its own files and the full sweep ran once at the end. Same coverage, no
  mid-flight false positives.
- **`design` drops sdd `brainstorm`'s multi-scope-assessment step.** Spec §4.2:223
  assigns the multi-scope check to `intent`, §4.3 never mentions it, and this plan's
  Task 2 omits it from **Keep intact** while its **Remove** clause covers problem-shaping
  language. Verified against all three sources before accepting.
- **A documentation precision gap was found and left unfixed, deliberately.**
  `artifact-chain.md:131` (reproducing spec §2.4) attributes the intent `— → draft`
  transition to `intent` alone, but spec §4.7 has `triage` writing a fresh `intent.md`
  at `status: draft`. So `triage` is an unlisted second writer of that transition.
  Documentation only — nothing derives behaviour from the "Flipped by" column — and it
  reproduces an approved spec faithfully, so patching the reference alone would conceal
  the divergence rather than close it. Raised for the author; the same call taken on
  plan 01's finding 4.
- **Task 7 (commit) not executed.** The user holds the commit gate; no agent commits.
