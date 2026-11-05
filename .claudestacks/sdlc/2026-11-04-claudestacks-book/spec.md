---
status: approved
created: 2026-11-04
built-on: 74c040cde5e6
---

# Spec: The claudestacks Book

This spec delivers one mdBook, "The claudestacks Book", at `https://airsstack.github.io/claudestacks/`,
covering `airsclaude`, `claudevs` and the plugin suite in re-authored chapters, the way `airsl` and
`buildl` publish theirs. It replaces `crates/*/docs/` as the home of the documentation, keeps
`install.sh` served, keeps Rust snippets gated, and leaves a stub at each old path so published links
keep working.

Probes ran on 2026-11-04 against `6de4962`, in a throwaway clone and scratch books that have since been
deleted. Output is quoted beside each claim.

## 1. What exists today

| Fact | Proof |
|---|---|
| 20 Markdown files will be replaced: 11 in airsclaude, 9 in claudevs | `find crates/airsclaude/docs -name '*.md' \| wc -l` → `11`; same for `crates/claudevs/docs` → `9` |
| The site root does not exist yet; `install.sh` does | `curl -w '%{http_code}'`: `/claudestacks/` → `404`; `/claudestacks/install.sh` → `200` |
| Pages deploys from Actions | `gh api repos/airsstack/claudestacks/pages --jq .build_type` → `workflow` |
| `pages.yml` publishes only the pointer | `.github/workflows/pages.yml:40-41` (`mkdir site`, `cp install/install.sh site/`) |
| `https://airsstack.github.io/claudestacks/install.sh` is published | `README.md:101`, `crates/claudevs-cli/README.md:12`, `crates/claudevs-cli/CHANGELOG.md:16` |
| Published READMEs link to the old paths | `crates/claudevs-cli/README.md:37`, `crates/claudevs/README.md:18`, `crates/airsclaude/README.md:91-101` |
| Only `docs_doctests.rs` reads the docs from code | `grep -n "docs/" crates --include='*.rs' --include='*.toml'` hits `crates/claudevs/src/docs_doctests.rs:5-42` as the only local reads; the same search also finds the unrelated `contract/site.rs:124` fixture string and external URLs |
| The docs hold 27 Rust fences, and only the 13 in claudevs's engine guides are gated | `grep -rc '^```rust' crates/airsclaude/docs crates/claudevs/docs`: airsclaude 14 (architecture 1, agent tutorial 7, messages explanation 1, messages tutorial 5), claudevs 13 (engine how-to 9, tutorial 2, explanation 2). Wiring: `docs_doctests.rs:4-14` |
| Five Mermaid diagrams exist | `grep -rhoE '^```[a-zA-Z0-9_,-]*' crates/*/docs \| sort \| uniq -c` → `5 ` + "```mermaid"; in `crates/airsclaude/docs/architecture.md`, `agent-sdk/explanation.md`, `messages-sdk/explanation.md` |
| Six plugins carry READMEs, 594 lines in total | `wc -l plugins/*/README.md` → `594 total` |
| Nothing mechanical reads a plugin README | `grep -rnE README plugins --include='*.lua' --include='*.sh' --include='*.json' --include='SKILL.md'` hits only test fixtures writing their own `README.md`, and the prose mention at `plugins/claudestacks/skills/snapshot-save/SKILL.md:78`. Control: the same grep style finds `enforcement.json` in `plugins/claudestacks/README.md` |
| Crate docs ship in the tarballs today | `cargo package -p claudevs --list \| grep -c '^docs/'` → `9`; `-p airsclaude` → `11` |
| No CHANGELOG uses an Unreleased heading | `grep -n -i unreleased crates/*/CHANGELOG.md` prints nothing. Control: the same files match `## \[0.1.1\]` at `crates/claudevs-cli/CHANGELOG.md:7` |
| No ADRs or RFCs bear on this | `ls .claudestacks/sdlc/adrs .claudestacks/sdlc/rfcs` → `No such file or directory` for both |

## 2. Site and tooling

`book/` at the repository root, matching `airsl` and `buildl`.

- **`book/book.toml`:** title "The claudestacks Book", `src = "src"`, `site-url = "/claudestacks/"`,
  `git-repository-url` and `edit-url-template` for this repository, the Mermaid preprocessor and
  `additional-js`. Shape: `../buildl/book/book.toml`.
- **`[build] create-missing = false`,** which the sibling books do not set. By default a chapter named in
  `SUMMARY.md` with no file is silently created empty:
  ```text
  $ mdbook build   # SUMMARY names gone.md, which does not exist
  build exit 0
  $ ls src
  gone.md i.md SUMMARY.md
  ```
  With the setting: `Error: Chapter file not found, gone.md`, exit `101`.
