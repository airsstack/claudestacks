# claudevs

Deterministic tests for Claude Code plugins. `claudevs` runs a plugin's hooks and scripts the way the
Claude Code runtime would, checks its wiring, and simulates its installed layout.

This crate is the `claudevs` binary. The engine it calls is the
[`claudevs`](https://crates.io/crates/claudevs) library crate.

## Install

```bash
curl -LsSf https://airsstack.github.io/claudestacks/install.sh | sh   # prebuilt binary, no Rust needed
cargo install claudevs-cli                                            # or build from source
```

The installed binary is named `claudevs`. It needs `git` on `PATH`: it creates a git repository as the
default project each case runs in.

## Use

Run these from a plugin's directory, or pass the plugin's path as the last argument:

```bash
claudevs check          # the gate: validate, wiring, the cases, and the cases against the installed layout
claudevs test           # run only the cases and native suites
claudevs doctor         # say what this environment can and cannot do
```

`test`, `check` and `doctor` take `--json` for the machine-readable report. Exit codes: `0` when
nothing was wrong, `1` for verdict failures or findings, `2` when claudevs itself could not run.

## Documentation

The book takes you from install to a passing gate.

- [Installation](https://airsstack.github.io/claudestacks/ch05-01-installation.html)
- [Getting Started](https://airsstack.github.io/claudestacks/ch05-00-claudevs-getting-started.html)
  writes a first plugin and a first case, then runs the gate.
- [Writing Cases](https://airsstack.github.io/claudestacks/ch06-00-writing-cases.html)
- [The check Gate](https://airsstack.github.io/claudestacks/ch07-00-check-gate.html), including
  [running it in CI](https://airsstack.github.io/claudestacks/ch07-03-ci.html).
- [claudevs CLI Reference](https://airsstack.github.io/claudestacks/appendix-01-claudevs-cli.html)
  lists every command, flag and exit code.

## License

Apache-2.0.
