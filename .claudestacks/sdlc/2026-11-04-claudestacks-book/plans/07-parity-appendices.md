---
status: approved
created: 2026-11-04
depends-on: [03]
built-on: bdf14ebffb48
---

# Parity appendices Implementation Plan

**Goal:** Carry the parity tables and the divergence list into the book without changing their content.

**Architecture:** Appendices B, C and D are copies of the three records with citations intact, the named exception to the book's no-citation rule. Exactly two kinds of edit are allowed, both listed below. The source files stay in place until plan 13.

**Tech Stack:** Markdown, mdBook, rustdoc doctests through `crates/book-doctests`.

**Content authority:** `spec.md` section 6.

---

## Files that change

```
book/src/appendix-00.md                  — modify: what the appendix holds
book/src/appendix-02-messages-parity.md  — modify: copy of messages-sdk/feature-parity.md
book/src/appendix-03-agent-parity.md     — modify: copy of agent-sdk/feature-parity.md
book/src/appendix-04-divergences.md      — modify: copy of divergences.md
```

## Order of work

### Task 1 — Copy the three records

**Files:**
- Modify `book/src/appendix-02-messages-parity.md` — whole of `crates/airsclaude/docs/messages-sdk/feature-parity.md`.
- Modify `book/src/appendix-03-agent-parity.md` — whole of `crates/airsclaude/docs/agent-sdk/feature-parity.md`.
- Modify `book/src/appendix-04-divergences.md` — whole of `crates/airsclaude/docs/divergences.md`.
- Modify `book/src/appendix-00.md` — says the appendix holds the claudevs CLI reference and the airsclaude parity records, and why B, C and D carry `file:line` citations while chapters do not.

**Change:** Only these edits differ from the sources.

Edit 1, the 17 relative links:
```text
11 (../divergences.md)                → appendix-04-divergences.md
 2 (../architecture.md)               → ch04-01-three-pillars.md
 2 (../agent-sdk/feature-parity.md)   → appendix-03-agent-parity.md
 1 (messages-sdk/feature-parity.md)   → appendix-02-messages-parity.md
 1 (agent-sdk/feature-parity.md)      → appendix-03-agent-parity.md
```
Edit 2, the bare fence at `crates/airsclaude/docs/messages-sdk/feature-parity.md:732` gets the label `text`, since it fails the gate with `unknown start of token: \u{2192}` otherwise.

**Proof:**
- `diff crates/airsclaude/docs/messages-sdk/feature-parity.md book/src/appendix-02-messages-parity.md` prints only link lines and the one fence. Same for the other two pairs, which show only link lines.
- `grep -cE '[a-z_/]+\.(rs|ts|mjs|py):[0-9]+'` gives 198 for appendix B, 81 for C and 15 for D, the source counts (spec section 6).
- `grep -cE '^\|' book/src/appendix-02-messages-parity.md` prints 238 and appendix C prints 167.
- `cargo test -p book-doctests --doc` passes with these pages wired, and `book_links_resolve` passes.

**Done when:** `cargo test -p book-doctests` and `cargo make book-build` pass and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): add the parity and divergence appendices`.

---

## Risks

- From plan 13 on, the appendices are the only copy. `crates/airsclaude/CLAUDE.md` is repointed in plan 12 so parity updates land here rather than at the old paths.
- The citations resolve against `crates/airsclaude/src/`, so they read as text rather than links, as they do today.

## Proof

- `cargo test -p book-doctests` exits 0.
- `cargo make book-build` exits 0.
- `cargo make dod` exits 0.
