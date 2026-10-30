# Python — Test Mandate

Every Python module under `src/` that contains executable logic has a matching test file in the test
tree, and the tree is laid out so mypy can check every file in it. The gate does not check that a
matching file exists or what it holds; review does. This file says where tests live, which modules
are exempt, what a test file covers, and which part of that the gate sees.

Reinforces the test discipline in `strict-quality.md`. Stricter than pytest's own advice: this rule
fixes *where* the tests sit and *what* a logic-bearing module must have, not just that tests exist.

**Evidence.** Behaviour claims below were observed on 2026-10-30 with uv 0.13.6, ruff 0.17.3, mypy
2.4.1 and pytest 9.2.0 on CPython 3.12.16, and are marked *observed*. Each observation that names a
gate step was made on a copy of a project carrying the baseline of `strict-quality.md`, on which all
five gate commands exited `0` before the change; every mypy observation about duplicate names used a
cold cache (`.mypy_cache` deleted first). Claims about what pytest documents give the document's line
and quoted words, fetched on 2026-10-30 (`goodpractices.rst` is
`https://raw.githubusercontent.com/pytest-dev/pytest/main/doc/en/explanation/goodpractices.rst`;
`pythonpath.rst` is the same path with that file name), from a URL that tracks the default branch, so
the live text can have moved since.

## The mandate

Each module under `src/` MUST have a test file in the test tree exercising its public AND non-trivial
private items, UNLESS the module falls under one of the [Exempt module kinds](#exempt-module-kinds).

- **Where the file sits.** A module `src/<package>/<path>/<module>.py` is tested by
  `tests/<path>/test_<module>.py`: the directories between `tests/` and the file mirror the
  module's directories below the package, and the file name is `test_` plus the module name.
  `src/base/a/models.py` is tested by `tests/a/test_models.py`. pytest collects "``test_*.py`` or
  ``*_test.py`` files" (`goodpractices.rst:110`); the guideline fixes the `test_<module>.py` form.
- **"Non-trivial"** = anything that branches, allocates, parses, formats, validates, masks,
  classifies, transforms, retries, or defines a non-derived `__repr__`, `__str__`, `__eq__` or
  `__hash__`. A getter or a pure forwarder is trivial; everything else is not.
- **One test per behaviour, not per line.** The bar is "would a regression here go unnoticed without
  this test?" If yes, the test is required.
- **Held by review.** A new logic module with no test file passed all five gate commands (*observed*,
  below). Nothing but review notices the omission.

## Where tests live

- **Tests sit in a separate tree, `tests/` at the project root, beside `src/`.** pytest names the
  layout: "Tests outside application code", for projects that "want to keep tests separate from
  actual application code (often a good idea)" (`goodpractices.rst:129-134`). `project-layout.md`
  fixes where the directory sits; this file fixes what is in it.
- **Every directory of the test tree carries an `__init__.py`, starting at the top of the tree.** The
  top is `tests/` in a single project and `packages/<member>/tests/<member>_tests/` in a workspace
  member. A workspace member's own `tests/` carries none: two members cannot each own a package
  called `tests` (below). One rule covers both project forms.
- **The top `__init__.py` is what mypy needs; the files below it are policy.** The gate fails only
  when two test files share a name and the tree has no `__init__.py` at all; a top file alone
  satisfies it (*observed*, below). Review holds the `__init__.py` in every subdirectory.
- **None of this is for pytest.** The baseline runs `--import-mode=importlib`, under which "Test
  module names do not need to be unique" (`pythonpath.rst:61`), and pytest recommends that mode for
  new projects (`goodpractices.rst:154`).
- **A workspace's root `pyproject.toml` holds the baseline with `testpaths = ["packages"]`** (see
  `../SKILL.md` § Definition of Done); the gate runs from the root with `--all-packages`, so the
  members are installed whichever way the root is declared.

### Why mypy needs the top `__init__.py`

A mirrored tree can hold two test files with the same name. With `tests/a/test_models.py` and
`tests/b/test_models.py` and no `__init__.py` anywhere under `tests/`:

```text
$ uv run --locked mypy --strict .            (cold cache)
tests/b/test_models.py: error: Duplicate module named "test_models" (also at "./tests/a/test_models.py")
Found 1 error in 1 file (errors prevented further checking)
exit 2
```

The same tree passed `pytest` (`6 passed`, exit `0`) and the other four gate commands, so only the
`mypy --strict .` step reports it (*observed*). mypy's own note lists the way out: "adding
`__init__.py` somewhere". With `__init__.py` in `tests/`, `tests/a/` and `tests/b/`, the full gate
exited `0` (`Success: no issues found in 12 source files`, `6 passed`), and a function in
`src/base/a/models.py` changed to return `"x"` as `int` made `mypy --strict .` exit `1` with
``Incompatible return value type (got "str", expected "int")  [return-value]`` (*observed*): the
`__init__.py` files let mypy check the whole tree, they do not stop it checking.

