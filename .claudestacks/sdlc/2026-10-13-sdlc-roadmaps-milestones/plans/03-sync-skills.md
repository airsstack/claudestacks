---
status: done
created: 2026-10-14
depends-on: [02]
built-on: a5a235079e03
---

# Sync Skills Implementation Plan

**Goal:** Every skill that reads or flips chain state enforces the board's sync rules.

**Architecture:** The rules live in one place — `references/artifact-chain.md`, written by plan 02 — and the board is their only executor. Each skill gains a `Sync check` section that renders the board, reads its chain's row, and maps the row's wording to one of three outcomes: act, refuse naming the skill that clears it, or clear it itself on the author's word. `design` and `plan` write `built-on`; `execute` writes `disproves`; no skill restates a rule the reference owns.

**Tech Stack:** Markdown skill files under `plugins/claudestacks-sdlc/skills/`; the board (`scripts/status.sh`) and `scripts/fingerprint.sh` from plans 01 and 02; `cargo make plugins` as the gate.

**Content authority:** spec §2 (who writes `built-on` and `disproves`; re-confirmation), §6 (chain walk-up), §8 (the shared check), §8.3 (Amending; Clearing `intent disproven`), §8.4, §8.5 (all but running the roll-up, which is plan 05), §8.6, and the sync scenarios of the §11 walkthrough.

---

## File structure

```
plugins/claudestacks-sdlc/skills/status/SKILL.md    — [modify] the no-airsl fallback derives the sync rules and computes fingerprints with fingerprint.sh
plugins/claudestacks-sdlc/skills/design/SKILL.md    — [modify] sync check, re-confirmation of a spec, built-on written at draft and at approval
plugins/claudestacks-sdlc/skills/plan/SKILL.md      — [modify] sync check, refusals, re-confirmation of a plan, built-on written at draft and at approval
plugins/claudestacks-sdlc/skills/execute/SKILL.md   — [modify] sync check, refusals, guarded approval of a draft plan, disproves, walk-up for a complete chain only
plugins/claudestacks-sdlc/skills/intent/SKILL.md    — [modify] sync check on re-invocation, the amend warning, clearing `intent disproven`
```

This plan touches no file under `references/` and no Lua. Plan 02 has already written the fingerprint definition, the `built-on` and `disproves` keys and the sync rules into `references/artifact-chain.md`; the skills below cite that file rather than restating it.

**How every edit task is verified.** Skill text has no unit test. Each task's red step is a `grep -c` for a phrase that exists only in the new text, printing `0`; its green step is the same command printing `1`. The behaviour is proven once, by the walkthrough in Task 12.

**Locating an edit.** Each task quotes the existing text it replaces, verbatim. Find it by that text. The `file:line` beside it is where it sits at commit `55df7cf`; earlier tasks in this plan move later lines in the same file.

**Paths in commands** are relative to the repository root.

**Decisions this plan makes where the spec is silent or unclear.** Each is reported to the author at the plan's approval gate:

- `design` acts on three rows only (stale spec, missing `built-on`, `spec disproven`). On any other row it says what the row reads and carries on under its state gate. It does not refuse on `no spec and no skip flag`, since writing a spec is what clears that. (Spec §8.4 names only the three.)
- `plan` names `design` for `INVALID (spec.md: missing built-on)` and the file for every other invalid result. Spec §8.4 says "the file" for all of them, while spec §10 sends that one to `design`.
- While `spec disproven` or `intent disproven` stands, `execute` lets any plan finish whose own `disproves` equals its authority's current fingerprint. Spec §8.5 says "the plan whose `disproves` raised it", and the board names only the lowest such plan.
- `execute` refuses a `draft` plan whose spec is still `draft`, naming `design`. The plan would pass the `built-on` test of spec §2 and then read `blocked (spec not approved)` the moment it went live.
- A replacement spec whose body is identical to the disproven one leaves `spec disproven` standing, because the fingerprint is unchanged. The skill text says so.
- On a chain whose plans are all settled, superseding a disproven spec ends the condition, and the chain then reads `chain complete` beside a `draft` spec (spec §3.3 checks live plans only). This plan does not change that; the walkthrough keeps a live plan in that scenario.
- **The walkthrough records the board, not the skills in action.** Spec §11 asks for "a recorded walkthrough on a throwaway chain root". During this plan's run the installed plugin is still 0.1.2, and whether a working-tree plugin can be loaded into the running session is not verified. So Task 12's script makes, by hand, each state change the edited skills prescribe, and records what the board prints; `grep` lines tie each condition to the skill sentence that handles it. No refusal is observed being spoken by a skill. The author may want a live pass after reinstalling the plugin.

### Task 1 — Teach the status fallback the sync rules

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/status/SKILL.md`

**Steps:**

1. Confirm the new text is absent:

   ```
   $ grep -c 'never work it out by eye' plugins/claudestacks-sdlc/skills/status/SKILL.md
   0
   ```

2. Replace this paragraph (`skills/status/SKILL.md:15-23`):

   ````text
   If it is empty, the airsl binary is not installed: derive the same board by
   hand. Scan `.claudestacks/sdlc/` per the rules in
   `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`: skip `prds/`, `rfcs/`
   and non-directories; read each chain's `intent.md`, `spec.md`, and
   `plans/NN-*.md` frontmatter; derive STATE and NEXT exactly per that file's
   NEXT-derivation rules; render an unparseable chain as
   `INVALID (<file>: <reason>)`; collapse to a count line any chain whose intent
   is `done` or `dropped`, or whose every plan is `done`/`superseded` with at
   least one `done`. Same columns, same output shape.
   ````

   with:

   ````text
   If it is empty, the airsl binary is not installed: derive the same board by
   hand, from `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md` and nothing
   else. That file owns every rule the script executes: which top-level entries
   are not chains, the frontmatter keys, the sync rules, NEXT derivation, and
   the board's layout. Scan `.claudestacks/sdlc/` by those rules, skipping the
   entries that file names and every non-directory; read each chain's
   `intent.md`, `spec.md`, and `plans/NN-*.md` frontmatter; derive STATE and
   NEXT exactly per that file's sync and NEXT-derivation rules; render an
   unparseable chain as `INVALID (<file>: <reason>)`.

   Where a rule compares a fingerprint, never work it out by eye. Run

       sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <file>

   for each file the rule names. It prints the 12 characters and exits 0, or
   prints nothing and exits 2 when the file has no fingerprint.

   A chain the rules call `chain complete` is a row, with NEXT
   `execute walk-up` — it is not part of the count. Collapse to the count line
   only the chains whose intent is `done` or `dropped`. Same columns, same
   output shape.
   ````

3. Confirm the new text is present:

   ```
   $ grep -c 'never work it out by eye' plugins/claudestacks-sdlc/skills/status/SKILL.md
   1
   ```

4. Commit `feat(repo): derive the sync rules in the sdlc status fallback`.

### Task 2 — Add the sync check and re-confirmation to design

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/design/SKILL.md`

**Steps:**

1. Confirm the section is absent:

   ```
   $ grep -c '^## Sync check$' plugins/claudestacks-sdlc/skills/design/SKILL.md
   0
   ```

