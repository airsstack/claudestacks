# Releasing

Three crates in this workspace are published to crates.io: `airsclaude`, `claudevs` and
`claudevs-cli`. Each is released on its own, from `main`, with the `/release` Claude Code skill
(`.claude/skills/release/SKILL.md`), which publishes the crate and tags the commit.

## The two steps

`/release` is check-only. It never chooses a version, writes a changelog entry, edits a file or
commits. That happens first, in an ordinary pull request.

```
 ┌─────────────────── you, in a normal PR ───────────────────┐
 │  bump version in crates/<crate>/Cargo.toml                 │
 │  add  ## [x.y.z] - <release day>  to                       │
 │       crates/<crate>/CHANGELOG.md                          │
 │  claudevs bump? also bump its pin under                    │
 │       [workspace.dependencies] in the root Cargo.toml      │
 │  open PR → CI green → merge to main                        │
 └──────────────────────────────┬─────────────────────────────┘
                                ▼
 ┌─────────────── /release <crate>, on main ─────────────────┐
 │  checks ──► publish (asks you) ──► tag (asks you)          │
 │  never edits a file, never commits                         │
 └────────────────────────────────────────────────────────────┘
```

Date the changelog entry with the day you will publish. `/release` refuses an entry whose date is not
today, so if the release slips, fix the date in a PR first.

## What `/release` does

```
/release claudevs
   │
   ├─ preflight ── on main? clean? == origin/main? ──────── no → STOP
   ├─ version ──── x.y.z in Cargo.toml, not on crates.io? ─ no → STOP
   │               tag claudevs-vx.y.z absent? ──────────── no → STOP
   ├─ changelog ── "## [x.y.z] - <today>"? ──────────────── no → STOP
   ├─ order ────── dependencies already on crates.io? ───── no → STOP
   ├─ gates ────── cargo make dod · deny ────────────────── red → STOP
   │               + claudevs-check · corpus-fetch · corpus-check
   │                 (claudevs and claudevs-cli only; failing corpus
   │                  rows are shown to you to decide)
   ├─ contents ─── LICENSE · README · CHANGELOG in the tarball;
   │               airsclaude: no CLAUDE.md / .claude/ / test stand-in
   │               cargo publish --dry-run ──────────────── fails → STOP
   │
   ├─ ✋ "publish claudevs x.y.z to crates.io? (irreversible)"
   │     yes → cargo publish -p claudevs
   │
   └─ ✋ "push tag claudevs-vx.y.z?"
         yes → git tag -a claudevs-vx.y.z
               git push origin claudevs-vx.y.z
```

Nothing before the first ✋ changes anything. A crates.io version can be yanked, never deleted or
replaced, which is why publishing waits for your explicit yes.

## When a check fails

`/release` names the failed check and stops. Nothing is published or tagged.

```
> /release claudevs-cli

  preflight   ✓ main, clean, up to date
  version     ✓ 0.1.1 (crates.io has 0.1.0)
  changelog   ✗ no "## [0.1.1] - 2026-11-03" in crates/claudevs-cli/CHANGELOG.md

  STOP — add the 0.1.1 entry in a PR, merge, then re-run /release claudevs-cli.
  Nothing was published or tagged.
```

## Order

```
  airsclaude ──────────────────────┐   (independent)
                                   ├──► /release one crate at a time
  claudevs ──► claudevs-cli ───────┘
               (refused until the claudevs version it pins is on crates.io)
```

## What a release leaves behind

```
  crates.io      claudevs x.y.z          ← built from the main commit
  git            claudevs-vx.y.z (tag)   ← annotated, on the same commit
  Cargo.toml     version = "x.y.z"       ← from your PR, not from /release
  CHANGELOG.md   ## [x.y.z] - <date>     ← from your PR, not from /release
```

Tags follow `<crate>-v<version>`, the same scheme as `airsl`. The tag message is `<crate> <version>`
followed by the changelog entry's body.

## Before your first release

- `cargo login` with a crates.io API token that can publish these crates.
- A C compiler: `claudevs` builds Lua 5.4 from C sources through `airsl`.
- Network access: `cargo make corpus-fetch` clones the pinned third-party plugin corpus.
