# Rust — Doc & Comment Discipline (Accurate, and No Internal-Artifact Leakage)

Code comments and rustdoc address **engineers reading or consuming this crate** — its public surface, invariants, constraints, and behaviour. They do NOT address the project's internal development process. Anything that exists only because of how the repo is *managed* (AI policies, plan documents, phase/task identifiers, internal review cycles) stays out of source files. This rule reinforces `M-FIRST-DOC-SENTENCE`, `M-MODULE-DOCS`, `M-CANONICAL-DOCS`, and `M-DOCUMENTED-MAGIC` from the Microsoft guidelines reference, and complements the mod-rs-export-only reference.

A comment has two duties, and they are independent. It must be *about the code* rather than about the process that produced it — the leakage rule below. It must also be *true of the code it sits beside* — the accuracy rule below. A comment can satisfy either one while failing the other, so both are checked.

## The leakage rule

Doc comments (`///`, `//!`) and source comments (`//`) MUST explain code, behaviour, or external context. They MUST NOT name or describe internal project artifacts.

### Disallowed in source (rustdoc and `//` comments alike)

- Paths or filenames under internal-only directories (such as out-of-band planning or tooling directories). Example: `// see internal-rules/rust-static-dispatch.md` — **rejected**.
- Names of internal rules, rule-numbered exceptions, or rule shortcodes that only resolve inside the local project. Example: `// project-rule exception #3` — **rejected**.
- Plan / spec / phase / task identifiers. Examples: `// Phase 3 Task 2`, `// per the v0.1 spec §8.4`, `*(lands in Task 3)*`, `// TODO Phase 5` — **rejected**.
- Workflow vocabulary from the development process: `subagent`, `implementer`, `reviewer`, `cavecrew`, `superpowers`, `the plan`, `the spec`, `the brainstorm`. Engineers reading the crate do not have this vocabulary; using it leaks the workflow into the contract. Exception: where the word names a runtime concept the documented code actually interacts with, rather than a role in how the code was produced. `subagent` on `HookEvent::SubagentStart`/`SubagentStop` (`crates/clauders/src/agent/capabilities.rs`) — naming the wire event names the `claude` binary emits during a turn — or on the `agent::subagents` module and `Options::agents` field that model the Agent SDK's programmatic subagent definitions, is describing the contract, not leaking the workflow; the same word standing in for "whoever implements this" is not. Judge by whether removing it would make the documentation less precise about the code's behaviour.
- AI/agent/model names in code comments: `Claude`, `Opus`, `Sonnet`, `the assistant`. Exception: when the *crate itself* is about LLM APIs and the name appears as a literal model identifier in a public type, identifier, or documented constant (e.g. a `ModelIdentifier::CLAUDE_SONNET` constant in an LLM SDK crate).
- PR / issue / commit references inside source. They belong in git history (commit messages, PR descriptions), not in the file — line numbers and SHAs rot quickly and the next reader does not have the issue tracker open.
- Narration of past or future work in this codebase: `added later`, `as discussed`, `originally written by`, `previously called`, `we decided to`. The diff explains *what changed*; the comment explains *what the code does*.

### Allowed (and encouraged)

- What the code does, the invariants it relies on, the contract it offers callers.
- Constraints and trade-offs the reader cannot derive from the code alone (hidden coupling, performance characteristics, ordering requirements).
- Cross-references via **rustdoc intra-doc links** to public items in this crate (`[`Storage`]`, `[`crate::error::StorageError`]`).
- References to **publicly published external standards and documentation**: RFCs, HTTP spec, API documentation URLs, `docs.rs` links for external crates, well-known industry guidelines.
- Microsoft Pragmatic Rust Guidelines codes (`M-*`) — they are an external public document. Acceptable in commit messages and rustdoc when motivating a design choice readers can look up.
- Repo-local *comment markers* that are grep-able conventions, not artifact references: `// SAFETY:`, `// dyn:`, `// PERF:`. The marker is fine; do NOT chase it with a path back into internal rule files. The reason text after the marker must stand on its own.

### Asking "where does this rule live?"

If a code reviewer cites an internal rule file on a finding, the *commit message* is the right place to acknowledge the rule (e.g. `Per M-DI-HIERARCHY, …`). The source file itself encodes the *decision* — not the bureaucracy that produced it. A reader two years from now opening `storage/seam.rs` cares about why `Storage` is `Send + Sync + 'static`, not which internal markdown file once said so.

## The accuracy rule

**Comments describe the code. The code is the authority.**

A comment, doc string, or shipped README sentence that describes behaviour is a claim about the code beside it. Where the two disagree, the code is what runs and the comment is what is wrong — with one exception, below.

