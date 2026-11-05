---
status: done
created: 2026-11-04
depends-on: [03]
built-on: bdf14ebffb48
---

# claudevs reference chapters Implementation Plan

**Goal:** Document the `claudevs` gate, engine and CLI reference in re-authored book chapters.

**Architecture:** Chapters 7, 8, 9 and appendix A, written from the remaining guides, which stay in place until plan 13. Engine snippets move from `crates/claudevs/docs/engine/` into pages, and from this plan on both copies compile until plan 13 retires the old one. Every rule for writing a page is in the root `CLAUDE.md` under `## The book`.

**Tech Stack:** Markdown, mdBook, rustdoc doctests through `crates/book-doctests`, the `claudevs` binary from this checkout.

**Content authority:** `spec.md` sections 3, 4 and 5.

---

## Files that change

```
book/src/ch07-00-check-gate.md               — modify
book/src/ch07-01-stages.md                   — modify
book/src/ch07-02-wiring.md                   — modify
book/src/ch07-03-ci.md                       — modify
book/src/ch08-00-embedding.md                — modify
book/src/ch08-01-first-suite.md              — modify
book/src/ch08-02-recipes.md                  — modify
book/src/ch09-00-claudevs-under-the-hood.md  — modify
book/src/ch09-01-design.md                   — modify
book/src/ch09-02-engine.md                   — modify
book/src/appendix-01-claudevs-cli.md         — modify
```

## Order of work

### Task 1 — Write the check Gate chapters

**Files:**
- Modify `book/src/ch07-00-check-gate.md` — a short opening that links to the pages below.
- Modify `book/src/ch07-01-stages.md` — from `crates/claudevs/docs/cli/explanation.md` `## Every stage runs`, `## What the installed layout catches`, `## Why validation is handed to claude`.
- Modify `book/src/ch07-02-wiring.md` — from `## Why a matcher claudevs cannot evaluate is a warning`.
- Modify `book/src/ch07-03-ci.md` — from `cli/how-to.md` `## Use JSON in CI`, `## Fail on manifest warnings`.

**Change:** A reader knows what `claudevs check` runs and how to use it in CI. JSON reports and transcripts are pasted from real runs of the checkout's binary over `crates/claudevs/examples/`. Apply `## The book` from the root `CLAUDE.md`.

**Proof:**
- The commands on these pages print what the pages paste.
- `book_links_resolve` and `cargo test -p book-doctests --doc` pass.

**Done when:** `cargo test -p book-doctests` and `cargo make book-build` pass and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): write the claudevs check Gate chapters`.

### Task 2 — Write the Embedding chapters

**Files:**
- Modify `book/src/ch08-00-embedding.md` — a short opening that links to the pages below.
- Modify `book/src/ch08-01-first-suite.md` — all sections of `crates/claudevs/docs/engine/tutorial.md` except `## Where to go next`.
- Modify `book/src/ch08-02-recipes.md` — all nine sections of `engine/how-to.md`.

**Change:** Engine snippets run offline, so they are plain `rust` fences that actually execute. Each snippet with a relative path starts with the hidden line `# std::env::set_current_dir(concat!(env!("CARGO_MANIFEST_DIR"), "/../claudevs")).unwrap();`. Without it, doctests from this member fail with `Io { operation: "resolve plugin dir", path: "examples/01_hook_decision", ... NotFound }`; with it, all nine how-to snippets pass (spec section 5). Apply `## The book` from the root `CLAUDE.md`.

**Proof:**
- `cargo test -p book-doctests --doc` reports these pages' snippets `ok`, not `compile`, because they run.
- Red: remove the hidden line from one snippet and see that `NotFound` failure. Restore it.
- `git status --short crates/claudevs/examples` prints nothing after the run.