2. Replace these lines (`skills/design/SKILL.md:28-30`):

   ````text
   - `approved` — proceed.

   ## Hard gate
   ````

   with:

   ````text
   - `approved` — proceed.

   ## Sync check

   Before acting, render the board and read this chain's row:

       sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"

   When that prints nothing, `airsl` is not installed: derive the row by hand, the way the
   `status` skill's fallback does. Do the same again after every `status` flip this skill
   makes, and tell the user what the row reads then.

   The row's wording, and what each condition means, come from the sync rules in
   `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`. Three of them are this skill's to
   clear:

   | The row reads | Do |
   |---|---|
   | `spec stale (intent changed)` | Offer re-confirmation, below. |
   | `INVALID (spec.md: missing built-on)` | Offer re-confirmation, below. |
   | `spec disproven by plan NN` | Tell the user that executing plan `NN` disproved a claim of this spec, and that the redesign path (step 11) is what clears it. On their word, follow step 11. The condition ends when the new `spec.md`'s text differs from the text that was disproven — a replacement with the same body leaves it standing. |

   Any other condition on the row is not this skill's to clear. Say what the row reads, in
   the board's own words, and carry on under the state gate above.

   **Re-confirmation.** An approved spec records, in its `built-on` frontmatter key, the
   fingerprint of the intent it was written against. When the intent's text has changed
   since, or the key is missing, ask the user one question: *does this spec still hold
   against the intent as it now reads?* Show them what the intent says now; do not answer
   for them.

   - **An explicit yes** — compute the intent's current fingerprint,

         sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <chain>/intent.md

     write the 12 characters it prints as `built-on` in `spec.md`'s frontmatter, and change
     nothing else in the file. The spec stays `approved`.
   - **A no** — the spec is superseded: follow the redesign path (step 11).

   Re-confirmation is never inferred from silence or from an answer to another question,
   and never given on the user's behalf.

   ## Hard gate
   ````

3. Confirm the section is present:

   ```
   $ grep -c '^## Sync check$' plugins/claudestacks-sdlc/skills/design/SKILL.md
   1
   ```

4. Commit `feat(repo): add the sync check and spec re-confirmation to sdlc design`.

### Task 3 — Have design write `built-on` at draft and at approval

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/design/SKILL.md`

**Steps:**

1. Confirm both new sentences are absent:

   ```
   $ grep -c 'as it reads at this moment' plugins/claudestacks-sdlc/skills/design/SKILL.md
   0
   $ grep -c 'the intent changed while this spec was a draft' plugins/claudestacks-sdlc/skills/design/SKILL.md
   0
   ```

2. Replace checklist step 8 (`skills/design/SKILL.md:150-155`):

   ````text
   8. **Write the spec.** Once the design is agreed upon, write `spec.md` in the chain
      directory, in the body shape from `${CLAUDE_PLUGIN_ROOT}/references/templates.md`,
      with `status: draft` frontmatter. Carry forward any provenance frontmatter
      (`derived-from-prd` / `derived-from-rfc`) the intent or this dialogue names. The spec
      is the durable record — write it to stand on its own without reference to this
      conversation.
   ````

   with:

   ````text
   8. **Write the spec.** Once the design is agreed upon, write `spec.md` in the chain
      directory, in the body shape from `${CLAUDE_PLUGIN_ROOT}/references/templates.md`,
      with `status: draft` frontmatter. Carry forward any provenance frontmatter
      (`derived-from-prd` / `derived-from-rfc`) the intent or this dialogue names. The spec
      is the durable record — write it to stand on its own without reference to this
      conversation.

      The frontmatter also carries `built-on`: the fingerprint of the chain's `intent.md`
      as it reads at this moment. Run

          sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <chain>/intent.md

      and write the 12 characters it prints. If it prints nothing, the intent has no
      fingerprint: stop and name the file rather than write a spec against it.
   ````

3. Replace checklist step 10 (`skills/design/SKILL.md:210-219`):

   ````text
   10. **User review gate.** Ask the user to read the spec file you just wrote and give
      explicit approval, and show them step 9's disposition table in the same message. An
      approval given without sight of the declined findings is not an approval of them.
      This is a mandatory stop, not a formality. If they request
      changes — small clarifications or significant redesigns — revise the spec and present
      it again. **Do not re-spawn the reviewer**; step 9 has already run and runs once per
      spec. Only on explicit
      approval, flip `spec.md`'s frontmatter
      `status: draft → approved` as the last step of this interaction. Committing the spec
      is the user's call — do not auto-commit.
   ````

   with:

   ````text
   10. **User review gate.** Ask the user to read the spec file you just wrote and give
      explicit approval, and show them step 9's disposition table in the same message. An
      approval given without sight of the declined findings is not an approval of them.
      This is a mandatory stop, not a formality. If they request
      changes — small clarifications or significant redesigns — revise the spec and present
      it again. **Do not re-spawn the reviewer**; step 9 has already run and runs once per
      spec.

      Before you ask, compute the intent's fingerprint again and compare it with the
      spec's `built-on`. If they differ, the intent changed while this spec was a draft:
      say so, and the approval question becomes whether the spec still holds against the
      intent as it now reads.

      Only on explicit approval, flip `spec.md`'s frontmatter `status: draft → approved`
      and write the intent's current fingerprint as `built-on`, in the same edit, as the
      last step of this interaction. Then render the board again (Sync check) and tell the
      user what the chain's row reads. Committing the spec is the user's call — do not
      auto-commit.
   ````

4. Confirm both sentences are present:

   ```
   $ grep -c 'as it reads at this moment' plugins/claudestacks-sdlc/skills/design/SKILL.md
   1
   $ grep -c 'the intent changed while this spec was a draft' plugins/claudestacks-sdlc/skills/design/SKILL.md
   1
   ```

5. Commit `feat(repo): record the intent fingerprint on every sdlc spec`.

### Task 4 — Add the sync check, refusals and re-confirmation to plan

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/plan/SKILL.md`

**Steps:**

1. Confirm the section is absent:

   ```
   $ grep -c '^## Sync check$' plugins/claudestacks-sdlc/skills/plan/SKILL.md
   0
   ```

2. Replace these lines (`skills/plan/SKILL.md:50-52`):

   ````text
   This skill never sets `spec: skipped` itself — it only reads the flag.

   ## Dialogue
   ````

   with:

   ````text
   This skill never sets `spec: skipped` itself — it only reads the flag.

   ## Sync check

   Before acting, render the board and read this chain's row:

       sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"

   When that prints nothing, `airsl` is not installed: derive the row by hand, the way the
   `status` skill's fallback does. Do the same again after every `status` flip this skill
   makes, and tell the user what the row reads then.

   The row's wording comes from the sync rules in
   `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`. A plan's **authority** is the
   chain's `spec.md`, or the chain's `intent.md` when the intent carries `spec: skipped`
   and no `spec.md` exists.

   Refuse — naming the file, the condition exactly as the board words it, and what clears
   it — when the row reads any of:

   | The row reads | Cleared by |
   |---|---|
   | `spec stale (intent changed)` | the `design` skill |
   | `spec disproven by plan NN` | the `design` skill |
   | `intent disproven by plan NN` | the `intent` skill |
   | `plan NN <status>: blocked (spec not approved)` | the `design` skill |
   | `INVALID (spec.md: missing built-on)` | the `design` skill |
   | any other `INVALID (…)`, except `INVALID (plans/NN: missing built-on)` | the user, in the file the row names |

   Two conditions are this skill's own to clear. When the row reads
   `plan NN <status>: stale (spec changed)`, `plan NN <status>: stale (intent changed)`, or
   `INVALID (plans/NN: missing built-on)`, take each such plan in number order and offer
   the user two ways out:

   - **Re-confirm it.** Ask one question: *does plan `NN` still hold against its authority
     as that authority now reads?* On an explicit yes, compute the authority's current
     fingerprint,

         sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <authority file>

     write the 12 characters it prints as `built-on` in that plan's frontmatter, and
     change nothing else in the file. The plan keeps its status.
   - **Supersede it.** Flip it `superseded` and write its replacement under the next free
     `NN` (Lifecycle, below).

   Re-confirmation is never inferred, and one plan's yes does not cover another. After
   clearing a condition, render the board again: an `INVALID` result replaces the whole
   row, so another condition may have been standing behind it.

   ## Dialogue
   ````

3. Confirm the section is present:

   ```
   $ grep -c '^## Sync check$' plugins/claudestacks-sdlc/skills/plan/SKILL.md
   1
   ```

4. Commit `feat(repo): add the sync check and plan re-confirmation to sdlc plan`.

