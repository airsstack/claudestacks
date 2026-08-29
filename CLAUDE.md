# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Never assert what you have not checked

Every factual claim about the official SDKs, the `claude` binary, or this codebase must come from
something you opened in the current task. Not memory, not inference, not plausibility.

- **Cite it or drop it.** A behavioural claim carries a `file:line` or byte offset you actually read.
  If you cannot cite it, go read it or write "not verified" — never state it flatly.
- **A subagent's recommendation is not a fact.** Research agents mix findings with advice. Promoting
  "you should gate on X" into "the SDK gates on X" is fabrication even though a report said it.
  Verify the underlying claim yourself before it enters a spec, a doc, or code.
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

## How to answer

Answer the question asked, then stop. Default to a few sentences. Direct and precise — say the thing,
do not build up to it.

Lead with the outcome: the first sentence says what happened or what you found; detail follows for
whoever wants it.

Be descriptive, not exhaustive. Give the finding and what it means for the work. Do not narrate the
process — no account of what you searched, read, or ruled out, no recap of steps the author watched you
take. Evidence appears where it changes the answer, not as a receipt attached to every claim.

Sound like a person wrote it. Vary sentence length. Skip formulaic openers, restating the question back,
and announcing the structure before you use it. Bullets are for things that are genuinely a list; prose
carries everything else.

Say the work, then the label — "the Agent SDK argv builder (Phase 3)", not "P3". Plain words over
house vocabulary: surface, substrate, seam, axis, cohesion, load-bearing, grounded.

Reach for a table, tree, or ASCII diagram when the content is structural: 3+ things compared on the
same axes, a pipeline, a file layout, a before/after size. Prose for everything else — a box around a
single fact costs more than the sentence it replaced.

Write at full precision, never compressed, for exact error text, shell commands, code, wire formats,
security warnings, and irreversible actions.

One topic per reply. Raise what blocks the current request; hold the rest until asked. A full backlog
is for when the author asks "what is left".

## Project

`claudestacks` is the author's Claude-focused Rust stack: an SDK for Anthropic's surfaces, the
tooling that tests Claude Code plugins, and the AI methodology that drives both. Cargo workspace,
`resolver = "3"`, Edition 2024, three members.

- `crates/clauders` — Claude SDK. The driving objective is **100% feature parity and behavioral
  compatibility with Anthropic's official SDKs** across three pillars: the Messages API, the Agent
  SDK (drives the `claude` Code CLI as a subprocess), and Managed Agents (server-hosted stateful
  agents). A Rust caller gets what a Python or TypeScript caller gets, with idiomatic Rust
  ergonomics. The Messages API and Agent SDK are implemented; Managed Agents is not started. Pillar
  map and internal structure:
  [`crates/clauders/docs/architecture.md`](crates/clauders/docs/architecture.md); docs index:
  [`crates/clauders/docs/README.md`](crates/clauders/docs/README.md).
- `crates/claudevs` — engine for the Claude Code plugin lifecycle CLI: case model, test harness,
  native-suite delegation. Fills the deterministic-testing gap between `claude plugin validate
  --strict` and `claude plugin eval`. Depends on `airsl` and reaches the Lua bindings through it
  (`airsl::mlua`) rather than declaring `mlua` itself, so the two can never resolve to different
  copies of the interpreter.
- `crates/claudevs-cli` — the `claudevs` binary.

`clauders::transport` is a module of the SDK crate (`crates/clauders/src/transport/`), not a
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
(`crates/clauders/src/test_support.rs`) rather than behind a feature. So `--all-features` is a no-op
that equals the default build.

The pass/fail gate (Definition of Done) lives in the `claudestacks-guideline-rust` plugin. Invoke
that skill for the command set rather than reconstructing it here.

`Makefile.toml` encodes that same gate as cargo-make tasks — `cargo make dod` runs all five steps,
`cargo make dod-crate <crate>` scopes them to one crate, and `cargo make --list-all-steps` shows the
individual steps. `.github/workflows/ci.yml` runs `cargo make dod` on push to `main` and on every
pull request, so CI and a local run are the same command. The plugin skill stays the source of
truth: if the two disagree, the skill is right and `Makefile.toml` needs fixing.

That same workflow carries two jobs the gate deliberately excludes. `cargo make claudevs-check` runs
`claudevs check` over the fixture plugin corpus in `crates/claudevs/tests/fixtures/` in both
directions — fixtures that must pass and fixtures that must fail at a named stage — because a corpus
of only-passing fixtures would go green the day the checkers stopped reporting. `cargo make deny`
runs cargo-deny over security advisories, licenses, duplicate versions and source registries, with
the policy and every suppression in `deny.toml`. It is its own job — invoking `cargo deny check`
directly, without cargo-make — because it compiles nothing and answers to a moving advisory
database, so it can fail on a commit that changed nothing.

