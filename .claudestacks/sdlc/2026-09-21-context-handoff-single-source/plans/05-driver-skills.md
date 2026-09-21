---
status: approved
created: 2026-09-21
depends-on: [01, 03]
---

# Driver Skill Implementation Plan

**Goal:** Every driver reaches the handoff procedure by invoking the `context-handoff` skill instead of restating it.

**Architecture:** Six skills across three plugins each carry their own account of the protocol — two describing the session lifecycle in full, four explaining independently why they skip it. Each is cut to an invocation of `/claudestacks:context-handoff` plus what is genuinely local: which spawns it makes, in what order, and where its reports land. This plan also owns the three references to the protocol's old path that plan `01` deliberately left behind, at `orchestrate/SKILL.md:107`, `:122` and `execute/SKILL.md:98`, because all three sit inside sections replaced here.

**Tech Stack:** Markdown skill definitions.

---

### Task 1 — Convert `orchestrate`

**Files:**
- Modify `plugins/claudestacks/skills/orchestrate/SKILL.md`

**Steps:**

1. Confirm the section being replaced, and that it carries two of the three stale path references
   this plan owns:

   ```
   $ sed -n '103,122p' plugins/claudestacks/skills/orchestrate/SKILL.md
   $ grep -n "references/context-handoff.md" plugins/claudestacks/skills/orchestrate/SKILL.md
   107:1. **Session start.** Run `handoff.lua init` (full invocation in `references/context-handoff.md`) once at the top of the
   122:The full protocol — file schema, contract, retention — is `process-guidelines/references/context-handoff.md`.
   ```

2. Replace lines `103-122` with:

   ```markdown
   ## Context handoff

   Subagents report through the filesystem so you hold summaries, not full detail. Invoke
   `/claudestacks:context-handoff` once at the top of the pipeline and follow it — it owns the
   tier decision, which session calls to make, and the protocol path every brief carries.

   This flow holds several agents in flight at once, so it takes the session tier.

   What is local to you: one `coder` per task with disjoint file sets, a single `reviewer` spawn
   over the batch diff, and the user commit gate. Route off each agent's `<summary>`; open a
   `<detail>` only when you personally must judge it.
   ```

3. Confirm the section is gone. Use a string the old section actually carried —
   `handoff.lua init` appears once before the edit and must appear zero times after:

   ```
   $ grep -c "handoff.lua init" plugins/claudestacks/skills/orchestrate/SKILL.md
   0
   ```

   Run this before the edit as well; it returns `1`. A check reading `0` both before and after
   proves nothing, which is why the pattern is this string and not `airsl run` — that one already
   reads `0` in this file today.

4. Confirm both stale path references are gone and the invocation is in:

   ```
   $ grep -c "references/context-handoff.md" plugins/claudestacks/skills/orchestrate/SKILL.md
   0
   $ grep -c "claudestacks:context-handoff" plugins/claudestacks/skills/orchestrate/SKILL.md
   1
   ```

5. Commit `refactor(repo): point orchestrate at the context-handoff skill`.

---

### Task 2 — Convert `execute`

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/execute/SKILL.md`

**Steps:**

1. Confirm the section being replaced and the stale reference inside it:

   ```
   $ sed -n '94,116p' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   $ grep -n "references/context-handoff.md" plugins/claudestacks-sdlc/skills/execute/SKILL.md
   98:`skills/process-guidelines/references/context-handoff.md`. Drive it:
   ```

2. Replace lines `94-116` with:

   ```markdown
   ## Context handoff

   Subagent detail stays on disk; only summaries reach you. Invoke
   `/claudestacks:context-handoff` once at the top of the run and follow it — it owns the tier
   decision, which session calls to make, and the protocol path every brief carries.

   This run holds several agents in flight at once, so it takes the session tier.

   What is local to you: the batching rules below, one handoff file per spawn, and never two
   concurrent coders on the same file. When a coder needs a task's verbatim text, pass the
   upstream `handoff:` path plus a `need:` pointer rather than paraphrasing it.
   ```

3. Confirm the stale reference is gone and the invocation is in:

   ```
   $ grep -c "references/context-handoff.md" plugins/claudestacks-sdlc/skills/execute/SKILL.md
   0
   $ grep -c "claudestacks:context-handoff" plugins/claudestacks-sdlc/skills/execute/SKILL.md
   1
   ```

4. Confirm the spawn briefs elsewhere in the file are untouched. Two lines match a bare
   `handoff:` at line start or three-space indent — `:69` and `:167`. The third mention, at
   `:177`, is a bullet reading ``- `handoff: …` `` and does not match that pattern; count it
   separately rather than expecting three:

   ```
   $ grep -c "^handoff: \|^   handoff: " plugins/claudestacks-sdlc/skills/execute/SKILL.md
   2
   $ grep -c '^   - `handoff: ' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   1
   ```

5. Commit `refactor(repo): point execute at the context-handoff skill`.

---

### Task 3 — Add the protocol field to every spawn brief in `execute`

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/execute/SKILL.md`

**Steps:**

