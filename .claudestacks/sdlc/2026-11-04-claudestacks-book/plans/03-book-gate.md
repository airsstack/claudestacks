---
status: done
created: 2026-11-04
depends-on: [01]
built-on: bdf14ebffb48
---

# Book gate Implementation Plan

**Goal:** Fail `cargo make dod` when a book page stops compiling, drops out of the book or links to nothing.

**Architecture:** A new unpublished workspace member, `crates/book-doctests`, includes every page under `#[cfg(doctest)]`, so `cargo test --workspace --all-features --doc` (the gate's doctest step) compiles the book. Link rules live in a small library module tested on its own, then applied to the real tree by an integration test. `mdbook test` is not used: it exits 101 with `E0432`, and with `E0514` once an `extern crate` line is added (spec section 5).

**Tech Stack:** Rust 2024, rustdoc doctests, Cargo workspace.

**Content authority:** `spec.md` section 5.

---

## Files that change

```
crates/book-doctests/Cargo.toml   — create: publish = false member
crates/book-doctests/README.md    — create: what this crate is, one paragraph
crates/book-doctests/src/lib.rs   — create: table of contents only
crates/book-doctests/src/pages.rs — create: one cfg(doctest) include per page
crates/book-doctests/src/links.rs — create: link scanning rules, with unit tests
crates/book-doctests/tests/book.rs — create: the rules applied to the real tree
Cargo.toml                        — modify: member and airsclaude dependency entry
Cargo.lock                        — modify: the new member
```

## Order of work

### Task 1 — Add the member and wire every page

**Files:**
- Create `crates/book-doctests/Cargo.toml` — `publish = false`, version `0.0.0`, workspace `edition`, `rust-version`, `license`, `repository`, `authors`, `[lints] workspace = true`. Dev-dependencies through `[workspace.dependencies]`: `airsclaude`, `claudevs`, `tokio`, `futures-core`, `futures-util`, `serde_json`. `tokio` enables `full`, the same choice `crates/airsclaude/Cargo.toml:52` makes for its own dev-dependency.
- Modify `Cargo.toml` — add `crates/book-doctests` to `members` at `:3`. Add an `airsclaude = { version = "0.1.0", path = "crates/airsclaude" }` entry at `:64-66`, and correct the comment saying nothing depends on it. A path-only dependency fails `cargo deny` with `wildcards`; a version fixes it (spec section 5).
- Create `crates/book-doctests/src/lib.rs` — module docs and `mod pages;` only (`references/mod-rs-export-only.md`).
- Create `crates/book-doctests/src/pages.rs` — for each of the 54 pages under `book/src/` except `SUMMARY.md`, one `#[cfg(doctest)]` struct carrying `#[doc = include_str!("../../../book/src/<page>.md")]`. Plus a `#[cfg(test)]` module with the wiring test.
- Create `crates/book-doctests/README.md` — one paragraph: this crate exists only to gate the book, and is never published.

**Change:** The gate compiles every page. A new page that is not wired fails a test naming it, in the same design as `every_engine_doc_is_compiled_as_a_doctest` (`crates/claudevs/src/docs_doctests.rs:24-45`).

**Proof:** written first, seen failing, then passing.
- `every_page_is_compiled_as_a_doctest` — reads `book/src/`, and asserts that each page except `SUMMARY.md` appears as an `include_str!` in `pages.rs`. Red: add a scratch page and see the failure name it. Remove the page afterwards.
- `cargo test -p book-doctests --doc` exits 0 with the title-only pages. Red: add a fence holding `not rust at all` to one page and see `FAILED` naming that page and line. Undo it.

**Done when:** `cargo test -p book-doctests` passes and the Definition of Done is green (`cargo make dod`). Commit `test(workspace): compile every book page as a doctest`.

### Task 2 — Add the link rules

**Files:**
- Modify `crates/book-doctests/src/lib.rs` — add `pub mod links;`.
- Modify `crates/book-doctests/Cargo.toml` — add `tempfile` as a dev-dependency, through its `[workspace.dependencies]` entry at root `Cargo.toml:50`.
- Create `crates/book-doctests/src/links.rs` — `Finding` (file, line, target or reason), `scan_page(file, base_dir, book_src, site_url) -> Vec<Finding>` applying the rules below to one Markdown file, and `orphan_pages(book_src) -> Vec<Finding>` reporting pages under `book/src/` not named in `SUMMARY.md`. A file that cannot be read, and a missing `SUMMARY.md`, are findings, never an empty result. Documented for a downstream reader, with no internal vocabulary.

The rules:
- Counted as a link: inline `[x](y)`, images `![x](y)`, `<https://...>` autolinks.
- Forbidden, reported as a finding: reference-style definitions (`[x]: y`) and raw `<a href`.
- Skipped: text in fences and inline code; anchor-only links; external URLs other than the book's own; book URLs that are not pages, such as `install.sh`.
- A relative link resolves against `base_dir`.
- A book URL `<site_url><page>.html` must resolve to `<book_src>/<page>.md`. The bare site root always passes. An anchor is dropped before either check.

**Change:** The rules exist and are unit tested; nothing applies them to the real tree yet.

**Proof:** written first, seen failing, then passing, each using a temporary directory.
- `inline_link_to_a_missing_file_is_a_finding` — `[x](nope.md)` reports file, line and target.
- `inline_link_to_a_present_file_passes` — `[x](a.md)` with `a.md` present reports nothing.
- `image_to_a_missing_file_is_a_finding` — `![i](missing.png)` is reported.
- `book_url_to_a_missing_page_is_a_finding` — `https://site/gone.html` is reported, as is the same URL in an autolink.
- `book_url_to_a_present_page_passes` — `https://site/a.html` with `a.md` present reports nothing.
- `bare_site_root_passes` — `https://site/` reports nothing.
- `book_url_that_is_not_a_page_is_skipped` — `https://site/install.sh` reports nothing.
- `anchor_is_dropped_before_the_check` — `[x](a.md#no-such-anchor)` with `a.md` present reports nothing.
- `anchor_only_link_is_skipped` — `[x](#here)` reports nothing.
- `external_url_is_skipped` — `https://example.com/x.html` reports nothing.
- `links_in_fences_and_inline_code_are_skipped` — a link in a fence and one in backticks report nothing.
- `reference_definition_is_a_finding` — `[ref]: nope.md` is reported.
- `raw_anchor_tag_is_a_finding` — `<a href="x.html">` is reported.
- `relative_link_resolves_against_the_base_dir` — the same `./LICENSE` passes with a `base_dir` holding the file, and fails with one that does not.
- `anchor_on_a_book_url_is_dropped_before_the_check` — `https://site/a.html#no-such-anchor` with `a.md` present reports nothing.
- `page_missing_from_summary_is_an_orphan` — a page absent from `SUMMARY.md` is reported; a named page is not.
- `unreadable_file_is_a_finding` — `scan_page` on a path that does not exist reports that path.
- `missing_summary_is_a_finding` — `orphan_pages` on a directory with no `SUMMARY.md` reports it.

**Done when:** `cargo test -p book-doctests` passes and the Definition of Done is green (`cargo make dod`). Commit `test(workspace): add the book link rules`.

### Task 3 — Apply the rules to the tree

**Files:**
- Create `crates/book-doctests/tests/book.rs` — integration tests over the real repository, with `https://airsstack.github.io/claudestacks/` as the site URL.

**Change:** Pages resolve relative links against `book/src/`. The root README, `crates/*/README.md` and `plugins/*/README.md` resolve against their own directory, so `./LICENSE` and `RELEASING.md` keep working. Failures name file, line and target.

**Proof:** written first, seen failing, then passing.
- `book_links_resolve` — no findings across `book/src/*.md`, including `SUMMARY.md`. Red: add `[x](nope.md)` to a page and see file, line and target named. Undo it.
- `every_page_is_named_in_summary` — `orphan_pages` reports nothing. Red: add a page absent from `SUMMARY.md`. Remove it afterwards.
- `readme_links_resolve` — no findings across the root, crate and plugin READMEs. Red: add a book URL to a page that does not exist to one README. Undo it.

**Done when:** `cargo test -p book-doctests` passes and the Definition of Done is green (`cargo make dod`). Commit `test(workspace): check every book and README link`.

### Task 4 — Confirm the release tooling ignores the member

**Change:** No file changes unless a check below fails.

**Proof:**
- `cargo make deny` prints `advisories ok, bans ok, licenses ok, sources ok`.
- `dist plan` names `claudevs-cli` and no `book-doctests`.

**Done when:** both commands pass and the Definition of Done is green (`cargo make dod`). No commit if nothing changed.

---

## Risks

- `crates/book-doctests` carries no `LICENSE` file, because `publish = false` packages nothing and the release skill checks only the three published crates.
- The wiring list in `pages.rs` is the only hand-kept copy of the page list. The wiring test keeps it honest in one direction, and `create-missing = false` keeps `SUMMARY.md` honest in the other.
- `site_url` and the other parameters are plain strings. This crate is unpublished and has one caller, so newtypes would guard nothing.
- The stub list is added in plan 13, because the stubs replace the source documents the chapter plans read.

## Proof

- `cargo test --workspace --all-features --doc` lists `Doc-tests book_doctests`.
- `cargo make dod` exits 0.
- `cargo make deny` exits 0.

## Review findings

Reviewed once: 4 blocking bugs plus 1 blocking risk, 8 further risks, 8 nits. All five blocking findings share one cause, the line-by-line scanner, and were fixed by replacing it with `pulldown-cmark`.

- Fixed, `links.rs:62`, a fence opened on a list item hid the rest of the page. `cargo test -p book-doctests`: `test result: ok. 32 passed; 0 failed`.
- Fixed, `links.rs:66`, a code span wrapped across lines blanked real prose. Same run.
- Fixed, `links.rs:75`, raw anchors with another attribute first, or wrapped, went unreported. Same run.
- Fixed, `links.rs:107`, a commented-out or fenced `SUMMARY.md` entry counted as named. Same run.
- Fixed, `links.rs:269`, an empty target was dropped. Same run.
- Fixed by the parser change, risks at `links.rs:228` (definitions inside containers), `:253` (paren in a title) and `:262` (destination on the next line). Same run.
- Open, risk: the `Display` impl has no test, yet "failures name file, line and target" rests on it.
- Open, risk: book URL recognition is literal; a query string, `http://` or different case passes as external.
- Open, risk: a page can link out of the book (`../../README.md`) and pass.
- Open, risk: reversion cover was thin on the old scanner (22 of 24 mutants survived); not re-measured on the parser.
- Open, risk: the wiring test and `markdown_files` read only the top level of `book/src`, while `orphan_pages` recurses. The outline has no subdirectories.
- Open, nits: the README and `description` name only the doctest half; `lib.rs` and `links.rs` lack the Responsibilities list; `Finding` uses `line: 0` and an empty `target` as sentinels; `[x](nope.md:12)` parses as a scheme and passes; an absolute target checks the filesystem root; the wiring test is a substring match.

## Deviations

- 2026-11-04: The Commit lines were not run during execution, which the instruction did not ask for. The author asked for the commits afterwards, with these messages: `test(workspace): compile and link-check every book page`, one commit for Tasks 1 to 3, because the final `Cargo.toml` and `lib.rs` already carry the later tasks.
- 2026-11-04: Task 2 named no parser and the first build hand-wrote one. Review showed real links to missing files passing in ordinary Markdown forms, so `crates/book-doctests` now has one more dependency than the plan lists: `pulldown-cmark` 0.13, default features off, through `[workspace.dependencies]`. `cargo make deny` still prints all four `ok`.
- 2026-11-04: `reference_definition_is_a_finding` uses `text\n[ref]: nope.md`. CommonMark says a definition cannot interrupt a paragraph, so the parser sees none there. To keep the assertion, a text line starting `[label]:` is also reported as a definition, a stricter rule than the parser's.
- 2026-11-04: `[x][r]` and email autolinks are not checked as links. The `[r]:` definition is itself a finding, so the form cannot reach a page.
- 2026-11-04: `SUMMARY.md` is scanned like any page, so a draft entry `- [Title]()` is a finding. The outline has none. How mdBook treats that syntax was not checked.
