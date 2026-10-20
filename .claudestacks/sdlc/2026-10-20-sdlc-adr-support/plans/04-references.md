---
status: done
created: 2026-10-20
built-on: 9078f8c84ed0
---

# ADR References Implementation Plan

**Goal:** The plugin's three reference files state every ADR rule that the board, the
skills, the no-`airsl` fallback and the reviewer read.

**Architecture:** `references/artifact-chain.md` stays the single source the board's prose
mirror and the status fallback derive from (`skills/status/SKILL.md:15-24`), so every ADR
rule lands there: in the existing sections where chain rules already live (§3, §6, §7,
§9, §10.3, §10.4), rule K in a new §11.7 beside §11.6 (spec §12), and one new section,
§13, for the ADR artifact itself, its rows and its layout. `templates.md` gains the ADR body shape and
`artifact-review.md` the ADR review criteria. This plan writes prose only and can run
beside plans 01–03.

**Tech Stack:** Markdown.

**Content authority:** spec §2, §3, §4, §5, §8, §12 (References).

---

## Files that change

```
plugins/claudestacks-sdlc/references/artifact-chain.md   — [modify] ADR layout, keys, states, rules and a new §13
plugins/claudestacks-sdlc/references/templates.md        — [modify] ADR body shape
plugins/claudestacks-sdlc/references/artifact-review.md  — [modify] § Reviewing a draft ADR
```

Every path is relative to the repository root. There is no Lua change and no test: the
gate for every task is that every wording the task lists is present verbatim, checked by
the `grep -F` commands it names, and that `cargo make plugins` still passes (nothing it
runs reads these files, so it must stay at the count it had before this plan).

**Wording rule.** Every STATE and NEXT string written into `artifact-chain.md` is copied
from the spec exactly (spec §4.1-§4.3 tables, §5.1 table), because the board's Lua code
and the status fallback must produce the same characters. Plan 07 re-checks each against
the rendered board.

Section numbers below are the file's current headings
(`references/artifact-chain.md`: §3 at :25, §6 at :91, §7.1 at :135, §7.2 at :145,
§7.4 at :180, §8 at :196, §9 at :204, §10 at :240, §10.3 at :288, §10.4 at :305, §11.6 at
:451, §12 at :466).

## Order of work

### Task 1 — State the ADR rules in `artifact-chain.md`

**Files:**
- Modify `plugins/claudestacks-sdlc/references/artifact-chain.md`

**Change:**

- **§3 Layout** — the tree gains `adrs/` with one `NNNN-<topic>.md` entry, commented
  "optional; created on first use by the adr skill", and the bullets gain one: `adrs/` is
  optional, never created by `setup`, and holds one repository-wide series (spec §2.1).
- **§6 Frontmatter schema** — the key list and table gain `adrs` (list of ADR numbers;
  optional; spec only) and `disproves-adr` (list of ADR numbers; optional; plan only;
  written by `execute`, never removed), so "all ten keys" (:94) becomes "all twelve
  keys". A closing sentence, beside the one for roadmap and milestone files (:130-131),
  says an ADR file carries `status`, `created`, and optionally `supersedes` and
  `sealed` (§13), that `sealed` and `supersedes` are ignored on a chain artifact, and
  that number lists are read as spec §3 says (four digits, `3` → `0003`).
- **§7.1** — a row `adr | draft → approved; approved → superseded; approved →
  deprecated; draft → dropped; dropped → draft`.
- **§7.2** — the six ADR transitions of spec §2.3, flipped by `adr`; the intent
  `approved → done` row (:151) changes "neither C1 nor C2 holds" to "none of C1, C2, C5,
  C6, C7 holds".
- **§7.4 Reversibility** — one paragraph, after the roadmap paragraph (:190-194): an
  ADR's `superseded` and `deprecated` are final, and reviving a retired decision is a new
  ADR; and the list of transitions that fire without a fresh question (:185-188) gains
  the ADR `approved → superseded` flip that follows the approval of an ADR listing it
  (spec §2.3).
- **§8 Spec skip** — one sentence: a chain that skips its spec cannot cite an ADR, since
  only a spec carries `adrs` (spec §3).
- **§9** — the skip list (:209) names `adrs/` beside `prds/`, `rfcs/` and `roadmaps/`,
  and the sentence pointing at §11 also points at §13 for the ADR block.
- **§10.3** — rows I6 and I7 with the STATE strings of spec §4.2, then the two
  paragraphs of spec §4.2 (I7 reads only live disproofs; a duplicated number is I6, an
  invalid single file resolves and reads C7).
