# Richer Input

A user turn is not limited to text. `MessageContent::Blocks` takes a list of `ContentBlockParam`
values, and two of them carry richer input: `Image` for pictures and `Document` for PDFs and plain-text
documents.

Every snippet on this page assumes a `client` built as in [Your First Call](ch02-01-first-call.md).

## Send an image

An `ImageBlock` holds an `ImageSource`. The `Base64` source sends the bytes inline, and its media type
is one of four values: `Jpeg`, `Png`, `Gif` or `Webp`. The `Url` source hands the API a URL to download
instead, which works only when the host lets the API's fetcher reach it.

```rust,no_run
# use airsclaude::prelude::*;
use airsclaude::messages::{ImageBlock, ImageMediaType, ImageSource, MessageContent, TextBlock};

# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
# let api_key = ApiKey::new(std::env::var("ANTHROPIC_API_KEY")?)?;
# let client = Client::builder()?.api_key(api_key).build()?;
# let encoded = String::new();
// `encoded` is the image file's bytes as a base64 string.
let image = ImageBlock {
    source: ImageSource::Base64 {
        media_type: ImageMediaType::Jpeg,
        data: encoded,
    },
    cache_control: None,
};

let req = MessageRequest::builder()
    .model(ModelId::claude_sonnet_4_5())
    .max_tokens(MaxTokens::new(1024))
    .add_message(
        Role::User,
        MessageContent::Blocks(vec![
            ContentBlockParam::Image(image),
            ContentBlockParam::Text(TextBlock::new("Describe this image in one sentence.")),
        ]),
    )
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

The client does not encode the file for you. The
[vision example](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/messages/08_vision)
encodes a bundled JPEG with the `base64` crate.

## Send a document and get citations back

A `DocumentBlock` works the same way. Its `DocumentSource` is one of:

- `Base64`, an inline PDF.
- `Url`, a PDF the API fetches.
- `Text`, a plain-text body sent as a document.
- `Content`, a document assembled from embedded content, kept as raw JSON.

Set `citations` to `CitationsConfig { enabled: true }` and the reply's text blocks carry `citations`
that point back into the document.

```rust,no_run
# use airsclaude::prelude::*;
use airsclaude::messages::{
    CitationsConfig, DocumentBlock, DocumentSource, MessageContent, PlainTextMediaType, TextBlock,
    TextCitation,
};

# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
# let api_key = ApiKey::new(std::env::var("ANTHROPIC_API_KEY")?)?;
# let client = Client::builder()?.api_key(api_key).build()?;
let document = DocumentBlock {
    source: DocumentSource::Text {
        media_type: PlainTextMediaType::TextPlain,
        data: "Acme Corp was founded in 1997 in Portland, Oregon.".into(),
    },
    cache_control: None,
    citations: Some(CitationsConfig { enabled: true }),
    context: None,
    title: Some("acme-facts.txt".into()),
};

let req = MessageRequest::builder()
    .model(ModelId::claude_sonnet_4_5())
    .max_tokens(MaxTokens::new(1024))
    .add_message(
        Role::User,
        MessageContent::Blocks(vec![
            ContentBlockParam::Document(document),
            ContentBlockParam::Text(TextBlock::new("When was Acme Corp founded? Cite the document.")),
        ]),
    )
    .build();

let msg = client.messages().create(req).await?;
for block in &msg.content {
    if let ContentBlock::Text(t) = block {
        println!("{}", t.text);
        for citation in t.citations.iter().flatten() {
            if let TextCitation::CharLocation {
                cited_text,
                start_char_index,
                end_char_index,
                ..
            } = citation
            {
                println!("cited [{start_char_index}..{end_char_index}]: {cited_text:?}");
            }
        }
    }
}
# Ok(())
# }
```

A plain-text document yields `CharLocation` citations, which give the cited text and its character
range. `TextCitation` has other variants for other locations, such as `PageLocation` for a page
range, so match the ones your sources can produce. The
[citations example](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/messages/09_document_citations)
prints every citation it receives.
