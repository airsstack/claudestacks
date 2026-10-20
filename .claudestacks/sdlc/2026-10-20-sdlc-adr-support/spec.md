---
status: approved
created: 2026-10-20
built-on: 89ee3fbfc650
---

# Spec: optional architecture decision records for claudestacks-sdlc

This spec adds architecture decision records (ADRs) to `plugins/claudestacks-sdlc` as an
optional, repository-wide series under `.claudestacks/sdlc/adrs/`, written only by a new `adr`
skill and cited only from a chain's `spec.md`. The status board checks every relation between
an ADR and the chains built on it — an accepted ADR edited in place, a cited ADR replaced,
retired or not yet accepted, an ADR disproven by a plan's execution — through the same rules,
rows and session-start hook that already report every other disagreement. A repository with
no `adrs/` directory renders exactly as it does today.

## 1. Design premises

Every claim below was checked on 2026-10-20 against this worktree. Probes ran against a
byte-identical copy of `plugins/claudestacks-sdlc/scripts/` in a throwaway directory and were
deleted afterwards.

**P1 — the board today treats an `adrs/` directory as a broken chain, and ignores keys on the
wrong artifact.** Probe: a chain root holding `adrs/0001-x.md`, and a chain whose `intent.md`
carries `depends-on: [01]` and `adrs: [0001]`, whose approved `spec.md` carries
`adrs: [0003]` and `milestone: nope/01`, and whose approved plan carries a block-list `adrs`
and `spec: skipped`, each with a correct `built-on`. Run with `airsl 0.1.2`:

```
CHAIN                             STATE                         NEXT
2026-10-20-probe                  plan 01 approved              execute 01
adrs                              INVALID (intent.md missing)   fix adrs
```

Every top-level directory not named in `SKIP` is read as a chain
(`scripts/lib/status.lua:22`, `:139-151`), and derivation reads only the keys it uses, so a
key on the wrong artifact is silently ignored (`status.lua:301-430`). So `adrs/` must join `SKIP`, as `roadmaps/` did, and the rule that
reports a misplaced key (§4.1) is new behaviour with no existing counterpart.

**P2 — the frontmatter parser returns an inline list as one string and a block list as a
table, and keeps leading zeros.** Probe: `parse_frontmatter` over `adrs: [0003, 0007]`, a
block list `- 0003`, `sealed: 7df83709971b` and `supersedes: 0003`:

```
adrs	string	[0003, 0007]
block	table	0003
supersedes	string	0003
sealed	string	7df83709971b
```

The parser stores a non-empty scalar as a string and a `key:` followed by `- item` lines as a
table (`status.lua:41-54`). Number lists are therefore read the way `depends-on` already is —
a table's items, or every `%d+` run in a string (`status.lua:184-195`) — and normalised to the
file name's width.

**P3 — the baseline Lua suite.** `cargo make plugins-test` reports
`506 passed, 0 failed (22 files)`, matching `CLAUDE.md:206`.

**P4 — a fingerprint excludes frontmatter.** The fingerprint is the first 12 hex characters of
the SHA-256 of the body, the lines after the closing `---` (`references/artifact-chain.md:249-255`);
`scripts/fingerprint.sh <file>` prints it for any file (`artifact-chain.md:257-259`). So writing
`sealed` or flipping `status` never changes an ADR's fingerprint, and editing an `adrs` key in a
spec never changes the spec's fingerprint — which decides how C6 is cleared (§6.2).

Structural facts the design builds on:

- Roadmaps are scanned by their own module, `scripts/lib/roadmap.lua`, which takes
  `read_artifact` as a parameter so it does not require `lib/status` (`roadmap.lua:25-30`), and
  is consumed by `status.lua` (`status.lua:11`, `:468`). `lib/adr.lua` follows the same split.
- `read_chain` reads every plan of every chain, whatever the intent's status
  (`status.lua:83-135`); fingerprints are computed only for an approved intent's chain
  (`status.lua:99-102`).
- A board row is `{ kind, label, state, next, indent, notes }`, and `kind = "heading"` prints its
  label only (`status.lua:459-461`, `:556-566`). The session hook skips headings and selects rows
  whose STATE contains `INVALID`, `stale`, `blocked`, `disproven` or `complete`
  (`status.lua:588`, `:605-623`); its first line counts open chains only (`status.lua:649-651`).