- **Pinned tools:** mdBook 0.4.52 and mdbook-mermaid 0.16.2, the versions `../buildl/.github/workflows/pages.yml:41`
  pins. Both are on this machine (`mdbook v0.4.52`, `mdbook-mermaid 0.16.2`).
- **Mermaid assets:** `mermaid.min.js` and `mermaid-init.js` beside `book.toml`, written by
  `mdbook-mermaid install book` and committed, as `buildl` does (`git -C ../buildl ls-files
  book/mermaid.min.js book/mermaid-init.js` → 2 files; `mermaid.min.js` is 2,667,011 bytes). Probe: a
  scratch book with one Mermaid block built with exit `0` and rendered one `class="mermaid"` element.
- **`Makefile.toml`:** `book`, `book-build`, `book-mdbook` and `book-mermaid` tasks, copied from
  `../buildl/Makefile.toml:517-575`. Exact versions, installed on first use.
- **`.gitignore`:** `book/book/`, as `../airsl/.gitignore` and `../buildl/.gitignore` do.
- **`.github/workflows/ci.yml`:** a `book` job running `mdbook build book`. Shape:
  `../buildl/.github/workflows/ci.yml:187-205`.
- **`.github/workflows/pages.yml`:** path filter `book/**`, `install/**`, `.github/workflows/pages.yml`.
  The build job installs both tools, runs `mdbook build book`, runs `cp install/install.sh book/book/`,
  and uploads `book/book`. Shape: `../airsl/.github/workflows/pages.yml`, which already does exactly this
  for its own installers. Its header comment saying `install.sh` is the only file served is rewritten.

Pages already deploys from Actions (§1), so no repository setting changes. The deploy job has
`needs: build` (`pages.yml:49`), so a failed book build does not reach the deploy step.

## 3. Book outline

Part titles build on mdBook 0.4.52. Probe: `# Part One` / `# Part Two` in a scratch `SUMMARY.md`, exit `0`,
and `toc.js` contains `part-title">Part One` and `part-title">Part Two`.

