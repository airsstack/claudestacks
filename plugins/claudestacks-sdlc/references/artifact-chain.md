# Artifact Chain — paths, naming, frontmatter, states

Canonical location, naming, frontmatter schema, and state model for every artifact the
`claudestacks-sdlc` workflow reads or writes. Every skill and command resolves paths and
states from this file — skills are told "paths and states come from
`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`" and nothing else, so what follows
is normative, not descriptive.

## 1. Chain root

- The chain root is `.claudestacks/sdlc/` at the consuming repository's root.
- Everything under the chain root is committed. There is no worktree-local or
  HOME-global split: the tree is resumable from any worktree, reviewable in a PR, and
  is the audit trail.
- The plugin never writes or edits a `.gitignore`. Nothing under `.claudestacks/` is
  ever excluded from git.

## 2. Chain directory naming

- A chain directory is named `YYYY-MM-DD-<kebab-topic>`, where the date is the day the
  chain (its `intent.md`) was created.
- One chain directory holds one intent. Two chains created on the same day are
  distinguished by topic, not by a suffix or counter.

## 3. Layout

```
.claudestacks/sdlc/                        # committed; provisioned by the setup command
├── prds/                                  # optional product input docs (inbox)
│   └── .gitkeep
├── rfcs/                                  # optional technical input docs (inbox)
│   └── .gitkeep
├── REVIEW.md                              # review policy, from template
└── 2026-08-24-webhook-reliability/        # one chain = one intent
    ├── intent.md
    ├── spec.md                            # absent until design runs; may be skipped
    └── plans/
        ├── 01-retry-core.md               # NN- prefix orders plans within a chain
        └── 02-dlq.md
```

- `prds/` and `rfcs/` are top-level inboxes, siblings of the chain directories, not
  nested inside any chain.
- `REVIEW.md` lives directly under `.claudestacks/sdlc/`, one copy per repository.
- Within a chain directory: `intent.md` and `spec.md` are singular files; `plans/`
  holds one file per plan.

## 4. Superseded-artifact renaming

- A superseded spec is renamed `spec-superseded-YYYY-MM-DD.md`, where the date is the
  date of supersession (not the date the spec was originally written). After renaming,
  a new `spec.md` is written. `spec.md` — the unsuffixed name — is always the
  governing spec for the chain.
- Plans are never renamed on supersession; they keep their original `NN-<topic>.md`
  name and flip `status: superseded` in frontmatter (§7). A replacement plan does not
  reuse the superseded plan's number — it takes the next free `NN` in the chain.
- Nothing is ever deleted from the chain. A superseded or dropped artifact stays in
  the tree, in git history and on disk, distinguished only by its `status` field.

## 5. Input docs: `prds/` and `rfcs/`

- **PRD** = product input (what users need, why, success criteria) — the natural seed
  for `intent`. **RFC** = technical input (approach, trade-offs, constraints) — the
  natural seed for `design`.
- Both directories are optional always: empty or absent, they prompt nothing and
  block nothing.
- Both are **read-only to the plugin**: no skill in this plugin creates, edits, moves,
  or deletes a file inside `prds/` or `rfcs/`.
- Both are raw material with **no state machine**: files here carry no frontmatter
  requirement, no lifecycle, and are never rendered as their own rows on the status
  board — they surface only as `⤷ inputs:` annotations under the chains that cite
  them (§9).
- Both are **top-level inbox only** — flat directories, no per-intent subfolders.
  Per-intent grouping is logical, expressed through the provenance frontmatter keys
  (`derived-from-prd` / `derived-from-rfc`, §6), because one input doc pre-dates
  chains and can seed more than one chain.
- Scanning: `intent` scans both `prds/` and `rfcs/` and surfaces relevant findings;
  `design` scans `rfcs/` plus anything the intent's provenance frontmatter names.
- Named-but-missing behavior: when the user names a specific input file explicitly,
  the skill loads it as primary input. If that named file does not exist, the skill
  reports the path it looked for and asks the user for a correction — it never
  guesses or silently substitutes another file.

## 6. Frontmatter schema

Every chain artifact (`intent.md`, `spec.md`, each `plans/NN-<topic>.md`) opens with
YAML frontmatter. The full schema, all seven keys:

```yaml
---
status: draft                 # per-artifact state, §7
created: 2026-08-24
derived-from-prd:             # optional, list-valued, provenance only
  - prds/payment-v2.md
derived-from-rfc:             # optional, list-valued, provenance only
  - rfcs/webhooks-v2.md
  - rfcs/retry-budget-notes.md
source: triage                # optional; absent = human-originated
spec: skipped                 # optional, intent only; §8
depends-on: [01]              # optional, plan only; empty/absent = independent
---
```

