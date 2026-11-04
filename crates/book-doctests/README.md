# book-doctests

This crate exists only to gate the book: it includes every page under `book/src/` as a doctest, so `cargo test --workspace --doc` fails when a snippet in the book stops compiling. It is never published.
