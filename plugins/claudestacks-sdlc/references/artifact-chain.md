# Artifact Chain — paths, naming, frontmatter, states

Canonical location, naming, frontmatter schema, and state model for every artifact the
`claudestacks-sdlc` workflow reads or writes. Every skill resolves paths and
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
.claudestacks/sdlc/                        # committed; provisioned by the setup skill
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
YAML frontmatter. The full schema, all nine keys:

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
built-on: 7df83709971b        # spec and plan; §10
disproves: 7df83709971b       # optional, plan only; §10
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
| `built-on` | fingerprint (12 hex characters, §10) | required on an `approved` spec and on an `approved` or `executing` plan; written when the artifact is drafted |
| `disproves` | fingerprint (12 hex characters, §10) | optional; plan only; written by `execute`, never removed |

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
| intent `approved → done` | the chain is complete: all its plans are `done` or `superseded`, with at least one `done`, and neither C1 nor C2 holds (§10.4) | `execute` (walk-up) |
| intent `→ dropped` | user declares the idea dead | `intent` |
| spec `— → draft` | file written | `design` |
| spec `draft → approved` | user approves at the design review gate | `design` |
| spec `approved → superseded` | user requests a redesign; old file renamed per §4, new `spec.md` written | `design` |
| plan `— → draft` | file written | `plan` |
| plan `draft → approved` | user approves at the plan review gate | `plan` |
| plan `draft → approved` | user names the plan and asks for it to be executed, and the plan's `built-on` equals its authority's current fingerprint (§10.2) — the instruction is the approval, so the gate is satisfied rather than bypassed | `execute` |
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
tier of `/claudestacks-sdlc:status`). The board scans the chain root one level deep:
every directory is a chain except `prds/` and `rfcs/`, and a plain file is not a row.
Derivation reads states and fingerprints only, no judgment call. For a chain whose
intent is `approved`, the sync rules of §10 are applied first; the list below decides
NEXT only when none of them does:

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
- the chain is complete (§10.4) → STATE `chain complete`, NEXT `execute walk-up`
- every plan `superseded` and none `done` → `plan`

Triage-sourced intents (`source: triage`) are tagged `(triage)` in the STATE column,
after every other part of the cell. Chains whose intent is `done` or `dropped` are
listed under a collapsed `DONE/DROPPED` tail section (count only), unless a verbose
flag in the status skill's dialogue asks for the detail. A complete chain whose intent
is still `approved` is **not** collapsed: it is a row reading `chain complete` →
`execute walk-up`, so a walk-up that was never performed stays visible.

A chain whose intent, spec, or any plan names input docs via the provenance frontmatter keys
(`derived-from-prd` / `derived-from-rfc`, §6) renders a `⤷ inputs:` annotation line
under that chain's row, listing the named files. Input docs never get their own row
(§5); this annotation is their only appearance on the board.

## 10. Fingerprints and sync rules

Related artifacts must still agree: a spec with the intent it was written from, a plan
with the spec it was written from. The board checks that mechanically, for every chain
whose intent is `approved`. A chain whose intent is `draft`, `dropped` or `done` is not
checked.

### 10.1 Fingerprints

The **fingerprint** of an artifact is the first 12 hexadecimal characters of the
SHA-256 of its body. The body is every line after the line that closes the frontmatter
(the first line equal to `---` after line 1), with one trailing carriage return removed
from each line and each line terminated by exactly one `\n`. The frontmatter is
excluded, so a `status` flip never changes a fingerprint and any edit to the text does.
A file whose first line is not `---`, or whose frontmatter is never closed, has no
fingerprint.

`scripts/lib/fingerprint.lua` computes it for the board. Without `airsl`, compute it
with `sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <file>`, which prints the 12
characters and exits 0, or prints nothing and exits 2 when the file has no fingerprint.

### 10.2 The two keys

An artifact's **authority** is what it was written from. A spec's authority is the
chain's `intent.md`. A plan's authority is the chain's `spec.md`; when the intent
carries `spec: skipped` and no `spec.md` exists (§8), it is the chain's `intent.md`.

