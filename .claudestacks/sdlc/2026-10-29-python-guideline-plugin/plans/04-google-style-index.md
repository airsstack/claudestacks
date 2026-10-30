---
status: done
created: 2026-10-29
depends-on: [02, 03]
built-on: fd450d45d88d
---

# Google Python Style Guide Index Implementation Plan

**Goal:** The `python-guidelines` skill carries a citable index of Google Python Style Guide
sections, each pointing at the reference that applies it.

**Architecture:** One new file, `references/google-style-guide.md`, playing the role
`microsoft-guidelines.md` plays for Rust: each item is identified by a stable code (`G-<section>`,
e.g. `G-2.4`) usable verbatim in commit messages and review comments, states the section's rule in
one line, and — where another reference is the authority — points at it with `→`. It depends on
plans 02 and 03 because every pointer must resolve to a file that exists.

**Tech Stack:** Markdown; the guide fetched with `curl -sS -L
'https://raw.githubusercontent.com/google/styleguide/gh-pages/pyguide.md' -o <file>`.

**Content authority:** spec §5 `google-style-guide.md` row, §1.5 (section numbers and lines);
intent Constraints (PEP 8 and PEP 257 as the baseline, the Google guide as the citable source,
Azure not used).

---

## Files that change

```
plugins/claudestacks-guideline-python/skills/python-guidelines/references/google-style-guide.md
                                  — [create] G-<section> index of the Google guide
plugins/claudestacks-guideline-python/skills/python-guidelines/SKILL.md
                                  — [modify] index entry for the new file
plugins/claudestacks-guideline-python/README.md
                                  — [modify] reference-list entry for the new file
```

## Order of work

### Task 1 — Write `google-style-guide.md`

**Files:**
- Create `references/google-style-guide.md`
- Modify `SKILL.md` — one index entry, in the form of `rust-guidelines/SKILL.md:52-71`; the
  entry appears once in the index section
  (`sed -n '/^## Reference index/,$p' SKILL.md | grep -c 'google-style-guide.md'` is 1)
- Modify `README.md` — add the file name to the reference list

**Change:** the file opens the way
`plugins/claudestacks-guideline-rust/skills/rust-guidelines/references/microsoft-guidelines.md:1-7`
opens — what the guide is, spirit over letter, codes used verbatim, `→` meaning another file is
the authority — and names PEP 8 and PEP 257 as the baseline beneath it. It then lists, grouped as
the guide groups them (2 Python Language Rules, 3 Python Style Rules), every numbered section of
the fetched guide that the eleven references of plans 02 and 03 or `strict-quality.md` apply, as
`G-<n.n>` with the section title, a one-line rule, and the `→` pointer. A section the guideline
deliberately departs from is listed with the departure stated — at minimum `G-2.20` (the guide
recommends `from __future__` imports; `typing.md` forbids them at a 3.14 floor). Sections that
Ruff or the formatter settle (line length, indentation, whitespace) point at `strict-quality.md`.

The section list is taken from the fetched file, not from this plan: run `grep -nE '^### [0-9]'`
over it and decide each heading — listed with a pointer, listed as a departure, or omitted as
covered by PEP 8 alone. Record that decision table in the commit body.

**Proof:** written first, seen failing, then passing —
- `every_code_matches_a_heading` — for each `G-<n.n>` in the file, `grep -n "^### <n.n> "` over
  the fetched guide finds exactly one heading whose title matches the entry's title, compared
  after removing Markdown backslash escapes from the heading (the guide writes
  `### 2.20 Modern Python: from \_\_future\_\_ imports`, pyguide.md :1438).
- `every_pointer_resolves` — each `→ references/<file>.md` in the file names a file that exists
  under `references/` (`test -e`).
- `section_heading_coverage` — every heading the `grep` lists is accounted for in the commit
  body's decision table (counts compared: headings found vs rows recorded).
- `claudevs_check_passes` — `claudevs check plugins/claudestacks-guideline-python` exits 0.

**Done when:** the four checks pass. Commit `feat(repo): add the Google Python Style Guide index`.

## Risks

- **The guide's numbering is not stable across its history** — sections have been removed (the
  fetched file at spec §1.5 has no 2.15 or 3.9). Codes cite the section as it reads at the fetch
  date; the file says so.
- **Pointers into plans 02 and 03.** If either plan renames a file, this one breaks; the
  `every_pointer_resolves` check catches it.

## Proof

- The four Task 1 checks pass.
- `SKILL.md`'s reference index lists all thirteen files of spec §5, each once:
  `sed -n '/^## Reference index/,$p' SKILL.md | grep -c '^- \`references/'` is 13, and each of the
  thirteen names appears once in that output.

## Review findings

Batch with plans 05 and 06, report `20261030-095405-ef9d/02-reviewer-plans-04-06.md`, blocking:
`google-style-guide.md:9` and Task 1 (one cause).
- blocking — the baseline `extend-select` applies five sections the index omitted: 2.5
  `PLW0603`, 2.8 `SIM118`, 2.10 `C417`, 2.14 `E711`/`E712`, 3.11 `SIM115`; the file's "only the
  sections a reference or the gate applies" was false — fixed, five entries → `strict-quality.md`,
  the remaining omitted rows re-probed. `bash p04/fix-probe.sh` → `failures=0`;
  `bash p04/checks.sh` → `29 entries checked, 0 bad`, `headings=38 rows=38`, `failures=0`.