```text
introduction.md                          Which product do you need?

# airsclaude
ch01-00-airsclaude-getting-started.md    Getting Started
ch02-00-messages-api.md                  The Messages API
  ch02-01-first-call.md
  ch02-02-streaming.md
  ch02-03-tools.md
  ch02-04-cost-and-latency.md
  ch02-05-richer-input.md
  ch02-06-structured-results.md
  ch02-07-models.md
  ch02-08-building-larger.md
ch03-00-agent-sdk.md                     The Agent SDK
  ch03-01-first-session.md
  ch03-02-conversations.md
  ch03-03-controlling-the-agent.md
  ch03-04-your-code-in-the-loop.md
  ch03-05-sessions.md
  ch03-06-interactive.md
ch04-00-airsclaude-under-the-hood.md     Under the Hood
  ch04-01-three-pillars.md
  ch04-02-messages-design.md
  ch04-03-agent-layers.md

# claudevs
ch05-00-claudevs-getting-started.md      Getting Started
  ch05-01-installation.md
  ch05-02-first-plugin.md
  ch05-03-first-case.md
  ch05-04-running-the-gate.md
ch06-00-writing-cases.md                 Writing Cases
  ch06-01-hook-decisions.md
  ch06-02-scripts-and-flows.md
  ch06-03-cases-in-lua.md
  ch06-04-native-suites.md
  ch06-05-selecting-and-skips.md
ch07-00-check-gate.md                    The check Gate
  ch07-01-stages.md
  ch07-02-wiring.md
  ch07-03-ci.md
ch08-00-embedding.md                     Embedding
  ch08-01-first-suite.md
  ch08-02-recipes.md
ch09-00-claudevs-under-the-hood.md       Under the Hood
  ch09-01-design.md
  ch09-02-engine.md

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

Examples stay in `crates/*/examples/`; chapters link to them with absolute
`https://github.com/airsstack/claudestacks/tree/main/...` URLs, because a book page has no relative path
to them.

### Where each section goes

Every `##` section of the 17 re-authored files has a destination below. `DROP` is limited to navigation
and to notes about the old file layout, which mean nothing in a book. The three verbatim files in §6 move
whole, so their sections are not listed. Completeness was checked by a script that extracted this block
and compared it with every `^## ` line outside a fence in those 17 files; its output is under the block.

```text
crates/airsclaude/docs/README.md
  Start here                                   ch01-00-airsclaude-getting-started
  Cross-cutting                                DROP
  The four modes, and which file is which      DROP
  Examples                                     ch01-00-airsclaude-getting-started
crates/airsclaude/docs/architecture.md
  Three pillars                                ch04-01-three-pillars
  The Agent SDK's four layers                  ch04-03-agent-layers
  The Messages API's shape                     ch04-02-messages-design
  Conventions worth knowing before you edit    crates/airsclaude/CLAUDE.md
  Where to go next                             DROP
crates/airsclaude/docs/messages-sdk/tutorial.md
  Before you start                             ch02-01-first-call
  Step 1 — build a client                      ch02-01-first-call
  Step 2 — send a request                      ch02-01-first-call
  Step 3 — read the rest of the response       ch02-01-first-call
  Step 4 — stream the same request             ch02-02-streaming
  Step 5 — give Claude a tool                  ch02-03-tools
  What you now know                            DROP
crates/airsclaude/docs/messages-sdk/how-to.md
  Prerequisites for every recipe               ch02-00-messages-api
  Getting a reply                              ch02-01-first-call
  Controlling cost and latency                 ch02-04-cost-and-latency
  Sending richer input                         ch02-05-richer-input
  Getting structured results                   ch02-06-structured-results
  Discovering what a model supports            ch02-07-models
  Building something larger                    ch02-08-building-larger
  Swapping the HTTP transport                  ch02-08-building-larger
crates/airsclaude/docs/messages-sdk/explanation.md
  Generic over the transport, cheap to clone   ch04-02-messages-design
  Builders that will not compile when incomplete ch04-02-messages-design
  Two content-block unions, not one            ch04-02-messages-design
  Unknown values are kept, not discarded       ch04-02-messages-design
  Validation happens at construction           ch04-02-messages-design
  The streaming accumulator                    ch04-02-messages-design
  What is not modelled, and why that is visible ch04-02-messages-design
crates/airsclaude/docs/agent-sdk/tutorial.md
  Before you start                             ch03-01-first-session
  Step 1 — send a prompt                       ch03-01-first-session
  Step 2 — read the frames you care about      ch03-01-first-session
  Step 3 — configure the session               ch03-01-first-session
  Step 4 — hold a conversation                 ch03-02-conversations
  Step 5 — ask the session about itself        ch03-02-conversations
  Step 6 — interrupt a turn                    ch03-02-conversations
  What you now know                            DROP
crates/airsclaude/docs/agent-sdk/how-to.md
  Prerequisites for every recipe               ch03-00-agent-sdk
  Getting output                               ch03-01-first-session
  Controlling the agent                        ch03-03-controlling-the-agent
  Running your own code inside the loop        ch03-04-your-code-in-the-loop
  Sessions                                     ch03-05-sessions
  Building something interactive               ch03-06-interactive
  Choosing between `query` and `Client`        ch03-02-conversations
crates/airsclaude/docs/agent-sdk/explanation.md
  It drives a binary, not an API               ch04-03-agent-layers
  Four layers, each blind upward               ch04-03-agent-layers
  A turn, end to end                           ch04-03-agent-layers
  `Options` is fixed at spawn; `Client` is not ch04-03-agent-layers
  Exhaustive, with an escape hatch             ch04-03-agent-layers
  Your code runs inside the loop               ch04-03-agent-layers
  Where this leaves parity                     ch04-03-agent-layers
crates/claudevs/docs/README.md
  Start here                                   ch05-00-claudevs-getting-started
  Cross-cutting                                DROP
  The four modes, and which file is which      DROP
  Examples                                     ch05-00-claudevs-getting-started
crates/claudevs/docs/architecture.md
  Two crates                                   ch09-02-engine
  Module map                                   ch09-02-engine
  From a plugin directory to a report          ch09-02-engine
  Where to read next                           DROP
crates/claudevs/docs/cli/tutorial.md
  Install claudevs                             ch05-01-installation
  The plugin                                   ch05-02-first-plugin
  Ask what is missing                          ch05-02-first-plugin
  Put the plugin in a marketplace              ch05-02-first-plugin
  Write your first case                        ch05-03-first-case
  Run it                                       ch05-03-first-case
  Run the gate                                 ch05-04-running-the-gate
  Break the hook                               ch05-04-running-the-gate
  Fix it and test the installed copy           ch05-04-running-the-gate
  Where to go next                             DROP
crates/claudevs/docs/cli/how-to.md
  Assert a hook's decision                     ch06-01-hook-decisions
  Assert context a hook adds                   ch06-01-hook-decisions
  Assert a hook stays silent                   ch06-01-hook-decisions
  Test a script with its environment           ch06-02-scripts-and-flows
  Test a multi-step flow in a project          ch06-02-scripts-and-flows
  Generate cases in Lua                        ch06-03-cases-in-lua
  Script a case with t                         ch06-03-cases-in-lua
  Run the plugin's own test command            ch06-04-native-suites
  Run only some cases                          ch06-05-selecting-and-skips
  Convert a YAML case to Lua                   ch06-03-cases-in-lua
  Use JSON in CI                               ch07-03-ci
  Fail on manifest warnings                    ch07-03-ci
  Read a skip                                  ch06-05-selecting-and-skips
crates/claudevs/docs/cli/reference.md
  Commands                                     appendix-01-claudevs-cli
  Exit codes                                   appendix-01-claudevs-cli
  Case discovery                               appendix-01-claudevs-cli
  Case fields                                  appendix-01-claudevs-cli
  Case load errors                             appendix-01-claudevs-cli
  Default payloads                             appendix-01-claudevs-cli
  How a hook run is read                       appendix-01-claudevs-cli
  What a spawned command gets                  appendix-01-claudevs-cli
  Projects and fixtures                        appendix-01-claudevs-cli
  Lua cases                                    appendix-01-claudevs-cli
  claudevs.toml                                appendix-01-claudevs-cli
  check stages                                 appendix-01-claudevs-cli
  Wiring checkers                              appendix-01-claudevs-cli
  doctor probes                                appendix-01-claudevs-cli
  JSON reports                                 appendix-01-claudevs-cli
crates/claudevs/docs/cli/explanation.md
  What sits between validate and a live session ch09-01-design
  Cases assert meaning, not mechanics          ch09-01-design
  A skip is an environment gap                 ch06-05-selecting-and-skips
  Every stage runs                             ch07-01-stages
  What the installed layout catches            ch07-01-stages
  Why validation is handed to claude           ch07-01-stages
  Why cases cover fewer events than hooks.json may use ch09-01-design
  Why a matcher claudevs cannot evaluate is a warning  ch07-02-wiring
crates/claudevs/docs/engine/tutorial.md
  Before you start                             ch08-01-first-suite
  Run the suite                                ch08-01-first-suite
  Read what it printed                         ch08-01-first-suite
  Look at each verdict                         ch08-01-first-suite
  Turn it into an exit code                    ch08-01-first-suite
  Where to go next                             DROP
crates/claudevs/docs/engine/how-to.md
  Produce a JSON report                        ch08-02-recipes
  Run only some cases                          ch08-02-recipes
  Run against the installed layout             ch08-02-recipes
  Run check from code                          ch08-02-recipes
  Diagnose the environment                     ch08-02-recipes
  Run the wiring checkers alone                ch08-02-recipes
  Load and run one YAML case                   ch08-02-recipes
  Run one Lua case file                        ch08-02-recipes
  Convert a YAML case to Lua                   ch08-02-recipes
crates/claudevs/docs/engine/explanation.md
  One type means a test case                   ch09-02-engine
  The harness spawns, observes, then judges    ch09-02-engine
  A failing plugin is a verdict, not an error  ch09-02-engine
  Wiring reads files and never runs them       ch09-02-engine
  validate and layout reach outside the plugin ch09-02-engine
  check and doctor compose the rest            ch09-02-engine
  Reports are data first                       ch09-02-engine
  Two lists of hook events                     ch09-02-engine
  What `#[non_exhaustive]` means for a caller  ch09-02-engine
```

```text
files 17 sections 131 files with differences 0 unknown pages []
```

`grep -rhc '^## ' crates/airsclaude/docs crates/claudevs/docs` sums to 167; the other 36 are in the three
verbatim files.

`## Module map` is rewritten to say what each module offers someone embedding the engine, so it meets §4.

## 4. Writing rules

These go into the root `CLAUDE.md` as the book's standing rules. They combine `../airsl/CLAUDE.md:137-156`
with the banned-vocabulary table at `crates/airsclaude/CLAUDE.md:143-178`.

- Written for someone using the software. Plain short sentences, present tense. No `file:line`, status
  tracking, decision history or internal vocabulary. Appendices B, C and D are the named exception (§6).
- Each chapter carries its own small, self-contained example. A fact lives in one chapter and others link
  to it.
- Where a chapter being written disagrees with the code, the book follows the code and the plan records
  the disagreement under its Deviations.
- API reference stays in rustdoc.
- Diagrams in the book are Mermaid.

**Output is never pasted unless something produced it.** Every snippet is classified by one test: does it
reach a service, spend usage, or need an interactive Claude Code session?

| Class | What it covers | Treatment |
|---|---|---|
| No live run | Rust calling the API or spawning `claude`; `cargo run --example` for a live example; `claude -p "hi"`; `/plugin` and `/claudestacks-*:*` commands; `cmux` | Rust is `rust,no_run`: compiled, never run. Everything else is the command only. No output either way |
| Run | `claude --version`, `claude plugin validate`, `claudevs`, `cargo`, `airsl`, offline Rust | Actually run while writing; output pasted from that run |
| Exercised by its reader | YAML and Lua cases pass `claudevs test`; `hooks.json` and `plugin.json` pass `claudevs check`; `claudevs.toml` loads in the case run; JSON reports are pasted from a real run | Run through the tool that reads it |
| Illustration | File trees; payload shapes taken from the rustdoc | `text` fence, never presented as output |

A snippet that fits no class is cut or rewritten until it does. Checked against real snippets:

```text
agent-sdk/tutorial.md:15   claude --version                  Run (no service, no usage)
agent-sdk/tutorial.md:23   claude -p "hi"                    No live run (spends usage)
agent tutorial Rust        query(...).await                  No live run, rust,no_run
cargo run ... --example    26 lines in crates/airsclaude/docs  No live run for those calling the API or claude
claudevs/docs/cli/how-to   YAML case                         Exercised by claudevs test
```

Grounds: `ANTHROPIC_API_KEY` is unset in this environment (`[ -n "$ANTHROPIC_API_KEY" ]` → unset), and the
author decided this table and amended the intent to match. `rust,no_run` was probed: Probe 5's tutorial
snippets report `- compile ... ok` and do not execute.

## 5. The snippet and link gate

A new workspace member, `crates/book-doctests`, with `publish = false`, using the workspace's dependency
and lint tables. `crates/claudevs/src/docs_doctests.rs` and its `mod` line at `crates/claudevs/src/lib.rs:13`
are removed in the same change.

**How the alternatives failed:**

| Approach | Result |
|---|---|
| `mdbook test -L target/debug/deps` | Exit `101`. `error[E0432]` on the crate import; with an added `extern crate` line, `error[E0514]: found crate claudevs compiled by an incompatible version of rustc` |
| `include_str!` to a book outside a published crate (scratch crate, `../../book/x.md`) | `cargo test --doc` and `cargo package` pass, but `cargo test --doc` from the unpacked tarball fails: `error: couldn't read src/../../book/x.md: No such file or directory`. The same failure reproduces with `../../../book/`, the path from `crates/*/src/` to the repository root |

**Probe 5, the chosen shape,** in a throwaway clone with a `publish = false` member wired into the
workspace, and `[lints] workspace = true`:

```text
cargo clippy -p bookprobe --all-targets --all-features -- -D warnings   Finished
RUSTDOCFLAGS="-D warnings" cargo doc -p bookprobe --no-deps             Generated
cargo fmt --all -- --check                                              exit 0
cargo test --workspace --all-features --doc                             Doc-tests bookprobe ... 1 passed
cargo deny check                                                        advisories ok, bans ok, licenses ok, sources ok
dist plan                                                               announcing v0.1.1 / claudevs-cli 0.1.1 (no bookprobe)
```

`cargo test --workspace --all-features --doc` is the doctest step of the gate, so `cargo make dod` and CI
pick the new member up with no workflow change. `cargo deny` reported `wildcards` on path-only
dependencies, and passed once each carried a version too, so the member's dev-dependencies use
`[workspace.dependencies]` entries. `airsclaude` gains one (`Cargo.toml:64-66`, whose comment saying
nothing depends on it is corrected). The dev-dependencies are `airsclaude`, `claudevs`, `tokio`,
`futures-core`, `futures-util` and `serde_json`, the crates today's snippets import.

**The member's rules, each with its checked example:**

| Rule | Checked example | Result |
|---|---|---|
| Every page under `book/src/` except `SUMMARY.md` is included as a doctest | `#[cfg(doctest)] #[doc = include_str!(...)] struct` for a page outside the member | `Doc-tests bookprobe ... 1 passed` |
| A test fails naming any page not wired in | Same design as `every_engine_doc_is_compiled_as_a_doctest` (`crates/claudevs/src/docs_doctests.rs:24-45`). Adding `crates/claudevs/docs/engine/extra.md` and running `cargo test -p claudevs --lib every_engine_doc` | `docs/engine/extra.md is not compiled as a doctest`, `test result: FAILED` |
| Snippets with relative paths start with a hidden line moving to the owning crate | `# std::env::set_current_dir(concat!(env!("CARGO_MANIFEST_DIR"), "/../claudevs")).unwrap();` on all 9 engine how-to snippets | Without it, 9 `FAILED`: `Io { operation: "resolve plugin dir", path: "examples/01_hook_decision", ... NotFound }`. With it, `9 ok` |
| An unlabelled fence fails the gate when its content is not valid Rust. Valid Rust just compiles and runs, so it causes no harm | A bare fence holding `not rust at all` | `FAILED` |
| An indented code block fails the gate on the same terms | Four-space-indented `not rust at all` | `FAILED` |
| Labelled non-Rust fences are not compiled | `console`, `text`, `mermaid`, `lua` | No test generated |
| `rust,ignore` stays visible but is not compiled | `rust,ignore` holding `not rust` | `ignored` |
| Hidden lines render hidden | `# fn hidden() {}` in a `rust` fence | `class="boring">fn hidden() {}` in the HTML |

