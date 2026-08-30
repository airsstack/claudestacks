---
status: draft
created: 2026-08-29
source: triage
---

# Intent: the plugin cache goes stale and its registry accumulates dead entries

## Problem

A plugin installed from a local directory marketplace keeps running the bytes it was installed with,
even after its source changes. `claude plugin update` compares versions, not content, so editing a
plugin without bumping its version leaves the installed copy stale and reports success. Nothing in the
CLI surfaces the drift, and nothing repairs it.

This is the ordinary condition of developing a plugin in this repository. The plugins under `plugins/`
are installed from a directory-source marketplace pointing at the checkout itself, so every edit made
without a version bump puts the cache and the source out of step. It is not hypothetical: right now
`skills/process-guidelines/references/context-handoff.md` differs between the cache entry for version
`0.1.4` and the source tree at that same version. Whatever Claude Code loads for that skill is not what
is in the repository.

Two related things also accumulate with nothing to clear them. Bumping a version leaves the previous
version's cache directory on disk, referenced by nothing. And local-scope registrations survive the
project directories they were made from — the registry currently holds fifteen registrations across
five plugins, five of which point at a git worktree that no longer exists.

Deleting any of this by hand is unsafe to do casually, because a single cache directory is shared by
every registration of that plugin version. All three registrations of each plugin here share one
`installPath`, so clearing a cache entry is never a single-consumer operation, and the obvious `rm -rf`
takes the plugin away from projects that still use it.

The tooling gap is real rather than assumed. `claude plugin update` refuses same-version refresh,
`claude plugin prune` covers auto-installed dependencies and never touches cache directories, and
`claude plugin uninstall` correctly declines to reclaim a shared path. None of the three fixes any of
the above.

## Affected systems

`crates/claudevs` gains the cache and registry model; `crates/claudevs-cli` gains the surface. Both are
new work rather than changes to the existing case/harness/wiring code, which this chain does not touch.

The data it reads and writes lives outside the repository, under the Claude Code configuration
directory: `plugins/installed_plugins.json`, `plugins/cache/<marketplace>/<plugin>/<version>/`,
`plugins/known_marketplaces.json`, and `plugins/data/<id>/`. The location is not fixed at `~/.claude` —
`CLAUDE_CONFIG_DIR` relocates the whole tree, which is both a correctness requirement and the mechanism
that makes this chain testable in isolation.

The five plugins under `plugins/` are the working example, but nothing here is specific to them.

## Desired outcome

An engineer developing a plugin can find out whether what Claude Code loads matches what is in their
working tree, and can put it right without hand-editing JSON under their home directory.

`claudevs` reports three things: cache entries whose content has drifted from their source, cache
directories no version in the registry references, and registrations whose `projectPath` no longer
exists. It can also repair all three — refreshing a stale entry from source, removing orphaned version
directories, and pruning dead registrations.

Repair is safe by construction. Reporting is the default and writes nothing. Any destructive operation
requires an explicit flag, prints exactly which paths will be removed and which registrations
reference each one before acting, and refuses outright to remove a cache entry that a still-live
`projectPath` depends on.

## Constraints

- Destructive operations run against the user's home directory, outside any repository and outside
  version control. There is no `git checkout` to undo a wrong deletion. Dry-run is the default; nothing
  is removed without an explicit flag and a printed manifest of what goes.
- A cache directory is never assumed to have one consumer. Every removal is decided against the full
  registration list in `installed_plugins.json`, not against the entry that prompted it.
- `CLAUDE_CONFIG_DIR` must be honoured everywhere. Hardcoding `~/.claude` would make the feature both
  wrong for anyone who relocates it and untestable without touching the developer's real installation.
- Tests must not read or write the developer's real Claude Code installation. The isolation mechanism
  is proven and available.
- The registry file is written by the `claude` binary, which may be running concurrently. Read-only
  reporting is always safe; anything that writes has to reckon with that.
- The workspace is featureless — no Cargo `[features]` may be introduced.
- The Definition of Done in the `claudestacks-guideline-rust` plugin is the pass/fail gate.
- Must land before the crates.io publication of `0.1.0`.

## Non-goals

- Reimplementing install, uninstall, enable, disable, or update. `claude plugin` owns those and keeps
  them; this chain fills the gaps that CLI leaves, and delegates wherever a command already exists.
- Any change to the marketplace manifest format or to how plugins are installed.
- Watching the filesystem, or refreshing automatically on a timer or hook. Drift is reported and
  repaired when asked, never in the background.
- Managing `plugins/data/<id>/`, the persistent per-plugin data directory. `claude plugin uninstall
  --keep-data` governs it and user data is not cache.
- The correctness defects in the case harness and wiring checkers, and the adoption path for existing
  plugins. Both are separate chains.

## Evidence

Produced on 2026-08-29. The behavioural experiments ran in a `CLAUDE_CONFIG_DIR`-isolated tree; the
observations of the real installation are read-only. A durable write-up lives in the journal note
`claude-code-plugin-cache-behavior`.

### Isolation works, so none of this needed the real installation

