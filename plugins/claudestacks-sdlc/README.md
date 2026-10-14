# claudestacks-sdlc

AI-native SDLC workflow for Claude Code: a committed `intent → design → plan → execute`
chain with `distill` and `triage` feedback loops and a deterministic status board. Six
skills, guided one question at a time, implement Anthropic's
[AI-native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook) at
single-author scale — every stage gates on frontmatter state, and nothing in the chain is
ever deleted. The board also checks that related artifacts still agree, and optional
roadmaps and milestones sit above the chains with progress that is counted, never
written down.

## Install

```
/plugin marketplace add airsstack/claudestacks
/plugin install claudestacks-sdlc@claudestacks
```

Skills are namespaced `claudestacks-sdlc:<name>`.

This plugin replaces `claudestacks-sdd`. If you have the retired plugin installed, uninstall
it first:

```
/plugin uninstall claudestacks-sdd@claudestacks
```

then install `claudestacks-sdlc@claudestacks` as above.

## Workflow

The pipeline is four stages plus two feedback loops, each a guided dialogue skill — one
question at a time, never a battery.

- **`intent`** — a rough idea (or an existing PRD/RFC, or a re-invocation) becomes
  `<date>-<topic>/intent.md`. Scans `prds/` and `rfcs/` for seed material, refuses to hold
  solution content, proposes splitting multi-scope problems into sibling chains. Writes:
  `status: draft`, or `approved` if the user approves in-session; may set
  `spec: skipped` to route straight to `plan`.
- **`design`** — an `approved` intent becomes `spec.md`. Refuses a `draft`, `dropped`, or
  `done` intent, naming the file and the command that advances it. Explores 2–3 approaches
  with a recommendation, self-reviews for placeholders and scope creep, traces every section
  back to the intent. Writes: `draft → approved` at the user's design-review approval.
- **`plan`** — an `approved` spec (or an `approved` intent carrying `spec: skipped`) becomes
  one or more `plans/NN-<topic>.md` files, each with an explicit `depends-on:` so independent
  plans are visibly parallelizable across worktrees. A plan follows the playbook's
  `plan.md` — files that change, order of work, risks, proof — and carries no code; the
  code is written in `execute`. Asks the author nothing until the set is written, then asks
  once: accept the whole set. Writes: `draft → approved` for every plan in the set together.
- **`execute`** — a plan, referenced as `<chain>/<NN>`, becomes a reviewed, verified diff.
  Takes the instruction to run an unchanged `draft` plan as its approval, resumes an
  `executing` one, and does not silently re-run a `done` or `superseded` one; warns if a
  `depends-on` plan isn't `done` yet. Cuts the plan's tasks into batches of genuinely
  independent work and runs each batch as parallel `coder` spawns, with subagent detail
  kept on disk through the main plugin's context-handoff protocol. Every fact a task asserts about something it
  does not create is proven first — a symbol lookup for structure, a throwaway test that
  is actually run for behaviour — because the plan is not evidence for itself. One review
  spawn and one fix round per batch, deliberately: extra rounds find shrinking code
  findings while the defects that matter are wrong premises no review can catch. Appends
  durable `## Review findings`, `## Probe results` and `## Deviations` sections to the
  plan before flipping it `done`; walks the intent up to `done` once every sibling plan is
  `done` or `superseded` with at least one `done`, no stale spec stands, and no spec or
  intent is disproven, then rolls up the chain's milestone and roadmap if it has one.
- **`distill`** (loop) — scans `## Review findings` across chains for a finding recurring in
  two or more chains, and proposes a concrete, minimal config edit per finding — accept /
  edit / skip, one at a time. Never edits without a per-proposal accept.
- **`triage`** (loop) — failure evidence (a pasted log, a file, a description) becomes a new
  `intent.md` with `source: triage` and the evidence quoted verbatim, entering the same
  queue as any other intent.

## Artifact chain

Everything lives under `.claudestacks/sdlc/` at the consuming repo's root, committed —
nothing here is git-ignored, and nothing is ever deleted, only superseded or dropped:

```
.claudestacks/sdlc/
├── prds/                                  # optional product input docs (inbox)
│   └── .gitkeep
├── rfcs/                                  # optional technical input docs (inbox)
│   └── .gitkeep
├── roadmaps/                              # optional; created by the roadmap skill
│   └── platform/
│       ├── roadmap.md
│       └── 01-auth.md                     # one file per milestone
├── REVIEW.md                              # review policy, from template
└── 2026-08-24-webhook-reliability/        # one chain = one intent
    ├── intent.md
    ├── spec.md                            # absent until design runs; may be skipped
    └── plans/
        ├── 01-retry-core.md               # NN- prefix orders plans within a chain
        └── 02-dlq.md
```

`references/artifact-chain.md` is the canonical authority for paths, naming, the frontmatter
schema, and the full state/transition tables — every skill and the status skill's fallback
path resolve against it rather than restating the rules locally.

## Keeping artifacts in sync

A spec is written from an intent and a plan from a spec, and each can change after the
other was approved. Every spec and plan therefore records, in a `built-on` frontmatter
key, a fingerprint of the text it was written against: the first 12 hex characters of
the SHA-256 of that artifact's body. The board compares the two on every render and
reports a disagreement instead of offering the next step:

| The board says | It means | Cleared by |
|---|---|---|
| `spec stale (intent changed)` | the intent was edited after its spec was approved | `design` |
| `plan NN <status>: stale (spec changed)` | the spec was edited or replaced after the plan was written against it | `plan` |
| `plan NN <status>: stale (intent changed)` | the same, on a spec-skip chain, where the plan was written against the intent | `plan` |
| `plan NN <status>: blocked (spec not approved)` | a live plan sits beside a draft spec | `design` |
| `spec disproven by plan NN` | executing that plan showed a claim of the spec to be wrong | `design` |
| `intent disproven by plan NN` | the same, on a spec-skip chain, where the claim was the intent's | `intent` |
| `INVALID (… missing built-on)` | an approved artifact carries no fingerprint | `design` or `plan` |

