# 06 — Native suite

A plugin that keeps its own test command and has claudevs run it next to the cases.

`claudevs.toml` at the plugin root declares the command:

```toml
[[native]]
run = "sh tests/native/syntax-check.sh"
```

claudevs spawns each `[[native]]` entry's `run` string with `sh -c` from the plugin directory. It
asserts only the exit code, and prints the command's combined output only when that code is not 0.
`run` is the only key an entry accepts.

`tests/native/syntax-check.sh` parses every hook script with `sh -n`. It sits under `tests/` without
being a case file, because only `*.yaml`, `*.yml`, `*_test.lua` and `test_*.lua` files are.

A plugin with a native suite still needs at least one case file. `claudevs test` looks for cases
first and exits 2 when it finds none, so this plugin also has `tests/session-banner.yaml`.

## Run it

```console
$ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/06_native_suite
```

```text
  ok    validate
        …
  ok    wiring
        0 errors, 0 warnings
  ok    test
          ok    session-banner
          ok    native: sh tests/native/syntax-check.sh (exit 0)
        1 passed, 0 failed (1 cases, 1 native suites)
  ok    test --installed
          ok    session-banner
          ok    native: sh tests/native/syntax-check.sh (exit 0)
        1 passed, 0 failed (1 cases, 1 native suites)

4 stages run, 0 failed, 0 skipped
```

The exit code is 0.
