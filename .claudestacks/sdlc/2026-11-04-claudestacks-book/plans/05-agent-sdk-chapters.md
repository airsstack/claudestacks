---
status: done
created: 2026-11-04
depends-on: [03]
built-on: bdf14ebffb48
---

# Agent SDK chapters Implementation Plan

**Goal:** Teach the `airsclaude` Agent SDK through re-authored book chapters.

**Architecture:** Chapter 3 of the book, written from the existing Agent SDK guides, which stay in place until plan 13. Every rule for writing a page is in the root `CLAUDE.md` under `## The book`.

**Tech Stack:** Markdown, mdBook, rustdoc doctests through `crates/book-doctests`.

**Content authority:** `spec.md` sections 3 and 4.

---

## Files that change

```
book/src/ch03-00-agent-sdk.md               — modify
book/src/ch03-01-first-session.md           — modify
book/src/ch03-02-conversations.md           — modify
book/src/ch03-03-controlling-the-agent.md   — modify
book/src/ch03-04-your-code-in-the-loop.md   — modify
book/src/ch03-05-sessions.md                — modify
book/src/ch03-06-interactive.md             — modify
```

## Order of work

### Task 1 — Write the first-session chapters

**Files:**
- Modify `book/src/ch03-00-agent-sdk.md` — from `crates/airsclaude/docs/agent-sdk/how-to.md` `## Prerequisites for every recipe`.
- Modify `book/src/ch03-01-first-session.md` — from `agent-sdk/tutorial.md` `## Before you start` and Steps 1 to 3, plus `how-to.md` `## Getting output`.
- Modify `book/src/ch03-02-conversations.md` — from `tutorial.md` Steps 4 to 6, plus `how-to.md` ``## Choosing between `query` and `Client` ``.

**Change:** A reader goes from one prompt to an interrupted conversation. Rust spawning `claude` is `rust,no_run` and complete through hidden `#` lines. `claude --version` is run with its output pasted. `claude -p "hi"` and live `cargo run --example` lines are commands only, with no output. `tutorial.md`'s `## What you now know` is dropped. Apply `## The book` from the root `CLAUDE.md`.

**Proof:**
- `cargo test -p book-doctests --doc` compiles every Rust snippet on these pages.
- `book_links_resolve` passes.

**Done when:** `cargo test -p book-doctests` and `cargo make book-build` pass and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): write the Agent SDK first-session chapters`.

### Task 2 — Write the recipe chapters

**Files:**
- Modify `book/src/ch03-03-controlling-the-agent.md` — from `agent-sdk/how-to.md` `## Controlling the agent`.
- Modify `book/src/ch03-04-your-code-in-the-loop.md` — from `## Running your own code inside the loop`.
- Modify `book/src/ch03-05-sessions.md` — from `## Sessions`.
- Modify `book/src/ch03-06-interactive.md` — from `## Building something interactive`.

**Change:** The how-to recipes become chapters, each with its own small example. Links to `crates/airsclaude/examples/agent/*` become absolute GitHub URLs. Apply `## The book` from the root `CLAUDE.md`.

**Proof:**
- `cargo test -p book-doctests --doc` compiles every Rust snippet on these pages.
- `book_links_resolve` passes.
- `grep -n '\.\./examples\|\.\./\.\./examples' book/src/ch03-*.md` prints nothing.