Nothing is repaired automatically: the owning skill asks whether the artifact still
holds and records the answer. `intent`, `design`, `plan` and `execute` read the board
before they act. `execute` refuses a plan while the board reads `INVALID`, a stale spec or
a disproven spec or intent (except for the plan that raised it), and while that plan's own
part reads `stale` or `blocked`; a part naming a different plan does not stop it. A chain
with an approved spec or a live plan from before version 0.2.0 carries no `built-on` and
reads `INVALID` until `design` or `plan` re-confirms it.

When every plan is finished and no disagreement stands, the board reads `chain complete`
instead, and the next step is `execute walk-up`.

## Roadmaps and milestones

Both are optional. A repository that never creates one sees no new question and no new
directory, and a single chain remains a complete use of the plugin.

- **`roadmap`** — creates `roadmaps/<name>/roadmap.md` with its first milestones, and
  approves, amends, drops or un-drops a roadmap. A repository may hold any number.
- **`milestone`** — works on one milestone, `roadmaps/<name>/NN-<topic>.md`: add,
  approve, amend, drop, un-drop, park scope as `draft` intents, adopt or release a chain,
  and roll up.

A chain joins a milestone through one intent frontmatter key, `milestone:
<roadmap>/<NN>`, and stays where it is at the chain root. No file stores a progress
figure: the board counts each milestone's member chains every time it renders, so every
agent gives the same answer. A milestone closes by roll-up when every member chain is
`done` or `dropped` with at least one `done`, and a roadmap closes the same way from its
milestones. A closed milestone takes no new work.

## Session-start hook

`hooks/hooks.json` declares one `SessionStart` hook. It prints one line counting the
open chains and the rows that need attention, then those rows: anything invalid, stale,
blocked, disproven or complete, any plan still marked `executing`, and the open chain or
milestone row left under a dropped milestone or roadmap. It needs the `airsl` runtime,
prints nothing without it, and never fails a session.

## Operational skills

Two more skills serve the chain rather than advance it. They ship under `skills/` like
the six pipeline skills and the two roadmap skills above — ten skills in all; nothing
here uses a `commands/` directory.

- **`/claudestacks-sdlc:status`** — a deterministic board over every chain, roadmap and
  milestone: state per artifact, every sync disagreement, each milestone's progress, and
  a derived NEXT action. Runs `scripts/status.lua` under the `airsl` runtime
  when it's installed; falls back to the model performing the same scan by the rules in
  `references/artifact-chain.md` when it isn't. Same output shape either way, never a hard
  failure. Read-only, so Claude may reach for it on its own.
- **`/claudestacks-sdlc:setup`** — idempotent provisioning of the committed chain root:
  `.claudestacks/sdlc/`, `prds/.gitkeep`, `rfcs/.gitkeep`, and `REVIEW.md` from
  `references/review-policy.md`. Creates only what's missing, never overwrites, never
  touches `.gitignore`, and reports what it created versus found. Carries
  `disable-model-invocation: true` — it writes into your repository, so only you can
  trigger it.

## Agents

Three leaf agents ship under `agents/`, namespaced `claudestacks-sdlc:<name>`. None
declares the `Agent` tool, so none can spawn anything: the skill on the main thread
does every spawn, receives every report, and holds every user gate. No agent flips an
artifact `status` and no agent commits — `references/artifact-chain.md` §7.3 keeps both
where they were.

- **`chain-reader`** (haiku · low) — mechanical section extractor. Given a glob and a
  heading, returns each match's content verbatim, tagged with its file. It does not
  group, count, or judge; the calling skill does that. `distill` spawns it to pull
  `## Review findings` out of every plan in the chain root without loading the plan
  bodies into the main context.
- **`artifact-reviewer`** (opus · high) — judges a draft `spec.md`, or a draft plan set,
  against its upstream authority and the criteria in `references/artifact-review.md`.
  Report-only, severity-tagged. `design` and `plan` spawn it in place of self-reviewing
  an artifact they just wrote themselves.
- **`task-briefer`** (sonnet · low) — mechanical brief extractor over one plan file. In
  `ledger` mode it returns a row per task (number, title, files, verifications); in
  `brief` mode it writes one task's content verbatim to a handoff file and returns only
  the summary, plus a list of every fact that task asserts about something it does not
  itself create. It never checks whether an asserted fact is true — that is the
  orchestrator's call. `execute` spawns it so a plan of tens of kilobytes never enters
  the main thread's context.

The read-heavy locating steps in `design` and `plan` reuse `claudestacks:explorer` from
the main plugin, and `execute` reuses `claudestacks:coder`, `claudestacks:explorer` and
`claudestacks:reviewer` for its per-batch pipeline. Those are cross-plugin dependencies,
so they degrade: if an agent does not resolve, the skill does the work inline and says
which agent was unavailable.

## Attribution

The stage model, the artifact shapes, and the `distill`/`triage` feedback loops implement
Anthropic's [AI-native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook),
which is the authority where the two lineages disagree. The execution discipline — gated
design dialogue, test-first execution, a user commit gate — descends from
`claudestacks-sdd`, itself adapted from the
[superpowers](https://github.com/obra/superpowers) plugin
(`superpowers@claude-plugins-official`). Its plan format, which wrote complete code into the
plan, was dropped for the playbook's `plan.md`: no code is written before the plan is
accepted.

## License

Apache-2.0. See [LICENSE](./LICENSE).