- nit — intro said every pointed-at file "states the rule in full"; `strict-quality.md`
  enforces without restating — fixed, "states or enforces".
- nit — G-2.21 omitted `strong-types.md` (cites 2.21 at `strong-types.md:49-50`) — fixed.
- nit — `SKILL.md` departures parenthetical named 5 of 8 — fixed, names all 8.
- nit, declined — no committed check guards pointer resolution after this run; plan Risks'
  "`every_pointer_resolves` catches a rename" holds only during execution. The plan asks for no
  committed test; review holds it.
- drift, accepted — omission reason "covered by PEP 8 alone" replaced (below).

## Probe results

- Guide fetched 2026-10-30, `curl -sS -L
  'https://raw.githubusercontent.com/google/styleguide/gh-pages/pyguide.md'`, 4097 lines,
  `grep -nE '^### [0-9]'` → 38 headings; spec §1.5 line numbers (:145, :230, :309, :929, :1438,
  :1519, :2090, :3117, :3408) match the fetched copy.
- Task 1 checks, red before the file existed (`failures=7`), green after (`failures=0`);
  mutation run — wrong title, unresolved pointer, code with no heading, dropped table row each
  turned its check red.
- `uvx ruff@0.17.3 format|check --isolated` (baseline families), observed: the formatter settles
  3.1, 3.3, 3.4, 3.5 (top-level blank lines only), 3.6, 3.14; Ruff `I` puts `import x` before
  `from x import y` (G-3.13 departure); rule firings for 2.5, 2.8, 2.10, 2.14, 3.11 as above;
  no finding on the omitted sections' examples (table below). Not re-asserted in
  `fix-probe.sh`: the `len(seq)` no-finding under 2.14, from the all-baseline run only.

## Deviations

- 2026-10-30 — Re-confirmed against spec `fd450d45d88d` on the author's instruction to execute
  plans 04-06; the amendments do not touch §5's Google row or §1.5. Started while plans 02 and
  03 are built but not yet `done`.
- 2026-10-30 — Omission reason changed from "covered by PEP 8 alone" to "no reference applies
  it and the baseline reports no violation (probed)": 2.6, 2.18, 3.17 and others are not PEP 8
  topics, so the plan's wording would be false.
- 2026-10-30 — The decision table the plan puts in the commit body is recorded here as well, so
  it survives if the commit is squashed. 38 headings, 38 rows: 21 pointer, 8 departure, 9 omitted.

| § | Kind | Pointer / reason |
|---|---|---|
| 2.1 | departure | strict-quality — Ruff + mypy, not pylint; every suppression carries a reason |
| 2.2 | departure | init-export-only — re-export line overrides 2.2; also the caller-side rule |
| 2.3 | pointer | init-export-only, modularity |
| 2.4 | departure | errors — stricter than 2.4 (TRY003) |
| 2.5 | pointer | strict-quality (`PLW0603`) |
| 2.6 | omitted | nested function/class drew no finding |
| 2.7 | omitted | the guide's "No:" examples drew no C4 finding |
| 2.8 | pointer | strict-quality (`SIM118`) |
| 2.9 | pointer | docstring-discipline (`Yields:`) |
| 2.10 | pointer | strict-quality (`C417`; `filter`/`reduce` lambdas not caught) |
| 2.11 | omitted | nested multi-line conditional drew no finding |
| 2.12 | pointer | idioms |
| 2.13 | pointer | protocols-and-composition |
| 2.14 | pointer | strict-quality (`E711`, `E712`) |
| 2.16 | omitted | "Okay to use"; `B023` fires on a rule the section does not state |
| 2.17 | omitted | `@staticmethod`/`@classmethod` drew no finding |
| 2.18 | omitted | shared-dict mutation and bare `Thread` drew no finding |
| 2.19 | pointer | strong-types (dataclasses/enum carve-out) |
| 2.20 | departure | typing |
| 2.21 | pointer | typing, strict-quality, strong-types |
| 3.1 | pointer | strict-quality (formatter) |
| 3.2 | departure | strict-quality, docstring-discipline — Ruff 88 vs Google 80 |
| 3.3 | pointer | strict-quality (formatter) |
| 3.4 | pointer | strict-quality (formatter) |
| 3.5 | pointer | strict-quality (formatter; blank line after `def` not settled) |
| 3.6 | pointer | strict-quality (formatter) |
| 3.7 | omitted | `EXE001` is not the "main file only" rule |
| 3.8 | pointer | docstring-discipline, init-export-only |
| 3.10 | pointer | idioms (log calls), strict-quality (quote style) |
| 3.11 | pointer | strict-quality (`SIM115`; sockets not caught) |
| 3.12 | departure | docstring-discipline — `TODO: <what is missing>` |
| 3.13 | departure | strict-quality, init-export-only — Ruff `I` order |
| 3.14 | pointer | strict-quality (formatter) |
| 3.15 | omitted | trivial getter/setter drew no finding |
| 3.16 | pointer | init-export-only, errors, strict-quality |
| 3.17 | omitted | no `__main__` guard drew no finding |
| 3.18 | pointer | modularity |
| 3.19 | departure | typing |
