# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Never assert what you have not checked

Every factual claim you state must come from something you opened in the current task. Not memory,
not inference, not plausibility.

That covers the official SDKs, the `claude` binary, and this codebase. It covers equally: what a
review report said, what a past commit did, why something is in the state it is in, and what you
yourself did earlier in the session. A claim about process is still a claim. A claim about your own
work is still a claim.

- **Cite it or drop it.** A behavioural claim carries a `file:line` or byte offset you actually read.
  If you cannot cite it, go read it or write "not verified" — never state it flatly.
- **A subagent's recommendation is not a fact.** Research agents mix findings with advice. Promoting
  "you should gate on X" into "the SDK gates on X" is fabrication even though a report said it.
  Verify the underlying claim yourself before it enters a spec, a doc, or code.
- **A causal story is not evidence.** Seeing an effect and naming its cause is a hypothesis, and it
  stays one until you open the thing that would show it. Explaining *why* something went wrong is
  where this breaks most often, because a plausible cause arrives instantly and checking it takes a
  `grep`. Run the `grep`. If you have not, say "I have not checked why" — that is a complete and
  useful answer, and a wrong cause is not.
- **Your own past actions need evidence too.** What you did an hour ago is memory. `git log`, file
  mtimes, the review report, the transcript on disk — open one before saying what happened. This
  applies hardest when you are accounting for a mistake: the reconstruction that flatters the
  narrative is the one that arrives first.
- **Absence needs a search that could have found it.** "X does not exist" names the exact command run
  and why it would have hit. Confirm the method works by finding a sibling you know is present.
- **A passing test proves nothing until you have seen it fail.** Break the fix, watch it go red.
- **Prefer the shipped artifact** — `sdk.d.ts`/`sdk.mjs`, the Python sdist, the binary — over
  documentation about them, and documentation over recollection.
- **Get the artifact into a local file, then grep it.** For the Claude Code docs that means
  `curl -sS -L 'https://code.claude.com/docs/en/<page>.md' -o <scratch>/<page>.md`. **Never WebFetch
  these URLs.** WebFetch truncates the page and hands the remainder to a summarizing model, which
  invents plausible content past the cutoff without erroring — three fetches of the same section
  returned `session_start_reason`, then `resume_reason`, then a decision table that does not exist.
  A summary of the artifact is not the artifact.
- **A review pass cannot validate a premise nobody checked.** Reviewers — human or agent — check
  internal consistency and conformance to an upstream document. They do not re-derive external facts,
  so repeated rounds raise confidence in a false premise without ever testing it. Ground every
  external claim against the artifact *before* it becomes the authority downstream work builds on.

This has produced real defects: wrong claims reached committed docs, and a workstream was scoped out
entirely on an unverified negative. The claudevs plugin-correctness spec was researched through
WebFetch and survived four `artifact-reviewer` rounds carrying four wrong facts about the hooks
reference — 31 events instead of 33, three stdout-as-context events instead of four, "no per-event
decision-control table exists" when it sits at `hooks.md:1011-1025`, and no mention that `FileChanged`
and `StopFailure` use a narrower matcher character set. The last one shipped as a real bug. One
`curl` of the 316,753-byte page answered all four by grep.

It recurs on process claims, where nothing looks like research so nothing gets checked. Asked why a
defect had reached a committed plan, this session answered "four review rounds ran and none flagged
it" — stated flatly, no report opened. One `grep` of the round-4 report found the finding present at
`plan-set-04.md:51`, filed 🟡 risk (tier headers at `:21`, `:41`, `:57`); `02-the-gates.md`'s mtime
showed it was last touched 92 minutes *before* that report was written, while every sibling plan was
edited after it. The reviewer had done its job and the finding was dropped at the fix step, which is
a different failure with a different fix. The invented cause sent the author hunting a broken
reviewer for two exchanges.

## How to answer

**High-level overview only. Detail on request.**

Default to three or four sentences. State the outcome, the state of the work, and what needs a
decision. Then stop and let the author ask.

Hold back, unless asked: tables of findings, per-item verdicts, citation lists, commit-by-commit
accounts, what each subagent reported, methodology, and any explanation of how a conclusion was
reached. One line naming the count is enough — "five spec claims were wrong, three now fixed" beats
five rows of evidence. The author will ask for the table if they want it.

A long reply about work that turned out to be wrong is worse than a short one. Volume of evidence is
not a substitute for the result being right, and presenting it as though it were wastes the reader
twice.

