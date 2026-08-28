---
status: done
created: 2026-08-26
depends-on: [01]
---

# Design and Plan Skill Wiring Implementation Plan

**Goal:** Wire the `design` and `plan` skills to the agent tier — `claudestacks:explorer` for their locating steps, `claudestacks-sdlc:artifact-reviewer` for their artifact-review hops.

**Architecture:** Two skill files, four edits, no new files. Each skill gains one *additive* edit (a delegation clause on a locating step, which changes no existing rule) and one *substitutive* edit (an artifact-review step that replaces an inline self-review checklist with an agent spawn, deleting the checklist because plan `01` already moved it to `references/artifact-review.md`). The substitutive edits are the ones spec §9 check 2 asserts: the criteria must end up in exactly one place, not two. Every user approval gate in both skills is untouched — an agent reports, the skill still stops and asks.

**Tech Stack:** Markdown skill files with YAML frontmatter. No code, no Lua, no Cargo changes.

**Content authority:** `.claudestacks/sdlc/2026-08-25-sdlc-agent-tier/spec.md` §6.1, §6.2, §7, §8, §9. Each task below is a binding contract: the named elements MUST appear in the file, and the spec section named is the authority on their exact semantics.

**Depends on plan `01`** for `plugins/claudestacks-sdlc/references/artifact-review.md` and `plugins/claudestacks-sdlc/agents/artifact-reviewer.md`. Tasks 2 and 4 delete criteria from a skill file and point at that reference; running them before `01` lands leaves the skills pointing at a file that does not exist.

**Verification convention, repeated at every task:** after the file change, run

```
$ cargo run -q -p claudevs-cli -- check plugins/claudestacks-sdlc
```

and confirm exit 0 with no `  FAIL  ` stage line. Spec §9 check 1.

---

## File structure

```
plugins/claudestacks-sdlc/skills/design/SKILL.md
    — [modify] step 3 gains explorer delegation (Task 1); step 8 becomes an agent spawn (Task 2)
plugins/claudestacks-sdlc/skills/plan/SKILL.md
    — [modify] "File structure first" gains explorer delegation (Task 3);
               "No placeholders" + "Before saving" become an agent spawn (Task 4)
```

Two files, four tasks, each task owning one section. No task touches a section another
task touches.

---

### Task 1 — Delegate `design` step 3's locating to `explorer`

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/design/SKILL.md`

**Steps:**

1. Assert the delegation is absent — failing-first:

   ```
   $ grep -c "explorer" plugins/claudestacks-sdlc/skills/design/SKILL.md
   0
   ```

   Exit status 1, count `0`.

2. Step 3 currently reads, at lines 55–57:

   ```
   3. **Explore project context.** Read relevant files, docs, and recent commits to
      understand the codebase, its conventions, and what already exists. Do not design in
      a vacuum. **Detect the active stack** and load its guideline now — see below.
   ```

   Leave those three lines exactly as they are and append a new indented paragraph
   immediately after them, inside step 3:

   ```markdown
      Delegate the locating half. When the exploration is broad — mapping an unfamiliar
      directory, sweeping for every use of a symbol, finding which files own a behavior —
      spawn `claudestacks:explorer` and work from the `file:line` tables it returns instead
      of reading those files into this thread. Read directly only what you must actually
      judge: a guideline, a convention you are about to follow, a file whose contents decide
      the design. If `claudestacks:explorer` does not resolve — the `claudestacks` main
      plugin is not installed — do the locating inline here and tell the user the agent was
      unavailable. Never fail hard for want of the main plugin.
   ```

3. Confirm green:

   ```
   $ grep -c "claudestacks:explorer" plugins/claudestacks-sdlc/skills/design/SKILL.md
   2
   $ grep -c "Never fail hard for want of the main plugin" plugins/claudestacks-sdlc/skills/design/SKILL.md
   1
   ```

4. Confirm step 3 is still step 3 and the numbering did not shift:

   ```
   $ grep -n "^3\. \*\*Explore project context\.\*\*" plugins/claudestacks-sdlc/skills/design/SKILL.md
   55:3. **Explore project context.** Read relevant files, docs, and recent commits to
   $ grep -n "^4\. \*\*Ask clarifying questions" plugins/claudestacks-sdlc/skills/design/SKILL.md
   ```

   The second command must return exactly one line. Its line number will have moved down
   by the length of the inserted paragraph; only its existence is under test.

5. Run the verification convention:

   ```
   $ cargo run -q -p claudevs-cli -- check plugins/claudestacks-sdlc
   ```

   Exit 0, no `  FAIL  ` line.

6. Commit `feat(repo): delegate design's context exploration to the explorer agent`.

