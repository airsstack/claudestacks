---
status: done
created: 2026-11-04
built-on: bdf14ebffb48
---

# Book skeleton Implementation Plan

**Goal:** Stand up an mdBook at `book/` whose table of contents names all 54 pages of the final outline.

**Architecture:** Every page exists from the start with only its title, so later plans each edit a disjoint set of files and never share `SUMMARY.md`. The book's writing rules go into the root `CLAUDE.md` in this plan, because every later coder reads that file.

**Tech Stack:** mdBook 0.4.52, mdbook-mermaid 0.16.2, cargo-make.

**Content authority:** `spec.md` sections 2, 3 and 4.

---

## Files that change

```
book/book.toml        — create: book configuration
book/src/SUMMARY.md   — create: the table of contents
book/src/*.md         — create: 54 pages holding a title only
book/mermaid.min.js   — create: written by mdbook-mermaid install
book/mermaid-init.js  — create: written by mdbook-mermaid install
Makefile.toml         — modify: book tasks
.gitignore            — modify: ignore book/book/
CLAUDE.md             — modify: the book's writing rules
```

## Order of work

### Task 1 — Configure the book and its pages

**Files:**
- Create `book/book.toml` — title "The claudestacks Book", `authors = ["airsstack"]`, `language = "en"`, `src = "src"`, `[build] create-missing = false`, `[preprocessor.mermaid] command = "mdbook-mermaid"`, and `[output.html]` with `site-url = "/claudestacks/"`, `git-repository-url = "https://github.com/airsstack/claudestacks"`, `edit-url-template = "https://github.com/airsstack/claudestacks/edit/main/book/{path}"`, `additional-js = ["mermaid.min.js", "mermaid-init.js"]`. Shape: `../buildl/book/book.toml`.
- Create `book/mermaid.min.js`, `book/mermaid-init.js` — by running `mdbook-mermaid install book`.
- Create `book/src/SUMMARY.md` — the outline below, using `# airsclaude`, `# claudevs`, `# The Plugin Suite` and `# Appendix` as part titles.
- Create one file per page below, holding only a `# <title>` heading.

```text
introduction.md                          Which product do you need?

# airsclaude
ch01-00-airsclaude-getting-started.md    Getting Started
ch02-00-messages-api.md                  The Messages API
  ch02-01-first-call.md                  Your First Call
  ch02-02-streaming.md                   Streaming
  ch02-03-tools.md                       Tools
  ch02-04-cost-and-latency.md            Cost and Latency
  ch02-05-richer-input.md                Richer Input
  ch02-06-structured-results.md          Structured Results
  ch02-07-models.md                      Models
  ch02-08-building-larger.md             Building Something Larger
ch03-00-agent-sdk.md                     The Agent SDK
  ch03-01-first-session.md               Your First Session
  ch03-02-conversations.md               Conversations
  ch03-03-controlling-the-agent.md       Controlling the Agent
  ch03-04-your-code-in-the-loop.md       Your Code in the Loop
  ch03-05-sessions.md                    Sessions
  ch03-06-interactive.md                 Building Something Interactive
ch04-00-airsclaude-under-the-hood.md     Under the Hood
  ch04-01-three-pillars.md               Three Pillars
  ch04-02-messages-design.md             How the Messages Client Is Built
  ch04-03-agent-layers.md                How the Agent SDK Is Built

# claudevs
ch05-00-claudevs-getting-started.md      Getting Started
  ch05-01-installation.md                Installation
  ch05-02-first-plugin.md                A First Plugin
  ch05-03-first-case.md                  A First Case
  ch05-04-running-the-gate.md            Running the Gate
ch06-00-writing-cases.md                 Writing Cases
  ch06-01-hook-decisions.md              Hook Decisions
  ch06-02-scripts-and-flows.md           Scripts and Flows
  ch06-03-cases-in-lua.md                Cases in Lua
  ch06-04-native-suites.md               Native Suites
  ch06-05-selecting-and-skips.md         Selecting Cases and Reading Skips
ch07-00-check-gate.md                    The check Gate
  ch07-01-stages.md                      Stages
  ch07-02-wiring.md                      Wiring
  ch07-03-ci.md                          Running in CI
ch08-00-embedding.md                     Embedding
  ch08-01-first-suite.md                 Your First Suite
  ch08-02-recipes.md                     Recipes
ch09-00-claudevs-under-the-hood.md       Under the Hood
  ch09-01-design.md                      Why It Works This Way
  ch09-02-engine.md                      How the Engine Fits Together

# The Plugin Suite
ch10-00-plugins-getting-started.md       Getting Started
ch11-00-claudestacks-plugin.md           claudestacks
ch12-00-sdlc-plugin.md                   claudestacks-sdlc
ch13-00-guideline-plugins.md             Guidelines (Rust and Python)
ch14-00-journal-plugin.md                claudestacks-journal
ch15-00-cmux-plugin.md                   claudestacks-cmux

# Appendix
appendix-00.md                           Appendix
  appendix-01-claudevs-cli.md            A. claudevs CLI Reference
  appendix-02-messages-parity.md         B. Messages API Parity
  appendix-03-agent-parity.md            C. Agent SDK Parity
  appendix-04-divergences.md             D. Deliberate Divergences
```

**Change:** The book builds with every page present and empty of content. `create-missing = false` makes a chapter file named in `SUMMARY.md` but absent a build failure: `Chapter file not found`, exit 101.