- A milestone number shared by two files makes both invalid (`roadmap.lua:75-80`).
- `plan` refuses by an explicit table of board conditions (`skills/plan/SKILL.md:85-96`), as
  `execute` does (`skills/execute/SKILL.md:45-55`).
- `design` chooses between approaches at step 6 (`skills/design/SKILL.md:188-191`) and approves a
  spec at step 10 (`:269-286`).

The scripts are Lua under `airsl`. No installed guideline plugin covers Lua:
`ls ~/.claude/plugins/cache/*/*/*/enforcement.json` lists exactly one manifest,
`claudestacks/claudestacks-guideline-rust/0.1.4/enforcement.json` — the same search finding the
Rust guideline is its control. Module layout therefore follows the plugin's own precedent rather
than a guideline rule.

## 2. The ADR artifact

### 2.1 Files

- An ADR is a file `.claudestacks/sdlc/adrs/NNNN-<topic>.md`. `NNNN` is four digits; `<topic>`
  is kebab-case. Four digits (up to 9999), not the two that plans and milestones use, because
  this series is repository-wide and grows for the life of the repository rather than one chain
  or one roadmap.
- `adrs/` is created by the `adr` skill on first use. `setup` never creates it.
- A new ADR takes the next number after the highest `NNNN` of any file in `adrs/` matching
  `^%d%d%d%d%-.+%.md$`, whatever its status or validity. A number is never reused.
- Any other entry in `adrs/` is ignored, as are subdirectories.
- Nothing in `adrs/` is renamed or deleted.
- Two files sharing a number are both invalid (§5.1).

### 2.2 Frontmatter and body

````markdown
---
status: draft
created: <YYYY-MM-DD>
supersedes: [0003]               # optional — the ADRs this one replaces
---

# ADR <NNNN>: <title>

## Context

[the forces at play and why a decision is needed now]

## Options considered

[at least two real options, each with its trade-offs]

## Decision

[what was decided]

## Consequences

[what follows from the decision, the costs included]
````

| Key | Type | Optionality |
|---|---|---|
| `status` | `draft`, `approved`, `superseded`, `deprecated`, `dropped` | required |
| `created` | date | required |
| `supersedes` | list of ADR numbers | optional; read only on a **sealed** ADR — one whose status is `approved`, `superseded` or `deprecated` (§5.1) |
| `sealed` | fingerprint | absent on a draft; written at approval; required on `approved`, `superseded` and `deprecated`; ignored on `draft` and `dropped` |

`supersedes` may list more than one number, so one decision can replace two. It stays a link
after the ADR carrying it is itself superseded or deprecated, so a chain of replacements
(`0003` ← `0009` ← `0012`) keeps every earlier record valid.

### 2.3 States and transitions

```
draft ──approve──▶ approved ──(a successor is approved)──▶ superseded    final
  │                    └──────────deprecate──────────────▶ deprecated    final
  └──drop──▶ dropped ──un-drop──▶ draft
```

| Transition | When | Flipped by |
|---|---|---|
| `— → draft` | file written | `adr` |
| `draft → approved` | the author approves; `sealed` is written in the same edit | `adr` |
| `approved → superseded` | an ADR listing it in `supersedes` is approved, in the same interaction — no fresh question, a consequence of that approval | `adr` |
| `approved → deprecated` | the author's instruction | `adr` |
| `draft → dropped` | the author's instruction | `adr` |
| `dropped → draft` | the author un-drops it | `adr` |

`superseded` and `deprecated` are final: reviving a retired decision is a new ADR. This differs
from `artifact-chain.md` §7.4, where `superseded` is terminal but reversible, and adds the
consequential `approved → superseded` flip to that section's list of transitions that fire
without a fresh question; §7.4 is amended to say both (§12). The flip rule of §7.3 holds: a flip
is the last step of the interaction that earns it, and no skill commits.

### 2.4 The seal

`sealed` holds the fingerprint (P4) of the ADR's body taken at approval. A draft's body may be
edited freely. Once approved, the body is never edited: a decision that changes is a new ADR
that supersedes it. The board compares the body with `sealed` on every render (§5.1).

The seal covers the body only, because a fingerprint excludes frontmatter (P4). A `supersedes`
list added to or changed on a sealed ADR is not caught as an edit; it surfaces instead as the
§5.1 row `superseded by MMMM but still <status>` on each newly listed ADR, and no skill acts on
that row without the author's explicit word (§7.1).

