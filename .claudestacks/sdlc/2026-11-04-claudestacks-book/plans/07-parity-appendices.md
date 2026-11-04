---
status: done
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

## Review findings

Plans 07, 08 and 09 shared one review. Checked after the fix round: `cargo test -p book-doctests` printed `32 passed`, `3 passed`, `59 passed`; `cargo make book-build` exit 0; `cargo make dod` exit 0. The full list is in the review report for this run, kept only on this machine.

- Clean: `diff` against the three sources adds 13, 3 and 2 lines (17 links and one fence label). Citation counts printed 198, 81, 15; table rows printed 238 and 167. All match the plan.
- Open, risk: `appendix-00.md:13` gives `models/capabilities.rs` as an example of a file name and line number, with no line number. "Each row says where the behaviour lives" overstates: the reviewer counted 91 of 212 table rows in B and 88 of 153 in C with no `:<line>`.
- Open, nit: `appendix-00.md:19`, "look it up in B, C or D" covers `airsclaude` only.

## Deviations

- 2026-11-04: The Commit line was not run during execution, which the instruction did not ask for. The author asked for the commits afterwards, with this message: `docs(repo): add the parity and divergence appendices`.
- 2026-11-04: The coder reported that the appendices are not wired into the doctest crate, based on a case-sensitive `grep`. That was wrong: `crates/book-doctests/src/pages.rs` includes them. Removing the `text` label at `appendix-02-messages-parity.md:732` failed `pages::Appendix02MessagesParity (line 732)` with `unknown start of token: \u{2192}`. The label was restored.
