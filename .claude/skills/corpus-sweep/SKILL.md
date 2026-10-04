---
name: corpus-sweep
description: Use when checking this repository's plugin checkers against third-party plugins — running cargo make corpus-fetch and corpus-check, reading their rows, or deciding whether to repin the corpus. Invoke before a release, or when a corpus row reads ABSENT or UNFETCHABLE.
---

# Corpus sweep

Two cargo-make tasks answer whether `claudevs check` holds up against plugins nobody here wrote.
Neither joins `cargo make dod` or CI, so they are run deliberately — **run both before a release.**

```bash
cargo make corpus-fetch   # clones the pinned repositories into target/corpus
cargo make corpus-check   # sweeps every plugin root in them
```

`corpus-fetch` clones the 13 pinned repositories in `crates/claudevs/tests/corpus/corpus.toml` into
`target/corpus` — the only step in this repository that touches the network. `corpus-check` sweeps
every one of their 156 plugin roots, rendering one row per root. The corpus is pinned by commit SHA
rather than vendored, so `corpus-check` needs a prior `corpus-fetch` and cannot run on a bare
checkout.

## Reading an absence

A repository that has since been deleted, made private, or force-pushed prints `UNFETCHABLE` to
stderr, is skipped rather than failing the fetch outright, and has its slug recorded in
`target/corpus/.unfetchable` — the record `corpus-check` consults so that repository's row can
legitimately read `ABSENT` without failing the sweep.

Any other absence — a repository the fetch never reached, or one lost after a previous fetch — has
no such record, and fails `corpus-check` instead of rendering as a quieter, shorter pass. So a green
sweep with fewer rows than you expected is a failure the check is designed to surface, not a pass.

## Repin only what you are willing to execute

Both lanes handle third-party code: `corpus-fetch` clones from 13 repositories nobody here controls
and `corpus-check` runs `claudevs check` over what they ship.

Today that stops short of executing it: no pinned repository ships a case file. That was established
by searching the checkouts for `claudevs.toml`, `tests/*.yaml`, `tests/*.yml`, `_test.lua` and
`test_*.lua` — rather than read off the `test=Skipped` column, since `check.rs:164` also skips on a
malformed marketplace or layout.

A corpus plugin that did carry a case file would have its suite run: its Lua under
`Policy::confined()`, and any declared native suite through an unconfined shell. That is the reason
the pins are deliberate — repin only what you are willing to execute.