**Done when:** `cargo test -p book-doctests` and `cargo make book-build` pass and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): write the Agent SDK recipe chapters`.

---

## Risks

- A live snippet compiles without proving what `claude` does. That is accepted in spec section 10, so these pages describe results from the crate's types only.
- A snippet needing a crate outside the dev-dependencies set in plan 03 fails to compile. Add it through `[workspace.dependencies]` if one exists there, and log it under Deviations.

## Proof

- `cargo test -p book-doctests` exits 0.
- `cargo make book-build` exits 0.
- `cargo make dod` exits 0.

## Review findings

Plans 04, 05 and 06 shared one review. Fixes were checked with `cargo test -p book-doctests`: `32 passed`, `3 passed`, `46 passed`, and `cargo make dod` exit 0. The full list is in the review report for this run, kept only on this machine.

- Fixed, `ch03-04:71`, the permission snippet set bare `allowed_tools(["Bash"])`, so the policy would never see the shell. Entry removed and the rule stated.
- Fixed, `ch03-04:166`, the `word_count` snippet turned off every prompt. It now uses `PermissionMode::Default` and names only `mcp__calc__word_count`.
- Fixed, `ch03-04:49`, also `ch03-05:82` and `ch03-06:160`: readers are told to add `async-trait`, `serde_json` and `tempfile` where snippets need them.
- Fixed, `ch03-03:40`, `allowed_tools` was described as narrowing tools. It now says pre-approving.
- Fixed, `ch03-03:92`, also `ch03-05:41,47`: an unread `_stream` was dropped at once, tearing the session down (`client.rs:346-348`). The snippets now read it.
- Fixed, `ch03-01:195`, effort through `Options::output_format` has no effect (`argv.rs:140-145`). The page points at `Options::effort`.
- Fixed, `ch03-05:160`, a stream ends at the first `Result` frame (`demux.rs:107-113`). The page says so and points at one `client.query` per prompt.
- Fixed, `ch03-06:84`, `Command::Quit` during a turn kept `run_agent` waiting. `run_turn` now returns `Result<bool, _>` and `run_agent` breaks on it.
- Fixed, `ch03-06:196`, `PermissionMode::Default` was named as what routes calls. Registering the policy does (`argv.rs:94-96`).
- Open, risk: restated instead of linked: "Options is fixed at spawn" (`ch03-01`, `ch03-03`, `ch04-03`), the four-trait table and cooperative cancellation (`ch03-04`, `ch04-03`).
- Open, nits: `ch03-01:22` imports `Message` unused; `ch03-01:116-117` promises more than Conversations shows; `ch03-03:174` says "when the stream ends" where drop is meant; `ch03-04:97` `contains("rm ")` overclaims.

## Deviations

- 2026-11-04: The Commit lines were not run during execution, which the instruction did not ask for. The author asked for the commits afterwards, with these messages: `docs(repo): write the Agent SDK first-session chapters`, `docs(repo): write the Agent SDK recipe chapters`.
- 2026-11-04: `crates/book-doctests/Cargo.toml` gained `async-trait` as a dev-dependency through `[workspace.dependencies]`, outside the set plan 03 listed, because trait impls in `ch03-04` and `ch03-06` need it.
- 2026-11-04: Risks says these pages describe results from the crate's types only. `allowed_tools` and `BypassPermissions` behaviour cannot be shown from the crate, so `ch03-03`, `ch03-04` and `ch03-06` attribute it to strings in the 2.1.318 binary, as "the binary's own message says". It was not confirmed by a live run. How `--allowed-tools` interacts with settings-file allow rules was not checked.
- 2026-11-04: Code over old docs. `how-to.md` says all four traits receive a `CancelSignal`; `Tool::call` takes only its input (`mcp/tool.rs:281`). It implies `Client::startup` cuts latency over `connect`; `connect` already spawns eagerly (`client.rs:303-320`). It names option `plugins`; the method is `plugin(PluginSpec)`. `tutorial.md` omits tokio's `time` feature, which Step 6's `tokio::time::sleep` needs; a build without it was not run. The pages follow the code.
- 2026-11-04: `tutorial.md` says the first frame is System and an interrupted turn still gets a Result frame. That is runtime behaviour not checkable offline, so `ch03-02` states no frame order.
- 2026-11-04: Example programs carry the same errors and were not changed, since no plan here names them: `05_permissions/main.rs:119-120` and `14_agent_console/main.rs:229` (policy with bare `allowed_tools`), `07_mcp_tools/main.rs:132` (`BypassPermissions`), `11_streaming_input/main.rs:82-104` (one stream across turns), `02_options/README.md:51` (the "narrow" sentence). The `allowed_tools` doc comment in `options.rs` is loose too.