## 3. Citation and disproof keys on chain artifacts

| Key | On | Holds |
|---|---|---|
| `adrs` | `spec.md` only | the ADR numbers the spec's design relies on |
| `disproves-adr` | a plan only | the ADR numbers whose premise this plan's execution disproved; written by `execute`, never removed |

Both are number lists, read per P2: a table's items or every `%d+` run in a string, each
normalised to four digits (`3` → `0003`). An absent key or an empty list means none.

A chain that skips its spec (`spec: skipped`, `artifact-chain.md` §8) cannot cite an ADR: the
intent holds no solution content, and only a spec carries `adrs`. A chain that needs one runs
`design`.

`sealed` and `supersedes` are read only from files in `adrs/`; on a chain artifact they are
ignored.

## 4. Board rules for chains

### 4.1 Misplaced keys (K)

For every chain whose intent is `draft` or `approved`:

| Found | Reported |
|---|---|
| `adrs` or `disproves-adr` on `intent.md` | `INVALID (intent.md: <key> not allowed here)` |
| `disproves-adr` on `spec.md` | `INVALID (spec.md: disproves-adr not allowed here)` |
| `adrs` on a plan | `INVALID (plans/NN: adrs not allowed here)` |

NEXT is `fix <chain>`. Checked intent first, then spec, then plans in number order. K ranks
after the membership problems (`artifact-chain.md` §11.6) and before I2. Because K applies to
`draft` chains as well, the reference states it in a section of its own ranked by reference, as
§11.6 is, rather than inside §10.3, whose preamble excludes draft chains
(`artifact-chain.md:242-245`).

### 4.2 Invalid citations (I6, I7)

For a chain whose intent is `approved`, after I5:

| # | Condition | STATE |
|---|---|---|
| I6 | a number in the spec's `adrs` matches no ADR file, or two | `INVALID (spec.md: unknown ADR NNNN)` / `INVALID (spec.md: ambiguous ADR NNNN)` |
| I7 | a plan that is not `superseded` names in `disproves-adr` an ADR whose status is `approved`, and the spec's `adrs` does not hold that number (or there is no `spec.md`) | `INVALID (plans/NN: disproves uncited ADR NNNN)` |

NEXT is `fix <chain>`. Within a rule, the lowest number first.

I7 reads only live disproofs — those naming an ADR still `approved`. Once that ADR is superseded
or deprecated, the disproof is history: the spec may stop citing it (§6.2) while the plan keeps
its `disproves-adr` value, as it must, and no rule reads it again. This is the property
`disproves` has by stopping matching (`artifact-chain.md:279-283`).

A number matching two files is I6 (`ambiguous`), whatever else is wrong with either file. A
number matching exactly one file that is itself invalid for another reason (§5.1) still
resolves: it is not I6, and the chain reads it as not approved (C7).

### 4.3 Conditions (C5, C6, C7)

For a chain whose intent is `approved`, alongside C1–C4:

| # | Condition | STATE part | NEXT |
|---|---|---|---|
An ADR is **disproven** when its status is `approved` and a plan that is not `superseded`, in
any chain whose directory parses, names it in `disproves-adr` (the same reading as the §5.1 row).

| # | Condition | STATE part | NEXT |
|---|---|---|---|
| C5 | a plan of this chain that is not `superseded` names a disproven ADR in `disproves-adr`; or `spec.md` is `approved` and cites a disproven ADR | `ADR NNNN disproven by plan NN` when a plan of this chain disproved it; otherwise `ADR NNNN disproven by <chain>/NN`, naming the disproving chain | `adr` |
| C6 | `spec.md` is `approved` and cites an ADR whose status is `superseded` or `deprecated` | `spec stale (ADR NNNN superseded by MMMM)` or `spec stale (ADR NNNN deprecated)` | `design` |
| C7 | `spec.md` is `approved` and cites an ADR whose status is `draft` or `dropped`, or which is invalid | `spec blocked (ADR NNNN not approved)` | `adr` |

`MMMM` is the lowest-numbered sealed ADR listing `NNNN` in `supersedes`. A superseded ADR that no
sealed ADR lists is invalid (§5.1), so a chain citing it reads C7, not C6. When several numbers
satisfy one condition, the part names the lowest; when several plans do, the lowest plan; when
several chains disproved it, the first in listing order.