### Task 5 — Have plan write `built-on` at draft and at approval

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/plan/SKILL.md`

**Steps:**

1. Confirm the three new passages are absent:

   ```
   $ grep -c 'as it reads when the plan is written' plugins/claudestacks-sdlc/skills/plan/SKILL.md
   0
   $ grep -c '^built-on: <fingerprint>' plugins/claudestacks-sdlc/skills/plan/SKILL.md
   0
   $ grep -c 'the authority changed while this plan was a draft' plugins/claudestacks-sdlc/skills/plan/SKILL.md
   0
   ```

2. Replace this paragraph (`skills/plan/SKILL.md:79-83`):

   ````text
   Plans live at `plans/NN-<kebab-topic>.md` inside the chain directory — the `NN` prefix orders
   plans within the chain, and sibling plans are disambiguated by topic, not renumbering. Each
   plan's frontmatter carries `status`, `created`, and `depends-on` (a list of plan numbers this
   plan needs `done` first; absent or empty means independent — visibly parallelizable across
   worktrees).
   ````

   with:

   ````text
   Plans live at `plans/NN-<kebab-topic>.md` inside the chain directory — the `NN` prefix orders
   plans within the chain, and sibling plans are disambiguated by topic, not renumbering. Each
   plan's frontmatter carries `status`, `created`, `built-on`, and `depends-on` (a list of plan
   numbers this plan needs `done` first; absent or empty means independent — visibly
   parallelizable across worktrees).

   `built-on` is the fingerprint of the plan's authority (Sync check, above)
   as it reads when the plan is written. Run

       sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <authority file>

   and write the 12 characters it prints into every plan of the set. If it prints nothing, the
   authority has no fingerprint: stop and name the file rather than write a plan against it.
   ````

3. In the header template (`skills/plan/SKILL.md:151`), replace this line:

   ````text
   depends-on: [01]                 # optional
   ````

   with:

   ````text
   depends-on: [01]                 # optional
   built-on: <fingerprint>          # the authority's fingerprint when written
   ````

   The key goes after `depends-on`, the position `references/templates.md` gives it (plan 02).

4. Replace the approval-gate paragraph (`skills/plan/SKILL.md:283-287`):

   ````text
   Each plan gets its own approval: present it, ask the user to read and approve, and show the
   rows of the disposition table that belong to that plan in the same message — including the
   declined ones. An approval given without sight of them is not an approval of them. Only on
   explicit approval, flip that plan's frontmatter `status: draft → approved` as the last step of
   the interaction that reviews it — do not flip a plan the user has not yet seen.
   ````

   with:

   ````text
   Each plan gets its own approval: present it, ask the user to read and approve, and show the
   rows of the disposition table that belong to that plan in the same message — including the
   declined ones. An approval given without sight of them is not an approval of them.

   Before you ask, compute the authority's fingerprint again and compare it with the plan's
   `built-on`. If they differ, the authority changed while this plan was a draft: say so, and
   the approval question becomes whether the plan still holds against the authority as it now
   reads.

   Only on explicit approval, flip that plan's frontmatter `status: draft → approved` and write
   the authority's current fingerprint as `built-on`, in the same edit, as the last step of the
   interaction that reviews it — do not flip a plan the user has not yet seen. Then render the
   board again (Sync check) and tell the user what the chain's row reads.
   ````

5. Confirm the three passages are present:

   ```
   $ grep -c 'as it reads when the plan is written' plugins/claudestacks-sdlc/skills/plan/SKILL.md
   1
   $ grep -c '^built-on: <fingerprint>' plugins/claudestacks-sdlc/skills/plan/SKILL.md
   1
   $ grep -c 'the authority changed while this plan was a draft' plugins/claudestacks-sdlc/skills/plan/SKILL.md
   1
   ```

6. Commit `feat(repo): record the authority fingerprint on every sdlc plan`.

### Task 6 — Let execute take a bare chain name for a missed walk-up

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/execute/SKILL.md`

**Steps:**

1. Confirm the new text is absent:

   ```
   $ grep -c 'its intent was never flipped' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   0
   ```

2. Replace the Input section (`skills/execute/SKILL.md:19-23`):

   ````text
   ## Input

   A chain/plan reference, e.g. `2026-08-24-webhook-reliability/01`, resolving to
   `.claudestacks/sdlc/2026-08-24-webhook-reliability/plans/01-<topic>.md`. Given a bare chain
   name with no plan number, ask which plan, offering the chain's `approved` plans as choices.
   ````

   with:

   ````text
   ## Input

   A chain/plan reference, e.g. `2026-08-24-webhook-reliability/01`, resolving to
   `.claudestacks/sdlc/2026-08-24-webhook-reliability/plans/01-<topic>.md`.

   Given a bare chain name with no plan number, read the chain's row on the board first
   (Sync check, below). When the row reads `chain complete`, the chain's plans are finished
   and its intent was never flipped: perform the State walk-up at the end of this file, and
   nothing else — no plan is run. Otherwise ask which plan, offering the chain's `approved`
   plans as choices.
   ````

3. Confirm the new text is present:

   ```
   $ grep -c 'its intent was never flipped' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   1
   ```

4. Commit `feat(repo): let sdlc execute perform a missed walk-up from a chain name`.

### Task 7 — Add the sync check and refusals to execute

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/execute/SKILL.md`

**Steps:**

1. Confirm the section is absent:

   ```
   $ grep -c '^## Sync check$' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   0
   ```

2. Replace these lines (`skills/execute/SKILL.md:25-27`):

   ````text
   ## State gate

   Read the plan's **frontmatter only** — not its body — before anything else:
   ````

   with:

   ````text
   ## Sync check

   Before acting, render the board and read the chain's row:

       sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"

   When that prints nothing, `airsl` is not installed: derive the row by hand, the way the
   `status` skill's fallback does. Do the same again after every `status` flip this skill
   makes — on a plan or on the intent — and tell the user what the row reads then.

   The row's wording comes from the sync rules in
   `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`. A plan's **authority** is the
   chain's `spec.md`, or the chain's `intent.md` when the intent carries `spec: skipped`
   and no `spec.md` exists.

   **Refuse to start or resume the plan** — naming the file, the condition exactly as the
   board words it, and what clears it — when the row reads any of:

   | The row reads | Cleared by |
   |---|---|
   | `INVALID (spec.md: missing built-on)` | the `design` skill |
   | `INVALID (plans/NN: missing built-on)` | the `plan` skill |
   | any other `INVALID (…)` | the user, in the file the row names |
   | `spec stale (intent changed)` | the `design` skill |
   | `plan NN <status>: blocked (spec not approved)`, for the plan you were given | the `design` skill |
   | `plan NN <status>: stale (spec changed)` or `plan NN <status>: stale (intent changed)`, for the plan you were given | the `plan` skill |

   A `blocked` or `stale` part that names a different plan does not stop this one. These
   are refusals, not warnings: stricter than the unmet-`depends-on` case in the state gate
   below, which stays the user's call.

   **While the row reads `spec disproven by plan NN` or `intent disproven by plan NN`**,
   refuse to start or resume every plan of the chain except one: the plan whose own
   `disproves` frontmatter key equals its authority's current fingerprint, which may finish
   the run that raised the condition. Every other plan waits — a `draft` plan you are asked
   to run included — until the `design` skill (for `spec disproven`) or the `intent` skill
   (for `intent disproven`) has brought the text up to date.

   ## State gate

   Read the plan's **frontmatter only** — not its body — before anything else:
   ````

3. Confirm the section is present:

   ```
   $ grep -c '^## Sync check$' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   1
   ```

4. Commit `feat(repo): refuse to execute an sdlc plan whose chain is out of sync`.

### Task 8 — Guard execute's approval of a draft plan

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/execute/SKILL.md`

**Steps:**

1. Confirm the new text is absent:

   ```
   $ grep -c 'provided nobody has changed' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   0
   ```

