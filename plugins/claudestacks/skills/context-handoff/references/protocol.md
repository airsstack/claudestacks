# Context Handoff

How delegated agents report to the orchestrator through the filesystem instead of
returning everything inline. An agent is an employee filing a report to its manager (the
main thread): a cheap **summary** goes up; the heavy **detail** stays on disk and is
pulled only by whoever must operate on it. This keeps detail out of the expensive,
long-lived main-thread context unless the main thread itself must reason over it.

The shell side — session lifecycle, the liveness lease, retention — is owned by
`plugins/claudestacks/scripts/lib/handoff.lua`. This prose and that script MUST agree on the
path and rules; change one, change the other.

## Path layout

Project-local, git-ignored, rooted at the **worktree root**:

```
<worktree-root>/.airsstack/cc/plugins/claudestacks/handoff/<session-id>/<NN>-<agent>-<slug>.md
```

- `<session-id>` = `<YYYYMMDD-HHMMSS>-<rand4>`, minted by `handoff.lua init`.
- `<NN>` = zero-padded spawn sequence within the session, assigned by the orchestrator.
- `<agent>` = agent role; `<slug>` = short kebab task slug, assigned by the orchestrator.

Rooting at the worktree root isolates parallel worktrees — each gets its own physical
handoff tree, no shared state, no cross-worktree prune race. (This differs from the
snapshot store, which uses the common-dir to *share* memory; handoff is ephemeral.)

## File schema

```markdown
---
agent: reviewer
task: <one line — what this report is of>
session: 20260621-153012-a1b2   # session-tier files only
seq: 03                         # session-tier files only
---
<summary>
Returned to the main thread. The verdict / index — cheap, scannable. Always present.
</summary>
<detail>
Stays on disk. Full findings, file:line tables, rationale — whatever a downstream agent
or the main thread would need to operate on this work. Omitted when the report is thin.
</detail>
```

`<summary>` is always written; `<detail>` is gated — omit it when the summary already
says everything.

`agent:` and `task:` are always present. `task:` is composed from the brief the agent already
receives; no brief carries a field to supply it.

`session:` and `seq:` are present exactly when the file sits under a minted session tree. The
protocol has three tiers:

| Tier | Path | `session:` / `seq:` |
|---|---|---|
| session tree | `<root>/.airsstack/cc/plugins/claudestacks/handoff/<sid>/` | present |
| single-subagent exception (below) | a literal temp path | absent |
| `init`-refused fallback (below) | `<session-scratch>/handoff/` | absent |

The third tier keeps the `<NN>-<agent>-<slug>.md` naming but mints no session and writes no
lease, so there is no session identifier to record. Classifying it with the exception rather
than with the session tree is deliberate, and is what the validator's path test implements.

There is no `created:` key. The file's own modification time carries it, and requiring one
would oblige every writer agent to gain a clock for a value nothing consults.

### Exception: single-subagent flows may skip the session tree

A skill that spawns exactly one subagent and mints no session may point that subagent
at a literal, non-session temp path (for example `${TMPDIR:-/tmp}/<skill>-review.md`)
instead of a path under the session tree above. The session tree's lease, heartbeat and
pruning exist to stop concurrent multi-agent pipelines from colliding over one shared
directory; a flow with a single spawn has nothing to collide with, so paying for a
session buys nothing. The `<summary>`/`<detail>` file schema and the return contract
below still apply unchanged — only the *path* the report lands at differs. A
single-subagent flow may also re-spawn **sequentially** — a review repeated over a
revised draft, say — provided the caller assigns each round its own path, for example a
zero-padded round counter in the filename. The rounds do not overlap, so there is still
nothing for a lease to arbitrate. What still MUST use the session tree is a pipeline
that holds more than one subagent in flight at once, or that interleaves spawns of
different agents whose reports refer to each other; this exception does not extend to
those cases.

## Return & routing contract

- **Main → subagent (on spawn):** the orchestrator assigns `<NN>`/`<agent>`/`<slug>` and
  passes the **full handoff write-path** in the brief. The agent does not compute it.
- **Subagent → main:** the agent returns its `<summary>` text **plus the handoff
  path** (relative to the worktree root for a session-tree write; the literal temp
  path under the exception above). It does NOT return `<detail>`.
