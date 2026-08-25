---
name: plan
description: Use when a chain's spec is approved (or its intent carries spec: skipped) and implementation plans are needed — decomposes the objective into a set of bite-sized test-first plans with exact file paths and complete code, proposes the plan fan-out and dependencies in dialogue, then writes them to the chain's plans directory. Invoke once a spec is approved (or skipped) and before any code is written.
---

# Plan

Turn an approved spec (or a spec-skipped intent) into one or more construction manuals an
implementer can execute with zero prior knowledge of the codebase: exact file paths, complete
code, runnable commands, expected output, and a commit at the end of each task. Not aspirational
prose.

A plan stands alone. Whoever picks it up may not know the codebase, may not have read the spec,
and shares no context with you — so every task carries everything that task needs.

Paths, naming, frontmatter, and state transitions all come from
`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`; artifact body shapes come from
`${CLAUDE_PLUGIN_ROOT}/references/templates.md`. Lazy-create the chain's `plans/` directory
before first write — never assume `/claudestacks-sdlc:setup` ran.

Three principles bind the content:

- **TDD.** Every behavioral change is preceded by a failing test: write the failing test →
  confirm it fails → minimal code to pass → confirm it passes → commit. No task skips the
  red-green cycle.
- **Honor the active stack's guidelines.** Detect the stack from repo markers (`Cargo.toml` →
  Rust) and load the matching guideline skill (`claudestacks-guideline-rust:rust-guidelines`).
  Every code block you write must already conform to its architecture rules, and each task's
  verification must include its Definition of Done. A plan that emits rule-violating code is a
  defect even if the code works.
- **DRY / YAGNI.** No abstraction the objective does not require. Extract shared code only where
  two tasks would genuinely duplicate it.

## State gate

This skill requires one of:

- a chain whose `spec.md` is `status: approved`; or
- a chain with no `spec.md`, whose `intent.md` is `status: approved` and carries
  `spec: skipped` in its frontmatter.

Anything else is refused, naming the file, its current state, and the command that advances it:

- `spec.md` is `draft` — refuse; the `design` skill's review gate is what flips it to
  `approved`.
- no `spec.md` and the intent has no `spec: skipped` flag — refuse; either the `design` skill
  runs first, or the user sets the skip flag by re-invoking the `intent` skill.
- `intent.md` is not `approved` — refuse; the `intent` skill is what advances it.

This skill never sets `spec: skipped` itself — it only reads the flag.

## Dialogue

Guided the same way every skill in this pipeline is: one question at a time, never a battery.
Prefer multiple-choice phrasing where a question has a natural small set of answers, and lead
with your own recommendation rather than laying out every option flat. If the user redirects
mid-dialogue — a different fan-out, a dependency you had not proposed — follow it without
re-litigating the answer it replaced.

Ask only when the answer changes the plan about to be written; anything derivable from the spec,
the repo, or a loaded guideline is derived instead and stated as an overridable assumption.

One sharpening against that rule: raise every ambiguity in the spec itself as a question, never
resolve one as an assumption. A plan is a construction manual an implementer follows with zero
other context — an assumption baked in silently here becomes code nobody agreed to, discovered
tasks later. If the spec leaves open which file owns a behavior, where a task's boundary falls,
or which of two reasonable readings it means, ask; do not pick one and note it in passing.

Every gate below — the fan-out proposal, checkpoint placement, each plan's approval — is a real
stop: present it and wait for an explicit answer, never "proceeding unless you object."

## Fan-out is first-class

A spec usually yields several plans, not one. Before writing anything, propose the plan set and
its dependency shape in dialogue: "N plans: `01-<topic>` (…), `02-<topic>` (…); `02` is
independent of `01` — agree?" Also ask where checkpoint boundaries belong within each plan (e.g.
"pause for review after tasks 1–3"). Only once the user agrees do you start writing files.