---

### Task 2 — Replace `design` step 8's self-review with an agent spawn

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/design/SKILL.md`

**Steps:**

1. Assert the criteria are still inline — this is the red half of spec §9 check 2:

   ```
   $ grep -c "Intent tracing" plugins/claudestacks-sdlc/skills/design/SKILL.md
   1
   ```

   Count `1`. If this is already `0`, the criteria were removed by something other than
   this task; stop and find out what before continuing.

2. Step 8 currently occupies lines 87–99 in full:

   ```
   8. **Self-review the spec.** Re-read what you wrote from the perspective of someone
      seeing it for the first time, and fix issues directly in the file. Check for:
      **placeholders** — no TBD, TODO, "to be determined," or vague deferral language;
      either fill the gap or make the decision explicit. **Internal consistency** —
      component names, data shapes, and behavioral descriptions agree throughout; a
      component described one way in the architecture section must match its description
      in the error-handling section. **Scope** — the spec is focused enough to map to a
      coherent implementation cycle; if multiple independent objectives are woven
      together, decompose before proceeding. **Ambiguity** — wherever the spec could be
      read two ways, pick one interpretation and make it explicit. **Intent tracing** —
      every spec section roots in the intent's problem or desired outcome; anything
      without a root is scope creep — cut it from the spec, or take it back to the user as
      a question about whether the intent itself needs to grow.
   ```

   Replace all thirteen lines with:

   ````markdown
   8. **Review the spec — by an agent, not by yourself.** You wrote every line of this
      spec and held the dialogue that produced it, so you are the weakest available reader
      of it. Spawn `claudestacks-sdlc:artifact-reviewer` over the draft:

      ```
      kind: spec
      draft: <chain>/spec.md
      authority: <chain>/intent.md
      report: <TMPDIR>/claudestacks-sdlc-<chain>-spec-<NN>.md
      ```

      Expand `${TMPDIR:-/tmp}` yourself before the path enters the brief — an agent
      receives its brief as literal text and runs no shell over it, so an unexpanded
      variable would reach it as a filename. `<NN>` starts at `01` and increments on each
      re-review of a revised draft, so sequential rounds never overwrite one another.

      The agent returns a verdict summary plus that path. Route off the summary; read the
      `<detail>` only when you must act on a finding. Fix the draft yourself — the agent
      never edits it, never flips a `status`, and never commits.

      The criteria it applies live in
      `${CLAUDE_PLUGIN_ROOT}/references/artifact-review.md` § *Reviewing a draft spec*. If
      the agent does not resolve, or returns nothing you can act on, apply that same file's
      criteria inline yourself and tell the user the review ran inline — never skip the
      review for want of the agent.
   ````

3. Confirm green — the criteria are gone from the skill and live only in the reference:

   ```
   $ grep -c "Intent tracing" plugins/claudestacks-sdlc/skills/design/SKILL.md
   0
   $ grep -c "Intent tracing" plugins/claudestacks-sdlc/references/artifact-review.md
   1
   ```

   Exit 1 then exit 0. That pair is spec §9 check 2 for the spec hop: moved, not
   duplicated.

4. Confirm the same for the other four criteria names:

   ```
   $ grep -c "Internal consistency\|Ambiguity\|placeholders" plugins/claudestacks-sdlc/skills/design/SKILL.md
   0
   ```

5. Confirm the surrounding steps survived and the approval gate is untouched:

   ```
   $ grep -n "^9\. \*\*User review gate\.\*\*" plugins/claudestacks-sdlc/skills/design/SKILL.md
   ```

   Exactly one line. Step 9 is the user's approval stop; if this task disturbed it, the
   edit ate too much of the file — revert and redo against the exact thirteen lines above.

6. Run the verification convention:

   ```
   $ cargo run -q -p claudevs-cli -- check plugins/claudestacks-sdlc
   ```

   Exit 0, no `  FAIL  ` line.

7. Commit `feat(repo): route design's spec review through the artifact-reviewer agent`.

---

> **CHECKPOINT — pause after Task 2.**
> `design` is fully wired: one additive delegation, one substitutive review hop, and the first half of spec §9 check 2 is green. Tasks 3 and 4 apply the same two shapes to `plan`, so review the pattern here before it is repeated. Surface both diffs.

---

