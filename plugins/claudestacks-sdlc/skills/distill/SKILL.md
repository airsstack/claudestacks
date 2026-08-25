---
name: distill
description: Use after chains complete to turn recurring review findings into agent-config edits — the same-mistake-twice loop. Reach for it when a review keeps flagging the same category of issue across separate chains and it is time to fix the root cause instead of the symptom again.
---

# Distill

Close the loop between review and configuration. Every `execute` run appends a durable `## Review
findings` section to the plan it just finished — `execute`'s own `SKILL.md` owns the exact line
shape (`category — description — where`); `references/templates.md` only names the section, and
`references/artifact-chain.md` does not mention it at all. Left alone, those findings are read
once and forgotten — the same category of mistake gets caught by review again on the next chain,
at the same cost. `distill` reads across every chain's findings, and when one category has bitten
twice, turns it into a concrete, minimal edit to the project's guidance so review stops needing to
catch it a third time.

## Shared contract, tuned to a read-mostly skill

This skill resolves the chain root and plan paths from
`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md` — the same authority every other skill in this
plugin uses, even though `distill` is reading plan files rather than writing new ones. It writes no
chain artifact of its own, so `references/templates.md`'s body shapes never apply to its output; there is
no chain directory to lazy-create, because this skill never creates a chain — if `.claudestacks/sdlc/`
does not exist yet, or holds no plans with findings, say so and stop rather than treating it as an error.
It never auto-commits: the edit it applies to a config file or a skill file is left in the working tree
for the user to review and commit. It never flips a chain-artifact `status` at all — the transitions
table in `artifact-chain.md` §7.2 governs `intent`/`spec`/`plan` state, and `distill` is not one of the
skills named as flipping any of it; every write this skill makes lands outside `.claudestacks/sdlc/`
entirely, in the target repo's `CLAUDE.md` or a skill file. Dialogue is guided the same as every other
skill in this plugin — one proposal at a time, never a batch, and the user's edit-or-skip on a proposal is
exactly the kind of explicit in-dialogue answer the other skills require before flipping a state, applied
here to accepting an edit instead.

## Input

Scan every plan file under `.claudestacks/sdlc/*/plans/*.md` for its `## Review findings` section. This
data is durable by construction — each finding was written to disk by `execute` before the plan flipped
`done`, so no session memory or prior conversation is needed to reconstruct it. Read the whole corpus
across every chain, not just the most recent one; a category that recurred six months ago and again last
week is still a recurrence.

## Recurrence rule

Propose an edit only for a finding category that appears in **two or more different chains**. A category
that shows up twice in the same chain's findings, or only once anywhere, does not qualify — it might be
noise, or specific to that piece of work, and proposing a permanent config change off a single data point
is exactly the failure mode this rule exists to prevent. Every proposal names both occurrences by
`chain/plan` (e.g. `2026-08-24-sdlc-plugin/plans/03-workflow-skills.md` and
`2026-07-10-auth-token/plans/02-refresh.md`), so the user can verify the pattern themselves before
accepting anything.

A category that has exactly one occurrence is not silently dropped from consideration — name it, name the
one chain/plan it appeared in, and state plainly that it needs a second occurrence before it becomes a
proposal. That is this skill's version of a state-gate refusal: it names the finding, its current count,
and the condition (a second chain) that would advance it to a proposal.

## Per-proposal dialogue

Present proposals one at a time, never as a batch. Each proposal carries three things: the finding
itself, where it recurred (the `chain/plan` citations from the rule above), and one concrete, minimal
edit — a single line added to the target repo's `CLAUDE.md`, or a specific change to a skill file, shown
in full, not described. Ask accept / edit / skip for that one proposal before moving to the next. "Edit"
means the user reshapes the wording or target before it is applied, not that this skill guesses a second
version on its own.

## On accept

Apply the edit exactly as agreed, to the file it targets. The user commits it — this skill does not run
`git add` or `git commit` on its own behalf, matching every other skill in this plugin. When the accepted
edit touches a plugin inside this suite (a file under `plugins/`), remind the user to run
`cargo make claudevs-check` and `cargo make plugins` before committing, since those two gates are not part
of the Rust Definition of Done and would otherwise go unrun on a plugin-only change.

## Hard rules

- Never edit a config or skill file without a per-proposal accept — no batch-apply, no "these all look
  reasonable, applying now."
- Never propose an edit from a single occurrence, regardless of how confident the pattern looks.
- Touch nothing else in the repo. This skill's entire footprint is: read findings across
  `.claudestacks/sdlc/`, and — on explicit accept — write to the one file a proposal named.
