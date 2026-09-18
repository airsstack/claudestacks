# 08 — Installed layout, broken

A hook that works while the plugin runs from this checkout and breaks once the plugin is installed.

## What is wrong

`hooks/block-rm-rf.sh` reads its message from `$CLAUDE_PLUGIN_ROOT/../shared/policy-message.txt`, a
file one directory above the plugin root. From this checkout that path lands in
`crates/claudevs/examples/shared/`, so `test` passes.

`test --installed` runs the same cases against a copy of the plugin at
`cache/<marketplace>/<plugin>/<version>/`, the layout Claude Code installs a plugin into, with
`CLAUDE_PLUGIN_ROOT` pointing at the copy. Only the plugin directory is copied, so there is no
`../shared/` next to it. The hook still exits 2, which keeps `decision: deny` passing, but its message
is gone and `stderr_contains` fails.

`wiring` does not catch this. The `refs` checker reads references written as
`${CLAUDE_PLUGIN_ROOT}/…`, with braces, and this script writes the variable without them.

The fix is to keep the file inside the plugin.

## Run it

```console
$ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/08_installed_broken
```

```text
  ok    validate
        …
  ok    wiring
        0 errors, 0 warnings
  ok    test
          ok    blocks-rm-rf
        1 passed, 0 failed (1 cases, 0 native suites)
  FAIL  test --installed
          FAIL  blocks-rm-rf
                stderr: expected to contain `blocked-by-policy`, got "cat: …/cache/claudevs-examples/installed-broken/0.1.0/../shared/policy-message.txt: No such file or directory\n\n"
                payload: {"cwd":"…","hook_event_name":"PreToolUse","session_id":"claudevs-test","tool_input":{"command":"rm -rf build","file_path":"…/file.txt"},"tool_name":"Bash"}
                handler: sh "${CLAUDE_PLUGIN_ROOT}/hooks/block-rm-rf.sh"
        0 passed, 1 failed (1 cases, 0 native suites)

4 stages run, 1 failed, 0 skipped
```

The exit code is 1.
