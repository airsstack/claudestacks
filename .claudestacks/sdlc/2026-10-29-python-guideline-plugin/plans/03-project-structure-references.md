---
status: done
created: 2026-10-29
depends-on: [01]
built-on: fd450d45d88d
---

# Python Project-Structure References Implementation Plan

**Goal:** The `python-guidelines` skill carries the three project-structure rule references of
spec §5 — layout, tests, workspaces — each grounded in a fetched source or an observed run.

**Architecture:** Three new Markdown files under
`plugins/claudestacks-guideline-python/skills/python-guidelines/references/`. `project-layout.md`
and `workspace.md` describe repository shape; `test-mandate.md` describes where tests live and what
they must cover. Each follows the shape of its Rust counterpart where one exists and states, per
rule, whether a gate step enforces it or review holds it. Each task appends its file to the
`SKILL.md` reference index and the README's reference list.

**Tech Stack:** Markdown; sources fetched with `curl -sS -L <url> -o <file>`; probes through
`uvx --from uv@0.13.6 uv` with ruff 0.17.3, mypy 2.4.1, pytest 9.2.0 on CPython 3.12.

**Content authority:** spec §1.3, §1.4, §1.6, §3 (workspace bullet), §5 rows `project-layout.md`,
`test-mandate.md`, `workspace.md`; author decisions in the intent's Constraints (test placement,
no coverage threshold, held by review).

---

## Files that change

```
plugins/claudestacks-guideline-python/skills/python-guidelines/references/project-layout.md
                                  — [create] repository shape of a Python project
.../references/test-mandate.md    — [create] where tests live and what they cover
.../references/workspace.md       — [create] uv workspaces
plugins/claudestacks-guideline-python/skills/python-guidelines/SKILL.md
                                  — [modify] one index entry per file above (every task)
plugins/claudestacks-guideline-python/README.md
                                  — [modify] one reference-list entry per file above (every task)
```

## Rules every task follows

The same four rules as plan 02 bind every task here, restated so this plan stands alone:

- **Ground before writing.** Fetch every named source to a local file (never a summarising fetch
  tool) and cite rules as `<source URL> :<line>` at the fetch date. An uncited rule does not go in.
- **Probe every tool-behaviour claim** in a fresh copy of the probe project (or the workspace probe
  below), recording command, exit code and output in the commit body. A rule no gate step catches
  is shown by every step exiting 0 and marked "held by review". The probe project is rebuilt at the
  start of this plan, never assumed to exist: `uvx --from uv@0.13.6 uv init --lib --python 3.12
  probe`; dev group pinned `ruff==0.17.3`, `mypy==2.4.1`, `pytest==9.2.0`; the `[tool.*]` tables
  copied from the shipped `strict-quality.md`; one Google-docstring module with a doctest and one
  test; all five `SKILL.md` gate commands exit 0 on it before any probe starts.
- **If a probe contradicts an expectation here, stop and report it** — a spec premise failing, not
  a wording choice.
- **Index and README:** one line per file appended to the `SKILL.md` "Reference index" in the form
  of `rust-guidelines/SKILL.md:52-71`, and the file name added to the README list.
- **Done-check for every task:** `claudevs check plugins/claudestacks-guideline-python` exits 0,
  and `sed -n '/^## Reference index/,$p' SKILL.md | grep -c '<path>'` is 1 (the count is taken
  over the index section only, since prose elsewhere may name a file).

## Order of work

### Task 1 — `project-layout.md`

**Files:** Create `references/project-layout.md`; modify `SKILL.md`, `README.md`.

**Change:** the spec §5 `project-layout.md` row: `src/` layout; `tests/` at the root; committed
files (`pyproject.toml`, `uv.lock`, `.python-version`) and ignored ones (`.venv`, `dist`);
`[project]` and `[build-system]` always declared; `py.typed` in libraries; dev tools in
`[dependency-groups]`; `.python-version` equal to the `requires-python` floor — 3.12 for a
library (any project published to a package index), 3.14 for an application (spec §4.2); and a
short section on standalone PEP 723 scripts saying the guideline is not surfaced for them (spec
§2.2) and what of it still applies when loaded by hand.

**Sources:** PEP 517, 561, 621, 723, 735
(`https://raw.githubusercontent.com/python/peps/main/peps/pep-<NNNN>.rst`); the packaging guide's
src-vs-flat discussion
(`https://raw.githubusercontent.com/pypa/packaging.python.org/main/source/discussions/src-layout-vs-flat-layout.rst`);
uv `concepts/projects/init.md`, `concepts/projects/layout.md`, `concepts/python-versions.md`
(`https://raw.githubusercontent.com/astral-sh/uv/main/docs/<path>`).

**Proof:** written first, seen failing, then passing —
- `uv_init_lib_shape` — `uvx --from uv@0.13.6 uv init --lib --python 3.12 p` produces
  `src/p/py.typed`, `.python-version` containing `3.12`, and `requires-python = ">=3.12"` (spec
  §1.3 recorded this; re-run and cite).
