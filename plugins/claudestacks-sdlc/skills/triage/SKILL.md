---
name: triage
description: Use when something broke and there is evidence — a CI log, an advisory, a backtrace — to convert into a triaged intent entering the normal pipeline. Invoke by hand right after a failure surfaces, while the log or error is still in front of you.
---

# Triage

Turn failure evidence into a chain. A CI job went red, a dependency advisory landed, a backtrace showed
up in a bug report — `triage` is the entry point that takes that evidence and produces the same thing
`intent` produces: a chain with a `draft` `intent.md`, ready to enter the normal pipeline. It exists so
failures do not get fixed once, ad hoc, and forgotten; they get a chain, like everything else, and the
distill loop can later notice if the same category of failure keeps recurring.

Manual invocation only. This skill is not wired to CI, and headless triage from a CI cron job or `claude
-p` is explicitly out of scope for this version — someone runs it by hand, with the evidence pasted or
named, right after the failure surfaces.

## Shared contract

Resolve chain naming and the `intent.md` frontmatter/body shape from
`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md` and `${CLAUDE_PLUGIN_ROOT}/references/templates.md`
— the same authorities `intent` uses, since the file this skill produces is a normal `intent.md` with one
extra section. Lazy-create the new `YYYY-MM-DD-<kebab-topic>/` chain directory before the first write;
never assume `/claudestacks-sdlc:setup` provisioned `.claudestacks/sdlc/` already. Never commit the file —
that is the user's separate act, same as every other skill here. This skill only ever writes the initial
`— → draft` state on a brand-new chain; it never touches an existing chain's state, so it carries no
state-gate refusal of its own the way `design` or `execute` do against a wrong input state — there is
nothing to refuse, because triage always starts a fresh chain rather than acting on one that already
exists. Dialogue is guided the same as elsewhere in this plugin: one question at a time, lead with a
recommendation where the evidence suggests one, and every question asked only because the answer changes
what gets written.

## Input

A pasted log, a path to a log or advisory file, or a plain description of what broke. Take whichever form
the user hands over; do not insist on a specific shape.

## Deterministic correlation first

Before asking anything, check what is actually checkable from the evidence. If the evidence names a file,
command, or path, look at it. Run `git log` (scoped to the paths the evidence implicates, when it names
any) to see whether anything relevant changed recently — a failure that started right after a touching
commit is a different story from one with no correlated change. State every conclusion from this pass as
an overridable assumption in the dialogue ("this looks tied to the `clauders::transport` change in
`ad6c1af` — is that right, or unrelated?") rather than presenting it as settled fact; the user can correct
it in one answer.

## Short evidence-seeded dialogue

Once the deterministic pass is done, ask what is left — usually one or two questions, not the 3–5 `intent`
asks from scratch, because the evidence has already answered problem and affected-systems. The remaining
gap is almost always desired outcome: what "fixed" looks like, and whether there is a constraint on how
(e.g. "no downtime" or "cannot touch the vendored transport").

## Output

Write a normal chain, `<date>-<topic>/intent.md`, using the same frontmatter and body shape `intent`
uses, plus two additions: `source: triage` in frontmatter, and an `## Evidence` section in the body after
Non-goals, holding the evidence at full precision — the exact error text, the exact command that produced
it, quoted verbatim, never paraphrased or summarized down. `status` is `draft`; this skill does not run
the approval gate itself.

## Downstream

None of this skill's own. The intent it wrote enters the same queue as any other — the `intent` skill
handles its approval, amendment, or drop on a later invocation, exactly as it would for a chain that
started from a rough idea instead of a stack trace.
