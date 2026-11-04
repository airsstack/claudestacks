# Getting Started

`airsclaude` is an unofficial Rust SDK for Anthropic's Claude. It ships two independent
clients in one crate, and they share no code beyond a handful of value types. This chapter helps you
pick one, then installs the crate.

## Pick a client

They are unrelated. One talks HTTP to `api.anthropic.com` and wants an API key. The other starts a
binary and wants no key at all.

| | Messages API | Agent SDK |
|---|---|---|
| What it is | a typed client over `POST /v1/messages` and its companion endpoints | drives the `claude` Code CLI over its control protocol |
| Reach for it when | you want a model to answer, with tools and streaming under your control | you want an agent that reads files, runs commands and manages its own loop |
| Needs | an Anthropic API key | a `claude` binary, version 2.0.0 or newer |
| Module | `airsclaude::messages` and `airsclaude::models` | `airsclaude::agent` |
| First page | [Your First Call](ch02-01-first-call.md) | [Your First Session](ch03-01-first-session.md) |

The Messages API client does not read the key from the environment on its own. You build an `ApiKey`
and hand it to the client builder. The examples read it from the `ANTHROPIC_API_KEY` environment
variable and pass it in.

The Agent SDK looks for the `claude` binary in this order: a path you set with
`Options::path_to_executable`, then each directory on `PATH`, then `$HOME/.claude/local/claude`. A
binary older than 2.0.0 logs a warning, and `Options::require_min_version` turns that into a hard
error. The Agent SDK makes no HTTP requests itself, so it uses whatever credentials the binary already
has. If `claude -p "hi"` works in your shell, the Agent SDK works.

## Install

Add the crate to your `Cargo.toml`:

```toml
[dependencies]
airsclaude   = "0.1"
tokio        = { version = "1", features = ["macros", "rt-multi-thread"] }
futures-util = "0.3" # StreamExt, for consuming the Agent SDK's message stream
```

Both clients run on `tokio`. `futures-util` is only needed by the Agent SDK, to read its stream of
messages. The crate needs Rust 1.94 or newer and declares no Cargo features, so there is nothing to
switch on.

The Messages API and the Agent SDK sit in the same crate, so one dependency line covers both.

## API reference

The reference for every type and method is the crate's rustdoc. Run this in your own project once
`airsclaude` is a dependency:

```bash
cargo doc --open
```

This book explains how the pieces fit together and when to use them. The rustdoc lists what each
one is.

## Examples

The repository holds 25 runnable programs, each in its own directory with a `main.rs` and a
`README.md`:

- [`examples/messages/`](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/messages)
  has 11 programs for the Messages API, simplest first.
- [`examples/agent/`](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/agent)
  has 14 programs for the Agent SDK, simplest first.

They talk to a live service, so run them yourself when you have a key or a signed-in `claude`. From a
checkout of the repository, you run one by name:

```text
cargo run -p airsclaude --example agent_01_query
```

## Where to go next

- To call a model yourself, read [The Messages API](ch02-00-messages-api.md), starting with
  [Your First Call](ch02-01-first-call.md).
- To hand a task to an agent, read [The Agent SDK](ch03-00-agent-sdk.md), starting with
  [Your First Session](ch03-01-first-session.md).
- To see how the crate is built and where it differs from the official SDKs, read
  [Under the Hood](ch04-00-airsclaude-under-the-hood.md) and
  [Appendix D](appendix-04-divergences.md).