Existing tutorial snippets are fragments, so re-authoring has to complete them. Probe 5 ran the 12
airsclaude tutorial snippets, changed only to `rust,no_run`, with the dependencies above. 7 compiled and 5
did not, with `E0728` (`await` outside `async`), `E0425` (`client`, `msg` from an earlier snippet) and
`E0433` among the errors. Hidden `#` lines are the fix, as `../airsl/book/src/ch06-02-scripts-and-values.md:62-64`
does.

**The link check** is a test in the same member, because `mdbook build` catches nothing here. Probe: a
page linking to `nope.md` and `b.md#missing` built with exit `0`, and `grep -ci 'warn\|nope'` on the output
printed `0`.

- **Scanned:** `book/src/*.md`, including `SUMMARY.md`; the 20 stubs, as a fixed list, so a deleted stub
  fails; the root and crate READMEs; the six plugin READMEs.
- **Counted as a link:** inline `[x](y)`, images `![x](y)`, and `<https://...>` autolinks.
- **Forbidden, and a failure:** reference-style definitions (`[x]: y`) and raw `<a href`. `grep -rnE
  '^\s*\[[^]]+\]: |<a href|<https?://' crates/*/docs plugins/*/README.md README.md crates/*/README.md | wc -l`
  prints `0`, so nothing today needs them.
