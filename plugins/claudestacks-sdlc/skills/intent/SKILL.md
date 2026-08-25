---
name: intent
description: Use before designing or building anything new — captures a problem, converts an existing PRD or RFC, or revisits a parked intent to approve, amend, drop, or un-drop it. Also for parking an idea without committing to build it yet.
---

# Intent

Turn a problem into a chain. `intent` is the entry point of the `claudestacks-sdlc` pipeline: every
chain under `.claudestacks/sdlc/` starts as one `intent.md`, and everything downstream — spec, plans,
execution — hangs off it. Writing an intent is not a commitment. It parks an idea; nothing pushes it
toward design or execution until the user approves it, and an approved intent can sit for months before
anyone runs `design` against it.

## Shared contract

Resolve every path, frontmatter key, and state transition from
`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md` — do not re-derive naming or the state model from
memory. Write the file itself in the body shape `${CLAUDE_PLUGIN_ROOT}/references/templates.md` defines
for `intent.md`. Lazy-create `.claudestacks/sdlc/` and the new chain directory before the first write;
never assume `/claudestacks-sdlc:setup` ran — an absent tree is not an error, it is the common case on a
fresh repo. Never commit the file; that stays the user's separate act. Flip `status` in frontmatter only
per the transitions table in `artifact-chain.md` §7.2, only as the last step of the interaction that
earns it, only after the user gives explicit in-dialogue approval — never flip on inference, and never
flip mid-dialogue before the question that earns it has actually been asked.

## Input modes

Three ways into this skill:

- **A rough idea in the user's words.** The common path — go straight to the dialogue below.
- **Conversion of an existing file.** "Turn this RFC into an intent," or a PRD the user names directly.
  Load it as primary input and treat its content as the seed for the same dialogue, not a shortcut past
  it — a converted file still needs the problem/outcome/constraints pass, because a PRD or RFC is
  written for a different audience and rarely maps cleanly onto intent's sections.
- **Re-invocation on an existing intent.** The user wants to approve, amend, drop, or un-drop a chain
  that already exists. Locate the chain, read its current `status`, and act on it directly: approve
  flips `draft → approved`; drop flips any state to `dropped`; un-drop reverses a prior drop back to
  whatever state preceded it (usually `draft`); amend rewrites body sections in place and only touches
  `status` if the amendment itself earns a fresh approval. A request this skill cannot satisfy from the
  current state — approving a `dropped` intent without first un-dropping it, for instance — is refused by
  name: the file, its current state, and that un-dropping is the command that advances it.

## Input-doc scan

Before the dialogue, list `prds/` and `rfcs/` under `.claudestacks/sdlc/`. Both are optional and often
empty — an absent or empty directory prompts nothing. When either holds files, surface the ones that look
relevant to what the user described and ask, as a question, whether any should seed this intent; do not
silently fold one in. If the user names a specific file and it does not exist at that path, report the
path you looked for and ask for a correction — never guess a nearby file instead. Every doc actually used
is recorded in the list-valued `derived-from-prd:` / `derived-from-rfc:` frontmatter keys; a doc merely
skimmed and rejected is not recorded.

## Dialogue

Ask 3–5 questions, one at a time, never a battery: problem, affected systems, desired outcome,
constraints, why-now. Prefer multiple-choice phrasing where a question has a natural small set of
answers. Ask only when the answer changes what gets written — anything derivable from the repo, an input
doc already loaded, or the shape of the conversation so far is derived instead and stated as an
overridable assumption ("I'm assuming this affects only `clauders::transport` — correct?").

## Hard gate — no solution content

If the dialogue drifts into "how" — architecture, tech choices, file layouts, which crate owns what —
that is design work, and design work belongs to the `design` skill, once this intent and its spec exist.
Cut the drift to at most a one-line "candidate direction" note in the body and steer the conversation back
to the problem: what is broken or missing, not what would fix it. An intent full of solution detail is
scope creep on its own future spec — it locks in an approach before the problem is even agreed on.

## Multi-scope check

If the problem as described spans independent subsystems — two crates with no shared dependency, or two
concerns that could ship on entirely separate timelines — propose splitting it into sibling chains before
anything is written. Each sibling gets its own `intent.md`, its own topic, its own pace through the
pipeline. Do not write one intent that quietly covers two problems.

## Spec-skip

When the chain is small and mechanical enough that a full design pass would be ceremony, offer the
spec-skip path: set `spec: skipped` in frontmatter plus a one-line reason recorded next to it in the body
("skip: single-file config change, no design ambiguity"). This is always the user's choice to take, never
this skill's to propose for a problem that plainly needs design — a multi-system change, an ambiguous
approach, or anything the multi-scope check flagged is not offered the skip.

## Output

Write `<date>-<topic>/intent.md` (chain directory named `YYYY-MM-DD-<kebab-topic>`, the date the intent
is created) in the frontmatter and body shape from `templates.md`: `status`, `created`, the optional
provenance lists, optional `source`, optional `spec: skipped`, and body sections Problem, Affected
systems, Desired outcome, Constraints, Non-goals, in that order. A triage-sourced intent (`source:
triage`) additionally carries an Evidence section — that shape is `triage`'s to write, not this skill's,
but this skill reads and amends such an intent the same as any other on re-invocation.

## Approval gate

Once the body is written, ask the user directly whether to approve it now or leave it `draft`. `draft →
approved` happens only on an explicit yes — never on silence, never on "looks good" read as consent to
more than it said. Committing the file to git is the user's separate call; this skill never runs `git
add` or `git commit`.