**Proof:** no Rust test exists for this task, so the proof is seen red, then green, by command.
- Remove `book/src/ch15-00-cmux-plugin.md`, run `mdbook build book`, and see `Chapter file not found` with exit 101. Restore the file.
- `mdbook build book` exits 0, and `book/book/index.html` and `book/book/appendix-04-divergences.html` exist.
- `ls book/src/*.md | wc -l` prints 55: the 54 pages plus `SUMMARY.md`.

**Done when:** `mdbook build book` passes and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): add the book skeleton`.

### Task 2 — Add the book tasks

**Files:**
- Modify `Makefile.toml` — add `book-mdbook`, `book-mermaid`, `book` and `book-build`, plus their explanatory comment, copied from `../buildl/Makefile.toml:517-575`, and list `book` and `book-build` in the file's header comment.
- Modify `.gitignore` — add `book/book/`, with the comment `../buildl/.gitignore:27-28` uses.

**Change:** `cargo make book` serves the book and `cargo make book-build` builds it once. Both install the exact pinned versions first, and fail naming the wrong binary when `PATH` holds another. Neither joins `dod`.

**Proof:**
- `cargo make book-build` exits 0.
- `git status --short book/` shows no path under `book/book/`.

**Done when:** `cargo make book-build` passes and the Definition of Done is green (`cargo make dod`). Commit `chore(repo): add the book cargo-make tasks`.

### Task 3 — Record the book's writing rules

**Files:**
- Modify `CLAUDE.md` — add a `## The book` section after `## Commands`.

**Change:** The section states these rules, so every later plan can apply them from one place:

- Written for someone using the software, in plain short sentences and the present tense. No `file:line`, status tracking, decision history or internal vocabulary. The banned vocabulary under `### Docs describe the software, never the work that produced it` in `crates/airsclaude/CLAUDE.md` applies to every page. Appendices B, C and D are the one exception: they keep their citations.
- Each chapter carries its own small, self-contained example. A fact lives in one chapter and others link to it. API reference stays in rustdoc. Diagrams are Mermaid, including any ASCII flow diagram in a source document; file trees stay in a `text` fence.
- Where a chapter disagrees with the code, the book follows the code, and the disagreement goes in the running plan's `## Deviations`.
- Examples stay in `crates/*/examples/`, linked with absolute `https://github.com/airsstack/claudestacks/tree/main/...` URLs.
- Output is never pasted unless something produced it. Every snippet is classified by one test: does it reach a service, spend usage, or need an interactive Claude Code session? The four classes:
  - **No live run:** Rust calling the API or spawning `claude`; `cargo run --example` for a live example; `claude -p "hi"`; `/plugin` and `/claudestacks-*:*` commands; `cmux`. Rust is `rust,no_run`; anything else is the command only. No output either way.
  - **Run:** `claude --version`, `claude plugin validate`, `claudevs`, `cargo`, `airsl`, offline Rust. Run while writing, with output pasted from that run.
  - **Exercised by its reader:** YAML and Lua cases pass `claudevs test`; `hooks.json` and `plugin.json` pass `claudevs check`; `claudevs.toml` loads in the case run; JSON reports are pasted from a real run.
  - **Illustration:** file trees, and payload shapes taken from the rustdoc, in a `text` fence and never presented as output.
  - A snippet that fits no class is cut or rewritten until it does.
- Every fence is labelled, and no page uses an indented code block, because the gate compiles unlabelled and indented code as Rust.
- A snippet with a relative path starts with a hidden line moving to the owning crate, for example `# std::env::set_current_dir(concat!(env!("CARGO_MANIFEST_DIR"), "/../claudevs")).unwrap();`. Snippets that continue an earlier one complete themselves with hidden `#` lines, as `../airsl/book/src/ch06-02-scripts-and-values.md:62-64` does.
- Links are inline, image or `<https://...>` autolinks. Reference-style definitions and raw `<a href` are refused by the gate. Relative links in a page resolve against `book/src/`.

**Proof:** `grep -n '^## The book' CLAUDE.md` prints one line.

**Done when:** `grep -c '^## The book' CLAUDE.md` prints 1 and the Definition of Done is green (`cargo make dod`). Commit `docs(repo): record the book's writing rules`.

---

## Risks

- Title-only pages are published if this branch merges before the chapter plans finish. The branch merges once, after the set is done.
- `mermaid.min.js` adds about 2.6 MB to the repository's history, permanently.

## Proof

- `cargo make book-build` exits 0.
- `cargo make dod` exits 0.

## Review findings

Reviewed together with plan 02: no blocking findings. `cargo make dod` exit 0, `cargo make book-build` exit 0.

- Open, nit: `book/book.toml:10`, nothing fails if `create-missing = false` is removed.
- Open, nit: `CLAUDE.md:182` still says three jobs the gate excludes; plan 12 Task 2 owns this edit.
- Open, nit: `CLAUDE.md:249`, "Two more tasks sit outside `dod`" does not count `book` and `book-build`, and plan 12 does not name this sentence.
- Open, nit: `CLAUDE.md:298` cites another repository by line number; Task 3 dictated the citation.

## Deviations

- 2026-11-04: The Commit lines were not run during execution, which the instruction did not ask for. The author asked for the commits afterwards, with these messages: `docs(repo): add the book skeleton`, `chore(repo): add the book cargo-make tasks`, `docs(repo): record the book's writing rules`.
- 2026-11-04: Plans 01 and 02 shared one review instead of one per batch, since their file sets do not overlap.
