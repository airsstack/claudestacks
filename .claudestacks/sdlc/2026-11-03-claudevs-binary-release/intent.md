---
status: done
created: 2026-11-03
---

# Intent: Install claudevs and the plugin runtime without a Rust toolchain

## Problem

The only documented way to install `claudevs` is `cargo install claudevs-cli` (`README.md:101`,
`crates/claudevs-cli/README.md:12`). Someone who only wants to test a Claude Code plugin has to
install Rust first and then compile it.

The plugin suite has the same problem one layer down. Every plugin hook runs on `airsl`, and
`plugins/claudestacks/scripts/install-airsl.sh:73-76` exits when `cargo` is missing, even though
`airsl` publishes prebuilt binaries and an installer on its GitHub releases. The docs and the
SessionStart preflight also name `cargo install airsl-cli --locked` (`README.md:162`,
`plugins/claudestacks/README.md:71`, `plugins/claudestacks/hooks/preflight.sh:47`).

Installing the prebuilt `airsl` by hand does not fully solve it. That binary goes to `~/.local/bin`,
while the fallback lookup the hooks and scripts use when `airsl` is not on `PATH` checks only
`CARGO_HOME` and `~/.cargo/bin` (for example `plugins/claudestacks/hooks/enforce.sh:25`). A hook
whose `PATH` lacks `~/.local/bin` would not find it.

`airsl` and `buildl` already give their users prebuilt binaries through one release pipeline. This
repository has no equivalent: `.github/workflows/` holds only `ci.yml` and `lua.yml`.

## Affected systems

- `crates/claudevs-cli`: the one crate here that ships a command. `airsclaude` and `claudevs` are
  libraries, all three are on crates.io at 0.1.0, and that part needs no work.
- `crates/airsclaude`: it declares a test-only binary, `airsclaude-agent-testchild`, which release
  tooling can mistake for a product.
- `.github/workflows/`, the workspace `Cargo.toml`, and the repository's GitHub Pages settings.
- The release process: `RELEASING.md` and `.claude/skills/release/SKILL.md`.
- The `airsl` install path and lookup, in the ten files that carry the same fallback lookup:
  `plugins/claudestacks/hooks/{comm-check,enforce,handoff-check,preflight,rearm,style}.sh`,
  `plugins/claudestacks/scripts/install-airsl.sh`,
  `plugins/claudestacks-sdlc/scripts/{attention,status}.sh`, and
  `plugins/claudestacks-journal/scripts/session-start.sh`.
  `plugins/claudestacks/scripts/statusline-install.lua:71` mentions the path only in a comment.
- User-facing install docs: `README.md`, `crates/claudevs-cli/README.md`,
  `plugins/claudestacks/README.md`.

## Desired outcome

- On macOS or Linux, on either architecture, including systems without glibc, a user installs a
  working `claudevs` with one command and no Rust toolchain, from
  `https://airsstack.github.io/claudestacks/install.sh`.
- Each `claudevs-cli` release publishes binaries that were run on their own platform before
  publication, the same guarantee `airsl` and `buildl` give.
- A pull request that breaks a release target fails on that pull request, not on the release tag.
- A user with no Rust toolchain can get the `airsl` runtime through the plugin's own install script,
  and every hook and script finds it afterwards, including when `~/.local/bin` is not on `PATH`.
- Only `claudevs` is released as a binary. The `airsclaude` test helper never appears in a release.

## Constraints

- Same pipeline shape as `airsl` and `buildl`, so the three repositories stay maintainable as one
  pattern.
- Targets match `buildl`: `aarch64` and `x86_64` for macOS, Linux glibc and Linux musl. Shell
  installer only. `claudevs` does not compile on Windows today
  (`crates/claudevs/src/wiring/invocations.rs:31`, `:212`).
- The first release with binaries is `claudevs-cli` 0.1.1. Version 0.1.0 is already on crates.io and
  its tag sits on a commit that has no pipeline.
- `/release` stays check-only: the version bump and changelog entry arrive through a normal pull
  request, and publishing and tagging each wait for the author's explicit yes.
- `cargo install claudevs-cli` keeps working for people who have Rust.

## Non-goals

- Windows support, for `claudevs` or its installer.
- Binaries or installers for the `airsclaude` and `claudevs` libraries.
- Changes to the `airsl` repository or its releases.
- Publishing `airsclaude` or `claudevs` new versions just to accompany this work.
- A self-updating `claudevs` binary.
