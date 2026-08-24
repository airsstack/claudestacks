---
status: approved
created: 2026-08-25
depends-on: []
---

# claudestacks-sdlc Scaffold Implementation Plan

**Goal:** Ship the plugin skeleton — manifest, license, README, both reference documents, and the setup command — so the sibling plans have a valid plugin to land code and skills into.

**Architecture:** A new plugin directory `plugins/claudestacks-sdlc/` following the suite's established layout (`.claude-plugin/plugin.json` manifest, `commands/`, `references/`). No `hooks/` directory — the committed chain removes the need for SessionStart provisioning (spec §3). The two reference files are the canonical authorities the skills and commands will cite: `artifact-chain.md` (paths, naming, frontmatter, states) and `review-policy.md` (the REVIEW.md template).

**Tech Stack:** Claude Code plugin manifest (JSON), markdown commands and references. No code in this plan.

**Content authority:** `.claudestacks/sdlc/2026-08-24-sdlc-plugin/spec.md` in this repository, cited by section below. For manifests the full content is in this plan; for prose files the plan gives a binding content contract and the spec section it must encode.

---

## File structure

```
plugins/claudestacks-sdlc/.claude-plugin/plugin.json  — [create] plugin manifest
plugins/claudestacks-sdlc/LICENSE                     — [create] Apache-2.0, copied from sdd
plugins/claudestacks-sdlc/README.md                   — [create] install, workflow, layout, attribution
plugins/claudestacks-sdlc/references/artifact-chain.md — [create] canonical chain rules (spec §2)
plugins/claudestacks-sdlc/references/templates.md      — [create] artifact templates from the chain-#1 exemplar
plugins/claudestacks-sdlc/references/review-policy.md  — [create] REVIEW.md template (spec §6)
plugins/claudestacks-sdlc/commands/setup.md           — [create] idempotent provisioning command (spec §5.2)
```

Verification used throughout: `claude plugin validate plugins/claudestacks-sdlc --strict` (structure) and `python3 -m json.tool` (JSON well-formedness). Markdown deliverables have no red-green cycle; each task's verification is the structural check plus a review of the file against its contract.

### Task 1 — Manifest and license

**Files:**
- Create `plugins/claudestacks-sdlc/.claude-plugin/plugin.json`
- Create `plugins/claudestacks-sdlc/LICENSE`

**Steps:**

1. Create the directory and write `plugins/claudestacks-sdlc/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "claudestacks-sdlc",
     "version": "0.1.0",
     "description": "AI-native SDLC workflow: a committed intent → spec → plan → execute chain with distill and triage feedback loops and a deterministic status board. Implements Anthropic's AI-native SDLC playbook.",
     "author": {
       "name": "rstlix0x0",
       "email": "rstlix.dev@gmail.com"
     },
     "license": "Apache-2.0",
     "homepage": "https://github.com/airsstack/claudestacks",
     "repository": "https://github.com/airsstack/claudestacks",
     "keywords": [
       "sdlc",
       "spec-driven-development",
       "planning",
       "workflow"
     ]
   }
   ```

2. Copy the license (sdd still exists at this point; plan 04 deletes it later):

   ```
   $ cp plugins/claudestacks-sdd/LICENSE plugins/claudestacks-sdlc/LICENSE
   ```

3. Verify:

   ```
   $ python3 -m json.tool plugins/claudestacks-sdlc/.claude-plugin/plugin.json > /dev/null && echo OK
   OK
   $ head -1 plugins/claudestacks-sdlc/LICENSE
                                    Apache License
   ```

### Task 2 — `references/artifact-chain.md`

**Files:**
- Create `plugins/claudestacks-sdlc/references/artifact-chain.md`

**Steps:**

