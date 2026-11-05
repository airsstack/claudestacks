---
status: done
created: 2026-11-04
depends-on: [11]
built-on: bdf14ebffb48
---

# Repository guidance Implementation Plan

**Goal:** Point the repository's agent guidance at the book.

**Architecture:** `CLAUDE.md` files are what future sessions load, so stale paths there mislead every one of them. `## The book` already landed in plan 01. This plan repoints what is left, and moves `airsclaude`'s maintainer conventions here, because the book is for readers using the crate.

**Tech Stack:** Markdown.

**Content authority:** `spec.md` sections 6 and 8.

---

## Files that change

```
crates/airsclaude/CLAUDE.md  — modify: Docs section, plus the moved conventions
CLAUDE.md                    — modify: doc pointers, member list, Commands
plugins/claudestacks-guideline-rust/skills/rust-guidelines/references/workspace.md — modify: quoted member list
```

## Order of work

### Task 1 — Update the airsclaude guidance

**Files:**
- Modify `crates/airsclaude/CLAUDE.md` — rewrite `## Docs` at `:128-133` around the book. Repoint `:133` and `:137` to `book/src/appendix-02-messages-parity.md`, `book/src/appendix-03-agent-parity.md` and `book/src/appendix-04-divergences.md`. Its mention of `docs/architecture.md` points to `book/src/ch04-01-three-pillars.md`. Add `## Conventions worth knowing before you edit`, moved from `crates/airsclaude/docs/architecture.md:120`. The banned-vocabulary rule at `:143-178` now governs `book/` as well as READMEs and rustdoc, and says parity updates land in the appendices.

**Change:** Someone editing the crate is sent to the right files and keeps the conventions.

**Proof:**
- `grep -n 'docs/' crates/airsclaude/CLAUDE.md` prints no path under the old docs tree.
- `grep -c 'Conventions worth knowing before you edit' crates/airsclaude/CLAUDE.md` prints 1.
- `cargo package -p airsclaude --list` does not list `CLAUDE.md`, so nothing changes for the published crate.

**Done when:** those commands pass and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): point the airsclaude guidance at the book`.

### Task 2 — Update the root guidance

**Files:**
- Modify `plugins/claudestacks-guideline-rust/skills/rust-guidelines/references/workspace.md:16` — its quoted `members` list gains `crates/book-doctests`. The plugin's version bump in plan 10 carries this.
- Modify `CLAUDE.md` — repoint `:124-125` to `book/src/ch04-01-three-pillars.md` and the book's URL. `:116` says four members, and the Project list gains `crates/book-doctests`, unpublished, existing only to gate the book. `## Commands` gains `cargo make book` and `cargo make book-build`, the `book` CI job, what `pages.yml` now publishes, and the two gate facts a future editor needs: `create-missing = false`, and that `crates/book-doctests` must wire every new page. The `pages.yml` description saying it publishes only the pointer is corrected. The sentence at `:182`, that `ci.yml` carries three jobs the gate excludes, counts the new `book` job.

**Change:** Root guidance matches the repository.

**Proof:**
- `grep -n 'crates/[a-z-]*/docs' CLAUDE.md` prints nothing.
- `grep -n 'three members' CLAUDE.md` prints nothing.
- `grep -c 'book-doctests' CLAUDE.md` prints at least 2.
- `grep -c 'crates/book-doctests' plugins/claudestacks-guideline-rust/skills/rust-guidelines/references/workspace.md` prints at least 1.

**Done when:** those commands pass and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): point the root guidance at the book`.

---

## Risks

- Line numbers here are from the commit this plan was written against. Earlier plans in the set edit `CLAUDE.md`, so find these lines by their text.

## Proof

- `grep -rn 'crates/[a-z-]*/docs' CLAUDE.md crates/airsclaude/CLAUDE.md` prints nothing.
- `cargo make dod` exits 0.

## Review findings

Plans 12 and 13 shared one review: no blocking findings, so no fix round. All greps above printed what the plan names; `cargo make dod` exit 0.

All below were fixed after the run, at the author's request, and carry no second review. `cargo make dod` exit 0, 0 `^warning` lines.

- Fixed, risk: `crates/airsclaude/CLAUDE.md` said each parity row carries a `file:line`, and the reviewer counted 117 of 238 rows in appendix B and 102 of 167 in appendix C with none, headers and legend rows included. It now says many rows do, but not all.
- Fixed, risk: the moved conventions said every newtype has its own `Invalid*` error, and `MaxTokens` has none (`crates/airsclaude/src/types/numeric.rs`). They now name the exception.
- Fixed, risk: the moved conventions said every server-decoded enum carries an `Unknown` arm. `BatchResult` now has one (decided without asking, at the author's "fix all"), seen failing first with `error[E0599]: no variant or associated item named Unknown`, then 19 passed. `Role` and `ServerToolName` stay closed, because `Role` is shared with requests; the claim is narrowed to open-ended enums and names both, in `CLAUDE.md`, `ch04-02`, and appendices B and D. Appendix B's "all ten" and "Ten enums" were stale and are gone.
- Fixed, from a second review before the 0.2.0 release, two blocking. `Cargo.lock` still said 0.1.0 (`cargo metadata --locked` exit 101); it now says 0.2.0. Corrupt results (`"x"`, `null`, `42`, `{}`, `{"type":42}`) decoded as `Ok(Unknown(..))`; `Unknown` now requires an object with a string `type`, and `result_that_is_not_an_object_with_a_string_type_is_an_error` failed on `"x"` first, then 39 passed. Also fixed: the `results.rs` doc comment claiming the stream ends after any error, tests for the tail error and for carrying on past bad rows, and appendix B §5.1 (`ErrorType`, the `Serialize` claim, a table row for `BatchResult`).
- Open, design call kept: a `succeeded` row whose message does not decode arrives as `Unknown` with its raw JSON, and a caller using `_ => {}` loses it silently. Documented in the arm's rustdoc and the changelog.
- Open, nits outside this work: a blank `\r\n` line yields `JsonLines`; `BatchResult` has no `PartialEq`; a decoded `custom_id` may be empty. A throwaway scan of `src/messages`, `src/models`, `src/types` and `src/error.rs` listed 15 decoded enums with an arm before this change.
- Fixed, nits: the root pointer now gives the pillar map and internal structure separately; the "before adding a surface" pointer names `ch04-02` and `ch04-03`; `src/lib.rs:41` lost its line number; the file's earlier restatements of the moved conventions are removed.

## Deviations

- 2026-11-05: The Commit lines were not run, because the instruction to execute did not ask for commits. Both tasks ran in the driver in one batch, without a task-briefer or coder, because the plan was already open and the edits were prose.
- 2026-11-05: The conventions' last link became a path, `book/src/appendix-04-divergences.md`, since the old relative link would land on a stub. The rest of the section moved unchanged.
- 2026-11-05: `cargo package -p airsclaude --list` was run with `--allow-dirty`, since the tree held this plan's uncommitted edits.
