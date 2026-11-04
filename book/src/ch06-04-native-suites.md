# Native Suites

A plugin may already have its own test command, such as a script that checks shell syntax or a Lua
test runner. You do not have to port it to cases. A native suite tells claudevs to run that command
alongside the cases and fail the run when the command fails.

The recipe uses a plugin called `banner`. A `SessionStart` hook prints a one-line banner, and a script
checks that every hook script parses:

```text
banner/
├── .claude-plugin/plugin.json
├── claudevs.toml
├── hooks/
│   ├── hooks.json
│   └── session-banner.sh
└── tests/
    ├── native/
    │   └── syntax-check.sh
    └── session-banner.yaml
```

## Run the plugin's own test command

`hooks/hooks.json` wires the banner hook:

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/session-banner.sh\"" } ] }
    ]
  }
}
```

`hooks/session-banner.sh`:

```sh
#!/bin/sh
echo "session-banner: native suite example"
```

`tests/native/syntax-check.sh` is the plugin's own test command. It parses each hook script with
`sh -n`, which reads a script without running it:

```sh
#!/bin/sh
# Parses every hook script without running it.
status=0
for script in hooks/*.sh; do
  if sh -n "$script"; then
    echo "ok    $script"
  else
    status=1
  fi
done
exit $status
```

`claudevs.toml` sits at the plugin root and declares the command:

```toml
[[native]]
run = "sh tests/native/syntax-check.sh"
```

A native suite sits beside at least one case. `claudevs test` looks for case files first, and with none
it stops with exit code 2 before it runs any native suite:

```console
$ claudevs test
```

```text
claudevs: no case files found under `/private/tmp/claudevs-cases/banner/tests` (cases are `*.yaml`, `*_test.lua` or `test_*.lua` in tests/)
```

The directory in that message is wherever your plugin is. `tests/native/syntax-check.sh` is not a case,
because only `*.yaml`, `*.yml`, `*_test.lua` and `test_*.lua` files are. So add one small case,
`tests/session-banner.yaml`:

```yaml
event: SessionStart
expect:
  context_contains: native suite
```

```console
$ claudevs test
```

```text
  ok    session-banner
  ok    native: sh tests/native/syntax-check.sh (exit 0)

1 passed, 0 failed (1 cases, 1 native suites)
```

claudevs runs each `[[native]]` entry's `run` string with `sh -c`, from the plugin directory. That is
why `hooks/*.sh` in the script finds the hooks without a path. Only the exit code is asserted, 0 for a
pass. The command's output is hidden while it passes. `run` is the only key an entry accepts, and any
other key stops the run with exit code 2 and a message that names it. Add more `[[native]]` tables to
run more commands.

## See a native suite fail

When the command exits with anything but 0, the run fails and the command's output is shown under its
line. Add a broken line to the end of `hooks/session-banner.sh`:

```sh
#!/bin/sh
echo "session-banner: native suite example"
if [ then
```

```console
$ claudevs test
```

```text
  ok    session-banner
  FAIL  native: sh tests/native/syntax-check.sh (exit 1)
        hooks/session-banner.sh: line 4: syntax error: unexpected end of file

1 passed, 1 failed (1 cases, 1 native suites)
```

The wording of the syntax error comes from your shell, so it can differ from this one. The exit code of
`claudevs test` is 1. Remove the broken line to return to the passing run.

The [native suite
example](https://github.com/airsstack/claudestacks/tree/main/crates/claudevs/examples/06_native_suite)
runs this plugin as it stands.
