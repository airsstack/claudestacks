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
hand. Scan `.claudestacks/sdlc/` per the rules in
`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`: skip `prds/`, `rfcs/`
and non-directories; read each chain's `intent.md`, `spec.md`, and
`plans/NN-*.md` frontmatter; derive STATE and NEXT exactly per that file's
NEXT-derivation rules; render an unparseable chain as
`INVALID (<file>: <reason>)`; collapse to a count line any chain whose intent
is `done` or `dropped`, or whose every plan is `done`/`superseded` with at
least one `done`. Same columns, same output shape.
