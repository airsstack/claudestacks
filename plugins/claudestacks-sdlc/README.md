# claudestacks-sdlc

AI-native SDLC for Claude Code: a committed `intent → design → plan → execute` chain with
`distill` and `triage` loops and a deterministic status board. It implements Anthropic's
[AI-native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook) at
single-author scale. Optional roadmaps, milestones and architecture decision records (ADRs)
sit above the chains.

## Install

```
/plugin marketplace add airsstack/claudestacks
/plugin install claudestacks-sdlc@claudestacks
```

Skills are namespaced `claudestacks-sdlc:<name>`. This plugin replaces `claudestacks-sdd`;
uninstall that first with `/plugin uninstall claudestacks-sdd@claudestacks`.

## Workflow

```
 intent ──► design ──► plan ──────► execute ──► walk-up: intent done, milestone roll-up
 discuss    discuss    no design    never asks, never re-proves, never refuses;
 + verify   + verify   questions;   records problems in the plan's ## Deviations;
                       one "accept  reports once at the end
                       the set?"
        ▲                                   │
        └── triage (failure → intent)       └── distill (## Review findings → config edits)
```

Discussion and verification happen only at intent and spec. Every later stage builds on
what those two settled.

## Skills

- **`intent`** — capture, convert a PRD/RFC, approve, amend, drop or un-drop an intent; may set `spec: skipped`.
- **`design`** — approved intent → `spec.md`, one question at a time; proves every claim before approval.
- **`plan`** — approved spec → `plans/NN-<topic>.md` with `depends-on`, no code; asks one question: accept the set.
- **`execute`** — runs a plan whatever the board says, flips it `executing → done` when every task completes, appends `## Review findings` and `## Deviations`, walks the intent up and rolls up its milestone.
- **`distill`** — turns review findings recurring across chains into agent-config edits, each accepted one at a time.
- **`triage`** — failure evidence → an intent with `source: triage`.
- **`roadmap`** — create, approve, amend, drop or un-drop a roadmap.
- **`milestone`** — add, approve, amend, drop, un-drop, park scope, adopt/release a chain, roll up.
- **`adr`** — the only skill that writes an ADR or changes its status.
- **`status`** — read-only board: per-artifact state, sync disagreements, progress, NEXT. Runs `scripts/status.lua` under `airsl`, otherwise the model applies the same rules.
- **`setup`** — idempotent provisioning of `.claudestacks/sdlc/`; user-invoked only.

## Agents

Leaf agents, none can spawn, flip a status, or commit (`references/artifact-chain.md` §7.3).

- **`chain-reader`** (haiku) — returns one named section from many chain files, verbatim.
- **`artifact-reviewer`** (opus) — severity-tagged review of a draft spec, plan set or ADR; report-only.
- **`task-briefer`** (sonnet) — per-task ledger or verbatim brief of one plan, so the plan never enters the main context.

`design`, `plan` and `execute` also use `claudestacks:explorer`, `coder` and `reviewer`
from the main plugin; if one is missing the skill works inline and says so.

## Artifact chain

Everything lives under `.claudestacks/sdlc/`, committed; nothing is ever deleted, only
superseded or dropped.

```
.claudestacks/sdlc/
├── prds/  rfcs/                          # optional input inboxes, read-only to the plugin
├── roadmaps/<name>/roadmap.md, NN-*.md   # optional roadmap + milestones
├── adrs/NNNN-<topic>.md                  # optional, one repository-wide series
├── REVIEW.md                             # review policy
└── 2026-08-24-webhook-reliability/       # one chain = one intent
    ├── intent.md
    ├── spec.md                           # absent until design runs; may be skipped
    └── plans/01-retry-core.md            # NN orders plans
```

Every spec and plan records a `built-on` fingerprint of the text it was written from, and
the board reports a stale, blocked, disproven or invalid chain instead of offering the
next step. A `SessionStart` hook prints the rows that need attention when `airsl` is
installed. Paths, frontmatter, states and every board rule: `references/artifact-chain.md`.
Body shapes: `references/templates.md`.

## Attribution

Stage model, artifact shapes and feedback loops follow Anthropic's
[AI-native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook). The
execution discipline descends from `claudestacks-sdd`, adapted from
[superpowers](https://github.com/obra/superpowers).

## License

Apache-2.0. See [LICENSE](./LICENSE).
