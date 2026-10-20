---
status: approved
created: 2026-10-20
built-on: c2d88a3e18f4
---

# ADR Library Implementation Plan

**Goal:** Every file in `adrs/` resolves, through a new `lib/adr.lua`, to a status, a
validity and the board row spec §5.1 gives it.

**Architecture:** One new Lua module, `plugins/claudestacks-sdlc/scripts/lib/adr.lua`,
owns everything about ADR files: scanning, number lists, the seal, supersession,
disproof and the row of each ADR. It follows `lib/roadmap.lua`: it takes lib/status's
`read_artifact` as a parameter so it never requires `lib/status`
(`scripts/lib/roadmap.lua:25-30`), and it may require `lib/fingerprint`, which has no
dependency on either. Nothing consumes the module yet; plan 02 wires it into the board.

**Tech Stack:** Lua 5.4 under `airsl` 0.1.2 (`airsstack.fs`, `airsstack.path`),
`lib/fingerprint.lua`, cargo-make.

**Content authority:** spec §2 (files, frontmatter, states, seal), §3 (number lists),
§4.3 (the definition of *disproven*), §5.1 (ADR rows), §5.2 (heading), §10, §11
(`adr_test.lua` row).

---

## Files that change

```
plugins/claudestacks-sdlc/scripts/lib/adr.lua    — [create] ADR scanning, validity, disproof, rows and heading
plugins/claudestacks-sdlc/scripts/adr_test.lua   — [create] tests for lib/adr
```

Every path is relative to the repository root. The gate for every task is
`cargo make plugins` (it runs `airsl check plugins` then the `airsl test` suite,
`Makefile.toml:112-219`), from the repository root; it needs the `airsl` binary
(`cargo make install-airsl`). No Rust changes, so the Rust Definition of Done does not
apply, and no installed guideline covers Lua (spec §1, closing paragraph): the module
layout follows the `lib/roadmap.lua` precedent.

Baseline, from spec P3: `cargo make plugins-test` reports `506 passed, 0 failed (22 files)`.

**Conventions the tests follow** (read from the existing files, so the new one reads
like them):

- A test file returns a table of `snake_case_name = function() … end` entries at
  two-space indent, and loads modules with `require("lib.<name>")` — no file sets
  `package.path` (`scripts/roadmap_test.lua:8-9`, `:68`).
- Fixtures are built fresh per test under `airsstack.fs.tempdir()` with `path.join` and
  `fs.write`, as `scripts/roadmap_test.lua:15-35` and `scripts/status_test.lua:22-35` do.
- `adr_test.lua` requires `lib.adr`, `lib.status` (for `read_artifact` and, in Task 3,
  `scan`, as `roadmap_test.lua:9` does) and `lib.fingerprint` (to write a correct
  `sealed` value).

**Readings this plan fixes**, each from the spec or a precedent it names:

- `<file>` in an ADR's `INVALID (<file>: <reason>)` is the bare file name, e.g.
  `0003-queue.md` — the milestone precedent the spec's §5.1 mirrors
  (`scripts/lib/roadmap.lua:65`, `:77`, `references/artifact-chain.md:431-432`).
- The reasons for spec §5.1's first row are the ones `read_artifact` already returns —
  `unreadable`, `missing frontmatter`, `unterminated frontmatter`, `missing status`
  (`scripts/lib/status.lua:33`, `:58`, `:67`, `:74`) — plus `unknown status <status>`
  for a status outside `draft`, `approved`, `superseded`, `deprecated`, `dropped`.
- A **lister** of an ADR is a *valid* ADR — invalid by no row of spec §5.1 — whose
  status is `approved`, `superseded` or `deprecated` and whose `supersedes` names it.
  This is spec §5.1's "an invalid ADR has no status for any other rule" read literally,
  so a lister that is itself invalid by row 6, 7 or 8 does not count: in an interrupted
  supersede (`0003` superseded and listed by `0009`; `0009` listed by sealed `0012` but
  still `approved`), `0009` is invalid, `0003` reads `superseded by nothing`, and a chain
  citing `0003` reads C7 — what spec §4.3 states. Rows 6–8 of an ADR therefore depend on
  the full validity of its listers, which is evaluated recursively along `supersedes`
  links, each ADR's result cached once known.
