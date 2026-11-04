# Controlling the Agent

Everything you decide about a session goes on one value, `Options`. `query` and `Client::connect` both
take it, so the same options configure a one-shot run and a long-lived session. Most of them are fixed
when the session starts. A few can change while it runs, through the `Client`.

These recipes assume the setup in [The Agent SDK](ch03-00-agent-sdk.md): a `claude` binary the SDK can
find, and credentials that binary already holds.

## Set the model, pre-approve tools, choose a directory

The core of `Options` is a system prompt, a model, the tools approved without asking, and where the
agent works.

```rust,no_run
# async fn run() -> Result<(), Box<dyn std::error::Error>> {
use airsclaude::agent::{Message, Options, PermissionMode, query};
use airsclaude::types::ModelId;
use futures_util::StreamExt;

let options = Options::builder()
    .system_prompt("You are a terse code reader. Answer in at most three lines.")
    .model(ModelId::claude_sonnet_4_5())
    .permission_mode(PermissionMode::Plan)
    .allowed_tools(vec!["Read".to_owned(), "Grep".to_owned(), "Glob".to_owned()])
    .disallowed_tools(vec!["Bash".to_owned()])
    .cwd(std::env::current_dir()?)
    .max_turns(4)
    .build();

let mut stream = query("Which files are in src/agent?", options).await?;
while let Some(frame) = stream.next().await {
    if let Message::Result(result) = frame? {
        println!("finished after {} turn(s)", result.num_turns);
    }
}
# Ok(())
# }
```

`allowed_tools` names tools the binary approves without asking, and `disallowed_tools` names tools it
denies. Naming a tool in `allowed_tools` does not remove the others from the agent, and the binary's
own message says a bare entry there approves the whole tool before any [permission
policy](ch03-04-your-code-in-the-loop.md) is consulted. `cwd` is where the subprocess runs, and
`add_dir` names further directories its tools may reach. `max_turns` stops the agent after that many
turns even if the work is unfinished.

Two timeouts bound the subprocess. `control_request_timeout` limits how long the SDK waits for the
binary to answer a control request, and `shutdown_grace` sets the window the binary gets to exit
cleanly. `require_min_version(true)` turns an out-of-date `claude` binary into an error instead of a
warning.

The [example](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/agent/02_options)
adds an environment variable for the child process and prints the options it built.

## Configure thinking, effort, skills, plugins, sandbox or betas

These options become flags on the `claude` process, so they are fixed once the session has started.

| Option | What it sets |
|---|---|
| `thinking` | extended thinking: a mode and whether the thinking is shown |
| `effort` | how hard the model works on each turn |
| `setting_sources` | which settings files the binary loads: user, project, local |
| `skills` | which skills are allowed: all of them, or a named list |
| `plugin` | a plugin directory to load |
| `sandbox` | the sandbox configuration |
| `betas` | beta feature flags |

```rust,no_run
# async fn run() -> Result<(), Box<dyn std::error::Error>> {
use airsclaude::agent::types::{
    SandboxConfig, SettingSource, Skills, ThinkingConfig, ThinkingDisplay, ThinkingMode,
};
use airsclaude::agent::{Options, PermissionMode, query};
use airsclaude::types::EffortLevel;
use futures_util::StreamExt;

let options = Options::builder()
    .permission_mode(PermissionMode::Plan)
    .thinking(ThinkingConfig {
        mode: ThinkingMode::Enabled { budget_tokens: Some(2048) },
        display: Some(ThinkingDisplay::Summarized),
    })
    .effort(EffortLevel::Low)
    .setting_sources([SettingSource::User, SettingSource::Project])
    .settings_inline(serde_json::json!({ "includeCoAuthoredBy": false }))
    .sandbox(SandboxConfig {
        enabled: Some(true),
        fail_if_unavailable: Some(false),
        ..SandboxConfig::default()
    })
    .skills(Skills::All)
    .max_turns(2)
    .build();

let mut stream = query("Why does Rust have both String and &str?", options).await?;
while let Some(frame) = stream.next().await {
    frame?;
}
# Ok(())
# }
```

Some of these interact:

- `thinking` wins. `max_thinking_tokens` is read only when `thinking` is unset.
- `skills` does not add a flag of its own. `Skills::All` allows the bare `Skill` tool, and
  `Skills::List` allows one `Skill(<name>)` entry per name.
- `sandbox` is merged into the settings the binary receives, so it cannot be combined with
  `settings_path`. Starting a session with both fails with `AgentError::SandboxWithSettingsPath`.
  `settings_inline`, as above, is fine.

The [example](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/agent/09_startup_options)
also sets `fallback_model`, `strict_mcp_config`, a session title and `betas`.

## Delegate to subagents

A subagent is a named helper the main agent can hand work to. You define it in Rust and register it
under the name the model uses to call it.

```rust
# fn main() -> Result<(), Box<dyn std::error::Error>> {
use airsclaude::agent::{AgentDefinition, Options, PermissionMode};
use airsclaude::types::ModelId;

let summarizer = AgentDefinition::new(
    "Summarizes a file in three bullet points.",
    "You summarize source files. Reply with exactly three bullet points.",
)?
.with_tools(vec!["Read".to_owned(), "Glob".to_owned()])
.with_model(ModelId::claude_haiku_4_5())
.with_max_turns(3);

// A definition with no description or prompt is refused when it is built.
assert!(AgentDefinition::new("", "You summarize source files.").is_err());

let options = Options::builder()
    .permission_mode(PermissionMode::Plan)
    .agent("summarizer", summarizer)
    .build();
# let _ = options;
# Ok(())
# }
```

The description is what the main agent reads when it chooses a helper. The prompt is the helper's own
system prompt. Every other field overrides the parent session when you set it and inherits from it when
you do not, which makes a subagent the place to run a narrow job on a cheaper model with fewer tools.

`agent_name` is a different control: it picks one agent to run as the session itself instead of the
default assistant.

The [example](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/agent/10_subagents)
runs two helpers and shows how a turn written by a subagent carries the id of the call that started it.

## Change the model or permission mode without restarting

Once you hold a `Client`, you can steer the running session.

```rust,no_run
# async fn run() -> Result<(), Box<dyn std::error::Error>> {
use airsclaude::agent::{Client, Options, PermissionMode};
use airsclaude::types::ModelId;

let client = Client::connect(Options::builder().permission_mode(PermissionMode::Plan).build()).await?;

client.set_model(ModelId::claude_haiku_4_5()).await?;
client.set_permission_mode(PermissionMode::AcceptEdits).await?;

let status = client.mcp_status().await?;
println!("{} MCP server(s)", status.servers.len());

if let Some(receipt) = client.interrupt().await? {
    println!("{} item(s) still queued", receipt.still_queued.len());
}
# Ok(())
# }
```

Each of these is a control request over the same pipe the messages arrive on, so `interrupt` works
while a turn is streaming. They exist only while a `Client` is alive. A `query` stream owns its session
and drops it when the stream ends; [Conversations](ch03-02-conversations.md) covers when to keep a
`Client` instead.

The `Client` also offers `set_max_thinking_tokens`, `apply_flag_settings`, `reconnect_mcp_server`,
`toggle_mcp_server`, `read_file`, `background_tasks`, `stop_task`, `rewind_files`, `get_usage`,
`get_context_usage`, `reload_plugins` and `reload_skills`. When the binary refuses one, the call returns
an `Err` carrying its answer. The
[example](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/agent/12_live_control)
calls each of them and prints what comes back.

To run code of your own at points in the turn, rather than steer from outside it, see
[Your Code in the Loop](ch03-04-your-code-in-the-loop.md).
