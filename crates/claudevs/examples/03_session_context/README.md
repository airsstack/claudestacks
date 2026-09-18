# 03 — Session context

Two hooks that add context to the conversation, and cases that assert the context arrived.

- `hooks/session-banner.sh` runs at `SessionStart` and prints one line. On `SessionStart` and
  `UserPromptSubmit`, plain stdout from a hook is context, so it needs no JSON.
- `hooks/deploy-reminder.sh` runs at `UserPromptSubmit`. When the prompt mentions a deploy it prints a
  JSON object whose `hookSpecificOutput.additionalContext` carries a reminder, and otherwise it prints
  nothing.

| Case | Asserts |
|---|---|
| `tests/session-start-injects-banner.yaml` | `context_contains` against plain stdout |
| `tests/deploy-prompt-gets-reminder.yaml` | `context_contains` against `additionalContext`, with `prompt` set in the payload |
| `tests/ordinary-prompt-stays-silent.yaml` | `output: none` against the default payload, whose prompt is `hello` |

`output: none` fails when a hook emits any JSON envelope or any context. Only hook cases accept it.

## Run it

```console
$ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/03_session_context
```

```text
  ok    validate
        Validating plugin manifest: …/crates/claudevs/examples/03_session_context/.claude-plugin/plugin.json
        ✔ Validation passed
  ok    wiring
        0 errors, 0 warnings
  ok    test
          ok    deploy-prompt-gets-reminder
          ok    ordinary-prompt-stays-silent
          ok    session-start-injects-banner
        3 passed, 0 failed (3 cases, 0 native suites)
  ok    test --installed
          ok    deploy-prompt-gets-reminder
          ok    ordinary-prompt-stays-silent
          ok    session-start-injects-banner
        3 passed, 0 failed (3 cases, 0 native suites)

4 stages run, 0 failed, 0 skipped
```

The exit code is 0.