The top file alone is enough for mypy. The same duplicate-name tree with `tests/__init__.py` and
none in `tests/a/` or `tests/b/` exited `0` on all five commands (`Success: no issues found in 10
source files`, `6 passed`) (*observed*). The `__init__.py` in each subdirectory is therefore not
gate-enforced; the rule asks for it and review holds it.

A project whose test file names are unique does not hit the failure: a project with
`tests/test_core.py` and no `tests/__init__.py` passed all five commands (*observed*). The rule is
stated for every project because a mirrored tree reaches a duplicate name as soon as two packages
each get a `models.py`, and the failure then stops mypy for the whole project.

The workspace form follows from the same mechanism. With `__init__.py` in both
`packages/core/tests/` and `packages/api/tests/`, cold-cache `mypy --strict .` exited `2` with
``Duplicate module named "tests" (also at "./packages/api/tests/__init__.py")`` (*observed*): two
members cannot each own a package called `tests`. With the tests in `packages/core/tests/core_tests/`
and `packages/api/tests/api_tests/`, `__init__.py` in each `*_tests/` directory and none in `tests/`,
all five commands exited `0` (`Success: no issues found in 8 source files`, `4 passed`) on a root
that declares `[project]`, synced with `--all-packages` (*observed*). Adding two `test_models.py`
files under `core_tests/a/` and `core_tests/b/`, with no `__init__.py` below `core_tests/`, left the
gate at exit `0` on all five commands (`10 source files`, `6 passed`) (*observed*): as in a single
project, the top file is gate-enforced and the deeper ones are review-held. Workspace claims in this
file rest on those three runs and no others.

### Shared test helpers

Under `importlib` mode "Test modules can't import each other", and testing utility modules in the
tests directories "are not importable"; pytest's advice is to "place testing utility modules together
with the application/library code", and to put fixtures in `conftest.py` (`pythonpath.rst:65-72`). A
helper that several test files import therefore lives in the package, not in the test tree.

## Exempt module kinds

A module is exempt — and may ship with no test file — ONLY if it falls into one of these categories.
The exemption is structural; "I'll add tests later" is not a category.

1. **Export-only modules.** An `__init__.py` holding exclusively a docstring, `__all__` and
   import / re-export statements. The `__init__.py` files inside the test tree hold no logic and are
   not modules under `src/`, so they need no test and no header.
2. **Pure type-alias modules.** A module whose only statements are `type Name = …` declarations.
3. **Pure protocol definitions.** A module whose only definitions are `Protocol` classes with
   signatures and docstrings and no method bodies containing logic.
4. **Constants-only modules.** A module that declares values and validates, computes and branches on
   none of them.

A module under an exemption MUST say which category and why, in its module docstring, so the
exemption is visible to reviewers without a search elsewhere:

```python
"""Pure Protocol definition.

No tests per the test-mandate exemption 3: the module has no executable logic.
"""
```

That docstring, and the constants-only form with the same shape, passed all five gate commands
(*observed*). The gate does not read the claim, so review checks that the module matches the
category it cites.

## Doctests and wider tests are not a substitute

A doctest on a public item and a test of the whole application do not satisfy the mandate for the
modules they pass through:

- **The gate cannot tell the difference.** The module that had no test file still ran: pytest
  reported `3 passed` for the run, one of them the module's own doctest (`src/base/pricing.py .`).
  A green `pytest` step says nothing about the mandate (*observed*).
- A doctest is an example of the public surface. The branches behind it, such as the
  `raise ValueError` path of a pricing function whose doctest shows only a valid call, run only if a
  test reaches them.
- A test of the assembled application fails far from the code that broke, so the failing module is
  ambiguous, and it costs more to run and keep than a test of the module.

Concretely: a module with a `classify_error` function MUST have a `tests/…/test_<module>.py` that
reaches each classification branch, even when an end-to-end test covers the happy path through the
caller.

## Required justification when omitting

If a module is NOT exempt and the author still believes tests are infeasible (rare), the module MUST
carry a docstring block giving the reason AND a tracking reference:

```python
"""Open a connection.

Tests deferred. Reason: `dial` opens a live socket and needs a socket fake that
does not exist yet. Tracked: ISSUE-123.
"""
```

That module passed all five gate commands (*observed*), so review rejects a deferral without both a
reason and a reference. "Covered by end-to-end tests" is not a valid reason; see the section above.

## What a test file should cover

For a typical logic-bearing module:

- **Happy path** for every public function and method. One assertion per behavioural claim.
- **Boundary inputs**: empty, zero, maximum, single-element, off-by-one, `None` where the type admits
  it, non-finite floats where the type allows them.
- **Error paths** for every `raise`: each exception the docstring's `Raises:` section lists is
  triggered, with `pytest.raises(…, match=…)`. Ruff's `PT011` gives the reason: `pytest.raises(Error)`
  "will catch any `Error` and may catch errors that are unrelated to the code under test"
  (`uvx ruff@0.17.3 rule PT011`). The baseline selects `PT`, so `pytest.raises(ValueError)` with no
  `match` fails `ruff check` (`PT011`, exit `1`); `pytest.raises(KeyError)` with no `match` does
  not (*observed*), so for an exception outside that rule's reach review holds it.