- `built-on` holds the fingerprint of the authority the artifact was written against,
  or last re-confirmed against. It is written when the artifact is drafted. The skill
  that owns the artifact — `design` for a spec, `plan` for a plan — compares it with
  the authority's current fingerprint before flipping `draft → approved`, says so when
  they differ, and writes the current fingerprint in the same edit as the flip.
  `execute` may approve a `draft` plan by being asked to run it (§7.2) only when that
  plan's `built-on` already equals its authority's current fingerprint; otherwise it
  refuses and names `plan`, because nobody has read the plan against the changed text.
  **Re-confirmation** rewrites the key on an approved artifact: the owning skill asks
  whether the artifact still holds against its authority as that authority now reads,
  and on an explicit yes writes the current fingerprint and changes nothing else. It is
  never inferred, and never performed by `execute`.
- `disproves` holds the fingerprint of the authority whose claim a plan's execution
  showed to be wrong. `execute` writes it on the plan it is running. It holds one
  fingerprint, a later disproof by the same plan overwrites it, and it is never
  removed: it stops matching, and so stops having any effect, once the authority's text
  changes.

A **live plan** is `approved` or `executing`. A **settled plan** is `done` or
`superseded`.

### 10.3 Invalid results

An invalid result replaces the whole STATE cell and its NEXT is `fix <chain>`. When
several hold, the cell shows the first in this order; within a rule, the lowest plan
number.

| # | Condition | STATE |
|---|---|---|
| I1 | an artifact is missing, unreadable or unparseable, or carries an unknown status | `INVALID (<file>: <reason>)`; a missing `intent.md` reads `INVALID (intent.md missing)`, with no colon |
| I2 | `spec.md` has a status other than `draft` or `approved` | `INVALID (spec.md: unknown status <status>)` |
| I3 | `spec.md` is `approved` and has no `built-on` | `INVALID (spec.md: missing built-on)` |
| I4 | a live plan exists, there is no `spec.md`, and the intent has no `spec: skipped` | `INVALID (plans/NN: no spec and no skip flag)` |
| I5 | a live plan has no `built-on` | `INVALID (plans/NN: missing built-on)` |

A superseded spec is renamed (§4), so `spec.md` itself is never legitimately
`superseded`.

### 10.4 Conditions, STATE and NEXT

| # | Condition | STATE part | NEXT |
|---|---|---|---|
| C1 | `spec.md` is `approved` and its `built-on` differs from the intent's fingerprint | `spec stale (intent changed)` | `design` |
| C2 | a plan that is not `superseded` carries `disproves` equal to the current fingerprint of its authority | `spec disproven by plan NN`; on the spec-skip path `intent disproven by plan NN` | `design`; on the spec-skip path `intent` |
| C3 | a live plan's authority is `spec.md` and that spec is `draft` | `plan NN <status>: blocked (spec not approved)` | `approve spec` |
| C4 | a live plan's `built-on` differs from its authority's fingerprint, and C3 does not hold for it | `plan NN <status>: stale (spec changed)`; on the spec-skip path `plan NN <status>: stale (intent changed)` | `plan` |

`<status>` is the plan's own status. C3 and C4 read live plans only. C2 reads every plan
except `superseded` ones, because a plan can finish its run with the debt still owed;
when several plans satisfy it, the part names the lowest number.

**STATE.** When no invalid result holds, the cell is built in this order,
comma-separated, with the `(triage)` tag last:

1. the C1 part, if C1 holds;
2. the C2 part, if C2 holds;
3. for a chain with plans, one part per plan in number order: `plan NN <status>`, or the
   C3 or C4 form for a plan they hold for;
4. for a chain without plans, the single state of §9 (`intent approved`,
   `intent approved (spec skipped)`, `spec draft`, `spec approved`), except that
   `spec approved` is omitted when C1 holds.

**NEXT.** The first of C1, C2, C3, C4 that holds decides it, per the table. Only when
none holds does the list in §9 apply. A chain with a standing C2 therefore never offers
`execute NN`.

**A chain is complete** when every plan is settled, at least one is `done`, and neither
C1 nor C2 holds. Only a complete chain reads `chain complete` and only a complete chain
is walked up to `done` (§7.2). While C1 or C2 stands the cell is built by the list
above and the intent stays `approved`.

---

This file owns paths, naming, frontmatter keys, and states. Artifact **body shapes** —
the sections inside an `intent.md`, `spec.md`, or plan file — are owned by
`references/templates.md`; change one, check the other.
