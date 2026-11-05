# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Scoped to `crates/airsclaude`. The workspace root `CLAUDE.md` still applies — this file adds only what
is specific to this crate.

## Commands

The Definition of Done is owned by the `claudestacks-guideline-rust` skill; while working inside this
crate, run it scoped with `-p airsclaude` instead of `--workspace`:

```bash
cargo fmt --all -- --check
cargo clippy -p airsclaude --all-targets --all-features -- -D warnings
RUSTDOCFLAGS="-D warnings" cargo doc -p airsclaude --all-features --no-deps
cargo test  -p airsclaude --all-targets --all-features
cargo test  -p airsclaude --all-features --doc
```

Use the `--workspace` form before a release or when the change reaches `src/transport/`.

Narrower runs while iterating:

```bash
cargo test -p airsclaude --test messages_streaming                  # one integration file
cargo test -p airsclaude --test messages_streaming -- name_of_test  # one test in it
cargo test -p airsclaude --lib agent::process::                     # unit tests under one module path
```

A changed `insta` snapshot fails the test and writes a `.snap.new` beside the `.snap` in
`tests/snapshots/`. Read the diff, then replace the `.snap` with it. (`cargo-insta` is not installed
here, so `cargo insta review` is unavailable unless you install it.)

Two test targets are deliberately outside the gate:

- `tests/agent_e2e.rs` is `#[ignore]`d *and* env-guarded. It needs a real backend binary:
  `AIRSCLAUDE_AGENT_E2E=1 cargo test -p airsclaude --all-features --test agent_e2e -- --ignored`
- `tests/compile_fail/*.stderr` are `trybuild` expectations. Regenerate with
  `TRYBUILD=overwrite cargo test -p airsclaude --test builder_compile` and read the diff — these files
  pin the type-state builder's error messages, so a changed message is a user-visible change.

Examples are registered by name in `Cargo.toml`, so they run from anywhere in the workspace. Messages
API examples need `ANTHROPIC_API_KEY`; agent examples need a `claude` binary 2.0.0+ on `PATH` and no
API key at all, because the Agent SDK drives that binary rather than calling the API.

```bash
ANTHROPIC_API_KEY=sk-... cargo run -p airsclaude --example 01_hello
cargo run -p airsclaude --example agent_01_query
```

Adding an example means adding an `[[example]]` block with an explicit `path` — every example lives in
its own directory with a `main.rs` and a `README.md`, which Cargo's autodiscovery does not find.

## Architecture

Three parity pillars, three module trees, no coupling between them:

| Pillar | Module | Talks to | State |
|---|---|---|---|
| Messages API | `src/messages/`, `src/models/` | Anthropic HTTP API via `crate::transport` | implemented |
| Agent SDK | `src/agent/` | the `claude` binary as a subprocess | implemented |
| Managed Agents | — | `/v1/agents`, `/v1/sessions`, … | not started |

The Managed Agents pillar has no code yet (`grep -rniE "managed_?agent|/v1/agents" src/` returns
nothing, while the same grep for `/v1/messages` hits `src/messages/resource.rs`).

### Messages API side

`Client<T = ReqwestTransport>` (`src/client.rs`) is generic over the HTTP transport per the
static-dispatch policy, holds an `Arc<ClientInner<T>>` so cloning is cheap, and hands out resource
handles: `client.messages()` → `MessagesResource`, `client.models()` → `ModelsResource`, and
`client.messages().batches()` → `BatchesResource`. Construction goes through a type-state builder
(`src/builder.rs`, `Missing`/`Present`) so `build()` does not exist until the API key is set.

### Agent SDK side

Four layers, each blind to the one above it — this is the main thing to preserve when editing:

```
agent::client::Client<R: Runtime>   stateful session + live-control ops
        │
agent::runtime  ── port.rs: the Runtime trait (the single seam)
        │         ├── cli/   CliRuntime: discovery, argv, handshake, demux, dispatch
        │         └── mock.rs  MockRuntime (cfg(test)) — replays turns, records control calls
        │
agent::protocol                     JSON frames + line codec; protocol-aware, transport-blind
        │
agent::process                      spawn/supervise/teardown; knows nothing about `claude` or JSONL
```

`agent::process` manages *any* child process — keep binary- and protocol-specific knowledge out of it.
`agent::protocol` turns lines into frames and back and never touches a process. Everything above the
`Runtime` trait is generic over it, which is why session and client logic is testable with no backend
binary present.

`agent::Options` is the only configuration argument, fixed at spawn time and shared by the one-shot
`query()` and `Client::connect`. Mid-session equivalents are methods on `Client`.

### Cross-cutting

`src/prelude.rs` is the one-import path for callers and is export-only.

## Testing setup

- **`src/test_support.rs`** — `mockall` fake of the `crate::transport::Transport` contract, consumer-owned.
- **`tests/messages_*.rs`, `tests/models.rs`, `tests/transport_reqwest.rs`** — `wiremock` against a
  local HTTP server.
- **`tests/agent_process.rs`, `tests/agent_capabilities.rs`** — drive the real
  `src/bin/airsclaude-agent-testchild.rs` helper binary via `CARGO_BIN_EXE_airsclaude-agent-testchild`. Its
  flags (`--ignore-eof`, `--spam-stderr`, `--exit-code`, `--fork-grandchild`, `--init-caps`) exist to
  provoke specific subprocess failure modes; extend the child rather than mocking around it.
