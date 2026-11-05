---
status: done
created: 2026-11-04
depends-on: [02, 12]
built-on: bdf14ebffb48
---

# Retire the old docs Implementation Plan

**Goal:** Replace the 20 old documents with stubs that point into the book.

**Architecture:** Runs last, because chapter plans read these files as their source. Each old path keeps a stub, so `blob/main` links in READMEs already on crates.io still resolve. Stubs leave the tarballs through `exclude`. The stub list is fixed in the gate, so a deleted stub fails.

**Tech Stack:** Markdown, Rust 2024, Cargo manifests.

**Content authority:** `spec.md` sections 5, 7, 9 and 10.

---

## Files that change

```
crates/airsclaude/docs/**            — modify: 11 files become stubs
crates/claudevs/docs/**              — modify: 9 files become stubs
crates/claudevs/src/docs_doctests.rs — delete: replaced by crates/book-doctests
crates/claudevs/src/lib.rs           — modify: remove its mod line
crates/claudevs/Cargo.toml           — modify: exclude docs/
crates/airsclaude/Cargo.toml         — modify: exclude docs/
crates/book-doctests/tests/book.rs   — modify: check the fixed stub list
```

## Order of work

### Task 1 — Replace the old documents with stubs

**Files:**
- Modify the 20 files below — each holds a heading, one sentence, and one absolute link, `https://airsstack.github.io/claudestacks/<page>.html`.
- Delete `crates/claudevs/src/docs_doctests.rs`, and remove `mod docs_doctests;` at `crates/claudevs/src/lib.rs:13`, in the same commit, since its `include_str!` targets lose their snippets.
- Modify `crates/book-doctests/tests/book.rs` — add the fixed stub list and its test.

```text
crates/airsclaude/docs/
  README.md                      → ch01-00-airsclaude-getting-started
  architecture.md                → ch04-01-three-pillars
  divergences.md                 → appendix-04-divergences
  messages-sdk/tutorial.md       → ch02-01-first-call
  messages-sdk/how-to.md         → ch02-00-messages-api
  messages-sdk/explanation.md    → ch04-02-messages-design
  messages-sdk/feature-parity.md → appendix-02-messages-parity
  agent-sdk/tutorial.md          → ch03-01-first-session
  agent-sdk/how-to.md            → ch03-00-agent-sdk
  agent-sdk/explanation.md       → ch04-03-agent-layers
  agent-sdk/feature-parity.md    → appendix-03-agent-parity
crates/claudevs/docs/
  README.md                      → ch05-00-claudevs-getting-started
  architecture.md                → ch09-02-engine
  cli/tutorial.md                → ch05-01-installation
  cli/how-to.md                  → ch06-00-writing-cases
  cli/reference.md               → appendix-01-claudevs-cli
  cli/explanation.md             → ch09-01-design
  engine/tutorial.md             → ch08-01-first-suite
  engine/how-to.md               → ch08-02-recipes
  engine/explanation.md          → ch09-02-engine
```

**Change:** The book is the only home of the content. Every old path still answers, with one link.

**Proof:** written first, seen failing, then passing.
- `every_stub_exists_and_links_into_the_book` — each of the 20 paths exists, and its only link is a book URL that resolves. Before the stubs are written it fails, naming the first path with no book link. Red again after: delete one stub and see its path named; change one stub's link to a missing page and see file, line and target named. Undo both.
- `cargo test -p claudevs` passes with `docs_doctests.rs` gone.
- `find crates/airsclaude/docs crates/claudevs/docs -name '*.md' | wc -l` prints 20.