1. **When reading, comparing, or mapping code, check the comment against the code.** A divergence is a finding, reported like any other. Never take a comment's word for what the code does; open the code.
2. **The default repair is the comment, never the code.** Rewriting working code to match a stale sentence turns a correct implementation into a defect.
3. **The exception: a comment stating an invariant the code is meant to uphold.** "Callers must hold the lock", "this must never be called twice", "the strip always succeeds because the walk is rooted here". If the code violates one of those, that is a bug report, not a comment fix — rewriting the invariant to match the breach launders the defect. Tell the two apart by asking whether the sentence describes what the code *does* or what the code *must guarantee*.
4. **A claim in a comment must be verified when it is written.** Error text and error codes, exit statuses, quoted command output, counts, version numbers, `file:line` citations, and any assertion that something does not exist. If it was not checked in the same change, it does not go in.
5. **Prefer the form that cannot rot.** Cite a symbol, never a line number. "the walk is rooted at `plugin_dir`, so the strip always succeeds" survives refactoring; "see `check.rs:164`" is wrong the moment a line moves.
6. **Budget the prose.** A comment explains the code. Reasoning, alternatives considered, and history belong in the commit message and the plan record, where a wrong sentence is cheap to correct and ships to nobody. A comment block longer than the code it explains is a signal to move most of it.

### What this looks like in Rust

- **Quoted diagnostics are toolchain-specific and neighbour-sensitive.** On rustc 1.94.1, destructuring a tuple struct with a private field through an imported name — `let FixtureRef(_x) = f;` — is ``error[E0532]: cannot match against a tuple struct which contains private fields``, while naming the same type through its path — `m::FixtureRef(_x)` in a pattern, or `m::FixtureRef(v)` as a constructor call — is ``error[E0603]: tuple struct constructor `FixtureRef` is private``. Two codes for what reads like one situation. Recall cannot separate them; `cargo check` separates them in seconds. Quote the text the compiler printed during *this* change, and say which toolchain printed it.
- **`#[expect(...)]` and `#[allow(...)]` reasons are claims.** `reason = "the enum is non_exhaustive upstream"` is checked by opening the upstream type, not by remembering it.
- **A comment naming a symbol must be re-resolved after the edit.** `// covered by parses_empty_manifest` is a defect the moment the same change renames or deletes that test — and the compiler will not tell you, because the name only exists in prose. Prefer an intra-doc link where the item is public, so `RUSTDOCFLAGS="-D warnings" cargo doc` fails when the target disappears.
- **Counts and quoted output are the shortest-lived claims of all.** "holds four fixtures", "the enum has six variants", a pasted libtest line ending `4 filtered out` — each is invalidated by an ordinary edit somewhere else. State the invariant that makes the number what it is, or drop the number.
- **Rule 5 and intra-doc links point the same way.** `[`Storage::insert`]` is the strongest citation Rust offers: the doc build resolves it, so it fails loudly instead of rotting quietly. `M-*` codes stay allowed under the leakage rule and are unaffected by rule 5 — they name a stable section of an external published document, not a position in a file that moves under edit. Rule 4 listing `file:line` among the things to verify governs *whether a claim was checked*, not *what form it may take in source*; where a line citation is the honest evidence, it belongs in the commit message or the review finding, which is pinned to the state of the tree it describes.

## How to translate a leaky or wrong comment

Common rewrites:

| Leaky or wrong                                                                              | Clean                                                                                                    |
| ------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `// Per internal-rules/rust-static-dispatch.md exception #1.`                              | `// dyn: heterogeneous concrete body-stream types across transport implementations.`                     |
| `//! Static-dispatch policy in internal-rules/rust-static-dispatch.md.`                    | *(delete the line; the `// dyn:` justification at the use site already explains the trade-off)*           |
| `//! Layout follows the export-only mod.rs rule.`                                          | `//! mod.rs re-exports only; concrete items live in sibling files.`                                      |
| `*(lands in Phase 3 Task 3)*`                                                               | *(delete; the type either exists or does not — future plans belong outside the source tree)*              |
| `// TODO Phase 5: support streaming.`                                                       | `// TODO: streaming support is unimplemented.` *(better: track in an issue and link the issue in commit)* |
| `// Decided in 2026-05-28 brainstorm session to keep this unbounded.`                       | `// Server enforces the upper bound; SDK-side cap would age badly across model releases.`                |
| `//! MockStorage (gated __test-mocks) — lands in Task 5.`                                  | *(delete the temporal qualifier; describe what exists now, period)*                                       |
| `// Matching here fails with error[E0603]: constructor is private.`                          | `// Matching the imported name fails: error[E0532], cannot match against a tuple struct which contains private fields (rustc 1.94.1).` *(run it; the path-qualified form is a different code)* |
| `// A missing suite maps to Skipped — see check.rs:164.`                                    | `// run_suite maps a missing suite to Skipped, alongside the unreadable and unparsable cases.` *(cite the symbol, and only claim what the arm actually covers)* |
| `// tests/fixtures/ holds four plugins.`                                                    | `// tests/fixtures/ holds one plugin per checker stage, in both passing and failing form.` *(the invariant outlives the count)* |

The pattern: replace "where the decision came from" with "what the decision *is* and *why it makes engineering sense*" — and replace anything you remember with something you ran.

## Why

