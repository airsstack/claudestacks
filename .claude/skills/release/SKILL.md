---
name: release
description: Publish one of this workspace's crates (airsclaude, claudevs, claudevs-cli) to crates.io and tag it. Check-only — verifies that main already carries the version bump and a dated CHANGELOG entry, runs the release gates, then publishes and tags only after an explicit yes for each. Never edits a file or commits.
argument-hint: <airsclaude|claudevs|claudevs-cli>
disable-model-invocation: true
---

# Release `$0`

Publish crate `$0` from `main` and tag it. `RELEASING.md` at the repository root is the picture an
engineer reads; this file is the procedure. They describe the same flow — if they disagree, fix the
one that is wrong in the same change.

**This skill is check-only.** It never bumps a version, writes a CHANGELOG entry, edits a file, or
commits. The version and the entry arrive on `main` through a normal PR before this skill runs. When
a check fails, STOP: report the failing check and what fixes it, and say that nothing was published
or tagged. Do not offer to fix it inside this run.

Run every step in order. Do not skip a step because an earlier release passed it.

## 1. The crate

`$0` must be exactly one of `airsclaude`, `claudevs`, `claudevs-cli`. Anything else — including no
argument — STOPs with that list. Read `version` from `crates/$0/Cargo.toml`; call it `V`.

## 2. Preflight

```bash
git fetch origin
git branch --show-current          # must be: main
git status --porcelain             # must be empty
git rev-parse HEAD origin/main     # the two must be equal
```

Then the version must be new, and the tag must not exist yet:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' -A 'claudestacks-release' \
  "https://crates.io/api/v1/crates/$0/V"        # must be 404; 200 means V is already published
git tag -l "$0-vV"                               # must print nothing
git ls-remote --tags origin "refs/tags/$0-vV"    # must print nothing
```

## 3. CHANGELOG

`crates/$0/CHANGELOG.md` must contain the heading `## [V] - <today>`, with today from
`date +%Y-%m-%d`. A missing entry, an `Unreleased` heading, or a different date all STOP — the date
is part of what the PR reviewed.

## 4. Dependency order

`claudevs-cli` depends on `claudevs`. When releasing `claudevs-cli`, read the `claudevs` version
pinned under `[workspace.dependencies]` in the root `Cargo.toml` and confirm it is on crates.io
(`curl … /api/v1/crates/claudevs/<that version>` returns 200). If it is not, STOP: release `claudevs`
first. `airsclaude` and `claudevs` have no in-workspace dependency.

## 5. Gates

```bash
cargo make dod
cargo make deny
```

For `claudevs` and `claudevs-cli` also run the plugin-checker lanes:

```bash
cargo make claudevs-check
cargo make corpus-fetch
cargo make corpus-check
```

Every command must exit 0. `corpus-check` exiting 0 only proves the corpus was not absent or short;
its per-root rows still need reading. Invoke the `corpus-sweep` skill to read them, show the author
any failing rows, and ask whether they block this release. The Lua plugin suite
(`cargo make plugins`) is not a release gate: it tests the plugins, not the published crates.

## 6. Package contents

```bash
cargo package -p $0 --list
```

The list must contain `LICENSE`, `README.md` and `CHANGELOG.md`. For `airsclaude` it must not contain
`CLAUDE.md`, anything under `.claude/`, or `src/bin/airsclaude-agent-testchild.rs`.

```bash
cargo publish -p $0 --dry-run
```

must succeed — it packages the crate and builds it from the tarball.

## 7. Publish — ask first

Show the author: crate, version, the `HEAD` commit, and that a crates.io version can be yanked but
never deleted or replaced. Ask for an explicit yes. Anything else STOPs.

```bash
cargo publish -p $0
```

If it fails, STOP and show the error. Do not tag.

## 8. Tag — ask first

The tag is annotated, named `<crate>-v<version>`, on the commit just published, and pushed by name —
never `git push --tags`, which would also push unrelated local tags. The message is `<crate> V`, a
blank line, then the body of the CHANGELOG entry for `V`. `--cleanup=verbatim` is required: git's
default cleanup strips every line starting with `#` as a comment, which deletes the entry's
`### Added` and similar headings from the tag message.

Show the author the tag name and message and ask for an explicit yes, then:

```bash
git tag -a "$0-vV" --cleanup=verbatim -F <message-file>
git push origin "$0-vV"
```

## 9. Report

One line per outcome: published `$0 V` (crates.io URL), tag `$0-vV` pushed. If the release is part
of a set, name the crate to release next — `claudevs-cli` after `claudevs`.