**Done when:** `cargo test -p book-doctests` and `cargo make book-build` pass and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): write the claudevs Embedding chapters`.

### Task 3 — Write Under the Hood and the CLI reference

**Files:**
- Modify `book/src/ch09-00-claudevs-under-the-hood.md` — a short opening that links to the pages below.
- Modify `book/src/ch09-01-design.md` — from `cli/explanation.md` `## What sits between validate and a live session`, `## Cases assert meaning, not mechanics`, `## Why cases cover fewer events than hooks.json may use`.
- Modify `book/src/ch09-02-engine.md` — from `crates/claudevs/docs/architecture.md` `## Two crates`, `## Module map`, `## From a plugin directory to a report`, and all nine sections of `engine/explanation.md`. `## Module map` says what each module offers someone embedding the engine. `## Where to read next` is dropped. The ASCII flow diagrams at `architecture.md:44-58` and `:62-67` become Mermaid, as does `engine/explanation.md:95-109` unless it repeats the first of them, in which case the page keeps one.
- Modify `book/src/appendix-01-claudevs-cli.md` — all fifteen sections of `cli/reference.md`.

**Change:** The design and reference pages exist. Facts in the reference are re-checked against `claudevs --help`, a real `--json` report and `claudevs doctor` from the checkout's binary, and the book follows the code where they differ. Apply `## The book` from the root `CLAUDE.md`.

**Proof:**
- The two explanation snippets in `engine/explanation.md` compile as part of `ch09-02-engine.md` under `cargo test -p book-doctests --doc`.
- `grep -c '^## ' book/src/appendix-01-claudevs-cli.md` is at least 15.
- `grep -c '^```mermaid' book/src/ch09-02-engine.md` is at least 2.
- `book_links_resolve` passes.

**Done when:** `cargo test -p book-doctests` and `cargo make book-build` pass and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): write the claudevs Under the Hood chapters and reference`.

---

## Risks

- A doctest that writes under `crates/claudevs/examples` would dirty the tree. The Task 2 `git status` check catches it.
- A Mermaid syntax error builds with exit 0 (spec section 10). Plan 13 lists every Mermaid page for the author's page check.
- The CLI reference is the longest re-authored page, so it is the likeliest place for a claim to disagree with the code. Such a disagreement goes in `## Deviations`.

## Proof

- `cargo test -p book-doctests` exits 0.
- `cargo make book-build` exits 0.
- `cargo make dod` exits 0.

## Review findings

Plans 07, 08 and 09 shared one review. Checked after the fix round: `cargo test -p book-doctests` printed `32 passed`, `3 passed`, `59 passed`; `cargo make book-build` exit 0; `cargo make dod` exit 0; `git status --short crates/claudevs/examples` printed nothing. The fixes were not reviewed again. Each was reproduced against `target/debug/claudevs` first. Line numbers below are from the review, before the fixes.

- Fixed, `appendix-01:47`: `test --case nomatch` still runs native suites: `0 passed, 1 failed (0 cases, 1 native suites)`, exit 1.
- Fixed, `appendix-01:161`: see the `output: none` fix in plan 08.
- Fixed, `appendix-01:261`: a `.gitinit` commit is always empty: `git ls-files` printed nothing and `git status --short` printed `?? README.md`.
- Fixed, `appendix-01:319`: with a malformed `plugin.json`, `test` exits 0 and only `test --installed` fails.
- Fixed, `ch07-00:4`, `ch07-01:8`: `check` does not always run all four stages. The rule is stated once in `ch07-01`.
- Fixed, `ch08-01:8`: see the `.gitinit` fix in plan 08.
- Fixed, `ch09-01:30`: `expect.exit` and `stderr_contains` exist, so "never" became "can say … instead of".
- Fixed, `ch09-02:126`: see the `t.script` fix in plan 08.
- Open, risk: `ch07-02:38`, "any other character makes the whole value a regular expression" omits `*` and the empty string. Matcher `*` gave `0 errors, 0 warnings` and the case ran.
- Open, risk: `appendix-01:108`, the `test` exit 2 list omits a missing fixture and an argv that cannot spawn.
- Open, risk: `appendix-01:256`, "one tracked and committed file named `file.txt`". `git ls-files` printed `Cargo.toml` and `file.txt`.
- Open, risk: `ch08-02:71`, "`Failed` for an unreadable `plugin.json`" holds only for `test --installed`.
- Open, nits: `appendix-01:102` `<stem>_test.lua` omits `-` becoming `_`; `appendix-01:110-111` doctor and migrate also exit 2 through clap; `appendix-01:175,249` message templates in `text` fences fit no snippet class literally; `appendix-01:343` misses the separator-only matcher; `appendix-01:433`, also `ch07-03:20` and `ch08-02:74`, `detail` is not the same text the human report shows; `ch08-00:20` `cargo doc --open` has no pasted output; `ch08-01:14` the `[dependencies]` block fits no class; `ch08-01:100` "surface"; `ch08-02:10` no subcommand prints a `WiringReport`; `ch09-02:13` `run_migrate` writes files itself.

