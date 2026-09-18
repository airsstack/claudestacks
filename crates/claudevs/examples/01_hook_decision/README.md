# 01 — Hook decision

A `PreToolUse` hook that guards `.env` files, tested with YAML hook cases.

`hooks/protect-env.sh` reads the tool call as JSON on stdin. It refuses an edit to a `.env` file by
exiting 2 with a message on stderr, asks for confirmation before anything under `secrets/` is touched
by printing a `permissionDecision` of `ask`, and stays silent otherwise.

| Case | Payload | Asserts |
|---|---|---|
| `tests/blocks-env-file.yaml` | `tool_input.file_path` set to `.env` | `decision: deny`, `stderr_contains` |
| `tests/asks-for-secrets.yaml` | `tool_name` and `tool_input.file_path` set | `decision: ask` |
| `tests/allows-other-files.yaml` | the default `PreToolUse` payload | `exit: 0`, `output: none` |

A case asserts what the hook means rather than how it says it. On `PreToolUse`, exit code 2 and a
JSON `permissionDecision` both read as a decision. The `payload` a case gives is laid over a default
payload for its event, so a case names only the fields it cares about.

## Run it

From the repository root:

```console
$ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/01_hook_decision
```

```text
  ok    validate
        …
  ok    wiring
        0 errors, 0 warnings
  ok    test
          ok    allows-other-files
          ok    asks-for-secrets
          ok    blocks-env-file
        3 passed, 0 failed (3 cases, 0 native suites)
  ok    test --installed
          ok    allows-other-files
          ok    asks-for-secrets
          ok    blocks-env-file
        3 passed, 0 failed (3 cases, 0 native suites)

4 stages run, 0 failed, 0 skipped
```

The exit code is 0.
