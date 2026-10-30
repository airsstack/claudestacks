# Python — `__init__.py` Is Export-Only

An `__init__.py` in `src/` is the **table of contents** of its package: a docstring, `__all__` and
re-exports. **No implementation lives in it.** Implementation lives in sibling modules, one concept
per module. This rule complements `strict-quality.md` (the gate), `test-mandate.md` (which exempts
export-only modules from needing a test) and `project-layout.md` (the `src/<package>/` shape).

**Evidence.** Behaviour claims below were observed on 2026-10-30 with uv 0.13.6, ruff 0.17.3,
mypy 2.4.1 and pytest 9.2.0 on CPython 3.12.16, on a copy of a project carrying the
`strict-quality.md` baseline whose five gate commands exited `0`, and are marked *observed*. Quoted
text was fetched on 2026-10-30; the live text can have moved since. Citations are `<file>:<line>` of:

- `distributing.rst` — `https://raw.githubusercontent.com/python/typing/main/docs/spec/distributing.rst`
  (the typing specification, "Distributing type information");
- `pyguide.md` — `https://raw.githubusercontent.com/google/styleguide/gh-pages/pyguide.md` (the
  Google Python Style Guide);
- `command_line.rst` — `https://raw.githubusercontent.com/python/mypy/master/docs/source/command_line.rst`;
- `pep-0257.rst` — `https://raw.githubusercontent.com/python/peps/main/peps/pep-0257.rst`;
- Ruff rule text, quoted from `uvx ruff@0.17.3 rule <CODE>`.

## The rule

An `__init__.py` under `src/` MUST contain only:

1. **A docstring** — see [Required package documentation](#required-package-documentation).
2. **`__all__`** — the list of names that are the package's public interface. Written as a literal
   list or tuple of string literals, sorted (see the forms the typing spec supports, below).
3. **Re-exports** — absolute `from <package>.<module> import <Name>` statements, one for each name
   in `__all__` that comes from a sibling module.

It MUST NOT contain:

- `def`, `async def`, `class` or `type` statements; any assignment other than `__all__` (that
  includes `__version__` and every other constant — put it in a sibling module and re-export it);
  decorators; `if` or `try` blocks; a module-level `__getattr__`.
- Star imports (`from <package>.<module> import *`).
- Relative imports (`from .core import double`).
- Tests or doctest-bearing functions. Tests live under `tests/` (`test-mandate.md`).

Which of these a tool catches is in [What the gate sees](#what-the-gate-sees-and-what-review-holds);
the short version is that the gate catches a *missing* export and a missing docstring, and review
holds everything else on this list.

### Re-export forms

The typing specification fixes how a type checker reads a package's interface. "Imported symbols
are considered private by default", only a fixed set of import forms re-export them, and a
module-level `__all__` "overrides all other rules above" (`distributing.rst:379-385`). The forms
that re-export (`distributing.rst:411-417`) and this guideline's position on each:

| Form | Re-exports | This guideline |
|---|---|---|
| `__all__ = ["double"]` after `from pkg.core import double` | `double` | **The form to use.** Lists the interface in one place. |
| `from pkg.core import double as double` | `double` | Accepted, for a package that lists no `__all__`. Do not mix the two forms in one file. |
| `import X as X` | the module `X` | Accepted, same condition. |
| `from pkg.core import *` | every name in `core`'s `__all__`, or every public name | **Forbidden.** The reader cannot see the interface; see below. |

mypy's `--no-implicit-reexport` agrees with the first two: "This flag changes the behavior to not
re-export unless the item is imported using from-as or is included in ``__all__``"
(`command_line.rst:706-708`), and the baseline's `strict = true` turns it on (*observed*, below).

`__all__` is written in the forms the specification lists as statically readable
(`distributing.rst:389-400`): `__all__ = ["a", "b"]`, `__all__ = ("a", "b")` and the `+=`, `extend`,
`append` and `remove` forms. A computed value is not on that list. `__all__ = sorted(["double"])`
failed three ways at once (*observed*): `ruff check` raised ``PLE0605 Invalid format for `__all__`,
must be `tuple` or `list` ``, `F401` on the import, and `mypy --strict .` raised ``Module "base"
does not explicitly export attribute "double"  [attr-defined]`` in the test that imported it.

**A star import passes the whole gate.** `from base.core import *` in `__init__.py` left all five
commands at `0`, and the same line in an ordinary module left `ruff check` at `0` (*observed*):
Ruff's `F403` (`undefined-local-with-import-star`) is not among the rules enabled by the baseline
plus Ruff 0.17.3's defaults. `uvx ruff@0.17.3 check --isolated --show-settings` lists neither
`F403` nor `F405`, and `ruff check --select F403` on the same file exited `1` (*observed*). So the
ban is held by review.

## Required package documentation

The docstring is the first statement in the file (`pyguide.md:2103-2105`: "A docstring is a string
that is the first statement in a package, module, class or function"). PEP 257: "The docstring for a
package (i.e., the docstring of the package's ``__init__.py`` module) should also list the modules
and subpackages exported by the package" (`pep-0257.rst:155-157`), and Google asks that files "start
with a docstring describing the contents and usage of the module" (`pyguide.md:2127-2128`).

An `__init__.py` docstring answers, in this order:

1. **What the package is** — one summary line ending in a period. Google asks for "a summary line
   (one physical line not exceeding 80 characters) terminated by a period, question mark, or
   exclamation point" (`pyguide.md:2108-2110`); accepting only the period is this guideline's
   policy. Concrete, not generic. Bad: `"""Core stuff."""`. Good:
   `"""Arithmetic helpers, importable from one path."""`.
2. **Why it exists** — the reason this package is separate from its siblings. If you cannot say why
   it is not merged into its parent, it probably should not exist.
3. **Responsibilities** — the modules and subpackages, one line each, in the order of the files.
   A reader scanning the list can predict which module a concept lives in.
4. **Not here** *(when non-obvious)* — what readers might mistakenly look for here.
5. **The test exemption line** — `test-mandate.md` requires a module under an exemption to name the
   category in its docstring: an `__init__.py` that holds only a docstring, `__all__` and
   re-exports is exemption 1 (export-only).

Keep the block to 5–15 lines. The gate requires a docstring and nothing about its content: an
`__init__.py` with no docstring raised `D104 Missing docstring in public package`, an empty one
raised the same, and a one-line docstring passed all five commands (*observed*). Review holds the
content.

### When the rule does not apply

- **The `__init__.py` files inside the test tree.** They hold no logic and are not modules under
  `src/` (`test-mandate.md`, "Exempt module kinds"), so they need no test and no docstring. The
  baseline's `"tests/**" = [..., "D"]` ignore means an empty one raises no `D104`; the gate was
  green with an empty `tests/__init__.py` (*observed*). Where the test tree starts, and which
  directories carry one, is `test-mandate.md`'s rule, not this file's.
- **A package that only groups modules.** An `__init__.py` holding a one-line docstring and nothing
  else is complete: no `__all__`, no re-exports. Callers import the module, `from base import core`,
  and the gate stayed green (*observed*). Use this when no name is worth flattening.
- **The scaffold is not an exception.** `uv init --lib` wrote `def hello() -> str` into
  `src/<package>/__init__.py`, and `uv init --app` wrote `def main() -> None` there with
  `[project.scripts] <name> = "<name>:main"` (*observed*). Move the function to a sibling and
  point the entry point at it: with `main` in `src/base/cli.py` and `base = "base.cli:main"`, the
  gate was green and `uv run --locked base` printed `4` (*observed*).

There is no size exemption. A one-function `__init__.py` is still implementation in the wrong file.

## Why

- **The interface is declared in one place, and a type checker enforces it.** The specification
  makes `__all__` and the redundant-alias forms the only ways to mark an import as part of the
  interface (`distributing.rst:379-385`). An import that is in neither is private to mypy, whatever
  Python does at run time: see the first row of the table below.
- **Export-only keeps the test mandate mechanical.** An `__init__.py` that only re-exports is exempt
  from needing a test file (`test-mandate.md`). Put logic in it and the exemption is gone; the file
  then needs a `tests/…/test_<module>.py`, and the gate does not notice either way (*observed*:
  an `__init__.py` with a `triple` function and no test left all five commands at `0`).
- **A diff says what moved.** A change to rounding edits `_rounding.py`, a change to the package's
  interface edits `__all__`. Rationale, not a tool fact.
- **A reader opens one file for the menu.** The docstring plus `__all__` is a five-second read; the
  reader opens only the module they need.

## Imports inside the package

- **Sibling modules import each other by the defining module, never through the package's own
  `__init__.py`.** `from base.helper import twice` in `core.py`, not `from base import twice`.
  *Held by review*; the pytest step catches only the load order that breaks. With `__init__.py`
  importing `base.core` and then `base.helper`, `core.py` doing `from base import twice` made
  `ruff check` and `mypy --strict .` exit `0` and `pytest` exit `2` with ``ImportError: cannot
  import name 'twice' from partially initialized module 'base'`` at collection (*observed*). With
  the same `__init__.py`, `helper.py` doing `from base import double` (defined in `core.py`, which
  loads first) left all five commands at `0` (*observed*). The static steps accept both; whether
  the import fails depends on the order of the lines in `__init__.py`, so a green run does not
  clear it.
- **Absolute, not relative.** Google 2.3 says to import each module "by its full package name"
  (`pyguide.md:261`), and 2.2 says "Do not use relative names in imports. Even if the module is in
  the same package, use the full package name" (`pyguide.md:210-212`). `from .core import double`
  passed all five commands (*observed*): the baseline does not select Ruff's `TID` family. Review
  holds it. Further import-graph rules (cycles) are in `modularity.md`.
- **The re-export line is where this guideline overrides Google 2.2.** The Google rule is "Use
  `import` statements for packages and modules only, not for individual types, classes, or
  functions" (`pyguide.md:147-148`), and `from pkg.core import double` imports a function. The
  typing specification has no way to re-export a function or class that avoids it, so the override
  is confined to `__init__.py`. The flattened surface serves the style Google prefers: `x.Obj` "says
  that object `Obj` is defined in module `x`" (`pyguide.md:166-168`), so callers write
  `import base` and `base.double(2)`. Both that form and `from base import double` type-checked once
  `double` was exported, and both failed with `attr-defined` when it was not (*observed*). How a
  caller imports is Google 2.2's rule, indexed in `google-style-guide.md`, not this file's.

## Canonical shape

```python
"""Arithmetic helpers, importable from one path.

Why it exists: callers write ``import base`` and call ``base.double``, so the
module layout below can change without touching them.

Responsibilities:

- ``core``: integer arithmetic (``double``).

Not here: command-line handling, which lives in ``base.cli``.

No tests per the test-mandate exemption 1: this module holds only a docstring,
``__all__`` and re-exports.
"""

from base.core import double

__all__ = ["double"]
```

This file, with `core.py` defining `double`, a `cli.py` beside it, an empty `tests/__init__.py` and
`import base` / `base.double(2)` in a test, passed all five gate commands (*observed*). No tool
reads the "Not here" cross-reference, so review keeps it true. Imports are
sorted (Ruff's `I`), `__all__` is sorted (`RUF022`), and the `from … import` line is what `F401`
needs `__all__` to excuse.

## Naming siblings

- **Name the file after the one concept it owns**, `lower_with_under`, `.py`, "Never use dashes"
  (`pyguide.md:3119`, `:3131`; dashes are also in Google's names to avoid, `:3155`). One concept per
  module: a new module owns exactly one, and review questions a name that does not describe its
  contents.
- **Avoid generic names — `utils.py`, `helpers.py`, `common.py`, `misc.py`.** Google asks that
  "Names should be descriptive" (`pyguide.md:3124`). A `utils.py` with a documented function passed
  all five commands (*observed*), so this is held by review; they invite mixed-concern dumping.
- **A leading underscore marks a private module.** In a package that ships `py.typed`, a type
  checker "will treat all modules within that package … as importable unless the file name begins
  with an underscore. These modules comprise the supported interface for the library"
  (`distributing.rst:367-370`). Name an implementation module `_rounding.py` and re-export through
  `__all__` what callers need; a public module is named without the underscore. Not `_impl.py`,
  `_internal.py`, `_stuff.py` — the underscore says private, the rest of the name still says what.
- **Do not name a module after a standard-library module.** The reasons and the Ruff rule are in
  `modularity.md`.

## What the gate sees, and what review holds

Each row is one defect applied alone to a fresh copy of a project carrying the baseline
(*observed*, 2026-10-30; the project's gate was green first).

| Defect in `src/base/__init__.py` | Failing step | Output |
|---|---|---|
| `from base.core import double`, no `__all__`, a test uses `base.double` and one uses `from base import double` | `mypy --strict .` (exit `1`) and `ruff check` (exit `1`); `pytest` exit `0` | ``Module "base" does not explicitly export attribute "double"  [attr-defined]`` (both tests); ``F401 `base.core.double` imported but unused; consider removing, adding to `__all__`, or using a redundant alias`` |
| the same name added to `__all__` | none | green |
| `from base.core import double as double`, no `__all__` | none | green |
| `__all__ = ["halve", "double"]` | `ruff check` | `RUF022 [*] `__all__` is not sorted` |
| `__all__ = sorted(["double"])` | `ruff check`, `mypy` | `PLE0605`, `F401`, `attr-defined` (above) |
| no docstring, or an empty file | `ruff check` | `D104 Missing docstring in public package` |
| `core.py` does `from base import twice` while `__init__.py` imports `core` before `helper` | `pytest` (exit `2`) | ``ImportError: cannot import name 'twice' from partially initialized module 'base'`` |
| `helper.py` does `from base import double` while `__init__.py` imports `core` before `helper` | none | green |
| `__all__ = ["double", "missing"]`, `missing` defined nowhere | none | green; `from base import *` then raised ``AttributeError: module 'base' has no attribute 'missing'`` (*observed*) |
| `from base.core import *` | none | green |
| `from .core import double` with `__all__` | none | green |
| a `def triple` in `__init__.py` with a docstring, no test | none | green |
| a `utils.py` module | none | green |

Ruff documents why the `__all__` line above is not caught: `F822` (`undefined-export`) "will flag
undefined names in `__init__.py` file" only "In [preview]" (`uvx ruff@0.17.3 rule F822`).

**Gate-enforced:** an interface name missing from `__all__` (mypy `attr-defined`, with Ruff `F401`),
an unsorted `__all__` (`RUF022`), a computed `__all__` (`PLE0605`), and a missing or empty package
docstring (`D104`).

**Held by review:** a sibling importing through the package's own `__init__.py` (pytest catches only
the load order that breaks); an `__all__` entry that names nothing; any `def`, `class`, `type`
statement, constant or other logic in `__init__.py`; star imports; relative imports; a docstring
that is present but does not answer the questions above, or omits the exemption line; a generic
module name.

Ruff's `F401` documents the redundant alias as the form that instructs Ruff and "other tools" to
respect a re-export (`uvx ruff@0.17.3 rule F401`), and that `__all__` is the alternative; its
`PLC0414` (`useless-import-alias`) "does not apply in `__init__.py` files" (`uvx ruff@0.17.3 rule
PLC0414`), which is why `import X as X` there raises nothing (*observed* above).

## Things to AVOID

- A `def`, `class`, `type` statement or constant directly in `__init__.py`. Move it to a sibling
  module and re-export it.
- Importing a name from a sibling and leaving it out of `__all__`: to mypy it is private.
- `from pkg.module import *` in `__init__.py`, or an `__all__` built by a call, comprehension or
  `sorted(...)`.
- `from .module import Name`. Write the full package name.
- A module-level `__getattr__` or `if TYPE_CHECKING:` block to load names lazily. It is logic; this
  reference does not carry a lazy-import form.
- Naming a sibling `utils.py`, `helpers.py`, `common.py`, `_impl.py`.
- Hiding a public module behind an underscore because the file is small: the underscore is a
  contract with type checkers (`distributing.rst:367-370`), not a tidying preference.
- Importing from your own package's `__init__.py` inside the package: import the defining module.

## Definition of Done (rule additions)

In addition to the `strict-quality.md` gate:

- Reviewer rejects any `src/**/__init__.py` containing a `def`, `class`, `type` statement,
  non-`__all__` assignment, decorator, `if`/`try` block, module-level `__getattr__`, star import or
  relative import.
- Reviewer rejects an `__init__.py` whose imported public names are not all in `__all__` (or
  re-exported with `as`) — the gate catches the case a test or module imports one, review catches the
  case nothing does yet — and an `__all__` entry that names nothing.
- Reviewer rejects an `__init__.py` docstring that is a stub (`"""Package."""`) where the package
  re-exports names, or that omits the test-exemption line for an export-only file. A docstring-only
  grouping package needs the summary line and the exemption line only.
- A new sibling module introduced by a change owns exactly one concept; reviewer questions a name
  that does not describe its contents.
- An `__init__.py` in the test tree holds no logic (`test-mandate.md`).
