---
status: approved
created: 2026-10-29
depends-on: [02, 03]
built-on: 80fae45ab510
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
