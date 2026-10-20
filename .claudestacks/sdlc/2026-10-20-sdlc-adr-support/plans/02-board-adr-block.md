---
status: approved
created: 2026-10-20
depends-on: [01]
built-on: c2d88a3e18f4
---

# Board ADR Block Implementation Plan

**Goal:** Every scanned ADR appears in an `ADRS:` block after the board's chain rows, a
block the session hook reads like any other rows.

**Architecture:** `scripts/lib/status.lua` requires plan 01's `lib/adr`, adds `adrs/` to
the chain-scan skip list, scans ADRs once per board and marks disproofs from the chains
it already scanned, and appends one heading row and the ADR rows after every chain row
in both layouts. The board keeps the scanned ADR list on the board table so plan 03's
chain rules read the same scan. The session hook needs no code change: its row filter
already skips headings and selects the words the ADR rows use (spec §9).

**Tech Stack:** Lua 5.4 under `airsl` 0.1.2, cargo-make.

**Content authority:** spec §1 P1, §5.2 (layout), §9 (hook), §11 (`status_test.lua` row:
the layout, byte-identical output, ADR-only root and hook items).

---

## Files that change

```
plugins/claudestacks-sdlc/scripts/lib/status.lua   — [modify] skip adrs/, scan ADRs, append the ADR block
plugins/claudestacks-sdlc/scripts/status_test.lua  — [modify] tests for the skip, the block and the hook
```

Every path is relative to the repository root. The gate for every task is
`cargo make plugins`, from the repository root. No Rust changes; no installed guideline
covers Lua (spec §1).

