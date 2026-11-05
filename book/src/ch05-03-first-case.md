# A First Case

A case says what a hook should do when it receives a given event. This page writes one case for
`protect-env.sh` and runs it.

## Write your first case

Cases live in the plugin's `tests/` directory. Create
`my-marketplace/my-plugin/tests/blocks-env-file.yaml`:

```yaml
event: PreToolUse
payload:
  tool_input:
    file_path: .env
expect:
  decision: deny
  stderr_contains: refusing to edit a .env file
```

`event` is what makes this a hook case. Its `payload` is laid over the default payload that
`claudevs` builds for `PreToolUse`, so the case only has to name the field it cares about. Here that
is the file the tool wants to edit.

`expect` is what the hook must do. `decision: deny` is satisfied by exit code 2 on `PreToolUse`.
`stderr_contains` checks that the hook said why on standard error.

`claudevs` finds YAML files under `tests/` and treats each as a case. A case's name is its file stem,
so this one is named `blocks-env-file`.

## Run it

```bash
claudevs test my-marketplace/my-plugin
```

The command exits with status 0:

```text
  ok    blocks-env-file

1 passed, 0 failed (1 cases, 0 native suites)
```

`claudevs` started the hook the way Claude Code would, sent it the payload, and compared what came
back with `expect`. One case passed. "0 native suites" counts test commands that the plugin declares
for itself; this plugin has none, and [Native Suites](ch06-04-native-suites.md) covers them.

A case can assert more than a decision. [Writing Cases](ch06-00-writing-cases.md) goes through the
rest, starting with [Hook Decisions](ch06-01-hook-decisions.md).

Next, [run the whole gate](ch05-04-running-the-gate.md).