- **§10.4** — the definition of *disproven* (spec §4.3, first sentence), rows C5, C6, C7
  with spec §4.3's STATE parts and NEXT, the paragraph on `MMMM` and the lowest number,
  and the paragraph on approved-spec-only reading and clearing; the STATE list (:321-327)
  gains the C5, C6 and C7 parts after C2 and the no-plans exception extends to C6 and C7;
  the NEXT paragraph (:329-331) becomes the order C1, C2, C5, C6, C7, C3, C4; the
  completion paragraph (:333-336) names C1, C2, C5, C6 and C7.
- **§11.6** — the ranking sentence (:462) adds that rule K (§11.7) ranks after these two.
- **New §11.7 Misplaced ADR keys**, after §11.6 — spec §4.1's table, NEXT `fix <chain>`,
  the check order, that it applies to every chain whose intent is `draft` or `approved`
  whether or not any roadmap exists, and its rank: after §11.6's membership problems and
  before I2. One opening sentence says it sits beside §11.6 because it ranks with those
  results, not because it concerns roadmaps, so §11's opening sentence (:340-341) is not
  read as excluding it.
- **New § 13. Architecture decision records**, after §12, opening with the optionality
  sentence (a repository with no `adrs/` sees no ADR behaviour), with:
  - **13.1 Files** — spec §2.1 in full.
  - **13.2 Seal and supersession** — spec §2.2's key table and the sentence on
    `supersedes` staying a link; spec §2.4.
  - **13.3 ADR rows** — spec §5.1's table, the paragraph that an invalid ADR has no
    status for any other rule, and the paragraph that disproofs are read from every
    parseable chain whatever its intent's status, naming the first chain and lowest plan.
    It also states the two rules plan 01 *Readings* fixes, so the fallback derives the
    same rows as `lib/adr.lua`: a **lister** of an ADR is a valid ADR, invalid by no row,
    whose status is `approved`, `superseded` or `deprecated` and whose `supersedes` names
    it, so a lister that is itself invalid does not count; and in a `supersedes` cycle,
    an ADR whose validity is still being worked out does not count as a lister of any
    ADR reached from it.
  - **13.4 Layout** — spec §5.2's bullets (heading, ADR rows, nothing without ADR files,
    an ADR-only root renders the board, `open` counts chains only), with the block placed
    after every chain row in either layout and before `DONE/DROPPED`. No sample board
    with column padding is included.

**Proof:** each command prints at least one line, run from the repository root with
`F=plugins/claudestacks-sdlc/references/artifact-chain.md` —
- `grep -nF 'all twelve keys' "$F"`
- `grep -nF 'disproves-adr' "$F"`
- `grep -nF 'INVALID (spec.md: unknown ADR NNNN)' "$F"` and `grep -nF 'INVALID (spec.md: ambiguous ADR NNNN)' "$F"`
- `grep -nF 'INVALID (plans/NN: disproves uncited ADR NNNN)' "$F"`
- `grep -nF 'ADR NNNN disproven by plan NN' "$F"` and `grep -nF 'ADR NNNN disproven by <chain>/NN' "$F"`
- `grep -nF 'spec stale (ADR NNNN superseded by MMMM)' "$F"` and `grep -nF 'spec stale (ADR NNNN deprecated)' "$F"`
- `grep -nF 'spec blocked (ADR NNNN not approved)' "$F"`
- `grep -nF 'not allowed here' "$F"`
- `grep -nF 'superseded by MMMM but still approved' "$F"`, `grep -nF 'superseded by MMMM but still <status>' "$F"`, `grep -nF 'superseded by nothing' "$F"`, `grep -nF 'edited after approval' "$F"`, `grep -nF 'missing sealed' "$F"`, `grep -nF 'supersedes unknown MMMM' "$F"`, `grep -nF 'duplicate number NNNN' "$F"`
- `grep -nF 'adr supersede NNNN' "$F"` and `grep -nF 'fix adr NNNN' "$F"`
- `grep -nE '^## 13\. ' "$F"` and `grep -nE '^### 11\.7 ' "$F"`
- `grep -nF 'cycle' "$F"`
- `grep -nF 'neither C1 nor C2' "$F"` prints nothing.

**Done when:** every command above behaves as stated and `cargo make plugins` passes.
Commit `docs(repo): state claudestacks-sdlc ADR rules in the artifact chain reference`.

### Task 2 — Add the ADR body shape to `templates.md`

**Files:**
- Modify `plugins/claudestacks-sdlc/references/templates.md`

**Change:** the title line (:1) names ADRs among the body shapes. A new section
`` ## `adrs/NNNN-<topic>.md` `` after the milestone section (:177-199) and before
`## A parked intent` (:200) holds spec §2.2's template — frontmatter `status: draft`,
`created`, the optional `supersedes` line, and the body `# ADR <NNNN>: <title>` with
`## Context`, `## Options considered`, `## Decision`, `## Consequences` and their
bracketed guidance — followed by two sentences: `sealed` is written by the `adr` skill at
approval and never by hand, and the body is never edited after approval (artifact-chain
§13.2).

