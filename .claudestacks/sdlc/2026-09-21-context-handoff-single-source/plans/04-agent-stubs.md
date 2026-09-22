---
status: approved
created: 2026-09-21
depends-on: [01, 03]
---

# Agent Stub Implementation Plan

**Goal:** Every writer agent carries the same handoff contract and reaches the full protocol through a pointer that resolves at runtime.

**Architecture:** Seven agent definitions today restate between ten and twenty lines of protocol each, three of them byte-identical and one carrying a clause meant for a different agent. Each is cut to a four-sentence stub holding only what must hold if the pointer is never read, plus one pointer line. The three `claudestacks` agents cite `${CLAUDE_PLUGIN_ROOT}` directly, which resolves in-plugin and works even standalone; the four cross-plugin agents take the path from their brief's `handoff-protocol:` field, because no literal they could write would survive a version bump. `chain-reader` and `artifact-reviewer` carry the stub as the opening of a `## Report` section rather than as a separate one, so no definition describes its file shape twice.

**Tech Stack:** Markdown agent definitions.

**Amended during execution, 2026-09-22.** This plan was corrected while being executed; the
text below is the corrected text, not what was originally approved. Five changes, each measured
against the tree rather than reasoned:

- Task 2 step 3's md5 comparison was replaced. The original `sed -n` script issued no `p`, so it
  emitted zero bytes for every file and the three "equal" hashes were all `md5("")` — it reported
  success whatever the files held.
- Task 2 step 4 named two different sections for one insertion. Resolved to `## Boundaries`.
- Task 5's `<summary>` and `<detail>` templates omitted three behavioural rules the old
  `## Output` carried — the two zero-case rules, `in glob order`, and the `<summary>`'s glob echo.
  All three are now in the block, with their destinations cited. They were lost in the tree first
  and restored in the fix round.
- Task 6's `<detail>` template is unchanged, and spec §5.3 was amended instead to authorize the
  section-per-tier shape. The author took that decision; see §5.3's exception paragraphs.
- Task 7 step 3's second `grep` pattern was shortened to `path in your`. The stub wraps after that
  word, so `path in your brief` spans a line break and matched none of the four files.

---

### Task 1 — Convert `explorer`, and fix the clause that does not belong to it

**Files:**
- Modify `plugins/claudestacks/agents/explorer.md`

**Steps:**

1. Confirm the section being replaced, and the stray clause inside it:

   ```
   $ sed -n '65,76p' plugins/claudestacks/agents/explorer.md
   ## Context handoff
   ...
   $ grep -n "for the coder, source within task scope" plugins/claudestacks/agents/explorer.md
   72:file (and, for the coder, source within task scope) — never write or edit any other file via this channel;
   ```

2. Replace lines `65-76` entirely with the stub:

   ```markdown
   ## Context handoff

   When your brief gives you a handoff write-path, write ONE file there: `<summary>…</summary>`
   wrapping what the orchestrator routes on, `<detail>…</detail>` wrapping the heavy material,
   omitted when there is none. Return ONLY the `<summary>` plus that path, never the `<detail>`.
   Write no file but that one through this channel. If no path is given, or the write fails (say
   so), return your full receipt inline. Full protocol:
   `${CLAUDE_PLUGIN_ROOT}/skills/context-handoff/references/protocol.md`.
   ```

3. Confirm the stray clause is gone and the pointer is in place:

   ```
   $ grep -n "for the coder, source within task scope" plugins/claudestacks/agents/explorer.md
   $ echo "exit=$?"
   exit=1
   $ grep -c "CLAUDE_PLUGIN_ROOT" plugins/claudestacks/agents/explorer.md
   1
   ```

4. Confirm the pointer target exists — a pointer that does not resolve is the defect this chain
   exists to remove:

   ```
   $ test -f plugins/claudestacks/skills/context-handoff/references/protocol.md && echo RESOLVES
   RESOLVES
   ```

5. Commit `refactor(repo): cut explorer's handoff section to the stub`.

---

**CHECKPOINT — stop here and present.** One agent is converted. The stub's exact wording is about
to be repeated across six more definitions, so it is approved once, here, rather than six times.
Do not start Task 2 until the author says continue.

---

### Task 2 — Convert `coder` and `reviewer`

**Files:**
- Modify `plugins/claudestacks/agents/coder.md`
- Modify `plugins/claudestacks/agents/reviewer.md`

**Steps:**

1. Replace `coder.md` lines `94-105` with the identical stub from Task 1 step 2 — the same eight
   lines, byte for byte, including the same pointer.

