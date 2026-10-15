# Changelog

All notable changes to `claudevs-cli` (the `claudevs` binary) are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the crate follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-15

Initial release, built on `claudevs` 0.1.0. Minimum supported Rust version: 1.94.

### Added

- `claudevs test [PATH]` — runs every discovered case plus declared native suites; `--installed`
  runs them against the installed layout, `--case <NAME>` narrows the run by case name.
- `claudevs check [PATH]` — delegated `claude plugin validate`, wiring, `test`, then
  `test --installed`; `--strict` passes `--strict` through to the validation stage.
- `claudevs doctor [PATH]` — names what this environment can and cannot do.
- `claudevs migrate <case.yaml>` — converts a YAML case to its data-Lua form; `--write` replaces the
  file instead of printing.
- `--json` on `test`, `check` and `doctor` for the machine-readable report.
- Exit codes: `0` nothing wrong, `1` verdict failures or findings, `2` claudevs could not run.
