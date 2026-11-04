---
status: approved
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
