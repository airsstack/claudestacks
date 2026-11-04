---
status: done
created: 2026-11-04
depends-on: [04, 05, 06, 07, 08, 09, 10]
built-on: bdf14ebffb48
---

# README front doors Implementation Plan

**Goal:** Turn the root and crate READMEs into short front doors to the book.

**Architecture:** Runs after every chapter plan, so a fact is never removed from a README before the book holds it. Crate READMEs render on crates.io, so their book links are absolute `https://airsstack.github.io/claudestacks/...` URLs, and Rust examples in them are complete programs, following `../airsl/CLAUDE.md:152-156`. The gate's `readme_links_resolve` covers all of them.

**Tech Stack:** Markdown.

**Content authority:** `spec.md` section 8.

---

## Files that change

```
README.md                    — modify: front door for all three products
crates/airsclaude/README.md  — modify: front door, at least 3,000 bytes
crates/claudevs/README.md    — modify: front door
crates/claudevs-cli/README.md — modify: front door, install command kept
```

## Order of work

### Task 1 — Rewrite the crate READMEs

**Files:**
- Modify `crates/airsclaude/README.md` — replaces the links at `:91-101` with book links. Stays at 3,000 bytes or more, because `crates/airsclaude/examples/messages/04_caching/main.rs:19-22` uses this file four times over as a long system prompt. It is 6,273 bytes today.
- Modify `crates/claudevs/README.md` — replaces the link at `:18` with a book link.
- Modify `crates/claudevs-cli/README.md` — replaces the link at `:37` with a book link. The install command at `:12` stays exactly as it is.

**Change:** Each crate's README says what the crate is, shows one short example, and links to the book. For scale, `airsl`'s READMEs are 95 to 97 lines and `buildl`'s is 84 (spec section 8).

**Proof:**
- `readme_links_resolve` passes.
- `wc -c crates/airsclaude/README.md` prints at least 3000.
- `grep -nE 'blob/main/crates/[a-z-]+/docs' crates/*/README.md` prints nothing. Links to `examples/` at `crates/airsclaude/README.md:134-135` and `crates/claudevs/README.md:20` stay.
- `grep -c 'airsstack.github.io/claudestacks/install.sh' crates/claudevs-cli/README.md` prints 1.
- Rust examples in these READMEs are compiled by hand as complete programs before landing, since they are not doctested.

**Done when:** `cargo test -p book-doctests` passes and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): make the crate READMEs front doors to the book`.

### Task 2 — Rewrite the root README

**Files:**
- Modify `README.md` — shrinks from 209 lines. Replaces the links at `:85` and `:119` with book links, keeps the install commands at `:101`, and points the plugin suite's install detail at `ch10-00-plugins-getting-started`. Removes the sentence at `:185` saying each plugin's README lists its full contents, which plan 10 made false. Keeps `RELEASING.md` and `./LICENSE` links (`:197`, `:209`), `## Working on this repository`, `## Credits` and `## License`.

**Change:** A visitor sees the three products, how to install each, and the book.

**Proof:**
- `readme_links_resolve` passes, including `RELEASING.md` and `./LICENSE`, resolved against the repository root.
- `grep -n 'crates/[a-z-]*/docs' README.md` prints nothing.
- `grep -n 'lists its full contents' README.md` prints nothing.
- `grep -c 'airsstack.github.io/claudestacks/install.sh' README.md` prints at least 1.

**Done when:** `cargo test -p book-doctests` passes and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): make the root README a front door to the book`.

---

## Risks

- `04_caching` cannot be run here without an API key, so the 3,000-byte floor is a decision, not a measurement (spec section 8).
- Updated crate READMEs reach crates.io only with each crate's next release. Until then the published READMEs reach the book through the stubs in plan 13.

## Proof

- `cargo test -p book-doctests` exits 0.
- `cargo make dod` exits 0.

## Review findings

Plans 10 and 11 shared one review, and neither of its two blocking findings was in this plan's files. `readme_links_resolve` passed; `cargo make dod` exit 0. The reviewer compiled all three README Rust examples in a throwaway crate; the `airsclaude` Agent SDK example was compiled, not run.

- Fixed after the run, at the author's request, nit: nothing failed if the README examples drifted. `crates/book-doctests/src/pages.rs` now includes the `airsclaude` and `claudevs` READMEs as doctests. A `compile_error!` added to the `claudevs` example failed at `README.md:28`, and `cargo test -p book-doctests` printed `62 passed` once it was removed.
- Open, plan drift: Task 1 says "one short example", and `crates/airsclaude/README.md` shows two, one per client. It is 139 lines, against the 95 to 97 the plan gives for scale, and 5,579 bytes.

## Deviations

- 2026-11-04: The Commit lines were not run, because the instruction to execute did not ask for commits. Both tasks ran in one batch with plan 10's Task 2 and Task 3. No task-briefer ran, because the plan was already open in the driver.
- 2026-11-04: Code over old READMEs. Root: `claude plugin validate --strict` is not "manifest only"; "results vary run to run" for `claude plugin eval` had no support and was cut; missing `airsl` is not silent; `/discuss` is `/claudestacks:discuss`. `crates/claudevs`: the old example's relative `plugins/my-plugin` was not runnable, so the path now comes from `argv`. `crates/claudevs-cli`: "git-initialises the project" now says it creates a git repository as the default project each case runs in.
- 2026-11-04: Moved to the book, not kept: the root README's Rust quick start, SDLC picture, plugin dependency diagram and feature table; `crates/claudevs`' commands table, exit-code text and wiring sections. `crates/airsclaude/README.md` dropped warm start, resume-at-a-message, effort levels and strict-tools detail, which were not verified for this page. `crates/claudevs/README.md` gained Install and License sections. `crates/claudevs-cli/README.md` has no Rust example; it shows three commands instead.
- 2026-11-04: The comment at `crates/airsclaude/examples/messages/04_caching/main.rs` calling the README "a few hundred tokens" was not changed, since no task names it.
