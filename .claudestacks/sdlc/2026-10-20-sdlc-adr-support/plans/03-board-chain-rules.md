---
status: approved
created: 2026-10-20
depends-on: [02]
built-on: c2d88a3e18f4
---

# Board Chain Rules for ADRs Implementation Plan

**Goal:** Every open chain's board row reports how its own artifacts relate to ADRs —
a misplaced key, an invalid citation or disproof, or a cited ADR that is disproven,
retired or not approved.

**Architecture:** `M.derive` in `scripts/lib/status.lua` gains a third parameter, the ADR
list plan 02 keeps on the board, and three local functions beside `membership_problem`:
one for misplaced keys (rule K), one for invalid citations (I6, I7), and one for the
conditions C5, C6 and C7. `M.sync` is left as it is, so its existing tests and its
returned shape stay unchanged; the new rules slot into `derive` at the ranks spec §4
gives them. All ADR facts — resolution, status, validity, disproof, successor — are read
from `lib/adr` (plan 01), never recomputed here.

**Tech Stack:** Lua 5.4 under `airsl` 0.1.2, cargo-make.

**Content authority:** spec §3 (keys), §4.1 (K), §4.2 (I6, I7), §4.3 (C5, C6, C7),
§4.4 (STATE, NEXT, completion), §9, §10, §11 (`status_test.lua` row).

---

## Files that change

```
plugins/claudestacks-sdlc/scripts/lib/status.lua   — [modify] rules K, I6, I7, C5, C6, C7 in derive
plugins/claudestacks-sdlc/scripts/status_test.lua  — [modify] tests for each rule, its rank and its STATE and NEXT
```

Every path is relative to the repository root. The gate for every task is
`cargo make plugins`, from the repository root. No Rust changes; no installed guideline
covers Lua (spec §1).

Plan 02 modified the same two files; this plan runs after it and reuses its
`adr_file(dir, name, fm, body)` test helper and `board.adrs`. The existing
`derive_only(dir)` helper (`scripts/status_test.lua:42-47`) calls `derive` with no ADR
list and keeps working: an absent list means no ADR. Tests in Tasks 2 and 3 read a
chain's row from `status.board(dir).rows` instead, through one new helper,
`row_of(dir, label)`, which returns the row whose label is `label` — the board is what
scans ADRs and marks disproofs.

**Where each rule enters `derive`** (`status.lua:301-430`), stated once:

```
chain.invalid (I1)                         :302-304
done / dropped → no check                  :310-312
draft:  membership → K → "intent draft"    :313-320
unknown intent status, unknown plan status :321-332
approved: membership → K → I2–I5 → I6 → I7 :334-343
conditions: C1, C2, C5, C6, C7 parts, then plan parts; NEXT C1, C2, C5, C6, C7, C3, C4
completion: none of C1, C2, C5, C6, C7     :394-398
no-plan branch                             :415-429
```

## Order of work

### Task 1 — Report a misplaced ADR key (rule K)

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/lib/status.lua` — local `misplaced_key(chain)`, called in `derive`
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`

**Change:** add `misplaced_key(chain)` — the first misplaced key of a chain, as the reason
`intent.md: <key> not allowed here`, `spec.md: disproves-adr not allowed here` or
`plans/NN: adrs not allowed here`, or nil. It checks `adrs` then `disproves-adr` on the
intent, then `disproves-adr` on the spec, then `adrs` on each plan in number order (spec
§4.1). A key counts as present when the frontmatter holds it at all, whatever its value.
`derive` calls it for a `draft` intent after `membership_problem` (`status.lua:314-317`)
and for an `approved` intent after `membership_problem` (`:335-337`) and before `M.sync`
(`:340`); a result renders `INVALID (<reason>)` → `fix <chain>`. A `done` or `dropped`
chain returns before either call (`:310-312`), so it is not checked. `sealed` and
`supersedes` on a chain artifact are not read by anything (spec §3).