- **A `supersedes` cycle** (`0001` lists `0002` and `0002` lists `0001`, reachable only
  by hand-editing frontmatter, since *approve* refuses unless every listed ADR is
  `approved`) would make that recursion endless. The spec does not address it. This plan
  decides: while an ADR's validity is being evaluated, it does not count as a lister of
  any ADR reached from it, so the recursion always ends and every ADR on the cycle gets
  one of spec §5.1's existing rows. Plan 04 writes this rule, and the lister rule above,
  into `artifact-chain.md` §13.3 so the board and the no-`airsl` fallback agree
  (`scripts/lib/status.lua:7-8`).

## Order of work

### Task 1 — Scan `adrs/` and read number lists

**Files:**
- Create `plugins/claudestacks-sdlc/scripts/lib/adr.lua`
- Create `plugins/claudestacks-sdlc/scripts/adr_test.lua`

**Change:** add the module with:

- `M.DIR` — the directory name `adrs`, which plan 02 adds to lib/status's skip list.
- `M.numbers(value)` — reads a number-list frontmatter value into a list of four-digit
  strings, in written order: a block list's items, or every `%d+` run of an inline
  string (spec P2, §3). Each numeric token is normalised to four digits (`3` → `0003`).
  A non-numeric block-list item passes through unchanged, so a typo surfaces as an
  unknown number instead of vanishing — the rule `normalize_dep` follows
  (`scripts/lib/status.lua:168-177`). Absent, an empty block list (an empty `key:`
  parses as `{}`, `status.lua:48-50`) and `[]` all read as an empty list.
- `M.scan(rootdir, read_artifact)` — every plain file in `<rootdir>/adrs/` whose name
  matches `^%d%d%d%d%-.+%.md$`, in `fs.list` order (four digits, so number order), as a
  record `{ num, file, fields, text, status, invalid }` — `status` is nil whenever
  `invalid` holds a reason; Task 3 adds `disproven_by = { chain, plan }`. Plans 02 and 03
  read these field names. Every other entry, subdirectories included, is ignored (spec §2.1).
  Empty when `adrs/` is absent. This task fills rows 1 and 2 of spec §5.1: an unreadable
  file, one `read_artifact` rejects, or one with an unknown status is invalid with that
  reason; then every file whose number is shared by another file, and is not already
  invalid, is invalid with `duplicate number NNNN` — the order `roadmap.lua:75-80` uses.
  An invalid ADR has no status.
- `M.resolve(adrs, num)` — the one ADR whose number is `num` (normalised by the caller),
  or nil and `unknown` (no file) or `ambiguous` (two or more files), mirroring
  `roadmap.resolve` (`scripts/lib/roadmap.lua:106`). An invalid single file still
  resolves (spec §4.2).

