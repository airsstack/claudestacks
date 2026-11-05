---
status: done
created: 2026-11-04
depends-on: [03]
built-on: bdf14ebffb48
---

# airsclaude Under the Hood Implementation Plan

**Goal:** Explain how `airsclaude` is built, for someone using it.

**Architecture:** Chapter 4 of the book, written from the explanation guides and `architecture.md`, which stay in place until plan 13. These sources carry citations and the chapters do not. All five Mermaid diagrams in the airsclaude and claudevs docs land here. Every rule for writing a page is in the root `CLAUDE.md` under `## The book`.

**Tech Stack:** Markdown, Mermaid, mdBook, rustdoc doctests through `crates/book-doctests`.

**Content authority:** `spec.md` sections 3 and 4.

---

## Files that change

```
book/src/ch04-00-airsclaude-under-the-hood.md  — modify
book/src/ch04-01-three-pillars.md              — modify
book/src/ch04-02-messages-design.md            — modify
book/src/ch04-03-agent-layers.md               — modify
```

## Order of work

### Task 1 — Write the Under the Hood chapters

**Files:**
- Modify `book/src/ch04-00-airsclaude-under-the-hood.md` — a short opening that links to the three pages below and to appendices B, C and D.
- Modify `book/src/ch04-01-three-pillars.md` — from `crates/airsclaude/docs/architecture.md` `## Three pillars`.
- Modify `book/src/ch04-02-messages-design.md` — from `architecture.md` `## The Messages API's shape`, and all seven `##` sections of `messages-sdk/explanation.md`.
- Modify `book/src/ch04-03-agent-layers.md` — from `architecture.md` `## The Agent SDK's four layers`, and all seven `##` sections of `agent-sdk/explanation.md`.

**Change:** A reader understands the two clients' design. The five Mermaid diagrams carry over: `grep -rhoE '^```mermaid' crates/airsclaude/docs/architecture.md crates/airsclaude/docs/agent-sdk/explanation.md crates/airsclaude/docs/messages-sdk/explanation.md` counts them (spec section 1). No `file:line` citation carries over. `architecture.md`'s `## Conventions worth knowing before you edit` is not written here; it moves to `crates/airsclaude/CLAUDE.md` in plan 12. `## Where to go next` is dropped. Apply `## The book` from the root `CLAUDE.md`.

**Proof:**
- `grep -c '^```mermaid' book/src/ch04-*.md` sums to 5.
- `grep -nE '\.(rs|ts|mjs|py):[0-9]+' book/src/ch04-*.md` prints nothing.
- `cargo test -p book-doctests --doc` compiles every Rust snippet on these pages.
- `book_links_resolve` passes.

**Done when:** `cargo test -p book-doctests` and `cargo make book-build` pass and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): write the airsclaude Under the Hood chapters`.

---

## Risks

- A Mermaid syntax error builds with exit 0 (spec section 10). Plan 13 names a page check for the author, since no build can catch it.
- Moving prose off its citations makes it easier to drift from the code. The appendices keep citations for the parity records; these chapters rely on the book following the code.

## Proof

- `cargo test -p book-doctests` exits 0.
- `cargo make book-build` exits 0.
- `cargo make dod` exits 0.

## Review findings

Plans 04, 05 and 06 shared one review. Fixes were checked with `cargo test -p book-doctests`: `32 passed`, `3 passed`, `46 passed`, and `cargo make dod` exit 0. The full list is in the review report for this run, kept only on this machine.

- Fixed, `ch04-02:59`, "kinds you can never send back" stated an API rule; `ContentBlockParam` is the crate's own six-variant enum. Now "kinds this crate cannot send back".
- Fixed, `ch04-02:99`, "every enum decoded from a response has an unknown arm" was false: `BatchResult` and `ServerToolName` have none. The page names both.
- Fixed, `ch04-02:159`, the concatenation sentence contradicted `accumulator.rs:250-252`. Removed.
- Fixed, `ch04-03:41`, the diagram showed protocol resting on process; the runtime imports both (`runtime/cli/runtime.rs:19-23`).
- Fixed, `ch04-03:177`, "every handler receives a `CancelSignal`". The page now names the three that do, and `Tool` takes only its input.
- Open, nits: `ch04-01:8-13` the `State` column reads as status tracking; `ch04-02:29` reads as a statement of purpose; `ch04-03:136` overstates "one new field"; `ch04-03:191` needs `async-trait` with no note for the reader; `ch04-03:237-239` is commentary on building the crate.
- Open, question: Task 1 asks for all seven sections of each explanation guide, which forces some restatement against the one-fact-one-chapter rule.

## Deviations

- 2026-11-04: The Commit line was not run during execution, which the instruction did not ask for. The author asked for the commit afterwards, with this message: `docs(repo): write the airsclaude Under the Hood chapters`.
- 2026-11-04: Code over old docs. `explanation.md` says ten enums carry an `Unknown` arm; `ch04-02` gives no count. It says `Runtime` is the only trait boundary in the tree, but `Options` holds `Arc<dyn PermissionPolicy>`, `Arc<dyn ElicitationPolicy>` and `Arc<dyn Hook>` (`options.rs:84,86,425`). `ch04-03` says "the only trait boundary between the layers".
- 2026-11-04: Cut as uncheckable from this repository: how the official SDKs treat unions and unknown payloads, that they await handlers with no timeout, that the control protocol has no version negotiation, and a sentence on Anthropic's versioning policy.
- 2026-11-04: Not checked: whether the API rejects a thinking block with an altered signature. The sentence stays on `ch04-02`, from `explanation.md`.
- 2026-11-04: The five Mermaid diagrams were read for syntax but not rendered, since this run has no browser. Plan 13 names the page check for the author.