**Proof:** written first, seen failing, then passing —
- `adrs_on_an_intent_is_invalid` — an approved intent carrying `adrs: [0001]` derives `INVALID (intent.md: adrs not allowed here)` / `fix 2026-08-24-a`; a draft intent carrying it derives the same.
- `disproves_adr_on_an_intent_is_invalid` — `INVALID (intent.md: disproves-adr not allowed here)`.
- `disproves_adr_on_a_spec_is_invalid` — `INVALID (spec.md: disproves-adr not allowed here)`.
- `adrs_on_a_plan_is_invalid` — plan `02` carrying a block-list `adrs` derives `INVALID (plans/02: adrs not allowed here)`.
- `misplaced_keys_report_intent_then_spec_then_plans` — `adrs` on the intent and on plan `01` reports the intent; `disproves-adr` on the spec and `adrs` on plan `01` reports the spec.
- `a_misplaced_key_ranks_after_membership_and_before_i2` — an intent with `adrs` and an unknown `milestone` reports the membership problem; a spec with `disproves-adr` and status `final` reports K, not `unknown status final`.
- `a_finished_chain_is_not_checked_for_misplaced_keys` — a `done` intent carrying `adrs` derives `done`.
- `sealed_and_supersedes_on_chain_artifacts_are_ignored` — an approved chain whose spec and plan carry `sealed` and `supersedes` derives as if they were absent (`plan 01 approved` / `execute 01`).

**Done when:** `cargo make plugins` passes. Commit
`feat(repo): report misplaced ADR keys on the claudestacks-sdlc board`.

### Task 2 — Report invalid citations and disproofs (I6, I7)

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/lib/status.lua` — `derive(chain, roadmaps, adrs)`; local `citation_problem(chain, adrs)`; `M.board` passes `board.adrs`
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`

**Change:** `M.derive` takes `adrs`, plan 01's scan as marked by `mark_disproofs`; absent
means none. `M.board` passes `board.adrs` at its `derive` call (`status.lua:476`).
`citation_problem(chain, adrs)` returns the first reason, or nil:

- **I6** — the lowest number in the spec's `adrs` (read with `adr.numbers`) for which
  `adr.resolve` reports `unknown` or `ambiguous`: `spec.md: unknown ADR NNNN` /
  `spec.md: ambiguous ADR NNNN`. A number resolving to one invalid file is not I6
  (spec §4.2).
- **I7** — the lowest plan that is not `superseded` whose `disproves-adr` names a number
  resolving to one valid `approved` ADR that the spec's `adrs` does not hold, or any such
  number when there is no `spec.md`: `plans/NN: disproves uncited ADR NNNN`, the lowest
  number within that plan.

`derive` calls it after `M.sync`'s invalid check (`status.lua:340-343`); a result renders
`INVALID (<reason>)` → `fix <chain>`. I6 reads the spec whatever its status, as I2 does.

**Proof:** written first, seen failing, then passing —
- `a_spec_citing_an_unknown_adr_is_invalid` — approved spec with `adrs: [0001, 0007]`, only `0001` exists: `INVALID (spec.md: unknown ADR 0007)` / `fix 2026-08-24-a`.
- `a_spec_citing_a_duplicated_number_is_ambiguous` — two `0001-*.md` files: `INVALID (spec.md: ambiguous ADR 0001)`, not the C7 part.
- `the_lowest_unresolved_number_is_reported` — `adrs: [0009, 0004]`, neither exists: `unknown ADR 0004`.
- `a_short_number_resolves_to_four_digits` — `adrs: [1]` with a valid approved `0001` derives `spec approved` / `plan`.
- `a_plan_disproving_an_uncited_approved_adr_is_invalid` — spec cites nothing; plan `02` names valid approved `0003`: `INVALID (plans/02: disproves uncited ADR 0003)`.
- `a_spec_skip_plan_disproving_an_adr_is_invalid` — spec skipped, no `spec.md`; plan `01` names valid approved `0003`: `INVALID (plans/01: disproves uncited ADR 0003)`.
- `a_superseded_plan_is_not_read_for_i7` — the same plan flipped `superseded`: no INVALID.
- `a_disproof_of_a_retired_adr_the_spec_no_longer_cites_is_valid` — plan `02` names `0003`, which is `superseded` and listed by approved `0009`; the spec cites `0009`: no INVALID (spec §6.3).
- `i6_ranks_before_i7` — a spec citing an unknown `0007` and a plan `01` disproving an uncited valid approved `0003`: `INVALID (spec.md: unknown ADR 0007)`.
- `citation_problems_rank_after_i5` — a live plan with no `built-on` and a spec citing an unknown ADR: `INVALID (plans/01: missing built-on)`.