Plans live at `plans/NN-<kebab-topic>.md` inside the chain directory — the `NN` prefix orders
plans within the chain, and sibling plans are disambiguated by topic, not renumbering. Each
plan's frontmatter carries `status`, `created`, and `depends-on` (a list of plan numbers this
plan needs `done` first; absent or empty means independent — visibly parallelizable across
worktrees).

## Scope check — one objective per plan

Each individual plan covers **exactly one objective**: one outcome stateable in a single
sentence without an "and". If a plan's goal sentence needs an "and", split it into sibling
plans. Tasks are not objectives — three tasks implementing parts of one feature belong in one
plan.

## File structure first

Before defining tasks, map the file changes, one sentence of responsibility each. Prefer a new
focused file over expanding an existing one.

```
src/auth/token.rs          — [create] token validation logic and unit tests
src/auth/mod.rs            — [modify] re-export the new token module
tests/auth_integration.rs  — [create] integration test for the token round-trip
```

Then assign each file to exactly the tasks that touch it. A task listing files it does not
touch is a defect; a file in no task is a dangling artefact.

## Task granularity

Each task is a 2–5 minute action — doable, testable, and committable in one sitting. Longer
means too coarse; break it down. "Write the implementation and tests for X" as one step is a
collapsed red-green cycle — expand it.

## Header template

Frontmatter and header follow the body shape in
`${CLAUDE_PLUGIN_ROOT}/references/templates.md`:

```markdown
---
status: draft
created: <YYYY-MM-DD>
depends-on: [01]                 # optional
---

# [Feature Name] Implementation Plan

**Goal:** [one sentence — no "and" joining two distinct objectives]

**Architecture:** [2-3 sentences on the structural decisions this plan makes]

**Tech Stack:** [key technologies, libraries, frameworks]

---
```

The Goal line is the scope guard. If you cannot write it without "and", stop and split.

## Task template

Each task names its files, then walks the red-green cycle with real code and real expected
output at every step. Substitute your actual language and names:

````markdown
### Task N — [Short imperative title]

**Files:**
- Create `src/math/add.py`
- Modify `src/math/__init__.py`
- Test `tests/test_add.py`

**Steps:**

1. Write the failing test in `tests/test_add.py`:

   ```python
   def test_add_two_positive_integers():
       assert add(2, 3) == 5
   ```

2. Run it and confirm failure:

   ```
   $ pytest tests/test_add.py
   FAILED tests/test_add.py::test_add_two_positive_integers — NameError: name 'add' is not defined
   ```

3. Write the minimal implementation in `src/math/add.py`:

   ```python
   def add(a: int, b: int) -> int:
       return a + b
   ```

4. Run it and confirm green:

   ```
   $ pytest tests/test_add.py
   1 passed in 0.01s
   ```

5. Export from the module index, then commit `feat(math): add integer addition function`.
````

Where two tasks share code structure, write it out in full in both — a plan that says "similar
to Task N" is no longer standalone, which is the property the whole format exists to protect.

## No placeholders

Fix these before saving:

- `TBD`, `TODO`, `implement later`.
- "add appropriate error handling / validation / edge cases" without naming them and showing
  the code.
- "write tests for the above" without the test code.
- A step saying *what* without showing *how* — no code block, no command, no expected output.
- A reference to a type, function, or constant defined neither earlier in the plan nor in the
  codebase (no forward references).

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

## Approval gate

Each plan gets its own approval: present it, ask the user to read and approve. Only on
explicit approval, flip that plan's frontmatter `status: draft → approved` as the last step of
the interaction that reviews it — do not flip a plan the user has not yet seen.

## Lifecycle

Plans are never deleted. A superseded plan keeps its original file and `NN-<topic>.md` name and
flips `status: superseded` in its frontmatter; a replacement plan does not reuse that number — it
takes the next free `NN` in the chain. Nothing is ever removed from the chain: git history plus
the `status` field is the complete record.

## Execution handoff

Recommend committing approved plans before execution starts, so a worktree picking up a plan
reads it from git rather than an uncommitted working tree — committing remains the user's act.
The `execute` skill is the next step once a plan is `approved`.
