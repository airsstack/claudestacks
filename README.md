# claudestacks

A Claude toolkit in Rust: an SDK for calling Claude, a test runner for Claude Code plugins, and a
Claude Code plugin suite for spec-driven development.

```
claudestacks
├── crates/
│   ├── airsclaude      Rust SDK for Claude                  ─► crates.io
│   ├── claudevs        plugin test engine (library)         ─► crates.io
│   └── claudevs-cli    the `claudevs` binary                ─► crates.io
└── plugins/            five Claude Code plugins             ─► /plugin marketplace
```

Pick the part you need. Each one works without the others.

| I want to… | Use |
| --- | --- |
| call Claude from Rust | [`airsclaude`](#airsclaude) |
| test a Claude Code plugin I wrote | [`claudevs`](#claudevs) |
| give Claude Code a review-gated dev workflow | [the plugin suite](#the-plugin-suite) |

## airsclaude

An unofficial Rust SDK for Claude, aiming for feature parity with Anthropic's official Python and
TypeScript SDKs. It ships two independent clients:

```
                       ┌─► airsclaude::messages ──HTTP──► Anthropic API     (needs ANTHROPIC_API_KEY)
your Rust program ─────┤
                       └─► airsclaude::agent ──spawns──► `claude` CLI 2.0+  (no API key; uses the CLI's login)
```

| Client | Use it when | Covers |
| --- | --- | --- |
| Messages API | you want a model to answer and you control the loop | streaming, tools, prompt caching, thinking, structured output, vision, PDFs, citations, batches |
| Agent SDK | you want an agent that reads files, runs commands and drives its own loop | `query`, stateful `Client`, in-process MCP tools, hooks, permissions, subagents, sessions |

Managed Agents, the third official surface, is not implemented.

**Install** (Rust 1.94+):

```toml
[dependencies]
airsclaude = "0.1"
tokio      = { version = "1", features = ["macros", "rt-multi-thread"] }
```

**Quick start:**

```rust
use airsclaude::messages::ContentBlock;
use airsclaude::prelude::*;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let client = Client::builder()?
        .api_key(ApiKey::new(std::env::var("ANTHROPIC_API_KEY")?)?)
        .build()?;

    let req = MessageRequest::builder()
        .model(ModelId::claude_sonnet_5())
        .max_tokens(MaxTokens::new(1024))
        .add_user_text("Say hi.")
        .build();

    let msg = client.messages().create(req).await?;
    for block in &msg.content {
        if let ContentBlock::Text(t) = block {
            println!("{}", t.text);
        }
    }
    Ok(())
}
```

25 runnable examples ship with the crate:

```bash
ANTHROPIC_API_KEY=sk-ant-... cargo run -p airsclaude --example 01_hello   # Messages API
cargo run -p airsclaude --example agent_01_query                          # Agent SDK
```

More: [crate README](crates/airsclaude/README.md) (Agent SDK quick start) ·
[docs](crates/airsclaude/docs/README.md) (tutorials, how-tos, parity tables).

## claudevs

Deterministic tests for Claude Code plugins. It runs a plugin's hooks and scripts the way Claude
Code would, checks the wiring, and tries the plugin in its installed layout.

```
claude plugin validate --strict   manifest only
claudevs check                    manifest ─► wiring ─► hook/script tests ─► installed-layout tests
claude plugin eval                model-driven, so results vary run to run
```

**Install:**

```bash
cargo install claudevs-cli     # installs a binary named `claudevs`
```

**Use:**

| Command | What it does |
| --- | --- |
| `claudevs check [PATH]` | the full gate above; every stage reports even if an earlier one fails |
| `claudevs test [PATH]` | runs the plugin's test cases (`--installed` for the installed layout) |
| `claudevs doctor [PATH]` | lists what this machine can and cannot run |
| `claudevs migrate <case.yaml>` | converts a YAML case to Lua |

Exit codes: `0` clean, `1` failures found, `2` claudevs itself could not run. Add `--json` to
`test`, `check` or `doctor` for machine-readable output.

More: [CLI README](crates/claudevs-cli/README.md) · [docs](crates/claudevs/docs/README.md).

## The plugin suite

Five plugins for [Claude Code](https://www.claude.com/product/claude-code), installed from this
repository's marketplace.

| Plugin | What you get |
| --- | --- |
| `claudestacks` | core agents (`coder`, `reviewer`, `explorer`), an `orchestrate` driver, snapshot memory, `/discuss` |
| `claudestacks-sdlc` | an `intent → spec → plan → execute` workflow under `.claudestacks/sdlc/`, with roadmaps, ADRs and a `status` board |
| `claudestacks-guideline-rust` | Rust guidelines and a Definition of Done the agents check against |
| `claudestacks-journal` | an Obsidian-compatible journal with embedding-free recall |
| `claudestacks-cmux` | control of the [cmux](https://cmux.com) terminal |

The SDLC workflow, in one picture:

```
intent ──► design ──► plan ──► execute
(problem)  (spec)    (tasks)   (code + review)

feedback loops
  failure evidence (a log, a bug)   ──► triage  ──► a new intent
  a review finding in 2+ chains     ──► distill ──► a proposed config fix
```

### What each plugin needs

The plugins' hooks and scripts are Lua, run by **`airsl`**, a separate binary. Install it first:
without it the hooks switch off silently, with no error.

```
airsl (binary) ◄── hooks/scripts ── claudestacks
               ◄──────────────────── claudestacks-sdlc
               ◄──────────────────── claudestacks-journal ──requires──► claudestacks
               ◄──────────────────── claudestacks-cmux ────requires──► cmux (binary)

claudestacks-guideline-rust ── no runtime needs; read by claudestacks
```

### Install

```bash
# 1. the Lua runtime (needs a Rust toolchain)
cargo install airsl-cli --locked
```

```
# 2. inside Claude Code: add the marketplace, then install what you want
/plugin marketplace add airsstack/claudestacks
/plugin install claudestacks@claudestacks
/plugin install claudestacks-sdlc@claudestacks
/plugin install claudestacks-guideline-rust@claudestacks
/plugin install claudestacks-journal@claudestacks
/plugin install claudestacks-cmux@claudestacks
```

If `airsl` is installed but the hooks still cannot find it, set
`AIRSL_BIN` to the binary's full path.

Inside this repository the marketplace is already registered by `.claude/settings.json`; enable
plugins with `/plugin`. Each plugin's README under `plugins/<name>/` lists its full contents.

## Working on this repository

| Command | Runs |
| --- | --- |
| `cargo make dod` | format, clippy, docs, tests, doctests — the gate CI runs |
| `cargo make dod-crate <crate>` | the same gate for one crate |
| `cargo make claudevs-check` | `claudevs check` over the fixture plugins |
| `cargo make plugins` | checks and tests the plugin Lua (`cargo make install-airsl` first) |
| `cargo make deny` | advisories, licenses, duplicate versions |

Releasing a crate: [RELEASING.md](RELEASING.md).

## Credits

- `claudestacks-sdlc` implements Anthropic's
  [AI-native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook); its
  design → plan → execute discipline is adapted from [superpowers](https://github.com/obra/superpowers).
- The `claudestacks` reply rules replace an earlier mode inspired by
  [caveman](https://github.com/juliusbrussee/caveman).

## License

Apache-2.0. See [LICENSE](./LICENSE).
