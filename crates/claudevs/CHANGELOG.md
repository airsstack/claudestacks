# Changelog

All notable changes to `claudevs` are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the crate follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-15

Initial release. Minimum supported Rust version: 1.94. Building it compiles Lua 5.4 from C sources
(through `airsl`), so a C compiler is required.

### Added

- Case model with two front-ends: YAML cases and Lua cases, plus mechanical YAML-to-Lua migration.
- Deterministic test harness that spawns a plugin's hooks and scripts the way the Claude Code
  runtime would, against a git-initialised project.
- Native-suite delegation for suites declared in `claudevs.toml`.
- Static wiring checks: `${CLAUDE_PLUGIN_ROOT}` reference resolution, dead-script detection from
  skill command blocks, and `hooks/hooks.json` event and matcher checks.
- Installed-layout simulation, running the same cases against a throwaway copy of the plugin in the
  shape it has once installed.
- Report rendering, human-readable and JSON.