2. Replace the `draft` bullet of the state gate (`skills/execute/SKILL.md:31-39`):

   ````text
   - `draft` — **the instruction to execute is the approval.** A user who names a plan and asks
     for it to run has done the thing the approval gate exists to capture, so do not refuse and
     do not send them to another skill to say it a second time. Flip
     `draft → approved → executing` yourself and state plainly, in one line, that you did:
     which plan, that it was `draft`, and that executing it is being recorded as its approval.
     Then carry on. Two exceptions where you stop and ask first: the plan carries an unresolved
     marker its own author left for the reader (a `TODO`, an open question, a `TBD`), or the
     reference you were given was a whole chain rather than one named plan — a blanket "execute
     this chain" is not approval of a specific draft nobody has read.
   ````

   with:

   ````text
   - `draft` — **the instruction to execute is the approval**, provided nobody has changed
     what the plan was written against. A user who names a plan and asks for it to run has
     done the thing the approval gate exists to capture, so do not send them to another
     skill to say it a second time. First compare the plan's `built-on` with its
     authority's current fingerprint:

         sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <authority file>

     When the two are equal, flip `draft → approved → executing` yourself and state plainly,
     in one line, that you did: which plan, that it was `draft`, and that executing it is
     being recorded as its approval. Then carry on.

     When they differ, or the plan has no `built-on`, refuse and name the `plan` skill: the
     authority changed after the plan was drafted and nobody has read the plan against the
     new text, so running it would approve something no one reviewed. Refuse the same way,
     naming the `design` skill, when the authority is a `spec.md` that is still `draft` —
     the plan would read `blocked (spec not approved)` the moment it went live.

     Two further cases where you stop and ask first: the plan carries an unresolved marker
     its own author left for the reader (a `TODO`, an open question, a `TBD`), or the
     reference you were given was a whole chain rather than one named plan — a blanket
     "execute this chain" is not approval of a specific draft nobody has read.
   ````

3. Confirm the new text is present:

   ```
   $ grep -c 'provided nobody has changed' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   1
   ```

4. Commit `feat(repo): approve a draft sdlc plan by execution only against unchanged text`.

### Task 9 — Have execute record a disproven authority

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/execute/SKILL.md`

**Steps:**

1. Confirm the new text is absent:

   ```
   $ grep -c 'Record the debt before you continue' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   0
   ```

2. Replace these two paragraphs (`skills/execute/SKILL.md:267-275`):

   ````text
   Stop and put it to the author as **its own question**: *the plan's premise is disproven —
   amend the plan and the spec now, or after this run?* Do not fold it into a question about the
   implementation and read the answer as covering both. Approving a code change is not approving
   the record.

   Sibling plans were written against the old text and cannot see the commit that corrected it.
   A commit body is not where the next plan's author looks. Amending a `draft` plan is the `plan`
   skill's; superseding an approved `spec.md` is the `design` skill's, and the author authorizes
   it.
   ````

   with:

   ````text
   Stop and put it to the author as **its own question**: *the plan's premise is disproven —
   amend the plan and the spec now, or after this run?* Do not fold it into a question about the
   implementation and read the answer as covering both. Approving a code change is not approving
   the record.

   **Record the debt before you continue.** When what the probe disproved is a claim of the
   plan's authority — the chain's `spec.md`, or its `intent.md` on the spec-skip path —
   write `disproves` into the frontmatter of the plan you are running, holding that
   authority's current fingerprint:

       sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <authority file>

   Write it whichever answer the author gives, and before any further task runs. The key
   holds one fingerprint: a later disproof by the same plan overwrites it, and it is never
   removed. From then on the board reads `spec disproven by plan NN` (or
   `intent disproven by plan NN`), no sibling plan can start, and the chain cannot
   complete, until the authority's text changes — at which point the marker matches
   nothing and stops having any effect. A disproven claim that belongs to the plan alone,
   not to its authority, writes no marker.

   Sibling plans were written against the old text and cannot see the commit that corrected it.
   A commit body is not where the next plan's author looks. Amending a `draft` plan is the `plan`
   skill's; superseding an approved `spec.md` is the `design` skill's, and amending the intent
   on the spec-skip path is the `intent` skill's. The author authorizes each.
   ````

3. Confirm the new text is present:

   ```
   $ grep -c 'Record the debt before you continue' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   1
   ```

4. Commit `feat(repo): record a disproven spec on the sdlc plan that found it`.

### Task 10 — Walk the chain up only when it is complete

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/execute/SKILL.md`

**Steps:**

1. Confirm the new text is absent:

   ```
   $ grep -c 'nothing is owed on the chain' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   0
   ```

2. Replace the final section (`skills/execute/SKILL.md:325-332`):

   ````text
   ## State walk-up

   After a plan flips to `done`, check the rest of the chain. If every plan is now `done` or
   `superseded`, with at least one `done`, flip the chain's `intent.md`
   `status: approved → done` and tell the user the chain is complete — the second transition
   that fires without a fresh approval question, a consequence of state already earned on the
   individual plans. If other plans remain `draft`, `approved`, or `executing`, leave the intent
   as is and say what is still open.
   ````

   with:

   ````text
   ## State walk-up

   After a plan flips to `done` — or when you were given a bare chain name whose row reads
   `chain complete` — render the board (Sync check) and read the chain's row.

   - **The row reads `chain complete`.** Every plan is `done` or `superseded`, with at least
     one `done`, and nothing is owed on the chain's text. Flip the chain's `intent.md`
     `status: approved → done` and tell the user the chain is complete — the second
     transition that fires without a fresh approval question, a consequence of state already
     earned on the individual plans.
   - **Every plan is settled, but the row reads `spec stale (intent changed)`,
     `spec disproven by plan NN` or `intent disproven by plan NN`.** The chain is not
     complete. Leave the intent `approved`, and say which condition holds it open and which
     skill clears it: `design` for the two `spec` conditions, `intent` for
     `intent disproven`. The walk-up fires on a later run, once the text is up to date.
   - **Other plans remain `draft`, `approved`, or `executing`.** Leave the intent as is and
     say what is still open.
   ````

3. Confirm the new text is present:

   ```
   $ grep -c 'nothing is owed on the chain' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   1
   ```

4. Commit `feat(repo): hold the sdlc chain walk-up while its text is out of date`.

