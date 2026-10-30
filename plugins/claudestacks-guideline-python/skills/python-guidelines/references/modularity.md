# Python — Modularity: One Responsibility, One Home

Every class, module and function owns **one** clearly-nameable responsibility, and every concept has
**exactly one** canonical type. Two opposite failure modes of the same axis: a **God object**
collapses many responsibilities into one unit; a **duplicate type** splits one concept across many
units. Two more rules keep the import graph honest: **no import cycles**, and **no module named after
a standard-library module**. This file says what each rule requires, which part of it a gate step
sees, and which part review holds. Most of it is review, and the observations below show why.

The first two rules are the ones in `rust-guidelines` `references/modularity.md` (Rules 1 and 2),
restated for Python; the last two are Python's own. `init-export-only.md` fixes what a package's
`__init__.py` may hold, `strong-types.md` how a domain value is modelled, `docstring-discipline.md`
what a module docstring says, and `test-mandate.md` where the tests of a split module go.

**Evidence.** Behaviour claims below were observed on 2026-10-30 with uv 0.13.6, ruff 0.17.3, mypy
2.4.1 and pytest 9.2.0 on CPython 3.12.16, and are marked *observed*. Each was made on a fresh copy
of a project carrying the baseline of `strict-quality.md` (package `probe` under `src/`, one test),
on which all five gate commands exited `0` before the change. Claims about what Python or Ruff
document give the file and line, or the command that printed the text, and the words quoted. The
CPython documents were fetched on 2026-10-30 from `main`
(`import.rst` is `https://raw.githubusercontent.com/python/cpython/main/Doc/reference/import.rst`;
`sys.rst` is `…/Doc/library/sys.rst` and `cmdline.rst` is `…/Doc/using/cmdline.rst`); the Google
Python Style Guide, as `pyguide.md`, from
`https://raw.githubusercontent.com/google/styleguide/gh-pages/pyguide.md` on the same day. All track
a default branch, so the live text can have moved since. Ruff's text is from `ruff rule <CODE>` and
`ruff config <option>` at 0.17.3.

## Rule 1 — No God object

A class, module or function that has accreted responsibilities it should not own. Review rejects:

- A class whose attributes serve unrelated concerns (configuration **and** connection state **and**
  a cache **and** metrics), so almost every change touches it.
- A module mixing distinct concept clusters, such as a decision vocabulary beside an unrelated
  rule-persistence cluster. Split it into sibling modules, one concept each.
- A function that resolves **and** does I/O **and** formats **and** maps errors. Extract each step
  into a named, independently testable function.
- A `*Manager`, `*Util`, `*Helper` or `*Context` class, or a `utils.py`, `helpers.py`, `common.py`
  or `misc.py` module, accumulating a grab-bag. Generic names invite this: name a unit after the one
  thing it owns, and if you cannot, it owns too much.

**Litmus test.** The summary line of the module docstring (`docstring-discipline.md`) states the
module's single load-bearing responsibility. If it needs an "and" joining unrelated concerns, split.

Splitting is behaviour-preserving when the new package's `__init__.py` re-exports every name
(`init-export-only.md`), so external import paths stay stable. Turning `probe/models.py`, holding
an enum and a frozen dataclass, into the package `probe/models/` with `decision.py`, `rule.py` and an
`__init__.py` that imports both and lists them in `__all__` left `from probe.models import Decision,
Rule` in an unchanged test working, and all five gate commands exited `0` (*observed*). The tests
then follow the modules (`test-mandate.md`). Split **the moment a second unrelated responsibility
appears**, not when the file gets long — but cohesion, not line count, is the test. Two or three
types forming one concept and always read together belong in one module; do not fragment a concept
into five one-line files.