**Proof:** written first, seen failing, then passing —
- `a_root_without_an_adrs_directory_scans_to_none` — `scan` of a root with no `adrs/` is an empty list.
- `only_four_digit_markdown_files_are_adrs` — beside `0001-a.md`, the entries `README.md`, `001-b.md`, `0002-c.txt`, a subdirectory `0003-d.md/` and a subdirectory `notes/` are not scanned; the result holds one ADR, `0001`.
- `adrs_scan_in_number_order` — files `0010-x.md`, `0002-y.md` and `0001-z.md` scan as `0001`, `0002`, `0010`.
- `an_inline_number_list_normalises_to_four_digits` — `numbers("[3, 0007, 12]")` is `0003`, `0007`, `0012`.
- `a_block_number_list_normalises_to_four_digits` — a block list of `3` and `0011` reads `0003`, `0011`.
- `an_absent_or_empty_number_list_reads_as_none` — `numbers(nil)`, `numbers({})` and `numbers("[]")` are each an empty list.
- `a_non_numeric_list_item_passes_through` — a block-list item `abc` reads back as `abc`.
- `an_unparseable_adr_is_invalid_with_its_reason` — a file with no frontmatter is invalid with `0001-a.md: missing frontmatter`, and one without `status` with `0002-b.md: missing status`; neither has a status.
- `an_unknown_adr_status_is_invalid` — `status: accepted` makes the ADR invalid with `0001-a.md: unknown status accepted`.
- `two_adrs_sharing_a_number_are_both_invalid` — `0004-a.md` and `0004-b.md`, both well-formed drafts, are each invalid with `<own file>: duplicate number 0004`.
- `an_unparseable_duplicate_keeps_its_first_reason` — of `0004-a.md` (no `status`) and `0004-b.md` (well-formed), the first reads `missing status` and the second `duplicate number 0004`.
- `resolve_finds_one_adr_by_number` — `resolve(adrs, "0001")` returns the ADR whose file is `0001-a.md`.
- `resolve_reports_unknown_and_ambiguous` — a missing number gives nil and `unknown`; a duplicated one nil and `ambiguous`.
- `resolve_returns_a_single_invalid_adr` — a lone `0005-x.md` with an unknown status resolves to that ADR.

**Done when:** `cargo make plugins` passes. Commit
`feat(repo): scan claudestacks-sdlc ADR files`.

### Task 2 — Check the seal and both halves of supersession

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/lib/adr.lua` — rows 3–8 of spec §5.1, `M.successor`
- Modify `plugins/claudestacks-sdlc/scripts/adr_test.lua`

**Change:** `M.scan` (Task 1) goes on to apply rows 3–8 of spec §5.1, in that order,
to each ADR that is still valid, the first that holds deciding its reason:

3. status `approved`, `superseded` or `deprecated`, and no `sealed` string — `missing sealed`;
4. the same statuses, and `fingerprint.of_text` of the file's text ≠ `sealed` —
   `edited after approval` (the fingerprint excludes frontmatter, spec P4);
5. one of those statuses, and a number in its `supersedes` (read with `M.numbers`)
   matches no ADR file — `supersedes unknown MMMM`, the lowest such number;
6. it has a lister (see *Readings*, above) and its status is `approved` —
   `superseded by MMMM but still approved`;
7. it has a lister and its status is `draft`, `dropped` or `deprecated` —
   `superseded by MMMM but still <status>`;
8. status `superseded`, and it has no lister — `superseded by nothing`.

`MMMM` in rows 6 and 7 is the lowest-numbered lister. `sealed` on a `draft` or `dropped`
ADR is ignored, and so is `supersedes` on any ADR that is not a lister-capable one
(spec §2.2). Rows 6–8 decide a lister's validity recursively, with the cycle rule of
*Readings*: an ADR whose validity is still being evaluated is not a lister.

Add `M.successor(adrs, num)` — the number of the lowest-numbered lister of `num`, or nil.
Rows 6–7 use it, and plan 03's C6 names `MMMM` with it (spec §4.3).

**Proof:** written first, seen failing, then passing —
- `a_sealed_status_without_sealed_is_invalid` — an `approved`, a `superseded` and a `deprecated` ADR, each with no `sealed`, are invalid with `missing sealed`.
- `a_draft_or_dropped_adr_ignores_sealed` — a `draft` with a wrong `sealed` value and a `dropped` with none are both valid.
- `an_approved_adr_matching_its_seal_is_valid` — `sealed` equal to the body's fingerprint gives a valid `approved` ADR.
- `an_approved_adr_edited_after_approval_is_invalid` — after the body is changed, the same ADR is invalid with `edited after approval`.
- `a_status_flip_never_breaks_the_seal` — the same body with `status` rewritten from `approved` to `deprecated` stays valid.
- `a_sealed_adr_superseding_an_unknown_number_is_invalid` — an approved `0002` with `supersedes: [0009]` and no `0009` file is invalid with `supersedes unknown 0009`.
- `a_listed_approved_adr_reads_superseded_but_still_approved` — sealed `0002` lists approved `0001`: `0001` is invalid with `superseded by 0002 but still approved`; `0002` is valid.
- `a_listed_draft_dropped_or_deprecated_adr_names_its_status` — the same with `0001` `draft`, then `dropped`, then `deprecated`, gives `superseded by 0002 but still draft` / `… dropped` / `… deprecated`.
- `a_superseded_adr_nothing_lists_is_invalid` — a lone sealed `superseded` `0001` is invalid with `superseded by nothing`.
- `a_draft_listing_an_adr_supersedes_nothing` — a `draft` `0002` with `supersedes: [0001]` leaves approved `0001` valid.
- `an_invalid_lister_supersedes_nothing` — `0002` edited after approval, listing superseded `0001`: `0001` reads `superseded by nothing`.
- `an_interrupted_supersede_invalidates_down_the_line` — `0003` superseded and listed by sealed `0009`; `0009` still `approved` and listed by sealed `0012`: `0009` reads `superseded by 0012 but still approved` and `0003` reads `superseded by nothing`; `successor(adrs, "0003")` is nil.
- `a_supersedes_cycle_ends` — sealed `0001` and `0002`, both `superseded`, each listing the other: `scan` returns, and each of the two carries an invalid reason from spec §5.1's rows.
- `a_second_generation_supersession_keeps_every_record_valid` — `0003` superseded, listed by `0009`; `0009` superseded, listed by `0012`; `0012` approved: all three valid.
- `a_deprecated_successor_keeps_its_predecessor_valid` — `0003` superseded and listed by `0009`, which is `deprecated` and sealed: both valid.
- `successor_is_the_lowest_valid_sealed_lister` — `0001` listed by sealed `0005` and sealed `0003`: `successor(adrs, "0001")` is `0003`; with `0003` edited after approval it is `0005`.
- `the_first_row_that_holds_names_the_reason` — an approved ADR both edited after approval and listed by a sealed ADR reads `edited after approval`; a deprecated ADR with no `sealed` that a sealed ADR lists reads `missing sealed`.

**Done when:** `cargo make plugins` passes. Commit
`feat(repo): check the seal and supersession of claudestacks-sdlc ADRs`.

### Task 3 — Read disproofs and derive each ADR's row and the heading

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/lib/adr.lua` — `M.mark_disproofs`, `M.row`, `M.heading`
- Modify `plugins/claudestacks-sdlc/scripts/adr_test.lua`

