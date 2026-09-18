# claudevs (engine)

Engine library for `claudevs`, the Claude Code plugin lifecycle CLI. Holds the
canonical case model (YAML and Lua front-ends), the deterministic test harness
that spawns a plugin's hooks and scripts the way the Claude Code runtime would,
native-suite delegation, static wiring checks, install-layout simulation, and
report rendering. The `claudevs-cli` crate is the binary; this crate is
everything it calls.

```rust,no_run
let report = claudevs::run_suite(std::path::Path::new("plugins/my-plugin"), &claudevs::SuiteOptions::default())?;
println!("{}", claudevs::render_human(&report));
# Ok::<(), claudevs::Error>(())
```

## Documentation

- [`docs/README.md`](docs/README.md) — tutorials, how-to guides, reference and explanation, for plugin
  authors using the `claudevs` binary and for Rust callers of this crate.
- [`examples/README.md`](examples/README.md) — runnable example plugins, each with its case files and
  the `claudevs check` outcome it produces.

## Commands

| Command | What it does |
| --- | --- |
| `test [PATH]` | Runs every discovered case plus the native suites declared in `claudevs.toml`. |
| `test --installed [PATH]` | The same cases against a throwaway copy of the plugin in the shape it has once installed, so a path that resolves only in the checkout fails here. |
| `check [PATH]` | The gate: delegated manifest validation, then wiring, then `test`, then `test --installed` — all four stages run and report even when an earlier one fails. |
| `doctor [PATH]` | Names what this environment can and cannot do, one line per probe. |
| `migrate <case.yaml>` | Mechanical conversion of a YAML case to its data-Lua form. |

Every command that produces a report — `test`, `check`, `doctor` — takes
`--json` for the machine-readable form. `migrate` writes Lua, so it does not.
`check` also takes `--strict`, which passes `--strict` through to the
delegated validation stage; see below for what that changes.

Exit codes read the same way everywhere: `0` when nothing was wrong, `1` for
verdict failures or findings, `2` when claudevs itself could not run. What
counts as "could not run" is per command, and the differences are deliberate.
`test` exits 2 whenever claudevs cannot run — for example on a usage error, an
unreadable plugin directory, a Lua case file that does not load, or a suite
with no cases to discover; the CLI reference lists every case. A plugin with no
cases is a broken discovery convention, not a green suite. Inside `check` that
condition is an environment gap for one stage, so it skips with a reason and
the run can still end at 0. `doctor` reports every environment problem it
meets as a gap, which is a 1; it exits 2 only when `--json` cannot render its
report, which its report types never cause.

## The wiring checkers

`check`'s wiring stage runs three static checkers. None of them executes
anything in the plugin.

- **refs** — every `${CLAUDE_PLUGIN_ROOT}/…` reference in the files Claude Code
  loads from a plugin (`.claude-plugin/*.json` and everything under `hooks/`,
  `skills/`, `agents/` and `commands/`) must resolve to a file that exists.
  References inside fenced code blocks are examples and are skipped. A `..`
  segment that leaves the plugin root is a finding even when the path it names
  happens to resolve today: the file is not part of the plugin and will not be
  there once it is installed.
- **invocations** — fenced command blocks in skill markdown are parsed into
  invocations by the crate's one fenced-command parser, the same one
  `t.skill_command` uses. A script (`.sh`, `.lua`, `.py` or `.js`) that nothing
  else in the plugin names is reported as a dead file. That one is a
  **warning**, not an error: it does not fail the stage. Case files, anything
  under `tests/`, language index files such as `__init__.py`, and files outside
  `hooks/` that neither start with `#!` nor are executable are not reported.
- **matchers** — `hooks/hooks.json` must be JSON with a top-level `hooks`
  object; either failure is an error. Everything else this checker reports is a
  warning: an event name claudevs does not know, a `matcher` on an event that
  takes none, and a `matcher` claudevs cannot evaluate in the exact-match and
  pattern modes the hooks reference defines. The event catalogue can lag a
  Claude Code release, and a matcher claudevs cannot evaluate is not proof the
  runtime rejects it.

## The validation stage and its absence

`check`'s first stage shells out to `claude plugin validate` rather than
reimplementing manifest validation. By default it runs without `--strict`: a
plugin whose only defect is, say, a missing `author` field still works, and a
gate that stops on that finding never reaches the three deterministic stages
that would find a real defect. `check --strict` passes `--strict` through to
the delegate, so the same findings it already reports as warnings fail the
stage instead. The binary is not a requirement either way: when it cannot be
run, that stage reports itself skipped with the reason, and the three
deterministic stages still gate. `doctor` names the same gap directly.

A skip always means the *environment* is missing something — no `claude`, no
marketplace manifest above the plugin to key an install path by, no case files
yet. It never means the plugin is wrong. A malformed `plugin.json` fails its
stage rather than skipping it, so a plugin that cannot be installed cannot pass
the gate on a machine where the validation stage had already skipped.
