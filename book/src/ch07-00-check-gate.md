# The check Gate

`claudevs check` is the command that answers one question about a plugin: is it sound? It runs four
stages in order and reports how each one went. A plugin is sound when none of them fails.

| Stage | What it looks at |
|---|---|
| `validate` | The manifest and the plugin's skills, agents and commands, through `claude plugin validate`. |
| `wiring` | Static checks over the plugin's files: paths that must exist, scripts nothing uses, and the matchers in `hooks.json`. |
| `test` | Your cases, run against the plugin where it sits in your checkout. |
| `test --installed` | The same cases, run against a copy laid out the way Claude Code installs a plugin. |

Here is a plugin that passes all four. Run it from the repository root:

```console
$ claudevs check --json crates/claudevs/examples/01_hook_decision | jq -c '.stages[] | {name, status}'
{"name":"validate","status":"passed"}
{"name":"wiring","status":"passed"}
{"name":"test","status":"passed"}
{"name":"test --installed","status":"passed"}
```

`--json` asks for a report a program can read. The `jq` line keeps each stage's name and verdict. The
human report is the default; [Stages](ch07-01-stages.md) shows one.

This chapter has three pages.

- [Stages](ch07-01-stages.md) explains why a failed stage does not stop the run, what the installed layout catches that
  your checkout hides, and what happens when `claude` is not on the machine.
- [Wiring](ch07-02-wiring.md) explains what the static checks look for, and why a matcher claudevs
  cannot evaluate is a warning and not an error.
- [Running in CI](ch07-03-ci.md) reads the JSON report and uses the exit code as the gate.

The cases that `test` runs are the subject of [Writing Cases](ch06-00-writing-cases.md).