### Task 11 — Add the sync check on re-invocation to intent

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/intent/SKILL.md`

**Steps:**

1. Confirm the section is absent:

   ```
   $ grep -c '^## Sync check on re-invocation$' plugins/claudestacks-sdlc/skills/intent/SKILL.md
   0
   ```

2. Replace these lines (`skills/intent/SKILL.md:41-43`):

   ````text
     name: the file, its current state, and that un-dropping is the command that advances it.

   ## Input-doc scan
   ````

   with:

   ````text
     name: the file, its current state, and that un-dropping is the command that advances it.

   ## Sync check on re-invocation

   When re-invoked on an existing chain, render the board before acting and read that
   chain's row:

       sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"

   When that prints nothing, `airsl` is not installed: derive the row by hand, the way the
   `status` skill's fallback does. Do the same again after every `status` flip this skill
   makes, and tell the user what the row reads then. A chain being created has no row yet
   and needs no check before it is written.

   The row's wording comes from the sync rules in
   `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`. Two of them touch this skill:

   - **Amending marks what was built on the intent stale.** A spec records the fingerprint
     of the intent's body it was written against, and on the spec-skip path each plan does.
     Before amending the body of an intent whose chain has an `approved` spec — or, with
     `spec: skipped`, a plan that is `approved` or `executing` — tell the user the amendment
     will make the board read `spec stale (intent changed)` (or
     `plan NN <status>: stale (intent changed)`), and that the `design` skill (or the `plan`
     skill) is what clears it afterwards. Then proceed on their word. Only the body counts:
     a `status` flip or a frontmatter key never changes a fingerprint.
   - **`intent disproven by plan NN` is cleared here.** On the spec-skip path the intent is
     the plans' authority, and this row means executing plan `NN` disproved one of its
     claims. It ends when the intent's body is amended to correct what was disproven — this
     skill's amend mode. Afterwards the chain's `approved` and `executing` plans read
     `plan NN <status>: stale (intent changed)` and go to the `plan` skill.

   Any other condition on the row is not this skill's to clear. Say what the row reads and
   carry on with what the user asked.

   ## Input-doc scan
   ````

3. Confirm the section is present:

   ```
   $ grep -c '^## Sync check on re-invocation$' plugins/claudestacks-sdlc/skills/intent/SKILL.md
   1
   ```

4. Commit `feat(repo): warn before an sdlc intent amendment marks its spec stale`.

---

**Checkpoint A — pause here.** Run the gate once and show its output:

```
$ cargo make plugins
```

Expected: `airsl check plugins` reports no error, and the `airsl test` summary line ends `0 failed`, with the same passed count it had before Task 1 (this plan changes no Lua). Present the five edited skill files and wait for "continue" before the walkthrough: it is the only verification this skill text gets.

---

### Task 12 — Record the sync walkthrough

This task changes no repository file. It builds throwaway chain roots under the system temp directory, makes each state change the edited skills prescribe, and records what the board prints.

**Steps:**

1. Write this script to a temp path outside the repository, e.g. `${TMPDIR:-/tmp}/sdlc-sync-walk.sh`:

   ```sh
   #!/bin/sh
   # Sync walkthrough for plan 03 of 2026-10-13-sdlc-roadmaps-milestones.
   #   sh sdlc-sync-walk.sh <absolute path of the repository root>
   # Builds throwaway chain roots, makes the state changes the edited skills
   # prescribe, and prints the board after each one.
   set -eu
   REPO=$1
   P="$REPO/plugins/claudestacks-sdlc"

   fp() { sh "$P/scripts/fingerprint.sh" "$1"; }

   # Starts a fresh chain root for one scenario.
   root() {
     WT=$(mktemp -d)
     R="$WT/.claudestacks/sdlc"
     mkdir -p "$R"
     printf '\n######## %s ########\n' "$1"
   }

   # art <file> <body> <frontmatter line>... — writes one artifact, replacing it.
   art() {
     f=$1; body=$2; shift 2
     mkdir -p "$(dirname "$f")"
     {
       echo '---'
       for line in "$@"; do echo "$line"; done
       echo '---'
       printf '%s\n' "$body"
     } > "$f"
   }

   board() {
     printf '\n-- %s\n' "$1"
     ( cd "$WT" && sh "$P/scripts/status.sh" )
   }

   # ---------------------------------------------------------------- S1
   root "S1 the two chains of spec premise P1"
   C="$R/2026-10-15-gap"
   art "$C/intent.md" "# Intent: gap" "status: approved" "created: 2026-10-15"
   art "$C/spec.md" "# Spec: gap" "status: draft" "created: 2026-10-15"
   art "$C/plans/01-core.md" "# Core Implementation Plan" \
     "status: approved" "created: 2026-10-15"
   D="$R/2026-10-16-nospec"
   art "$D/intent.md" "# Intent: nospec" "status: approved" "created: 2026-10-16"
   art "$D/plans/01-core.md" "# Core Implementation Plan" \
     "status: approved" "created: 2026-10-16"
   board "S1.1 as probed: no built-on anywhere"
   art "$C/plans/01-core.md" "# Core Implementation Plan" \
     "status: approved" "created: 2026-10-15" "built-on: $(fp "$C/spec.md")"
   board "S1.2 the gap chain's plan now carries built-on"

   # ---------------------------------------------------------------- S2
   root "S2 an intent edited after its spec was approved"
   C="$R/2026-10-17-edited"
   art "$C/intent.md" "# Intent: edited" "status: approved" "created: 2026-10-17"
   art "$C/spec.md" "# Spec: edited" \
     "status: approved" "created: 2026-10-17" "built-on: $(fp "$C/intent.md")"
   board "S2.1 spec approved against the intent as written"
   art "$C/intent.md" "# Intent: edited, then amended in place" \
     "status: approved" "created: 2026-10-17"
   board "S2.2 intent amended its body"
   art "$C/spec.md" "# Spec: edited" \
     "status: approved" "created: 2026-10-17" "built-on: $(fp "$C/intent.md")"
   board "S2.3 design re-confirmed the spec: built-on rewritten, nothing else"

   # ---------------------------------------------------------------- S3
   root "S3 a spec superseded under an approved plan"
   C="$R/2026-10-18-superseded"
   art "$C/intent.md" "# Intent: superseded" "status: approved" "created: 2026-10-18"
   art "$C/spec.md" "# Spec: superseded" \
     "status: approved" "created: 2026-10-18" "built-on: $(fp "$C/intent.md")"
   art "$C/plans/01-core.md" "# Core Implementation Plan" \
     "status: approved" "created: 2026-10-18" "built-on: $(fp "$C/spec.md")"
   board "S3.1 plan approved against the governing spec"
   art "$C/spec-superseded-2026-10-19.md" "# Spec: superseded" \
     "status: superseded" "created: 2026-10-18" "built-on: $(fp "$C/intent.md")"
   art "$C/spec.md" "# Spec: superseded, second design" \
     "status: draft" "created: 2026-10-19" "built-on: $(fp "$C/intent.md")"
   board "S3.2 design superseded the spec; the replacement is a draft"
   art "$C/spec.md" "# Spec: superseded, second design" \
     "status: approved" "created: 2026-10-19" "built-on: $(fp "$C/intent.md")"
   board "S3.3 design approved the replacement spec"
   art "$C/plans/01-core.md" "# Core Implementation Plan" \
     "status: approved" "created: 2026-10-18" "built-on: $(fp "$C/spec.md")"
   board "S3.4 plan re-confirmed plan 01 against the new spec"

   # ---------------------------------------------------------------- S4
   root "S4 a draft plan whose spec changed before approval"
   C="$R/2026-10-19-draftplan"
   art "$C/intent.md" "# Intent: draftplan" "status: approved" "created: 2026-10-19"
   art "$C/spec.md" "# Spec: draftplan" \
     "status: approved" "created: 2026-10-19" "built-on: $(fp "$C/intent.md")"
   OLD=$(fp "$C/spec.md")
   art "$C/plans/01-core.md" "# Core Implementation Plan" \
     "status: draft" "created: 2026-10-19" "built-on: $OLD"
   board "S4.1 a draft plan, written against the spec as it read"
   art "$C/spec.md" "# Spec: draftplan, edited in place" \
     "status: approved" "created: 2026-10-19" "built-on: $(fp "$C/intent.md")"
   board "S4.2 the spec's body was edited in place; a draft is not checked on the board"
   printf 'S4.2 plan built-on=%s spec fingerprint now=%s\n' "$OLD" "$(fp "$C/spec.md")"
   art "$C/plans/01-core.md" "# Core Implementation Plan" \
     "status: approved" "created: 2026-10-19" "built-on: $(fp "$C/spec.md")"
   board "S4.3 plan approved it against the spec as it now reads"

   # ---------------------------------------------------------------- S5
   root "S5 a disproves marker holds back a sibling plan, then clears"
   C="$R/2026-10-20-disproven"
   art "$C/intent.md" "# Intent: disproven" "status: approved" "created: 2026-10-20"
   art "$C/spec.md" "# Spec: disproven" \
     "status: approved" "created: 2026-10-20" "built-on: $(fp "$C/intent.md")"
   SP=$(fp "$C/spec.md")
   art "$C/plans/01-core.md" "# Core Implementation Plan" \
     "status: executing" "created: 2026-10-20" "built-on: $SP"
   art "$C/plans/02-extras.md" "# Extras Implementation Plan" \
     "status: approved" "created: 2026-10-20" "built-on: $SP"
   board "S5.1 plan 01 mid-flight, plan 02 ready"
   art "$C/plans/01-core.md" "# Core Implementation Plan" \
     "status: executing" "created: 2026-10-20" "built-on: $SP" "disproves: $SP"
   board "S5.2 execute recorded that plan 01 disproved the spec"
   art "$C/plans/01-core.md" "# Core Implementation Plan" \
     "status: done" "created: 2026-10-20" "built-on: $SP" "disproves: $SP"
   board "S5.3 plan 01 finished its run; the debt still stands"
   art "$C/spec-superseded-2026-10-21.md" "# Spec: disproven" \
     "status: superseded" "created: 2026-10-20" "built-on: $(fp "$C/intent.md")"
   art "$C/spec.md" "# Spec: disproven, corrected" \
     "status: draft" "created: 2026-10-21" "built-on: $(fp "$C/intent.md")"
   board "S5.4 design superseded the spec: the marker matches nothing"
   art "$C/spec.md" "# Spec: disproven, corrected" \
     "status: approved" "created: 2026-10-21" "built-on: $(fp "$C/intent.md")"
   board "S5.5 design approved the replacement spec"
   art "$C/plans/02-extras.md" "# Extras Implementation Plan" \
     "status: approved" "created: 2026-10-20" "built-on: $(fp "$C/spec.md")"
   board "S5.6 plan re-confirmed plan 02 against the new spec"

   # ---------------------------------------------------------------- S6
   root "S6 a disproves marker holds back the walk-up, on the spec-skip path"
   C="$R/2026-10-21-heldwalkup"
   art "$C/intent.md" "# Intent: heldwalkup" \
     "status: approved" "created: 2026-10-21" "spec: skipped"
   IP=$(fp "$C/intent.md")
   art "$C/plans/01-core.md" "# Core Implementation Plan" \
     "status: done" "created: 2026-10-21" "built-on: $IP" "disproves: $IP"
   board "S6.1 every plan settled, the intent still disproven"
   art "$C/intent.md" "# Intent: heldwalkup, corrected" \
     "status: approved" "created: 2026-10-21" "spec: skipped"
   board "S6.2 intent amended its body: the chain is complete, the walk-up is owed"
   art "$C/intent.md" "# Intent: heldwalkup, corrected" \
     "status: done" "created: 2026-10-21" "spec: skipped"
   board "S6.3 execute, given the bare chain name, performed the walk-up"

   # ---------------------------------------------------------------- S7
   root "S7 a missed walk-up, the chain of spec premise P11"
   C="$R/2026-10-17-missed-walkup"
   art "$C/intent.md" "# Intent: missed walk-up" \
     "status: approved" "created: 2026-10-17" "spec: skipped"
   art "$C/plans/01-core.md" "# Core Implementation Plan" \
     "status: done" "created: 2026-10-17"
   board "S7.1 the plan is done, the intent was never flipped"
   art "$C/intent.md" "# Intent: missed walk-up" \
     "status: done" "created: 2026-10-17" "spec: skipped"
   board "S7.2 execute, given the bare chain name, performed the walk-up"
   ```

2. Run it with the repository root's absolute path:

   ```
   $ sh "${TMPDIR:-/tmp}/sdlc-sync-walk.sh" "$(git rev-parse --show-toplevel)"
   ```

   Every board must show the STATE and NEXT below for the chain named. Each row is what the spec section cited requires, and each was printed, exactly as written here, when this script was run on 2026-10-14 against a prototype of the code plans 01 and 02 specify. The run in this task is against the real code; record its output, and treat any difference as a finding.

   | Step | Chain | STATE | NEXT | Spec |
   |---|---|---|---|---|
   | S1.1 | `2026-10-15-gap` | `INVALID (plans/01: missing built-on)` | `fix 2026-10-15-gap` | §3.5 |
   | S1.1 | `2026-10-16-nospec` | `INVALID (plans/01: no spec and no skip flag)` | `fix 2026-10-16-nospec` | §3.5 |
   | S1.2 | `2026-10-15-gap` | `plan 01 approved: blocked (spec not approved)` | `approve spec` | §3.5 |
   | S2.1 | `2026-10-17-edited` | `spec approved` | `plan` | §3.3 |
   | S2.2 | `2026-10-17-edited` | `spec stale (intent changed)` | `design` | §3.2 C1, §3.4 |
   | S2.3 | `2026-10-17-edited` | `spec approved` | `plan` | §2 re-confirmation |
   | S3.1 | `2026-10-18-superseded` | `plan 01 approved` | `execute 01` | §3.3 |
   | S3.2 | `2026-10-18-superseded` | `plan 01 approved: blocked (spec not approved)` | `approve spec` | §3.2 C3 |
   | S3.3 | `2026-10-18-superseded` | `plan 01 approved: stale (spec changed)` | `plan` | §3.2 C4 |
   | S3.4 | `2026-10-18-superseded` | `plan 01 approved` | `execute 01` | §2 re-confirmation |
   | S4.1 | `2026-10-19-draftplan` | `plan 01 draft` | `approve plan 01` | §3.3 |
   | S4.2 | `2026-10-19-draftplan` | `plan 01 draft` | `approve plan 01` | §13 (drafts are not checked) |
   | S4.2 | — | the `printf` line shows two different 12-character values | — | §2 |
   | S4.3 | `2026-10-19-draftplan` | `plan 01 approved` | `execute 01` | §2 |
   | S5.1 | `2026-10-20-disproven` | `plan 01 executing, plan 02 approved` | `execute 02` | §3.3 |
   | S5.2 | `2026-10-20-disproven` | `spec disproven by plan 01, plan 01 executing, plan 02 approved` | `design` | §3.2 C2, §3.4 |
   | S5.3 | `2026-10-20-disproven` | `spec disproven by plan 01, plan 01 done, plan 02 approved` | `design` | §3.2 C2 |
   | S5.4 | `2026-10-20-disproven` | `plan 01 done, plan 02 approved: blocked (spec not approved)` | `approve spec` | §2, §3.2 C3 |
   | S5.5 | `2026-10-20-disproven` | `plan 01 done, plan 02 approved: stale (spec changed)` | `plan` | §3.2 C4 |
   | S5.6 | `2026-10-20-disproven` | `plan 01 done, plan 02 approved` | `execute 02` | §2 |
   | S6.1 | `2026-10-21-heldwalkup` | `intent disproven by plan 01, plan 01 done` | `intent` | §3.2 C2, §3.3, §3.4 |
   | S6.2 | `2026-10-21-heldwalkup` | `chain complete` | `execute walk-up` | §3.3, §7.1 |
   | S6.3 | `2026-10-21-heldwalkup` | no row; the tail reads `DONE/DROPPED: 1 done, 0 dropped (not listed)` | — | §7.1 |
   | S7.1 | `2026-10-17-missed-walkup` | `chain complete` | `execute walk-up` | §6, §7.1 |
   | S7.2 | `2026-10-17-missed-walkup` | no row; the tail reads `DONE/DROPPED: 1 done, 0 dropped (not listed)` | — | §7.1 |

   At S5.2 and S5.3 the NEXT cell must not read `execute 02`: a standing `spec disproven` never offers a plan (spec §3.4).

3. Tie each condition to the sentence that handles it. Run these and keep the output; each must print exactly one line:

   ```
   $ grep -n '| `spec stale (intent changed)` | Offer re-confirmation' plugins/claudestacks-sdlc/skills/design/SKILL.md
   $ grep -n '| `spec disproven by plan NN` | Tell the user' plugins/claudestacks-sdlc/skills/design/SKILL.md
   $ grep -n 'the intent changed while this spec was a draft' plugins/claudestacks-sdlc/skills/design/SKILL.md
   $ grep -n '| `plan NN <status>: blocked (spec not approved)` | the `design` skill |' plugins/claudestacks-sdlc/skills/plan/SKILL.md
   $ grep -n 'Re-confirm it' plugins/claudestacks-sdlc/skills/plan/SKILL.md
   $ grep -n 'the authority changed while this plan was a draft' plugins/claudestacks-sdlc/skills/plan/SKILL.md
   $ grep -n 'refuse to start or resume every plan of the chain except one' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   $ grep -n 'refuse and name the `plan` skill' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   $ grep -n 'Record the debt before you continue' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   $ grep -n 'its intent was never flipped' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   $ grep -n 'The chain is not' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   $ grep -n 'is cleared here' plugins/claudestacks-sdlc/skills/intent/SKILL.md
   $ grep -n 'Amending marks what was built on the intent stale' plugins/claudestacks-sdlc/skills/intent/SKILL.md
   ```

4. Record in this plan's `## Probe results` section, under a `### Walkthrough` heading, at full precision: the command of step 2, the script's complete real output, and the thirteen `grep -n` lines of step 3. Where a real row differs from the table in step 2, do not edit the table to match: stop and report the difference — it means the board (plan 02) and the spec disagree.

