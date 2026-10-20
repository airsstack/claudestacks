---
status: done
created: 2026-10-20
depends-on: [03, 04]
built-on: 9078f8c84ed0
---

# ADR Skill Implementation Plan

**Goal:** A new `adr` skill is the only way an ADR is written or changes state, with each
draft reviewed by `artifact-reviewer` before the author approves it.

**Architecture:** One new skill, `skills/adr/SKILL.md`, carries every ADR operation of spec
§7.1 and resolves paths, keys, states and rows from `references/artifact-chain.md` §13
and the body shape from `references/templates.md` (plan 04), as the `milestone` skill
does for milestones (`skills/milestone/SKILL.md:20-30`). It reads ADR state from the
board (plans 02, 03) before acting. `agents/artifact-reviewer.md` gains the `adr` kind
the skill spawns it with. Both are prose; there is no Lua change.

**Tech Stack:** Markdown (Claude Code skill and agent definitions), `scripts/status.sh`,
`scripts/fingerprint.sh`.

**Content authority:** spec §2.3, §2.4, §6.1, §7.1, §8.

---

## Files that change

```
plugins/claudestacks-sdlc/skills/adr/SKILL.md         — [create] the adr skill
plugins/claudestacks-sdlc/agents/artifact-reviewer.md — [modify] the adr review kind
```

Every path is relative to the repository root. Skill behaviour has no unit test (spec
§11); plan 07 runs the recorded walkthrough. The gate for each task here is
`claude plugin validate --strict plugins/claudestacks-sdlc` exiting 0 (its `--help` says
`--strict` treats warnings as errors and validates skills and agents in a directory),
the named `grep` checks, and `cargo make plugins` still passing.

Skill prose in this plugin names its own files through `${CLAUDE_PLUGIN_ROOT}`
(`skills/status/SKILL.md:8`, `:16`, `:28`) and renders the board with
`sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"`; the new skill does the same.

## Order of work

### Task 1 — Write the `adr` skill

**Files:**
- Create `plugins/claudestacks-sdlc/skills/adr/SKILL.md`

**Change:** a skill with frontmatter `name: adr` and a `description` naming its operations
(new, approve, supersede, deprecate, amend, drop, un-drop, finish supersede) and that it
is invoked with an ADR number such as `0003` or `3`, in the style of the `milestone`
skill's description (`skills/milestone/SKILL.md:1-4`). Its sections, in order:

- **Shared contract** — paths, keys, states and rows from `artifact-chain.md` (§7, §13),
  the body shape from `templates.md`; lazy-create `.claudestacks/sdlc/adrs/` on the first
  write, never assume `setup` ran; the only writer of `adrs/`; never renames or deletes a
  file there; never edits an approved ADR's body; flips status only per artifact-chain
  §7.2–§7.4 as the last step of the interaction that earns it; never commits.
- **Input** — an ADR is named `0003` or `3` (normalised to four digits); `new` takes no
  number.
- **Check before acting** — for any operation on an existing ADR: render the board, read
  the `ADR NNNN` row; with no row, read the status from the file (spec §7.1); on an
  `INVALID` row refuse, naming the file and the reason as the board words it, except
  `superseded by MMMM but still approved`, which offers *finish supersede*. After every
  flip, render the board again and tell the author what the ADR's row, and each affected
  chain's row, reads.
- **Numbering** — the next number after the highest `NNNN` of any file in `adrs/`
  matching the ADR file pattern, whatever its status or validity; a number is never
  reused (spec §2.1).
- **Operations** — spec §7.1's table, one subsection each:
  - *new* — one question at a time: title, context, options considered (two or more),
    decision, consequences; writes `NNNN-<topic>.md` as `draft`; runs the review; asks
    whether to approve.
  - *approve* — refused unless `draft`, and unless every ADR in its `supersedes` is
    `approved`; computes `sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <file>` and
    writes the 12 characters as `sealed` in the same edit as `draft → approved`; then
    flips each listed ADR `approved → superseded` in the same interaction with no fresh
    question, and names the open chains whose rows now read `spec stale (ADR NNNN
    superseded by MMMM)`.
  - *supersede N* — refused unless `N` is `approved`; writes a new draft with
    `supersedes: [N]` whose context states what in `N` no longer holds, citing the plan's
    probe result when the row reads `disproven by <chain>/NN`; reviews it with `N` as
    authority; then approves as above.
  - *deprecate N* — refused unless `approved`; flips `approved → deprecated` on the
    author's explicit word and changes nothing else in the file; the reason belongs in
    the author's commit message, since the body is sealed.
  - *amend* — refused unless `draft`; rewrites the body.
  - *drop / un-drop* — `draft → dropped` / `dropped → draft`, each refused from any
    other status.
  - *finish supersede* — refused unless the ADR is `approved` and its row reads
    `superseded by MMMM but still approved`; shows the author that `MMMM` lists it and
    asks whether `MMMM` replaces it; flips it `approved → superseded` only on an explicit
    yes (spec §2.4, §7.1).
- **Review** — spawn `claudestacks-sdlc:artifact-reviewer` once per draft with `kind:
  adr`, `draft: <the ADR file>`, `authority:` none for *new* and the replaced ADR file(s)
  for *supersede*, and a literal temp `handoff:` path with `handoff-protocol:`, through
  `/claudestacks:context-handoff`'s single-subagent tier — the brief `design` step 9
  writes (`skills/design/SKILL.md:216-267`). Exactly one round; every finding at every
  tier gets a disposition row the author sees at the approval question; when the agent
  does not resolve, apply `artifact-review.md` § *Reviewing a draft ADR* inline and say
  so.