- **The crate's public docs are its contract.** `cargo doc` output gets read by downstream consumers, search engines, and AI agents indexing crates. Internal repo paths in that output are noise at best and confusing at worst — readers have no way to follow internal tooling paths and shouldn't try.
- **Internal artifacts churn.** Rules get renumbered, plans get superseded, phases get re-ordered. Source files that name them go stale silently. The diff in a code review can show that a rule was renamed; the diff cannot show that twenty rustdoc comments now point at a moved file.
- **A wrong comment is more dangerous than no comment.** A missing explanation sends the reader to the code; a confident wrong one stops them from going. A quoted error code or a `file:line` citation reads as authority — it looks like someone checked — so it is trusted at exactly the point where trust is unearned, and the reader acts on it: pastes the wrong diagnostic into a test fixture, or builds the next comment, review, or design note on top of it. Silence costs a lookup; a wrong sentence costs a defect.
- **Mixing process with product is a smell.** The reader of `seam.rs` is trying to use `Storage`. They are not trying to learn how the team coordinates work. Process commentary in source files breaks the reading flow without paying it back.
- **AI agents writing code tend to leak workflow vocabulary** ("as the plan describes", "Phase 3 Task 2 below"). The fact that this comes naturally to agents is the precise reason the rule must be explicit — otherwise leakage compounds with every generated file. The same tendency produces plausible-sounding error codes, counts, and citations that were never run; both need the rule spelled out.

## Boundary: where the artifact reference *does* belong

- **Commit messages**: cite rule codes, plan rationale, and review findings here. `Per M-LINT-OVERRIDE-EXPECT, switched #[allow] to #[expect]` is fine in a commit body. `file:line` evidence belongs here too — a commit message is pinned to the tree it describes, so a line number in it stays meaningful forever.
- **PR descriptions**: link to specs, plans, design docs, prior incidents — these are project-management surfaces.
- **Project rules files and planning files**: cross-link freely. These files are *for* the project process.
- **Out-of-band planning notes** (gitignored scratch, internal specs/plans): free-form, never read by `rustdoc`, not shipped — narrate however helps you.

The forbidden zone is **the source tree under `crates/*/src/`, `crates/*/tests/`, `crates/*/examples/`, and any `README.md` shipped with a crate** — anything `cargo doc` reads, anything downstream consumers see, anything that ends up in the published crate.

## Things to AVOID

- Quoting the `# Examples` / `# Errors` / `# Panics` doc sections of an internal rule file by name in a source comment. Just state the constraint.
- Naming an internal rule file even in a `//` comment "for traceability". Reviewer rejects.
- Including in a doctest a reference to an internal planning artifact to explain why the test exists. Tests describe the behaviour under test, not the planning that produced them.
- README.md text that walks the reader through internal phases ("This crate is in Phase 3 of the implementation plan…"). The README is for users.
- Module docs that read like a journal entry ("Originally we wanted X but pivoted to Y after…"). Describe the *current* design.
- Writing a compiler diagnostic, error code, exit status, or command output from memory. Run it in this change and paste what it printed.
- Numbers a routine edit invalidates: how many files a directory holds, how many variants an enum has, a pasted test summary line. If the number must appear, it is re-counted in every change that could move it.
- Line-number citations into source (`// see check.rs:164`). Name the function, type, or module instead; use an intra-doc link when the item is public.
- Naming a test, field, or function in prose without re-resolving the symbol after the change that touched it. A rename elsewhere in the same diff is the usual way this breaks, and nothing in the build catches it.
- Stating what a matched arm, branch, or error path covers without reading the whole arm. "Maps a missing file to `Skipped`" is wrong the moment that arm also swallows two other variants.
- Rewriting a `# Safety` note, a "callers must hold the lock", or any other guarantee so that it agrees with code that breaks it. That is a bug being papered over, not a documentation fix.

## Definition of Done (rule additions)

In addition to the strict-quality reference DoD and the mod-rs-export-only reference DoD:

- Reviewer greps the touched files for internal planning path patterns, `Phase `, `Task `, `Step `, `subagent`, `implementer`, `the plan`, `the spec`, `the brainstorm` and rejects matches in source / rustdoc / shipped README. A `subagent` match is judged, not auto-rejected: keep it where it names the runtime concept the code interacts with, per the exception above.
- Source comments naming an internal rule file path or internal rule number are rejected even when factually correct — the rule's content is what matters, the file is internal.
- Newly written rustdoc explains the type/function/module on its own terms without requiring the reader to open any file outside the published crate.
- Reviewer re-runs or re-resolves every verifiable claim in a changed comment: quoted diagnostics and error codes against the pinned toolchain, quoted command output against a real run, counts against the tree as it stands after the change, named symbols against the post-change source, and "does not exist" assertions against a search that would have found the thing. A claim that cannot be re-resolved is rejected rather than accepted on the author's word.
- A comment that disagrees with the code beside it is a finding even when the code is right — the finding is real and the repair goes in the comment. The single exception is a violated invariant, which is raised as a defect against the code and never edited away in the prose.
- Line-number citations into source are rejected in favour of the symbol. Where the cited item is public, an intra-doc link is preferred over a bare name, because `RUSTDOCFLAGS="-D warnings" cargo doc` then turns a moved or deleted target into a build failure rather than a silent lie.