**Done when:** `cargo make plugins` passes. Commit
`feat(repo): report invalid ADR citations on the claudestacks-sdlc board`.

### Task 3 — Report disproven, retired and unapproved cited ADRs (C5, C6, C7)

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/lib/status.lua` — local `adr_conditions(chain, adrs)`; STATE, NEXT and completion in `derive`
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`

**Change:** `adr_conditions(chain, adrs)` returns the C5, C6 and C7 parts, each nil when
its condition does not hold (spec §4.3). An ADR is **disproven** when `mark_disproofs`
set its `disproven_by` (plan 01, Task 3).

- **C5** — the ADRs that are disproven and either named in the `disproves-adr` of a plan
  of this chain that is not `superseded`, or cited by an `approved` spec. The part names
  the lowest such number: `ADR NNNN disproven by plan NN` when a plan of this chain names
  it (the lowest such plan), otherwise `ADR NNNN disproven by <chain>/NN` from its `disproven_by`.
- **C6** — the approved spec cites a valid ADR whose status is `superseded` or
  `deprecated`; for the lowest such number, `spec stale (ADR NNNN superseded by MMMM)`
  with `MMMM` from `adr.successor`, or `spec stale (ADR NNNN deprecated)`.
- **C7** — the approved spec cites an ADR that is `draft`, `dropped` or invalid; for the
  lowest, `spec blocked (ADR NNNN not approved)`.

C6, C7 and C5's citation half read an `approved` spec only (spec §4.3). In `derive`:

- **STATE** (`status.lua:345-353`): after the C1 and C2 parts, the C5, C6, C7 parts in
  that order, then the plan parts (spec §4.4).
- **NEXT** (`:354-358`): `sync_next` becomes the first that holds of C1 → `design`,
  C2 → its existing value, C5 → `adr`, C6 → `design`, C7 → `adr`, C3 → `approve spec`,
  C4 → `plan`.
- **Completion** (`:394`): `chain complete` additionally requires that none of C5, C6, C7
  holds.
- **No plans** (`:415-418`): the branch that today returns the parts when C1 holds also
  returns them when C6 or C7 holds, so `spec approved` is omitted then; when only C5
  holds (which, without plans, means its citation half), the parts are followed by
  `spec approved`, with NEXT `adr`.