1. `execute` spawns `task-briefer` and `coder`. `task-briefer` is cross-plugin and reads the
   protocol from its brief; `coder` is in `claudestacks` and cites it directly, but the field is
   harmless and keeps the briefs uniform. Add it to the ledger spawn at `:69`:

   ```
   mode: ledger
   plan: <chain>/plans/NN-<topic>.md
   handoff: <session-dir>/01-task-briefer-ledger.md
   handoff-protocol: <the path /claudestacks:context-handoff gave you>
   ```

2. Add it to the per-task brief spawn at `:167`:

   ```
   mode: brief
   plan: <chain>/plans/NN-<topic>.md
   task: <N>
   handoff: <session-dir>/<NN>-task-briefer-task<N>.md
   handoff-protocol: <the path /claudestacks:context-handoff gave you>
   ```

3. Add a bullet to the coder brief list at `:177`, matching the existing bullet form:

   ```markdown
   - `handoff-protocol: <the path /claudestacks:context-handoff gave you>` — the protocol;
   ```

4. Confirm three sites carry it:

   ```
   $ grep -c "handoff-protocol" plugins/claudestacks-sdlc/skills/execute/SKILL.md
   3
   ```

5. Commit `feat(repo): pass the protocol path in execute's spawn briefs`.

---

### Task 4 — Convert `design` and `plan`

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/design/SKILL.md`
- Modify `plugins/claudestacks-sdlc/skills/plan/SKILL.md`

**Steps:**

1. In `design/SKILL.md`, confirm the two ranges. The brief block sits at `:161-166` **inside
   numbered item 9, at a three-space indent**; the rationale paragraph follows at `:169-171`:

   ```
   $ sed -n '159,171p' plugins/claudestacks-sdlc/skills/design/SKILL.md
   ```

2. Replace the brief block at `:161-166`, keeping the three-space indent the surrounding list item
   requires:

   ```
      kind: spec
      draft: <chain>/spec.md
      authority: <chain>/intent.md
      handoff: <TMPDIR>/claudestacks-sdlc-<chain>-spec-<NN>.md
      handoff-protocol: <the path /claudestacks:context-handoff gave you>
   ```

3. Replace the rationale paragraph at `:169-171`, at the same indent:

   ```markdown
      Invoke `/claudestacks:context-handoff` for the tier rules and the protocol path. This flow
      spawns exactly one subagent, so it takes a literal temp path and mints no session. Expand
      `${TMPDIR:-/tmp}` yourself before the path enters the brief. The report is always `01`.
   ```

4. In `plan/SKILL.md`, the same two elements are flush left: the brief block at `:221-226` and the
   rationale at `:228-230`. Confirm, then replace the brief:

   ```
   $ sed -n '219,231p' plugins/claudestacks-sdlc/skills/plan/SKILL.md
   ```

   ```
   kind: plan-set
   draft: <chain>/plans/NN-*.md
   authority: <chain>/spec.md
   handoff: <TMPDIR>/claudestacks-sdlc-<chain>-plan-set-<NN>.md
   handoff-protocol: <the path /claudestacks:context-handoff gave you>
   ```

   and the rationale, flush left:

   ```markdown
   Invoke `/claudestacks:context-handoff` for the tier rules and the protocol path. This flow
   spawns exactly one subagent, so it takes a literal temp path and mints no session. Expand
   `${TMPDIR:-/tmp}` yourself before the path enters the brief. The report is always `01`.
   ```

5. Confirm neither skill still argues the exception for itself, and that both now invoke the skill.
   The pattern is a phrase each file carries today:

   ```
   $ grep -c "an agent receives its brief as literal text" plugins/claudestacks-sdlc/skills/design/SKILL.md plugins/claudestacks-sdlc/skills/plan/SKILL.md
   plugins/claudestacks-sdlc/skills/design/SKILL.md:0
   plugins/claudestacks-sdlc/skills/plan/SKILL.md:0
   $ grep -c "claudestacks:context-handoff" plugins/claudestacks-sdlc/skills/design/SKILL.md plugins/claudestacks-sdlc/skills/plan/SKILL.md
   plugins/claudestacks-sdlc/skills/design/SKILL.md:1
   plugins/claudestacks-sdlc/skills/plan/SKILL.md:1
   ```

   Run the first command before the edits; both files return `1`.

6. Commit `refactor(repo): point design and plan at the context-handoff skill`.

---

### Task 5 — Convert `distill`

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/distill/SKILL.md`

**Steps:**

1. Confirm the brief block and its rationale:

   ```
   $ sed -n '47,60p' plugins/claudestacks-sdlc/skills/distill/SKILL.md
   ```

   The brief is `:49-53`; the rationale that follows explains the `${TMPDIR}` expansion and the
   `corpus` segment.

2. Replace the brief:

   ```
   glob: .claudestacks/sdlc/*/plans/*.md
   heading: ## Review findings
   handoff: <TMPDIR>/claudestacks-sdlc-corpus-findings-<NN>.md
   handoff-protocol: <the path /claudestacks:context-handoff gave you>
   ```

   and the rationale:

   ```markdown
   Invoke `/claudestacks:context-handoff` for the tier rules and the protocol path. One subagent,
   so a literal temp path and no session. Expand `${TMPDIR:-/tmp}` yourself before the path enters
   the brief. The `corpus` segment stands where a chain name goes, because this scan spans every
   chain rather than one. `<NN>` starts at `01` and increments on each re-scan.
   ```

