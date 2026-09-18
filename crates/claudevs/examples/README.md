# claudevs examples

Each directory below is a small Claude Code plugin whose `tests/` directory holds claudevs cases. Run
one from the repository root:

```console
$ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/01_hook_decision
```

`check` runs four stages in order: `validate`, `wiring`, `test` and `test --installed`. Every stage
runs even when an earlier one fails. `claudevs test <dir>` runs the cases and native suites alone,
without `validate` or `wiring`.

| Example | Shows | `claudevs check` ends with |
|---|---|---|
| [`01_hook_decision`](01_hook_decision/README.md) | a `PreToolUse` gate tested with YAML hook cases: `decision`, `stderr_contains`, `output: none`, payload overlays | exit 0 |
| [`02_hook_decision_broken`](02_hook_decision_broken/README.md) | the same gate with a defect, and the failure its case reports | exit 1, `FAIL  test` |
| [`03_session_context`](03_session_context/README.md) | context added at `SessionStart` and `UserPromptSubmit`, asserted with `context_contains` and `output: none` | exit 0 |
| [`04_script_and_flow`](04_script_and_flow/README.md) | a script case with `invocation.env`, and a flow over a fixture project with `.gitinit`, `apply_fixture` and `files_exist` | exit 0 |
| [`05_lua_cases`](05_lua_cases/README.md) | generated data cases and scripted cases in Lua using `t.hook`, `t.script`, `t.skill_command` and `t.json`, and `claudevs migrate` | exit 0 |
| [`06_native_suite`](06_native_suite/README.md) | a native test command declared in `claudevs.toml` | exit 0 |
| [`07_wiring_broken`](07_wiring_broken/README.md) | a `${CLAUDE_PLUGIN_ROOT}` reference to a file that does not exist | exit 1, `FAIL  wiring` |
| [`08_installed_broken`](08_installed_broken/README.md) | a hook that works in this checkout and breaks once installed | exit 1, `FAIL  test --installed` |
| [`09_doctor_gaps`](09_doctor_gaps/README.md) | `claudevs doctor`: what it answers versus `check`, and the gaps and warning it reports on a broken environment | exit 0 |

`cargo test -p claudevs --test examples` runs `claudevs check` on every example and asserts the exit
code and the stage in the last column, so an example that stops matching its README fails the build.

## Without a `claude` binary

The `validate` stage hands the manifest to `claude plugin validate`. When `claude` is not on `PATH`,
that stage reports `skip  validate` with the reason, and the other three stages still decide the
result. Every outcome in the table holds either way.

## Why a marketplace manifest sits here

`.claude-plugin/marketplace.json` makes this directory a marketplace for the plugins inside it.
`test --installed` copies a plugin to `cache/<marketplace>/<plugin>/<version>/`, the layout Claude Code
installs a plugin into, and takes `<marketplace>` from the nearest `.claude-plugin/marketplace.json`
above the plugin. Without one, that stage skips. This manifest lists no plugins.

## Why `shared/` sits here

`shared/policy-message.txt` belongs to `08_installed_broken`. That example's hook reads the file
through a path that climbs out of the plugin root: it is found while the plugin runs from this
checkout, and missing from the installed copy. That gap is what the example shows.
