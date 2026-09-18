# 07 — Wiring, broken

A plugin whose `hooks/hooks.json` points at a script that is not there.

## What is wrong

The `PostToolUse` hook runs `${CLAUDE_PLUGIN_ROOT}/hooks/format-on-write.sh`, but the script in
`hooks/` is `format.sh`. The `refs` wiring checker resolves every `${CLAUDE_PLUGIN_ROOT}/…` reference
in the files Claude Code loads from a plugin. A reference to a file that does not exist is an error,
so the `wiring` stage fails.

No case exercises `PostToolUse`, so `test` and `test --installed` still pass. `wiring` finds the
defect without running anything, and a failing stage does not stop the stages after it.

## Run it

```console
$ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/07_wiring_broken
```

```text
  ok    validate
        Validating plugin manifest: …
        ✔ Validation passed
  FAIL  wiring
          error  refs  hooks/hooks.json:9  `${CLAUDE_PLUGIN_ROOT}/hooks/format-on-write.sh` does not exist
        1 error, 0 warnings
  ok    test
          ok    session-banner
        1 passed, 0 failed (1 cases, 0 native suites)
  ok    test --installed
          ok    session-banner
        1 passed, 0 failed (1 cases, 0 native suites)

4 stages run, 1 failed, 0 skipped
```

The exit code is 1. Point the command at `hooks/format.sh` and the run ends at 0.
