# The Messages API

The Messages API is how you talk to Claude over HTTP. You send a list of messages and get one back.
`airsclaude` wraps that API in a typed client: you build a request, send it, and read a typed reply.

This chapter takes you from an empty project to a streamed tool call, then through the features you
reach for next.

| Page | What you do |
|---|---|
| [Your First Call](ch02-01-first-call.md) | Build a client, send a request, read the reply |
| [Streaming](ch02-02-streaming.md) | Show the answer as it is generated |
| [Tools](ch02-03-tools.md) | Let Claude call your code |
| [Cost and Latency](ch02-04-cost-and-latency.md) | Reuse a prompt prefix, let the model reason first |
| [Richer Input](ch02-05-richer-input.md) | Send images and documents |
| [Structured Results](ch02-06-structured-results.md) | Get output that matches a schema |
| [Models](ch02-07-models.md) | Find out what a model supports |
| [Building Something Larger](ch02-08-building-larger.md) | Put the pieces together |

## What you need

An API key in `ANTHROPIC_API_KEY`, and access on that key to the model a page names. If a model is
not available to you, swap the `ModelId::claude_*()` call for one that is.

The example programs live in the
[examples directory](https://github.com/airsstack/claudestacks/tree/main/crates/airsclaude/examples/messages)
and are registered by name, so they run from anywhere in the workspace:

```bash
ANTHROPIC_API_KEY=sk-ant-... cargo run -p airsclaude --example 01_hello
```

The snippets in this chapter call the live API. They are compiled with the rest of the book but never
run, so none of them shows output.