1. Write the file. It is the prose authority every skill and the status fallback cite. Binding contract — it must state, as normative rules (not narrative):
   - Chain root `.claudestacks/sdlc/` at the consuming repo's root; everything under it is committed; the plugin never writes `.gitignore`.
   - Chain directory naming `YYYY-MM-DD-<kebab-topic>`; same-day chains differ by topic.
   - The full layout tree from spec §2.1 including `prds/`, `rfcs/`, `REVIEW.md`, and a chain's `intent.md` / `spec.md` / `plans/NN-<topic>.md`.
   - Superseded-spec renaming: `spec-superseded-YYYY-MM-DD.md` (date of supersession); `spec.md` is always governing. Plans keep `NN-` names; a replacement takes the next free number.
   - Input-doc rules from spec §2.2: optional always, read-only to the plugin, no state machine, top-level inbox only, scanning and named-but-missing behavior.
   - The frontmatter schema from spec §2.3 verbatim (all seven keys with their types and optionality).
   - The state tables from spec §2.4 — both the per-artifact states table and the full transitions table — reproduced in full, plus the flip rule sentence ("a skill flips a state only as the last step of the interaction that earns it, after the user's explicit in-dialogue approval") and the reversibility note.
   - Spec-skip from spec §2.5.
   - The NEXT-derivation rules from spec §5.1 (this is what the status fallback executes by hand).
2. Verify: re-read against spec §§2.1–2.5 and §5.1; every rule above present; no placeholder text.

### Task 2b — `references/templates.md`

**Files:**
- Create `plugins/claudestacks-sdlc/references/templates.md`

**Steps:**

1. Write the file: the three artifact templates the skills reproduce, distilled from
   the first live chain — `.claudestacks/sdlc/2026-08-24-sdlc-plugin/` in this
   repository is the exemplar; copy its shapes, not its content. One fenced template
   per artifact:
   - **intent.md** — frontmatter (`status`, `created`, optional `derived-from-prd`
     / `derived-from-rfc` lists, optional `source: triage`, optional
     `spec: skipped`) and body sections `# Intent: <title>` / `## Problem` /
     `## Affected systems` / `## Desired outcome` / `## Constraints` /
     `## Non-goals` (triage-sourced intents add `## Evidence`).
   - **spec.md** — frontmatter (`status`, `created`) and body: `# Spec: <title>`,
     a one-paragraph summary, numbered `##` sections as the design requires, with
     a `## Non-goals` section always present.
   - **plans/NN-<topic>.md** — frontmatter (`status`, `created`, `depends-on`)
     and the header block (`# <name> Implementation Plan`, **Goal** one sentence
     without "and", **Architecture**, **Tech Stack**), then `## File structure`,
     then `### Task N — <imperative title>` blocks with **Files:** / **Steps:**
     and per-step verification, closing with `## Verification summary
     (plan-level)`. Executed plans gain `## Review findings` and `## Deviations`
     (appended by the execute skill, not authored).
   - A closing note: `references/artifact-chain.md` owns paths, naming, and
     states; this file owns body shapes — change one, check the other.
2. Verify: each of the three templates round-trips against its chain-#1 exemplar
   file — every section present there appears in the template and nothing invented
   appears that the exemplar lacks.

### Task 3 — `references/review-policy.md`

**Files:**
- Create `plugins/claudestacks-sdlc/references/review-policy.md`

**Steps:**

1. Write the file: a short preamble (what REVIEW.md is, that `/claudestacks-sdlc:setup` provisions it, never overwriting an existing one) followed by the template inside a fenced block, exactly:

   ````markdown
   # REVIEW.md — review policy

   <!-- Provisioned by claudestacks-sdlc. Versioned: edit deliberately, log changes
        in the Tuning log. Reviewer-agent consumption of this file is a separate
        future chain; until then this policy is documentation you can point any
        reviewer at, including pasting it into a review prompt by hand. -->

   ## Passes, in order

   1. **Bugs and logic errors** — correctness of the diff on its own terms.
   2. **Security** — injection, secrets in the diff, unsafe input handling,
      privilege and network boundaries.
   3. **Compliance** — the diff against the chain's spec and plan: scope drift,
      silent carry-over, missing or unauthorized requirements.

   ## Severity

   - **Important** — must be addressed before commit.
   - **Nit** — batch or ignore; never blocks.

   ## Exclusions

   - Generated paths.
   - Anything CI already enforces deterministically.

   ## Tuning log

   <!-- Dated entries when this policy changes. Newest first. -->
   ````

