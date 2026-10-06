---
name: discuss
description: Open, browse and close a topic-indexed discussion. Agents briefed under it hand back a short summary plus numbered topics, the detail stays on disk until a topic is opened, and a closed discussion is archived per project. Runs only when the author types /claudestacks:discuss.
argument-hint: "[list | list archive | <id> | <sid8>/<id> | done]"
disable-model-invocation: true
---

# Discuss

Argument: `$ARGUMENTS`

The communication protocol is `${CLAUDE_PLUGIN_ROOT}/skills/discuss/references/protocol.md`.
Read it before the first brief. It inherits the Context Handoff protocol, which
`/claudestacks:context-handoff` hands you.

## The command line

Resolve the storage root once, with a plain command:

```
echo "${AIRSSTACK_HOME:-$HOME/.airsstack}"
```

Call its output `<root>`. Every command below runs from the repository root as:

```
airsl run --policy confined --allow-env HOME --allow-env AIRSSTACK_HOME \
  --allow-read / --allow-write <root> \
  "${CLAUDE_PLUGIN_ROOT}/scripts/discuss.lua" <command> [argument] --session ${CLAUDE_SESSION_ID}
```

with `<root>` pasted as a literal. If `airsl` is not found, say that `airsl` is not installed,
point at `${CLAUDE_PLUGIN_ROOT}/scripts/install-airsl.sh`, and stop.

A command that fails prints its reason on stdout, one line or one line per violation for `add`,
and exits non-zero; `airsl` also writes a Lua traceback to stderr. Show the author the stdout
lines as they are, not the traceback. If stdout is empty, show the first line of stderr instead.

## What each argument does

| `$ARGUMENTS` | Run | Then |
|---|---|---|
| empty | ` start --keep '${user_config.archive_keep}'` | The discussion is open. Follow "While a discussion is open" below. |
| `list` | ` list` | Show the output. |
| `list archive` | ` list --archive` | Show the output. `<sid8>/<id>` opens one of these. |
| a number, or `<sid8>/<number>` | ` show <it>` | Answer from that section only. Do not open other topics. |
| `done` | ` done` | If you minted a Context Handoff session for this discussion, run its `end`. Report any `missing:` lines. |
| anything else | nothing | Refuse: `unknown /claudestacks:discuss argument: <it>. Use: list, list archive, <id>, done.` |

Never guess what an unrecognised argument meant.

## While a discussion is open

- **Brief agents under the protocol.** Every brief carries `handoff:`, `handoff-protocol:` and
  `comm-protocol: ${CLAUDE_PLUGIN_ROOT}/skills/discuss/references/protocol.md`.
- **After each report, add it.** Run ` add <report-path>`. It prints the new topics as
  `<id> <title>`. Show the author the agent's summary and those lines. Do not read the
  report's `<detail>` yourself.
- **If `add` refuses a report,** show its violation lines, and re-brief the agent to fix that
  report rather than repairing it yourself.
- **Your own long answers become reports too.** When an answer would run past about 15 lines,
  run ` report-path <kebab-slug>`, write the answer there as a protocol report with
  `agent: main`, run ` add` on that path, then reply with its summary and topics.
- **End every reply with the topic list** — the output of ` list`.
