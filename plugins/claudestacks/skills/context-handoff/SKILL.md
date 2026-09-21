---
name: context-handoff
description: Use when driving subagents that report through the filesystem — deciding where reports land, running a handoff session, and handing each agent the resolved path to the protocol. Invoke once at the top of any pipeline that spawns reporting agents, before the first spawn.
---

# Context Handoff

Subagent detail stays on disk; only summaries reach the thread that spawned them. This skill is
the driver half: it decides where reports land, says which session calls to make, and hands
every agent a path to the protocol that it can actually open.

**The protocol is `${CLAUDE_PLUGIN_ROOT}/skills/context-handoff/references/protocol.md`.** It
is the authority for the file schema, the tiers, the return contract, error handling, retention,
and the exact `airsl` command line for the session calls below. Read it before your first
`init`.

## Pass two fields in every brief

```
handoff: <the full write-path you assign this spawn>
handoff-protocol: <the protocol path above, exactly as it appears>
```

By the time you read this file the placeholder is already an absolute path — copy it. An agent
cannot compute it: the variable is absent from the environment of a `Bash` tool call
(`plugins-reference.md:721`), and an agent in another plugin resolves it to its own plugin's
root rather than this one's.

`coder`, `explorer` and `reviewer` live in this plugin and cite the path in their own
definitions, so they do not need the second field. Passing it anyway is harmless.

## Choose the tier

| Situation | Where reports land | Session? |
|---|---|---|
| more than one subagent in flight at once, or interleaved spawns whose reports refer to each other | the session tree | yes |
| exactly one subagent, or sequential rounds of one | a literal temp path, e.g. `${TMPDIR:-/tmp}/<skill>-<round>.md` | no |
| `init` refused or failed | `<session-scratch>/handoff/`, same `<NN>-<agent>-<slug>.md` naming | no |

Expand `${TMPDIR:-/tmp}` yourself before a path enters a brief. An agent receives its brief as
literal text and runs no shell over it, so an unexpanded variable reaches it as a filename.

A single-subagent flow calls none of the session commands and mints no session directory. There
is nothing for a lease to arbitrate, so paying for a session buys nothing. The file schema and
the return contract still apply unchanged — only the path differs.

## Run a session

Only for the first row of that table. The command line for each call, its grants, and the
worktree-guard workaround are in the protocol's session-lifecycle section — run them exactly as
written there.

1. **Once, at the top of the pipeline.** `init` mints the session, writes its lease, prunes
   stale prior sessions, and prints the session directory and id. Keep both.
2. **Per spawn.** Assign `<NN>-<agent>-<slug>.md` under the session directory and pass it as
   `handoff:`. Call `beat <session-dir>` so a long run is never pruned by a concurrent session.
3. **At close.** `end <session-dir>` drops the lease. Optional — the grace window self-heals a
   crash.

If `init` is refused or fails, do not improvise a layout: take the third tier, and record the
deviation in the run's execution record.

## Route off the summary

The agent returns its `<summary>` plus the path — never the `<detail>`. Route off the summary.
Open a `<detail>` yourself only when you personally must judge it. When a downstream agent needs
upstream detail, pass the upstream `handoff:` path plus a targeted `need:` pointer; it reads its
own slice and the detail never transits you.

## Check a report by hand

Reports are validated automatically by this plugin's hooks. To check one yourself:

```
airsl run --policy confined --allow-read / \
  "${CLAUDE_PLUGIN_ROOT}/scripts/handoff_report.lua" <path-to-report>
```

Silence and exit 0 mean the report conforms. Otherwise it prints one line per violation.
