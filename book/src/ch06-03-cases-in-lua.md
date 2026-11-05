# Cases in Lua

A YAML case is one fixed case. When you need ten similar cases, or a case that makes a decision part
way through, write it in Lua. A Lua case file returns a table, and each entry in it is a case. An entry
that is a plain table is a data case with the same fields a YAML case has. An entry that is a function
is a scripted case that drives the harness by hand.

The recipes use a plugin called `pushguard`. It blocks force pushes with a `PreToolUse` hook on `Bash`:

```text
pushguard/
├── .claude-plugin/plugin.json
├── hooks/
│   ├── hooks.json
│   └── block-force-push.sh
└── tests/
```

`hooks/hooks.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/block-force-push.sh\"" }
        ]
      }
    ]
  }
}
```

`hooks/block-force-push.sh`:

```sh
#!/bin/sh
# Blocks force pushes; every other Bash command passes silently.
payload=$(cat)
case "$payload" in
  *'git push'*'--force'*|*'git push'*' -f'*)
    echo "block-force-push: force pushes are not allowed" >&2
    exit 2
    ;;
esac
exit 0
```

## Generate cases in Lua

A force push has two spellings, `--force` and `-f`. `tests/force_push_test.lua` builds one case for
each from a table, in a loop:

```lua
local cases = {}

for name, command in pairs({
  long_flag = "git push --force origin main",
  short_flag = "git push -f origin main",
}) do
  cases["blocks_force_push_" .. name] = {
    event = "PreToolUse",
    payload = { tool_name = "Bash", tool_input = { command = command } },
    expect = { decision = "deny", stderr_contains = "force pushes are not allowed" },
  }
end

return cases
```

```console
$ claudevs test
```

```text
  ok    blocks_force_push_long_flag
  ok    blocks_force_push_short_flag

2 passed, 0 failed (2 cases, 0 native suites)
```

A file is a Lua case file when its name ends in `_test.lua` or starts with `test_`. The key of each
entry is the case name, and a case name uses only `A-Z`, `a-z`, `0-9`, `.`, `_` and `-`. A new
spelling to cover is one more line in the table.

## Script a case with t

Some checks do not fit a fixed `expect`. An entry whose value is a function is a scripted case. It
receives `t`, a handle onto the harness, and passes by returning. A failed `assert` fails the case, the
same way a mismatched `expect` fails a data case.

Add this above `return cases` in the same file. It runs the hook on a plain push and checks that the
hook returned no decision and no context:

```lua
cases.plain_push_emits_nothing = function(t)
  local reply = t.hook("PreToolUse", {
    tool_name = "Bash",
    tool_input = { command = "git push origin main" },
  })
  assert(reply.exit == 0, "expected exit 0, got " .. tostring(reply.exit))
  assert(not reply.emitted, "a plain push should emit nothing")
end
```

```console
$ claudevs test
```

```text
  ok    blocks_force_push_long_flag
  ok    blocks_force_push_short_flag
  ok    plain_push_emits_nothing

3 passed, 0 failed (3 cases, 0 native suites)
```

`t.hook(ref, payload)` runs a hook and returns its `exit`, `stdout` and `stderr`, along with
`decision` and `context` when the run carried them, and `emitted`, which is true when the hook returned a decision or context. Text on stderr alone leaves
it false. `ref` is an event name, or a substring of one handler's command. The other functions on `t`
are `t.script`, `t.skill_command`, `t.json`, `t.project`, `t.fixture` and `t.apply_fixture`. The
[claudevs CLI reference](appendix-01-claudevs-cli.md) describes each, and the
[example](https://github.com/airsstack/claudestacks/tree/main/crates/claudevs/examples/05_lua_cases)
uses `t.skill_command`, `t.script` and `t.json` to check that a skill's command prints the version in
the plugin manifest.

The Lua itself runs confined, with no access to files or processes. The functions on `t` run outside
that confinement, though, and `t.script` can start any program. Treat a case file as code you run, in
the same way you treat a shell script from the same author.

## Convert a YAML case to Lua

You can turn a YAML case into its Lua form. Say `tests/allows-plain-push.yaml` already exists:

```yaml
event: PreToolUse
payload:
  tool_name: Bash
  tool_input:
    command: git push origin main
expect:
  exit: 0
  output: none
```

`claudevs migrate` prints the Lua form to stdout and changes nothing:

```console
$ claudevs migrate tests/allows-plain-push.yaml
```

```text
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

With `--write`, it writes the file next to the YAML one and deletes the YAML file:

```console
$ claudevs migrate --write tests/allows-plain-push.yaml
```

```text
tests/allows-plain-push.yaml -> tests/allows_plain_push_test.lua
```

The new file is named `<stem>_test.lua`, with every `-` in the stem replaced by `_`. The case keeps its
original name, because the name is the table key, so the report does not change:

```console
$ claudevs test
```

```text
  ok    allows-plain-push
  ok    blocks_force_push_long_flag
  ok    blocks_force_push_short_flag
  ok    plain_push_emits_nothing

4 passed, 0 failed (4 cases, 0 native suites)
```
