# claudestacks

The Claude-Code half of the author's personal AI technology stack: a Claude SDK written in Rust, an
engine for testing Claude Code plugins deterministically, and the Claude Code plugin suite that
packages the development methodology the other two are built with. It was migrated out of
[`rstlix0x0/airsstack`](https://github.com/rstlix0x0/airsstack) with its history preserved, so
everything here has the commits that produced it.

## Rust crates

A Cargo workspace under `crates/` — `resolver = "3"`, Edition 2024 — with three members:

- **`clauders`** — the Claude SDK. Its driving objective is **100% feature parity and behavioral
  compatibility with Anthropic's official SDKs** across three surfaces: the **Messages API** (the
  stateless `POST /v1/messages` client), the **Agent SDK** (drives the `claude` Code CLI as a
  subprocess over line-delimited JSON), and **Managed Agents** (server-hosted stateful agents). A
  Rust caller gets what a Python or TypeScript caller gets, with idiomatic Rust ergonomics. The
  Messages API and the Agent SDK are implemented; Managed Agents is not started. The pillar map and
  internal structure are in [`crates/clauders/docs/architecture.md`](crates/clauders/docs/architecture.md);
  the docs index is [`crates/clauders/docs/README.md`](crates/clauders/docs/README.md).
- **`claudevs`** — the engine behind the Claude Code plugin lifecycle CLI: the canonical case model,
  a deterministic test harness that spawns a plugin's hooks and scripts the way the Claude Code
  runtime would, native-suite delegation, static wiring checks, and install-layout simulation. It
  fills the gap between `claude plugin validate --strict`, which checks a manifest, and
  `claude plugin eval`, which is not deterministic.
- **`claudevs-cli`** — the `claudevs` binary.

`clauders` carries its HTTP transport in-tree as the `clauders::transport` module
(`crates/clauders/src/transport/`) rather than depending on the `airs-transport` crate — that crate
stays in `rstlix0x0/airsstack` where `openrouter-rs` still uses it, and vendoring lets the two copies
diverge freely instead of coupling two repos over one dependency.

## The plugin suite

A marketplace (`.claude-plugin/marketplace.json`) of five plugins under `plugins/` that package this
project's spec-driven, review-gated development methodology for
[Claude Code](https://www.claude.com/product/claude-code):

| Plugin | What it provides |
| --- | --- |
| **`claudestacks`** | Execution engine: a TDD `coder`, a merged code+spec `reviewer`, a read-only `explorer`, an `orchestrate` driver, process guidelines, project-local snapshot memory, and a `concise` output mode. |
| **`claudestacks-sdd`** | Spec-driven workflow: `brainstorm` an idea into a spec → `write-plan` (one objective per plan) → `execute-plan` with review checkpoints. |
| **`claudestacks-guideline-rust`** | Rust engineering guidelines plus a strict Definition-of-Done, delivered as a single lazily-loaded skill the execution agents consult when they touch Rust. |
| **`claudestacks-journal`** | Transparent, note-based experiential memory: an Obsidian-compatible journal vault with a deterministic, embedding-free recall index (`capture` / `note` / `recall` / `link` / `review` / `helped`). |
| **`claudestacks-cmux`** | Native [cmux](https://cmux.com) terminal control as four lazily-loaded skills (`cmux-control` hub, `cmux-workspace`, `cmux-browser`, `cmux-config`) over the real `cmux` CLI. Requires a cmux install on the machine. |

The suite was renamed from `airsstack*` in the move, and two members did not come with it:
`airsstack-okf` and `airsstack-plugin-dev` were dropped.

The plugins are language-agnostic except for the guideline plugin: the agents obtain their
Definition-of-Done and rules from whichever `*-guidelines` skill is installed, and degrade
gracefully when none is present.

Upstream attribution, restated from each plugin's own README: the `brainstorm → write-plan →
execute-plan` workflow in `claudestacks-sdd` is adapted from the
[superpowers](https://github.com/obra/superpowers) plugin, and the `concise` skill in
`claudestacks` is inspired by [caveman](https://github.com/juliusbrussee/caveman).

## Commands

Standard Rust commands apply (`cargo build`, `cargo clippy`, `cargo fmt`). The pass/fail gate is a
[cargo-make](https://github.com/sagiegurari/cargo-make) task set defined in `Makefile.toml`:

| Command | What it runs |
| --- | --- |
| `cargo make dod` | The Definition of Done — format check, clippy, docs, tests, doctests, every step zero-warning. |
| `cargo make dod-crate <crate>` | The same gate scoped to one crate while you work in it. |
| `cargo make claudevs-check` | `claudevs check` over the fixture plugin corpus, both directions. |
| `cargo make plugins` | Every check over the Lua plugin scripts (needs `cargo make install-airsl` first). |
| `cargo make deny` | cargo-deny: security advisories, licenses, duplicate versions, sources. |

`deny`, `plugins`, and `claudevs-check` are deliberately not part of `dod` — the gate is the five
commands the guideline skill owns, and they answer different questions.

## Installing the suite

**Inside this repository**, the suite loads on its own: `.claude/settings.json` registers the
in-repo directory marketplace and enables all five plugins. Restart Claude Code once to activate.

**In another project**, install the `airsl` binary that every plugin hook runs on *first* —
installing the plugins without it leaves every hook silently disabled, with no error anywhere:

```
cargo install airsl-cli --locked
```

Then install from the GitHub marketplace:

```
/plugin marketplace add airsstack/claudestacks
/plugin install claudestacks@claudestacks
/plugin install claudestacks-sdd@claudestacks
/plugin install claudestacks-guideline-rust@claudestacks
/plugin install claudestacks-journal@claudestacks
/plugin install claudestacks-cmux@claudestacks
```

Each plugin has its own README under `plugins/<name>/` with the full component list. Everything is
namespaced (`claudestacks:<name>`, `claudestacks-sdd:<name>`, `claudestacks-journal:<name>`, …).

## License

Apache-2.0. See [LICENSE](./LICENSE).
