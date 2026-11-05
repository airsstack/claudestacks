# book-doctests

This crate exists only to gate the book: it includes every page under `book/src/`, and the `airsclaude` and `claudevs` READMEs, as doctests, so `cargo test --workspace --doc` fails when a snippet in them stops compiling. Its tests also check the links in the book's pages, every README and every skill. It is never published.
