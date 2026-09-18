# Test a plugin with claudevs

One path from a plugin with a hook to a passing `claudevs check`, a deliberate failure, and a
run against the installed layout.

## Install claudevs

From a checkout of this repository:

```console
$ cargo install --locked --path crates/claudevs-cli
```

Recorded: `Installed package `claudevs-cli v0.1.0 (…)` (executable `claudevs`)`.

Hooks run through `sh`, and cases need `git` on `PATH`: hook commands in `hooks.json` spawn as
`sh -c <command>`, and every case runs against a materialized project that is git-initialised so
a hook branching on project state cannot take a silent not-found path. `claude` is optional — only
the `validate` stage inside `check` delegates to it, and its absence degrades that one stage to
skipped rather than failing the run.

## The plugin

```text
my-marketplace/
└── my-plugin/
    ├── .claude-plugin/plugin.json
    └── hooks/
        ├── hooks.json
        └── protect-env.sh
```

`my-marketplace/my-plugin/.claude-plugin/plugin.json`:

```json
{
  "name": "my-plugin",
  "version": "0.1.0",
  "description": "Guards .env files from edits",
  "author": { "name": "You" }
}
```

`my-marketplace/my-plugin/hooks/hooks.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/protect-env.sh\"" }
        ]
      }
    ]
  }
}
```

`my-marketplace/my-plugin/hooks/protect-env.sh`:

```sh
#!/bin/sh
# Refuses edits to .env files and asks before touching anything under secrets/.
# Every other path passes silently.
payload=$(cat)
case "$payload" in
  *'"file_path":"'*'.env"'*)
    echo "protect-env: refusing to edit a .env file" >&2
    exit 2
    ;;
  *'"file_path":"secrets/'*|*'/secrets/'*)
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"protect-env: files under secrets/ need confirmation"}}'
    ;;
esac
exit 0
```

## Ask what is missing

```console
$ claudevs doctor my-marketplace/my-plugin
```

Recorded (exit 1):

```text
  ok    claude binary: present; `check` delegates its validate stage
  ok    plugin manifest: my-plugin 0.1.0
  warn  cases: no case files found under `…/my-plugin/tests` (cases are `*.yaml`, `*_test.lua` or `test_*.lua` in tests/)
  gap   marketplace: marketplace `…/my-plugin/../.claude-plugin/marketplace.json`: no `.claude-plugin/marketplace.json` in any ancestor directory; the installed layout is keyed by the marketplace that hosts the plugin
  gap   install layout: marketplace `…/my-plugin/../.claude-plugin/marketplace.json`: no `.claude-plugin/marketplace.json` in any ancestor directory; the installed layout is keyed by the marketplace that hosts the plugin

2 gaps, 1 warning
```

A `gap` is something the environment around the plugin lacks — no marketplace above it, no
simulated install layout, no `claude` binary — and makes the exit code 1. A `warn` is an
observation about the plugin's own content, here that no case files exist yet, and does not affect
the exit code. Without `claude` on `PATH` the first line reads as a gap too, naming the stage that
gets skipped.

## Put the plugin in a marketplace

`my-marketplace/.claude-plugin/marketplace.json`:

```json
{
  "name": "my-marketplace",
  "owner": { "name": "You" },
  "plugins": []
}
```

The installed layout is keyed by the name of the nearest marketplace manifest found by walking up
from the plugin.

## Write your first case

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

`event` is what makes this a hook case. Its `payload` is laid over the default payload built for
`PreToolUse`, so the case only has to name the field it cares about. `decision: deny` is satisfied
by exit code 2 on `PreToolUse`. YAML files under `tests/` are discovered as cases, and a case's name
is its file stem — this one is named `blocks-env-file`.

## Run it

```console
$ claudevs test my-marketplace/my-plugin
```

Recorded (exit 0):

```text
  ok    blocks-env-file

1 passed, 0 failed (1 cases, 0 native suites)
```

## Run the gate

```console
$ claudevs check my-marketplace/my-plugin
```

Recorded (exit 0):

```text
  ok    validate
        Validating plugin manifest: …/my-plugin/.claude-plugin/plugin.json
        ✔ Validation passed
  ok    wiring
        0 errors, 0 warnings
  ok    test
          ok    blocks-env-file
        1 passed, 0 failed (1 cases, 0 native suites)
  ok    test --installed
          ok    blocks-env-file
        1 passed, 0 failed (1 cases, 0 native suites)

4 stages run, 0 failed, 0 skipped
```

`check` runs four stages in order: delegated manifest validation, static wiring, the case suite,
and the case suite again from the simulated install layout. Without `claude` on `PATH` the first
line instead reads `skip  validate` and the run still ends at exit 0.

## Break the hook

In `protect-env.sh`, change `exit 2` to `exit 1`, then:

```console
$ claudevs test my-marketplace/my-plugin
```

Recorded (exit 1):

```text
  FAIL  blocks-env-file
        decision: expected Deny, got None
        payload: {"cwd":"…","hook_event_name":"PreToolUse","session_id":"claudevs-test","tool_input":{"file_path":".env"},"tool_name":"Edit"}
        handler: sh "${CLAUDE_PLUGIN_ROOT}/hooks/protect-env.sh"

0 passed, 1 failed (1 cases, 0 native suites)
```

Three lines to read: the mismatch itself, the payload the hook received with the default fields
filled in, and the handler that actually ran. Exit 1 is not a `PreToolUse` denial as far as
claudevs is concerned — only exit 2 counts — so the case now reports no decision at all. See
`../../examples/02_hook_decision_broken/README.md` for this failure worked through in full.

## Fix it and test the installed copy

Change `exit 1` back to `exit 2`, then:

```console
$ claudevs test --installed my-marketplace/my-plugin
```

Recorded (exit 0):

```text
  ok    blocks-env-file

1 passed, 0 failed (1 cases, 0 native suites)
```

`--installed` runs the same cases again, this time against a throwaway copy of the plugin made at
a path shaped like `cache/<marketplace>/<plugin>/<version>/`, with `CLAUDE_PLUGIN_ROOT` pointed at
that copy instead of the source checkout. See `../../examples/08_installed_broken/README.md` for a
plugin that passes `test` and fails only here.

## Where to go next

- `how-to.md` — goal-oriented recipes for specific assertions.
- `reference.md` — the case file format and CLI surface in full.
- `explanation.md` — the ideas behind claudevs.
- `../../examples/README.md` — the full set of example plugins this tutorial and the how-to guide
  draw from.
