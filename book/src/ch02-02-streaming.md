# Streaming

`create` waits for the whole reply. `stream` hands you the reply in fragments as Claude writes it, so
you can show the first words while the rest is still on its way.

The request is built the same way as in [Your First Call](ch02-01-first-call.md). Only the send step
changes.

```rust,no_run
use std::pin::Pin;

use airsclaude::messages::{ContentDelta, StreamEvent};
use airsclaude::prelude::*;
use futures_core::Stream as _;

# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
# let api_key = ApiKey::new(std::env::var("ANTHROPIC_API_KEY")?)?;
# let client = Client::builder()?.api_key(api_key).build()?;
let req = MessageRequest::builder()
    .model(ModelId::claude_sonnet_5())
    .max_tokens(MaxTokens::new(1024))
    .add_user_text("Count from one to five.")
    .build();

let mut stream = client.messages().stream(req).await?;

loop {
    let next = std::future::poll_fn(|cx| Pin::new(&mut stream).poll_next(cx)).await;
    match next {
        None => break,
        Some(Ok(StreamEvent::ContentBlockDelta {
            delta: ContentDelta::TextDelta { text },
            ..
        })) => {
            use std::io::Write as _;
            print!("{text}");
            std::io::stdout().flush()?;
        }
        Some(Ok(_)) => {}
        Some(Err(e)) => return Err(e.into()),
    }
}

println!();
# Ok(())
# }
```

Add `futures-core = "0.3"` to your dependencies for the `Stream` trait. The numbers appear one fragment
at a time instead of all at once.

`stream` yields `StreamEvent`s. Most of them describe the reply's structure, such as a block starting
or stopping. The text itself is in `ContentBlockDelta` events that carry a `ContentDelta::TextDelta`,
which is the only event this loop prints. The `Some(Ok(_)) => {}` arm skips the rest.

Every item is a `Result`. A connection or decoding failure ends the stream with an `Err`. The API can
also report an error inside the stream as a `StreamEvent::Error` item, after which the stream ends.
The `Some(Ok(_))` arm above skips that event too, so match `StreamEvent::Error` before it if your
program needs to react.

## When you want the finished message

If you only need the assembled `Message` and not the fragments, call `collect` on the stream. It reads
every event and returns the assembled `Message`. It turns an error event into an `Err`, so you do not
match it yourself.

```rust,no_run
# use airsclaude::prelude::*;
# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
# let api_key = ApiKey::new(std::env::var("ANTHROPIC_API_KEY")?)?;
# let client = Client::builder()?.api_key(api_key).build()?;
# let req = MessageRequest::builder()
#     .model(ModelId::claude_sonnet_5())
#     .max_tokens(MaxTokens::new(1024))
#     .add_user_text("Count from one to five.")
#     .build();
let msg = client.messages().stream(req).await?.collect().await?;
println!("stop_reason: {:?}", msg.stop_reason);
# Ok(())
# }
```

## Run the example

```bash
cargo run -p airsclaude --example 02_streaming
```

The full program is
[`02_streaming`](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/messages/02_streaming).
Next, [Tools](ch02-03-tools.md) lets Claude call your code.