- `uv_init_app_shape` — `uvx --from uv@0.13.6 uv init --app --python 3.14 a`; record which files
  it writes and whether it declares `[build-system]`. If it does not, the reference tells the
  reader to use `uv init --package` (or add the table) so the "always declared" rule holds — and
  states which, from the run.
- `floor_mismatch_is_review_held` — a library with `requires-python = ">=3.12"` and
  `.python-version` `3.14`; expected: the gate is green, which is why the floor rule is held by
  review.

**Done when:** the rules above hold and the probes are recorded. Commit
`feat(repo): add the python project-layout reference`.

### Task 2 — `test-mandate.md`

**Files:** Create `references/test-mandate.md`; modify `SKILL.md`, `README.md`.

**Change:** the spec §5 `test-mandate.md` row, adapting the sections of
`plugins/claudestacks-guideline-rust/skills/rust-guidelines/references/unit-test-mandate.md` (the
mandate, exempt file kinds, integration tests are not a substitute, required justification when
omitting, what tests should cover, reviewer checklist, rationale): every logic-bearing module under
`src/` has a matching `tests/…/test_<module>.py`; every directory of the test tree carries an
`__init__.py`; in a workspace each member's tests sit in `tests/<member>_tests/` (spec §1.6);
boundary and error paths are tested, not only the happy path; exemptions are named and cited; the
mandate is held by review. It states where Python differs from the Rust mandate: tests sit in a
separate tree, and the visibility reason for colocating does not apply because tests can import
`_private` names — shown by the `private_name_import_passes` probe below, not asserted.

**Sources:** pytest goodpractices
(`https://raw.githubusercontent.com/pytest-dev/pytest/main/doc/en/explanation/goodpractices.rst`
:124-133, :154 per spec §1.5); pytest import modes
(`…/doc/en/explanation/pythonpath.rst`); spec §1.6 evidence.

**Proof:** written first, seen failing, then passing —
- `duplicate_test_names_without_init_fail_mypy` — re-run spec §1.6 row 1 (`tests/a/test_models.py`,
  `tests/b/test_models.py`, no `__init__.py`, cold mypy cache): `mypy --strict .` exits 2,
  `Duplicate module named "test_models"`.
- `duplicate_test_names_with_init_pass` — spec §1.6 row 3: with `__init__.py` in every test
  directory, the full gate exits 0, and a planted wrong return type in `src/` makes `mypy` exit 1.
- `missing_test_file_is_review_held` — a new logic module with no matching test file; expected:
  the gate is green, so the mandate is marked held by review.
- `private_name_import_passes` — a test importing `_helper` from `src/<pkg>/core.py`; expected:
  the gate is green (Ruff's `import-private-name`, `PLC2701`, is a preview rule the baseline does
  not enable — confirm with `uvx ruff@0.17.3 rule PLC2701` and record it).

**Done when:** the rules above hold and the probes are recorded. Commit
`feat(repo): add the python test-mandate reference`.

### Task 3 — `workspace.md`

**Files:** Create `references/workspace.md`; modify `SKILL.md`, `README.md`.

**Change:** the spec §5 `workspace.md` row, in the section shape of
`plugins/claudestacks-guideline-rust/skills/rust-guidelines/references/workspace.md` where it
applies (why a workspace, root manifest shape, member manifest shape, directory layout,
inter-member dependencies): use a workspace only for packages developed together that can share
one lockfile, one environment and one `requires-python`; a root holding the spec §4.1
baseline with `testpaths = ["packages"]` and the test ignores keyed `"packages/*/tests/**"`; the
gate with `--all-packages`; `tests/<member>_tests/` per member; members declaring every package
they import; separate projects joined by path dependencies otherwise. It states the differences
from Cargo the spec proved (§1.4): a plain `uv sync` leaves members uninstalled when the root
declares `[project]` (a virtual root installs them; `--all-packages` covers both),
`requires-python` is the intersection, and uv cannot stop a member importing another member's
dependency. *(Amended 2026-10-30 with spec §1.4.)*

**Sources:** uv `concepts/projects/workspaces.md` (spec §1.4: :177-200, :202-205, :209);
`concepts/projects/dependencies.md` for `{ workspace = true }` sources; spec §1.4 and §1.6
evidence.

**Proof:** written first, seen failing, then passing — a workspace probe built as spec §1.4
describes (a root declaring `[project]` with the baseline, members `core` and `api` made with
`uv init --lib`, each with `src/<m>/` and `tests/<m>_tests/`):
- `plain_sync_leaves_members_out` — `uv sync --locked --all-groups` exits 0 and
  `.venv/bin/python -c "import core"` then exits 1; in a copy whose root drops `[project]`
  (a virtual root), the same import exits 0.
- `workspace_gate_is_green` — the five gate commands with `--all-packages` all exit 0.
- `member_defects_fail_the_gate` — each spec §1.4 planted defect (unused import in `core`, wrong
  return type in `core`, failing test in `api`), in a fresh copy, fails its step.
- `undeclared_sibling_dependency_is_review_held` — `api` importing a package declared only by
  `core`; expected: the gate is green, so the declaration rule is marked held by review.

**Done when:** the rules above hold and the probes are recorded. Commit
`feat(repo): add the python workspace reference`.