**Change:**

- `M.mark_disproofs(adrs, chains)` — `chains` is lib/status's `scan` result
  (`scripts/lib/status.lua:79-83`, `:139-151`). For every chain without `invalid`, in
  list order, and each of its plans whose status is not `superseded`, in number order,
  every number in its `disproves-adr` (read with `M.numbers`) that resolves to exactly
  one valid `approved` ADR marks that ADR disproven by that chain's name and plan
  number, unless an earlier chain or plan already marked it (spec §4.3, §5.1). The
  chain's intent status is not consulted, so a `done` or `dropped` chain counts. A chain
  marked `invalid` contributes nothing even though `read_chain` may already hold the
  plans it read before the failing file (`status.lua:118-131`) — spec §10 says its plans
  contribute no disproof.
- `M.row(adr)` — the STATE and NEXT of one ADR, or nil when it gets no row, per spec
  §5.1: an invalid ADR reads `INVALID (<reason>)` (its reason already starts with the
  file name) with NEXT `fix adr NNNN`, except `superseded by MMMM but still approved`,
  whose NEXT is `adr`, and `superseded by MMMM but still <status>`, whose NEXT is
  `fix adr MMMM`; a disproven ADR reads `disproven by <chain>/NN` → `adr supersede NNNN`;
  a `draft` reads `draft` → `approve or drop`; every other ADR gets no row.