**Done when:** `cargo test -p book-doctests` and `cargo test -p claudevs` pass and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): replace the old docs with stubs into the book`.

### Task 2 — Keep stubs out of the tarballs

**Files:**
- Modify `crates/claudevs/Cargo.toml` — add `exclude = ["docs/"]`.
- Modify `crates/airsclaude/Cargo.toml:18` — add `"docs/"` to the existing `exclude`, keeping the other three entries.

**Change:** The next release of each crate ships no stubs. The stubs still resolve on GitHub, which is where published links point.

**Proof:**
- `cargo package -p claudevs --list --allow-dirty | grep -c '^docs/'` prints 0, and the same for `-p airsclaude`.
- Both lists still contain `LICENSE`, `README.md` and `CHANGELOG.md`.
- `cargo package -p claudevs --allow-dirty` and `cargo package -p airsclaude --allow-dirty` verify from the tarball.

**Done when:** those commands pass and the Definition of Done is green (`cargo make dod`). Commit `chore(repo): leave the doc stubs out of the crate tarballs`.

### Task 3 — Run the whole-set checks

**Change:** No file changes unless a check below fails. This runs every check in spec section 9, including those no earlier task could see together.

**Proof:**
- `cargo make dod`, `cargo make book-build`, `cargo make deny`, `cargo make plugins` and `cargo make claudevs-check` each exit 0.
- `test -f book/book/index.html`. `cp install/install.sh book/book/`, then `test -f book/book/install.sh`.
- `dist plan` names `claudevs-cli` only.
- `wc -c crates/airsclaude/README.md` prints at least 3000.
- Every page has more than its title: `grep -c . book/src/*.md | grep -E ':[01]$'` prints nothing, since short opening pages are fine but a title alone is not.
- Book-wide bans: `grep -nE '\.(rs|ts|mjs|py):[0-9]+' book/src/*.md | grep -v 'appendix-0[234]'` prints nothing.
- Rendered diagrams match their sources: `grep -l '^```mermaid' book/src/*.md` lists the Mermaid pages; for each, its `class="mermaid"` count in `book/book/` equals its `^```mermaid` count in `book/src/`.
- Seen failing once more, on the final tree: an unwired page, a page missing from `SUMMARY.md`, a broken relative link, a broken book URL, a forbidden link form, and a snippet that stops compiling. Undo each. A broken stub target, a deleted stub and a missing chapter file were seen red in Task 1 and plan 01.

**Done when:** every command above passes and the Definition of Done is green (`cargo make dod`). No commit if nothing changed.

---

## Risks

- This is the point of no return for the old text on `main`, though git history keeps it. The appendices and chapters must be complete first, which `depends-on` enforces.
- After `pages.yml` first runs, the site root changes from 404 to the book. `install.sh` is copied by a step that fails the job when it cannot, so a missing installer stops the deploy.
- A green build cannot show that a Mermaid diagram draws: a syntax error builds with exit 0 (spec section 10). `execute` has no browser, so it names the pages for the author, who opens them from `cargo make book` before merging. No local run can see the deploy either, so that is left to the author after merging.

## Proof

- Every check in Task 3.
- The completion report names two checks for the author. Before merging, each page from the Mermaid list in Task 3 must draw its diagrams under `cargo make book`. After merging, both `curl` lines must print `200`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://airsstack.github.io/claudestacks/
curl -sS -o /dev/null -w '%{http_code}\n' https://airsstack.github.io/claudestacks/install.sh
```

## Review findings

Plans 12 and 13 shared one review: no blocking findings, so no fix round.

Results of Task 3: `cargo make dod`, `book-build`, `deny`, `plugins` and `claudevs-check` each exit 0. `dist plan` names `claudevs-cli` only (`grep -c airsclaude` prints 0). `crates/airsclaude/README.md` is 5,579 bytes. Mermaid counts match on all 18 pages. The title-only and citation greps print nothing. Tarballs hold 0 `docs/` entries and verify.

Seen red on this tree, each undone: deleted stub (`how-to.md:0: cannot read file`); stub linking to a missing page (`how-to.md:3: no page ch06-00-gone.md in the book`); unwired page (`book/src/zz-probe.md is not compiled as a doctest`); page missing from `SUMMARY.md`; broken relative link (`link target does not exist (gone.md)`); broken book URL; reference-style link definition; `compile_error!` snippet (`ch02-01-first-call.md` line 121, `62 passed; 1 failed`). The reviewer separately saw a stub with a second link and a `SUMMARY.md` entry with no file go red.

All below were fixed after the run, at the author's request, and carry no second review. `cargo make dod` and `book-build` exit 0; `cargo test -p book-doctests --test book` printed `7 passed`.

- Fixed, risk: 15 link labels in appendices B and C named old paths, such as `../divergences.md`. They now read "Appendix C", "Appendix D" and "Three Pillars".
- Fixed, risk: `every_stub_exists_and_links_into_the_book` did not hold the stub's shape. It now compares a stub's whole text; a stub with an added line went red (`how-to.md: must read exactly:`).
- Fixed, risk: a new file under `docs/` stayed green. `the_docs_trees_hold_only_the_stubs` went red on a planted `crates/claudevs/docs/new.md`.
- Fixed, risk: reverting `"docs/"` in an `exclude` went unnoticed. `stubs_stay_out_of_the_tarballs` reads both manifests and went red with the line removed (`Cargo.toml does not exclude "docs/"`).
- Fixed, nits: the comparison made `link_targets` unnecessary, so it and its unit test are gone and `crates/book-doctests/src/links.rs` is unchanged; that also clears the fixture and test-placement nits; the stub message now shows the exact text expected.
- Left as it is: `crates/airsclaude/CHANGELOG.md:29` names the old paths, in a released entry. The stubs still answer there.

## Deviations

- 2026-11-05: The Commit lines were not run, because the instruction to execute did not ask for commits. Tasks ran in the driver, without a task-briefer or coder, because the plan was already open.
- 2026-11-05: Each stub keeps its old heading, and its sentence reads "This content is in the claudestacks book:", followed by the link as an autolink.
- 2026-11-05: A forbidden link form was seen red as a reference-style definition; a raw `<a href>` was not tried on the final tree.
- 2026-11-05: Mermaid pages for the author to open under `cargo make book`: introduction, ch02-03, ch02-08, ch03-00, ch03-04, ch03-06, ch04-01, ch04-02, ch04-03, ch06-00, ch07-01, ch09-01, ch09-02, ch10-00, ch11-00, ch12-00, ch14-00, ch15-00. They were opened and reported good before this plan. Since then only prose changed on `ch04-02` and appendices B and D, and link labels on appendices B and C; no diagram did.
