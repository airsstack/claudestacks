# Artifact Chain — paths, naming, frontmatter, states

Normative. Every skill resolves paths and states from this file. The Lua under
`scripts/lib/` is its code mirror; the two must agree. Body shapes live in
`references/templates.md`.

## 1. Chain root

- `.claudestacks/sdlc/` at the consuming repository's root. Everything under it is
  committed; no worktree-local or HOME-global split.
- The plugin never writes or edits a `.gitignore`; nothing under `.claudestacks/` is
  excluded from git.

## 2. Chain directory naming

- `YYYY-MM-DD-<kebab-topic>`, dated the day its `intent.md` was created.
- One directory = one intent. Same-day chains differ by topic, never by suffix or counter.

## 3. Layout

```
.claudestacks/sdlc/                        # committed; provisioned by the setup skill
├── prds/.gitkeep                          # optional product input docs (inbox)
├── rfcs/.gitkeep                          # optional technical input docs (inbox)
├── roadmaps/                              # optional; created on first use by the roadmap skill
│   └── platform/                          # one directory per roadmap; the engineer names it
│       ├── roadmap.md
│       └── 01-auth.md                     # one file per milestone; NN orders them
├── adrs/                                  # optional; created on first use by the adr skill
│   └── NNNN-<topic>.md                    # one file per decision; NNNN orders them (§13)
├── REVIEW.md                              # review policy, from template; one per repository
└── 2026-08-24-webhook-reliability/        # one chain = one intent
    ├── intent.md
    ├── spec.md                            # absent until design runs; may be skipped
    └── plans/
        ├── 01-retry-core.md               # NN- prefix orders plans within a chain
        └── 02-dlq.md
```

- `prds/` and `rfcs/` are top-level inboxes, never nested in a chain.
- `roadmaps/` and `adrs/` are optional and never created by `setup`. Chains stay flat at
  the root whether or not they belong to a milestone (§11). `adrs/` is one
  repository-wide series (§13).

## 4. Superseded-artifact renaming

- A superseded spec is renamed `spec-superseded-YYYY-MM-DD.md` (date of supersession),
  then a new `spec.md` is written. Unsuffixed `spec.md` always governs.
- Plans are never renamed: they flip `status: superseded` (§7). A replacement takes the
  next free `NN`, never the superseded plan's number.
- Nothing is ever deleted from the chain; a superseded or dropped artifact differs only by
  `status`.

## 5. Input docs: `prds/` and `rfcs/`

- PRD = product input, seeds `intent`. RFC = technical input, seeds `design`.
- Optional always: empty or absent, they prompt and block nothing.
- Read-only to the plugin: no skill creates, edits, moves or deletes a file in them.
- No state machine: no frontmatter requirement, no lifecycle, no board row. They appear
  only as `⤷ inputs:` annotations under chains that cite them (§9).
- Flat inboxes, no per-intent subfolders; grouping is via `derived-from-prd` /
  `derived-from-rfc` (§6). One doc may seed several chains.
- `intent` scans `prds/` and `rfcs/`; `design` scans `rfcs/` plus whatever the intent's
  provenance keys name.
- A file the user names explicitly is loaded as primary input. If it does not exist, the
  skill reports the path it looked for and asks for a correction — never guesses or
  substitutes.

## 6. Frontmatter schema

Every chain artifact (`intent.md`, `spec.md`, each `plans/NN-<topic>.md`) opens with YAML
frontmatter. All twelve keys:

