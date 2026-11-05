//! Compiles every page of the book under `book/src/` as a doctest.
//!
//! The crate is never published and has no API for other crates. It exists so that a Rust snippet in the
//! book that stops compiling fails `cargo test --doc`, which `mdbook test`
//! cannot do for a book that depends on workspace crates. The [`links`] module holds
//! the link rules the book's pages are checked against.

pub mod links;
mod pages;
