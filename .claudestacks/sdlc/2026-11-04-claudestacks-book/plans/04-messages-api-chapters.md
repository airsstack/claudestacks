---
status: done
created: 2026-11-04
depends-on: [03]
built-on: bdf14ebffb48
---

# Messages API chapters Implementation Plan

**Goal:** Teach the `airsclaude` Messages API through re-authored book chapters.

**Architecture:** Chapters 1 and 2 of the book, written from the existing Messages API guides, which stay in place until plan 13. Every rule for writing a page is in the root `CLAUDE.md` under `## The book`.

**Tech Stack:** Markdown, mdBook, rustdoc doctests through `crates/book-doctests`.

**Content authority:** `spec.md` sections 3 and 4.

---

## Files that change

```
book/src/introduction.md                        — modify: which product do you need
book/src/ch01-00-airsclaude-getting-started.md  — modify
book/src/ch02-00-messages-api.md                — modify
book/src/ch02-01-first-call.md                  — modify
book/src/ch02-02-streaming.md                   — modify
book/src/ch02-03-tools.md                       — modify
book/src/ch02-04-cost-and-latency.md            — modify
book/src/ch02-05-richer-input.md                — modify
book/src/ch02-06-structured-results.md          — modify
book/src/ch02-07-models.md                      — modify
book/src/ch02-08-building-larger.md             — modify
```

## Order of work

### Task 1 — Write the book's front page and airsclaude's

**Files:**
- Modify `book/src/introduction.md` — says what `airsclaude`, `claudevs` and the plugin suite each are, and links to each part's first page.
- Modify `book/src/ch01-00-airsclaude-getting-started.md` — from `crates/airsclaude/docs/README.md` `## Start here` and `## Examples`. Drops `## Cross-cutting` and `## The four modes, and which file is which`.

**Change:** A reader can pick a product, then pick one of the two `airsclaude` clients and install the crate. Apply `## The book` from the root `CLAUDE.md`.

**Proof:**
- `book_links_resolve` passes with the new links.
- `grep -nE 'Diátaxis|tutorial|how-to' book/src/introduction.md book/src/ch01-00-airsclaude-getting-started.md` prints nothing, because the old layout's terms mean nothing here.

**Done when:** `cargo test -p book-doctests` and `cargo make book-build` pass and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): write the book introduction and airsclaude start`.

### Task 2 — Write the first-call chapters

**Files:**
- Modify `book/src/ch02-00-messages-api.md` — from `crates/airsclaude/docs/messages-sdk/how-to.md` `## Prerequisites for every recipe`.
- Modify `book/src/ch02-01-first-call.md` — from `messages-sdk/tutorial.md` `## Before you start` and Steps 1 to 3, plus `how-to.md` `## Getting a reply`.
- Modify `book/src/ch02-02-streaming.md` — from `tutorial.md` Step 4.
- Modify `book/src/ch02-03-tools.md` — from `tutorial.md` Step 5.

**Change:** A reader goes from a client to a streamed tool call. Every API-calling snippet is `rust,no_run` and complete through hidden `#` lines, since the old snippets are fragments (`E0728`, `E0425`, spec section 5). `cargo run --example` lines that call the API are commands only, with no output. `tutorial.md`'s `## What you now know` is dropped. Apply `## The book` from the root `CLAUDE.md`.

**Proof:**
- `cargo test -p book-doctests --doc` compiles every `rust,no_run` snippet on these pages.
- `book_links_resolve` passes.

**Done when:** `cargo test -p book-doctests` and `cargo make book-build` pass and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): write the Messages API first-call chapters`.

### Task 3 — Write the recipe chapters

**Files:**
- Modify `book/src/ch02-04-cost-and-latency.md` — from `messages-sdk/how-to.md` `## Controlling cost and latency`.
- Modify `book/src/ch02-05-richer-input.md` — from `## Sending richer input`.
- Modify `book/src/ch02-06-structured-results.md` — from `## Getting structured results`.
- Modify `book/src/ch02-07-models.md` — from `## Discovering what a model supports`.
- Modify `book/src/ch02-08-building-larger.md` — from `## Building something larger` and `## Swapping the HTTP transport`.

**Change:** The how-to recipes become chapters, each with its own small example. Links to `crates/airsclaude/examples/messages/*` become absolute GitHub URLs. Apply `## The book` from the root `CLAUDE.md`.