| Key | Type | Optionality |
|---|---|---|
| `status` | enum per artifact (§7) | required |
| `created` | date `YYYY-MM-DD` | required |
| `derived-from-prd` | list of paths under `prds/` | optional; provenance only; omitted (not `[]`) when nothing seeded it |
| `derived-from-rfc` | list of paths under `rfcs/` | optional; provenance only; omitted (not `[]`) when nothing seeded it |
| `source` | string, e.g. `triage` | optional; absent = human-originated |
| `spec` | `skipped` | optional; intent only (§8) |
| `milestone` | `<roadmap>/<NN>` | optional; intent only (§11); absent = simple chain |
| `depends-on` | list of plan numbers, e.g. `[01]` | optional; plan only; empty/absent = independent |
| `adrs` | list of ADR numbers, e.g. `[0003]` | optional; spec only; ADRs the design relies on (§13) |
| `built-on` | fingerprint, 12 hex (§10) | required on an `approved` spec and an `approved`/`executing` plan; written at drafting |
| `disproves` | fingerprint, 12 hex (§10) | optional; plan only; written by `execute`, never removed |
| `disproves-adr` | list of ADR numbers | optional; plan only; ADRs the plan's execution disproved (§10.4); written by `execute`, never removed |

- Roadmap and milestone files carry only `status` and `created` (§11).
- ADR files carry `status`, `created`, optional `supersedes` and `sealed` (§13). `sealed`
  and `supersedes` are read only from files in `adrs/`; ignored on chain artifacts.
- Number lists (`adrs`, `disproves-adr`, `supersedes`) read like `depends-on`: block-list
  items, or every run of digits in any string value (inline list or bare scalar such as
  `adrs: 3`). Numeric tokens normalise to four digits (`3` → `0003`). A non-numeric block
  item passes through unchanged (reads as an unknown number). Absent key or empty list =
  none.

## 7. States and transitions

### 7.1 Per-artifact states

| Artifact | States |
|---|---|
| intent | `draft → approved → done`; `dropped` from any state |
| spec | `draft → approved`; `approved → superseded` |
| plan | `draft → approved → executing → done`; `superseded` from draft/approved/executing |
| roadmap | `draft → approved → done`; `dropped` from `draft` or `approved`; `dropped → draft` |
| milestone | `draft → approved → done`; `dropped` from `draft` or `approved`; `dropped → draft` |
| adr | `draft → approved`; `approved → superseded`; `approved → deprecated`; `draft → dropped`; `dropped → draft` |

### 7.2 Transitions

`— → draft` happens when the file is written, by the artifact's owning skill: `intent`,
`design` (spec), `plan`, `roadmap`, `milestone` (`roadmap` for a roadmap's first
milestones), `adr`. Every other transition:

| Transition | When | Flipped by |
|---|---|---|
| intent `draft → approved` | user approves at the intent gate | `intent` |
| intent `approved → done` | chain complete (§10.4) | `execute` (walk-up) |
| intent `→ dropped` | user declares it dead | `intent` |
| spec `draft → approved` | user approves at design review | `design` |
| spec `approved → superseded` | user requests a redesign; renamed per §4, new `spec.md` written | `design` |
| plan `draft → approved` | user accepts the plan set (the plan skill's one question); every plan in the set flips together | `plan` |
| plan `draft → approved` | user asks for the plan to be executed — the instruction is the approval; a `built-on` mismatch is recorded in `## Deviations`, never a refusal (§10.2) | `execute` |
| plan `approved → executing` | execution starts | `execute` |
| plan `executing → done` | every task completed; no acceptance step | `execute` |
| plan `→ superseded` | re-planning replaces it | `plan` |
| roadmap / milestone `draft → approved` | author approves | `roadmap` / `milestone` |
| roadmap / milestone `approved → done` | roll-up (§12) | skill running the roll-up |
| roadmap / milestone `→ dropped`, `dropped → draft` | author's instruction | `roadmap` / `milestone` |
| adr `draft → approved` | author approves; `sealed` written in the same edit | `adr` |
| adr `approved → superseded` | an ADR listing it in `supersedes` is approved — same interaction, no fresh question | `adr` |
| adr `approved → deprecated`, `draft → dropped`, `dropped → draft` | author's instruction | `adr` |

### 7.3 Flip rule

A skill flips state only as the last step of the interaction that earns it, by editing the
frontmatter of the file it worked on. Author-gated flips need explicit in-dialogue
approval; the mechanical flips of §7.4 need none. No skill or agent commits.

### 7.4 Reversibility

- `dropped` and `superseded` are terminal but reversible on the user's explicit
  instruction. Git history plus `status` is the full record.
- Mechanical flips (no fresh question, consequences of state already earned): plan
  `draft → approved → executing → done` by `execute`, the intent's `done` walk-up, the
  milestone and roadmap `done` roll-up (§12), and an ADR's `approved → superseded`.
- Roadmaps/milestones: un-dropping returns to `draft` for re-approval. `done` is final —
  never reopened, amended or dropped; later work is a simple chain or a new milestone.
  Amending a body leaves status unchanged.
- ADR `superseded` and `deprecated` are final; reviving a decision is a new ADR.

## 8. Spec skip

The user may set `spec: skipped` on the intent during the intent dialogue, with a one-line
reason in the body. `plan` accepts an `approved` intent with no `spec.md` only when this
flag is set; `plan` reads it, never sets it. A spec-skipped chain cannot cite an ADR (only
a spec carries `adrs`); a chain that needs one runs `design`.

## 9. NEXT derivation (status board)

Run by `scripts/status.lua` under `airsl`, or by hand from this file (status fallback).
The board scans the chain root one level deep: every directory is a chain except `prds/`,
`rfcs/`, `roadmaps/`, `adrs/`; a plain file is not a row. Roadmaps/milestones layout: §11.
ADR block: §13. States and fingerprints only, no judgment. For an `approved` intent, §10
applies first; this list decides NEXT only when §10 does not:

| Chain state | NEXT |
|---|---|
| intent `draft` | `approve or drop` |
| intent `approved`, no spec, no skip flag | `design` |
| intent `approved`, `spec: skipped`, no plans | `plan` |
| spec `draft` | `approve spec` |
| spec `approved`, no plans | `plan` |
| plan `approved`, every `depends-on` plan `done` | `execute NN` |
| plan `approved`, any `depends-on` plan not `done` | `wait (dependencies pending)` |
| plan `executing` | shown as executing; no derivation |
| chain complete (§10.4) | STATE `chain complete`, NEXT `execute walk-up` |
| every plan `superseded`, none `done` | `plan` |

- `source: triage` → `(triage)` tag in STATE, last in the cell.
- Intent `done` or `dropped` → collapsed `DONE/DROPPED` tail (count only) unless the
  status dialogue asks for verbose. A complete chain whose intent is still `approved` is
  **not** collapsed.
- Provenance keys (§6) on intent, spec or any plan → a `⤷ inputs:` line under the row
  listing the files. Input docs never get their own row.

## 10. Fingerprints and sync rules

Checked for every chain whose intent is `approved`; `draft`, `dropped` and `done` chains
are not checked.

### 10.1 Fingerprints

- Fingerprint = first 12 hex chars of SHA-256 of the body.
- Body = every line after the line closing the frontmatter (the first line equal to `---`
  after line 1), each with one trailing `\r` removed and terminated by exactly one `\n`.
- Frontmatter excluded: a status flip never changes it; any text edit does.
- First line not `---`, or frontmatter never closed → no fingerprint.
- Code: `scripts/lib/fingerprint.lua`. Without `airsl`:
  `sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <file>` prints the 12 chars and exits
  0, or prints nothing and exits 2.

### 10.2 The two keys

**Authority**: a spec's is `intent.md`; a plan's is `spec.md`, or `intent.md` when the
intent has `spec: skipped` and no `spec.md` exists (§8).

- `built-on` — fingerprint of the authority as written against or last re-confirmed
  against. Written at drafting. The owning skill (`design` for a spec, `plan` for a plan)
  compares it with the authority's current fingerprint before `draft → approved`, says so
  when they differ, and writes the current one in the same edit as the flip.
  - `execute` approves a `draft` plan by being asked to run it (§7.2). On a mismatch it
    still runs and records it in `## Deviations` as a plan-stage defect.
  - **Re-confirmation** rewrites the key on an approved artifact: the owning skill asks
    whether it still holds against the authority as it now reads; on an explicit yes it
    writes the current fingerprint and nothing else. Never inferred; never done by
    `execute`.
- `disproves` — fingerprint of the authority whose claim the plan's execution showed
  wrong. Written by `execute` on the plan it runs. One value; a later disproof overwrites
  it; never removed — it stops matching (and stops mattering) once the authority's text
  changes.

**Live plan** = `approved` or `executing`. **Settled plan** = `done` or `superseded`.

### 10.3 Invalid results

An invalid result replaces the whole STATE cell; NEXT is `fix <chain>`. First that holds,
in this order; within a rule, the lowest plan number.

| # | Condition | STATE |
|---|---|---|
| I1 | an artifact is missing, unreadable or unparseable, or carries an unknown status | `INVALID (<file>: <reason>)`; missing `intent.md` reads `INVALID (intent.md missing)`, no colon |
| I2 | `spec.md` status other than `draft` or `approved` | `INVALID (spec.md: unknown status <status>)` |
| I3 | `spec.md` `approved` with no `built-on` | `INVALID (spec.md: missing built-on)` |
| I4 | a live plan, no `spec.md`, intent lacks `spec: skipped` | `INVALID (plans/NN: no spec and no skip flag)` |
| I5 | a live plan has no `built-on` | `INVALID (plans/NN: missing built-on)` |
| I6 | a number in the spec's `adrs` matches no ADR file, or two | `INVALID (spec.md: unknown ADR NNNN)` / `INVALID (spec.md: ambiguous ADR NNNN)` |
| I7 | a non-`superseded` plan's `disproves-adr` names an `approved` ADR that the spec's `adrs` lacks (or no `spec.md`) | `INVALID (plans/NN: disproves uncited ADR NNNN)` |

- Ranking around these: I1, then §11.6's two membership results, then rule K (§11.7),
  then I2–I7.
- `spec.md` is never legitimately `superseded` (it is renamed, §4).
- I6: lowest number first. I7: lowest plan, then lowest ADR within it.
- I7 reads only live disproofs (ADR still `approved`). Once the ADR is superseded or
  deprecated the plan keeps its `disproves-adr` but no rule reads it.
- A number matching two files is I6 `ambiguous` regardless of either file's other faults.
  A number matching exactly one file that is itself invalid (§13.3) still resolves — not
  I6; the chain reads it as not approved (C7).

### 10.4 Conditions, STATE and NEXT

An ADR is **disproven** when it is `approved` and a non-`superseded` plan, in any chain
whose directory parses, names it in `disproves-adr` (same reading as §13.3).

| # | Condition | STATE part | NEXT |
|---|---|---|---|
| C1 | `spec.md` `approved` and its `built-on` ≠ the intent's fingerprint | `spec stale (intent changed)` | `design` |
| C2 | a non-`superseded` plan's `disproves` = its authority's current fingerprint | `spec disproven by plan NN`; spec-skip: `intent disproven by plan NN` | `design`; spec-skip: `intent` |
| C3 | a live plan's authority is `spec.md` and the spec is `draft` | `plan NN <status>: blocked (spec not approved)` | `approve spec` |
| C4 | a live plan's `built-on` ≠ its authority's fingerprint, and C3 does not hold for it | `plan NN <status>: stale (spec changed)`; spec-skip: `plan NN <status>: stale (intent changed)` | `plan` |
| C5 | a non-`superseded` plan of this chain names a disproven ADR in `disproves-adr`; or `spec.md` is `approved` and cites a disproven ADR | `ADR NNNN disproven by plan NN` (this chain disproved it), else `ADR NNNN disproven by <chain>/NN` | `adr` |
| C6 | `spec.md` `approved` and cites an ADR that is `superseded` or `deprecated` | `spec stale (ADR NNNN superseded by MMMM)` / `spec stale (ADR NNNN deprecated)` | `design` |
| C7 | `spec.md` `approved` and cites an ADR that is `draft`, `dropped` or invalid | `spec blocked (ADR NNNN not approved)` | `adr` |

- `<status>` is the plan's own status. C3, C4 read live plans only. C2 reads every
  non-`superseded` plan (a finished plan can still owe the debt).
- Ties: lowest number; then lowest plan; for several disproving chains, the first in
  listing order.
- `MMMM` = lowest-numbered lister of `NNNN` (§13.3); an invalid sealed ADR is never
  `MMMM`. A superseded ADR no lister lists is invalid, so citing it is C7, not C6.
- C1, C6, C7 and C5's citation half read an `approved` spec only. A draft spec citing a
  draft or disproven ADR is ordinary mid-design; `design` refuses to approve it until the
  ADR is approved and not disproven.
- C5 reaches the disproving chain and every chain whose approved spec cites the ADR. It
  clears only when the ADR is superseded or deprecated (a sealed body never changes).

**STATE** (no invalid result), comma-separated, `(triage)` last:

1. C1 part; 2. C2 part; 3. C5 part; 4. C6 part; 5. C7 part — each if it holds;
6. with plans: one part per plan in number order, `plan NN <status>` or its C3/C4 form;
7. without plans: the single §9 state (`intent approved`, `intent approved (spec skipped)`,
   `spec draft`, `spec approved`); `spec approved` is omitted when C1, C6 or C7 holds.

**NEXT**: the first of C1, C2, C5, C6, C7, C3, C4 that holds; only if none, §9. So a
standing C2, C5, C6 or C7 never offers `execute NN`.

**Chain complete**: every plan settled, at least one `done`, and none of C1, C2, C5, C6,
C7 holds. Only then does STATE read `chain complete` and the intent get walked up to
`done` (§7.2); otherwise the cell is built as above and the intent stays `approved`.

## 11. Roadmaps and milestones

Optional. No `roadmaps/` directory and no intent with a `milestone` key → no roadmap or
milestone behaviour at all.

### 11.1 Files

- Roadmap = directory `roadmaps/<roadmap>/` holding `roadmap.md`. Milestone = a file
  `NN-<topic>.md` beside it. Kebab-case names; any number of roadmaps.
- A roadmap may not be named `plans` (`roadmaps/plans/NN-<topic>.md` would match the glob
  `distill` reads plans through).
- Milestone reference: `<roadmap>/<NN>`, e.g. `platform/01`. Numbers never reused; a new
  milestone takes the next free `NN`.
- Nothing in `roadmaps/` is deleted or renamed; unwanted milestones are `dropped`.
- In a roadmap directory, entries other than `roadmap.md` and `NN-<topic>.md` are ignored;
  plain files directly under `roadmaps/` are ignored.
- No body holds a milestone list, chain list, progress figure or done-checklist.
- Milestone/roadmap status never gates chain work.

### 11.2 Membership and progress

- Only link: the intent key `milestone: <roadmap>/<NN>` (§6). At most one milestone per
  chain; none = **simple chain**. Chain directories never move.
- Membership is never inferred. `intent` writes the key only when the author names a
  milestone; `milestone` writes it when parking scope or adopting, removes it on release.
- Progress is counted at every render, never written down:
  - milestone `N of M done`: `M` = members whose intent is not `dropped`; `N` = members
    whose intent is `done`.
  - roadmap `N of M milestones done`: `M` = milestone files not `dropped`; `N` = those
    `done`.
- Parked, unbegun work is a `draft` intent, so it is in `M` from the moment it is parked.

### 11.3 Board layout

**Open chain** = one with a row: intent `draft` or `approved`, or rendering `INVALID`.

No roadmap directory → flat layout of §9. At least one → same three columns, grouped:

```
CHAIN                             STATE                         NEXT
ROADMAP platform                  approved, 1 of 2 milestones done
MILESTONE platform/01-auth        done, 4 of 4 done
MILESTONE platform/02-billing     approved, 1 of 3 done
  2026-10-13-invoices             plan 01 approved: stale (spec changed)  plan
  2026-10-14-refunds              intent draft                  approve or drop
UNASSIGNED
  2026-10-15-fix-typo             intent approved               design
DONE/DROPPED: 6 done, 2 dropped (not listed)
```

- First column: `ROADMAP <roadmap>`; `MILESTONE <roadmap>/<file name without .md>`.
- Order: roadmaps in directory-listing order → their milestones in number order → each
  milestone's open members in directory-listing order, indented two spaces.
- Under a `draft`/`approved` roadmap, or one whose `roadmap.md` is invalid, every
  milestone prints. Under a `done`/`dropped` roadmap, a milestone prints only if it is not
  `done`/`dropped` itself or has an open member.
- Non-open members count in progress and the tail, and are not listed.
- `UNASSIGNED` heads every open chain not listed under a milestone (simple chains and
  unresolved `milestone` values); omitted when empty.
- Annotation lines, indented two past their row: `⤷ inputs:` first, then `⤷ milestone …`;
  a milestone's `⤷ roadmap …` follows its row.
- A root with a roadmap and no chain renders the board, not the starter hint.

### 11.4 Milestone rows

| Milestone status | Condition | STATE | NEXT |
|---|---|---|---|
| `draft` | — | `draft, N of M done` | `approve or drop` |
| `approved` | `M` is 0 | `approved, 0 of 0 done` | `park scope` |
| `approved` | every member `done` or `dropped`, at least one `done` | `milestone complete` | `roll up` |
| `approved` | otherwise | `approved, N of M done` | empty |
| `done` | every member `done` or `dropped` | `done, N of M done` | empty |
| `done` | any member neither `done` nor `dropped` | `INVALID (done with open chains)` | `fix <roadmap>/<NN>` |
| `dropped` | — | `dropped` | empty |
| file unparseable, or any other status | — | `INVALID (<file>: <reason>)` | `fix <roadmap>/<NN>` |
| two files in one roadmap share a number | each of them | `INVALID (<file>: duplicate number NN)` | `fix <roadmap>/<NN>` |

### 11.5 Roadmap rows

| Roadmap status | Condition | STATE | NEXT |
|---|---|---|---|
| `draft` | — | `draft, N of M milestones done` | `approve or drop` |
| `approved` | `M` is 0 (no milestone file, or all `dropped`) | `approved, 0 of 0 milestones done` | `add milestone` |
| `approved` | every milestone `done` or `dropped`, at least one `done` | `roadmap complete` | `roll up` |
| `approved` | otherwise | `approved, N of M milestones done` | empty |
| `done` | every milestone `done` or `dropped` | `done, N of M milestones done` | empty |
| `done` | any milestone neither `done` nor `dropped` | `INVALID (done with open milestones)` | `fix <roadmap>` |
| `dropped` | — | `dropped` | empty |
| `roadmap.md` missing or unparseable, or any other status | — | `INVALID (roadmap.md: <reason>)` | `fix <roadmap>` |
| the directory is named `plans` | — | `INVALID (reserved name)` | `fix plans` |

An invalid milestone has no status: it counts in `M`, never in `N`, keeping its roadmap
open.

### 11.6 Membership problems

For every chain whose intent is `draft` or `approved`, in either layout:

| Condition | Reported as |
|---|---|
| `milestone` value not of the form `<roadmap>/<NN>`, or no milestone file has that roadmap and number | `INVALID (intent.md: unknown milestone <value>)` → `fix <chain>` |
| value matches two milestone files (duplicate number) | `INVALID (intent.md: ambiguous milestone <value>)` → `fix <chain>` |
| chain names a `dropped` milestone | under the chain's row: `⤷ milestone <roadmap>/<NN> is dropped — release this chain` |
| a `draft` or `approved` milestone under a `dropped` roadmap | under the milestone's row: `⤷ roadmap <roadmap> is dropped — drop this milestone` |

The two invalid results rank after I1 and before I2 (§10.3). With no roadmap directory, a
chain carrying a `milestone` key renders the first row in the flat layout. Rule K
(§11.7) ranks after these two.

### 11.7 Misplaced ADR keys

Rule K applies whether or not any roadmap exists (it sits here only because of its rank),
to every chain whose intent is `draft` or `approved`:

| Found | Reported |
|---|---|
| `adrs` or `disproves-adr` on `intent.md` | `INVALID (intent.md: <key> not allowed here)` |
| `disproves-adr` on `spec.md` | `INVALID (spec.md: disproves-adr not allowed here)` |
| `adrs` on a plan | `INVALID (plans/NN: adrs not allowed here)` |

- A key counts when present, whatever its value — `adrs: []` on an intent is reported
  (unlike §6, where an empty list reads as none).
- NEXT `fix <chain>`. Checked intent, then spec, then plans in number order. Ranks after
  §11.6's membership problems, before I2.

## 12. Roll-up

Takes a roadmap name; idempotent.

1. For each `approved` milestone, in number order: if every member's intent is `done` or
   `dropped`, at least one `done`, flip it `approved → done` and tell the author.
2. If the roadmap is `approved` and every milestone is `done` or `dropped`, at least one
   `done`, flip it `approved → done` and tell the author.

Runs as the last step of any interaction that could make either true, for that roadmap:

| Event | Skill |
|---|---|
| a member's intent flips to `done` (chain walk-up) | `execute` |
| a member's intent is dropped | `intent` |
| a chain is released; a milestone is approved or dropped | `milestone` |
| a roadmap is approved | `roadmap` |
| the author asks, or the board's NEXT reads `roll up` | `milestone`, operation `roll up`, given a roadmap name or milestone reference |

A missed roll-up shows as `milestone complete` / `roadmap complete` → `roll up` (§11.4,
§11.5).

## 13. Architecture decision records

Optional. No `adrs/` directory and no chain artifact with an `adrs` or `disproves-adr` key →
no ADR behaviour at all. Body shape: `references/templates.md`.

### 13.1 Files

- `.claudestacks/sdlc/adrs/NNNN-<topic>.md`: four-digit `NNNN`, kebab-case `<topic>`. One
  repository-wide series.
- `adrs/` is created by the `adr` skill on first use, never by `setup`.
- A new ADR takes the next number after the highest `NNNN` of any file matching
  `^%d%d%d%d%-.+%.md$`, whatever its status or validity. Numbers never reused.
- Any other entry in `adrs/`, and any subdirectory, is ignored.
- Nothing in `adrs/` is renamed or deleted.
- Two files sharing a number are both invalid (§13.3).

### 13.2 Seal and supersession

| Key | Type | Optionality |
|---|---|---|
| `status` | `draft`, `approved`, `superseded`, `deprecated`, `dropped` | required |
| `created` | date | required |
| `supersedes` | list of ADR numbers | optional; read only on a **sealed** ADR (status `approved`, `superseded` or `deprecated`) |
| `sealed` | fingerprint | absent on a draft; written at approval; required on `approved`, `superseded`, `deprecated`; ignored on `draft`, `dropped` |

- `supersedes` may list several numbers. It remains a link after its carrier is itself
  superseded or deprecated, so a chain `0003` ← `0009` ← `0012` keeps every record valid.
- `sealed` = the body's fingerprint (§10.1) at approval. Drafts may be edited freely; an
  approved body is never edited — a changed decision is a new superseding ADR. The board
  checks body vs `sealed` on every render.
- The seal excludes frontmatter, so a `supersedes` edit on a sealed ADR is caught only by
  the §13.3 rows (still-`<status>`, cycle — self-listing included — unknown, superseded by
  nothing). No skill acts on those rows without the author's explicit word. Adding a
  number already `superseded` under another valid lister shows no row; it changes only
  (when the new lister is lower) the `MMMM` that C6 names.

### 13.3 ADR rows

Derived by `scripts/lib/adr.lua` under `airsl`, else by hand. First that holds:

| Condition | STATE | NEXT |
|---|---|---|
| unreadable, unparseable, missing or unknown `status` | `INVALID (<file>: <reason>)` | `fix adr NNNN` |
| two files share the number | `INVALID (<file>: duplicate number NNNN)` | `fix adr NNNN` |
| `approved`, `superseded` or `deprecated`, and no `sealed` | `INVALID (<file>: missing sealed)` | `fix adr NNNN` |
| `approved`, `superseded` or `deprecated`, and the body's fingerprint ≠ `sealed` | `INVALID (<file>: edited after approval)` | `fix adr NNNN` |
| sealed, and its `supersedes` names a number matching no ADR file | `INVALID (<file>: supersedes unknown MMMM)` | `fix adr NNNN` |
| sealed, and following `supersedes` entries that each name exactly one ADR file, from it through sealed ADRs, leads back to it | `INVALID (<file>: supersedes cycle)` | `fix adr NNNN` |
| listed by a lister `MMMM`, and its status is `approved` | `INVALID (<file>: superseded by MMMM but still approved)` | `adr` |
| listed by a lister `MMMM`, and its status is `draft`, `dropped` or `deprecated` | `INVALID (<file>: superseded by MMMM but still <status>)` | `fix adr MMMM` |
| `superseded`, and no lister lists it | `INVALID (<file>: superseded by nothing)` | `fix adr NNNN` |
| disproven (§10.4) | `disproven by <chain>/NN` | `adr supersede NNNN` |
| `draft` | `draft` | `approve or drop` |
| otherwise | no row | |

- An invalid ADR has no status for any other rule: it counts as invalid in the heading and
  chains read it as not approved.
- Disproof is read from every chain whose directory parses, whatever its intent's status.
  Several plans → the first chain in listing order, its lowest plan.
- **Lister** of an ADR = a sealed ADR that no row invalidates and whose `supersedes` names
  it; `MMMM` = the lowest-numbered one. Validity thus walks along `supersedes`. A walk edge
  is a sealed-by-status ADR's `supersedes` entry naming exactly one ADR file (seal intact
  or not). Every ADR on a loop of such edges is settled by the cycle row or an earlier one
  (`missing sealed`, `edited after approval`, `supersedes unknown` win, first that holds),
  so no lister's validity depends on itself. Loops arise only by hand-editing; the `adr`
  skill's approve refuses unless every listed ADR is `approved`.

### 13.4 Layout

When `adrs/` holds at least one file matching §13.1, one block follows every chain row (in
either layout, §9, §11.3) and precedes the `DONE/DROPPED` line.

- Heading: `ADRS: ` + non-zero counts as `<n> <word>`, joined by `, `, in order approved,
  superseded, deprecated, draft, dropped, invalid — e.g. `ADRS: 2 approved, 1 draft`. An
  invalid ADR counts only as invalid.
- Then one row per ADR that has a row (§13.3), labelled `ADR NNNN`, indented two spaces,
  in number order (file-name order on a duplicate). Row-less ADRs are counted, not listed.
- No such file → nothing prints; the block adds no byte.
- A root with ADRs and no chain renders the board, not the starter hint.
- The board's `open` count stays the count of chain rows.

---

This file owns paths, naming, frontmatter keys and states. Body shapes of every artifact
are owned by `references/templates.md`; change one, check the other.