Lead with the outcome: the first sentence says what happened or what you found. Do not narrate the
process — no account of what you searched, read, or ruled out, no recap of steps the author watched you
take. Evidence appears only where the author cannot act without it.

Bad news goes first and plainly. If something is still wrong, unverified, or unfinished, that is the
first sentence, not a caveat at the end.

Brevity is not licence to skip the check. A short wrong answer wastes the author exactly as much as a
long one, and reads as more confident. When the check has not been run, the honest short answer names
what is unverified — never a confident sentence standing in for the work.

Sound like a person wrote it. Vary sentence length. Skip formulaic openers, restating the question back,
and announcing the structure before you use it. Bullets are for things that are genuinely a list; short
connective reasoning is prose, and anything that would grow into a long narrative becomes an ASCII
visualization (below).

Say the work, then the label — "the Agent SDK argv builder (Phase 3)", not "P3". Plain words over
house vocabulary: surface, substrate, seam, axis, cohesion, load-bearing, grounded.

Replace long narrative with an ASCII visualization. When an explanation would run past a short
paragraph — a flow, a sequence of states, a dependency chain, a before/after, 3+ things compared on
the same axes, a file layout — draw it as an ASCII diagram, tree, or table instead of writing it out.
Keep a sentence or two of prose around it for the outcome. A single fact stays a sentence — a box
around one fact costs more than the sentence it replaced.

**The `claudestacks` plugin's hooks deliver the communication protocol's reply rules every
session; there is nothing to load.** The guidance in this section sits on top of them.

Write at full precision, never compressed, for exact error text, shell commands, code, wire formats,
security warnings, and irreversible actions.

One topic per reply. Raise what blocks the current request; hold the rest until asked. A full backlog
is for when the author asks "what is left".

## Project

`claudestacks` is the author's Claude-focused Rust stack: an SDK for Anthropic's surfaces, the
tooling that tests Claude Code plugins, and the AI methodology that drives both. Cargo workspace,
`resolver = "3"`, Edition 2024, three members.

- `crates/airsclaude` — Claude SDK. The driving objective is **100% feature parity and behavioral
  compatibility with Anthropic's official SDKs** across three pillars: the Messages API, the Agent
  SDK (drives the `claude` Code CLI as a subprocess), and Managed Agents (server-hosted stateful
  agents). A Rust caller gets what a Python or TypeScript caller gets, with idiomatic Rust
  ergonomics. The Messages API and Agent SDK are implemented; Managed Agents is not started. Pillar
  map and internal structure:
  [`crates/airsclaude/docs/architecture.md`](crates/airsclaude/docs/architecture.md); docs index:
  [`crates/airsclaude/docs/README.md`](crates/airsclaude/docs/README.md).
- `crates/claudevs` — engine for the Claude Code plugin lifecycle CLI: case model, test harness,
  native-suite delegation. Fills the deterministic-testing gap between `claude plugin validate
  --strict` and `claude plugin eval`. Depends on `airsl` and reaches the Lua bindings through it
  (`airsl::mlua`) rather than declaring `mlua` itself, so the two can never resolve to different
  copies of the interpreter.
- `crates/claudevs-cli` — the `claudevs` binary.

