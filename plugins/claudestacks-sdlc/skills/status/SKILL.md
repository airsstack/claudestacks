---
name: status
description: Render the claudestacks-sdlc chain status board — deterministic via airsl, model fallback otherwise. Use when the user says "/claudestacks-sdlc:status", asks what state the SDLC chains are in, or asks what to work on next.
---

## Board

!`sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"`

## Task

If the board above is non-empty, present it to the user exactly as printed
and stop — the derivation has already happened; run nothing else.

If it is empty, the airsl binary is not installed: derive the same board by
hand, from `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md` and nothing
else. That file owns every rule the script executes: which top-level entries
are not chains, the frontmatter keys, the sync rules, and NEXT derivation —
each row's STATE and NEXT. Scan `.claudestacks/sdlc/` by those rules, skipping
the entries that file names and every non-directory; read each chain's
`intent.md`, `spec.md`, and `plans/NN-*.md` frontmatter; derive STATE and
NEXT exactly per that file's sync and NEXT-derivation rules; render an
unparseable chain as `INVALID (<file>: <reason>)`. Print the rows as CHAIN /
STATE / NEXT, followed by the `DONE/DROPPED` tail line as §9 describes it.

Where a rule compares a fingerprint, never work it out by eye. Run

    sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <file>

for each file the rule names. It prints the 12 characters and exits 0, or
prints nothing and exits 2 when the file has no fingerprint.

A chain the rules call `chain complete` is a row, with NEXT
`execute walk-up` — it is not part of the count. Collapse to the count line
only the chains whose intent is `done` or `dropped`. Same columns, same
output shape.