---

**Checkpoint B — end of plan.** Present the walkthrough record and the completion report, and wait for the author before flipping this plan to `done`.

---

## Verification summary (plan-level)

- `cargo make plugins` ends `0 failed` with the passed count unchanged from before Task 1 (Checkpoint A).
- Each of Tasks 1–11 showed its phrase absent before the edit and present once after.
- The walkthrough's real output matches every row of Task 12's table, and at no step does a chain with a standing `spec disproven` or `intent disproven` offer `execute NN` or read `chain complete`.
- `git diff --stat` for this plan lists the five `SKILL.md` files of the file structure and this plan file itself (its appended record sections), and nothing under `references/` or `scripts/`.

## Review findings

One `claudestacks:reviewer` round over Tasks 1–11 (report
`.airsstack/cc/plugins/claudestacks/handoff/20261014-094648-c59e/22-reviewer-plan03.md`, git-ignored).
Verdict: conformance byte-exact, every cross-reference resolves; code 0🔴 6🟡 11🔵, spec 0🔴 2🟡 1🔵;
blocking set empty. One fix round followed (see Deviations); the reviewer was not re-run.

- cross-skill consistency — `design` called every row outside its table "not this skill's to clear", while `plan` and `execute` send `blocked (spec not approved)` to it — `skills/design/SKILL.md:50-51` — fixed (F1): a fourth row sends it to the review gate, step 10. Unverified beyond the greps under Probe results.
- missing re-render — writing `built-on` (design), amending (intent) and writing `disproves` (execute) are not status flips, so the "render again after every flip" rule never fired and a condition hidden behind a cleared `INVALID` went unreported — `design:59-65`, `intent:66-70`, `execute:328-341` — fixed (F2). Unverified beyond the greps under Probe results.
- flip rule — "A no — the spec is superseded: follow step 11" read a no as authority to supersede — `design:65` — fixed (F3): on a no, offer step 11 and follow it only on the user's explicit word.
- guard ordering — the `draft` permit preceded both refusals and the ask-first cases — `execute:74-95` — fixed (F4): refusals and ask-first cases now come first; the refusal reason also covers a missing `built-on`.
- unverifiable claim — the status fallback said `artifact-chain.md` owns "the board's layout"; header, widths and tail wording live only in `lib/status.lua` `M.render` — `status:16-19` — fixed (F5): the reference owns each row's STATE and NEXT; the layout is named in the skill.
- test teeth — reverting any of the eleven edits trips nothing; the greps run once and the walkthrough records but does not gate — all five skills — not fixed: spec §11 accepts that skill prose has no unit test.
- nit — "Before you ask" check placed after the instruction to ask — `design:266-275` — not fixed.
- nit — a bare chain whose plans are all settled while C1/C2 stands is offered zero plans; walk-up bullet 2 would be the useful answer — `execute:24-28` — not fixed.
- nit — "except one": every plan whose `disproves` matches is exempt, not only one — `execute:61-66` — not fixed.
- nit — the state gate's "before anything else" now sits after the Sync check — `execute:70,73` — not fixed.
- nit — the walk-up bullets are not exhaustive (all settled with the row INVALID; all superseded with none done); safe because the intent flips only under bullet 1 — `execute:401-412` — not fixed.
- nit — I4 has two exits (state gate: design or intent; sync table: the user) — `plan:44-47,77` — not fixed.
- nit — precedence unstated when one row holds a refusal part and a stale part — `plan:67-93` — not fixed.
- nit — kept old text tells `plan` to "fix the spec", which in place would stale every live plan and bypass `design` — `plan:165-167` — not fixed.
- nit — "prints nothing, so `airsl` is not installed" also fires when `airsl run` fails (`status.sh:26-28`) — all four Sync checks and `status` — not fixed.
- nit — Sync checks point at "the status skill's fallback" instead of `artifact-chain.md` §9–§10 — all four Sync checks — not fixed.
- spec hygiene — decisions 2–4 of this plan extend spec §8.4/§8.5 and are recorded only here — plan lines 40-46 — open, author's call.
- spec gap — an all-settled chain whose disproven spec was superseded reads `chain complete` → `execute walk-up` mid-redesign, and `execute` would then flip the intent `done` — spec §3.3, `execute:401-405` — open, author's call.
- spec gap — between step 11's rename and the new `spec.md`, a chain with live plans reads I4, which the tables route to "the user" rather than `design` — spec §10, `plan:77`, `execute:52` — open, author's call.