`airsclaude::transport` is a module of the SDK crate (`crates/airsclaude/src/transport/`), not a
dependency. It was vendored from the `airs-transport` crate when the SDK moved to this repository.
`openrouter-rs` vendored the same crate the same way when it moved to
[`airsstack/openrouter-rs`](https://github.com/airsstack/openrouter-rs), and `rstlix0x0/airsstack` —
where both the SDK and `airs-transport` originated — has been deleted, so there is no upstream copy
left. The two vendored copies are independent and free to diverge; that divergence is the accepted
price of the split, and reconciling them only matters if the mixed-routing thesis ever returns.

`airsl` (the embeddable Lua 5.4 runtime the plugin suite runs on) and `airsl-cli` (the `airsl`
binary) live in [`airsstack/airsl`](https://github.com/airsstack/airsl) and arrive from crates.io —
as a library to `claudevs`, as an installed binary to the plugin hooks. Do not add them under
`crates/`; changes to the runtime belong in that repository.

`openrouter-rs` and `airs-transport` are not members here and are not coming back. Do not re-add
them.

Add members under `crates/` only when there is concrete work for them. Be pragmatic; the repo ships
only what serves the parity target.

### Do not reintroduce

Removed at the parity pivot (vision §5) because none of it exists in the official SDKs: `ApiRuntime`
(the native Messages loop), cross-provider routing, the middleware/evals/orchestration framework
tier, and the native permission/judge/subagent/session engines. Obsolete crate names:
`airsstack-cli`, `airsstack-core`, `provider-claude`, `provider-openrouter`, `airsdsp`.

The token-efficiency / mixed-routing thesis (route sub-tasks to cheaper non-Claude models via
OpenRouter) is **shelved, not abandoned** — it returns only under vision §8, once all three pillars
are at parity. Do not design for it now.

Re-introducing any of the above is named and scoped by the author at that point, under vision §8.

## Commands

Standard Rust commands apply (`cargo build`, `cargo clippy`, `cargo fmt`). **The workspace is
featureless** — no crate declares any Cargo `[features]`, every module compiles unconditionally, and
the `mockall` test double lives in a consumer-owned `cfg(test)` module
(`crates/airsclaude/src/test_support.rs`) rather than behind a feature. So `--all-features` is a no-op
that equals the default build.

The pass/fail gate (Definition of Done) lives in the `claudestacks-guideline-rust` plugin. Invoke
that skill for the command set rather than reconstructing it here.

`Makefile.toml` encodes that same gate as cargo-make tasks — `cargo make dod` runs all five steps,
`cargo make dod-crate <crate>` scopes them to one crate, and `cargo make --list-all-steps` shows the
individual steps. `.github/workflows/ci.yml` runs `cargo make dod` on push to `main` and on every
pull request, so CI and a local run are the same command. The plugin skill stays the source of
truth: if the two disagree, the skill is right and `Makefile.toml` needs fixing.

That same workflow carries three jobs the gate deliberately excludes. `cargo make claudevs-check` runs
`claudevs check` over the fixture plugin corpus in `crates/claudevs/tests/fixtures/` in both
directions — fixtures that must pass and fixtures that must fail at a named stage — because a corpus
of only-passing fixtures would go green the day the checkers stopped reporting. `cargo make deny`
runs cargo-deny over security advisories, licenses, duplicate versions and source registries, with
the policy and every suppression in `deny.toml`. It is its own job — invoking `cargo deny check`
directly, without cargo-make — because it compiles nothing and answers to a moving advisory
database, so it can fail on a commit that changed nothing. The third, `install-pointer`, runs
`cargo make install-check`: it installs `shellcheck`, which no gate step has, and compiles nothing.

The third-party corpus lanes — `cargo make corpus-fetch` and `cargo make corpus-check`, which run
`claudevs check` over 156 plugin roots in 13 pinned repositories nobody here controls — are the
`corpus-sweep` skill. Run both before a release; invoke that skill for how to read their rows and
what repinning commits you to.

Releasing a crate to crates.io is the `/release <crate>` skill (`.claude/skills/release/SKILL.md`),
pictured for engineers in `RELEASING.md`. It is check-only: the version bump and a dated CHANGELOG
entry reach `main` through a normal PR first, and the skill verifies them, runs the gates (the corpus
lanes among them for `claudevs` and `claudevs-cli`), then publishes and tags only after an explicit
yes for each. It never edits or commits.

The plugin suite has its own check for a different reason: `cargo make plugins` runs `airsl check`
then `airsl test` over the Lua scripts in `plugins/`, and needs the `airsl` binary installed
(`cargo make install-airsl`) rather than only the workspace built. The two answer different
questions — `check` compiles every file including the drivers no test loads, `test` runs the
630 tests across 23 files — and either can be run alone as `cargo make plugins-check` /
`cargo make plugins-test`. They are two of three jobs in `.github/workflows/lua.yml`, a workflow of
its own, because it gates the Lua rather than the Rust workspace. The third, `plugins-install`,
shellchecks the installer, runs `cargo make plugins-install` (offline cases for how the hooks find
`airsl`, run against stubs by `scripts/test-plugins-install.sh`), then installs `airsl` for real with
`install-airsl.sh` under a throwaway `HOME`. The workflow is filtered to `plugins/**` plus
`.github/workflows/lua.yml`, `Makefile.toml` and `scripts/test-plugins-install.sh`, so a change to the
gate re-runs the gate. If any workflow file is missing, add it by hand: a session whose GitHub token lacks the `workflow` scope
cannot push anything under `.github/workflows/`, and the rejection names neither the file nor the
scope. An SSH remote authenticates with the key rather than that token, so it sidesteps the
restriction — but only an SSH remote does.

`airsl` has two install routes, and neither pins a version, so the suite always runs on the latest
published runtime. `plugins/claudestacks/scripts/install-airsl.sh` is the one users are pointed at: it
runs `airsl`'s prebuilt-binary installer (into `~/.local/bin`) and builds from source only if that
cannot run or does not complete. `cargo make install-airsl` is the cargo route alone
(`cargo install airsl-cli --locked`), and is what the `plugins-check` and `plugins-test` CI jobs use,
because their cache is keyed to a `cargo install` build. `--locked` is a separate axis from the
version: it builds that release against its own `Cargo.lock`, which keeps the vendored Lua C sources
from drifting between two installs of the same version. The cost of leaving the version unpinned is that a runtime change can break the suite with
no commit here, and no `paths:` filter can catch it because nothing in this repository changes when
`airsl` is published. It surfaces on the next push to `plugins/`, attributed to whatever unrelated
change triggered the run, so read a sudden Lua failure as a possible upstream release before hunting
the diff. Publishing a new `airsl` without a matching `airsl-cli` is the other half of the trap: the
binary's lockfile pins the library, so a library-only release reaches nobody.

The `claudevs` binary ships prebuilt too, built by `dist` from `dist-workspace.toml`. A `claudevs-cli`
tag (the `tag-namespace`; `airsclaude` and `claudevs` tags start nothing, since the workflow's tag
filter, `claudevs-cli**[0-9]+.[0-9]+.[0-9]+*`, never matches them) runs
`.github/workflows/claudevs-cli-release.yml`, which also runs on every pull request to build and
smoke-test the archives without publishing. That file is generated: change
`dist-workspace.toml` and run `dist generate`, never edit the workflow by hand. The one hand-written
piece is `.github/workflows/claudevs-cli-smoke.yml`, which the release calls through
`global-artifacts-jobs` and which `host` waits on. It runs each archive on the platform it was built
for (the musl ones in Alpine) against the fixture plugins, and an archive that fails it is never
published. `.github/workflows/pages.yml` publishes `install/install.sh` to
`https://airsstack.github.io/claudestacks/install.sh`, a pointer that fetches the latest release's
installer; the repository's Pages source must be set to "GitHub Actions" or its deploy job fails.

`aarch64-apple-darwin` builds and smoke-tests on `macos-15`, set in `dist-workspace.toml`'s
`github-custom-runners` and again in the smoke workflow. The sibling `airsl` and `buildl` repositories
stay on dist's default `macos-14`, which GitHub retires on November 2, 2026, so copying either file
over from them brings that runner back; do not restore `macos-14`. Two more tasks sit outside `dod`:
`cargo make install-check` shellchecks `install/install.sh` and proves it refuses a bad
`CLAUDEVS_VERSION` before any download (it needs `shellcheck`), and `cargo make plugins-install` runs
the offline hook-lookup cases against stubs, needing neither `airsl` nor the network.

## The book

The rules below apply to every page of the book, so each plan that writes a chapter applies them from
here.

**Voice.** Write for someone using the software, in plain short sentences and the present tense. No
`file:line`, status tracking, decision history or internal vocabulary. The banned vocabulary under
`### Docs describe the software, never the work that produced it` in `crates/airsclaude/CLAUDE.md`
applies to every page. Appendices B, C and D are the one exception: they keep their citations.

**Structure.** Each chapter carries its own small, self-contained example. A fact lives in one chapter
and the others link to it. API reference stays in rustdoc. Diagrams are Mermaid, including any ASCII
flow diagram in a source document; file trees stay in a `text` fence.

**Code wins.** Where a chapter disagrees with the code, the book follows the code, and the
disagreement goes in the running plan's `## Deviations`.

**Examples.** Examples stay in `crates/*/examples/`, linked with absolute
`https://github.com/airsstack/claudestacks/tree/main/...` URLs.

**Output.** Output is never pasted unless something produced it. Every snippet is classified by one
test: does it reach a service, spend usage, or need an interactive Claude Code session? There are four
classes.

- **No live run:** Rust calling the API or spawning `claude`; `cargo run --example` for a live
  example; `claude -p "hi"`; `/plugin` and `/claudestacks-*:*` commands; `cmux`. Rust is `rust,no_run`;
  anything else is the command only. No output either way.
- **Run:** `claude --version`, `claude plugin validate`, `claudevs`, `cargo`, `airsl`, offline Rust.
  Run it while writing, and paste the output from that run.
- **Exercised by its reader:** YAML and Lua cases pass `claudevs test`; `hooks.json` and `plugin.json`
  pass `claudevs check`; `claudevs.toml` loads in the case run; JSON reports are pasted from a real
  run.
- **Illustration:** file trees, and payload shapes taken from the rustdoc, in a `text` fence and never
  presented as output.

A snippet that fits no class is cut or rewritten until it does.

**Fences.** Every fence is labelled, and no page uses an indented code block, because the gate
compiles unlabelled and indented code as Rust.

**Relative paths.** A snippet with a relative path starts with a hidden line moving to the owning
crate, for example
`# std::env::set_current_dir(concat!(env!("CARGO_MANIFEST_DIR"), "/../claudevs")).unwrap();`. Snippets
that continue an earlier one complete themselves with hidden `#` lines, as
`../airsl/book/src/ch06-02-scripts-and-values.md:62-64` does.

**Links.** Links are inline, image or `<https://...>` autolinks. Reference-style definitions and raw
`<a href` are refused by the gate. Relative links in a page resolve against `book/src/`.

## AI methodology — the claudestacks plugin suite

The methodology ships as a Claude Code plugin suite from the in-repo marketplace
(`.claude-plugin/marketplace.json`), not as loose `.claude/rules/` files or repo-local agents. The
Rust rules, commit convention, model-routing, and agent-orchestration policies are delivered as
plugin skills and references — invoke the relevant skill rather than expecting always-on rule files.

| Plugin | What it provides |
|---|---|
| `claudestacks` | coder, reviewer, explorer; orchestration driver; process guidelines; project-local snapshot memory; /discuss communication protocol |
| `claudestacks-sdlc` | AI-native SDLC workflow: committed intent → spec → plan → execute chain with distill/triage loops, artifact sync checks, optional roadmaps and milestones, and optional architecture decision records (`.claudestacks/sdlc/`) |
| `claudestacks-guideline-rust` | Rust engineering guidelines and the Definition of Done |
| `claudestacks-guideline-python` | Python engineering guidelines and the Definition of Done |
| `claudestacks-journal` | Obsidian-compatible journal vault kept outside the repo, written by isolated subagents |
| `claudestacks-cmux` | native cmux terminal control (control / workspace / browser / config) |

Install with `/plugin marketplace add .`, then `/plugin install <name>@claudestacks` per plugin. Each
ships a README under `plugins/<name>/README.md`.

Two plugins from the previous suite did not come across: the Open Knowledge Format toolkit, whose
`knowledge/` bundle was never migrated, and the plugin-development cache-sync hook, which has no
replacement here.

### When execution disproves the spec

Executing a plan is the first time a spec's claims meet the artifact they describe, so this is where
a wrong premise surfaces. When it does, the code fix is only half the work — the other half is that
the chain now lies to whoever executes the next plan.

**Do not ask during execution — about this or anything else.** An approved plan is ready to execute;
all discussion and verification belong to intent and spec. A disproven premise is a defect of the
spec stage: build to what the check showed, record it in the plan's `## Deviations` and its
`disproves` marker, and lead the completion report with it. Sibling plans were written against the
old text and cannot see the commit that corrected it, so the board marker — not a commit body — is
the record.

Superseding an approved spec belongs to the `design` skill (rename to `spec-superseded-YYYY-MM-DD.md`,
flip its status, write a fresh draft), after the run, on the author's word.

## Before re-deriving, query the stores

Both are index-first and token-cheap. Reach for them instead of re-deriving.

- **`/journal-recall <topic>`** — why something was built the way it is, what was already tried, what
  a past session decided. Returns ranked pointers from a derived index; open at most the one or two
  it surfaces. Mark a note that actually helped with `/journal-helped <stem>`.
- **`/snapshot-load`** — per-branch session orientation ("where was I on this branch"), not durable
  history or reference knowledge.

## Conventions owned by the repo

- **Commits** follow Conventional Commits v1.0.0 with workspace-aware scopes: a crate name
  (`airsclaude`, `claudevs`, `claudevs-cli`), `workspace` (root Cargo files / top-level config), or
  `repo` (`.claude/`, `.github/`, `plugins/`, docs). Full convention ships in the `claudestacks`
  plugin.
- **No session or chat links in commit messages, PR bodies, or any other committed artifact.** No
  `Claude-Session:` trailer, no `claude.ai/code/session_…` URL, no co-author or "generated by" line.
  They point at a transcript nobody reading the history can open, and they date the commit to a tool
  rather than to the change. Some harnesses inject such a trailer by default — this rule overrides
  that instruction. The message body carries the reasoning; `file:line` carries the evidence.
- `.claude/settings.json` carries non-secret project settings; `.claude/settings.local.json` carries
  machine-local permission grants (gitignored).
