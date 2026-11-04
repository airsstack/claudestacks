# claudestacks

A Claude toolkit in Rust: an SDK for calling Claude, a test runner for Claude Code plugins, and a
Claude Code plugin suite for spec-driven development.

```
claudestacks
├── crates/
│   ├── airsclaude      Rust SDK for Claude                  ─► crates.io
│   ├── claudevs        plugin test engine (library)         ─► crates.io
│   └── claudevs-cli    the `claudevs` binary                ─► crates.io
└── plugins/            six Claude Code plugins              ─► /plugin marketplace
```

Pick the part you need. Each one works without the others. The
[book](https://airsstack.github.io/claudestacks/introduction.html) covers all three.

| I want to… | Use | Start in the book |
| --- | --- | --- |
| call Claude from Rust | [`airsclaude`](#airsclaude) | [Getting Started](https://airsstack.github.io/claudestacks/ch01-00-airsclaude-getting-started.html) |
| test a Claude Code plugin I wrote | [`claudevs`](#claudevs) | [Getting Started](https://airsstack.github.io/claudestacks/ch05-00-claudevs-getting-started.html) |
| give Claude Code a review-gated dev workflow | [the plugin suite](#the-plugin-suite) | [Getting Started](https://airsstack.github.io/claudestacks/ch10-00-plugins-getting-started.html) |

## airsclaude

An unofficial Rust SDK for Claude, aiming for feature parity with Anthropic's official Python and
TypeScript SDKs. It ships two independent clients:

```
                       ┌─► airsclaude::messages ──HTTP──► Anthropic API     (needs an API key)
your Rust program ─────┤
                       └─► airsclaude::agent ──spawns──► `claude` CLI 2.0+  (no API key; uses the CLI's login)
```

The Messages API client suits a model that answers while you control the loop. The Agent SDK client
suits an agent that reads files, runs commands and drives its own loop. Managed Agents, the third
official surface, is not implemented.

**Install** (Rust 1.94+):

```toml
[dependencies]
airsclaude = "0.1"
tokio      = { version = "1", features = ["macros", "rt-multi-thread"] }
```

25 runnable examples ship with the crate:

```bash
ANTHROPIC_API_KEY=sk-ant-... cargo run -p airsclaude --example 01_hello   # Messages API
cargo run -p airsclaude --example agent_01_query                          # Agent SDK
```

Read on in the book: [Getting Started](https://airsstack.github.io/claudestacks/ch01-00-airsclaude-getting-started.html),
[your first Messages API call](https://airsstack.github.io/claudestacks/ch02-01-first-call.html) and
[your first Agent SDK session](https://airsstack.github.io/claudestacks/ch03-01-first-session.html).
How closely it matches the official SDKs is in
[Appendix B](https://airsstack.github.io/claudestacks/appendix-02-messages-parity.html) and
[Appendix C](https://airsstack.github.io/claudestacks/appendix-03-agent-parity.html). The
[crate README](crates/airsclaude/README.md) has the short version.

## claudevs

Deterministic tests for Claude Code plugins. It runs a plugin's hooks and scripts the way Claude
Code would, checks the wiring, and tries the plugin in its installed layout.

```
claude plugin validate --strict   manifest, skills, agents and commands; runs no hook
claudevs check                    validate ─► wiring ─► cases ─► cases in the installed layout
claude plugin eval                runs eval cases against a plugin and scores the results
```

**Install:**

```bash
curl -LsSf https://airsstack.github.io/claudestacks/install.sh | sh   # prebuilt binary, no Rust needed
cargo install claudevs-cli     # or build from source; installs a binary named `claudevs`
```

`claudevs` needs `git` on `PATH`: it git-initialises the project each case runs against.

| Command | What it does |
| --- | --- |
| `claudevs check [PATH]` | the full gate above; every stage reports even if an earlier one fails |
| `claudevs test [PATH]` | runs the plugin's test cases (`--installed` for the installed layout) |
| `claudevs doctor [PATH]` | reports what this machine can and cannot run |
| `claudevs migrate <case.yaml>` | converts a YAML case to Lua |

Exit codes: `0` clean, `1` failures found, `2` claudevs itself could not run. Add `--json` to
`test`, `check` or `doctor` for machine-readable output.

Read on in the book: [Getting Started](https://airsstack.github.io/claudestacks/ch05-00-claudevs-getting-started.html),
[Running the Gate](https://airsstack.github.io/claudestacks/ch05-04-running-the-gate.html) and the
[command reference](https://airsstack.github.io/claudestacks/appendix-01-claudevs-cli.html). The
[CLI README](crates/claudevs-cli/README.md) has the short version.

## The plugin suite

Six plugins for [Claude Code](https://www.claude.com/product/claude-code), installed from this
repository's marketplace.

| Plugin | What you get |
| --- | --- |
| `claudestacks` | core agents (`coder`, `reviewer`, `explorer`), an `orchestrate` driver, snapshot memory, `/claudestacks:discuss` |
| `claudestacks-sdlc` | an `intent → spec → plan → execute` workflow under `.claudestacks/sdlc/`, with roadmaps, ADRs and a `status` board |
| `claudestacks-guideline-rust` | Rust guidelines and a Definition of Done the agents check against |
| `claudestacks-guideline-python` | Python guidelines and a Definition of Done the agents check against |
| `claudestacks-journal` | an Obsidian-compatible journal with embedding-free recall |
| `claudestacks-cmux` | control of the [cmux](https://cmux.com) terminal |

**Install.** Most hooks and scripts run on `airsl`, a separate binary, so install it first. If it is
missing, the hooks that run on it do nothing, and the `claudestacks` plugin's session-start check
puts a notice in the session saying so.

```bash
# 1. the Lua runtime: a prebuilt binary, no Rust needed
curl -LsSf https://airsstack.github.io/airsl/install.sh | sh
# or build it from source
cargo install airsl-cli --locked
```

```
# 2. inside Claude Code: add the marketplace, then install what you want
/plugin marketplace add airsstack/claudestacks
/plugin install claudestacks@claudestacks
/plugin install claudestacks-sdlc@claudestacks
/plugin install claudestacks-guideline-rust@claudestacks
/plugin install claudestacks-guideline-python@claudestacks
/plugin install claudestacks-journal@claudestacks
/plugin install claudestacks-cmux@claudestacks
```

Which plugin needs what, and how the hooks find `airsl`, is in
[Getting Started](https://airsstack.github.io/claudestacks/ch10-00-plugins-getting-started.html).
Each plugin then has its own chapter:
[claudestacks](https://airsstack.github.io/claudestacks/ch11-00-claudestacks-plugin.html),
[claudestacks-sdlc](https://airsstack.github.io/claudestacks/ch12-00-sdlc-plugin.html),
[the guidelines](https://airsstack.github.io/claudestacks/ch13-00-guideline-plugins.html),
[claudestacks-journal](https://airsstack.github.io/claudestacks/ch14-00-journal-plugin.html) and
[claudestacks-cmux](https://airsstack.github.io/claudestacks/ch15-00-cmux-plugin.html).

Inside this repository the marketplace is already registered by `.claude/settings.json`; enable
plugins with `/plugin`.

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
