# Sessions

The `claude` binary stores every session on disk. Two things in the SDK work with that history, and
they are separate. `SessionControl` on `Options` decides what a new run does with earlier history.
`SessionArchive` reads and edits the stored transcripts without starting the binary at all.

## Continue, resume or fork a previous session

`Options::session` takes a `SessionControl`:

| Value | The new run |
|---|---|
| `New` | starts fresh with no history. This is the default. |
| `Continue { fork }` | picks up the most recent session for the working directory |
| `Resume { id, fork, resume_at }` | picks up the session named by `id` |

`fork: true` branches instead of continuing in place. The new run starts from the same history under a
new session id, and the original is untouched. `resume_at` limits a resume to the messages up to one
message id. It sits on `Resume` because the binary accepts it only together with a resume.

```rust,no_run
# async fn run() -> Result<(), Box<dyn std::error::Error>> {
use airsclaude::agent::types::SessionControl;
use airsclaude::agent::{Message, Options, query};
use futures_util::StreamExt;

// The first run starts a session. Its id arrives on the result frame.
let mut stream = query("Remember this word: pangolin.", Options::default()).await?;
let mut session = None;
while let Some(frame) = stream.next().await {
    if let Message::Result(result) = frame? {
        session = Some(result.session_id);
    }
}
let session = session.ok_or("the turn ended without a result frame")?;

// Resume it in place: the agent sees the earlier turn.
let resumed = Options::builder()
    .session(SessionControl::Resume { id: session.clone(), fork: false, resume_at: None })
    .build();
let mut stream = query("What word did I ask you to remember?", resumed).await?;
while let Some(frame) = stream.next().await {
    frame?;
}

// Or fork it: same history, a new session id.
let forked = Options::builder()
    .session(SessionControl::Resume { id: session, fork: true, resume_at: None })
    .build();
let mut stream = query("Same question, with an exclamation mark.", forked).await?;
while let Some(frame) = stream.next().await {
    frame?;
}
# Ok(())
# }
```

The options become the binary's `--continue`, `--resume <id>`, `--fork-session` and
`--resume-session-at=<uuid>` flags when the session starts. For several turns in one live session
without resuming from disk, keep a `Client`; see [Conversations](ch03-02-conversations.md).

The [example](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/agent/13_sessions)
runs all three and then reads the store.

## List past sessions or read a transcript from disk

`SessionArchive` works on the files the binary writes, under
`<config root>/projects/<encoded working directory>/<session id>.jsonl`. `SessionArchive::new` uses the
`CLAUDE_CONFIG_DIR` directory, or `$HOME/.claude` when that is unset. `SessionArchive::with_base` takes a
config root of your choosing.

| Method | Does |
|---|---|
| `list(ListOptions)` | lists stored sessions, newest first |
| `info(id, dir)` | returns metadata for one session, or `None` |
| `messages(id, MessagesOptions)` | reads the transcript |
| `rename(id, title, dir)` | sets a session's title |
| `tag(id, tag, dir)` | sets a tag, or clears it with `None` |

Everything here is local file access, so you can try it against a store you build yourself. This
snippet points an archive at an empty directory made with the `tempfile` crate, so add
`tempfile = "3"` to your dependencies.

```rust
# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
use airsclaude::agent::{ListOptions, MessagesOptions, SessionArchive};

let config_root = tempfile::tempdir()?;
let archive = SessionArchive::with_base(config_root.path());

// An empty store lists nothing.
assert!(archive.list(ListOptions::default()).await?.is_empty());

// A session that is not on disk is `None` or empty, not an error.
let id = "00000000-0000-0000-0000-000000000000";
assert!(archive.info(id, None).await?.is_none());
assert!(archive.messages(id, MessagesOptions::default()).await?.is_empty());

// Renaming and tagging need the session file to exist, so these are errors.
assert!(archive.rename(id, "my session", None).await.is_err());
assert!(archive.tag(id, Some("keep"), None).await.is_err());
# Ok(())
# }
```

An id that is not a UUID makes `info` return `None` and `messages` return an empty list. `rename` and `tag` refuse it
with `SessionError::InvalidSessionId`, refuse an empty title or tag with `SessionError::EmptyValue`,
and report a missing session as `SessionError::SessionNotFound`.

`messages` returns the whole transcript as a flat list. Each entry carries its `uuid` and `parent_uuid`,
so you can rebuild a branch yourself. The official SDKs return one reconstructed thread instead; the
difference is listed in [Divergences](appendix-04-divergences.md).

Against your own history, build the archive with `new`:

```rust,no_run
# #[tokio::main]
# async fn main() -> Result<(), Box<dyn std::error::Error>> {
use airsclaude::agent::{ListOptions, SessionArchive};

let archive = SessionArchive::new()?;
let recent = archive
    .list(ListOptions {
        dir: Some(std::env::current_dir()?),
        limit: Some(5),
        ..ListOptions::default()
    })
    .await?;
for info in &recent {
    println!("{}  {}", info.session_id.as_str(), info.summary);
}
# Ok(())
# }
```

## Start the process before you have a prompt

`Client::startup(options)` spawns the binary and completes the handshake, then hands back a `WarmQuery`.
The prompt can come later, from a queue or a person. `WarmQuery::query` takes it and returns a
`WarmSession`.

```rust,no_run
# async fn run() -> Result<(), Box<dyn std::error::Error>> {
use airsclaude::agent::{Client, Message, Options};
use futures_util::StreamExt;

let warm = Client::startup(Options::default()).await?;

// ... wait for the user's input here; the process is already running ...

let mut session = warm.query("Name one Rust crate for async I/O.").await?;
while let Some(frame) = session.stream().next().await {
    if let Message::Result(_) = frame? {
        break;
    }
}
# Ok(())
# }
```

`query` consumes the `WarmQuery`, so a second prompt does not compile. `WarmQuery::close` shuts the
session down without sending one. `WarmSession` also has `interrupt`.

## Feed turns in as they arrive

`Prompt::stream` takes any `Stream<Item = String>` and sends each item to a live session as a user
message. Use it when the messages come from a UI, a socket or another task.

```rust,no_run
# async fn run() -> Result<(), Box<dyn std::error::Error>> {
use airsclaude::agent::types::Prompt;
use airsclaude::agent::{Client, Message, Options};
use futures_util::StreamExt;

let client = Client::connect(Options::default()).await?;

let turns = futures_util::stream::iter([
    "Remember the number 7.".to_owned(),
    "Add 5 to it.".to_owned(),
    "What is the running total?".to_owned(),
]);

let mut stream = client.query(Prompt::stream(turns)).await?;
// This stream ends at the first `Result` frame.
while let Some(frame) = stream.next().await {
    if let Message::Result(result) = frame? {
        println!("{} turn(s): {}", result.num_turns, result.result);
    }
}
# Ok(())
# }
```

The stream that `query` returns ends at the first `Result` frame, and frames that arrive after it are
not delivered to it. The loop above therefore reads up to the first result, not a reply to each of the
three messages. To read one reply per turn, call `client.query` once per prompt, as in
[Conversations](ch03-02-conversations.md).

The [example](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/agent/11_streaming_input)
spaces the turns out in time and times the warm start.