## Probe results

### Walkthrough

Run on 2026-10-14 against the real code of plans 01 and 02. The script is the one in Task 12 step 1, unedited, run from outside the repository.

Command:

```
$ sh /private/tmp/claude-501/-Users-hiraq-Projects-airsstack-claudestacks/9ec84b5c-9416-415b-97a4-e06f57d16fc6/scratchpad/walk03/sdlc-sync-walk.sh /Users/hiraq/Projects/airsstack/claudestacks/.claude/worktrees/sdlc-milestones-roadmap
```

Output:

```

######## S1 the two chains of spec premise P1 ########

-- S1.1 as probed: no built-on anywhere
CHAIN                             STATE                         NEXT
2026-10-15-gap                    INVALID (plans/01: missing built-on)  fix 2026-10-15-gap
2026-10-16-nospec                 INVALID (plans/01: no spec and no skip flag)  fix 2026-10-16-nospec

-- S1.2 the gap chain's plan now carries built-on
CHAIN                             STATE                         NEXT
2026-10-15-gap                    plan 01 approved: blocked (spec not approved)  approve spec
2026-10-16-nospec                 INVALID (plans/01: no spec and no skip flag)  fix 2026-10-16-nospec

######## S2 an intent edited after its spec was approved ########

-- S2.1 spec approved against the intent as written
CHAIN                             STATE                         NEXT
2026-10-17-edited                 spec approved                 plan

-- S2.2 intent amended its body
CHAIN                             STATE                         NEXT
2026-10-17-edited                 spec stale (intent changed)   design

-- S2.3 design re-confirmed the spec: built-on rewritten, nothing else
CHAIN                             STATE                         NEXT
2026-10-17-edited                 spec approved                 plan

######## S3 a spec superseded under an approved plan ########

-- S3.1 plan approved against the governing spec
CHAIN                             STATE                         NEXT
2026-10-18-superseded             plan 01 approved              execute 01

-- S3.2 design superseded the spec; the replacement is a draft
CHAIN                             STATE                         NEXT
2026-10-18-superseded             plan 01 approved: blocked (spec not approved)  approve spec

-- S3.3 design approved the replacement spec
CHAIN                             STATE                         NEXT
2026-10-18-superseded             plan 01 approved: stale (spec changed)  plan

-- S3.4 plan re-confirmed plan 01 against the new spec
CHAIN                             STATE                         NEXT
2026-10-18-superseded             plan 01 approved              execute 01

######## S4 a draft plan whose spec changed before approval ########

-- S4.1 a draft plan, written against the spec as it read
CHAIN                             STATE                         NEXT
2026-10-19-draftplan              plan 01 draft                 approve plan 01

-- S4.2 the spec's body was edited in place; a draft is not checked on the board
CHAIN                             STATE                         NEXT
2026-10-19-draftplan              plan 01 draft                 approve plan 01
S4.2 plan built-on=4c6e45bfc95a spec fingerprint now=58a010624fe0

-- S4.3 plan approved it against the spec as it now reads
CHAIN                             STATE                         NEXT
2026-10-19-draftplan              plan 01 approved              execute 01

######## S5 a disproves marker holds back a sibling plan, then clears ########

-- S5.1 plan 01 mid-flight, plan 02 ready
CHAIN                             STATE                         NEXT
2026-10-20-disproven              plan 01 executing, plan 02 approved  execute 02

-- S5.2 execute recorded that plan 01 disproved the spec
CHAIN                             STATE                         NEXT
2026-10-20-disproven              spec disproven by plan 01, plan 01 executing, plan 02 approved  design

-- S5.3 plan 01 finished its run; the debt still stands
CHAIN                             STATE                         NEXT
2026-10-20-disproven              spec disproven by plan 01, plan 01 done, plan 02 approved  design

-- S5.4 design superseded the spec: the marker matches nothing
CHAIN                             STATE                         NEXT
2026-10-20-disproven              plan 01 done, plan 02 approved: blocked (spec not approved)  approve spec

-- S5.5 design approved the replacement spec
CHAIN                             STATE                         NEXT
2026-10-20-disproven              plan 01 done, plan 02 approved: stale (spec changed)  plan

-- S5.6 plan re-confirmed plan 02 against the new spec
CHAIN                             STATE                         NEXT
2026-10-20-disproven              plan 01 done, plan 02 approved  execute 02

######## S6 a disproves marker holds back the walk-up, on the spec-skip path ########

-- S6.1 every plan settled, the intent still disproven
CHAIN                             STATE                         NEXT
2026-10-21-heldwalkup             intent disproven by plan 01, plan 01 done  intent

-- S6.2 intent amended its body: the chain is complete, the walk-up is owed
CHAIN                             STATE                         NEXT
2026-10-21-heldwalkup             chain complete                execute walk-up

-- S6.3 execute, given the bare chain name, performed the walk-up
CHAIN                             STATE                         NEXT
DONE/DROPPED: 1 done, 0 dropped (not listed)

######## S7 a missed walk-up, the chain of spec premise P11 ########

-- S7.1 the plan is done, the intent was never flipped
CHAIN                             STATE                         NEXT
2026-10-17-missed-walkup          chain complete                execute walk-up

-- S7.2 execute, given the bare chain name, performed the walk-up
CHAIN                             STATE                         NEXT
DONE/DROPPED: 1 done, 0 dropped (not listed)
```

