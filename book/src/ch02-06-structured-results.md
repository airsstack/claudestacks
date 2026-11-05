# Structured Results

`OutputConfig` on the request constrains the reply to a JSON Schema. The reply arrives as one text
block whose content is JSON that conforms to the schema, so you parse it without checking its shape
first.

The snippet assumes the same `ApiKey` setup as [Your First Call](ch02-01-first-call.md). The one
change is a beta header on the client. The API currently expects `structured-outputs-2025-11-13` for
this feature, and `add_anthropic_beta` attaches it.

```rust,no_run
# use airsclaude::prelude::*;
use airsclaude::messages::structured_outputs::OutputConfig;

# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
let api_key = ApiKey::new(std::env::var("ANTHROPIC_API_KEY")?)?;
let client = Client::builder()?
    .api_key(api_key)
    .add_anthropic_beta(BetaHeader::new("structured-outputs-2025-11-13")?)
    .build()?;

let schema = serde_json::json!({
    "type": "object",
    "properties": {
        "city":       { "type": "string" },
        "country":    { "type": "string" },
        "population": { "type": "integer" }
    },
    "required": ["city", "country", "population"],
    "additionalProperties": false
});

let req = MessageRequest::builder()
    .model(ModelId::claude_sonnet_5())
    .max_tokens(MaxTokens::new(1024))
    .add_user_text("Give the capital of France as structured data.")
    .output_config(OutputConfig::json_schema(schema))
    .build();

let msg = client.messages().create(req).await?;
for block in &msg.content {
    if let ContentBlock::Text(t) = block {
        let parsed: serde_json::Value = serde_json::from_str(&t.text)?;
        println!("{}", serde_json::to_string_pretty(&parsed)?);
    }
}
# Ok(())
# }
```

The schema must be strict. Every `object` in it sets `"additionalProperties": false`, or the API
rejects the request with an `invalid_request_error`. The client forwards the schema as written and does
not check it. The API enforces it while the model generates.

## There is no typed `parse()` helper

The official Python and TypeScript SDKs can turn the reply straight into a typed value. This client
cannot. You get schema-conforming JSON in the first text block and deserialize it yourself, as the
snippet does with `serde_json`.

## Reasoning effort

`OutputConfig` also carries an `effort` slot. `OutputConfig::json_schema(schema).with_effort(level)`
sets both the schema and an `EffortLevel`, and `OutputConfig::effort(level)` sets the effort alone.
[Models](ch02-07-models.md) shows how to ask which effort levels a model accepts.
