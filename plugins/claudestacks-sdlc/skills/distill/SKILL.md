---
name: distill
description: Use after chains complete to turn review findings that recur across chains into agent-config edits.
---

# Distill

## The rule

Read `## Review findings` across every chain's plans; when one category appears in two or more
different chains, propose one minimal edit to the project's guidance. Plan paths come from
`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`; the finding line shape
(`category — description — where`) is owned by `execute`. This skill writes no chain artifact,
creates nothing, flips no chain `status`, and never commits. If `.claudestacks/sdlc/` is absent or
no plan has findings, say so and stop.

## Read the corpus

Never read the plans yourself. Invoke `/claudestacks:context-handoff` for the protocol path, then
spawn `claudestacks-sdlc:chain-reader`:

```
glob: .claudestacks/sdlc/*/plans/*.md
heading: ## Review findings
handoff: <TMPDIR>/claudestacks-sdlc-corpus-findings-<NN>.md
handoff-protocol: <the path /claudestacks:context-handoff gave you>
```

One subagent: literal expanded `${TMPDIR:-/tmp}` path, no session. `<NN>` starts `01`, increments
per re-scan. It returns a summary and the path; read the `<detail>` yourself, then group and count
(the agent refuses to). Plans matched but none carrying the heading: no corpus, say so and stop.

## Recurrence

Propose only for a category in two or more different chains; the same chain twice or one occurrence
does not qualify. Name both occurrences by `chain/plan`. A single-occurrence category: name it, its
one `chain/plan`, and that it needs a second chain.

## Proposals

One at a time, never a batch. Each carries the finding, the `chain/plan` citations, and one concrete
edit shown in full: a line for the target repo's `CLAUDE.md`, or a specific change to a skill file.
Ask accept / edit / skip. Edit means the user reshapes it.

On accept, apply it exactly as agreed to the one file named; the user commits. If the file is under
`plugins/`, remind them to run `cargo make claudevs-check` and `cargo make plugins` first.

## Never

- Edit any file without a per-proposal accept.
- Propose from a single occurrence.
- Touch anything else; the footprint is reading findings and writing the one accepted file.
