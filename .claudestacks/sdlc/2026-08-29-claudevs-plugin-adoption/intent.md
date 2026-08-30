---
status: draft
created: 2026-08-29
---

# Intent: an engineer with an existing plugin has no path to adopt claudevs

## Problem

There is no route from "I have a Claude Code plugin" to "I have a passing claudevs case." Someone
arriving with a plugin they already wrote has nothing to follow: no starting command, no example, and
no description of the file they are supposed to write.

The case file format is documented nowhere. `crates/claudevs/README.md` covers the subcommands, the
exit-code contract, the three wiring checkers and the skip policy, and contains not one example of a
case. Everything an author needs — that cases live under `<plugin>/tests`, that Lua cases must be named
`*_test.lua` or `test_*.lua` while YAML can be any `.yaml`, that the case name is the file stem and so
the filename is the report identity, that a fixture file named `.gitinit` triggers `git init` and an
empty commit, that `expect.output` accepts exactly one value — is discoverable only by reading Rust
source. A dogfooding attempt against this repository's own plugin spent roughly seventy percent of its
effort fighting the tool rather than writing assertions, and every field it used was learned from
`crates/claudevs/src/case/model.rs`.

The format also cannot express common hooks. A hook case sends the synthesized payload on stdin but has
no `env` map — that field exists only on `Invocation`, which in turn is never given stdin. Any hook that
both reads a payload and branches on an environment variable therefore fits neither case kind. There are
no per-case setup or teardown steps, and no negative assertions, so a hook whose defining behaviour is
deleting a file or staying silent on a second invocation cannot be tested at all. Three of the five
hooks in `plugins/claudestacks` could only be covered by hand-rolling shell pipelines that bypass
claudevs, giving up payload synthesis, hook resolution from `hooks.json`, and event semantics along the
way. A fourth got only a vacuous pass.

The consequence is visible in this repository: five plugins ship, and not one has a case file. The tool
built to test plugins is not used to test the plugins sitting beside it.

Some of what an adoption flow would need already exists in the `claude` binary and should not be built
again — `claude plugin list --json` emits a full registration inventory, `claude plugin details` reports
a component inventory, and `claude plugin init --with skills,agents,hooks` scaffolds a new plugin. What
is missing is the step none of those cover: turning a plugin that already exists into one with a test
suite.

## Affected systems

`crates/claudevs` — the case model and its discovery rules, which have to grow the fields an author
needs; `crates/claudevs-cli` for whatever surface the flow drives.

A new skill in the `claudestacks` plugin under `plugins/`, gated by `cargo make plugins` like the rest
of the suite, plus its README.

Documentation of the case format, which today has no home at all: `crates/claudevs/README.md` and the
docs tree under `crates/claudevs/docs/`.

The five plugins under `plugins/` are the first consumers and the proving ground.

## Desired outcome

An engineer points Claude Code at a plugin they already wrote and comes away with case files that run.

The flow reads what is actually there — the manifest, the hooks the plugin declares, the scripts those
hooks invoke, the skills and agents it ships — and produces cases grounded in that structure rather than
in a guess. The engineer reviews and edits them; they are a starting point, not an oracle. Running
`claudevs` afterwards tells them something true about their plugin.

The case format is documented well enough that the next case is written without opening the crate. And
the format can express the hooks people actually write: a hook case can set environment variables, a
case can prepare state before it runs and clean up after, and a case can assert that something did not
happen.

The proof is this repository. The five plugins under `plugins/` carry real cases, written through the
flow, and those cases catch a deliberately broken hook.

## Constraints

- Sequenced after the plugin-correctness chain. Pointing `claudevs` at a third-party plugin today
  yields a 93% false-failure rate; an adoption path laid over that teaches people the tool is wrong.
- Delegate to `claude plugin` wherever a command already exists. Inventory and scaffolding of new
  plugins are solved; this chain covers only the gap.
- The generated cases are reviewed by a human before they are trusted. A generator that emits confident
  assertions about behaviour it has not observed would manufacture exactly the false greens the
  correctness chain exists to remove.
- The skill ships in `plugins/` and answers to `cargo make plugins` — `airsl check` over every file and
  `airsl test` over the suite.
- Case-format changes are free to break the existing shape: the repository ships zero case files today.
  That freedom ends at the crates.io publication of `0.1.0`.
- The workspace is featureless — no Cargo `[features]` may be introduced.
- The Definition of Done in the `claudestacks-guideline-rust` plugin is the pass/fail gate.

## Non-goals

- Scaffolding new plugins from nothing. `claude plugin init --with ...` does that and keeps doing it;
  this chain is about plugins that already exist.
- Reimplementing `claude plugin list --json` or `claude plugin details` as native inventory.
- The correctness defects in the harness and the wiring checkers, including `--strict`, the fail-fast
  stage pipeline, and the case-loading order. All belong to the plugin-correctness chain.
- Plugin cache staleness and dead registry entries. Separate chain.
- Migrating this repository's plugins to some new structure. They get cases; they do not get rearranged.
- Generating cases for `type: prompt`, `type: agent`, `http`, or `mcp_tool` hook handlers. Only
  `type: command` is in scope.

## Candidate direction

Deterministic input from the plugin's own structure, model-driven conversion, reviewed output — the
shape described when this was first raised. How much is a `claudevs` subcommand and how much is the
skill is a design question, not one this intent settles.