2. Verify: the template carries all four sections (Passes / Severity / Exclusions / Tuning log) and the scope-2 disclaimer comment, per spec §6.

### Task 4 — `commands/setup.md`

**Files:**
- Create `plugins/claudestacks-sdlc/commands/setup.md`

**Steps:**

1. Write the command file:

   ````markdown
   ---
   description: Provision the committed .claudestacks/sdlc/ chain root (prds/, rfcs/, REVIEW.md). Idempotent, never overwrites.
   ---

   Provision the claudestacks-sdlc artifact chain in the current repository.
   Every step is idempotent: create only what is missing, never overwrite
   anything that exists, and report each item as "created" or "already present".

   1. Create the directories `.claudestacks/sdlc/prds/` and
      `.claudestacks/sdlc/rfcs/` if missing.
   2. In each of the two, create an empty `.gitkeep` file if the directory has
      no committed content (committed-empty directories need the keep file).
   3. If `.claudestacks/sdlc/REVIEW.md` does not exist, create it from the
      template in the fenced block of
      `${CLAUDE_PLUGIN_ROOT}/references/review-policy.md` (the template body
      only, without the fence). If it exists, leave it untouched and report
      "already present".
   4. Do NOT write or modify any `.gitignore` — everything under
      `.claudestacks/` is meant for git.
   5. Report what was created versus found, then stop. Committing is the
      user's call.
   ````

2. Verify:

   ```
   $ claude plugin validate plugins/claudestacks-sdlc --strict
   ```

   Expected: validation passes (README is not yet present at this point only if validate requires it — if validate reports a missing README, complete Task 5 first and re-run; order the two accordingly on the day).

### Task 5 — `README.md`

**Files:**
- Create `plugins/claudestacks-sdlc/README.md`

**Steps:**

1. Write the README. Binding contract — sections, in order:
   - **Title + one-paragraph summary**: the six-skill committed-chain workflow, naming the playbook (https://claude.com/blog/the-ai-native-sdlc-playbook) as the model.
   - **Install**: `/plugin marketplace add airsstack/claudestacks` then `/plugin install claudestacks-sdlc@claudestacks`; skills namespaced `claudestacks-sdlc:<name>`. Plus the migration note verbatim: users of the retired plugin run `/plugin uninstall claudestacks-sdd@claudestacks` first (spec §9).
   - **Workflow**: the pipeline (`intent → design → plan → execute`) and the two loops (`distill`, `triage`), one paragraph each, with the state each skill gates on.
   - **Artifact chain**: the layout tree from spec §2.1 and a pointer to `references/artifact-chain.md` as the authority; note that everything is committed and nothing is ever deleted (superseded/dropped instead).
   - **Commands**: `status` (deterministic Lua board, model fallback when `airsl` is absent) and `setup` (idempotent provisioning).
   - **Attribution** (spec §11): the stage model and feedback loops implement Anthropic's AI-native SDLC playbook; the design/plan/execute discipline descends from `claudestacks-sdd`, itself adapted from the superpowers plugin (`superpowers@claude-plugins-official`). Apache-2.0.
2. Verify:

   ```
   $ claude plugin validate plugins/claudestacks-sdlc --strict
   ```

   Expected: passes.

### Task 6 — Commit

**Steps:**

1. Commit everything from Tasks 1–5:

   ```
   $ git add plugins/claudestacks-sdlc
   $ git commit -m "feat(repo): scaffold the claudestacks-sdlc plugin"
   ```

   (Scope `repo` per the workspace commit convention — `plugins/` belongs to it.)

---

## Verification summary (plan-level)

- `claude plugin validate plugins/claudestacks-sdlc --strict` passes.
- `python3 -m json.tool` accepts the manifest.
- Both references read as complete against spec §§2 and 6 with no placeholders.
