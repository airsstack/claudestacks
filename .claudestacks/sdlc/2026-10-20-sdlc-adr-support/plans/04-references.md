---
status: approved
created: 2026-10-20
built-on: c2d88a3e18f4
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
