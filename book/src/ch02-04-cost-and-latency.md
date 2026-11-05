# Cost and Latency

Four tools control what a request costs and how long it takes: reuse a long prefix through the
cache, let the model think before it answers, count tokens before you send, and move bulk work to the
batch endpoint.

Every snippet on this page assumes a `client` built as in [Your First Call](ch02-01-first-call.md).

## Reuse a long prompt prefix

Mark the end of a stable prefix with a cache breakpoint. The first call writes the prefix to the
cache. Later calls with the same prefix read it back.

```rust,no_run
# use airsclaude::prelude::*;
use airsclaude::types::{CacheControl, SystemPrompt, SystemSegment};

# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
# let api_key = ApiKey::new(std::env::var("ANTHROPIC_API_KEY")?)?;
# let client = Client::builder()?.api_key(api_key).build()?;
let long_prompt = "Reference material that stays the same on every call. ".repeat(500);

let segment = SystemSegment::text(long_prompt).with_cache(CacheControl::ephemeral());
let req = MessageRequest::builder()
    .model(ModelId::claude_sonnet_4_5())
    .max_tokens(MaxTokens::new(64))
    .system(SystemPrompt::segments(vec![segment]))
    .add_user_text("Reply with the single word: ok.")
    .build();

let msg = client.messages().create(req).await?;
println!("written to cache: {:?}", msg.usage.cache_creation_input_tokens);
println!("read from cache:  {:?}", msg.usage.cache_read_input_tokens);
# Ok(())
# }
```

Send the same request a second time and `cache_creation_input_tokens` on the first reply becomes
`cache_read_input_tokens` on the second. `Usage::total_input_tokens` adds the regular, cache-write and
cache-read counts together.

`CacheControl::ephemeral()` uses the API's default lifetime of five minutes.
`CacheControl::ephemeral_with_ttl(CacheTtl::OneHour)` asks for one hour. The server only stores a
prefix once it is long enough; the
[caching example](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/messages/04_caching)
repeats its text to clear a minimum of about 1024 tokens for Sonnet models.

Breakpoints also exist on other pieces. `MessageRequestBuilder::cache_control` sets a request-level
breakpoint, and the `cache_control` field on a tool or an image or document block marks that piece.

## Give the model room to reason

`ThinkingConfig` on the request turns on extended thinking. The reasoning comes back as
`ContentBlock::Thinking` blocks beside the text.

```rust,no_run
# use airsclaude::prelude::*;
use airsclaude::messages::ThinkingConfig;

# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
# let api_key = ApiKey::new(std::env::var("ANTHROPIC_API_KEY")?)?;
# let client = Client::builder()?.api_key(api_key).build()?;
let req = MessageRequest::builder()
    .model(ModelId::claude_sonnet_4_5())
    .max_tokens(MaxTokens::new(4096))
    .thinking(ThinkingConfig::enabled(1024))
    .add_user_text("A farmer has 17 sheep. All but 9 run away. How many are left?")
    .build();

let msg = client.messages().create(req).await?;
for block in &msg.content {
    match block {
        ContentBlock::Thinking(t) => println!("thinking: {}", t.thinking),
        ContentBlock::Text(t) => println!("answer: {}", t.text),
        _ => {}
    }
}
# Ok(())
# }
```

There are three ways to configure it:

- `ThinkingConfig::enabled(budget_tokens)` sets an explicit budget.
- `ThinkingConfig::adaptive()` lets the model decide how much to think.
- `ThinkingConfig::disabled()` turns thinking off, on models that accept that.

The budget must be at least 1024 and less than the request's `max_tokens`. The client does not check
either bound. The API rejects a request that breaks them with an `invalid_request_error`. Not every
model supports thinking; [Models](ch02-07-models.md) shows how to ask.

## Count tokens before you send

`count_tokens` takes the same `MessageRequest` you would send and returns how many input tokens it
would use.

```rust,no_run
# use airsclaude::prelude::*;
# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
# let api_key = ApiKey::new(std::env::var("ANTHROPIC_API_KEY")?)?;
# let client = Client::builder()?.api_key(api_key).build()?;
let req = MessageRequest::builder()
    .model(ModelId::claude_sonnet_4_5())
    .max_tokens(MaxTokens::new(256))
    .add_user_text("How many tokens is this?")
    .build();

let count = client.messages().count_tokens(req).await?;
println!("{} input tokens", count.input_tokens);
# Ok(())
# }
```

The call sends `POST /v1/messages/count_tokens` with only the fields that endpoint accepts: the model,
messages, system prompt, tools, tool choice, `thinking` and `output_config`. Fields such as
`max_tokens`, `temperature` and `stop_sequences` are left out. `thinking` is sent because it changes
the count.

## Submit a lot of work cheaply

`client.messages().batches()` is the Message Batches endpoint. A batch is a set of independent
requests, each with a `custom_id` you choose, that the server works through asynchronously.

```rust,no_run
# use airsclaude::prelude::*;
use airsclaude::messages::{BatchRequest, BatchStatus};
use airsclaude::types::CustomRequestId;

# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
# let api_key = ApiKey::new(std::env::var("ANTHROPIC_API_KEY")?)?;
# let client = Client::builder()?.api_key(api_key).build()?;
let one = |prompt: &str| {
    MessageRequest::builder()
        .model(ModelId::claude_sonnet_4_5())
        .max_tokens(MaxTokens::new(64))
        .add_user_text(prompt)
        .build()
};

let batch_req = BatchRequest::builder()
    .add(CustomRequestId::new("greeting")?, one("Say hello in French."))
    .add(CustomRequestId::new("math")?, one("What is 6 times 7?"))
    .build();

let batch = client.messages().batches().create(batch_req).await?;
let current = client.messages().batches().get(&batch.id).await?;
if current.processing_status == BatchStatus::Ended {
    println!("done: {} succeeded", current.request_counts.succeeded);
}
# Ok(())
# }
```

The handle also offers `list`, `results`, `cancel` and `delete`. `results` returns a stream with one
row per submitted request, and each row is a success, an error, a cancellation or an expiry. A small
batch usually finishes within a minute, but it can take longer, so poll `get` until the status is
`Ended` before you read results. The
[batches example](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/messages/10_batches)
submits a batch, polls it and prints every result row.