The plugin suite has its own check for a different reason: `cargo make plugins` runs `airsl check`
then `airsl test` over the Lua scripts in `plugins/`, and needs the `airsl` binary installed
(`cargo make install-airsl`) rather than only the workspace built. The two answer different
questions — `check` compiles every file including the drivers no test loads, `test` runs the
266 assertions across 16 files — and either can be run alone as `cargo make plugins-check` /
`cargo make plugins-test`. They are separate jobs in `.github/workflows/lua.yml`, a workflow of its
own filtered to `plugins/**`, because it gates the Lua rather than the Rust workspace. If either
workflow file is missing, add it by hand: a session whose GitHub token lacks the `workflow` scope
cannot push anything under `.github/workflows/`, and the rejection names neither the file nor the
scope. An SSH remote authenticates with the key rather than that token, so it sidesteps the
restriction — but only an SSH remote does.

Both `cargo make install-airsl` and `plugins/claudestacks/scripts/install-airsl.sh` install the crate
unpinned (`cargo install airsl-cli --locked`), so the suite always runs on the latest published
runtime. `--locked` is a separate axis from the version: it builds that release against its own
`Cargo.lock`, which keeps the vendored Lua C sources from drifting between two installs of the same
version. The cost of leaving the version unpinned is that a runtime change can break the suite with
no commit here, and no `paths:` filter can catch it because nothing in this repository changes when
`airsl` is published. It surfaces on the next push to `plugins/`, attributed to whatever unrelated
change triggered the run, so read a sudden Lua failure as a possible upstream release before hunting
the diff. Publishing a new `airsl` without a matching `airsl-cli` is the other half of the trap: the
binary's lockfile pins the library, so a library-only release reaches nobody.

## AI methodology — the claudestacks plugin suite

The methodology ships as a Claude Code plugin suite from the in-repo marketplace
(`.claude-plugin/marketplace.json`), not as loose `.claude/rules/` files or repo-local agents. The
Rust rules, commit convention, model-routing, and agent-orchestration policies are delivered as
plugin skills and references — invoke the relevant skill rather than expecting always-on rule files.

| Plugin | What it provides |
|---|---|
| `claudestacks` | coder, reviewer, explorer; orchestration driver; process guidelines; project-local snapshot memory; concise output mode |
| `claudestacks-sdlc` | AI-native SDLC workflow: committed intent → spec → plan → execute chain with distill/triage loops (`.claudestacks/sdlc/`) |
| `claudestacks-guideline-rust` | Rust engineering guidelines and the Definition of Done |
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

Stop and put it to the author as its own question: *the spec's premise is disproven, amend now or
after this plan?* Do not fold it into a question about the implementation and read the answer as
covering both — approving a code change is not approving the record. Sibling plans were written
against the old text and cannot see the commit that corrected it; a commit body is not where the next
plan's author looks.

Superseding an approved spec belongs to the `design` skill (rename to `spec-superseded-YYYY-MM-DD.md`,
flip its status, write a fresh draft), and the author authorizes it. "Not without asking" means
*asking*, not carrying on quietly.

## Before re-deriving, query the stores

Both are index-first and token-cheap. Reach for them instead of re-deriving.

- **`/journal-recall <topic>`** — why something was built the way it is, what was already tried, what
  a past session decided. Returns ranked pointers from a derived index; open at most the one or two
  it surfaces. Mark a note that actually helped with `/journal-helped <stem>`.
- **`/snapshot-load`** — per-branch session orientation ("where was I on this branch"), not durable
  history or reference knowledge.

## Conventions owned by the repo

- **Commits** follow Conventional Commits v1.0.0 with workspace-aware scopes: a crate name
  (`clauders`, `claudevs`, `claudevs-cli`), `workspace` (root Cargo files / top-level config), or
  `repo` (`.claude/`, `.github/`, `plugins/`, docs). Full convention ships in the `claudestacks`
  plugin.
- **No session or chat links in commit messages, PR bodies, or any other committed artifact.** No
  `Claude-Session:` trailer, no `claude.ai/code/session_…` URL, no co-author or "generated by" line.
  They point at a transcript nobody reading the history can open, and they date the commit to a tool
  rather than to the change. Some harnesses inject such a trailer by default — this rule overrides
  that instruction. The message body carries the reasoning; `file:line` carries the evidence.
- `.claude/settings.json` carries non-secret project settings; `.claude/settings.local.json` carries
  machine-local permission grants (gitignored).
