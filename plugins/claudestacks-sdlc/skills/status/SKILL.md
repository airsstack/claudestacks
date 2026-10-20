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
unparseable chain as `INVALID (<file>: <reason>)`. Also scan
`.claudestacks/sdlc/adrs/` when it exists, and read the frontmatter of each file
in it that §13.1 names an ADR: derive every ADR's row by §13.3, and every chain's
ADR conditions (C5, C6, C7) by §10.4, which read each cited ADR's status and validity per
§13.3, not its row: a healthy superseded or deprecated ADR has no row. Print the
chain rows as CHAIN / STATE / NEXT, then the `ADRS:` block as §13.4 describes it,
then the `DONE/DROPPED` tail line as §9 describes it. With no ADR file, print no
`ADRS:` block.

Where a rule compares a fingerprint, never work it out by eye. Run

    sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <file>

for each file the rule names — a sealed ADR's body included, which §13.3 compares
with its `sealed` key. It prints the 12 characters and exits 0, or
prints nothing and exits 2 when the file has no fingerprint.

A chain the rules call `chain complete` is a row, with NEXT
`execute walk-up` — it is not part of the count. Collapse to the count line
only the chains whose intent is `done` or `dropped`. Same columns, same
output shape.
