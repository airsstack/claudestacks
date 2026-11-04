---
status: done
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

## Review findings

Plans 07, 08 and 09 shared one review. Checked after the fix round: `cargo test -p book-doctests` printed `32 passed`, `3 passed`, `59 passed`; `cargo make book-build` exit 0; `cargo make dod` exit 0. The fixes were not reviewed again. Each was reproduced against `target/debug/claudevs` first. Line numbers below are from the review, before the fixes.

- Fixed, `ch05-01:49`: a fixture without `.gitinit` is not a git repository, so `git status` in it gave `exit: expected 0, got 128`.
- Fixed, `ch06-00:34`: a scripted case's `t.script` runs in the plugin directory unless given `cwd`, and `leaked.txt` reached the next case.
- Fixed, `ch06-01:197`: `output: none` still passes on plain stdout and `{"systemMessage":"hi"}`.
- Fixed, `ch06-03:94,121`: `reply.emitted` was false with stdout and stderr both written.
- Fixed, `ch06-05:109`: with `TMPDIR=/nonexistent/x`, a plugin with a case exits 2, and one with no cases prints `1 stage run, 0 failed, 3 skipped` and exits 0.
- Fixed, `ch06-05:112`: `check` with invalid `hooks.json` and a hook case, or a missing fixture, prints one line and exits 2.
- Open, risk: `ch06-00:31` and `ch06-03:84`, "starting with `test_`" drops `.lua`. `tests/test_foo.sh` gave `no case files found`, exit 2.
- Open, risk: `ch06-02:147`, "one committed file, `file.txt`". `Cargo.toml` is committed too.
- Open, nits: `ch05-00:36` "worked through" where the page only links; `ch06-00:5` softens the same overclaim fixed at `ch09-01:30`; `ch06-00:35` "each recipe is also a directory"; `ch06-04:134` the example asserts different text; `ch06-05:29` the paste drops the binary's leading blank line; `ch06-05:96`, also `:74` and `ch07-01:32`, call a missing case file a gap in the machine; `ch05-00:18` and `ch05-01:52` both explain `claude` being optional; `ch06-02:81-83` repeats `ch06-01:197-199`.

## Deviations

- 2026-11-04: The Commit lines were not run during execution, which the instruction did not ask for. The author asked for the commits afterwards, with these messages: `docs(repo): write the claudevs Getting Started chapters`, `docs(repo): write the claudevs Writing Cases chapters`.
- 2026-11-04: Task 1 and Task 2 ran in one batch with plans 07 and 09, each in its own scratch directory. The coders ran only `cargo test -p book-doctests`; `cargo make book-build` and `cargo make dod` ran once for the batch.
- 2026-11-04: Code over old docs. `doctor` prints paths as typed, not `…/my-plugin`. `validate` under `claude` 2.1.318 prints a long "Plugin directory checks" block, pasted unedited in `ch05-04`, which says those lines change with `claude`'s version. An uncreatable temp directory is not always a skip, as the review fix above records.
- 2026-11-04: Added outside the sections the plan names, all from real runs: a second `doctor` run in `ch05-02`; a no-`claude` run in `ch05-04`; `claudevs --version` in `ch05-01`; `## See a native suite fail` in `ch06-04`; `--case` facts in `ch06-05`: a filter matching nothing exits 0, and `--case` does not filter native suites.
- 2026-11-04: `cli/tutorial.md`'s "Installed package claudevs-cli v0.1.0" line was dropped, because the install commands are not run. `ch05-04` keeps one closing paragraph of links where the plan drops `## Where to go next`.
- 2026-11-04: `ch06-00` carries a Mermaid flowchart. Failure transcripts carrying a random temp path are described in prose on `ch06-*`, and pasted unedited on `ch05-04`, with a note that the path differs per run.
- 2026-11-04: Claims taken from the source and not run for this page: hooks spawn as `sh -c`, and "0 native suites" counts test commands a plugin declares for itself.