- **Validation invariants** for constructors that validate, such as `__post_init__` — both the accept
  and the reject side.
- **Round trips** for any type that serializes and carries semantic content.
- **Hand-written dunder methods**: `__repr__` masking a secret, `__str__` formatting, `__eq__` and
  `__hash__` quirks.

A skipped or expected-failure test carries a reason (`strict-quality.md`).

## Where Python differs from the Rust mandate

The Rust rule colocates tests in the file they test. Python does not:

- **The tests sit in a separate tree.** pytest names that layout (`goodpractices.rst:129-134`), and the
  baseline's `testpaths` and `per-file-ignores` assume it.
- **The visibility reason for colocating does not apply.** Rust colocates partly because an
  integration test cannot reach `pub(crate)` items. A Python test can import a `_private` name:
  `from base.core import _helper` in `tests/test_core.py` passed all five gate commands
  (`3 passed`, exit `0`). Ruff's `import-private-name` (`PLC2701`) would flag it, but the rule "is in
  preview and is not stable. The `--preview` flag is required for use" (`uvx ruff@0.17.3 rule
  PLC2701`), and the baseline does not enable preview; with `--preview --select PLC2701` the same
  file exited `1` with ``Private name import `_helper` from external module `base.core` ``
  (*observed*).
- **A test that imports a `_private` name couples itself to an implementation detail.** The rule's
  own text: private imports "are prone to unexpected changes". Test through the public function when
  it reaches the branch; import the private name when the logic is non-trivial and no public caller
  can reach it.
- **Drift is the cost of a separate tree.** When a module moves, its test file stays behind unless
  someone moves it. The mirrored layout makes the missing or stranded file findable by path, and
  review holds it.

## What the gate sees and what review holds

| Rule | Gate step | Outcome |
|---|---|---|
| a matching test file exists | none | green with the file absent (*observed*): review |
| duplicate test file names in a tree with no `__init__.py` anywhere | `mypy --strict .` | exit `2`, `Duplicate module named` (*observed*) |
| `__init__.py` at the top of the test tree, none in the subdirectories below it | none | green with duplicate names (*observed*): review holds the per-directory files |
| unique test file names, no `__init__.py` | none | green (*observed*): review |
| `__init__.py` in a workspace member's own `tests/`, in two members | `mypy --strict .` | exit `2`, `Duplicate module named "tests"` (*observed*) |
| a module claims an exemption | none | review compares the claim with the module |
| a test imports a `_private` name | none | green (*observed*); allowed |
| `pytest.raises(ValueError)` without `match` | `ruff check --no-fix` | exit `1`, `PT011` (*observed*) |
| `pytest.raises(KeyError)` without `match` | none | green (*observed*): review |
| boundary and error paths are tested | none | review |
| `@pytest.mark.skipif` with a boolean condition and no `reason=` | `pytest` | exit `1`, `Error evaluating 'skipif': you need to specify reason=STRING when using booleans as conditions.` (*observed*) |
| bare `@pytest.mark.skip` or `@pytest.mark.xfail`, no reason | none | green, `3 passed, 1 skipped, 1 xfailed` (*observed*): review |

## Reviewer checklist

Reject the change if:

- A new logic module under `src/` has no `tests/…/test_<module>.py` AND carries no exemption or
  deferral docstring.
- A module claims an exemption but does not match the category (a module with a function body
  claiming "export-only").
- A deferral docstring omits the tracking reference or the reason.
- A module gains a non-trivial public function, or a non-trivial private one, without a test for it.
- A test file is missing its mirrored path: `tests/…/test_<module>.py` does not correspond to the
  module's location under `src/`, or a moved module left its test behind.
- A directory of the test tree has no `__init__.py` (the top of the tree is `tests/` in a single
  project and `<member>_tests/` in a workspace member), or a workspace member's own `tests/` has one.
- Error and boundary paths are untested while the happy path is covered.
- A test is skipped or marked expected-failure without a reason.

## Rationale

Three failure modes this rule prevents:

1. **A green gate that proves nothing about coverage.** The module with a `raise` and two branches
   and no test file passed `ruff`, `mypy` and `pytest`. A regression in its branches has nothing to
   fail.
2. **Branches covered only through a doctest.** The doctest ran the happy path and counted as a
   passing test. The rejection path and the below-threshold path ran in no test.
3. **A mirrored tree that stops the type check.** Two `test_models.py` files and no `__init__.py`
   made `mypy --strict .` exit `2` before it checked any file, so one cosmetic collision removed the
   type check from the whole project until it was fixed.

The cost of a test file is minutes. The cost of a regression found only when a caller breaks is the
bisect through unrelated code.

## Interaction with other rules

- `strict-quality.md` — covers the gate command set, `--doctest-modules`, the `tests/**` ignores in
  `per-file-ignores`, and the rule on skipped tests. This rule adds the *placement* and *presence*
  requirements the gate does not check.
- `project-layout.md` — fixes where `tests/` sits relative to `src/`; this file fixes what is in it.