- **Skipped:** text in fences and inline code; anchor-only links; external URLs other than the book's own;
  book URLs that are not pages, such as `install.sh`.
- **Relative links in a book page** resolve against `book/src/`. **Relative links in a README or stub**
  resolve against that file's own directory, so `./LICENSE` and `RELEASING.md` keep working.
- **A book URL,** `https://airsstack.github.io/claudestacks/<page>.html`, must resolve to
  `book/src/<page>.md`. The bare site root always passes. The anchor is dropped before either check.
- **Every page under `book/src/` must be named in `SUMMARY.md`.** mdBook renders only what it names. Probe:
  `orphan.md` present and linked but not in `SUMMARY.md` builds with exit `0`, `a.html` holds
  `href="orphan.html"`, and no `orphan.html` exists.
- **A failure** names the file, the line and the target.

Checked examples: this rule as a throwaway script.

```text
../airsl/book/src, with airsl's site URL     ok 79 skipped 6 bad 0, orphans []
this repo's root, crate and plugin READMEs   ok 11 skipped 33 bad 0
airsl, with these added to introduction.md   bad 4, orphans ['orphan.md']
  [ref]: nope.md
  <a href="x.html">x</a>
  <https://airsstack.github.io/airsl/gone.html>
  ![img](missing.png)
```

