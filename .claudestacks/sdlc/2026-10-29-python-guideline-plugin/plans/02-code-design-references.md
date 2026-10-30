---
status: executing
created: 2026-10-29
depends-on: [01]
built-on: fd450d45d88d
---

# Python Code-Design References Implementation Plan

**Goal:** The `python-guidelines` skill carries the eight code-design rule references of spec §5,
each rule grounded in a fetched source or an observed tool run.

**Architecture:** Eight new Markdown files under
`plugins/claudestacks-guideline-python/skills/python-guidelines/references/`, one rule area each.
Each follows the shape of its Rust counterpart where one exists — a title `# Python — <topic>`, the
bar, the rules, a "Things to AVOID" list, and reviewer or Definition-of-Done additions — and states
for every rule whether a gate step enforces it (naming the step and rule code) or review holds it.
Each task appends its file to the `SKILL.md` reference index and the README's reference list.

**Tech Stack:** Markdown; sources fetched with `curl -sS -L <url> -o <file>` into a fresh
directory under the session temp directory; probes run through `uvx --from uv@0.13.6 uv` with
ruff 0.17.3, mypy 2.4.1, pytest 9.2.0 on CPython 3.12.

**Probe project:** rebuilt at the start of this plan, never assumed to exist: `uvx --from
uv@0.13.6 uv init --lib --python 3.12 probe`; dev group pinned `ruff==0.17.3`, `mypy==2.4.1`,
`pytest==9.2.0`; the `[tool.*]` tables copied from the shipped `strict-quality.md`; one
Google-docstring module with a doctest and one test; all five `SKILL.md` gate commands exit 0
on it before any probe starts. Each probe works on a fresh copy.

**Content authority:** spec §5 (one table row per file), §1.5, §4.1; author decisions recorded in
the intent's Constraints.

---

## Files that change

```
plugins/claudestacks-guideline-python/skills/python-guidelines/references/typing.md
                                  — [create] modern typing syntax and exhaustiveness
.../references/strong-types.md    — [create] domain values carry types
.../references/protocols-and-composition.md
                                  — [create] choosing an abstraction
.../references/init-export-only.md
                                  — [create] what __init__.py may hold
.../references/modularity.md      — [create] one responsibility, one home, no cycles
.../references/docstring-discipline.md
                                  — [create] Google docstrings, no internal-artifact leakage
.../references/errors.md          — [create] exception hierarchy and chaining
.../references/idioms.md          — [create] mutable defaults, pathlib, encoding, logging, TaskGroup
plugins/claudestacks-guideline-python/skills/python-guidelines/SKILL.md
                                  — [modify] one index entry per file above (every task)
plugins/claudestacks-guideline-python/README.md
                                  — [modify] one reference-list entry per file above (every task)
```

## Rules every task follows

These bind Tasks 1–8 identically; each task restates nothing here.

- **Ground before writing.** Fetch every source the task names to a local file and cite rules as
  `<source URL> :<line>` at the fetch date. Never use a summarising fetch tool. A rule that cannot
  be cited does not go in.
- **Probe every tool-behaviour claim.** A sentence saying a gate step catches something is backed
  by a probe the task names: the defect planted in a fresh copy of the probe project, the step
  run, its exit code and rule code recorded in the commit body. A sentence saying nothing in the
  gate catches something is backed by the same probe showing every step exit 0, and the rule is
  then marked "held by review".
- **If a probe contradicts this plan's expectation, stop and report it.** The expected outcomes
  below are what the spec's premises predict; a different result is a premise failing, not a
  wording choice (CLAUDE.md, "When execution disproves the spec").
- **Index and README.** The task appends one line to the `SKILL.md` "Reference index" in the form
  of the Rust index entries (`rust-guidelines/SKILL.md:52-71`): backticked path, em dash, one-line
  bar. The README list gets the same file name.
- **Done-check for every task:** `claudevs check plugins/claudestacks-guideline-python` exits 0,
  and the new file's path appears exactly once inside the index section —
  `sed -n '/^## Reference index/,$p' SKILL.md | grep -c '<path>'` is 1 (prose elsewhere in
  `SKILL.md` may also name a file, so the count is taken over the index section only).

