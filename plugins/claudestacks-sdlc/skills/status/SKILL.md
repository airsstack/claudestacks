---
name: status
description: Render the claudestacks-sdlc chain status board. Use when the user says "/claudestacks-sdlc:status", asks what state the SDLC chains are in, or what to work on next.
---

## Board

!`sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"`

## Task

If the board above is non-empty, present it exactly as printed and stop.

If empty, `airsl` is not installed: derive the board by hand from
`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md` alone (it owns the non-chain entries, keys,
sync rules and NEXT derivation).

1. Scan `.claudestacks/sdlc/`, skipping the entries that file names and every non-directory. Read
   each chain's `intent.md`, `spec.md`, `plans/NN-*.md` frontmatter; derive STATE and NEXT; render an
   unparseable chain as `INVALID (<file>: <reason>)`.
2. If `adrs/` exists, read each §13.1 ADR file's frontmatter: ADR rows by §13.3, chain ADR
   conditions (C5, C6, C7) by §10.4 (cited ADR status and validity per §13.3, not its row; a healthy
   superseded or deprecated ADR has no row).
3. Print chain rows as CHAIN / STATE / NEXT, then the `ADRS:` block per §13.4 (none without an ADR
   file), then the `DONE/DROPPED` tail per §9. A `chain complete` chain is a row with NEXT
   `execute walk-up`, not counted; collapse only chains whose intent is `done` or `dropped`.

For any fingerprint comparison (a sealed ADR's body included, per §13.3) never eyeball; run
`sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <file>`: it prints 12 characters and exits 0, or
prints nothing and exits 2 when the file has no fingerprint.