Comparison with the Task 12 table: every board row matches character for character, and the S4.2 `printf` line shows two different 12-character values. At S5.2 and S5.3 the NEXT cell reads `design`, not `execute 02`.

The 13 `grep -n` lines of Task 12 step 3, each printing exactly one line:

```
$ grep -n '| `spec stale (intent changed)` | Offer re-confirmation' plugins/claudestacks-sdlc/skills/design/SKILL.md
46:| `spec stale (intent changed)` | Offer re-confirmation, below. |
$ grep -n '| `spec disproven by plan NN` | Tell the user' plugins/claudestacks-sdlc/skills/design/SKILL.md
48:| `spec disproven by plan NN` | Tell the user that executing plan `NN` disproved a claim of this spec, and that the redesign path (step 11) is what clears it. On their word, follow step 11. The condition ends when the new `spec.md`'s text differs from the text that was disproven — a replacement with the same body leaves it standing. |
$ grep -n 'the intent changed while this spec was a draft' plugins/claudestacks-sdlc/skills/design/SKILL.md
267:   spec's `built-on`. If they differ, the intent changed while this spec was a draft:
$ grep -n '| `plan NN <status>: blocked (spec not approved)` | the `design` skill |' plugins/claudestacks-sdlc/skills/plan/SKILL.md
75:| `plan NN <status>: blocked (spec not approved)` | the `design` skill |
$ grep -n 'Re-confirm it' plugins/claudestacks-sdlc/skills/plan/SKILL.md
84:- **Re-confirm it.** Ask one question: *does plan `NN` still hold against its authority
$ grep -n 'the authority changed while this plan was a draft' plugins/claudestacks-sdlc/skills/plan/SKILL.md
344:`built-on`. If they differ, the authority changed while this plan was a draft: say so, and
$ grep -n 'refuse to start or resume every plan of the chain except one' plugins/claudestacks-sdlc/skills/execute/SKILL.md
62:refuse to start or resume every plan of the chain except one: the plan whose own
$ grep -n 'refuse and name the `plan` skill' plugins/claudestacks-sdlc/skills/execute/SKILL.md
86:  When they differ, or the plan has no `built-on`, refuse and name the `plan` skill: the
$ grep -n 'Record the debt before you continue' plugins/claudestacks-sdlc/skills/execute/SKILL.md
328:**Record the debt before you continue.** When what the probe disproved is a claim of the
$ grep -n 'its intent was never flipped' plugins/claudestacks-sdlc/skills/execute/SKILL.md
26:and its intent was never flipped: perform the State walk-up at the end of this file, and
$ grep -n 'The chain is not' plugins/claudestacks-sdlc/skills/execute/SKILL.md
407:  `spec disproven by plan NN` or `intent disproven by plan NN`.** The chain is not
$ grep -n 'is cleared here' plugins/claudestacks-sdlc/skills/intent/SKILL.md
66:- **`intent disproven by plan NN` is cleared here.** On the spec-skip path the intent is
$ grep -n 'Amending marks what was built on the intent stale' plugins/claudestacks-sdlc/skills/intent/SKILL.md
58:- **Amending marks what was built on the intent stale.** A spec records the fingerprint
```

### After the fix round

The same 13 `grep -n` checks were re-run after the fix round (F1–F5): each still prints
exactly one line, with the text unchanged and only the line numbers moved (design 46, 48,
271; plan 75, 84, 344; execute 62, 82, 330, 26, 413; intent 66, 58). The 14 per-task
`grep -c` checks of Tasks 1–11 each still print `1`. The two passages plan 05 quotes
verbatim, formerly `intent/SKILL.md:72-73` and `execute/SKILL.md:411-412`, are byte-identical
and now sit at `:76-77` and `:417-418`.

### Gate

`cargo make plugins`, run after plan 02's Task 6 with all eleven skill edits in place:

```
69 file(s) compiled, 0 failed
441 passed, 0 failed (21 files)
fingerprint gate: 8 cases passed
fingerprint gate: 8 cases passed with sha256sum
```

## Deviations

- **2026-10-14 — started before plan 02 was `done`.** `depends-on: [02]`. The author's goal
  for the session was to execute plans 01 to 03; Tasks 1–11 ran while plan 02's Tasks 3–7
  were in flight. Their files are disjoint from plan 02's. The walkthrough (Task 12) ran only
  after plan 02's board code was complete.
- **2026-10-14 — Checkpoint A not paused at.** The same goal directed execution to continue;
  the gate was run once plan 02 settled (above) instead of at the checkpoint itself.
- **2026-10-14 — Tasks 7–10 given to one coder in order**, because all four edit
  `skills/execute/SKILL.md`. Each task's grep was still run before and after its own edit.
- **2026-10-14 — no per-task briefs.** Coders read their task straight from this plan's line
  range rather than from a `task-briefer` brief.
- **2026-10-14 — no per-task commits.** Committing is the author's act; every change is in
  the working tree, so the per-task commit messages are not yet used.
- **2026-10-14 — fix round departs from this plan's text.** F1–F5 under Review findings
  change wording the plan gave verbatim, in `design`, `intent`, `execute` and `status`.
  F2 differs from what was asked: `intent` and `execute` have no re-confirmation step, so
  the re-render sentence went after the non-flip edit each makes (`intent`: an amendment
  clearing `intent disproven`; `execute`: writing `disproves`).