C5 is how a disproof reaches every open chain built on the decision: the disproving chain, and
every other chain whose approved spec cites the ADR. C6 and C7, and C5's citation half, read an
approved spec only, as C1 does. A draft spec citing a draft or disproven ADR is ordinary
mid-design; `design` refuses to approve it until the ADR is approved and not disproven (§7.2).
C5 clears when the ADR is superseded or deprecated — a sealed body never changes, so unlike
`disproves` it cannot clear by a text edit.

### 4.4 STATE, NEXT and completion

STATE, when no invalid result holds, is built in this order, comma-separated, `(triage)` last:
the C1 part, the C2 part, the C5 part, the C6 part, the C7 part, then the plan parts or the
single chain state of `artifact-chain.md` §10.4. For a chain without plans, `spec approved` is
omitted when C1, C6 or C7 holds.

NEXT is decided by the first that holds of C1, C2, C5, C6, C7, C3, C4; only when none holds does
`artifact-chain.md` §9 apply. A standing C5, C6 or C7 therefore never yields `execute NN`.

A chain is complete when every plan is settled, at least one is `done`, and none of C1, C2, C5,
C6, C7 holds. Only a complete chain reads `chain complete` and is walked up to `done`.

## 5. Board rules for ADRs

### 5.1 ADR rows

`lib/adr.lua` reads every ADR and derives its row. In order, the first that holds:

| Condition | STATE | NEXT |
|---|---|---|
| unreadable, unparseable, missing or unknown `status` | `INVALID (<file>: <reason>)` | `fix adr NNNN` |
| two files share the number | `INVALID (<file>: duplicate number NNNN)` | `fix adr NNNN` |
| `approved`, `superseded` or `deprecated`, and no `sealed` | `INVALID (<file>: missing sealed)` | `fix adr NNNN` |
| `approved`, `superseded` or `deprecated`, and the body's fingerprint ≠ `sealed` | `INVALID (<file>: edited after approval)` | `fix adr NNNN` |
| sealed, and its `supersedes` names a number matching no ADR file | `INVALID (<file>: supersedes unknown MMMM)` | `fix adr NNNN` |
| listed in the `supersedes` of a sealed ADR `MMMM`, and its status is `approved` | `INVALID (<file>: superseded by MMMM but still approved)` | `adr` |
| listed in the `supersedes` of a sealed ADR `MMMM`, and its status is `draft`, `dropped` or `deprecated` | `INVALID (<file>: superseded by MMMM but still <status>)` | `fix adr MMMM` |
| `superseded`, and no sealed ADR lists it | `INVALID (<file>: superseded by nothing)` | `fix adr NNNN` |
| disproven (§4.3) | `disproven by <chain>/NN` | `adr supersede NNNN` |
| `draft` | `draft` | `approve or drop` |
| otherwise | no row | |

An invalid ADR has no status for any other rule: it counts in the heading as invalid and is read
by chains as not approved.

The disproof is read from every chain whose directory parses, whatever its intent's status, so
dropping or finishing a chain does not hide a known-broken decision. When several plans name the
ADR, the row names the first chain in listing order and its lowest plan.

### 5.2 Layout

When `adrs/` holds at least one file matching §2.1, one block follows every chain row, in either
layout (`artifact-chain.md` §9, §11.3), and precedes the `DONE/DROPPED` line. An illustration of
the order of lines only — column padding is whatever `pad` (`status.lua:449-454`) produces, and
no plan or test copies this block as expected output:

```
CHAIN                             STATE                         NEXT
2026-10-20-queue                  ADR 0003 disproven by plan 02, plan 01 done, plan 02 executing  adr
2026-10-21-billing                ADR 0003 disproven by 2026-10-20-queue/02, plan 01 approved  adr
ADRS: 6 approved, 2 superseded, 1 deprecated, 1 draft
  ADR 0003                        disproven by 2026-10-20-queue/02  adr supersede 0003
  ADR 0011                        draft                         approve or drop
DONE/DROPPED: 7 done, 2 dropped (not listed)
```

- The heading is a `heading` row: `ADRS: ` followed by the non-zero counts in the order approved,
  superseded, deprecated, draft, dropped, invalid.
