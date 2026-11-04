# Hook Decisions

A hook case sends a hook one event and a payload, then checks what the hook did. You name the event,
write only the payload fields you care about, and state the result in plain words. This page asserts
a decision, then context a hook adds, then a hook that stays silent.

The recipes use one small plugin, `guard`. It wires two hooks. `protect-env.sh` guards file edits and
`deploy-reminder.sh` adds a reminder to deploy prompts:

```text
guard/
├── .claude-plugin/plugin.json
├── hooks/
│   ├── hooks.json
│   ├── protect-env.sh
│   └── deploy-reminder.sh
└── tests/
```

`hooks/hooks.json` connects each event to its script:

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
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/deploy-reminder.sh\"" }
        ]
      }
    ]
  }
}
```

The manifest is an ordinary `plugin.json`, as in [A First Plugin](ch05-02-first-plugin.md). Run
`claudevs test` from the `guard` directory after each recipe.

## Assert a hook's decision

`hooks/protect-env.sh` refuses an edit to a `.env` file by exiting with code 2. It asks for
confirmation before touching anything under `secrets/` by printing a JSON decision, and it stays
silent for every other path:

```sh
#!/bin/sh
# Refuses edits to .env files and asks before touching anything under secrets/.
payload=$(cat)
case "$payload" in
  *'"file_path":"'*'.env"'*)
    echo "protect-env: refusing to edit a .env file" >&2
    exit 2
    ;;
  *'"file_path":"secrets/'*)
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"protect-env: files under secrets/ need confirmation"}}'
    ;;
esac
exit 0
```

`tests/blocks-env-file.yaml` sends an edit to `.env` and expects a denial:

```yaml
event: PreToolUse
payload:
  tool_input:
    file_path: .env
expect:
  decision: deny
  stderr_contains: refusing to edit a .env file
```

`tests/asks-for-secrets.yaml` expects the hook to ask instead:

```yaml
event: PreToolUse
payload:
  tool_input:
    file_path: secrets/api-key.txt
expect:
  decision: ask
```

Run them:

```console
$ claudevs test
```

```text
  ok    asks-for-secrets
  ok    blocks-env-file

2 passed, 0 failed (2 cases, 0 native suites)
```

The `payload` you write is laid over a default payload for the event, so each case names only the
fields it changes. The default for `PreToolUse` carries the tool name `Edit` and a file inside the
temporary project. That is why neither case sets `tool_name`.

A `decision` is `allow`, `deny`, `ask` or `defer`. The two hooks reach their decisions in different
ways, one by exit code and one by JSON, and both cases read the same. On `PreToolUse`, exit code 2
alone reads as `deny`. A JSON envelope on stdout can also carry a decision, in any of three shapes:
`hookSpecificOutput.permissionDecision`, `hookSpecificOutput.decision.behavior`, or a top-level
`decision` field spelled `"block"`. You write `decision: deny` in each case and the hook keeps the
freedom to choose its spelling.

When a case fails, `claudevs` lists every mismatch, the payload it sent and the handler it ran. The
fix is in the hook or in the case, whichever is wrong. See the
[example](https://github.com/airsstack/claudestacks/tree/main/crates/claudevs/examples/01_hook_decision)
for a plugin that passes these cases, and its
[broken twin](https://github.com/airsstack/claudestacks/tree/main/crates/claudevs/examples/02_hook_decision_broken)
for one that does not.

## Assert context a hook adds

A hook can add context to the conversation. `hooks/deploy-reminder.sh` does it when a prompt mentions
a deploy, by printing a JSON envelope with `additionalContext`:

```sh
#!/bin/sh
# Adds a reminder when the prompt mentions a deploy; says nothing otherwise.
payload=$(cat)
case "$payload" in
  *deploy*)
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"deploy-reminder: production deploys need a change ticket"}}'
    ;;
esac
exit 0
```

`tests/deploy-prompt-gets-reminder.yaml` sets the prompt and checks the context:

```yaml
event: UserPromptSubmit
payload:
  prompt: deploy the api to production
expect:
  context_contains: change ticket
```

```console
$ claudevs test
```

```text
  ok    asks-for-secrets
  ok    blocks-env-file
  ok    deploy-prompt-gets-reminder

3 passed, 0 failed (3 cases, 0 native suites)
```

`context_contains` matches a substring of the injected context. Context comes from
`hookSpecificOutput.additionalContext` in a JSON envelope. On `SessionStart` and `UserPromptSubmit`
only, a hook's plain stdout with no envelope also counts. A `PreToolUse` hook that prints plain text
adds no context, so a `context_contains` case against it fails.

The [session context
example](https://github.com/airsstack/claudestacks/tree/main/crates/claudevs/examples/03_session_context)
adds a `SessionStart` hook that prints a banner as plain text, with a case for it.

## Assert a hook stays silent

Most prompts should pass without a word from the hook. `expect: output: none` checks that. This is
`tests/ordinary-prompt-stays-silent.yaml`:

```yaml
event: UserPromptSubmit
expect:
  output: none
```

It sets no payload, so the prompt is the default one, `hello`, which does not mention a deploy.

```console
$ claudevs test
```

```text
  ok    asks-for-secrets
  ok    blocks-env-file
  ok    deploy-prompt-gets-reminder
  ok    ordinary-prompt-stays-silent

4 passed, 0 failed (4 cases, 0 native suites)
```

The case fails if the hook returns a decision or any context. Plain stdout counts as context only on
`SessionStart` and `UserPromptSubmit`, and other output, such as text on stderr, does not count at all.
[How a hook run is read](appendix-01-claudevs-cli.md#how-a-hook-run-is-read) lists what does. The
expectation is accepted only on a hook case. A script or flow case that sets it is refused before it
runs, because only a hook run records whether anything was emitted.

Two more fields are rarely needed. A case field named `hook` picks one handler by a substring of its
command when several handlers match the same event. `payload_raw` replaces the generated stdin with a
literal string, for a hook that has to survive input that is not JSON. The
[claudevs CLI reference](appendix-01-claudevs-cli.md) lists both.

Next, [Scripts and Flows](ch06-02-scripts-and-flows.md) tests what is not a hook.