| Key | Type | Optionality |
|---|---|---|
| `status` | string (enum, per-artifact — §7) | required on every artifact |
| `created` | date (`YYYY-MM-DD`) | required on every artifact |
| `derived-from-prd` | list of strings (paths under `prds/`) | optional; provenance only |
| `derived-from-rfc` | list of strings (paths under `rfcs/`) | optional; provenance only |
| `source` | string (e.g. `triage`) | optional; absent means human-originated |
| `spec` | string (`skipped`) | optional; intent only (§8) |
| `depends-on` | list of plan numbers (e.g. `[01]`) | optional; plan only; empty/absent means independent |

Provenance fields (`derived-from-prd`, `derived-from-rfc`) are omitted entirely — not
written as an empty list — when nothing seeded the artifact.

## 7. States and transitions

### 7.1 Per-artifact states

| Artifact | States |
|---|---|
| intent | `draft → approved → done`; `dropped` from any state |
| spec | `draft → approved`; `approved → superseded` |
| plan | `draft → approved → executing → done`; `superseded` from draft/approved/executing |

### 7.2 Transitions

| Transition | When | Flipped by |
|---|---|---|
| intent `— → draft` | file written | `intent` |
| intent `draft → approved` | user approves at the intent gate (in-session or on later re-invocation) | `intent` |
| intent `approved → done` | all the chain's plans are `done` or `superseded`, with at least one `done` | `execute` (walk-up) |
| intent `→ dropped` | user declares the idea dead | `intent` |
| spec `— → draft` | file written | `design` |
| spec `draft → approved` | user approves at the design review gate | `design` |
| spec `approved → superseded` | user requests a redesign; old file renamed per §4, new `spec.md` written | `design` |
| plan `— → draft` | file written | `plan` |
| plan `draft → approved` | user approves at the plan review gate | `plan` |
| plan `approved → executing` | execution starts task 1 | `execute` |
| plan `executing → done` | every task verified and the user accepts the completion report | `execute` |
| plan `→ superseded` | re-planning replaces it | `plan` |

### 7.3 Flip rule

A skill flips a state only as the last step of the interaction that earns it, always
after the user's explicit in-dialogue approval, always by editing the frontmatter of
the file it just worked on. Committing that change to git remains the user's separate
act — no skill in this plugin commits.

### 7.4 Reversibility

`dropped` and `superseded` are terminal but reversible by re-invocation: the skill
flips the state back on the user's explicit instruction. Nothing is ever deleted, so
git history plus the current value of the `status` field is the complete record of an
artifact's life. The only transitions that fire without a fresh approval question are
the mechanical pair: plan `approved → executing` and the intent's `done` roll-up —
both are consequences of state already earned elsewhere, not new decisions.

## 8. Spec skip

Small chains may go straight from intent to plan, skipping design. During the intent
dialogue the user may set `spec: skipped` in the intent's frontmatter; the skill
records a one-line reason next to it in the body. The `plan` skill accepts an
`approved` intent directly, with no `spec.md` present, only when this flag is set on
that intent — `plan` reads the flag but never sets it itself.

## 9. NEXT derivation (status board)

These are the rules the status board's NEXT column executes — by `scripts/status.lua`
when `airsl` is installed, and by hand, from this file, when it is not (the fallback
tier of `/claudestacks-sdlc:status`). Derivation is states-only, no judgment call:

- intent `draft` → `approve or drop`
- intent `approved`, no spec, no skip flag → `design`
- intent `approved` with `spec: skipped` and no plans yet → `plan`
- spec `draft` → `approve spec`
- spec `approved`, no plans yet → `plan`
- plan `approved` with every plan named in its `depends-on` already `done` →
  `execute NN`
- plan `approved` with any plan named in its `depends-on` not yet `done` →
  `wait (dependencies pending)`
- plan `executing` → shown as executing (no further derivation; it is mid-flight)
- all plans in the chain `done` → chain complete

Triage-sourced intents (`source: triage`) are tagged `(triage)` in the STATE column
alongside their derived state. Chains whose intent is `dropped`, or whose every plan
is `done`/`superseded`, are listed under a collapsed `DONE/DROPPED` tail section
(count only), unless a verbose flag in the command's dialogue asks for the detail.

A chain whose intent, spec, or any plan names input docs via the provenance frontmatter keys
(`derived-from-prd` / `derived-from-rfc`, §6) renders a `⤷ inputs:` annotation line
under that chain's row, listing the named files. Input docs never get their own row
(§5); this annotation is their only appearance on the board.

---

This file owns paths, naming, frontmatter keys, and states. Artifact **body shapes** —
the sections inside an `intent.md`, `spec.md`, or plan file — are owned by
`references/templates.md`; change one, check the other.