## Order of work

### Task 1 — `typing.md`

**Files:** Create `references/typing.md`; modify `SKILL.md`, `README.md`.

**Change:** the spec §5 `typing.md` row: PEP 695 syntax, `X | None`, `collections.abc` generics,
`@override` on every override, `assert_never` closing every `match` over a union or enum, no
`TypeAlias`, `TypeIs` over `TypeGuard` where the floor provides it, 3.15-only features gated by
the floor, and neither `from __future__ import annotations` nor quoted forward references at a
3.14 floor — citing Google 2.20 as the rule it overrides.

**Sources:** PEP 695, 698, 742, 749
(`https://raw.githubusercontent.com/python/peps/main/peps/pep-<NNNN>.rst`);
`https://raw.githubusercontent.com/python/cpython/3.15/Doc/library/typing.rst` (TypeAlias
deprecation, spec §1.5); the typing spec
(`https://raw.githubusercontent.com/python/typing/main/docs/spec/narrowing.rst`,
`generics.rst`, `aliases.rst`); Google 2.20, 2.21, 3.19
(`https://raw.githubusercontent.com/google/styleguide/gh-pages/pyguide.md`).

**Proof:** written first, seen failing, then passing —
- `missing_override_fails_mypy` — already proven (spec §1.2, `explicit-override`); cite it.
- `non_exhaustive_match_with_assert_never_fails_mypy` — a `match` over a two-member `Enum` that
  handles one member and ends `case _: assert_never(x)`; expected: `mypy --strict .` exits 1.
- `non_exhaustive_match_without_assert_never` — the same `match` with no closing case in a
  function returning `None`; expected: every gate step exits 0, which is why the rule is
  mandatory and held by review where the case is absent.
- `type_alias_annotation` — `X: TypeAlias = int`; record which gate step (if any) flags it and
  with which code; the reference states the result.

**Done when:** the rules above hold and the probes are recorded. Commit
`feat(repo): add the python typing reference`.

### Task 2 — `strong-types.md`

**Files:** Create `references/strong-types.md`; modify `SKILL.md`, `README.md`.

**Change:** the spec §5 `strong-types.md` row: `NewType` for identifiers, frozen slotted dataclasses
validating in `__post_init__`, `Enum`/`StrEnum`/`Literal` for closed sets, `bool` parameters
keyword-only. It states where Python differs from the Rust rule
(`rust-guidelines/references/strong-types.md`): `NewType` checks nothing at runtime, and
`frozen=True` does not freeze a mutable field's contents — both to be shown by probe, not asserted.

**Sources:** typing spec (`…/docs/spec/aliases.rst` for `NewType`, `literal.rst`);
`https://raw.githubusercontent.com/python/cpython/main/Doc/library/dataclasses.rst`,
`…/Doc/library/enum.rst`; Google 2.21.

**Proof:** written first, seen failing, then passing —
- `positional_bool_fails_ruff` — already proven (spec §1.2, `FBT001`); cite it.
- `newtype_swap_fails_mypy` — two `NewType`s over `str`, one passed where the other is expected;
  expected: `mypy --strict .` exits 1 with `arg-type`.
- `newtype_accepts_any_value_at_runtime` — `python -I -c` constructing a `NewType` over `int`
  from `-5` succeeds; the reference says validation belongs in a constructor.
- `frozen_dataclass_field_still_mutable` — `python -I -c` appending to a `list` field of a frozen
  dataclass succeeds; the reference requires immutable field types (`tuple`, `frozenset`).

**Done when:** the rules above hold and the probes are recorded. Commit
`feat(repo): add the python strong-types reference`.

### Task 3 — `protocols-and-composition.md`

**Files:** Create `references/protocols-and-composition.md`; modify `SKILL.md`, `README.md`.

**Change:** the spec §5 row: prefer a concrete type, then a callable, then a `Protocol` at a module
boundary, then an ABC only to share implementation; composition over inheritance; no reliance on
`@runtime_checkable` for signature checks. It replaces the Rust `static-dispatch.md` rationale
(dispatch cost) with the Python one (coupling), and says so.

**Sources:** PEP 544; typing spec `…/docs/spec/protocol.rst`;
`https://raw.githubusercontent.com/python/cpython/main/Doc/library/abc.rst`.