- ADR rows have `kind = "adr"`, label `ADR NNNN`, indent 2, in number order (file name order on a
  duplicate).
- With no such file, nothing prints and the board is byte-identical to today's.
- A root holding ADRs and no chain renders the board, not the starter hint, as a root holding only
  a roadmap does (`artifact-chain.md:418`).
- `board.open` stays the count of chain rows.

## 6. Clearing paths

### 6.1 Superseding a decision

```
/adr supersede 0003           refused unless 0003 is approved
  ▼
adrs/0009-<topic>.md          draft, supersedes: [0003]
  ▼ reviewed (kind adr, authority adrs/0003-*.md) → approved by the author
0009 approved + sealed; 0003 approved → superseded       same interaction
  ▼
every open chain whose approved spec cites 0003 reads C6 → design (§6.2)
```

### 6.2 Clearing C6 in `design`

The `adrs` key is frontmatter, so changing it leaves the spec's fingerprint, and therefore its
plans, untouched (P4). C6 is cleared by the re-confirmation pattern `design` already uses:

```
spec stale (ADR 0003 superseded by 0009)
  design asks: does this spec still hold under 0009 as it reads?
   ├─ explicit yes → replace 0003 with its successor(s) in adrs (remove it if deprecated);
   │                 change nothing else → plans unaffected
   └─ no          → redesign path (step 11) → new spec body → plans read C4 → plan
```

### 6.3 A plan disproves a decision

```
execute plan 02: a probe disproves ADR 0003's premise
  ▼ stop; ask the author, as its own question, which claim broke — the plan's, the spec's,
  ▼ a cited ADR's (any mix) — and whether to amend now or after this run
write disproves-adr: [0003] in plan 02 before any further task, whatever the answer
  ▼
this chain:          ADR 0003 disproven by plan 02 → adr      plan 02 may finish; no other plan starts
every other open
chain citing 0003:   ADR 0003 disproven by <chain>/02 → adr   no plan starts
ADR row:             disproven by <chain>/02 → adr supersede 0003
  ▼ /adr supersede 0003 (or deprecate)  → C5 and the ADR row clear everywhere
  ▼ C6 on every open chain citing 0003 → design → plan → execute resumes
```

Plan 02 keeps `disproves-adr: [0003]` for good. Once 0003 is superseded, I7 and C5 no longer read
it (§4.2), so the spec dropping 0003 from `adrs` leaves the chain valid.

## 7. Skills

### 7.1 `adr` (new)

`skills/adr/SKILL.md`, the only writer of `adrs/`. It resolves paths, keys and states from
`artifact-chain.md` and the body shape from `templates.md`, lazy-creates `adrs/`, flips status
only per §2.3 and §7.3 of the reference, and never commits. An ADR may be named `0003` or `3`.
Before acting on an existing ADR it renders the board and reads that ADR's row. A healthy
`approved`, `superseded`, `deprecated` or `dropped` ADR has no row (§5.1); then it reads the
status from the file. On an `INVALID` row it refuses, naming the file and the reason as the board
words them, except the `superseded by MMMM but still approved` row, which it offers to clear by
finishing the supersede (below). After every flip it renders the board again and says what the
row reads.

| Operation | Does | Refused when |
|---|---|---|
| new | asks one question at a time — title, context, options considered (two or more), decision, consequences — writes `NNNN-<topic>.md` as `draft`, runs the review (§8), then asks whether to approve | — |
| approve | `draft → approved`: computes the body's fingerprint with `fingerprint.sh` and writes it as `sealed` in the same edit; if the ADR lists `supersedes`, flips each listed ADR `approved → superseded` in the same interaction, then names the open chains now reading C6 | not `draft`; a listed ADR is not `approved` |
| supersede `N` | writes a new draft with `supersedes: [N]` whose context states what in `N` no longer holds, citing the plan's probe result when a plan disproved it; review with `N` as authority; then approve as above | `N` is not `approved` |
| deprecate `N` | `approved → deprecated` on the author's explicit word; nothing else in the file changes | `N` is not `approved` |
| amend | rewrites a draft's body | not `draft` |
| drop / un-drop | `draft → dropped` / `dropped → draft` | not `draft` / not `dropped` |
| finish supersede | for an ADR reading `superseded by MMMM but still approved`, shows the author that `MMMM` lists it and asks whether `MMMM` replaces it; on an explicit yes, flips it `approved → superseded`. It asks because the row is reachable only through an interrupted approval or a hand-edited `supersedes`, which the seal does not cover (§2.4) | its status is not `approved` |