2. Replace `reviewer.md` lines `106-117` with the same eight lines.

3. Confirm all three `claudestacks` agents now carry identical stub bodies. Extract the body and
   hash it — the same extraction Task 7 step 1 uses, because it is the one that emits anything:

   ```
   $ for f in coder explorer reviewer; do
       sed -n '/^When your brief gives you a handoff write-path/,/Full protocol:/p' plugins/claudestacks/agents/$f.md | sed '$d' | md5
     done
   ```

   All three hashes must be equal, over a non-empty extraction — confirm the byte count first:

   ```
   $ sed -n '/^When your brief gives you a handoff write-path/,/Full protocol:/p' plugins/claudestacks/agents/explorer.md | sed '$d' | wc -c
        377
   ```

   Do **not** use `sed -n '/^## Context handoff$/,/^$/!d;/^## Context handoff$/d'` for this. Under
   `-n` that script issues no `p`, so it emits zero bytes for every file and the three "equal"
   hashes are all `md5("")`. It reports success whatever the files contain.

   They were byte-identical before this plan and must stay so — what changed is that the shared
   text no longer contains a rule belonging to one of them.

4. The coder's source-writing latitude lived **only** inside the block just deleted
   (`coder.md:101`), so after step 1 it is gone from this file. It is an implementation duty, not a
   handoff rule, so it does not return to the shared stub. Plan `01` Task 3 states it in
   `protocol.md`; state it here too, in the coder's own scope terms, because a coder must not have
   to open the protocol to learn what it may write.

   Add it to `## Boundaries` (`:68-75`), as a new final bullet with these two sentences as the
   bullet's text. That is the section which already bounds what the agent may touch. The section
   sitting immediately before `## Context handoff` is `## Security` (`:90-92`), which is not a
   scope section and is not where this goes:

   ```markdown
   Your handoff report is one file and is not a channel for editing anything else. Source files
   within your task's scope are a separate licence, and this one: you write them because
   implementing the task requires it.
   ```

5. Confirm the rule is present exactly once, and that neither sibling picked it up:

   ```
   $ grep -c "Source files" plugins/claudestacks/agents/coder.md
   1
   $ grep -c "Source files" plugins/claudestacks/agents/explorer.md plugins/claudestacks/agents/reviewer.md
   plugins/claudestacks/agents/explorer.md:0
   plugins/claudestacks/agents/reviewer.md:0
   ```

6. Commit `refactor(repo): cut coder and reviewer handoff sections to the stub`.

---

### Task 3 — Convert `task-briefer`

**Files:**
- Modify `plugins/claudestacks-sdlc/agents/task-briefer.md`

**Steps:**

1. Confirm the extent of the section. Its heading is `## Report schema` at `:97`, not at `:99` —
   the range must include the heading or it survives with an empty body:

   ```
   $ grep -n "^## Report schema$" plugins/claudestacks-sdlc/agents/task-briefer.md
   97:## Report schema
   $ sed -n '97,120p' plugins/claudestacks-sdlc/agents/task-briefer.md
   ```

2. Replace lines `97-120` — heading included — with the stub, using the cross-plugin pointer.
   `task-briefer` is in
   `claudestacks-sdlc`, so `${CLAUDE_PLUGIN_ROOT}` there resolves to the sdlc plugin, not to the
   one that owns the protocol:

   ```markdown
   ## Context handoff

   When your brief gives you a handoff write-path, write ONE file there: `<summary>…</summary>`
   wrapping what the orchestrator routes on, `<detail>…</detail>` wrapping the heavy material,
   omitted when there is none. Return ONLY the `<summary>` plus that path, never the `<detail>`.
   Write no file but that one through this channel. If no path is given, or the write fails (say
   so), return your full receipt inline. Full protocol: the `handoff-protocol:` path in your
   brief. If the brief carries none, follow this section and note that you had no protocol path.
   ```

3. Add `handoff-protocol` to the brief table beside the existing `handoff` row at `:30`:

   ```markdown
   | `handoff-protocol` | absolute path to the handoff protocol — read it for any rule this definition does not state |
   ```

4. Confirm the agent no longer spells out the schema itself. Before this task the file inlines the
   frontmatter block at `:104-105`, so this check genuinely moves from non-zero to zero:

   ```
   $ grep -c "^agent:\|^session:\|^seq:" plugins/claudestacks-sdlc/agents/task-briefer.md
   0
   ```

   Run the same command before the edit to see it return non-zero; a check that reads zero both
   before and after proves nothing.

