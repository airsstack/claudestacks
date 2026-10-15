fn main() -> Result<(), airsclaude::error::BuildError> {
    let key = airsclaude::types::ApiKey::new("sk-test-key").unwrap();
    let _client = airsclaude::Client::builder()?
        .api_key(key)
        .build()?;
    Ok(())
}