**Proof:** written first, seen failing, then passing —
- `missing_protocol_method_fails_mypy` — a class lacking one method of a `Protocol`, passed where
  the `Protocol` is expected; expected: `mypy --strict .` exits 1.
- `runtime_checkable_ignores_signatures` — `python -I -c` showing `isinstance` true for a class
  whose method has the right name and a wrong signature; the reference cites this as the reason
  for the rule.

**Done when:** the rules above hold and the probes are recorded. Commit
`feat(repo): add the python protocols-and-composition reference`.

### Task 4 — `init-export-only.md`

**Files:** Create `references/init-export-only.md`; modify `SKILL.md`, `README.md`.

**Change:** the spec §5 row: `__init__.py` holds a docstring, `__all__` and re-exports;
implementation lives in sibling modules. Adapt the Rust `mod-rs-export-only.md` sections (the
rule, required module documentation, why, when it does not apply, canonical shape, naming
siblings) to Python, including the typing spec's re-export forms.

**Sources:** typing spec `…/docs/spec/distributing.rst`; Google 2.2, 2.3.

**Proof:** written first, seen failing, then passing —
- `implicit_reexport_fails_mypy` — a test importing from the package a name its `__init__.py`
  imports but neither lists in `__all__` nor re-exports as `X as X`; expected: `mypy --strict .`
  exits 1 (strict implies `--no-implicit-reexport`).
- `explicit_reexport_passes` — the same name added to `__all__`; expected: the gate is green.

**Done when:** the rules above hold and the probes are recorded. Commit
`feat(repo): add the python init-export-only reference`.

### Task 5 — `modularity.md`

**Files:** Create `references/modularity.md`; modify `SKILL.md`, `README.md`.

**Change:** the spec §5 row: carry over the Rust `modularity.md` rules (no God object, no duplicate
types) and add no import cycles and no module named after a standard-library module.

**Sources:** `plugins/claudestacks-guideline-rust/skills/rust-guidelines/references/modularity.md`;
Google 2.2, 2.3; `https://raw.githubusercontent.com/python/cpython/main/Doc/reference/import.rst`.

**Proof:** written first, seen failing, then passing —
- `import_cycle_against_the_gate` — modules `a` and `b` importing each other at module level;
  record every gate step's exit code. If all exit 0, the rule is marked held by review; if one
  fails, the reference names that step and code.
- `stdlib_shadowing_module` — a module named `logging.py` inside the package; record which step
  (if any) flags it (Ruff `A005` is a candidate in the `A` family selected by the baseline) and
  state the result.

**Done when:** the rules above hold and the probes are recorded. Commit
`feat(repo): add the python modularity reference`.

### Task 6 — `docstring-discipline.md`

**Files:** Create `references/docstring-discipline.md`; modify `SKILL.md`, `README.md`.

**Change:** the spec §5 row: Google-convention docstrings on every public module, class and
function; the leakage and accuracy rules of
`plugins/claudestacks-guideline-rust/skills/rust-guidelines/references/doc-comment-discipline.md`
(no planning paths, plan identifiers, workflow vocabulary, or AI/agent names; comments stay
accurate) carried over and restated for docstrings and `#` comments.

**Sources:** PEP 257 (`…/peps/pep-0257.rst`); Google 3.8; the Rust reference above; Ruff's own
rule text for the `D` codes the file names (`uvx ruff@0.17.3 rule <CODE>`) and the pydocstyle
`convention` setting (`https://raw.githubusercontent.com/astral-sh/ruff/main/docs/settings.md`,
or `uvx ruff@0.17.3 config lint.pydocstyle.convention`).

**Proof:** written first, seen failing, then passing —
- `missing_args_entry_fails_ruff` — already proven (spec §1.2, `D417`); cite it.
- `missing_public_docstring_fails_ruff` — a public function with no docstring; expected:
  `ruff check --no-fix` exits 1 with a `D1xx` code (record which).
- `leakage_is_review_held` — a docstring containing a plan path; expected: every gate step exits
  0, so the leakage rule is marked held by review.

**Done when:** the rules above hold and the probes are recorded. Commit
`feat(repo): add the python docstring-discipline reference`.