**Proof:** written first, seen failing, then passing — fixtures cite through spec
frontmatter `adrs: [..]` and seal ADRs with `fingerprint.of_text`:
- `a_plan_disproving_a_cited_adr_reads_disproven_by_plan` — spec cites `0003`; plan `01` done, plan `02` executing with `disproves-adr: [0003]`: `ADR 0003 disproven by plan 02, plan 01 done, plan 02 executing` / `adr`.
- `a_sibling_citing_a_disproven_adr_reads_disproven_by_chain` — chain `2026-08-24-a` as above and chain `2026-08-25-b` whose approved spec cites `0003`, with plan `01` approved: `b` reads `ADR 0003 disproven by 2026-08-24-a/02, plan 01 approved` / `adr`.
- `a_spec_citing_a_superseded_adr_reads_stale_by_successor` — spec cites `0003`, superseded and listed by approved `0009`; plan `01` approved: `spec stale (ADR 0003 superseded by 0009), plan 01 approved` / `design`.
- `a_spec_citing_a_deprecated_adr_reads_stale_deprecated` — `spec stale (ADR 0003 deprecated)`.
- `a_spec_citing_an_unapproved_adr_reads_blocked` — for `0003` `draft`, then `dropped`, then invalid (`missing sealed`): `spec blocked (ADR 0003 not approved)` / `adr`.
- `a_draft_spec_reads_no_adr_condition` — a draft spec citing a draft `0003`, a superseded one and a disproven one: no C5, C6 or C7 part (`spec draft` / `approve spec`).
- `adr_parts_follow_c1_and_lead_the_plan_parts` — C1, C5 (chain `2026-08-25-b` plan `01` disproved `0001`), C6 and C7 together with plan `01` approved: `spec stale (intent changed), ADR 0001 disproven by 2026-08-25-b/01, spec stale (ADR 0002 deprecated), spec blocked (ADR 0004 not approved), plan 01 approved` / `design`.
- `next_follows_c1_c2_c5_c6_c7_c3_c4` — C5 with C6 gives `adr`; C6 with C7 gives `design`; C7 with a stale plan (C4) gives `adr`; C2 with C5 gives `design`, and its STATE starts `spec disproven by plan 01, ADR 0003 disproven by plan 01` (the C2 part before the C5 part).
- `the_lowest_number_names_each_condition` — the spec cites `0005` and `0002`, both deprecated: `spec stale (ADR 0002 deprecated)`.
- `each_adr_condition_prevents_chain_complete` — every plan `done`, with C5, then C6, then C7 standing: the STATE is the condition part followed by `plan 01 done`, never `chain complete`, and NEXT is that condition's.
- `a_chain_without_plans_omits_spec_approved_under_c6_or_c7` — no plans, spec citing a deprecated `0003`: `spec stale (ADR 0003 deprecated)` / `design`; citing a draft: `spec blocked (ADR 0003 not approved)` / `adr`.
- `a_chain_without_plans_keeps_spec_approved_under_c5` — no plans, spec citing `0003`, which plan `01` of chain `2026-08-25-b` disproved: `ADR 0003 disproven by 2026-08-25-b/01, spec approved` / `adr`.
- `a_chain_citing_healthy_adrs_reads_as_before` — spec citing a valid approved `0001`, plan `01` approved: `plan 01 approved` / `execute 01`.
- `the_hook_shows_chains_with_broken_adr_citations` — three chains reading C5, C6 and C7: `status.attention` counts `3 need attention` and lists the three chain rows (`disproven`, `stale` and `blocked` are attention words, `status.lua:588`).

**Done when:** `cargo make plugins` passes. Commit
`feat(repo): report broken ADR citations on the claudestacks-sdlc board`.

---

## Risks

- **NEXT and completion ordering** (Task 3) is the riskiest step: `sync_next` and the
  completion test (`status.lua:354-358`, `:394`) decide what every other skill reads,
  and an off-by-one in the order would let `execute NN` appear under a standing C5, C6
  or C7. `next_follows_c1_c2_c5_c6_c7_c3_c4` and
  `each_adr_condition_prevents_chain_complete` pin it.
- **The C5 own-plan form wins over the mark.** When this chain's plan and an earlier
  chain both disproved the same ADR, this chain reads `by plan NN` while the ADR row
  names the earlier chain. That is what spec §4.3 states; a test pins only the sibling
  case.
- **`derive`'s new parameter** is optional, so every existing call through
  `derive_only` and every existing assertion stay as they are.
- Not done here: the prose for any rule (plan 04) and the skills reacting to them
  (plan 06).

## Proof

- `cargo make plugins` passes; every pre-existing test is unchanged.
- Every rule of spec §4 — each row of K, I6, I7, C5, C6, C7, the STATE order, the NEXT
  order and the completion rule — and every `status_test.lua` item spec §11 lists that
  plan 02 did not cover has a named test in this plan.
- `sh plugins/claudestacks-sdlc/scripts/status.sh`, run from the repository root,
  prints this repository's board unchanged.
