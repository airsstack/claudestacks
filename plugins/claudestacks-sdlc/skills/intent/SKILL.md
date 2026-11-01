---
name: intent
description: Use before designing or building anything new — captures a problem, converts a PRD or RFC, or revisits an intent to approve, amend, drop or un-drop it.
---

# Intent

## The rule

An intent parks a problem as `.claudestacks/sdlc/<YYYY-MM-DD>-<kebab-topic>/intent.md`. It is
the first stage with discussion; it states the problem, never the solution. Writing it commits
to nothing.

Paths, keys, states: `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md` (transitions §7.2).
Body shape: `${CLAUDE_PLUGIN_ROOT}/references/templates.md`. Lazy-create the tree and chain
directory; never assume `setup` ran. Never commit. Flip `status` only as the last step of the
interaction, on an explicit yes.

## Modes

- **Rough idea:** go to the dialogue.
- **Existing PRD/RFC:** load it as the seed and still run the dialogue.
- **Existing intent:** approve (`draft → approved`), drop (any state `→ dropped`), un-drop
  (back to the prior state, usually `draft`), amend (rewrite body in place; touch `status` only
  if it earns a fresh approval). A request the current state cannot satisfy is refused, naming
  the file, its state, and the command that advances it.

## Re-invocation: sync check

Before acting, and after every `status` flip, render the board and read the chain's row (no
output means `airsl` is missing: derive it as the `status` skill does); tell the user what it
reads:

    sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"

- **Amending the body marks downstream stale.** Before amending an intent whose chain has an
  `approved` spec (or, with `spec: skipped`, an `approved`/`executing` plan), say the board will
  read `spec stale (intent changed)` (or `plan NN <status>: stale (intent changed)`) and that
  `design` (or `plan`) clears it. Proceed on the user's word. Only body edits count.
- **`intent disproven by plan NN`** is cleared by amending the body to correct the disproven
  claim; the chain's `approved`/`executing` plans then read stale and go to `plan`.
- Re-render after an amend; an `INVALID` result replaces the row.
- Any other condition is not this skill's: say what the row reads and continue.
- With a `milestone` key, read that milestone's row too. `⤷ milestone <roadmap>/<NN> is dropped
  — release this chain`: say so and name `milestone` `release`. `INVALID (intent.md: unknown
  milestone <value>)` or `ambiguous milestone <value>`: name file and value; the user corrects.

## Before the dialogue

List `prds/` and `rfcs/` under `.claudestacks/sdlc/` (absent or empty prompts nothing). If files
look relevant, ask whether any should seed this intent. A user-named file that does not exist:
report the path and ask. Record docs used in list keys `derived-from-prd:` / `derived-from-rfc:`.

## Dialogue

3–5 questions, one at a time: problem, affected systems, desired outcome, constraints, why-now.
Prefer multiple choice. Ask only when the answer changes what is written; state derivable things
as overridable assumptions.

- **No solution content.** Cut "how" drift to a one-line candidate direction; it belongs to
  `design`.
- **Multi-scope.** If the problem spans independent subsystems, propose sibling chains before
  writing.
- **Spec-skip.** For a small mechanical change, offer `spec: skipped` plus a one-line reason in
  the body. Never offer it for a multi-system, ambiguous, or multi-scope problem.

## Milestones

Optional `milestone: <roadmap>/<NN>` in frontmatter.

- Write the key only when the user names a milestone; otherwise write none and ask nothing about
  milestones. Never infer membership.
- Find `.claudestacks/sdlc/roadmaps/<roadmap>/<NN>-<topic>.md`; write the key only if exactly one
  file matches and its status is `draft` or `approved`. Otherwise write no key, report the path,
  status or duplicate files, and ask.
- After dropping an intent with `milestone`, run the roll-up from `artifact-chain.md` for its
  roadmap as the last step.
- Un-dropping a member of a `done` milestone: remove the key in the same edit and say the chain
  is now simple.

Adopt, release and park are the `milestone` skill's.

## Output

`<date>-<topic>/intent.md`: frontmatter `status`, `created`, optional `derived-from-*`, `source`,
`spec: skipped`, `milestone`; body Problem, Affected systems, Desired outcome, Constraints,
Non-goals. A `source: triage` intent also has `## Evidence` (written by `triage`; amended here
like any other).

## Approval

Ask whether to approve now or leave `draft`. `draft → approved` only on an explicit yes. Never
`git add` or commit.