**Held by review.** A class with 25 public methods passed all five gate commands (*observed*). Ruff
has a rule for it, `PLR0904` `too-many-public-methods` ("By default, this rule allows up to 20
public methods", `ruff rule PLR0904`), but it is a preview rule: `ruff check --no-fix --preview
--select PLR0904` flagged the class with `Too many public methods (25 > 20)`, and the baseline
selects no preview rule. What the gate does see is a size proxy for the function case: a function
with six parameters failed `ruff check --no-fix` with `PLR0913` (`Too many arguments in function
definition (6 > 5)`) and `PLR0917` (`Too many positional arguments (6 > 5)`) (*observed*). A
function can be under every size limit and still mix four concerns, so review holds the rule.

## Rule 2 — No duplicate types

Two or more types modelling the *same concept*. It forces converters, drifts out of sync, and
doubles the surface a reader learns. Review rejects:

- Two enums or dataclasses with the same members and meaning, differing only by name or a dropped
  field (a private `Gate` with `ALLOW` and `DENY` mirroring the public `Decision`). Reuse the
  canonical type; if a stage needs less data, transform the canonical value in place.
- A bare enum re-declared per consumer (`FooBehavior`, `BarBehavior`, both `ALLOW` and `DENY`).
  Declare one shared enum. A payload-carrying dataclass and a bare enum are *not* duplicates —
  different shapes, different roles — but two enums with identical members are.
- A "wire" dataclass and a "domain" dataclass that are field-identical with an identity conversion.
  They are legitimately two only when they carry different invariants (a validated type beside its
  raw form, `strong-types.md`); say so in each class docstring.
- Re-deriving a concept the project, the standard library or a dependency already provides. Search
  before declaring: `http.HTTPStatus` already has `NOT_FOUND` with the value `404` (*observed*,
  `python -I -c` on CPython 3.12.12), so a project enum of HTTP status codes is a duplicate.

**The canonical-type test.** For any concept exactly one type *is* that concept; everything else
references it. Before adding a type, ask whether an existing one already means this. If yes, reuse.
If it means *almost* this, decide whether the difference is a real invariant (keep both, document
why) or mere convenience (reuse, transform in place).

**Held by review.** Two enums, `Decision` and `Gate`, each with members `ALLOW = 1` and `DENY = 2`
and the same docstring, in two modules, passed all five gate commands (*observed*). No Ruff or mypy
rule compares type definitions.

## Rule 3 — No import cycles

The module import graph is acyclic: if module `a` imports `b`, directly or through others, `b` does
not import `a`. A cycle means each module needs the other to be understood, so neither has one home
and neither can be tested or reused alone.

- **Held by review, because the gate does not see a cycle.** Modules `a` and `b` importing each
  other at module level (`from probe import b` in `a`, `from probe import a` in `b`, each using the
  other's functions inside function bodies) passed all five gate commands (*observed*). Searching
  `ruff rule --all --output-format json` for "cycl" and "circular" in the rule text found six rules:
  `ASYNC110`, `B911`, `TC001`, `F401`, `PLC0415` and `PLW0406`. None detects a cycle between
  modules; `PLW0406` `import-self` flags only a module importing itself.
- **A cycle can also be a runtime failure.** The same two modules importing names, `from probe.b
  import base_b` in `a` and `from probe.a import base_a` in `b`, passed `ruff format --check`, `ruff
  check --no-fix` and `mypy --strict .`, and `pytest` exited `2` with `3 errors during collection`
  (`tests/test_cycle.py`, `src/probe/a.py`, `src/probe/b.py`). Outside pytest, `python -I -c "import
  probe.a"` printed ``ImportError: cannot import name 'base_a' from partially initialized module
  'probe.a' (most likely due to a circular import)`` followed by the path of `a.py` (*observed*).
  The reason is in the import machinery: "The module will exist in `sys.modules` before the loader executes the module code. This
  is crucial because the module code may (directly or indirectly) import itself"
  (`import.rst:391-393`), so the second module is handed one whose names are not yet defined. The
  module-level form survives only while each name is used inside a function body: adding `X =
  b.base_b()` at the top of `a` and `Y = a.base_a()` at the top of `b` kept `ruff format --check`,
  `ruff check --no-fix` and `mypy --strict .` at exit `0`, `pytest` exited `2` with `3 errors during
  collection`, and `python -I -c "import probe.a"` and `python -I -c "import probe.b"` each raised
  ``AttributeError: partially initialized module … has no attribute … (most likely due to a circular
  import)`` (*observed*). Working today is a property of where a name is used, not of the design, and
  the rule forbids both forms.
- **A deferred import is not the remedy.** Moving `from probe.a import base_a` into the function
  body of `b` made the cycle work at runtime and failed `ruff check --no-fix` with `PLC0415`
  (`` `import` should be at the top-level of a file ``) (*observed*). The gate therefore stops the
  common escape hatch; a `# noqa: PLC0415` that hides a cycle is rejected by review, and an import
  under `if TYPE_CHECKING:` is still a dependency edge that the rule counts.
- **Remove the cycle by changing the design:**
  - Move what both modules need into a third module that both import and that imports neither.
  - Merge the two when they are really one concept (Rule 1's cohesion test).
  - Pass the one thing `b` needs from `a` in as an argument, a callable or a `Protocol` defined
    where `b` can see it (`protocols-and-composition.md`).
- **Review traces the imports.** For each module a change adds or edits, follow its imports down
  until they end or return to it. There is no tool in the gate to ask.

## Rule 4 — No module named after a standard-library module

No module file and no package directory in the project takes the name of a standard-library module:
not `logging.py`, `json.py`, `types.py`, `email/`, or `secrets.py`, at any depth under `src/`.
Google 2.3 (Packages, `pyguide.md:230`) names the benefit of full package names as avoiding
"conflicts in module names or incorrect imports due to the module search path not being what the
author expected" (`pyguide.md:241-242`), warns that a bare `import jodie` has an "actual import
behavior" that "depends on external factors controlling sys.path" (`pyguide.md:293-295`), and says
code "should assume that `import jodie` refers to a third-party or top-level package named
`jodie`, not a local `jodie.py`" (`pyguide.md:300-302`).

- **Why a nested module is still a hazard.** `python script.py` prepends the script's directory to
  `sys.path` (`sys.rst:1635-1637`), so a script run by path from inside the package finds the sibling
  before the standard library. With `src/probe/logging.py` and `src/probe/runme.py` containing
  `import logging`, `python src/probe/runme.py` printed `…/src/probe/logging.py` for
  `logging.__file__` and `False` for `hasattr(logging, "getLogger")`; `python -I src/probe/runme.py`
  and `python -m probe.runme` both printed the standard library's `logging/__init__.py` and `True`
  (*observed*). `-I` leaves "neither the script's directory nor the user's site-packages directory"
  on `sys.path` (`cmdline.rst:325-326`). So the defect appears only for some ways of starting the
  program, which is the kind a reviewer cannot see from the diff.
- **The gate sees only the top-level case under the baseline.** Ruff's `A005`
  (`stdlib-module-shadowing`) reads: "By default, the module path relative to the project root or
  `src` directories is considered, so a top-level `logging.py` or `logging/__init__.py` will clash
  with the builtin `logging` module, but `utils/logging.py`, for example, will not" (`ruff rule
  A005`). Observed with the baseline:

  | Layout | `ruff check --no-fix` | Other steps |
  |---|---|---|
  | `src/probe/logging.py` | exit `0` | all exit `0` |
  | `src/logging.py` | exit `1`, `A005` | `mypy` and `pytest` exit `0` |
  | `src/probe/logging.py` and `[tool.ruff.lint.flake8-builtins] strict-checking = true` | exit `1`, `A005` | `mypy` and `pytest` exit `0` |

  The `A` family is in the baseline, but the layout this rule exists for, a module inside the
  package, passes it. **Held by review** unless the project adds `strict-checking = true`, which
  `ruff config lint.flake8-builtins.strict-checking` describes as "Compare module names instead of
  full module paths". A project may add that setting; the baseline does not require it.
  `allowed-modules` lists exceptions, and a project that uses one names the module and the reason.
- **The list of names is the interpreter's.** `sys.stdlib_module_names` is "A frozenset of strings
  containing the names of standard library modules" and lists only top-level names: `email` is in it
  and `email.message` is not (`sys.rst:2252-2263`). Run from the project root, this prints every
  module or package name under `src/` that is also a standard-library name, and printed `['logging']`
  for the layout above and `[]` for the project without it (*observed*):

  ```bash
  python -I -c "import sys, pathlib; src = pathlib.Path('src'); names = {p.stem for p in src.rglob('*.py')} | {p.parent.name for p in src.rglob('__init__.py')}; print(sorted(names & sys.stdlib_module_names))"
  ```

  It checks the interpreter that runs it, so it names the standard library of that Python version;
  a name added in a later version appears only when the gate runs on it.
- **Rename the module after what it owns**, not after the library it wraps: `probe/log_setup.py`,
  not `probe/logging.py`. Google's other import rule, "Do not use relative names in imports"
  (`pyguide.md:210-212`), is part of the same defence: spell the full package name.

## What the gate sees and what review holds

| Rule | Gate step that sees it | Held by review |
|---|---|---|
| 1. No God object | `ruff check`: `PLR0913`, `PLR0917` on a 6-parameter function | a class of unrelated concerns, a mixed module, a function doing four jobs, a grab-bag name |
| 2. No duplicate types | none | every duplicate |
| 3. No import cycles | `ruff check`: `PLC0415` on a deferred import; `pytest` when a name-import cycle fails at import | every cycle, including the module-level form |
| 4. No stdlib-named module | `ruff check`: `A005` for a top-level module, or any module with `strict-checking = true` | a module inside the package, with the default setting |

## Things to AVOID

- A class or module that needs "and" to say what it is for.
- `utils.py`, `helpers.py`, `common.py`, `misc.py`, or a `*Manager` / `*Util` / `*Helper` /
  `*Context` that grows methods for every new need.
- Two enums or dataclasses that mean the same thing under different names.
- Declaring a type the standard library or a dependency already provides.
- A module-level import cycle, or a function-level import added to make one work.
- A module or package named `logging`, `json`, `types`, `email`, `secrets` or any other name in
  `sys.stdlib_module_names`.

## Reviewer checklist

Reject the change if:

- A class, module or function has a responsibility that cannot be stated without an "and" joining
  unrelated concerns, or a change adds a second unrelated responsibility to a module without
  splitting it in the same change.
- A new type duplicates an existing concept in the project, the standard library or a dependency. A
  look-alike kept on purpose says, in its docstring, which invariant distinguishes it from its twin.
- A new import completes a cycle between modules, whether at module level or under
  `if TYPE_CHECKING:`, or a function-level import or `# noqa: PLC0415` is used to avoid one.
- A new module or package takes a standard-library name, at any depth under `src/`.
- A split leaves an import path unusable instead of re-exporting from the package's `__init__.py`,
  or leaves the split modules without the tests `test-mandate.md` requires.