- **Never** — a short list: no commit, no rename, no delete, no edit of a sealed body, no
  question to the author about whether something should be an ADR (spec §13: no skill
  prompts the author to create one).

**Proof:** run from the repository root with `S=plugins/claudestacks-sdlc/skills/adr/SKILL.md` —
- `claude plugin validate --strict plugins/claudestacks-sdlc` exits 0.
- `grep -nE '^name: adr$' "$S"` prints one line.
- `grep -nF 'fingerprint.sh' "$S"`, `grep -nF 'status.sh' "$S"`, `grep -nF 'kind: adr' "$S"`, `grep -nF 'superseded by MMMM but still approved' "$S"` each print at least one line.
- `grep -niE 'git (add|commit)' "$S"` prints only lines that forbid it.

**Done when:** every check holds and `cargo make plugins` passes. Commit
`feat(repo): add the claudestacks-sdlc adr skill`.

### Task 2 — Teach `artifact-reviewer` the `adr` kind

**Files:**
- Modify `plugins/claudestacks-sdlc/agents/artifact-reviewer.md`

**Change:**

- The `description` (:3-7) says it reviews a spec, a set of plans or an ADR, and that the
  `adr` skill spawns it too.
- The brief table's `kind` row (:29) reads `spec`, `plan-set` or `adr`; the `authority`
  row (:31) adds: none for `kind: adr` on a new ADR, the replaced ADR file(s) on a
  supersede.
- The sentence on reading the authority first (:35-36) says that with no authority the
  ADR is judged against the criteria alone.
- One sentence under the report section's verdict example (:70-75): for `kind: adr` the
  verdict line reads `ADR: <n> blocking, <n> risk, <n> nit` (spec §8).

**Proof:** run from the repository root with `A=plugins/claudestacks-sdlc/agents/artifact-reviewer.md` —
- `claude plugin validate --strict plugins/claudestacks-sdlc` exits 0.
- `grep -nE 'spec.*plan-set.*adr' "$A"` prints the `kind` row; `grep -nF 'ADR: ' "$A"` prints the verdict sentence.

**Done when:** every check holds. Commit
`feat(repo): let artifact-reviewer review a claudestacks-sdlc ADR`.

---

## Risks

- **Agent definitions are read at session start**, so a session that edited
  `artifact-reviewer.md` will not see the new kind until it restarts. Plan 07's
  walkthrough runs the review in a fresh session for that reason.
- **The supersede flip is the step most likely to go wrong in prose**: approving the
  successor and flipping the predecessor happen in one interaction, and an interruption
  between the two leaves `superseded by MMMM but still approved`, which *finish
  supersede* clears only with the author's yes. The walkthrough exercises both.
- Not done here: `design`, `execute`, `plan` and `status` reacting to ADR conditions
  (plan 06).

## Proof

- `claude plugin validate --strict plugins/claudestacks-sdlc` exits 0.
- `ls plugins/claudestacks-sdlc/skills` lists eleven directories, `adr` among them.
- Plan 07's walkthrough runs every operation of the skill against a throwaway root.

## Review findings

Reviewer report: one round over both tasks, 0🔴 1🟡 6🔵 2❓; blocking set empty. Fix round
re-verified with `claude plugin validate --strict plugins/claudestacks-sdlc` → `✔ Validation passed`.

- risk — the `superseded by MMMM but still approved` exception did not refuse other operations or say *offer* — `skills/adr/SKILL.md:51-54` — fixed: refuse every other operation, offer *finish supersede* (:53-54).
- question — approve's "listed ADR not `approved`" left invalid / unmatched numbers open — `skills/adr/SKILL.md:72` — fixed: read as in *Check before acting*; an `INVALID` row or no single matching file counts as not approved (:87-90).
- nit — appended sentence not reflowed — `agents/artifact-reviewer.md:36` — fixed (:36-37).
- nit — no ADR citation example — `agents/artifact-reviewer.md:81` — fixed: `0003-foo.md ## Decision` (`## Decision` is `templates.md:218`).
- nit — duplicate-number wording holds only when no earlier row wins — `skills/adr/SKILL.md:35-36` — declined: copied from the milestone skill, harmless.
- nit — "`<topic>` is the title in kebab-case" is unstated by spec/reference — `skills/adr/SKILL.md:85` — declined: a sensible default.
- nit — the half-done supersede row is also reachable by a hand revert — `skills/adr/SKILL.md:115-117` — declined: mirrors spec §7.1 verbatim.
- nit — reversion guard: only presence greps pin the prose — whole skill — declined: spec §11 accepts it; plan 07's walkthrough is the behavioural check.
- nit — Task 2's kind-row grep prints two lines — plan wording — no change.
- question — spec §2.2 allows a multi-number `supersedes` that no operation writes — spec — not changed; recorded as spec debt.

## Probe results

None run: both tasks are prose, and the plan names plan 07's walkthrough as their behavioural
proof. Gates: `cargo make plugins` → `630 passed, 0 failed (23 files)`, fingerprint gate 8
cases passed twice; `claude plugin validate --strict plugins/claudestacks-sdlc` → exit 0;
`ls plugins/claudestacks-sdlc/skills | wc -l` → `11`.

## Deviations

- 2026-10-20 — `agents/artifact-reviewer.md`'s description and opening line say "artifact"
  rather than "chain artifact", since an ADR is not a chain artifact.
- 2026-10-20 — the review temp path is `<TMPDIR>/claudestacks-sdlc-adr-<NNNN>-01.md`, and
  `amend` does not re-spawn the reviewer (one round per draft); the plan left both open.
