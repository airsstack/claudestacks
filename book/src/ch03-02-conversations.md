# Conversations

`query` connects, sends one prompt and tears the session down when you drop the stream. When a second
prompt needs to remember the first, keep the session alive with a `Client`.

This page holds a two-turn conversation, asks the session about itself, and interrupts a turn.

## Hold a conversation

`Client::connect` takes an `Options`, starts the `claude` process and keeps it running. Each call to
`client.query` sends a prompt on that same session.

```rust,no_run
use airsclaude::agent::{Client, ContentBlock, Message, Options, PermissionMode};
use futures_util::StreamExt;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let options = Options::builder()
        .system_prompt("Answer in one short sentence. Never use a tool.")
        .permission_mode(PermissionMode::Plan)
        .max_turns(2)
        .build();

    let client = Client::connect(options).await?;

    for prompt in [
        "Pick a number between 1 and 10 and tell me what it is.",
        "Double the number you just picked.",
    ] {
        println!("> {prompt}");
        let mut stream = client.query(prompt).await?;
        while let Some(frame) = stream.next().await {
            if let Message::Assistant(assistant) = frame? {
                for block in &assistant.content {
                    if let ContentBlock::Text { text } = block {
                        println!("{text}");
                    }
                }
            }
        }
    }

    Ok(())
}
```

One process serves both turns, so the second prompt sees the first. Dropping the client shuts the
process down.

The same program, with a few extra reads, is the example
[`agent_03_session`](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/agent/03_session):

```bash
cargo run -p airsclaude --example agent_03_session
```

## Ask the session about itself

A connected client answers questions that the one-shot `query` cannot. Some of them cost nothing,
because the `claude` process describes itself when the session starts and the client keeps that answer.

```rust,no_run
# use airsclaude::agent::{Client, Options};
# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
# let client = Client::connect(Options::default()).await?;
println!("advertised models: {}", client.supported_models().len());
println!("slash commands:    {}", client.supported_commands().len());
# Ok(())
# }
```

These two calls send nothing to the process. This one does, because it asks the running session:

```rust,no_run
# use airsclaude::agent::{Client, Options};
# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
# let client = Client::connect(Options::default()).await?;
let context = client.get_context_usage().await?;
println!(
    "context: {} / {} tokens ({}%) on {}",
    context.total_tokens, context.max_tokens, context.percentage, context.model
);
# Ok(())
# }
```

`get_usage` reports subscription and rate-limit information for the session in the same way.

## Interrupt a turn

Live control is the reason to hold a client. Start a long turn, let it run for a moment, then stop it.

```rust,no_run
use std::time::Duration;

use airsclaude::agent::{Client, Message, Options};
use futures_util::StreamExt;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let client = Client::connect(Options::default()).await?;
    let mut stream = client.query("Count slowly from 1 to 500.").await?;

    tokio::time::sleep(Duration::from_secs(2)).await;
    let receipt = client.interrupt().await?;
    println!("interrupted; receipt: {receipt:?}");

    while let Some(frame) = stream.next().await {
        if let Message::Result(result) = frame? {
            println!("stopped after {} turns", result.num_turns);
        }
    }

    Ok(())
}
```

`interrupt` returns `Some` receipt when the `claude` binary reports which queued items are still
waiting after the interrupt, and `None` when it reports nothing. Keep reading the stream afterwards so
you see how the turn closed.

## Choosing between `query` and `Client`

| You want | Use |
|---|---|
| One prompt, one answer | `query(prompt, options)` |
| More than one turn on the same history | `Client::connect(options)` |
| `interrupt`, `set_model`, `mcp_status`, `get_usage` | `Client::connect(options)` |

The control methods exist only while a client is alive, because they act on a running session. Which
settings you can change mid-session, and how, is covered in
[Controlling the Agent](ch03-03-controlling-the-agent.md).