With `CLAUDE_CONFIG_DIR` pointed at an empty directory, `claude plugin list --json` returns `[]` and
the CLI provisions `.claude.json` and `backups/` there. A throwaway directory-source marketplace and a
one-plugin fixture were installed into that tree for every experiment below.

### `claude plugin update` is version-keyed, not content-keyed

The fixture was installed at `0.1.0`, then its source file was edited from `GENERATION-A` to
`GENERATION-B` with the version left unchanged:

```
===== A. mutate SOURCE content, keep version 0.1.0 =====
source now:
GENERATION-B
cache now: 
GENERATION-A
===== C. claude plugin update demo@spikemkt =====
Checking for updates for plugin "demo@spikemkt" at user scope…
✔ demo is already at the latest version (0.1.0).
exit=0
===== D. cache AFTER update (same version) =====
cache content:
GENERATION-A
```

Exit 0, success message, stale bytes still on disk. `claude plugin list --json` reports nothing unusual
either.

### A version bump orphans the previous cache directory

After bumping the source manifest to `0.2.0` and running update again:

```
✔ Plugin "demo" updated from 0.1.0 to 0.2.0 for scope user. Restart to apply changes.
exit=0
===== F. cache dirs after version bump =====
.../iso/plugins/cache/spikemkt/demo/0.1.0
.../iso/plugins/cache/spikemkt/demo/0.2.0
```

The registry then references only `0.2.0`. Nothing references `0.1.0` and nothing removes it.

### `prune` does not touch cache directories

```
===== H. does prune --dry-run see the orphaned 0.1.0? =====
Nothing to prune (no auto-installed plugins at user scope).
exit=0
===== I. does prune -y remove it? =====
Nothing to prune (no auto-installed plugins at user scope).
exit=0
cache dirs after prune:
.../iso/plugins/cache/spikemkt/demo/0.1.0
.../iso/plugins/cache/spikemkt/demo/0.2.0
```

`prune`/`autoremove` is scoped to auto-installed dependencies. The orphan survives both.

### One cache directory, many registrations

Installing the same plugin at `--scope local` from two further project directories produced three
registrations, all three carrying the same `installPath`:

```
      {
        "scope": "user",
        "installPath": ".../iso/plugins/cache/spikemkt/demo/0.2.0",
        "version": "0.2.0",
      },
      {
        "scope": "local",
        "projectPath": ".../spike-cache/projA",
        "installPath": ".../iso/plugins/cache/spikemkt/demo/0.2.0",
      },
      {
        "scope": "local",
        "installPath": ".../iso/plugins/cache/spikemkt/demo/0.2.0",
        "projectPath": ".../spike-cache/projB",
      }
```

Uninstalling the `local` registration from `projA` removed that row alone and left the cache directory
in place, because `projB` still referenced it. That is correct, and it is the constraint any deletion
feature has to reproduce.

### The real installation, observed read-only

Same-version content drift, present now:

```
$ diff -rq /Users/hiraq/.claude/plugins/cache/claudestacks/claudestacks/0.1.4 \
           /Users/hiraq/Projects/airsstack/claudestacks/plugins/claudestacks
Files /Users/hiraq/.claude/plugins/cache/claudestacks/claudestacks/0.1.4/skills/process-guidelines/references/context-handoff.md and /Users/hiraq/Projects/airsstack/claudestacks/plugins/claudestacks/skills/process-guidelines/references/context-handoff.md differ
```

Fifteen registrations, five plugins, three distinct project paths:

```
$ claude plugin list --json | grep '"id"' | sort | uniq -c
   3     "id": "claudestacks-cmux@claudestacks"
   3     "id": "claudestacks-guideline-rust@claudestacks"
   3     "id": "claudestacks-journal@claudestacks"
   3     "id": "claudestacks-sdlc@claudestacks"
   3     "id": "claudestacks@claudestacks"

$ claude plugin list --json | grep -o '"projectPath": "[^"]*"' | sort -u
"projectPath": "/Users/hiraq/Projects/airsstack/claudestacks"
"projectPath": "/Users/hiraq/Projects/airsstack/claudestacks/.claude/worktrees/claudevs-docs"
"projectPath": "/Users/hiraq/Projects/airsstack/claudestacks/.claude/worktrees/plugin-sdlc-agent"
```

The third path no longer exists:

```
$ ls -d /Users/hiraq/Projects/airsstack/claudestacks/.claude/worktrees/plugin-sdlc-agent
ls: /Users/hiraq/Projects/airsstack/claudestacks/.claude/worktrees/plugin-sdlc-agent: No such file or directory

$ git worktree list
/Users/hiraq/Projects/airsstack/claudestacks                                  2db55e4 [main]
/Users/hiraq/Projects/airsstack/claudestacks/.claude/worktrees/claudevs-docs  2db55e4 [worktree-claudevs-docs] locked
```

Five dead registrations, one per plugin.

### Prior art for the interaction shape

`claude plugin prune --dry-run` already establishes dry-run as the default posture for a destructive
plugin operation in this CLI. `claude --plugin-dir <path>` loads a plugin from a directory for one
session only, bypassing the cache entirely — the existing workaround for the drift above, and the
reason this chain reports rather than intercepts.