An earlier run over airsl also confirmed the skips: with `[x](nope.md)`, `[y](.../gone.html)`,
`[z](ch02-00-first-project.md#no-such-anchor)`, `` `[c](code.md)` ``, a fenced `[f](fence.md)` and
`[i](.../install.sh)` added, only `nope.md` and `gone.md` were reported. A bad anchor counts as ok, by
decision. The final implementation is Rust, in `crates/book-doctests`.

## 6. The three verbatim appendices

`crates/airsclaude/docs/messages-sdk/feature-parity.md`, `agent-sdk/feature-parity.md` and `divergences.md`
become appendices B, C and D with their content unchanged, citations included. They are the named exception
to §4. `crates/airsclaude/CLAUDE.md:137-140` describes why each row carries a `file:line`.

```text
grep -cE '[a-z_/]+\.(rs|ts|mjs|py):[0-9]+'   messages parity 198, agent parity 81, divergences 15
```

Exactly two kinds of edit are allowed:

1. **Relative links, 17 of them,** are retargeted.
   ```text
   grep -oE '\]\([^)h#][^)]*\)' <the three files>
     11 (../divergences.md)                → appendix-04-divergences.md
      2 (../architecture.md)               → ch04-01-three-pillars.md
      2 (../agent-sdk/feature-parity.md)   → appendix-03-agent-parity.md
      1 (messages-sdk/feature-parity.md)   → appendix-02-messages-parity.md
      1 (agent-sdk/feature-parity.md)      → appendix-03-agent-parity.md
   ```
2. **The bare fence at `crates/airsclaude/docs/messages-sdk/feature-parity.md:732`** gets the label `text`.
   It is the only bare fence opening in either docs tree (a script walking every fence in `crates/*/docs`
   printed only that line), and it fails the gate. Probe: wiring the three records and `cli/reference.md`
   as doctests produced exactly one test, that one, `FAILED` with `unknown start of token: \u{2192}`.

Rendering was checked: both parity files in a scratch mdBook build with no warning or error, and every
table row survives. Source rows minus separator rows equal rendered `<tr>`s: messages 238 − 26 = 212,
agent 167 − 14 = 153. `file:line` text survives: `grep -cE '[a-z_/]+\.(rs|ts|mjs|py):[0-9]+'` over the
rendered messages page prints `196`.