Deprecation records no reason in the file, because the body is sealed; the reason belongs in the
author's commit message.

### 7.2 `design` (changed)

- **Never asks about ADRs.** It hands off to `/adr new` only when the author asks for a choice to
  be recorded as one, then writes the ADR's number into the draft spec's `adrs`.
- **Reads approved ADRs before proposing approaches.** When `adrs/` exists, step 3 reads the
  title of every `approved` ADR and the body of each one that bears on the intent. Step 6 treats
  those decisions as settled: an approach that contradicts one says so and names the ADR, and
  taking it means superseding that ADR through the `adr` skill, on the author's word. Reading is
  not asking: a repository with no `adrs/` sees no change. This is the lookup that answers "what
  was decided about X, and why" (the intent's third problem).
- **Sync table** gains: C5 → tell the author the cited ADR is disproven and that the `adr` skill
  supersedes or deprecates it; C6 → the re-confirmation of §6.2; C7 → tell the author the cited
  ADR is not approved and that the `adr` skill approves it.
- **Approval gate (step 10)** refuses to approve a spec whose `adrs` names an ADR that is unknown,
  ambiguous, invalid, disproven, or not `approved`, naming the ADR and its status.
- A redesign writes `adrs` afresh in the new spec.

### 7.3 `execute` (changed)

- **Disproof** (`skills/execute/SKILL.md:323-350`): the question asks which claim broke — the
  plan's, the spec's, a cited ADR's, or several. When a cited ADR's claim broke, it adds that
  number to the running plan's `disproves-adr` before any further task, whatever the author
  answers; numbers are added, never removed. Only ADRs the spec cites may be named (I7).
