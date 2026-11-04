---
status: approved
created: 2026-11-04
depends-on: [03]
built-on: bdf14ebffb48
---

# claudevs learning chapters Implementation Plan

**Goal:** Teach a plugin author to write and run `claudevs` cases through re-authored book chapters.

**Architecture:** Chapters 5 and 6 of the book, written from the CLI guides, which stay in place until plan 13. Nothing here calls a live service, so every `claudevs` command and case is really run while writing. Install commands are the one exception, classified in Task 1. Every rule for writing a page is in the root `CLAUDE.md` under `## The book`.

**Tech Stack:** Markdown, mdBook, the `claudevs` binary from this checkout, YAML and Lua case files.

**Content authority:** `spec.md` sections 3 and 4.

---

## Files that change

```
book/src/ch05-00-claudevs-getting-started.md  — modify
book/src/ch05-01-installation.md              — modify
book/src/ch05-02-first-plugin.md              — modify
book/src/ch05-03-first-case.md                — modify
book/src/ch05-04-running-the-gate.md          — modify
book/src/ch06-00-writing-cases.md             — modify
book/src/ch06-01-hook-decisions.md            — modify
book/src/ch06-02-scripts-and-flows.md         — modify
book/src/ch06-03-cases-in-lua.md              — modify
book/src/ch06-04-native-suites.md             — modify
book/src/ch06-05-selecting-and-skips.md       — modify
```

## Order of work

### Task 1 — Write the Getting Started chapters

**Files:**
- Modify `book/src/ch05-00-claudevs-getting-started.md` — from `crates/claudevs/docs/README.md` `## Start here` and `## Examples`. Drops `## Cross-cutting` and `## The four modes, and which file is which`.
- Modify `book/src/ch05-01-installation.md` — from `cli/tutorial.md` `## Install claudevs`. Keeps the install command `curl -LsSf https://airsstack.github.io/claudestacks/install.sh | sh`, and the two `cargo install` commands from `cli/tutorial.md:17,23`. All three are shown as commands only, with no output: they reach a service or replace the machine's installed binary, so they are not run.
- Modify `book/src/ch05-02-first-plugin.md` — from `## The plugin`, `## Ask what is missing`, `## Put the plugin in a marketplace`.
- Modify `book/src/ch05-03-first-case.md` — from `## Write your first case`, `## Run it`.
- Modify `book/src/ch05-04-running-the-gate.md` — from `## Run the gate`, `## Break the hook`, `## Fix it and test the installed copy`. `## Where to go next` is dropped.

**Change:** A reader goes from nothing to a passing `claudevs check`, then breaks and fixes a hook. Every other transcript is pasted unedited from a real run of the checkout's binary: `cargo build -p claudevs-cli`, with `target/debug` first on `PATH`, in a scratch plugin in a neutral directory such as `/tmp/claudevs-demo`, so no output holds the machine's home directory. Apply `## The book` from the root `CLAUDE.md`.

**Proof:**
- The tutorial's plugin and case are built exactly as the pages say, and each command prints what the page pastes.
- `book_links_resolve` and `cargo test -p book-doctests --doc` pass.

**Done when:** `cargo test -p book-doctests` and `cargo make book-build` pass and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): write the claudevs Getting Started chapters`.

### Task 2 — Write the Writing Cases chapters

**Files:**
- Modify `book/src/ch06-00-writing-cases.md` — a short opening that links to the pages below.
- Modify `book/src/ch06-01-hook-decisions.md` — from `cli/how-to.md` `## Assert a hook's decision`, `## Assert context a hook adds`, `## Assert a hook stays silent`.
- Modify `book/src/ch06-02-scripts-and-flows.md` — from `## Test a script with its environment`, `## Test a multi-step flow in a project`.
- Modify `book/src/ch06-03-cases-in-lua.md` — from `## Generate cases in Lua`, `## Script a case with t`, `## Convert a YAML case to Lua`.
- Modify `book/src/ch06-04-native-suites.md` — from `## Run the plugin's own test command`.
- Modify `book/src/ch06-05-selecting-and-skips.md` — from `## Run only some cases`, `## Read a skip`, and `cli/explanation.md` `## A skip is an environment gap`.

**Change:** Each recipe becomes a chapter with its own small example. YAML and Lua cases pass `claudevs test` in a scratch plugin before they land. `claudevs.toml` loads in the case run. Links to `crates/claudevs/examples/*` become absolute GitHub URLs. Apply `## The book` from the root `CLAUDE.md`.

**Proof:**
- Every YAML and Lua case on these pages passes `claudevs test` in the scratch plugin, with pasted output from that run.
- `book_links_resolve` and `cargo test -p book-doctests --doc` pass.
- `grep -n '\.\./examples\|\.\./\.\./examples' book/src/ch05-*.md book/src/ch06-*.md` prints nothing.

**Done when:** `cargo test -p book-doctests` and `cargo make book-build` pass and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): write the claudevs Writing Cases chapters`.

---

## Risks

- `claudevs` needs `git` on `PATH`, and `claude` for the `validate` stage (`crates/claudevs/docs/README.md`). Pasted `validate` output depends on the local `claude` version, so pages do not state a version as a requirement beyond what the source says.

## Proof

- `cargo test -p book-doctests` exits 0.
- `cargo make book-build` exits 0.
- `cargo make dod` exits 0.
