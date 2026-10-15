# claudevs

Deterministic tests for Claude Code plugins. `claudevs` runs a plugin's hooks and scripts the way the
Claude Code runtime would, checks its wiring, and simulates its installed layout.

This crate is the `claudevs` binary. The engine it calls is the
[`claudevs`](https://crates.io/crates/claudevs) library crate.

## Install

```bash
cargo install claudevs-cli
```

The installed binary is named `claudevs`.

## Commands

| Command | What it does |
| --- | --- |
| `test [PATH]` | Runs every discovered case plus the native suites declared in `claudevs.toml`. |
| `test --installed [PATH]` | The same cases against a throwaway copy of the plugin in the shape it has once installed, so a path that resolves only in the checkout fails here. |
| `test --case <NAME> [PATH]` | Runs only the cases whose name contains `NAME`. |
| `check [PATH]` | The gate: delegated manifest validation, then wiring, then `test`, then `test --installed` — all four stages run and report even when an earlier one fails. |
| `doctor [PATH]` | Names what this environment can and cannot do, one line per probe. |
| `migrate <case.yaml>` | Mechanical conversion of a YAML case to its data-Lua form, printed to stdout. |
| `migrate --write <case.yaml>` | The same conversion, replacing the `.yaml` file with the `.lua` file. |

`test`, `check` and `doctor` take `--json` for the machine-readable report. Exit codes: `0` when
nothing was wrong, `1` for verdict failures or findings, `2` when claudevs itself could not run.

## Documentation

The full documentation — tutorials, how-to guides, the CLI reference and explanation — lives in the
[`claudevs` docs](https://github.com/airsstack/claudestacks/blob/main/crates/claudevs/docs/README.md).

## License

Apache-2.0.
