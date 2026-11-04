---
status: approved
created: 2026-11-04
depends-on: [03]
built-on: bdf14ebffb48
---

# Plugin suite chapters Implementation Plan

**Goal:** Move the plugin suite's documentation out of its READMEs into the book.

**Architecture:** Chapters 10 to 15, written from `plugins/*/README.md` and the root README's install section. Each plugin README then shrinks to a front door. Installed copies only refresh when a plugin's version changes (`https://code.claude.com/docs/en/plugins/loading.md:298-302`, spec section 8), so all six get a patch bump. Every rule for writing a page is in the root `CLAUDE.md` under `## The book`.

**Tech Stack:** Markdown, mdBook, plugin manifests, the `airsl` runtime.

**Content authority:** `spec.md` sections 3, 4 and 8.

---

## Files that change

```
book/src/ch10-00-plugins-getting-started.md             — modify
book/src/ch11-00-claudestacks-plugin.md                 — modify
book/src/ch12-00-sdlc-plugin.md                         — modify
book/src/ch13-00-guideline-plugins.md                   — modify
book/src/ch14-00-journal-plugin.md                      — modify
book/src/ch15-00-cmux-plugin.md                         — modify
plugins/claudestacks/README.md                          — modify: front door
plugins/claudestacks-sdlc/README.md                     — modify: front door
plugins/claudestacks-guideline-rust/README.md           — modify: front door
plugins/claudestacks-guideline-python/README.md         — modify: front door
plugins/claudestacks-journal/README.md                  — modify: front door
plugins/claudestacks-cmux/README.md                     — modify: front door
plugins/claudestacks/skills/snapshot-save/SKILL.md      — modify: repoint line 78
plugins/*/.claude-plugin/plugin.json                    — modify: patch bump, six files
```

## Order of work

### Task 1 — Write the plugin chapters

**Files:**
- Modify `book/src/ch10-00-plugins-getting-started.md` — from root `README.md` `## The plugin suite`, `### What each plugin needs` and `### Install`. The ASCII picture at `README.md:151-159` becomes Mermaid. The flow at `README.md:137-144` is not repeated, and this page links to `ch12-00-sdlc-plugin` for it. The sentence at `README.md:185` saying each README lists its full contents is not carried over.
- Modify `book/src/ch11-00-claudestacks-plugin.md` — from `plugins/claudestacks/README.md`, including `## Project snapshots` and `## Enforcement dispatcher`.
- Modify `book/src/ch12-00-sdlc-plugin.md` — from `plugins/claudestacks-sdlc/README.md`. The ASCII flow at `:21-29` becomes Mermaid, and the file tree at `:64-74` stays in a `text` fence.
- Modify `book/src/ch13-00-guideline-plugins.md` — from both guideline READMEs.
- Modify `book/src/ch14-00-journal-plugin.md` — from `plugins/claudestacks-journal/README.md`, organised by what each feature does. Dated section names such as `## Phase 1 — Foundation (this release)` are not carried over.
- Modify `book/src/ch15-00-cmux-plugin.md` — from `plugins/claudestacks-cmux/README.md`.

**Change:** The suite's documentation has one home. `/plugin` and `/claudestacks-*:*` commands and `cmux` are commands only, with no output. The sources' other bare fences get labels, because the gate compiles them as Rust otherwise. Apply `## The book` from the root `CLAUDE.md`.

**Proof:**
- `cargo test -p book-doctests --doc` passes with these pages, including every fence that was bare in the source.
- `book_links_resolve` passes.
- `grep -nE 'Phase [0-9]' book/src/ch14-00-journal-plugin.md` prints nothing.
- `grep -c '^```mermaid' book/src/ch10-00-plugins-getting-started.md book/src/ch12-00-sdlc-plugin.md` prints 1 for each.

**Done when:** `cargo test -p book-doctests` and `cargo make book-build` pass and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): write the plugin suite chapters`.

### Task 2 — Shrink the plugin READMEs

**Files:**
- Modify the six `plugins/*/README.md` — what the plugin is, how to install it, and one absolute link to its chapter: `https://airsstack.github.io/claudestacks/ch11-00-claudestacks-plugin.html` and the matching pages. Each keeps whichever of `## Attribution` and `## License` it has today, gaining none. Both: `claudestacks`, `claudestacks-sdlc`. License only: `claudestacks-cmux`, `claudestacks-guideline-rust`, `claudestacks-guideline-python`. Neither: `claudestacks-journal`.
- Modify `plugins/claudestacks/skills/snapshot-save/SKILL.md:78` — repoint from the plugin `README.md` to the absolute URL `https://airsstack.github.io/claudestacks/ch11-00-claudestacks-plugin.html`, which now describes the snapshot key. An installed copy has no `book/` to resolve a path against.

**Change:** Beyond what the plugin is and how to install it, no fact lives in both a README and the book.

**Proof:**
- `readme_links_resolve` passes. Red: point one README at `https://airsstack.github.io/claudestacks/gone.html` and see the file, line and target named. Undo it.
- `cat plugins/*/README.md | wc -l` prints at most 240, down from 594. The number is a limit set here, not a measurement.
- `grep -c '^## Attribution' plugins/claudestacks/README.md plugins/claudestacks-sdlc/README.md` prints 1 for both.

**Done when:** `cargo test -p book-doctests` passes and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): shrink the plugin READMEs to front doors`.

### Task 3 — Bump the plugin versions

**Files:**
- Modify `plugins/claudestacks/.claude-plugin/plugin.json:3` — `0.2.3` to `0.2.4`.
- Modify `plugins/claudestacks-sdlc/.claude-plugin/plugin.json:3` — `0.4.1` to `0.4.2`.
- Modify `plugins/claudestacks-guideline-rust/.claude-plugin/plugin.json:3` — `0.1.5` to `0.1.6`.
- Modify `plugins/claudestacks-guideline-python/.claude-plugin/plugin.json:3` — `0.1.0` to `0.1.1`.
- Modify `plugins/claudestacks-journal/.claude-plugin/plugin.json:3` — `0.1.4` to `0.1.5`.
- Modify `plugins/claudestacks-cmux/.claude-plugin/plugin.json:3` — `0.1.1` to `0.1.2`.

**Change:** An installed copy picks up the short README on its next update. Nothing else pins these versions: the spec's search printed nothing outside `plugin.json` (spec section 8).

**Proof:**
- `grep -h '"version"' plugins/*/.claude-plugin/plugin.json` prints the six new versions.
- `cargo make plugins` exits 0.

**Done when:** `cargo make plugins` passes and the Definition of Done is green (`cargo make dod`). Commit `chore(repo): bump the plugins for their short READMEs`.

---

## Risks

- An installed plugin's README no longer holds the full reference offline. That was the author's decision.
- `cargo make plugins` needs the `airsl` binary installed (`cargo make install-airsl`, root `CLAUDE.md`).
- A plugin hook edit in the same window would ride on these bumps. This plan changes no hook.

## Proof

- `cargo test -p book-doctests` exits 0.
- `cargo make book-build` exits 0.
- `cargo make plugins` exits 0.
- `cargo make dod` exits 0.
