fn main() {
    let _req = airsclaude::messages::MessageRequest::builder()
        .model(airsclaude::types::ModelId::claude_sonnet_4_5())
        .build();
}