`status_test.lua`'s existing helpers are reused by name: `root()`, `artifact(dir, name,
fm, body)`, `chain_root(intent_fm, spec_fm, plans, bodies)`, `roadmap_file(…)`,
`member(…)` and `trimmed(board)` (`scripts/status_test.lua:22-95`). Tasks 2 and 3 add
one helper, `adr_file(dir, name, fm, body)`, which writes `adrs/<name>` through
`artifact`, creating `adrs/` on first use; a sealed fixture takes its `sealed` value from
`fingerprint.of_text`, which the file already requires (`status_test.lua:9`).

Plan 03 also modifies `scripts/lib/status.lua` and `scripts/status_test.lua`; it runs
after this plan.

## Order of work

### Task 1 — Stop reading `adrs/` as a chain

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/lib/status.lua` — require `lib.adr`; `SKIP` gains `adr.DIR`
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`

**Change:** `status.lua` requires `lib.adr` beside `lib.roadmap` (`status.lua:10-11`) and
the skip table at `status.lua:22` gains `[adr.DIR] = true`, so `scan` no longer turns
`adrs/` into an `INVALID (intent.md missing)` row (spec P1).

**Proof:** written first, seen failing, then passing —
- `an_adrs_directory_is_not_a_chain` — `status.scan` of a root holding chain `2026-08-24-a` and `adrs/0001-x.md` returns one chain, named `2026-08-24-a`.

**Done when:** `cargo make plugins` passes. Commit
`fix(repo): stop reading claudestacks-sdlc adrs/ as a chain`.

### Task 2 — Append the ADR block to the board

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/lib/status.lua` — `M.board` scans ADRs and appends the block
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`

**Change:** in `M.board` (`status.lua:466-552`):

- After `M.scan` and `roadmap.scan`, scan ADRs with `adr.scan(rootdir, M.read_artifact)`
  and mark disproofs with `adr.mark_disproofs(adrs, chains)`; keep the list on the
  board table as `board.adrs`, which plan 03 passes to `derive`.
- `board.empty` becomes true only when there is no chain, no roadmap and no ADR file
  (`status.lua:471`), so a root holding only ADRs renders the board, not the starter
  hint (spec §5.2; `artifact-chain.md:418` is the roadmap precedent).
- When at least one ADR file exists, after every other row — the flat rows
  (`status.lua:513-516`, which today returns early) or the grouped rows ending with
  `UNASSIGNED` (`:544-550`) — append one row `{ kind = "heading", label =
  adr.heading(adrs), indent = 0, notes = {} }`, then one row per ADR that `adr.row`
  gives a row, in scan order: `{ kind = "adr", label = "ADR " .. num, state, next,
  indent = 2, notes = {} }`.
- `board.open` stays the count of chain rows (spec §5.2). `M.render` is unchanged: it
  already prints `board.rows` in order and the `DONE/DROPPED` line after them
  (`status.lua:569-585`), and `M.row_lines` already pads a label by `34 - indent`
  (`:561`).

With no ADR file nothing is appended and every existing output is unchanged.

**Proof:** written first, seen failing, then passing — expected lines are built in each
test from its own fixture and compared through `trimmed`, never copied from spec §5.2
(spec §5.2 says no test copies that illustration):
- `the_adr_block_follows_the_chain_rows_in_the_flat_layout` — one open chain, one done chain and a draft `0001`: the lines read header, the chain row, `ADRS: 1 draft`, `  ADR 0001` padded with STATE `draft` and NEXT `approve or drop`, then `DONE/DROPPED: 1 done, 0 dropped (not listed)`.
- `the_adr_block_follows_unassigned_in_the_grouped_layout` — a roadmap with one milestone, one member chain, one simple chain and a draft `0001`: the `ADRS:` line follows the `UNASSIGNED` chain row and precedes nothing but the ADR row.
- `approved_adrs_count_without_rows` — two valid approved ADRs and no chain: the board is the header and `ADRS: 2 approved`, with no ADR row.
- `a_disproven_adr_prints_its_row` — chain `2026-08-24-a` whose plan `01` carries `disproves-adr: [0001]`, and a valid approved `0001`: an `ADR 0001` row reads `disproven by 2026-08-24-a/01` / `adr supersede 0001`.
- `adr_rows_print_in_number_order_and_file_order_on_a_duplicate` — drafts `0002-b.md`, `0001-a.md` and `0003-c.md` beside `0003-d.md`: rows `ADR 0001`, `ADR 0002`, `ADR 0003` (`INVALID (0003-c.md: duplicate number 0003)`), `ADR 0003` (`INVALID (0003-d.md: duplicate number 0003)`).
- `no_adrs_directory_renders_no_block` — a root with chains and no `adrs/` renders no line starting with `ADRS:`.
- `an_adrs_directory_without_adr_files_renders_byte_identical` — the same root rendered before and after creating `adrs/` holding only `README.md` gives equal strings.
- `a_root_holding_only_adrs_renders_the_board` — a root holding only `adrs/0001-a.md` (draft) renders the header line, not `No chains`.
- `board_open_counts_chain_rows_only` — two open chains and three ADRs with rows: `board.open` is 2.

**Done when:** `cargo make plugins` passes. Commit
`feat(repo): print claudestacks-sdlc ADR rows on the board`.

### Task 3 — Pin the session hook's reading of ADR rows

**Files:**
- Modify `plugins/claudestacks-sdlc/scripts/status_test.lua`

**Change:** none to code. `M.needs_attention` skips `heading` rows and selects a row whose
STATE contains `INVALID` or `disproven` (`status.lua:588`, `:605-623`), and an ADR row is
neither a heading nor free of those words when it is a problem; the count line reads
`board.open` (`:649-651`). This task pins that behaviour so a later change to either
cannot drop ADR rows from the hook silently.

**Proof:** these tests are expected to pass against Task 2's code. Before keeping them,
see each fail: temporarily make `M.board` skip appending ADR rows (keep the heading), run
the suite, watch the first two go red, and restore it; temporarily add `draft` to
`ATTENTION_WORDS` (`status.lua:588`), watch the third go red because the draft row is
listed, and restore it. The heading half of the third test has no meaningful red: a
heading carries no `state` (`status.lua:545`), so un-skipping headings crashes rather
than lists it, and its lowercase `invalid` count never matches the word `INVALID`. That
half is pinned by inspection only.
- `the_hook_shows_an_invalid_adr_row` — a root whose only problem is an approved `0001` with no `sealed`: `status.attention` has the count line ending `1 need attention …` and the `ADR 0001` row line exactly as `row_lines` prints it.
- `the_hook_shows_a_disproven_adr_row` — the disproof fixture of Task 2: the `ADR 0001` row line is in the attention text.
- `the_hook_skips_the_adrs_heading_and_a_draft_adr_row` — a root with one healthy chain and a draft `0001`: `status.attention` is the single line `claudestacks-sdlc: 1 open, 0 need attention — full board: /claudestacks-sdlc:status`.

**Done when:** `cargo make plugins` passes. Commit
`test(repo): pin the claudestacks-sdlc hook on ADR rows`.

---

## Risks

- **Byte-identical output without ADR files** is the property most at risk (Task 2): the
  flat branch returns early today (`status.lua:513-516`), so the block must be appended
  on both paths without disturbing either when the list is empty. The 92 existing
  `status_test.lua` tests pin today's output (count: `grep -cE '^  [a-z_0-9]+ = function\(\)'`
  on the file), and the byte-identical test pins the empty-`adrs/` case.
- **Scanning ADRs costs one directory read** per render when `adrs/` is absent;
  `adr.scan` returns early then, as `roadmap.scan` does.
- **Disproofs are read from every scanned chain**, collapsed ones included, because
  `M.scan` reads plans whatever the intent's status (`status.lua:118-131`).
- Not done here: chains reading their ADR citations (plan 03).

## Proof

- `cargo make plugins` passes; every pre-existing test is unchanged.
- `sh plugins/claudestacks-sdlc/scripts/status.sh`, run from the repository root,
  prints today's board for this repository unchanged (it holds no `adrs/`).