### Task 7 — `errors.md`

**Files:** Create `references/errors.md`; modify `SKILL.md`, `README.md`.

**Change:** the spec §5 row: a project exception hierarchy, `raise … from` inside `except`, no bare
or catch-all `except`, `except*` for exception groups.

**Sources:** Google 2.4; PEP 3134, PEP 654;
`https://raw.githubusercontent.com/python/cpython/main/Doc/tutorial/errors.rst`; Ruff's rule text
for every `B`, `BLE`, `TRY` or `E` code the file names (`uvx ruff@0.17.3 rule <CODE>`).

**Proof:** written first, seen failing, then passing —
- `raise_without_from_fails_ruff` — already proven (spec §1.2, `B904`); cite it.
- `bare_except_fails_ruff` — `except:`; expected: `ruff check --no-fix` exits 1 (record the code).
- `catch_all_exception_fails_ruff` — `except Exception: pass`; expected: exit 1 under the `BLE` or
  `S` family (record the code).
- `try_family_probe` — `raise ValueError(f"bad value {x}")` outside a custom exception class, and
  a `try` body that returns inside the `try` with logic after it; record which `TRY` codes fire
  and state in the reference which `TRY` rules the gate enforces.

**Done when:** the rules above hold and the probes are recorded. Commit
`feat(repo): add the python errors reference`.

### Task 8 — `idioms.md`

**Files:** Create `references/idioms.md`; modify `SKILL.md`, `README.md`.

**Change:** the spec §5 row: no mutable defaults, `pathlib` over `os.path`, explicit `encoding=`,
`logging` not `print` in library code, `asyncio.TaskGroup` for concurrent tasks.

**Sources:** Google 2.12; `https://raw.githubusercontent.com/python/cpython/main/Doc/library/pathlib.rst`,
`…/Doc/howto/logging.rst`, `…/Doc/library/asyncio-task.rst`.

**Proof:** written first, seen failing, then passing —
- `print_fails_ruff` — already proven (spec §1.2, `T201`); cite it.
- `mutable_default_fails_ruff` — `def f(x: list[int] = [])`; expected: exit 1 with `B006`.
- `os_path_fails_ruff` — `os.path.join(...)`; expected: exit 1 with a `PTH` code (record which).
- `missing_encoding` — `Path(p).read_text()` with no `encoding=`; record every step's exit code.
  If all are 0, the encoding rule is marked held by review.
- `taskgroup_is_review_held` — `asyncio.gather` in place of a `TaskGroup`; expected: the gate is
  green, so the rule is marked held by review.

**Done when:** the rules above hold and the probes are recorded. Commit
`feat(repo): add the python idioms reference`.

## Risks

- **A probe may contradict an expectation above.** Several "expected" outcomes (the `D1xx`,
  `PTH`, `BLE`/`S`, `A005` codes, the `TypeAlias` flag) are predictions from the rule families the
  baseline selects, not runs. The rule in "Rules every task follows" governs: stop and report.
- **Parallel edits to `SKILL.md` and `README.md`.** Plan 03 appends to the same index and list;
  resolve a merge conflict by keeping every entry in spec §5 table order.
- **Source drift.** Raw files on `main` branches move; cite the line at the fetch date and keep
  the fetched copy until the commit is made.
- **Most risky task:** Task 1 — the widest set of claims, several version-gated.
- **Not done here:** `project-layout.md`, `test-mandate.md`, `workspace.md` (plan 03),
  `google-style-guide.md` (plan 04).

## Proof

- `ls` of the eight files succeeds; each has exactly one entry in `SKILL.md`'s index.
- `claudevs check plugins/claudestacks-guideline-python` exits 0.
- Every rule in the eight files carries a citation or names the probe that backs it; the
  reviewer rejects one that does not.
- The commit bodies hold each probe's command, exit code and rule code.

## Review findings

Tasks 1-4, report `41-reviewer-p02-tasks1-4.md`, blocking: init-export-only.md cycle label,
protocols-and-composition.md example.
- blocking — sibling import through `__init__` labelled gate-enforced; the reverse load order
  passes all five steps — fixed: held by review, green row added.