**Proof:** run from the repository root with
`T=plugins/claudestacks-sdlc/references/templates.md` —
- `grep -nE '^## .adrs/NNNN-<topic>\.md.$' "$T"` prints one line, and its line number is below the milestone section's and above `## A parked intent`'s.
- `grep -nF '# ADR <NNNN>: <title>' "$T"` and `grep -nF '## Options considered' "$T"` each print one line.

**Done when:** both checks hold. Commit
`docs(repo): add the claudestacks-sdlc ADR template`.

### Task 3 — Add the ADR review criteria to `artifact-review.md`

**Files:**
- Modify `plugins/claudestacks-sdlc/references/artifact-review.md`

**Change:** a new section `## Reviewing a draft ADR` after `## Reviewing a draft plan
set` (:99), in the shape of the spec section (:51): an *Authority* line — none for a new
ADR, the replaced ADR(s) for a supersede — and *Body shape: `templates.md` §
`adrs/NNNN-<topic>.md`*, then the criteria of spec §8: no placeholders; at least two real
options, each with its trade-offs; the decision follows from the context; the
consequences name costs as well as benefits; every claim carries its proof by the same
rule as a spec (pointing at the spec section's grounding criteria rather than restating
them); on a supersede, the context states what in the replaced ADR no longer holds. The
file's opening sentence (:3) gains ADRs among what is reviewed.

**Proof:** run from the repository root with
`R=plugins/claudestacks-sdlc/references/artifact-review.md` —
- `grep -nF '## Reviewing a draft ADR' "$R"` prints one line below `## Reviewing a draft plan set`.
- `grep -nF 'Options considered' "$R"` and `grep -nF 'no longer holds' "$R"` each print at least one line.

**Done when:** both checks hold. Commit
`docs(repo): add claudestacks-sdlc ADR review criteria`.

---

## Risks

- **Drift between the prose and the Lua** is the main risk: the two are written in
  separate plans from the same spec. The wording rule above and plan 07's walkthrough,
  which compares the rendered board with this file, are the guard.
