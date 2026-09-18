# 05 — Lua cases

Cases written in Lua: data cases generated in a loop, and scripted cases that drive the harness
through the `t` handle.

The plugin blocks force pushes with a `PreToolUse` hook on `Bash`, and has a `release` skill whose
one fenced command prints the manifest version.

## Data cases

`tests/force_push_test.lua` returns a table. An entry whose value is a table is a data case, with the
same fields a YAML case has. The file builds two of them in a loop, one per force-push spelling.

A Lua file is a case file when its name ends in `_test.lua` or starts with `test_`. Each entry's key
is its case name, and a case name uses only `A-Z`, `a-z`, `0-9`, `.`, `_` and `-`.

## Scripted cases

An entry whose value is a function is a scripted case. It receives `t`, and it passes by returning;
an error, such as a failed `assert`, fails it.

- `plain_push_emits_nothing` calls `t.hook("PreToolUse", payload)` and reads `exit` and `emitted`
  from the result.
- `release_skill_prints_the_manifest_version` takes the skill's first fenced command with
  `t.skill_command("release", 1)`, runs it with `t.script`, and compares what it printed with the
  version `t.json` reads from `.claude-plugin/plugin.json`.

The Lua runs under a confined policy with no grants. The `t` functions run on the host, though, and
`t.script` can start any program, so treat a case file as code you run.

## From YAML to Lua

`tests/allows-plain-push.yaml` is an ordinary YAML case. `claudevs migrate` prints its data-Lua form:

```console
$ cargo run -q -p claudevs-cli -- migrate crates/claudevs/examples/05_lua_cases/tests/allows-plain-push.yaml
return {
  ["allows-plain-push"] = {
    event = "PreToolUse",
    expect = {
      exit = 0,
      output = "none",
    },
    payload = {
      tool_input = {
        command = "git push origin main",
      },
      tool_name = "Bash",
    },
  },
}
```

`claudevs migrate --write` instead writes `allows_plain_push_test.lua` next to the YAML file and
deletes the YAML file.

## Run it

```console
$ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/05_lua_cases
```

```text
  ok    validate
        …
  ok    wiring
        0 errors, 0 warnings
  ok    test
          ok    allows-plain-push
          ok    blocks_force_push_long_flag
          ok    blocks_force_push_short_flag
          ok    plain_push_emits_nothing
          ok    release_skill_prints_the_manifest_version
        5 passed, 0 failed (5 cases, 0 native suites)
  ok    test --installed
          ok    allows-plain-push
          ok    blocks_force_push_long_flag
          ok    blocks_force_push_short_flag
          ok    plain_push_emits_nothing
          ok    release_skill_prints_the_manifest_version
        5 passed, 0 failed (5 cases, 0 native suites)

4 stages run, 0 failed, 0 skipped
```

The exit code is 0.
