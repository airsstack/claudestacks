---
status: done
created: 2026-08-26
depends-on: [01]
---

# Distill Corpus-Scan Wiring Implementation Plan

**Goal:** Wire the `distill` skill's cross-chain findings scan to the `chain-reader` agent.

**Architecture:** One skill file, one section rewritten, no new files. `distill`'s `## Input` section currently instructs the main thread to read every plan file in the chain root looking for one heading; it is replaced by a spawn of `claudestacks-sdlc:chain-reader`, which returns that heading's content verbatim and nothing else. Everything downstream of the scan — the two-chain recurrence rule, the per-proposal dialogue, the accept/edit/skip gate — is untouched and stays on the main thread, because it is judgment feeding a conversation with the user and a subagent never gets a user turn.

**Tech Stack:** Markdown skill file with YAML frontmatter. No code, no Lua, no Cargo changes.

**Content authority:** `.claudestacks/sdlc/2026-08-25-sdlc-agent-tier/spec.md` §3, §6.1, §6.2, §7, §8, §9. Each task below is a binding contract: the named elements MUST appear in the file, and the spec section named is the authority on their exact semantics.

**Depends on plan `01`** for `plugins/claudestacks-sdlc/agents/chain-reader.md`. Running this before `01` lands leaves `distill` instructed to spawn an agent that does not exist.

**Independent of plan `02`.** That plan touches `skills/design/SKILL.md` and `skills/plan/SKILL.md`; this one touches `skills/distill/SKILL.md` only. No file is shared, so the two can run in parallel worktrees once `01` is done.

**Verification convention, repeated at every task:** after the file change, run

```
$ cargo run -q -p claudevs-cli -- check plugins/claudestacks-sdlc
```

and confirm exit 0 with no `  FAIL  ` stage line. Spec §9 check 1.

---

## File structure

```
plugins/claudestacks-sdlc/skills/distill/SKILL.md
    — [modify] the ## Input section becomes a chain-reader spawn (Task 1)
```

One file, one section. Task 2 changes no file.

---