- **§11.7 sits under *Roadmaps and milestones*,** as spec §12 places it ("beside
  §11.6"), though K is not about roadmaps. Its opening sentence says so, so a reader of
  §11's opening sentence does not take K to vanish in a repository without roadmaps.
- Not done here: any skill's prose (plans 05, 06) and the plugin README (plan 07).

## Proof

- Every `grep` above behaves as stated.
- Read top to bottom, `artifact-chain.md` lets a reader with no `airsl` derive the ADR
  block and every chain's ADR condition for a sample root: plan 07's walkthrough does
  that comparison against the real board.

## Review findings

One `claudestacks:reviewer` round over the batch (Tasks 1–3), then one fix round. Verdict
before fixes: code 0🔴 4🟡 6🔵, spec 2🟡 2🔵; blocking: the first line below.

- wording-rule — rows 6–8 and §10.4's `MMMM` said "sealed ADR" where plan 01 *Readings* make them count valid listers, so the fallback could name a different successor than the board — `artifact-chain.md` §10.4, §13.3 — fixed: rows 6–7 read "listed by a lister `MMMM`", row 8 "no lister lists it", `MMMM` "the lowest-numbered lister of `NNNN` (§13.3)"
- wording-rule — I7's "lowest number first" was ambiguous between plan and ADR order — `artifact-chain.md` §10.3 — fixed: lowest plan, then lowest ADR within it (plan 03 :107-110)
- wording-rule — the cycle rule dropped plan 01's "cached once known", making the fallback order-dependent — `artifact-chain.md` §13.3 — fixed, then superseded: the amended spec's `supersedes cycle` row replaced the whole cycle rule (Deviations)
- wording-rule — the `ADRS:` heading format was unstated with no sample board — `artifact-chain.md` §13.4 — fixed: `<n> <word>`, comma-separated, non-zero counts, plan 01 Task 3 order
- wording-rule — number-list sentence narrower than `lib/status.lua` (bare scalar; non-numeric block item) — `artifact-chain.md` §6 — fixed
- nit — "(§10.4)" did not support "the spec may stop citing it" — `artifact-chain.md` §10.4 — fixed: points at C6 and `design`
- nit — footer omitted roadmap, milestone and ADR body shapes — `artifact-chain.md` closing paragraph — fixed
- nit — "checks are internal except the proof check" contradicted by the supersede check — `artifact-review.md` § Reviewing a draft ADR — fixed
- nit — "last two bullets above" was position-dependent — `artifact-review.md` § Reviewing a draft ADR — fixed: named by bold leads, incomplete-review paragraph applies
- not verified — §13.3 claims agreement with `scripts/lib/adr.lua`, which derived no rows when reviewed — `artifact-chain.md` §13.3 — open until plan 01 completes
- addition — 🔴 tier pins on the one-option and supersede criteria are not in spec §8 — `artifact-review.md` — kept, precedent at `artifact-review.md:117`
- spec amendment — spec §4.3's `MMMM` still said "sealed"; spec §4.2's I7 order and spec intro :14-15 likewise — `spec.md` — amended: all three fixed in the spec redesign of 2026-10-20 (Deviations)

Fix verified by re-running every Proof grep after the fix round and again after the
cycle-row sync (2026-10-20). `grep -cF` counts for the Task 1 list, in order, after the
sync: `1 10 1 1 1 1 1 1 1 1 3 1 2 2 2 2 2 1 1 7 5 0` (the final `0` is
`neither C1 nor C2`; four row reasons and `cycle` now also appear in §13.2, and the cycle
row adds one `fix adr NNNN`); `supersedes cycle` 2, `still being worked out` 0;
`534:### 11.7 Misplaced ADR keys`,
`578:## 13. Architecture decision records`; templates.md `177 < 200 < 231`;
artifact-review.md `100:## Reviewing a draft plan set`, `142:## Reviewing a draft ADR`.
`cargo make plugins` before the fix round: `522 passed, 0 failed (23 files)` (the 23rd
file is plan 01's `adr_test.lua`; nothing it runs reads these files).

## Probe results

No throwaway probe was run: every task's proof is its own grep list, run before (all
absent) and after (all present) by each writer and again by the orchestrator. Section
line citations in *Files that change* were checked against the file before Task 1
(`artifact-chain.md`: §3 :25, §6 :91, §8 :196, §9 :204, §10 :240, §11 :338, §12 :466;
`:94` "all ten keys", `:151` "neither C1 nor C2", `:209` skip list, `:462` ranking
sentence — all as the plan states; `artifact-review.md` :3, :51, :99 and `templates.md`
:177, :200 as stated).

## Deviations

- 2026-10-20 — §13's opening sentence widened from "a repository with no `adrs/` sees no
  ADR behaviour" to "no `adrs/` directory, and no chain artifact carrying an `adrs` or
  `disproves-adr` key", because rules K and I6 (spec.md:202-204, :218) fire on those keys
  without `adrs/`. The same claim in spec.md:14-15 was put to the author, who ruled it a
  wording nit: no `disproves` marker, fix when the spec next changes. It was fixed in the
  spec redesign below.
- 2026-10-20 — Spec redesigned mid-run, on the author's word. Plan 01's Task 2 review
  found that plan 01's cycle rule (an in-progress ADR does not count as a lister) lets a
  hand-closed `supersedes` loop or a self-listing ADR stay silent, breaking spec §2.4's
  promise; plan 01 had said the spec did not address cycles. The author chose a new row:
  `spec.md` was archived as `spec-superseded-2026-10-20.md`, and a draft adding
  `INVALID (<file>: supersedes cycle)` / `fix adr NNNN`, the lister definition, and the
  three wording amendments above was reviewed once (0🔴 4🟡 4🔵; nit 2, renaming
  `superseded by nothing`, declined) and approved (fingerprint `9078f8c84ed0`). The author
  re-confirmed all seven plans against it, plans 01 and 04 with this deviation. §13.2,
  §13.3 and §13.4 were then synced: the cycle row, the spec's lister paragraph in place of
  the in-progress rule and the number-order evaluation, the hand-edit paragraph of spec
  §2.4, and "the ADR block adds no byte to the board".
- 2026-10-20 — `templates.md`'s intro sentence (:3-4) also names `adr` among the skills
  that write artifacts, beyond the title-line change the plan named.
- 2026-10-20 — §13.4 adds that an ADR with no row is counted in the heading and not
  listed; spec §5.2's sample implies it but its text does not say it.
- 2026-10-20 — The review's fix round (Review findings) changed wording beyond the plan's
  bullets: the lister wiring of rows 6–8 and `MMMM`, I7's tie order, the heading format
  (and a cycle direction and caching rule, later replaced by the cycle row).
- 2026-10-20 — Plan 03's review fix round added one sentence to §11.7: a misplaced key
  counts when present whatever its value, an empty list included, as distinct from §6's
  "an empty list means none" for reading citations. Spec §4.1 says only "`adrs` or
  `disproves-adr` on `intent.md`"; it was not amended.
