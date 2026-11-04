# airsclaude

Unofficial Rust SDK for Anthropic's Claude. Not affiliated with Anthropic.

The crate holds two independent clients. They share almost no code, and which one you want depends on
what you are building:

| | Messages API | Agent SDK |
|---|---|---|
| What it is | a typed client over `POST /v1/messages` and its companion endpoints | drives the `claude` Code CLI as a subprocess over its control protocol |
| Reach for it when | you want a model to answer, with tools and streaming under your control | you want an agent that reads files, runs commands, and manages its own loop |
| Needs | `ANTHROPIC_API_KEY` | a `claude` binary 2.0.0+ on `PATH`, and no API key |
| Module | `airsclaude::messages`, `airsclaude::models` | `airsclaude::agent` |

A third pillar, Managed Agents (`/v1/agents`, `/v1/sessions`), has no code in the crate.

## Install

```toml
[dependencies]
airsclaude   = "0.1"
tokio        = { version = "1", features = ["macros", "rt-multi-thread"] }
futures-util = "0.3" # StreamExt, for consuming the Agent SDK's message stream
```

`tokio` drives both examples below. `futures-util` is needed only by the Agent SDK one. The crate
needs Rust 1.94 or newer and declares no Cargo features.

## Example: Messages API

A complete program that asks one question and prints the text of the reply. It reads the key from the
environment and passes it to the client builder.

```rust,no_run
use airsclaude::messages::ContentBlock;
use airsclaude::prelude::*;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let client = Client::builder()?
        .api_key(ApiKey::new(std::env::var("ANTHROPIC_API_KEY")?)?)
        .build()?;

    let req = MessageRequest::builder()
        .model(ModelId::claude_sonnet_5())
        .max_tokens(MaxTokens::new(1024))
        .add_user_text("Say hi.")
        .build();

    let msg = client.messages().create(req).await?;

    for block in &msg.content {
        if let ContentBlock::Text(t) = block {
            println!("{}", t.text);
        }
    }
    Ok(())
}
```

## Example: Agent SDK

A complete program that hands a prompt to the `claude` binary and prints what the agent says. It
needs no API key, because the binary uses the credentials it already holds.

```rust,no_run
use airsclaude::agent::{ContentBlock, Message, Options, query};
use futures_util::StreamExt;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut stream = query("Say hi in one short sentence.", Options::default()).await?;

    while let Some(frame) = stream.next().await {
        match frame? {
            Message::Assistant(a) => {
                for block in &a.content {
                    if let ContentBlock::Text { text } = block {
                        println!("{text}");
                    }
                }
            }
            Message::Result(r) => println!("session {}", r.session_id.as_str()),
            _ => {}
        }
    }
    Ok(())
}
```

## What the crate offers

**Messages API.** `POST /v1/messages` with streaming and an accumulator; custom tools and all four
`tool_choice` forms; prompt caching with both TTL tiers; extended thinking; structured output; image
and PDF input with citations; token counting; the Message Batches API; and `GET /v1/models` with its
capability payload.

**Agent SDK.** A one-shot `query` and a stateful `Client`; the 45 fields of `Options`; in-process MCP
tools written in Rust; hooks; six permission modes and a `PermissionPolicy` callback; MCP
elicitation; programmatic subagents; session continue, resume and fork; on-disk session inspection;
and 22 mid-session control and introspection operations.

Neither client is at complete parity with the official SDKs. The parity appendices grade each feature
against the shipped Python and TypeScript artifacts and name every gap.

## Documentation

The book covers both clients, one task at a time. Start with
[Getting Started](https://airsstack.github.io/claudestacks/ch01-00-airsclaude-getting-started.html),
which helps you pick a client.

- [The Messages API](https://airsstack.github.io/claudestacks/ch02-00-messages-api.html), from
  [Your First Call](https://airsstack.github.io/claudestacks/ch02-01-first-call.html).
- [The Agent SDK](https://airsstack.github.io/claudestacks/ch03-00-agent-sdk.html), from
  [Your First Session](https://airsstack.github.io/claudestacks/ch03-01-first-session.html).
- [Under the Hood](https://airsstack.github.io/claudestacks/ch04-00-airsclaude-under-the-hood.html)
  explains how the crate is built.
- [Messages API Parity](https://airsstack.github.io/claudestacks/appendix-02-messages-parity.html),
  [Agent SDK Parity](https://airsstack.github.io/claudestacks/appendix-03-agent-parity.html) and
  [Deliberate Divergences](https://airsstack.github.io/claudestacks/appendix-04-divergences.html) are
  the reference tables.

The API reference is the rustdoc: `cargo doc --open` in a project that depends on the crate.

## Examples

The repository holds 25 runnable programs, each in its own directory with a `README.md`:

```bash
ANTHROPIC_API_KEY=sk-ant-... cargo run -p airsclaude --example 01_hello
cargo run -p airsclaude --example agent_01_query
```

- [`examples/messages/`](https://github.com/airsstack/claudestacks/blob/main/crates/airsclaude/examples/messages/README.md) has 11 programs, simplest first.
- [`examples/agent/`](https://github.com/airsstack/claudestacks/blob/main/crates/airsclaude/examples/agent/README.md) has 14 programs, simplest first.

## License

Apache-2.0. See the `LICENSE` file.