### Task 3 — Delegate `plan`'s file-structure mapping to `explorer`

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/plan/SKILL.md`

**Steps:**

1. Assert the delegation is absent — failing-first:

   ```
   $ grep -c "explorer" plugins/claudestacks-sdlc/skills/plan/SKILL.md
   0
   ```

   Exit status 1, count `0`.

2. The `## File structure first` section currently ends, at lines 103–104, with:

   ```
   Then assign each file to exactly the tasks that touch it. A task listing files it does not
   touch is a defect; a file in no task is a dangling artefact.
   ```

   Leave that paragraph in place and append a new paragraph immediately after it, before
   the next `##` heading:

   ```markdown
   Delegate the locating. Working out which files exist, what they export, and which one
   owns the behavior the spec describes is exactly `claudestacks:explorer`'s job — spawn it
   and build the file map from the `file:line` tables it returns, rather than reading the
   tree into this thread. Deciding what *should* change stays here; the agent only reports
   what is there, and refuses judgment if you ask for more. If `claudestacks:explorer` does
   not resolve — the `claudestacks` main plugin is not installed — map the files inline here
   and tell the user the agent was unavailable. Never fail hard for want of the main plugin.
   ```

3. Confirm green:

   ```
   $ grep -c "claudestacks:explorer" plugins/claudestacks-sdlc/skills/plan/SKILL.md
   2
   $ grep -c "Never fail hard for want of the main plugin" plugins/claudestacks-sdlc/skills/plan/SKILL.md
   1
   ```

4. Confirm the section boundary held — the paragraph landed inside `## File structure
   first`, not inside the section after it:

   ```
   $ grep -n "^## " plugins/claudestacks-sdlc/skills/plan/SKILL.md | grep -A1 "File structure first"
   ```

   The line after `## File structure first` must be `## Task granularity`, unchanged.

5. Run the verification convention:

   ```
   $ cargo run -q -p claudevs-cli -- check plugins/claudestacks-sdlc
   ```

   Exit 0, no `  FAIL  ` line.

6. Commit `feat(repo): delegate plan's file-structure mapping to the explorer agent`.

---

### Task 4 — Replace `plan`'s pre-save checks with an agent spawn

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/plan/SKILL.md`

**Steps:**

1. Assert both criteria blocks are still inline — the red half of spec §9 check 2 for this
   hop:

   ```
   $ grep -c "^- \*\*Spec coverage\*\*" plugins/claudestacks-sdlc/skills/plan/SKILL.md
   1
   $ grep -c "^## No placeholders$" plugins/claudestacks-sdlc/skills/plan/SKILL.md
   1
   ```

   Both count `1`.

2. Two consecutive sections are being replaced by one. `## No placeholders` occupies lines
   186–196:

   ```
   ## No placeholders

   Fix these before saving:

   - `TBD`, `TODO`, `implement later`.
   - "add appropriate error handling / validation / edge cases" without naming them and showing
     the code.
   - "write tests for the above" without the test code.
   - A step saying *what* without showing *how* — no code block, no command, no expected output.
   - A reference to a type, function, or constant defined neither earlier in the plan nor in the
     codebase (no forward references).
   ```

   and `## Before saving` occupies lines 198–210:

   ```
   ## Before saving

   Check each draft plan on three axes, fixing inline:

   - **Spec coverage** — every in-scope spec requirement (or, on the spec-skip path, every
     requirement stated in the intent) maps to a task across the plan set, or is explicitly
     deferred with a justification.
   - **Type consistency** — every type, signature, and constant used in Task N+1 was defined in an
     earlier task or already exists. A forward reference is a defect: reorder, or add the
     definition.
   - **Guideline conformance** — every code block scanned against the active guideline's
     architecture rules. Cheaper to fix here than after the coder ships it. If no guideline matches
     the stack, say so.
   ```

   Replace both sections — lines 186 through 210 inclusive, including the blank line
   between them — with this single section:

   ````markdown
   ## Before saving — review by an agent

   You wrote these plans, so you are the weakest available reader of them. Spawn
   `claudestacks-sdlc:artifact-reviewer` over the whole draft set:

   ```
   kind: plan-set
   draft: <chain>/plans/NN-*.md      — every draft plan in the set
   authority: <chain>/spec.md        — or <chain>/intent.md on the spec-skip path
   report: <TMPDIR>/claudestacks-sdlc-<chain>-plan-set-<NN>.md
   ```

   Expand `${TMPDIR:-/tmp}` yourself before the path enters the brief — an agent receives
   its brief as literal text and runs no shell over it, so an unexpanded variable would
   reach it as a filename. `<NN>` starts at `01` and increments on each re-review of a
   revised set.

   One spawn for the set, never one per plan. Spec coverage is a property of the *set*: a
   requirement satisfied in plan `03` is covered even though plan `01` says nothing about
   it, and a reviewer shown one plan at a time cannot see that. The per-plan approval gate
   below is unaffected — each plan is still presented and approved on its own.

   The agent returns a verdict summary plus that path. Route off the summary; read the
   `<detail>` only when you must act on a finding. Fix every finding in the drafts
   yourself. The agent never edits a plan, never flips a `status`, and never commits.

   The criteria it applies live in `${CLAUDE_PLUGIN_ROOT}/references/artifact-review.md`
   § *Reviewing a draft plan set*: spec coverage, type consistency, guideline conformance,
   and the no-placeholder list. Hold yourself to that no-placeholder list while drafting
   rather than waiting for the agent to find them — a plan that reaches the reviewer full
   of `TBD` has wasted the spawn. If the agent does not resolve, or returns nothing you can
   act on, apply that same file's criteria inline yourself and tell the user the review ran
   inline; never skip the review for want of the agent.
   ````