5. Commit `refactor(repo): cut task-briefer's handoff section to the stub`.

---

### Task 4 — Convert `journal-curator`

**Files:**
- Modify `plugins/claudestacks-journal/agents/journal-curator.md`

**Steps:**

1. Confirm the inlined schema being replaced — note the range runs to `:87`, where the
   error-handling sentence ends:

   ```
   $ sed -n '76,87p' plugins/claudestacks-journal/agents/journal-curator.md
   ```

2. Replace lines `76-87` with the same cross-plugin stub from Task 3 step 2, then re-add the two
   curator-specific lines that are about *what it reports*, not about the file's shape:

   ```markdown
   Your `<summary>` is a tight tally of what changed. Your `<detail>` is the full per-file change
   log plus the deferred link suggestions you chose not to apply.
   ```

3. Add the `handoff-protocol` input beside the existing `handoff` input at `:29`:

   ```markdown
   - `handoff-protocol` — absolute path to the handoff protocol. Read it for any rule this
     definition does not state. You do NOT compute it.
   ```

4. Confirm the shape rules are gone but the content rules survived. This file never inlined a
   frontmatter block — it described its report in prose bullets — so a `^agent:` grep reads zero
   before and after and would prove nothing. Check the prose that actually goes away instead:

   ```
   $ grep -c "tight tally" plugins/claudestacks-journal/agents/journal-curator.md
   1
   $ grep -c "Context Handoff schema, no session" plugins/claudestacks-journal/agents/journal-curator.md
   0
   ```

   The second string is the old section's heading text (`:76`), which returns `1` before the edit
   and `0` after.

5. Commit `refactor(repo): cut journal-curator's handoff section to the stub`.

---

### Task 5 — Give `chain-reader` one `## Report` section

**Files:**
- Modify `plugins/claudestacks-sdlc/agents/chain-reader.md`

**Steps:**

1. Confirm both sections that describe this agent's file today:

   ```
   $ sed -n '41,58p' plugins/claudestacks-sdlc/agents/chain-reader.md   # ## Output
   $ sed -n '66,74p' plugins/claudestacks-sdlc/agents/chain-reader.md   # ## Context handoff
   ```

2. Delete both sections and write one `## Report` **at `:41`, where `## Output` was** — before
   `## Boundaries`, not after it. Note the exact heading text being removed is
   `## Output (compact, no preamble, no prose)`, so a check anchored as `^## Output$` would never
   match it. It opens with the stub verbatim, so the
   contract survives an unread pointer, then pins the two shapes. The `<detail>` template
   reproduces extracted text byte for byte — no indent, because the two-space indent the old
   `## Output` used silently drops the blank line between a heading and its first body line, which
   is a layout rule editing content.

   Three things in the old `## Output` are behaviour, not layout, and the block below carries each
   one. The two zero-case rules sit immediately after the `<summary>` template, unchanged in
   wording, which is the destination `2026-08-26-agent-report-shape/spec.md:105-110` names. `in
   glob order` stays in the `<detail>` prose — output ordering is the whole product of an agent
   whose job is an ordered extraction, and the `<summary>` counts give a consumer no way to detect
   a reordering. The `<summary>` keeps the glob echo the carried-over template at that source's
   `:82` states, because the counts mean nothing without the pattern that produced them. Dropping
   any of the three breaches spec §5.3's carried-forward guarantee that no rule in either file is
   lost:

   ````markdown
   ## Report

   When your brief gives you a handoff write-path, write ONE file there: `<summary>…</summary>`
   wrapping what the orchestrator routes on, `<detail>…</detail>` wrapping the heavy material,
   omitted when there is none. Return ONLY the `<summary>` plus that path, never the `<detail>`.
   Write no file but that one through this channel. If no path is given, or the write fails (say
   so), return your full receipt inline. Full protocol: the `handoff-protocol:` path in your
   brief. If the brief carries none, follow this section and note that you had no protocol path.

   This section is the only place your file's shape is described. Frontmatter keys, which tag
   holds what, and error handling come from the protocol; do not restate them here or anywhere
   else in this definition.

   Your `<summary>` is the index and nothing else — the glob, how many files it matched, and how
   many carried the heading:

   ```
   Glob <glob> matched <N> files; <M> carried <heading>.
   ```

   If the glob matches files but none carries the heading, say so in one line and list
   nothing. If the glob matches no files at all, say that instead — those are different
   answers and the caller acts on them differently.

   Your `<detail>` is the extraction itself. One `### <path>` heading per file, in glob order, then
   that file's section reproduced byte for byte — every interior blank line, every indent, exactly
   as it appears in the source. No separator, no commentary, no summary line:

   ```
   ### .claudestacks/sdlc/2026-08-24-webhook-reliability/plans/01-retry-core.md

   <the extracted section, verbatim>

   ### .claudestacks/sdlc/2026-08-24-webhook-reliability/plans/02-dlq.md

   <the extracted section, verbatim>
   ```
   ````

