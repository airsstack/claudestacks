# Models

`client.models()` asks the API what each model can do, so you do not need a hardcoded table of
models and features. `list` returns the available models, and `get` returns one model by id. Both
return `ModelInfo`.

The snippet assumes a `client` built as in [Your First Call](ch02-01-first-call.md).

```rust,no_run
# use airsclaude::prelude::*;
# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
# let api_key = ApiKey::new(std::env::var("ANTHROPIC_API_KEY")?)?;
# let client = Client::builder()?.api_key(api_key).build()?;
let list = client.models().list().await?;
println!("{} models on this page", list.data.len());

let info = client.models().get(&ModelId::claude_sonnet_4_5()).await?;
println!("{}", info.display_name);
println!("max input tokens: {:?}", info.max_input_tokens);
println!("max output tokens: {:?}", info.max_tokens);

if let Some(caps) = &info.capabilities {
    println!("image input: {}", caps.image_input.supported);
    println!("pdf input:   {}", caps.pdf_input.supported);
    println!("thinking:    {}", caps.thinking.supported);
    println!("adaptive:    {}", caps.thinking.types.adaptive.supported);
    println!("effort:      {}", caps.effort.supported);
}
# Ok(())
# }
```

## What a model reports

`ModelInfo` carries the id, a display name, the creation time, `max_input_tokens` and `max_tokens`.
The two limits and `capabilities` are `Option` values, and are `None` when the API leaves them out.

`ModelCapabilities` covers these areas:

| Field | Reports |
|---|---|
| `batch` | Message Batches support |
| `citations` | citation generation |
| `code_execution` | the code-execution tool |
| `image_input` | image blocks |
| `pdf_input` | PDF blocks |
| `structured_outputs` | JSON Schema output |
| `context_management` | context management, plus a map of dated strategies |
| `effort` | which effort levels the model accepts |
| `thinking` | thinking support, and whether the `adaptive` and `enabled` types work |

Most fields are a `CapabilitySupport`, which holds one `supported` flag. `effort` lists `low`,
`medium`, `high` and `max`, and an `xhigh` entry when the model reports one.

## Paging

`ModelList` has `has_more`, `first_id` and `last_id`. `list` returns the current page of results.
