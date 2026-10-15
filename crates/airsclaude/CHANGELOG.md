# Changelog

All notable changes to `airsclaude` are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the crate follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-15

Initial release. Minimum supported Rust version: 1.94. The crate declares no Cargo features.

### Added

- **Messages API client** — `POST /v1/messages` with SSE streaming and a full accumulator; custom
  tools with `strict` and all four `tool_choice` forms; prompt caching with both TTL tiers and
  per-tier usage accounting; extended thinking and effort levels; JSON-Schema structured output;
  image and PDF input; citations; token counting; the Message Batches API; `GET /v1/models` with the
  capability-discovery payload.
- **Agent SDK client** — drives a `claude` binary 2.0.0+ as a subprocess. One-shot `query` and a
  stateful `Client`; 45 `Options` fields; in-process MCP tools written in Rust; hooks; the six-mode
  permission system with a `PermissionPolicy` callback; MCP elicitation; programmatic subagents;
  session continue, resume, fork and resume-at-a-message; on-disk session inspection; warm start;
  22 mid-session control and introspection operations.
- 25 runnable examples: 11 for the Messages API, 14 for the Agent SDK.

### Not included

- Managed Agents (`/v1/agents`, `/v1/sessions`).
- Neither client is at complete parity with the official SDKs; the feature-parity documents under
  `docs/` list every gap, and `docs/divergences.md` every deliberate difference.