`crates/airsclaude/CLAUDE.md:133` and `:137` are repointed to these appendices, where they name the parity
files and divergences. Its mention of `docs/architecture.md` is handled in §8.

## 7. Old paths become stubs

Each of the 20 old files is replaced by a stub: a heading, one sentence, and one absolute link to its new
page. The old relative paths keep resolving on GitHub's `blob/main` because the file is still there.

```text
crates/airsclaude/docs/
  README.md                     → ch01-00-airsclaude-getting-started
  architecture.md               → ch04-01-three-pillars
  divergences.md                → appendix-04-divergences
  messages-sdk/tutorial.md      → ch02-01-first-call
  messages-sdk/how-to.md        → ch02-00-messages-api
  messages-sdk/explanation.md   → ch04-02-messages-design
  messages-sdk/feature-parity.md→ appendix-02-messages-parity
  agent-sdk/tutorial.md         → ch03-01-first-session
  agent-sdk/how-to.md           → ch03-00-agent-sdk
  agent-sdk/explanation.md      → ch04-03-agent-layers
  agent-sdk/feature-parity.md   → appendix-03-agent-parity
crates/claudevs/docs/
  README.md                     → ch05-00-claudevs-getting-started
  architecture.md               → ch09-02-engine
  cli/tutorial.md               → ch05-01-installation
  cli/how-to.md                 → ch06-00-writing-cases
  cli/reference.md              → appendix-01-claudevs-cli
  cli/explanation.md            → ch09-01-design
  engine/tutorial.md            → ch08-01-first-suite
  engine/how-to.md              → ch08-02-recipes
  engine/explanation.md         → ch09-02-engine
```

Each stub is the only content at its path, and each is covered by the §5 link check.

`crates/airsclaude/Cargo.toml` and `crates/claudevs/Cargo.toml` add `docs/` to `exclude`, since a stub in a
tarball helps nobody. Probe, on `claudevs`: `exclude = ["docs/"]` with `docs_doctests.rs` removed gives
`cargo package --list | grep -c '^docs/'` → `0`, and `cargo package` builds from the tarball (`Finished`).
`airsclaude`'s existing `exclude` is at `crates/airsclaude/Cargo.toml:18`.

## 8. Everything that points at the docs

- **READMEs become short front doors.** Root (209 lines today), `crates/airsclaude` (141),
  `crates/claudevs` (95), `crates/claudevs-cli` (41), following `../airsl/CLAUDE.md:152-156`: crate READMEs
  link to the book with absolute URLs, because they render on crates.io. For scale, `airsl`'s are 95–97
  lines and `buildl`'s 84. `crates/claudevs-cli/README.md:12`'s install command stays.
- **`crates/airsclaude/README.md` keeps at least 3,000 bytes.** `crates/airsclaude/examples/messages/04_caching/main.rs:19-22`
  uses it four times over as a long system prompt, to clear what its comment gives as a ~1024-token caching
  minimum. It is 6,273 bytes today, and `airsl`'s crate README is 3,616. The floor is a decision, not a
  measurement: counting tokens needs the API key this work does not use.
- **Plugin READMEs shrink** to what the plugin is, install and a book link, and each keeps whichever of
  `## Attribution` and `## License` it has today, gaining none. Both: `claudestacks`, `claudestacks-sdlc`.
  License only: `claudestacks-cmux`, both guideline plugins. Neither: `claudestacks-journal`
  (`grep -cE '^## (Attribution|License)'` per file). The content moves to chapters 10–15. Dated section names like
  `## Phase 1 — Foundation (this release)` in `plugins/claudestacks-journal/README.md` are not carried over.
- **`plugins/claudestacks/skills/snapshot-save/SKILL.md:78`** is repointed from the plugin README to the
  `ch11-00-claudestacks-plugin`, which now describes the snapshot key.
- **Plugin versions:** all six get a patch bump, so an installed copy picks up the short README. The docs
  say an update does not replace the cached copy when the computed version matches, and that a manifest
  pinning `"version"` keeps it the same across commits (`https://code.claude.com/docs/en/plugins/loading.md`,
  fetched with `curl` on 2026-11-04, 43,799 bytes, sha256 `4384e0e85677682e…`, lines 298-302). All six pin one (`plugins/*/.claude-plugin/plugin.json:3`). Nothing pins these versions elsewhere:
  `grep -rnE '0\.4\.1|0\.2\.3|0\.1\.5|0\.1\.4|0\.1\.1|0\.1\.0' plugins scripts crates/claudevs/tests/*.rs
  Makefile.toml .claude-plugin`, excluding `plugin.json`, prints nothing. Control: the same pattern over
  `plugins --include=plugin.json` finds 3 files.