3. Confirm green — both criteria blocks are gone from the skill and live only in the
   reference:

   ```
   $ grep -c "^- \*\*Spec coverage\*\*" plugins/claudestacks-sdlc/skills/plan/SKILL.md
   0
   $ grep -c "^## No placeholders$" plugins/claudestacks-sdlc/skills/plan/SKILL.md
   0
   $ grep -c "^- \*\*Spec coverage\*\*" plugins/claudestacks-sdlc/references/artifact-review.md
   1
   ```

   Exit 1, exit 1, exit 0. That triple is spec §9 check 2 for the plan hop.

   The anchor matters. A bare `grep -c "Spec coverage"` would return `1` here, because
   the replacement text above says "Spec coverage is a property of the *set*" as ordinary
   prose. What check 2 asserts is that the criteria *bullet* moved, not that the phrase
   never appears — so the pattern matches the bullet's exact shape.

4. Confirm the other two axis names are gone too:

   ```
   $ grep -c "Type consistency\|Guideline conformance" plugins/claudestacks-sdlc/skills/plan/SKILL.md
   0
   ```

5. Confirm the sections either side survived and the per-plan approval gate is untouched:

   ```
   $ grep -c "^## Approval gate$" plugins/claudestacks-sdlc/skills/plan/SKILL.md
   1
   $ grep -c "^## Task template$" plugins/claudestacks-sdlc/skills/plan/SKILL.md
   1
   ```

   Both `1`. `## Approval gate` is the per-plan user stop; if it vanished, the replacement
   ate past line 210 — revert and redo against the exact range above.

6. Run the verification convention:

   ```
   $ cargo run -q -p claudevs-cli -- check plugins/claudestacks-sdlc
   ```

   Exit 0, no `  FAIL  ` line.

7. Commit `feat(repo): route plan's pre-save review through the artifact-reviewer agent`.

---

## Verification summary (plan-level)

| Check | Command | Expected |
|---|---|---|
| Plugin validity | `cargo run -q -p claudevs-cli -- check plugins/claudestacks-sdlc` | exit 0, no `  FAIL  ` line |
| Explorer wired, design | `grep -c "claudestacks:explorer" plugins/claudestacks-sdlc/skills/design/SKILL.md` | `2` |
| Explorer wired, plan | `grep -c "claudestacks:explorer" plugins/claudestacks-sdlc/skills/plan/SKILL.md` | `2` |
| Spec criteria moved | `grep -c "Intent tracing" plugins/claudestacks-sdlc/skills/design/SKILL.md` | `0` |
| Plan criteria moved | `grep -c "^- \*\*Spec coverage\*\*" plugins/claudestacks-sdlc/skills/plan/SKILL.md` | `0` |
| Criteria still exist once | `grep -c "Intent tracing\|Spec coverage" plugins/claudestacks-sdlc/references/artifact-review.md` | `2` |
| User gates intact | `grep -c "^9\. \*\*User review gate\.\*\*" plugins/claudestacks-sdlc/skills/design/SKILL.md` and `grep -c "^## Approval gate$" plugins/claudestacks-sdlc/skills/plan/SKILL.md` | `1` each |

Rows 4–6 together are spec §9 check 2: the criteria moved rather than being duplicated.
Row 7 is the invariant this whole chain rests on — an agent reports, the skill still stops
and asks.

No Lua is added, so `cargo make plugins` is unaffected. The Rust Definition of Done does
not apply — this plan touches no Rust.

**Deferred to a sibling plan, by design:** `skills/distill/SKILL.md` and the `chain-reader`
wiring are plan `03`, which is independent of this one and touches no file this plan
touches. The two can run in parallel worktrees once `01` is done.

**Manual, not automated:** spec §9 check 3, the dogfood run. After this plan lands,
invoking `/claudestacks-sdlc:design` on a chain with an approved intent should show an
`artifact-reviewer` spawn at step 8 and still stop at step 9 for approval. No task here
automates that, and none claims to.
