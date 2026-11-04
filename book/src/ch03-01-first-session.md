# Your First Session

This page sends one prompt to an agent and reads what comes back. You need the `claude` binary from
[the chapter introduction](ch03-00-agent-sdk.md) and a Rust project.

Add the crate, an async runtime and a stream helper to the project:

```toml
[dependencies]
airsclaude = "0.2"
tokio = { version = "1", features = ["macros", "rt-multi-thread", "time"] }
futures-util = "0.3"
serde_json = "1"
```

## Send a prompt

`query` takes a prompt and an `Options`. It starts the `claude` binary and returns a stream of
messages. Here is the smallest complete program:

```rust,no_run
use airsclaude::agent::{Message, Options, query};
use futures_util::StreamExt;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut stream = query("Say hi in one short sentence.", Options::default()).await?;

    while let Some(frame) = stream.next().await {
        println!("{:?}", frame?);
    }

    Ok(())
}
```

Running it starts a real session, so the page shows no output. The stream carries a few kinds of
frame: system frames, assistant frames with the agent's output, and one `Result` frame that ends the
turn.

The stream owns the session. When you drop it, the `claude` process is shut down.

## Read the frames you care about

Printing `{:?}` shows that the pipe works. To get the text out, match on `Message`. It has one variant
per kind of frame, so the compiler stops you from forgetting a case.

```rust,no_run
use airsclaude::agent::{ContentBlock, Message, Options, query};
use futures_util::StreamExt;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut stream = query("Say hi in one short sentence.", Options::default()).await?;

    while let Some(frame) = stream.next().await {
        match frame? {
            Message::Assistant(assistant) => {
                for block in &assistant.content {
                    if let ContentBlock::Text { text } = block {
                        println!("{text}");
                    }
                }
            }
            Message::Result(result) => {
                println!("---");
                println!("session:  {}", result.session_id.as_str());
                println!("turns:    {}", result.num_turns);
                if let Some(cost) = result.total_cost_usd {
                    println!("cost:     ${cost:.6}");
                }
            }
            Message::User(_) | Message::System(_) | Message::StreamEvent(_) => {}
            Message::Other(raw) => println!("(unmodelled frame: {raw})"),
        }
    }

    Ok(())
}
```

The program prints the reply, then the session id, the number of turns and the cost.

Keep the `Message::Other` arm. It holds any frame this release of the crate does not model, so a newer
`claude` that adds a frame kind does not break your program.

The same loop is the example
[`agent_01_query`](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/agent/01_query):

```bash
cargo run -p airsclaude --example agent_01_query
```

## Configure the session

`Options` is the one configuration argument. Build it and pass it where `Options::default()` was.

```rust,no_run
# use airsclaude::agent::{Options, PermissionMode, query};
# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
let options = Options::builder()
    .system_prompt("Answer in one short sentence. Never use a tool.")
    .permission_mode(PermissionMode::Plan)
    .max_turns(2)
    .build();

let mut stream = query("What is 2 + 2?", options).await?;
# let _ = &mut stream;
# Ok(())
# }
```

This gives the agent a system prompt, puts it in plan mode so it does not execute anything, and caps it
at two turns. Everything on `Options` is fixed when the process starts. Changing a setting after that
is the job of the control methods on a connected client, described in
[Conversations](ch03-02-conversations.md). The rest of `Options` is in
[Controlling the Agent](ch03-03-controlling-the-agent.md).

## Stream tokens as they are produced

By default the stream delivers whole messages: one `Assistant` frame for each model turn. Turn on
partial messages and the stream also carries `Message::StreamEvent` frames, so you can print text while
the model writes it.

```rust,no_run
# use airsclaude::agent::{Message, Options, query};
# use futures_util::StreamExt;
# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
let options = Options::builder().include_partial_messages(true).build();
let mut stream = query("Explain what a Rust lifetime is.", options).await?;

while let Some(frame) = stream.next().await {
    if let Message::StreamEvent(event) = frame? {
        // `event.event` is the raw JSON payload of the partial message.
        println!("{}", event.event);
    }
}
# Ok(())
# }
```

The whole message still arrives when the turn completes. The example
[`agent_04_partial_streaming`](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/agent/04_partial_streaming)
extracts the text from each event, and also shows `Options::stderr`, a callback that receives what the
`claude` process writes to its standard error.

## Get the answer as JSON

To receive data instead of prose, give the agent a JSON Schema. The parsed document arrives on
`ResultMessage::structured_output`. `max_budget_usd` caps what the run may spend.

```rust,no_run
use airsclaude::agent::types::BudgetUsd;
use airsclaude::agent::{Message, Options, PermissionMode, query};
use futures_util::StreamExt;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let schema = serde_json::json!({
        "type": "object",
        "properties": {
            "language": { "type": "string" },
            "first_released": { "type": "integer" }
        },
        "required": ["language", "first_released"],
        "additionalProperties": false
    });

    let options = Options::builder()
        .system_prompt("Answer only through the required output schema.")
        .permission_mode(PermissionMode::Plan)
        .output_schema(schema)
        .max_budget_usd(BudgetUsd::new(0.50)?)
        .max_turns(3)
        .build();

    let mut stream = query("Describe the Rust programming language.", options).await?;

    while let Some(frame) = stream.next().await {
        if let Message::Result(result) = frame? {
            match &result.structured_output {
                Some(value) => println!("{}", serde_json::to_string_pretty(value)?),
                None => println!("no structured output; errors: {:?}", result.errors),
            }
        }
    }

    Ok(())
}
```

`structured_output` is `None` when no schema was requested or the run ended before one was produced.
To set the reasoning effort, use `Options::effort`. The effort field inside an `OutputConfig` passed to
`Options::output_format` does not change the agent's effort. The example
[`agent_08_structured_output`](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/agent/08_structured_output)
handles each way a turn can end.

One prompt answers one question. To ask a second question that remembers the first, keep the session
open with a `Client`, as [Conversations](ch03-02-conversations.md) shows.