- `M.heading(adrs)` — the heading label: `ADRS: ` followed by the non-zero counts, comma
  separated, in the order approved, superseded, deprecated, draft, dropped, invalid, as
  `<n> <word>` (spec §5.2). An invalid ADR counts only as invalid.

`status.scan` still reads `adrs/` as a chain until plan 02 adds it to the skip list; such
a chain is `invalid` (`intent.md missing`, spec P1), so `mark_disproofs` skips it and the
Task 3 fixtures need no workaround.

**Proof:** written first, seen failing, then passing —
- `a_plan_naming_an_approved_adr_disproves_it` — chain `2026-10-20-a` whose plan `02` (approved) carries `disproves-adr: [0003]`, and an approved valid `0003`: `0003` is disproven by `2026-10-20-a` plan `02`.
- `a_superseded_plan_disproves_nothing` — the same plan flipped `superseded` leaves `0003` not disproven.
- `a_disproof_of_a_retired_adr_is_history` — the same plan naming a valid `superseded` or `deprecated` `0003` marks nothing.
- `a_disproof_counts_from_a_done_chain_and_a_dropped_chain` — with the chain's intent `done`, then `dropped`, `0003` is disproven.
- `an_invalid_chain_contributes_no_disproof` — plan `01` names `0003` and `plans/02-x.md` has no frontmatter: `0003` is not disproven.
- `the_first_chain_and_lowest_plan_name_the_disproof` — chains `2026-10-20-a` (plan `03`) and `2026-10-21-b` (plan `01`) both name `0003`, and `a`'s plan `02` names it too: the mark is `2026-10-20-a` plan `02`.
- `a_disproven_adr_row_names_its_chain_and_plan` — `row` reads `disproven by 2026-10-20-a/02` / `adr supersede 0003`.
- `an_invalid_adr_row_names_its_file_and_fix` — an ADR with `missing sealed` reads `INVALID (0003-x.md: missing sealed)` / `fix adr 0003`.
- `a_still_approved_row_sends_to_the_adr_skill` — `superseded by 0009 but still approved` has NEXT `adr`.
- `a_still_status_row_sends_to_the_lister` — `superseded by 0009 but still draft` has NEXT `fix adr 0009`.
- `a_draft_adr_row_asks_to_approve_or_drop` — a valid draft reads `draft` / `approve or drop`.
- `a_healthy_adr_has_no_row` — a valid `approved` (not disproven), `superseded`, `deprecated` and `dropped` ADR each give nil.
- `the_heading_counts_non_zero_statuses_in_order` — two approved, one superseded, one deprecated, one draft, one dropped and one invalid ADR give `ADRS: 2 approved, 1 superseded, 1 deprecated, 1 draft, 1 dropped, 1 invalid`; with only two approved and one draft, `ADRS: 2 approved, 1 draft`.

**Done when:** `cargo make plugins` passes. Commit
`feat(repo): derive claudestacks-sdlc ADR rows`.

---

## Risks

- **Rows 6–8 and the lister set** are the most intricate step (Task 2): validity is
  recursive along `supersedes`. The cycle rule in *Readings* is this plan's decision on a
  case the spec leaves open; `a_supersedes_cycle_ends` pins only that the scan ends and
  both ADRs read invalid, not which row each gets.
- **The fingerprint of an ADR** is computed from the text `read_artifact` returns as its
  second result (`scripts/lib/status.lua:61-76`), the same text `read_chain` hands to
  `fingerprint.of_text` (`status.lua:93-101`). An ADR whose frontmatter is unterminated
  never reaches the seal check, because row 1 already rejects it.
- **`fs.list` order** is relied on for "number order" and "file name order on a
  duplicate". `status.lua:137-138` already relies on it being lexicographic for chains.
- Not done here: wiring into the board (plan 02), any chain rule (plan 03), any prose
  (plan 04).

## Proof

- `cargo make plugins` passes with every existing test unchanged and the new
  `adr_test.lua` tests added; the summary line reads `23 files`.
- Every row of spec §5.1, the heading's order, and the second-generation supersession
  of spec §11 each have a named test above.