3. Confirm exactly one section now describes the file:

   ```
   $ grep -c "^## Output\|^## Context handoff$" plugins/claudestacks-sdlc/agents/chain-reader.md
   0
   $ grep -c "^## Report$" plugins/claudestacks-sdlc/agents/chain-reader.md
   1
   ```

   The `^## Output` alternative is deliberately unanchored at its end: the heading carries a
   parenthetical, so `^## Output$` would return `0` before the edit as well and prove nothing.

4. Confirm the refusal rules that were never about layout are untouched:

   ```
   $ grep -c "Out of scope — I extract, I don't interpret" plugins/claudestacks-sdlc/agents/chain-reader.md
   1
   ```

5. Commit `refactor(repo): give chain-reader one Report section`.

---

### Task 6 — Give `artifact-reviewer` one `## Report` section

**Files:**
- Modify `plugins/claudestacks-sdlc/agents/artifact-reviewer.md`

**Steps:**

1. Confirm the full extent of `## Output` — it runs to `:75`, not `:69`; `## Boundaries` starts at
   `:77`:

   ```
   $ sed -n '51,76p' plugins/claudestacks-sdlc/agents/artifact-reviewer.md
   $ grep -n "^## Boundaries$" plugins/claudestacks-sdlc/agents/artifact-reviewer.md
   77:## Boundaries
   ```

2. Note which of those lines are layout and which are behaviour. `:53-65` is layout and becomes
   the templates. `:67-75` is behaviour and does not belong in a template — it is routed, not
   deleted:

   | Rule at | Goes to |
   |---|---|
   | `:67-69` the verdict line states the blocking set exactly, its count or `none` | `## Report`, as a sentence governing the `<summary>` template |
   | `:69-71` 🟡 and 🔵 under `none` blocking is a normal, passing review | a new `## Reporting discipline` section after `## Report` |
   | `:73-75` clean draft → one line; never invent findings; never inflate a nit | the same new section |

3. Add the protocol field to this agent's brief table, beside the `handoff` row Task 2 of plan
   `03` renamed at `:32`. `task-briefer` and `journal-curator` get the equivalent in Tasks 3 and 4;
   `chain-reader` needs none, because its brief is prose (`:17-18`) rather than a table:

   ```markdown
   | `handoff-protocol` | absolute path to the handoff protocol — read it for any rule this definition does not state |
   ```

4. Delete `## Output` (`:51-75`) and `## Context handoff` (`:83-91`), and write `## Report` at
   `:51`, where `## Output` was — before `## Boundaries` at `:77`:

   ````markdown
   ## Report

   When your brief gives you a handoff write-path, write ONE file there: `<summary>…</summary>`
   wrapping what the orchestrator routes on, `<detail>…</detail>` wrapping the heavy material,
   omitted when there is none. Return ONLY the `<summary>` plus that path, never the `<detail>`.
   Write no file but that one through this channel. If no path is given, or the write fails (say
   so), return your full receipt inline. Full protocol: the `handoff-protocol:` path in your
   brief. If the brief carries none, follow this section and note that you had no protocol path.

   This section is the only place your file's shape is described. Frontmatter keys, which tag
   holds what, and error handling come from the protocol; do not restate them here or anywhere
   else in this definition.

   Your `<summary>` is the verdict line plus every blocking finding, and nothing else. The verdict
   line states the blocking set exactly — its count, or `none` when there is no 🔴. That set is
   the stopping condition the calling skill closes the round on, so getting it right matters more
   than any single finding below it:

   ```
   SPEC: 2 blocking, 1 risk, 1 nit

   spec.md §4: 🔴 blocking: "error handling TBD" is a placeholder; the intent names three failure modes this section has to decide.
   spec.md §6: 🔴 blocking: the intent's constraint on cross-plugin degradation has no section.
   ```

   Your `<detail>` is every finding, severity-ordered, with its rationale. Cite each by artifact
   section — `spec.md §4`, `plans/02-foo.md Task 3`; a finding with no location is not actionable.
   Report every tier, nits included: completeness is your job, triage belongs to the skill and the
   user:

   ```
   ## 🔴 Blocking

   **1. <one-line claim.>**
   <rationale, with the citation that settles it>

   ## 🟡 Risk

   ## 🔵 Nit
   ```

   ## Reporting discipline

   Coming back with 🟡 and 🔵 under `none` blocking is a normal, passing review; say nothing that
   reads as "another round would help".

   If the draft is clean, say so in one line and report nothing further. Never invent findings to
   justify the spawn, and never inflate a nit to 🔴 to look thorough — a padded blocking set holds
   the artifact for nothing.
   ````

