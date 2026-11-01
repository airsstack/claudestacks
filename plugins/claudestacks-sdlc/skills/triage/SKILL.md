---
name: triage
description: Use by hand right after a failure surfaces (CI log, advisory, backtrace) to turn the evidence into a draft intent that enters the normal pipeline.
---

# Triage

## The rule

Turn failure evidence into a new chain with a `draft` `intent.md`. Manual only; never wired to CI.
It always starts a fresh chain and never touches an existing one, so it has no state-gate refusal.
Never commit.

Naming and shape: `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md` and
`${CLAUDE_PLUGIN_ROOT}/references/templates.md`. Lazy-create `YYYY-MM-DD-<kebab-topic>/`; never
assume `setup` ran.

## Steps

1. **Input.** A pasted log, a path to a log or advisory, or a plain description; take any form.
2. **Correlate first.** Before asking, look at any file, command or path the evidence names, and run
   `git log` scoped to the implicated paths. State each conclusion as an overridable assumption.
3. **Cite outside-system claims or drop them.** Any claim about an external system carries
   `<local file>:<line>` or a version and byte offset from an artifact you fetched. Fetch docs as raw
   source and grep: `curl -sS -L '<doc-url>.md' -o "${TMPDIR:-/tmp}/<name>.md"`; never a summarizing
   fetch tool. Check counts, exhaustive lists and negative existence claims individually. An
   uncitable claim is written "not verified" or left out.
4. **Short dialogue.** One question at a time, recommendation first, only where the answer changes
   what is written; usually just the desired outcome and any constraint on how.
5. **Write** `<date>-<topic>/intent.md` in `intent`'s shape plus `source: triage` in frontmatter and
   an `## Evidence` section after Non-goals: exact error text and the exact command, quoted
   verbatim. `status: draft`; no approval gate here.

The `intent` skill handles later approval, amendment or drop.