## Risks

- **Expectations not yet run:** what `uv init --app` writes, and the two "held by review"
  outcomes, are predictions; the stop-and-report rule governs.
- **Parallel edits to `SKILL.md` and `README.md`** with plan 02; resolve by keeping every entry in
  spec §5 table order.
- **Most risky task:** Task 3 — the workspace probe is the largest and depends on network installs
  for two members.
- **Not done here:** the code-design references (plan 02) and the Google index (plan 04).

## Proof

- `ls` of the three files succeeds; each has exactly one entry in `SKILL.md`'s index.
- `claudevs check plugins/claudestacks-guideline-python` exits 0.
- Every rule in the three files carries a citation or names its probe; the commit bodies hold the
  probe outputs.

## Review findings

Task 1 (`project-layout.md`), report `17-reviewer-p03-task1.md`, blocking: :53, :131.
- blocking — `src/` layout "enforced by the gate" holds only under uv_build's default
  `module-root`; `module-root = ""` passes all five steps — fixed, relabelled.
- blocking — dev tools in `[project] dependencies` pass all five steps — fixed, split from the
  gate-enforced `[project.optional-dependencies]` case.
- risk — displaced test directory "not noticed" contradicts its probe (ruff exit 1) — fixed.
- nits fixed — probe name unintroduced, `pep-0621.rst:113-119`, lock refresh unstated, uncited
  "an application ships none" (dropped), two long lines, PEP 723 "not surfaced" now cites
  `enforcement.json` `detect` and the dispatcher trace. Declined — citation key legend (resolves).
- Verified: `claudevs check plugins/claudestacks-guideline-python` → `2 stages run, 0 failed, 2
  skipped`.

Task 2 (`test-mandate.md`), report `22-reviewer-p03-task2.md`, blocking: :45-48, :208.
- blocking — "every directory carries `__init__.py` … for mypy" overclaims; `tests/__init__.py`
  alone passes the gate — fixed: top file is what mypy needs, deeper ones review-held; one rule
  for both project forms; table rows added.
- blocking — skip/xfail "none | review" is partly false: boolean `skipif` without `reason=` fails
  the pytest step — fixed, split; matching line in strict-quality.md aligned.
- nits fixed — probe names, `match=` rule labelled (PT011), workspace table row, index order now
  spec §5 order (strict-quality, test-mandate, project-layout, workspace).
- spec §5 :355 wording vs §1.6 — resolved by amendment (Deviations).

Task 3 (`workspace.md`), report `24-reviewer-p03-task3.md`, blocking: :5-6, :240.
- blocking — rules without gate/review labels — fixed: every rule labelled from a fresh probe,
  11 table rows added.
- blocking — undeclared-sibling row wrong in condition and exit code — fixed: fails only when
  declared in `dependencies` without `[tool.uv.sources]`, exit 2 with `uv.lock` present, 1
  without.
- risks/nits fixed — :80 tables named, :184 both lock cases, wraps, `.git/` artifact explained,
  Rust sibling cited by section, bullet count, uncited Cargo implication dropped, "a module
  pytest collects", test-tree rule aligned with test-mandate.md.
- Verified after all fix rounds: `claudevs check` exit 0; each of the four references counts 1
  in the SKILL.md index section.

## Probe results

- Task 1 — `uv init --lib --python 3.12 p`: `src/p/py.typed`, `.python-version` `3.12`,
  `requires-python = ">=3.12"`. `uv init --app --python 3.14 a` declares `[build-system]`
  (uv_build) — the plan's "if it does not" branch did not fire. Floor mismatch (`>=3.12`,
  `.python-version` 3.14, `from warnings import deprecated`): all five exit 0 → review-held.
- Task 2 — duplicate basenames, no `__init__.py`, cold cache: `mypy --strict .` exit 2
  `Duplicate module named "test_models"`; with inits: gate exit 0, planted wrong return → mypy
  exit 1; missing test file: all five exit 0; `_helper` import: all five exit 0;
  `ruff rule PLC2701`: "This rule is in preview and is not stable."
- Task 3 — root declaring `[project]`: plain sync then `import core` exit 1, `--all-packages`
  exit 0; virtual root: plain sync `import core` exit 0; full gate with `--all-packages` green on
  both shapes (`5 passed`); planted defects fail ruff/mypy/pytest; undeclared sibling dependency:
  all five exit 0 → review-held.

## Deviations

- 2026-10-30 — Task 3's `plain_sync_leaves_members_out` and its Change text amended before the
  task ran, with spec §1.4 (virtual-root correction, see plan 01 Deviations).
- 2026-10-30 — Spec §5 `test-mandate.md` row amended in place: the tree starts at `tests/` (single
  project) or `<member>_tests/` (workspace, member's `tests/` carries none); mypy needs only the
  top file, the rest review-held. Settled by the orchestrator from the author's earlier decision
  ("`__init__.py` in every test dir", "workspace tests in `<m>_tests/`"); plans 01 and 03
  re-confirmed against `fd450d45d88d`.
- 2026-10-30 — Task 1 started while plan 01 was built but not yet `done` (author's goal named
  both plans).
