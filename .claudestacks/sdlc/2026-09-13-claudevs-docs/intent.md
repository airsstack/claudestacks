---
status: approved
created: 2026-09-13
---

# Intent: claudevs has no documentation or examples to learn it from

## Problem

`clauders` can be learned without reading its source. It has a Diátaxis docs tree under
`crates/clauders/docs/` (tutorial, how-to, explanation and reference per pillar, plus architecture and
divergences) and 25 runnable examples under `crates/clauders/examples/`, each a directory with a
`main.rs` and a `README.md`. `claudevs` has none of that. `crates/claudevs/` contains `Cargo.toml`,
`README.md`, `src/` and `tests/` — no `docs/`, no `examples/` — and `crates/claudevs-cli/` has no
README at all.

The one document there is, `crates/claudevs/README.md`, already contradicts the code. It says the
`matchers` wiring checker compiles each `matcher` with the `regex` crate and reports what it rejects
(`README.md:56-60`). The crate docs say the opposite: matchers are evaluated in the exact-match and
pattern modes the hooks reference defines, and a pattern Rust cannot compile is a warning naming the
divergence, not an error against the plugin (`src/lib.rs:8-11`, `src/wiring/matchers.rs:10-11`). A
reader who trusts the README is told the wrong failure mode.

The only worked examples of case files are the test fixtures under `crates/claudevs/tests/fixtures/`.
They exist to pin behaviour, not to teach it — several are deliberately broken plugins that must fail a
named stage — and nothing points a newcomer at them.

Two groups meet this gap. A plugin author using the `claudevs` binary has no walkthrough from a plugin
to a passing `claudevs test` or `claudevs check`. A Rust caller embedding the engine has the rustdoc and
a three-line snippet (`README.md:10-14`), with nothing on how the case model, harness, wiring checkers
and report fit together.

This matters now because the draft `2026-08-29-claudevs-plugin-adoption` intent names this docs tree as
the home for case-format documentation (`intent.md:50-51`) and that tree does not exist yet.

## Affected systems

- `crates/claudevs/` — a new `docs/` tree, a new `examples/` tree, and `README.md`.
- `Makefile.toml` and `.github/workflows/ci.yml` — whatever runs the examples as a gate.
- The root `CLAUDE.md`, where it describes the `claudevs` jobs.

## Desired outcome

Someone new to claudevs learns it from its docs, on either track, without opening the crate source.

- A plugin author follows a tutorial from an existing plugin to a passing run, finds how-to guidance by
  the goal they arrive with, and can look up exactly what each command, flag, exit code, stage, checker
  and case field does.
- A Rust caller finds how to drive the engine and how its parts fit together, with the rustdoc as the
  API reference.
- Runnable example plugins show real case files. Each example's documented command and outcome is
  asserted in CI, so an example that stops matching its docs fails the build.
- Every behavioural claim in the docs and README matches the code as it stands, including the matcher
  claim above.

## Constraints

- Two tracks of equal weight: plugin authors using the CLI, and Rust callers of the engine library.
- Examples are small plugins carrying YAML and Lua case files, run through the `claudevs` binary. They
  are not Rust `[[example]]` programs.
- The example gate runs in CI next to `cargo make claudevs-check` (`.github/workflows/ci.yml:64-91`),
  and asserts both the command and its expected exit code.
- Document the case format and CLI as they exist today. The adoption chain owns later format changes
  and updates the case-format pages when it makes them.
- Docs describe the software, never the work that produced it. The rule and its banned vocabulary in
  `crates/clauders/CLAUDE.md` apply here unchanged.
- Every behavioural claim is checked against the source before it is written, and cites it where the
  document form allows.
- The workspace is featureless. No Cargo `[features]` may be introduced.
- The Definition of Done in the `claudestacks-guideline-rust` plugin is the pass/fail gate for any Rust
  or rustdoc change.

## Non-goals

- Changing the case format, adding case fields, or changing any claudevs behaviour. A behaviour defect
  found while documenting is reported, not fixed here.
- The adoption flow, the case-generation skill, and cases for the plugins under `plugins/`. All belong
  to `2026-08-29-claudevs-plugin-adoption`.
- A separate docs tree or README for `crates/claudevs-cli`.
- Rewriting the rustdoc beyond what the docs need to link to.
- Replacing or restructuring the fixtures under `crates/claudevs/tests/fixtures/`, or the corpus lane.
- Changing `crates/clauders/docs/` or its examples.

Candidate direction: mirror the clauders layout — a `docs/README.md` index over per-track Diátaxis
files — with numbered example plugin directories, simplest first.