- blocking — the shipped Protocol example failed `ruff format --check` and `ruff check` (D100,
  I001) — fixed: the probed shape ships; format/check/mypy/pytest exit 0.
- risk — typing.md required quoted forward references below a 3.14 floor, beyond spec §5 —
  fixed: either form below 3.14, review-held; "deprecated" reason dropped (pep-0749.rst:91-95).
- question — mypy `exhaustive-match` into the baseline — declined: stays a project option; the
  spec §4.1 baseline is unchanged.
- nits fixed — full Google quote (pyguide.md:2108-2110), guideline-reasoning label, process
  narration removed, plain `Ident = int` passes all five steps (UP040 reads only `TypeAlias`) →
  review-held, re-wraps, nested backticks. Kept — `google-style-guide.md` pointer (plan 04).

Tasks 5-8, report `42-reviewer-p02-tasks5-8.md`, blocking: none.
- risk — narrow `except X: pass` labelled gate — fixed: only `contextlib.suppress(<X>)` with a
  reason comment, review-held.
- risk — LOG015/G201 depend on Ruff's default rule set; `select =` drops them silently — fixed:
  strict-quality.md checklist rejects any `select =` key.
- nits fixed — BLE001 row, G201 provenance, nested backticks, idioms.md AVOID section, 404
  sentence dropped, leakage grep robust to absent operands; bare `except:` with a bare `raise`
  body draws no E722 — row qualified.
- Verified after both fix rounds: `claudevs check plugins/claudestacks-guideline-python` exit 0;
  12 reference bullets in the SKILL.md index section.

## Probe results

All runs: uv 0.13.6, ruff 0.17.3, mypy 2.4.1, pytest 9.2.0, CPython 3.12.16 (3.13.18 / 3.14.10
for floor rows); full command/exit/output per probe in handoffs 31-38, 43, 44.
- Task 1 — missing `@override`: mypy exit 1 `explicit-override`; unclosed `match` with
  `assert_never`: mypy exit 1 `arg-type`; without it: all five exit 0; `TypeAlias`: `UP040`.
- Task 2 — swapped `NewType`s: mypy exit 1 `arg-type`; `NewType` accepts `-5` at runtime; frozen
  dataclass `list` field appendable; positional `bool`: `FBT001`; literal `65535`: `PLR2004`.
- Task 3 — every planned probe as predicted.
- Task 4 — implicit re-export fails mypy and `F401`; explicit `__all__` passes; `F403` and
  `F822` (in `__init__`) not enabled → review-held.
- AGAINST THE PLAN — Task 5: A005 does not fire on a nested `src/<pkg>/logging.py` without
  `strict-checking = true`; a name-import cycle fails pytest (exit 2) rather than passing; a
  function-level import fails `PLC0415`.
- Task 6 — `D100`-`D107`, `D415`, `D417` etc. fire; leakage passes all five → review-held.
- Task 7 — `E722`, `BLE001`+`S110`+`SIM105`, `B904`, `TRY*` fire; Google 2.4's own example fails
  `TRY003`/`PLR2004`; `contextlib.suppress(Exception)` passes → review-held.
- Task 8 — `B006`, `PTH*` fire; missing `encoding=` and `gather` pass → review-held; B006 skips an
  immutable-annotated mutable default; Ruff 0.17.3's default rule set includes LOG015, G201,
  B006, BLE001 (407 rules enabled with an empty config).

## Deviations

- 2026-10-30 — Plan re-confirmed against spec `fd450d45d88d` by the orchestrator: plan 02 encodes
  none of the amended claims (§7, §1.4, §3, §5 test-mandate row).
- 2026-10-30 — All eight tasks ran in parallel; each coder wrote only its reference, and the
  orchestrator added the eight SKILL.md index entries and README names in spec §5 order. Task
  briefs were read from the plan directly, not through task-briefer.
- 2026-10-30 — Probe contradictions (Task 5) were written into the reference as observed rather
  than stopping the run, under the updated execute policy.
- 2026-10-30 — Task 6 source `astral-sh/ruff/main/docs/settings.md` returns 404; the plan's
  fallback `uvx ruff@0.17.3 config lint.pydocstyle.convention` was used.