## Deviations

- 2026-11-04: The Commit lines were not run during execution, which the instruction did not ask for. The author asked for the commits afterwards, with these messages: `docs(repo): write the claudevs check Gate chapters`, `docs(repo): write the claudevs Embedding chapters`, `docs(repo): write the claudevs Under the Hood chapters and reference`.
- 2026-11-04: Task 1, Task 2 and Task 3 ran in one batch with plans 07 and 08. The coders ran only `cargo test -p book-doctests`; `cargo make book-build` and `cargo make dod` ran once for the batch.
- 2026-11-04: Code over old docs. `cli/reference.md` says `test` skips when there is no marketplace or the temp project cannot be created. With cases present and no marketplace, `check` printed `ok test` and `skip test --installed`, so that condition is on `test --installed` only. `t.project()` is the default project, not an empty one: `ls -A` printed `.git Cargo.toml file.txt`. A relative `t.json` path reads from the working directory, not the plugin directory. Summary lines pluralise (`1 error, 3 warnings`). Flow step numbers start at 0. `--json` carries native `output` for every suite, while the human report shows it only on a non-zero exit. A matcher `claudevs` cannot evaluate warns at `wiring` and also fails `test`, with `no PreToolUse handler matches`.
- 2026-11-04: Exit 2 causes in `appendix-01`, added from runs: missing `hooks.json` with a hook case, `hooks.json` that is not JSON, a bad Lua case name, an unknown `claudevs.toml` key, an uncreatable temp directory.
- 2026-11-04: In `ch07-*`, reports are narrowed with `jq` from real runs, because `validate` prints absolute paths and long text that varies with `claude`. The one full human report is the run with `claude` hidden. `08_installed_broken` keeps its random temp paths, unedited, with a note. The `--strict` demo uses a copy of `01_hook_decision` without `author`, because `07_wiring_broken` showed no change under `--strict`.
- 2026-11-04: No GitHub Actions YAML in `ch07-03`, since it fits no snippet class and cannot run here; the page uses a `bash` script that was run. `ch07-02` gains `## What the stage checks`, a section the plan does not name, from real runs.
- 2026-11-04: `engine/explanation.md:95-109` repeats `architecture.md:44-58`, so `ch09-02` keeps that diagram once, plus the command-wrapper diagram. The module map leaves out the private `docs_doctests`. `ch07-01` carries one more Mermaid flowchart. A green build does not show that any of them draws; the reviewer read all five `claudevs` Mermaid blocks and reported they parse, but nothing rendered them.
- 2026-11-04: In `appendix-01`, the matcher message "is not JSON: REASON" comes from the source and was not read verbatim from a run. `ch08-02` keeps prose from `how-to.md` (probe order, `Skipped` and `Failed` conditions, `Error` variants) that was not re-derived beyond what its snippets assert. `check`, `doctor` and wiring recipes paste no output, because it depends on whether `claude` is on `PATH`. `ch08-00` and `ch08-01` add `cargo doc -p claudevs --no-deps --open` and a `claudevs = "0.1"` dependency block; the `--open` form was not run, only `--no-deps`.
