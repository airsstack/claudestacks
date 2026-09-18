# claudevs how-to

Recipes for one goal at a time. Each links the example that shows it running end to end.

## Assert a hook's decision

`tests/blocks-env-file.yaml` from `01_hook_decision`:

```yaml
event: PreToolUse
payload:
  tool_input:
    file_path: .env
expect:
  decision: deny
  stderr_contains: refusing to edit a .env file
```

A `decision` is `allow`, `deny`, `ask` or `defer`. On `PreToolUse`, exit code 2 alone reads as `deny`.
Separately from an exit code, a JSON envelope on stdout carries a decision through
`hookSpecificOutput.permissionDecision`, `hookSpecificOutput.decision.behavior`, or a top-level
`decision` field spelled `"block"`.

See `../../examples/01_hook_decision/README.md`.

## Assert context a hook adds

`tests/deploy-prompt-gets-reminder.yaml` from `03_session_context`:

```yaml
event: UserPromptSubmit
payload:
  prompt: deploy the api to production
expect:
  context_contains: change ticket
```

Injected context is `hookSpecificOutput.additionalContext` in a JSON envelope, or, on `SessionStart`
and `UserPromptSubmit` only, a hook's plain stdout with no envelope at all.

See `../../examples/03_session_context/README.md`.

## Assert a hook stays silent

```yaml
expect:
  output: none
```

This fails the case if the hook emits any JSON envelope or any context, on any event. It is accepted
only on a hook case: a script or flow case that sets it is rejected before it runs.

`03_session_context`'s `tests/ordinary-prompt-stays-silent.yaml` asserts this against the plugin's
default prompt. See `../../examples/03_session_context/README.md`.

A case field named `hook` disambiguates which of a plugin's several commands for the same event to
run, and `payload_raw` replaces the generated stdin with a literal string instead of a JSON overlay.
No example needs either field: `reference.md` covers both.

## Test a script with its environment

`tests/greets-by-name.yaml` from `04_script_and_flow`:

```yaml
invocation:
  argv: [sh, -c, 'sh "$CLAUDE_PLUGIN_ROOT/scripts/greet.sh"']
  env:
    GREETING_NAME: claudevs
expect:
  exit: 0
  stdout_contains: hello, claudevs
```

`invocation.argv` is spawned directly, without a shell — this case runs `sh -c` itself so that
`$CLAUDE_PLUGIN_ROOT` gets expanded. `{project}` in any `argv` or `env` value is replaced with the
path of the case's temporary project before the child is spawned.

See `../../examples/04_script_and_flow/README.md`.

## Test a multi-step flow in a project

`tests/new-note-flow.yaml` from `04_script_and_flow`:

```yaml
project: notes-repo
steps:
  - run:
      argv: [sh, -c, 'sh "$CLAUDE_PLUGIN_ROOT/scripts/new-note.sh" "first note"']
    expect:
      exit: 0
      stdout_contains: created notes/first-note.md
  - apply_fixture: imported-notes
  - run:
      argv: [ls, notes]
expect:
  exit: 0
  stdout_contains: imported.md
  files_exist:
    - notes/first-note.md
    - notes/imported.md
```

`project: notes-repo` seeds one project shared by every step from `tests/fixtures/notes-repo/`. Each
`run` step's own `expect`, when it has one, must hold for the flow to continue; `apply_fixture` copies
another fixture directory over the same project without running anything. The top-level `expect` is
judged against the last step that ran, and its `files_exist` paths are relative to the project.

See `../../examples/04_script_and_flow/README.md`.

## Generate cases in Lua

`tests/force_push_test.lua` from `05_lua_cases` builds a data case per loop iteration:

```lua
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
```

An entry in the table a Lua case file returns is a data case, with the same fields a YAML case has,
whenever its value is a plain table rather than a function.

See `../../examples/05_lua_cases/README.md` and `reference.md#lua-cases`.

## Script a case with t

