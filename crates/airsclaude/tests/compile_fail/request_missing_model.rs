fn main() {
    let _req = airsclaude::messages::MessageRequest::builder()
        .max_tokens(airsclaude::types::MaxTokens::new(1))
        .build();
}