- **Refusal table** (`:45-55`) gains: `ADR NNNN disproven by plan NN`, except for plan `NN`
  itself, which may finish its run → the `adr` skill; `ADR NNNN disproven by <chain>/NN` (a
  sibling chain's disproof), with no exception → the `adr` skill; `spec stale (ADR …)` →
  `design`; `spec blocked (ADR …)` → the `adr` skill.
- **Walk-up** (`:406-424`): C5, C6 and C7 hold the chain open like C1 and C2, naming the skill
  that clears each.

### 7.4 `plan` (changed)

The refusal table (`skills/plan/SKILL.md:85-96`) gains `ADR NNNN disproven by …` (either form)
→ `adr`, `spec stale (ADR …)` → `design`, `spec blocked (ADR …)` → `adr`. This overrides the intent's
assumption that `plan` is unaffected, which the intent marked overridable.

### 7.5 `status` (changed)

The no-`airsl` fallback (`skills/status/SKILL.md`) also scans `adrs/` and renders the ADR block by
the rules this spec's §12 adds to `artifact-chain.md`.

### 7.6 Unchanged

`intent`, `roadmap`, `milestone`, `distill`, `triage`, `setup`, and the `chain-reader` and
`task-briefer` agents. `distill` globs `.claudestacks/sdlc/*/plans/*.md`
(`skills/distill/SKILL.md:50`); `adrs/` holds no `plans/` directory, so the glob is unaffected.

## 8. Review of a draft ADR

- `agents/artifact-reviewer.md`: `kind` gains `adr`. Its `authority` is none for a new ADR, and the
  replaced ADR(s) for a supersede. The verdict line reads `ADR: <n> blocking, …`.
- `references/artifact-review.md` gains § *Reviewing a draft ADR*: no placeholders; at least two
  real options, each with trade-offs; the decision follows from the context; the consequences
  name costs, not only benefits; every claim carries its proof, by the same rule as a spec; on a
  supersede, the context states what in the replaced ADR no longer holds.
- The `adr` skill spawns the reviewer exactly once per draft, carries every finding's disposition
  to the author at the approval question, and applies the criteria inline, saying so, when the
  agent does not resolve — the discipline `design` follows (`skills/design/SKILL.md:216-267`).

## 9. Session-start hook

No change to the hook or to `ATTENTION_WORDS`. ADR problem rows are worded with `INVALID` or
`disproven`, and the chain conditions with `disproven`, `stale` or `blocked`, so
`needs_attention` (`status.lua:605-623`) selects them; the `ADRS:` heading is a heading and is
skipped; a `draft` ADR row holds no attention word and is not shown.

## 10. Error handling

- An unparseable or otherwise invalid ADR is its own `INVALID` row; it never makes a chain
  invalid. A chain citing it reads C7.
- An unparseable chain stays `INVALID` as today; its plans contribute no disproof, because none
  of them was read.
- Without `airsl`, every skill derives rows by hand from `artifact-chain.md`, and computes
  fingerprints with `fingerprint.sh`, as today.

## 11. Testing

Lua behaviour is tested under `airsl test`, run by `cargo make plugins-test`; `cargo make
plugins-check` compiles every file. Each test is seen failing before the code that satisfies it
is written.

| File | Pins |
|---|---|
| `scripts/adr_test.lua` (new) | scanning and ignored entries; four-digit parsing of inline and block lists, with normalisation; duplicate numbers; every row of §5.1, in order; the seal matching, edited and missing; both halves of supersession; a second-generation supersession (`0003` ← `0009` ← `0012`, and `0009` deprecated) leaving `0003` valid; disproof read from a chain whose intent is `done` and one whose intent is `dropped`; the heading's counts and order |
| `scripts/status_test.lua` | `adrs/` no longer rendering as a chain (P1); every row of K, I6, I7 and their place in the invalid order; I6 winning over C7 for a duplicate number; I7 ignoring a disproof of a superseded ADR the spec no longer cites; C5 on the disproving chain and on a sibling chain that only cites the ADR; C5, C6, C7 parts, their STATE order and NEXT order; C6 and C7 and C5's citation half ignoring a draft spec; each of C5, C6, C7 preventing `chain complete`; the ADR block's placement in the flat and grouped layouts; no block and byte-identical output without `adrs/`; a root holding only ADRs rendering the board; the hook showing ADR problem rows and skipping the heading and a draft row |

The 506 existing tests keep passing unchanged.

Skill behaviour is prose with no unit test. It is verified by a recorded walkthrough on a
throwaway chain root, with the real board output pasted into the executing plan: a new ADR
approved and sealed; its body edited afterwards (`edited after approval`); a supersede producing
C6 on two chains, one cleared by re-confirmation and one by redesign; a disproof holding back a
sibling plan, a second chain that only cites the ADR, and the walk-up, then clearing on
supersede with the disproving chain completing; a deprecation; a misplaced key (K); and the
hook's output for that root.

## 12. Delivery

- **Order.** `lib/adr.lua` and its tests come first; the `status.lua` wiring builds on it; the
  reference changes can proceed beside both; the skills and the reviewer follow the references and
  the wiring; documentation and the version bump come last.
- **References.** `references/artifact-chain.md` gains `adrs/` in the layout (§3) and in the scan's
  skip list (§9), the four keys (§6), the ADR states and transitions (§7.1, §7.2), the ADR
  finality and consequential flip in §7.4 (spec §2.3), I6 and I7 (§10.3), C5–C7 and the
  completion rule (§10.4), K in a section of its own beside §11.6 (spec §4.1), and a new section
  for ADR rows and layout.
  `references/templates.md` gains the ADR body shape. `references/artifact-review.md` gains the
  ADR criteria.
- **Documentation.** `plugins/claudestacks-sdlc/README.md`; the description in
  `plugins/claudestacks-sdlc/.claude-plugin/plugin.json` and at `.claude-plugin/marketplace.json:17`;
  `CLAUDE.md:235`; `README.md:44`; and the Lua test count at `CLAUDE.md:206`.
- **Version.** `plugins/claudestacks-sdlc/.claude-plugin/plugin.json` moves from `0.2.1` to
  `0.3.0`.

## 13. Non-goals

- Making ADRs a required stage, or any skill prompting the author to create one.
- Citing an ADR from an intent, or from a spec-skip chain's plans.
- Re-checking finished chains against ADRs that changed after they closed (disproof rows excepted,
  §5.1).
- Importing existing ADRs from another location or tool, or migrating existing chains to cite ADRs.
- Recording a deprecation's reason inside the sealed ADR.
- Judging whether a spec's prose agrees with the ADRs it cites; that stays with `artifact-reviewer`.
- Validating the placement of keys other than `adrs` and `disproves-adr`.
- Repairing a disagreement automatically.