**Proof:**
- `cargo test -p book-doctests --doc` compiles every Rust snippet on these pages.
- `book_links_resolve` passes.
- `grep -n '\.\./examples\|\.\./\.\./examples' book/src/ch02-*.md` prints nothing.

**Done when:** `cargo test -p book-doctests` and `cargo make book-build` pass and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): write the Messages API recipe chapters`.

---

## Risks

- A live snippet compiles without proving what the API returns. That is accepted in spec section 10, so these pages describe results from the crate's types only.
- A snippet needing a crate outside the dev-dependencies set in plan 03 fails to compile. Add it through `[workspace.dependencies]` if one exists there, and log it under Deviations.

## Proof

- `cargo test -p book-doctests` exits 0.
- `cargo make book-build` exits 0.
- `cargo make dod` exits 0.

## Review findings

Plans 04, 05 and 06 shared one review. Fixes were checked with `cargo test -p book-doctests`: `32 passed`, `3 passed`, `46 passed`, and `cargo make dod` exit 0. The full list is in the review report for this run, kept only on this machine.

- Fixed, `ch01-00:3` and `introduction.md:27`, "client for Anthropic's official SDKs" read as a wrapper around them. Both now follow `crates/airsclaude/Cargo.toml:3`.
- Fixed, `ch02-00:25`, "one example program covers each" was false: no example under `crates/airsclaude/examples/messages` calls `models()`. Sentence cut.
- Fixed, `ch02-04:8`, a link promising client setup landed on a page with none. Line cut.
- Fixed, `ch02-08:16`, "the tool loop from Tools" pointed at a page with one round trip. It now links `07_agentic_tool_loop`.
- Open, risk: facts told more than once instead of linked: the choice between clients (`ch01-00`, `introduction`, `ch03-00`, `ch04-01`), binary lookup and version gate (`ch01-00`, `ch03-00`), type-state builder rules (`ch02-01`, `ch04-02`), the two-enum split (`ch02-03`, `ch04-02`), transport generics (`ch02-08`, `ch04-02`).
- Open, risk: `ch02-07:56-58` names `has_more` and `last_id` under "Paging", but `list(&self)` takes no cursor.
- Open, question: `toml` dependency stanzas fit none of the four snippet classes in `## The book`.
- Open, nits: `ch01-00:53` `cargo doc --open` has no pasted output; `ch01-00:72` a command in a `text` fence; `ch02-06:4` "without checking its shape first" is unconditional; `ch02-01:117` and `ch02-03:150` repeat one sentence; `ship`, `currently` near the banned vocabulary.
- Open, drift: `ch02-04:161` ("usually finishes within a minute") and `ch02-03:147` describe service behaviour rather than the crate's types.

## Deviations

- 2026-11-04: The Commit lines were not run during execution, which the instruction did not ask for. The author asked for the commits afterwards, with these messages: `docs(repo): write the book introduction and airsclaude start`, `docs(repo): write the Messages API first-call chapters`, `docs(repo): write the Messages API recipe chapters`.
- 2026-11-04: Code over old docs. `README.md` says the Messages API needs `ANTHROPIC_API_KEY`; the crate reads no such variable, and only the examples do. `README.md` says `claude` must be 2.0.0 or newer; `discovery.rs:63-86` only warns unless `Options::require_min_version` is set. The pages follow the code.
- 2026-11-04: Code over old docs. `how-to.md` describes a PDF recipe, but its example sends plain text; `DocumentSource` has four forms and the page names them. `how-to.md` omits the `structured-outputs-2025-11-13` header the example sends; the page includes it. `tutorial.md` calls `usage` "what you were billed for"; the page says token counts.
- 2026-11-04: `streaming.rs` delivers an API error as `Ok(StreamEvent::Error)`, which the old stream loop swallows. `ch02-02` says so and covers `MessageStream::collect()`, which the old docs omit.
- 2026-11-04: `base64` and `reqwest` are not dev-dependencies, so the image snippet takes a hidden `encoded` string and `ReqwestTransport::from_client` appears in prose only.
- 2026-11-04: Book snippets use `ModelId::claude_sonnet_5()` as `tutorial.md` does, while the example programs use `claude_sonnet_4_5()`. Both exist. The difference is left in place.
- 2026-11-04: Not checked against the API: the ~1024-token cache minimum, which comes from the `04_caching` example's comment. `cargo doc --open` in a reader's project was not run.
