# Your First Call

By the end of this page you will have built a client, sent a request to Claude, and read the reply and
the details that come with it.

## Before you start

You need an Anthropic API key in your environment:

```bash
export ANTHROPIC_API_KEY=sk-ant-...
```

You also need the crate and an async runtime:

```toml
[dependencies]
airsclaude = "0.2"
tokio = { version = "1", features = ["macros", "rt-multi-thread"] }
```

## Build a client

One import line covers most call sites.

```rust,no_run
use airsclaude::prelude::*;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let api_key = ApiKey::new(std::env::var("ANTHROPIC_API_KEY")?)?;
    let client = Client::builder()?.api_key(api_key).build()?;

    println!("client ready");
    Ok(())
}
```

`ApiKey::new` validates the key, so once you hold an `ApiKey` it is well formed. `build()` exists only
after `api_key` has been called. Delete that line and the program does not compile, instead of
failing at runtime.

## Send a request

Build the request, send it, print the reply. The snippets from here on hide the lines you have already
seen, such as the client setup; the full program is
[`01_hello`](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/messages/01_hello).

```rust,no_run
# use airsclaude::prelude::*;
use airsclaude::messages::ContentBlock;

# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
# let api_key = ApiKey::new(std::env::var("ANTHROPIC_API_KEY")?)?;
# let client = Client::builder()?.api_key(api_key).build()?;
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
# Ok(())
# }
```

`MessageRequest::builder()` follows the same rule as the client builder. `model` and `max_tokens` are
required, and `build()` does not exist until both are set.

A reply is a list of content blocks, not a string. A plain answer arrives as one or more
`ContentBlock::Text` blocks, which is why the loop matches on the variant.

## Read the rest of the response

The text is not the only thing that comes back. Add these lines after the loop.

```rust,no_run
# use airsclaude::prelude::*;
# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
# let api_key = ApiKey::new(std::env::var("ANTHROPIC_API_KEY")?)?;
# let client = Client::builder()?.api_key(api_key).build()?;
# let req = MessageRequest::builder()
#     .model(ModelId::claude_sonnet_5())
#     .max_tokens(MaxTokens::new(1024))
#     .add_user_text("Say hi.")
#     .build();
# let msg = client.messages().create(req).await?;
println!("stop_reason: {:?}", msg.stop_reason);
println!(
    "usage: input={} output={}",
    msg.usage.input_tokens, msg.usage.output_tokens
);
# Ok(())
# }
```

`stop_reason` is an `Option<StopReason>` that says why generation ended. `EndTurn` is a complete
answer, `MaxTokens` means the reply hit your ceiling, and `ToolUse` means Claude wants to call a tool
(see [Tools](ch02-03-tools.md)). `usage` counts the tokens the request read and the reply wrote.

## Run the example

```bash
cargo run -p airsclaude --example 01_hello
```

## Next

The API is stateless: every request carries its own history. To show the reply as it is written, go to
[Streaming](ch02-02-streaming.md). For what a request can carry beyond text, see
[Richer Input](ch02-05-richer-input.md).