### Task 1 — Route `distill`'s corpus scan through `chain-reader`

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/distill/SKILL.md`

**Steps:**

1. Assert the delegation is absent — failing-first:

   ```
   $ grep -c "chain-reader" plugins/claudestacks-sdlc/skills/distill/SKILL.md
   0
   ```

   Exit status 1, count `0`.

2. The `## Input` section currently occupies lines 34–40:

   ```
   ## Input

   Scan every plan file under `.claudestacks/sdlc/*/plans/*.md` for its `## Review findings` section. This
   data is durable by construction — each finding was written to disk by `execute` before the plan flipped
   `done`, so no session memory or prior conversation is needed to reconstruct it. Read the whole corpus
   across every chain, not just the most recent one; a category that recurred six months ago and again last
   week is still a recurrence.
   ```

   Replace those seven lines with:

   ````markdown
   ## Input

   Every plan file under `.claudestacks/sdlc/*/plans/*.md` may carry a `## Review findings`
   section. That data is durable by construction — each finding was written to disk by
   `execute` before the plan flipped `done` — so no session memory or prior conversation is
   needed to reconstruct it. The whole corpus is in scope, across every chain, not just the
   most recent one; a category that recurred six months ago and again last week is still a
   recurrence.

   Do not read those plan files yourself. A plan is a full construction manual and its
   findings section is a few lines, so scanning the corpus inline pulls an enormous amount
   of text in to extract very little — and that cost grows with every chain the repository
   accumulates, while the answer stays a short table. Spawn
   `claudestacks-sdlc:chain-reader` instead:

   ```
   glob: .claudestacks/sdlc/*/plans/*.md
   heading: ## Review findings
   report: <TMPDIR>/claudestacks-sdlc-corpus-findings-<NN>.md
   ```

   Expand `${TMPDIR:-/tmp}` yourself before the path enters the brief — an agent receives
   its brief as literal text and runs no shell over it, so an unexpanded variable would
   reach it as a filename. The `corpus` segment stands where a chain name goes in the
   report-path shape, because this scan spans every chain rather than one. `<NN>` starts at
   `01` and increments on each re-scan.

   The agent returns a summary — how many files the glob matched, how many carried the
   heading — plus that path. Read the `<detail>` yourself: the extraction is exactly what
   you apply the recurrence rule to, so this is the case where the main thread does need
   the detail rather than routing off the summary alone.

   What comes back is verbatim, tagged by source file, and nothing else. The agent does not
   group, count, categorize, or rank, and refuses if asked. That work is yours, below —
   it is judgment, and it feeds a dialogue with the user that a subagent can never hold.

   If the glob matches plan files but none carries a `## Review findings` heading, there is
   no findings corpus yet: say so and stop, rather than proposing anything.
   ````

3. Confirm green:

   ```
   $ grep -c "claudestacks-sdlc:chain-reader" plugins/claudestacks-sdlc/skills/distill/SKILL.md
   1
   $ grep -c "corpus-findings" plugins/claudestacks-sdlc/skills/distill/SKILL.md
   1
   ```

4. Confirm the section boundaries held and everything downstream survived untouched:

   ```
   $ grep -c "^## Input$" plugins/claudestacks-sdlc/skills/distill/SKILL.md
   1
   $ grep -c "^## Recurrence rule$" plugins/claudestacks-sdlc/skills/distill/SKILL.md
   1
   $ grep -c "two or more different chains" plugins/claudestacks-sdlc/skills/distill/SKILL.md
   1
   $ grep -c "^## Per-proposal dialogue$" plugins/claudestacks-sdlc/skills/distill/SKILL.md
   1
   ```

   All `1`. The recurrence rule and the per-proposal dialogue are the two things this task
   must not disturb: they are the judgment half of the skill and they stay on the main
   thread. If any of these returns `0`, the replacement ate past line 40 — revert and redo
   against the exact seven lines above.

5. Confirm the section order is unchanged:

   ```
   $ grep -n "^## " plugins/claudestacks-sdlc/skills/distill/SKILL.md
   ```

   The headings must appear in this order, with only their line numbers shifted:
   `## Shared contract, tuned to a read-mostly skill`, `## Input`, `## Recurrence rule`,
   `## Per-proposal dialogue`, `## On accept`, `## Hard rules`.

6. Run the verification convention:

   ```
   $ cargo run -q -p claudevs-cli -- check plugins/claudestacks-sdlc
   ```

   Exit 0, no `  FAIL  ` line.

7. Commit `feat(repo): route distill's corpus scan through the chain-reader agent`.

---

### Task 2 — Dogfood the wired skill against the real corpus

**Files:** none — this task changes no file and produces no commit.

**This task runs on the main thread, not inside a coder agent.** Plugin agents are leaves
with no `Agent` tool, so a delegated implementer physically cannot perform the spawn that
is under test here. Whoever is driving the plan runs this directly.

This is spec §9 check 3 for the `distill` half — a manual check, recorded as manual. It is
not automated by this plan and nothing here claims it is.

**Steps:**

1. Establish what the corpus actually holds, so you can tell a correct result from a wrong
   one:

   ```
   $ grep -rln "^## Review findings" .claudestacks/sdlc/
   .claudestacks/sdlc/2026-08-24-sdlc-plugin/plans/01-scaffold.md
   .claudestacks/sdlc/2026-08-24-sdlc-plugin/plans/02-status-board.md
   .claudestacks/sdlc/2026-08-24-sdlc-plugin/plans/03-workflow-skills.md
   .claudestacks/sdlc/2026-08-24-sdlc-plugin/plans/04-rollout.md
   ```

   Four files, all in one chain. If the listing differs, use what it actually prints as
   the expectation below — chains accumulate, and this plan may run long after it was
   written.

2. Invoke `/claudestacks-sdlc:distill` and watch for the spawn. Three things must hold:
   - a `claudestacks-sdlc:chain-reader` spawn happens, with the glob and heading from
     Task 1's brief;
   - it returns a summary plus a report path, and the report file exists at that path
     carrying both a `<summary>` and a `<detail>` tag;
   - the plan bodies do **not** appear in the main thread. Only the extracted findings do.
     If whole plan files show up, the skill read them itself and the wiring did not take.

3. Confirm the extraction is verbatim rather than summarized. Compare one file by hand:

   ```
   $ sed -n '/^## Review findings/,/^## /p' .claudestacks/sdlc/2026-08-24-sdlc-plugin/plans/03-workflow-skills.md
   ```

   The corresponding block in the agent's `<detail>` must match this output. If the agent
   grouped, re-worded, or condensed anything, its HARD-REFUSE section is not binding hard
   enough — fix `agents/chain-reader.md` and re-run.

4. Confirm the judgment half still runs on the main thread and the recurrence rule holds.
   All four files carrying findings are in a **single** chain, and the rule requires a
   category to appear in **two or more different chains**. So the correct outcome is that
   `distill` proposes nothing, and instead names each single-occurrence category with the
   one `chain/plan` it appeared in and states that a second chain is needed before it
   becomes a proposal.

   A proposal appearing here is a defect, not a success: it means the two-chain threshold
   was applied to plans rather than to chains.

5. Confirm the user gate is intact: `distill` must present anything it does have one item
   at a time and wait for accept / edit / skip. It must not apply an edit on its own, and
   it must not run `git add` or `git commit`.

6. No commit — this task verifies, it does not change the tree.

---

## Verification summary (plan-level)

| Check | Command | Expected |
|---|---|---|
| Plugin validity | `cargo run -q -p claudevs-cli -- check plugins/claudestacks-sdlc` | exit 0, no `  FAIL  ` line |
| Agent wired | `grep -c "claudestacks-sdlc:chain-reader" plugins/claudestacks-sdlc/skills/distill/SKILL.md` | `1` |
| Report path named | `grep -c "corpus-findings" plugins/claudestacks-sdlc/skills/distill/SKILL.md` | `1` |
| Recurrence rule intact | `grep -c "two or more different chains" plugins/claudestacks-sdlc/skills/distill/SKILL.md` | `1` |
| Dialogue intact | `grep -c "^## Per-proposal dialogue$" plugins/claudestacks-sdlc/skills/distill/SKILL.md` | `1` |
| End-to-end | Task 2 | spawn occurs, extraction verbatim, no proposal from a single chain |

Rows 4 and 5 are the invariant this chain rests on: the scan moved to an agent, the
judgment and the user gate did not.

No Lua is added, so `cargo make plugins` is unaffected. The Rust Definition of Done does
not apply — this plan touches no Rust.

**Nothing is deferred from this plan.** With `01`, `02`, and this plan done, every
requirement in spec §1–§9 has an implementing task, and the chain's only remaining
manual item is the `design` dogfood named in plan `02`.