5. Confirm every behavioural rule survived the replacement. Each of these was in `## Output`
   before this task and must still be somewhere in the file:

   ```
   $ grep -c "states the blocking set exactly" plugins/claudestacks-sdlc/agents/artifact-reviewer.md
   1
   $ grep -c "normal, passing review" plugins/claudestacks-sdlc/agents/artifact-reviewer.md
   1
   $ grep -c "never inflate a nit" plugins/claudestacks-sdlc/agents/artifact-reviewer.md
   1
   $ grep -c "a finding with no location is not actionable\|with no location is not actionable" plugins/claudestacks-sdlc/agents/artifact-reviewer.md
   1
   ```

   Any `0` means a rule was dropped, which the chain's intent forbids.

6. Confirm one section owns the shape, and that the brief row landed:

   ```
   $ grep -c "^## Output\|^## Context handoff$" plugins/claudestacks-sdlc/agents/artifact-reviewer.md
   0
   $ grep -c '^| `handoff-protocol`' plugins/claudestacks-sdlc/agents/artifact-reviewer.md
   1
   ```

7. Commit `refactor(repo): give artifact-reviewer one Report section`.

---

### Task 7 — Assert the stub is identical across all seven

**Files:**
- None — verification only.

**Steps:**

1. Spec §11.3 asks for more than a phrase count: the stub's body, with the pointer line stripped,
   must be byte-identical across all seven. Extract it from each definition — the body runs from
   the first sentence to the line carrying `Full protocol:`, which is the only part that
   legitimately differs — and hash what remains:

   ```
   $ for f in plugins/claudestacks/agents/coder.md \
              plugins/claudestacks/agents/explorer.md \
              plugins/claudestacks/agents/reviewer.md \
              plugins/claudestacks-sdlc/agents/task-briefer.md \
              plugins/claudestacks-sdlc/agents/chain-reader.md \
              plugins/claudestacks-sdlc/agents/artifact-reviewer.md \
              plugins/claudestacks-journal/agents/journal-curator.md; do
       sed -n '/^When your brief gives you a handoff write-path/,/Full protocol:/p' "$f" | sed '$d' | md5
     done | sort -u | wc -l
        1
   ```

   Exactly one distinct hash means all seven carry the same stub. Any other number names how many
   variants exist, and the loop run without `sort -u | wc -l` shows which file differs.

2. Confirm all seven were actually found — an empty extraction also hashes identically, so the
   check above passes vacuously if the `sed` matches nothing:

   ```
   $ grep -rlc "write ONE file there" plugins/*/agents/ | wc -l
          7
   ```

3. Confirm the two pointer forms are used exactly where they belong — three in-plugin, four by
   brief field. The second pattern stops at `path in your`: the stub wraps after that word, so
   `path in your brief` spans a line break and `grep` would return nothing for all four files:

   ```
   $ grep -rl "CLAUDE_PLUGIN_ROOT}/skills/context-handoff/references/protocol.md" plugins/*/agents/ | sort
   plugins/claudestacks/agents/coder.md
   plugins/claudestacks/agents/explorer.md
   plugins/claudestacks/agents/reviewer.md
   $ grep -rl "the \`handoff-protocol:\` path in your" plugins/*/agents/ | sort
   plugins/claudestacks-journal/agents/journal-curator.md
   plugins/claudestacks-sdlc/agents/artifact-reviewer.md
   plugins/claudestacks-sdlc/agents/chain-reader.md
   plugins/claudestacks-sdlc/agents/task-briefer.md
   ```

4. Confirm no agent restates the protocol any more. None may carry the frontmatter key list:

   ```
   $ grep -rn "^seq: \|^session: " plugins/*/agents/
   $ echo "exit=$?"
   exit=1
   ```

5. Prove that search would have found something — the same pattern against the file that
   legitimately carries the schema. Without this control, step 4's empty result is equally
   consistent with a pattern that matches nothing anywhere:

   ```
   $ grep -c "^seq: \|^session: " plugins/claudestacks/skills/context-handoff/references/protocol.md
   2
   ```

6. Commit nothing.