The same file's `plain_push_emits_nothing` entry is a function, so it is a scripted case:

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

A scripted case receives `t`, the handle onto the harness, and passes by returning: a failed `assert`
fails the case the same way a mismatched `expect` fails a data case.

See `../../examples/05_lua_cases/README.md` and `reference.md#lua-cases`.

## Run the plugin's own test command

`claudevs.toml` from `06_native_suite`:

```toml
[[native]]
run = "sh tests/native/syntax-check.sh"
```

Each `[[native]]` entry's `run` string is spawned with `sh -c` from the plugin directory alongside the
case files, and only its exit code is asserted.

See `../../examples/06_native_suite/README.md`.

## Run only some cases

```console
$ claudevs test --case blocks crates/claudevs/examples/01_hook_decision
```

```text
  ok    blocks-env-file

1 passed, 0 failed (1 cases, 0 native suites)
```

`--case` keeps a case only when its name contains the given substring.

See `../../examples/01_hook_decision/README.md`.

## Convert a YAML case to Lua

```console
$ claudevs migrate <file>
```

prints the case's data-Lua form to stdout. `claudevs migrate --write <file>` instead writes
`<stem>_test.lua` next to it, with any `-` in the stem replaced by `_`, and deletes the YAML file.

See `../../examples/05_lua_cases/README.md`.

## Use JSON in CI

```console
$ claudevs check --json crates/claudevs/examples/07_wiring_broken | jq -r '.stages[] | select(.status == "failed") | .name'
wiring
```

Each stage's `status` is `"passed"`, `"failed"` or `"skipped"`, and its `detail` is the same rendered
text the human report shows, not a further layer of JSON. The report on stdout carries no verdict of
its own, so keep `claudevs check`'s exit code as the gate — for example by adding `set -o pipefail`
before a pipeline like the one above.

See `reference.md#json-reports` and `../../examples/07_wiring_broken/README.md`.

## Fail on manifest warnings

```console
$ claudevs check --strict my-marketplace/my-plugin
```

Recorded against a plugin whose `plugin.json` has no `author`, no marketplace manifest above it and no
case files yet:

```text
  FAIL  validate
        Validating plugin manifest: …/my-plugin/.claude-plugin/plugin.json
        ⚠ Found 1 warning:
          ❯ author: No author information provided. Consider adding author details for plugin attribution
        ✘ Validation failed (--strict treats warnings as errors)
  ok    wiring
        0 errors, 0 warnings
  skip  test
        no case files found under `…/my-plugin/tests` (cases are `*.yaml`, `*_test.lua` or `test_*.lua` in tests/)
  skip  test --installed
        marketplace `…/my-plugin/../.claude-plugin/marketplace.json`: no `.claude-plugin/marketplace.json` in any ancestor directory; the installed layout is keyed by the marketplace that hosts the plugin

2 stages run, 1 failed, 2 skipped
```

The exit code is 1. Without `--strict`, the same plugin's `validate` stage passes with the warning
still shown (`✔ Validation passed with warnings`) and the run ends at `2 stages run, 0 failed,
2 skipped`, exit 0. `--strict` changes nothing about the three stages below `validate`, and nothing
at all when `claude` is not on `PATH` to begin with.

To reproduce this, remove `author` from a plugin manifest before it has a marketplace above it or any
case files: see `tutorial.md`.

## Read a skip

The `skip` lines above name what the environment lacks rather than failing the run: no case files, and
no marketplace manifest above the plugin to key an installed copy by. A third kind reads
`` skip  validate `` with `` cannot run `claude`: No such file or directory (os error 2) `` when the
`claude` binary itself is not on `PATH`. None of the three fails `claudevs check`; the fix is a case
file, a marketplace manifest, or `claude` on `PATH`, whichever is missing.

See `tutorial.md#put-the-plugin-in-a-marketplace` and
`../../examples/README.md#without-a-claude-binary`.