- **`crates/airsclaude/CLAUDE.md`:** the `## Docs` section is rewritten for the book.
  `## Conventions worth knowing before you edit` from `crates/airsclaude/docs/architecture.md` moves here,
  because the book is for readers using the crate.
- **`crates/airsclaude/CHANGELOG.md:28-29`** mentions `docs/` in prose, and stays as written, because it is
  history.
- **Root `CLAUDE.md`:** the doc pointers at `:124-125`, the member list (now four), the `Commands` section
  (book tasks, `pages.yml`, `create-missing`), and the §4 rules.

## 9. Testing

| Check | Command | Must show |
|---|---|---|
| Gate, including all book doctests and the link test | `cargo make dod` | exit 0 |
| Book builds | `cargo make book-build` | exit 0, `book/book/index.html` present |
| Installer step | `cp install/install.sh book/book/`, as `pages.yml` runs it | `book/book/install.sh` present |
| Supply chain | `cargo make deny` | `advisories ok, bans ok, licenses ok, sources ok` |
| Release tooling sees no new crate | `dist plan` | names `claudevs-cli` only |
| Crates still package | `cargo package -p claudevs --list`, `-p airsclaude --list` | no `docs/`; `LICENSE`, `README.md`, `CHANGELOG.md` present |
| Plugin suite unaffected | `cargo make plugins` | exit 0 |
| Fixtures unaffected | `cargo make claudevs-check` | exit 0 |
| Caching example's system prompt | `wc -c crates/airsclaude/README.md` | at least 3000 |
| Diagrams drawn | Open each Mermaid page from `cargo make book` | Diagram renders. A Mermaid syntax error builds with exit 0, so nothing else catches it |

**Seen failing before trusted,** per the root `CLAUDE.md`. Execution breaks each once and watches it go red:
an unwired page, a page missing from `SUMMARY.md`, a broken relative link, a broken book URL, a broken stub
target, a deleted stub, a forbidden link form, a snippet that stops compiling, and a missing chapter file
under `create-missing = false`.

**After the merge,** the first deploy has to be checked, because no local run can see it. The completion
report names these for the author; both must print `200`:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://airsstack.github.io/claudestacks/
curl -sS -o /dev/null -w '%{http_code}\n' https://airsstack.github.io/claudestacks/install.sh
```

## 10. Failure modes

| What goes wrong | Where it surfaces | What the author sees |
|---|---|---|
| Page not wired into the gate | `cargo make dod` | Test names the page |
| Link to a missing page, from a chapter, `SUMMARY.md`, stub or README | `cargo make dod` | Test names file, line, target |
| Page exists but is not in `SUMMARY.md` | `cargo make dod` | Test names the page |
| A stub is deleted | `cargo make dod` | Test names the path |
| Reference-style link or raw `<a href` | `cargo make dod` | Test names file and line |
| Bad anchor on a real page | Nowhere, by decision | Reader lands on the right page |
| Rust snippet stops compiling | `cargo make dod` | Doctest failure naming page and line |
| Unlabelled fence or indented block holding text that is not Rust | `cargo make dod` | Doctest failure naming page and line |
| Mermaid syntax error | Not caught by a build (probe: `graph TD; A--` builds with exit 0) | Found by the §9 page check, or by a reader |
| `SUMMARY.md` names a missing file | `mdbook build`, CI `book` job | `Chapter file not found`, exit 101 |
| Book fails to build on a pull request | CI `book` job | Red job |
| Book fails to build on `main` | `pages.yml` build job | Red run; `deploy` has `needs: build` and does not start |
| Deploy fails after a good build | `pages.yml` deploy job | Red run; the §9 `curl` checks show it |
| Wrong mdBook or mermaid version locally | `book-mdbook` and `book-mermaid` tasks | Installs the exact version, or names the wrong binary on `PATH` (`../buildl/Makefile.toml:530-556`) |
| Empty page | Not rejected. A page with no code produces no doctests, and is caught only in review | |
| Live-service snippet returns something unexpected at a reader's machine | Not covered, by decision (§4). The gate proves it compiles, not what the service returns | |

## 11. Non-goals

- Changing what any crate or plugin does.
- Releasing a crate as part of this work. Updated READMEs reach crates.io with each crate's next normal
  release. No CHANGELOG entry is written now, since the release flow requires a dated entry and no release
  is happening (`.claude/skills/release/SKILL.md` step 3).
- Moving rustdoc into the book.
- Decoupling the caching example from `crates/airsclaude/README.md`.
- Anchor checking, by decision (§5).
- Running live API or `claude` calls to produce output, by decision (§4).
- Fixing the `refs` checker's false positive on paths in prose, seen in the 0.1.1 corpus sweep.
