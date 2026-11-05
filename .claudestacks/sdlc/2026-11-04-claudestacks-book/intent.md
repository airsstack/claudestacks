---
status: done
created: 2026-11-04
---

# Intent: claudestacks has no book, unlike airsl and buildl

## Problem

`airsl` and `buildl` each publish an mdBook at `https://airsstack.github.io/<repo>/`: one book, read
front to back, built from `book/` and deployed by `.github/workflows/pages.yml`. `claudestacks` has
none. Its Pages site serves one file, `install.sh`, and nothing else.

Its documentation is scattered instead, and a reader has to know where to look:

- `crates/airsclaude/docs/` holds 11 files and `crates/claudevs/docs/` holds 9, split by Diátaxis mode
  (tutorial, how-to, reference, explanation) and read as Markdown on GitHub.
- The plugin suite has no shared documentation at all, only a README in each of the six plugins under
  `plugins/*/README.md`.

Someone moving between the sibling projects meets a different documentation shape here, and someone
new to `claudestacks` has no single place to start. `claudevs-cli` 0.1.1 has just shipped prebuilt
binaries for people who need no Rust toolchain, and those readers land on GitHub-rendered files.

## Affected systems

- `crates/airsclaude/docs/` and `crates/claudevs/docs/`, the content being replaced.
- `plugins/*/README.md`, source material for the part of the book covering the plugin suite.
- `crates/claudevs/src/docs_doctests.rs`, which compiles and runs the 13 Rust snippets in
  `crates/claudevs/docs/engine/` under `cargo test --doc`, and asserts each guide there is wired in.
- `.github/workflows/pages.yml`, today publishing only `install/install.sh`, and
  `.github/workflows/ci.yml`.
- `Makefile.toml`, `.gitignore`.
- The READMEs at the root and in `crates/airsclaude`, `crates/claudevs` and `crates/claudevs-cli`, all
  of which link into the docs trees.
- The root `CLAUDE.md` and `crates/airsclaude/CLAUDE.md`, which name these paths and tell maintainers
  to read `docs/architecture.md` and `docs/divergences.md` before changing the crate.

## Desired outcome

One book, "The claudestacks Book", published at `https://airsstack.github.io/claudestacks/`, covering
all three products: `airsclaude`, `claudevs` and the plugin suite.

It reads like the sibling books: re-authored numbered chapters written for someone using the software,
each with a small self-contained example. Every snippet and transcript that can run without a live
service or an interactive session is run against the checkout before it lands. The rest are compiled or
shown without output, and no output is pasted that nothing produced. It is not the existing files dropped
into an mdBook. The Diátaxis trees under
`crates/*/docs/` stop being where the documentation lives, and the READMEs become short front doors
into the book, as they are in `airsl`.

## Constraints

- **`https://airsstack.github.io/claudestacks/install.sh` must keep working.** The README and the
  `claudevs-cli` CHANGELOG publish that URL, and it is what prebuilt-binary users run.
- **Rust snippets in the book stay gated.** A snippet that stops compiling must fail a check, so the
  move loses none of the protection the engine guides have today. This goes further than the sibling
  books, whose CI only runs `mdbook build`. `docs_doctests.rs` reaches its guides with `include_str!`
  from inside the crate, and a book at the repository root sits outside it. How to gate them without
  breaking `cargo publish`'s verification of the crate is for `design` to settle.
- **Published links must not die.** READMEs already on crates.io, including `claudevs-cli` 0.1.1, link
  to `github.com/airsstack/claudestacks/blob/main/crates/*/docs/...`, and a published version cannot be
  changed. A short stub stays at each old path, pointing to the matching book page.
- **Nothing maintainers rely on is lost.** The two `feature-parity.md` files (1,339 lines, each row
  carrying a `file:line`) and `divergences.md` are records `crates/airsclaude/CLAUDE.md` tells
  maintainers to consult. The `airsl` book's rule forbids `file:line` citations and status tracking, so
  the two conflict. Where these records end up is an open question for `design`.
- **Book tooling matches the siblings.** mdBook 0.4.52, the version both sibling repositories pin, with
  the same `cargo make book` and `book-build` tasks, a `book` CI job, and `book/book/` ignored.

## Non-goals

- Changing what any crate or plugin does. Where re-running a snippet shows a doc was wrong, the book is
  written to what the code does.
- Releasing a new crate version as part of this work. Published READMEs are handled by the stubs, and
  updated READMEs reach crates.io with each crate's next normal release.
- Moving rustdoc into the book. API reference stays in the rustdoc, as in `airsl`.
- Fixing the `refs` checker's false positive on paths in prose, seen in the 0.1.1 corpus sweep.
