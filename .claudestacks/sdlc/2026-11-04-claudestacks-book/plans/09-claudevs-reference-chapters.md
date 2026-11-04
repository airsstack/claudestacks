---
status: approved
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