- **`tests/messages_snapshot.rs`** — `insta` snapshots of serialized request JSON in `tests/snapshots/`.
- **`tests/builder_compile.rs`** — `trybuild` fixtures locking the type-state contracts.

## Docs

This crate's documentation is the first part of the book at the repository root, in `book/src/` and
published at <https://airsstack.github.io/claudestacks/>. Its pages run from
`ch01-00-airsclaude-getting-started.md` to `ch04-03-agent-layers.md`: Chapter 2 is the Messages API,
Chapter 3 the Agent SDK, and Chapter 4 the design behind them. The root `CLAUDE.md` holds the rules for
writing a page.

Read `book/src/ch04-01-three-pillars.md` and the chapter for your client,
`book/src/ch04-02-messages-design.md` or `book/src/ch04-03-agent-layers.md`, before adding a surface.
Read `book/src/appendix-04-divergences.md` before "fixing" behaviour that looks wrong — several
departures from the official SDKs are deliberate and pinned by test.

`book/src/appendix-02-messages-parity.md` and `book/src/appendix-03-agent-parity.md` are the parity
reference: what the official Python and TypeScript SDKs do, what this crate does, and where they differ.
They are graded against shipped artifacts (`sdk.d.ts`/`sdk.mjs`, the Python sdist, the
`@anthropic-ai/sdk` tarball, the live binary), and many rows carry a `file:line`, but not all. **They
still lag the code between revisions.** When a doc and the source disagree, the source wins — and say so in the reply
rather than repeating the table.

## Conventions worth knowing before you edit

**`#![forbid(unsafe_code)]`** in `src/lib.rs`. Not a lint — the crate will not compile with unsafe in
it.

**`mod.rs` and `lib.rs` are tables of contents.** Module docs, `mod` declarations, `pub use`. No
implementation. Every implementation lives in a sibling file named after the thing it defines.

**Values are parsed at construction, not validated at use.** `src/types/` holds newtypes — `ApiKey`,
`BaseUrl`, `ModelId`, `Temperature`, `BetaHeader` — each with its own `Invalid*` error. `MaxTokens` has
none, because every `u32` is valid. Once you hold the type, the invariant is proven. A new domain value
belongs here, not as a bare `String` or `u32` parameter.

**The workspace declares no Cargo features.** Every module compiles unconditionally, so
`--all-features` is identical to the default build. The flag stays in the gate commands for the day
that changes, not because it does anything today. The `mockall` transport double lives in
`src/test_support.rs` behind `#[cfg(test)]`, not behind a feature.

**Unit tests are colocated.** Each logic-bearing `src/*.rs` carries its own `#[cfg(test)] mod tests`.
Integration tests under `tests/` complement those; they do not replace them.

**Forward compatibility is a contract, not a nicety.** `agent::Message` is exhaustive but carries
`Message::Other`, so a newer `claude` release emitting an unmodelled frame cannot fail a turn. On the
Messages side every open-ended enum decoded from a response carries a payload-retaining `Unknown` arm
for the same reason. Some are closed on purpose: an unrecognised `Role` fails the message's decode, and
closed enums inside a content block, such as `ServerToolName` and `CacheControl`, land the block in
`ContentBlock::Unknown`. Preserve this
property in any new frame or response enum — see `book/src/appendix-04-divergences.md` for why the
payload is retained rather than discarded.

### Docs describe the software, never the work that produced it

Every page under `book/`, every `README.md`, and every rustdoc comment is written for someone using
this crate. They have no view into how it gets built and no reason to want one. Development vocabulary
in a user-facing document is noise at best; at worst the reader tries to decode it and concludes the
crate is half-finished.

**Never appears in user-facing docs:**

| Banned | Why | Write instead |
|---|---|---|
| phases, phase 1/2/…, workstreams, WS A/1, epics, milestones, sprints | internal sequencing | nothing — describe what exists |
| tasks, task items, backlog, TODO | a work queue | nothing, or name the gap plainly |
| plans, action plans, specs, RFCs, roadmaps | planning artifacts | nothing |
| "delivered", "landed", "shipped", "closed", "now supports", "no longer fails" | change history | plain present tense: "carries", "returns", "supports" |
| "prior revision", "this revision", "as of \<date\>", "used to", "was wrong" | doc changelog | state the current fact and stop |
| commit SHAs as status markers | internal history | omit; `file:line` is the useful citation |
| "planned", "coming soon", "not yet", "future work" | promises | a plain ❌ or a gap entry |

The exceptions are literal, and narrow: a domain term that happens to collide (`PermissionMode::Plan`,
`taskBudget`, an async *task*, a *closed* enum), a verbatim quote from another project's source, and
the pinned upstream versions a parity table is graded against.

**Two rules follow from this.**

Present tense, not narrative. A parity table records what is true now, not what changed and when. If a
row would read "delivered in X" it should read "present" — and if it is at parity it is simply ✅ with
a `file:line`. Parity updates land in the book's appendices.

A gap is not a plan. Something the official SDKs do and this crate does not is a fact about the
current state, so record it, rank it by how likely a caller is to hit it, and stop. Do not attach an
intention, an owner, an estimate, or an ordering.

The same rule governs source comments: `references/doc-comment-discipline.md` in the
`claudestacks-guideline-rust` skill bans internal planning paths, phase identifiers, workflow vocabulary,
and AI/agent names from rustdoc and `//` comments. This is that rule extended to `book/`.