- **Main → downstream agent** needing prior detail: the orchestrator passes the upstream
  `handoff:` path **and** a targeted `need:` pointer; the downstream agent reads that
  file itself and pulls only the pointed-at slice into its own context.

The orchestrator stays the sole router: an agent reads another agent's handoff only
because the orchestrator handed it the path. The flat/leaf topology and the user commit
gate are unchanged.

## Report-write mechanism

Every spawn writes exactly one handoff file — its own, never another agent's, never
source. `coder` writes with its `Write` tool. The read-only agents (`explorer`,
`reviewer`) carry `Write` **scoped by instruction** to the handoff directory only —
writing the report is a first-class duty, distinct from mutating source, which they still
must never do.

The report is not a channel for editing anything else. An agent writes its own handoff file and
no other file through it. A `coder` additionally writes source within its task scope, but that
is its implementation duty, stated in its own definition — not part of this protocol and not a
licence any other agent inherits.

## Session lifecycle (via handoff.lua)

Applies only when a session is minted. A single-subagent flow taking the exception
above calls none of `init`/`beat`/`end` and mints no session dir — there is no lease to
refresh or drop.

- `handoff.lua init` — mint a session, write its `.active` lease, prune old sessions,
  print the session dir + id. The orchestrator runs this once at pipeline start.
- `handoff.lua beat <session-dir>` — refresh the `.active` lease; the orchestrator calls
  it on each spawn as a heartbeat.
- `handoff.lua end <session-dir>` — drop the lease at clean session close.

### The invocation

Run exactly this, from the repository root:

```
airsl run --policy confined \
  --allow-env AIRSSTACK_HANDOFF_KEEP --allow-env AIRSSTACK_HANDOFF_GRACE \
  --allow-read . --allow-write . \
  "${CLAUDE_PLUGIN_ROOT}/scripts/handoff.lua" init
```

`beat` and `end` take the same flags, with `beat <session-dir>` or `end <session-dir>`
in place of `init`.

**No `--allow-exec git`.** Claude Code's worktree-isolation guard refuses a command whose
operands it cannot read, and `git` behind a launcher it cannot see through is one: it
cannot prove the resulting call stays inside the worktree, so it blocks the whole command
before `airsl` starts. That is what made `init` unusable in an isolated session.

The same guard also rejects most variables in an `airsl` command line — `${CLAUDE_PLUGIN_ROOT}`,
`$TMPDIR` and `$PWD` all come back as "a value computed at runtime". `$HOME` resolves and
is accepted; nothing else here should be relied on. So in an isolated session, resolve the
path in a separate plain command first and paste the result in:

```sh
echo "$CLAUDE_PLUGIN_ROOT"     # plain commands may use variables freely
```

then run the block above with that absolute literal in place of the variable.

Without the git grant the root comes from the working directory, which is correct
whenever the caller stands at the repository root — Claude Code resets the shell there on
every call. From anywhere else, pass an absolute literal path:

```
  "${CLAUDE_PLUGIN_ROOT}/scripts/handoff.lua" init --root /abs/path/to/worktree
```

`init` prints a warning to stderr when it fell back to the working directory, so a tree
minted in the wrong place is visible rather than silent.

### When init cannot run

If `init` is refused or fails, do not improvise a layout per run. Use
`<session-scratch>/handoff/` with the same `<NN>-<agent>-<slug>.md` file naming, skip the
`.active` lease and pruning, and record the deviation in the run's execution record. The
protocol above is unchanged for everything else — only the location and the lease differ.

Retention: keep the last `AIRSSTACK_HANDOFF_KEEP` (default 10) session dirs. A dir beyond
that is pruned only once its `.active` lease is absent or older than
`AIRSSTACK_HANDOFF_GRACE` minutes (default 120). So an active (heartbeating) session is
never pruned, and a crashed one self-heals after the grace window. Pruning runs only at
`init`, never mid-run.

## Error handling

- Report write fails → the agent returns its full receipt inline and notes the failure;
  the task is not hard-failed.
- Downstream read fails (path missing) → the agent reports `handoff not found: <path>`;
  the orchestrator re-supplies inline or re-routes.
- No handoff path in the brief (agent run standalone) → the agent returns its receipt
  inline, exactly as without this protocol. Backward-compatible.
