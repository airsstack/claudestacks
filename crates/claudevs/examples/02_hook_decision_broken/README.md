# 02 — Hook decision, broken

The plugin from [`01_hook_decision`](../01_hook_decision/README.md) with one defect, to show what a
failing case reports.

## What is wrong

`hooks/protect-env.sh` exits 1 on the `.env` branch instead of 2. claudevs reads a `PreToolUse`
denial from exit code 2 or from a JSON decision on stdout. Exit code 1 is neither, so the hook still
prints its message but communicates no decision, and `tests/blocks-env-file.yaml`, which asserts
`decision: deny`, fails.

The `test` stage reports it, and so does `test --installed`, because both stages run the same cases.

## Run it

```console
$ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/02_hook_decision_broken
```

```text
  ok    validate
        …
  ok    wiring
        0 errors, 0 warnings
  FAIL  test
          ok    allows-other-files
          ok    asks-for-secrets
          FAIL  blocks-env-file
                decision: expected Deny, got None
                payload: {"cwd":"…","hook_event_name":"PreToolUse","session_id":"claudevs-test","tool_input":{"file_path":".env"},"tool_name":"Edit"}
                handler: sh "${CLAUDE_PLUGIN_ROOT}/hooks/protect-env.sh"
        2 passed, 1 failed (3 cases, 0 native suites)
  FAIL  test --installed
          ok    allows-other-files
          ok    asks-for-secrets
          FAIL  blocks-env-file
                decision: expected Deny, got None
                payload: {"cwd":"…","hook_event_name":"PreToolUse","session_id":"claudevs-test","tool_input":{"file_path":".env"},"tool_name":"Edit"}
                handler: sh "${CLAUDE_PLUGIN_ROOT}/hooks/protect-env.sh"
        2 passed, 1 failed (3 cases, 0 native suites)

4 stages run, 2 failed, 0 skipped
```

The exit code is 1. A failing hook case prints the payload the hook received and the handler that
ran, which tells you which branch the hook took. Change `exit 1` to `exit 2` in the script and the
run ends at 0.