3. `distill` is the one caller instructed to read a `<detail>` into the main thread. Confirm that
   instruction still describes what `chain-reader` emits after plan `04` Task 5 pinned its
   `<detail>` shape as `### <path>` headings with verbatim bodies:

   ```
   $ grep -n "detail" plugins/claudestacks-sdlc/skills/distill/SKILL.md
   ```

   If any line describes a different shape — indented blocks, `---` separators — correct it to
   match the `<detail>` template now in `plugins/claudestacks-sdlc/agents/chain-reader.md`. The two
   must agree, or `distill` parses something the agent no longer writes.

4. Commit `refactor(repo): point distill at the context-handoff skill`.

---

### Task 6 — Convert `journal-review`

**Files:**
- Modify `plugins/claudestacks-journal/skills/journal-review/SKILL.md`

**Steps:**

1. Confirm the steps being replaced, including the paragraph reasoning about the sibling plugin's
   versioned install path:

   ```
   $ sed -n '64,80p' plugins/claudestacks-journal/skills/journal-review/SKILL.md
   ```

2. Replace step 4's body. The reasoning it carried — that a sibling plugin's path cannot be spelled
   because its version is not exposed — is now the protocol's own, and the skill it invokes solves
   the problem rather than working around it:

   ```markdown
   4. Invoke `/claudestacks:context-handoff` for the tier rules and the protocol path. This review
      spawns exactly one subagent, so it takes a literal temp path and mints no session:

      `${TMPDIR:-/tmp}/journal-curator-review.md`
   ```

3. Extend step 5's spawn to pass both fields:

   ```markdown
   5. Spawn the `journal-curator` subagent (`subagent_type: journal-curator`), passing `scope`, the
      `vault` root, the `health_report` temp path, the literal
      `${TMPDIR:-/tmp}/journal-curator-review.md` from step 4 as `handoff`, and the protocol path
      from step 4 as `handoff-protocol`. The curator applies its additive edits and returns a
      one-line summary plus its handoff path.
   ```

4. Confirm the workaround prose is gone and the invocation is in:

   ```
   $ grep -c "whose install path carries that plugin's version" plugins/claudestacks-journal/skills/journal-review/SKILL.md
   0
   $ grep -c "claudestacks:context-handoff" plugins/claudestacks-journal/skills/journal-review/SKILL.md
   1
   ```

   Run the first before the edit; it returns `1`.

5. Confirm the unrelated `airsl run` for `graph-health.lua` at `:56-61` is untouched — it has
   nothing to do with handoff and must survive:

   ```
   $ grep -c "graph-health.lua" plugins/claudestacks-journal/skills/journal-review/SKILL.md
   1
   ```

6. Commit `refactor(repo): point journal-review at the context-handoff skill`.

---

### Task 7 — Assert no driver restates the procedure

**Files:**
- None — verification only.

**Steps:**

1. All six drivers must invoke the skill:

   ```
   $ grep -rl "claudestacks:context-handoff" \
       plugins/claudestacks/skills/orchestrate/SKILL.md \
       plugins/claudestacks-sdlc/skills/execute/SKILL.md \
       plugins/claudestacks-sdlc/skills/design/SKILL.md \
       plugins/claudestacks-sdlc/skills/plan/SKILL.md \
       plugins/claudestacks-sdlc/skills/distill/SKILL.md \
       plugins/claudestacks-journal/skills/journal-review/SKILL.md | wc -l
          6
   ```

2. The handoff `airsl` invocation must exist in exactly one file in the whole tree. Key on
   `AIRSSTACK_HANDOFF_KEEP`, which that invocation carries and no other `airsl run` in the
   repository does — including the `graph-health.lua` one in `journal-review`:

   ```
   $ grep -rln "AIRSSTACK_HANDOFF_KEEP" plugins/
   plugins/claudestacks/scripts/handoff.lua
   plugins/claudestacks/skills/context-handoff/references/protocol.md
   ```

   Two files, and both are correct: `handoff.lua` documents its own invocation in its header
   comment, and `protocol.md` is the authority. `SKILL.md` must **not** appear — spec §3 puts the
   command line in the protocol and the skill points at it. A third path here is a copy that
   should not exist.

3. Prove the pattern finds what it is meant to find, by running it against the file that
   definitely carries it:

   ```
   $ grep -c "AIRSSTACK_HANDOFF_KEEP" plugins/claudestacks/skills/context-handoff/references/protocol.md
   1
   ```

   A control against `git grep … HEAD` does **not** work here: no `SKILL.md` has ever carried this
   string, so such a control returns nothing and proves nothing.

4. Confirm no reference to the protocol's old path survives anywhere in the tree, now that this
   plan has cleared the three plan `01` left:

   ```
   $ grep -rn "references/context-handoff.md" plugins/
   $ echo "exit=$?"
   exit=1
   ```

5. Commit nothing.
