---
status: done
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

## Review findings

Plans 10 and 11 shared one review. Checked after the fix round: `cargo test -p book-doctests` printed `32 passed`, `3 passed`, `59 passed`; `cargo make book-build` exit 0; `cargo make dod` exit 0. `cargo make plugins` exit 0 before the fixes, which touched only book pages. The fixes were not reviewed again. Line numbers are from the review, before the fixes. The full list is in the review report for this run, kept only on this machine.

- Fixed, `ch11-00:252`: "no plugin has a readable `enforcement.json`, which means the plugin's files did not reach the cache". `ls plugins/*/enforcement.json` lists only the two guideline plugins. The reviewer ran a registry holding only `claudestacks@claudestacks` with every file present and got `STOP: zero manifests loaded (delivery failure — run the parity check)`. The page now says this is expected when no guideline plugin is installed.
- Fixed, `ch13-00:116`: "fails the gate" contradicted `python-guidelines/SKILL.md:57`, "The gate cannot detect a missing baseline, so review holds its presence." The page now says so.
- Fixed after the run, at the author's request, nits, code: `ch14-00:116` the agent in link mode edits a note, but `journal-recall` has no edit tool and the main thread edits; `ch14-00:168` "how to undo the run" overstates `tar xzf`, which leaves files the curator created; `ch15-00:109` "never rewrites the file through `jq`" is stronger than `cmux-config/SKILL.md:58`; `ch15-00:116` scoped to cmux 0.64.17 and not checked on 0.65.2; `ch11-00:90` the hook also sends three "Applied as" bullets; `ch11-00:204` `**/` works anywhere in a pattern; `ch12-00:141` quoted summary line is trimmed with invented counts; `ch12-00:14` retirement note reads as change history; `ch13-00:130` omits "a logged isolation point"; `ch14-00:161` omits `AIRSSTACK_JOURNAL_MOC_MIN`, which only the curator's agent text names; `ch11-00:186`, `ch14-00:77,171` snippets fit no class; nothing tests the link at `snapshot-save/SKILL.md:78`.
- Fixed after the run, nits, facts removed from READMEs and in no page: `--force` applies to the cargo route only; pointers to `references/artifact-chain.md`, `templates.md`, `note-schema.md`; a skill's context cost before it loads; a plugin ships no enforcement hook of its own; the Zettelkasten and Building a Second Brain framing; the `explorer` inline fallback.
- Checked for the fixes above: `cargo test -p book-doctests` printed `32 passed`, `4 passed`, `62 passed`; `cargo make book-build` exit 0; `cargo make dod` exit 0. These fixes were not reviewed again, and `cargo make plugins` was not re-run because no Lua changed. `skill_links_resolve` printed `snapshot-save/SKILL.md:78: no page ch11-00-gone.md in the book` with the link broken, then passed with it restored.
- Open, plan drift: facts appearing twice despite "one home": the journal dependency (`ch10`, `ch14`), agents with no guideline (`ch11`, `ch13`), guideline plugins having no hooks (`ch10`, `ch13`), sdlc without `airsl` (`ch10`, `ch12`), per-plugin install lines (`ch10`, `ch13`, `ch14`, `ch15`).
- Rendered: every Mermaid block in the book, 21 on 18 pages, drew in headless Chrome under the `light` and `navy` themes with no error, and a deliberately broken block came back as `aria-roledescription="error"`. At the 750px page width, the first diagram in `ch09-02` had 4.4px labels, `ch11` 8.2px, `ch12` 7.3px and `ch14` 10.8px, so all four went from `flowchart LR` to `flowchart TD`. Those four were not measured again; the author opened the book under `cargo make book` and reported everything good.

## Deviations

- 2026-11-04: After the run. The skill-context fact went into `ch10` rather than `ch13` and `ch15`, so it has one home, and says "at most its description", because `skills.md:586` reads "Description always in context, full skill loads when invoked". That replaces the cut "costs no context otherwise". `AIRSSTACK_JOURNAL_MOC_MIN` and the enforcement-hook sentence, also cut below, returned in narrower wording: `grep` finds the variable only in `agents/journal-curator.md:50`, and only `plugins/claudestacks/hooks/hooks.json` names `enforce`. On cmux 0.65.2, `config doctor`, `check` and `validate` each exited 1 on an invalid file passed with `--path`, so `ch15-00` no longer scopes that to 0.64.17. The `tar` restore ran against an archive from the real `journal-backup.lua`: it printed nothing, restored `notes/a.md` and left `mocs/MOC - x.md`. `skill_links_resolve` and the README doctests are new checks no task named.

- 2026-11-04: The Commit lines were not run, because the instruction to execute did not ask for commits.
- 2026-11-04: No task-briefer ran, because the plans were already open in the driver. Coders read the task's line range directly. The two review fixes were made by the driver, not a fresh coder. Task 2 and Task 3 went to one coder, in one batch with plan 11.
- 2026-11-04: Code over old READMEs. `orchestrate` runs the reviewer once for the whole run, not per task. The skills table omitted `enforce-doctor`. Missing `airsl` is not silent: `hooks/preflight.sh` prints a notice. The Rust gate has five commands and no `cargo build`. The Rust reference list omitted `modularity`. `.index/` holds four files, not three. Journal skills are `/claudestacks-journal:journal-*`, not bare names. The journal's later-phase sections described things that already exist. Only `design` and `plan` call `explorer` and carry the inline fallback.
- 2026-11-04: Open defect found, not changed since this plan changes no hook: the dispatcher's design phase watches `<AIRSSTACK_HOME>/cc/plugins/sdd/<key>/specs|plans` (`hooks/lib/enforce.lua:208-209`). `grep -rl 'plugins/sdd' plugins` lists only `enforce.lua`, and `claudestacks-sdlc` keeps its files in `.claudestacks/sdlc/`. `ch11-00` states the path as the code defines it.
- 2026-11-04: Cut as unverifiable: `AIRSSTACK_JOURNAL_MOC_MIN`, the `permissionDecision: defer` observation, "the only sanctioned enforcement channel", the login-shell reason for the `airsl` lookup order, "costs no context otherwise", the `/config` version requirement. The cmux pages rest on the skills' 0.64.17 grounding, and this machine has 0.65.2.
- 2026-11-04: Added from the plugins and beyond the READMEs: the `airsl` lookup order, the reply rules, the `match` glob grammar, dedupe marker locations, the execute branch name, the attention hook rules, journal settings and card limits, cmux preflight and config precedence.
- 2026-11-04: Definition of Done commands in `ch13-00` are inline-code lists, not fences, and are not run; a `cargo` or `uv` fence would be Run class. `airsl --version` is the one Run snippet (`airsl 0.1.2`). `airsl run` helper commands are in prose. Credits and Attribution text stay in the READMEs.
- 2026-11-04: `claudestacks`, `claudestacks-journal` and `claudestacks-cmux` READMEs keep a one-line `airsl` install command, and `claudestacks-sdlc` keeps the `claudestacks-sdd` uninstall line, as install steps. The Task 2 red printed `plugins/claudestacks-cmux/README.md:26: no page gone.md in the book (https://airsstack.github.io/claudestacks/gone.html)`, and was undone. `cat plugins/*/README.md | wc -l` printed 191.
