//! Compiles the engine guides under `docs/engine/` as doctests, so a snippet
//! that stops compiling or stops passing fails `cargo test --doc`.

#[cfg(doctest)]
#[doc = include_str!("../docs/engine/explanation.md")]
struct EngineExplanation;

#[cfg(doctest)]
#[doc = include_str!("../docs/engine/how-to.md")]
struct EngineHowTo;

#[cfg(doctest)]
#[doc = include_str!("../docs/engine/tutorial.md")]
struct EngineTutorial;

#[cfg(test)]
mod tests {
    #![expect(
        clippy::unwrap_used,
        reason = "tests unwrap a directory the crate ships"
    )]

    #[test]
    fn every_engine_doc_is_compiled_as_a_doctest() {
        let source = include_str!("docs_doctests.rs");
        let dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("docs/engine");
        let mut docs: Vec<String> = std::fs::read_dir(dir)
            .unwrap()
            .map(|entry| entry.unwrap().file_name().into_string().unwrap())
            .filter(|name| {
                std::path::Path::new(name)
                    .extension()
                    .is_some_and(|ext| ext == "md")
            })
            .collect();
        docs.sort();
        assert!(!docs.is_empty(), "docs/engine holds no markdown");
        for name in docs {
            let wired = format!("include_str!(\"../docs/engine/{name}\")");
            assert!(
                source.contains(&wired),
                "docs/engine/{name} is not compiled as a doctest"
            );
        }
    }
}
