# Python — Typing

Every function is annotated, and every annotation is spelled the way the project's minimum Python
spells it: PEP 695 type parameters and `type` aliases, `X | None`, generics from `collections.abc`,
`@override` on every override, and `assert_never` closing every `match` over a closed set. The gate
enforces most of this through the baseline in `strict-quality.md`; this file says which rules the
gate holds, which review holds, and where the guideline overrides the Google Python Style Guide.

**The floor** is the `requires-python` minimum: 3.12 for a library, 3.14 for an application
(`strict-quality.md`). The gate runs on the interpreter `.python-version` names, which equals the
floor, so a name that does not exist at the floor fails the gate (below). Every rule here is for a
floor of 3.12 or later; where the answer depends on the floor, the rule says so.

**Evidence.** Behaviour claims below were observed on 2026-10-30 with uv 0.13.6, ruff 0.17.3, mypy
2.4.1 and pytest 9.2.0 on CPython 3.12.16 (3.13.18 and 3.14.10 for the rows that name a floor), and
are marked *observed*. Each observation was made by planting one change in a fresh copy of a project
carrying the baseline of `strict-quality.md`, on which all five gate commands exited `0` before the
change; "every step exits `0`" below means the full gate was run on the changed copy. Document
citations are `<file>:<line>` in files fetched with `curl` on 2026-10-30 from URLs that track each
project's default branch, so the live text can have moved since:

| File | URL |
|---|---|
| `pep-0695.rst`, `pep-0698.rst`, `pep-0742.rst`, `pep-0749.rst` | `https://raw.githubusercontent.com/python/peps/main/peps/` plus the file name |
| `typing.rst` | `https://raw.githubusercontent.com/python/cpython/3.15/Doc/library/typing.rst` |
| `whatsnew-3.14.rst` | `https://raw.githubusercontent.com/python/cpython/main/Doc/whatsnew/3.14.rst` |
| `unreachable.rst` | `https://raw.githubusercontent.com/python/typing/main/docs/guides/unreachable.rst` |
| `error_code_list2.rst` | `https://raw.githubusercontent.com/python/mypy/master/docs/source/error_code_list2.rst` |
| `pyguide.md` | `https://raw.githubusercontent.com/google/styleguide/gh-pages/pyguide.md` |

## Every function is annotated

- **Every parameter and return is annotated.** Google lets a module be partly annotated: "You are not
  required to annotate all the functions in a module" (`pyguide.md:3444`). This guideline does not.
  *Gate-enforced*: a function with no annotations failed `ruff check` with `ANN201` and `ANN001`
  and `mypy --strict` with `no-untyped-def` (*observed*).
- **A generic is parameterised.** `def f(a: list) -> int` failed `mypy --strict` with
  `Missing type arguments for generic type "list"  [type-arg]` (*observed*); Google gives the same
  reason, that an unparameterised generic is read as `Any` (`pyguide.md:4028-4036`).

## Type parameters and aliases use PEP 695 syntax

PEP 695 is a Python 3.12 feature (`pep-0695.rst:10`), so it is available at every floor.

- **Generics are declared with brackets**: `class Box[T]`, `def first[T](items: list[T]) -> T`.
  The old form needs a `TypeVar` and a `Generic[...]` base with a redundant quoted name
  (`pep-0695.rst:99-106`, `:120-135`, `:153`). Variance is inferred from use, so `_T_co` and
  `_T_contra` names go away (`pep-0695.rst:101-102`, `:618-625`). *Gate-enforced*: a class on
  `Generic[T]` failed `ruff check` with `UP046`, and a function using a module-level `TypeVar`, or
  a `ParamSpec` decorator, with `UP047` (*observed*). The bracketed forms, including `def
  logged[**P, R](func: Callable[P, R])`, passed every step.
- **Aliases are `type` statements**: `type Ident = int`, `type Tree[T] = T | list[Tree[T]]`. An
  alias may name itself without quotes (`pep-0695.rst:334-342`) because its value is evaluated
  lazily (`pep-0695.rst:386`); the recursive alias passed every step on a 3.12 floor (*observed*).
  A `type` alias cannot use a module-level `TypeVar` (`pep-0695.rst:358-365`), so a generic alias
  takes its own brackets.
- **`TypeAlias` is not used.** The CPython documentation says it "is deprecated in favor of the
  `type` statement" and that "Removal of `TypeAlias` is not currently planned, but users are
  encouraged to migrate" (`typing.rst:1078-1086`); PEP 695 proposes the deprecation
  (`pep-0695.rst:368-369`). The deprecation does not remove the name, so banning it is this
  guideline's policy. *Gate-enforced*: `Ident: TypeAlias = int` failed `ruff check` with `UP040`
  at a 3.12 floor and every other step exited `0` (*observed*).
- **A plain assignment is not an alias either.** `Ident = int` and `Maybe = int | None` passed
  every step at a 3.12 floor (*observed*): `UP040` reads the `TypeAlias` annotation and nothing
  else. *Held by review*: every alias is a `type` statement.

## Optional, unions and containers use the builtin spellings

- **`X | None`, `X | Y`, `list[int]`, `tuple[int, str]`.** Not `Optional`, `Union`, `List`, `Tuple`.
  Google recommends `|` and says explicit `X | None` is preferred over implicit
  (`pyguide.md:3649-3653`) but still lists `Union` and `Optional` as acceptable
  (`pyguide.md:3649-3650`, `:3662`); this guideline does not accept them. *Gate-enforced*:
  `Optional[int]` failed `ruff check` with `UP045`, `Union[int, str]` with `UP007`, `List[int]` with
  `UP006` and `typing.List` with `UP035` (*observed*).
- **Abstract types come from `collections.abc`**: `Callable`, `Sequence`, `Mapping`, `Iterable`.
  Google agrees (`pyguide.md:3909-3934`). *Gate-enforced*: `from typing import Callable, Sequence`
  failed `ruff check` with `UP035` ("Import from `collections.abc` instead") (*observed*).
- **No implicit `Optional`.** `def f(a: str = None)` failed `ruff check` with `RUF013` and
  `mypy --strict` with `Incompatible default for parameter "a"  [assignment]` (*observed*).
- **A parameter takes the most abstract type the function needs** (`Sequence[int]`, not `list[int]`),
  as Google advises (`pyguide.md:3932-3934`, `:3949-3954`). *Held by review*:
  `def total(items: list[int])` passed every step (*observed*). Choosing between a concrete type, a
  callable and a `Protocol` is `protocols-and-composition.md`.

## `@override` on every override

- **A method that overrides a base-class method carries `@override`** (`from typing import
  override`, available from 3.12: `typing.rst:3410-3448`). A type checker treats a decorated method
  as an error unless it overrides something (`pep-0698.rst:178-181`), and a project can trust that a
  refactor of a base class is override-safe only if the decorator is used throughout
  (`pep-0698.rst:228-232`).
- *Gate-enforced*, by the `explicit-override` code that the baseline's `enable_error_code` turns on
  (`--strict` does not): an override without the decorator failed `mypy --strict` with `Method
  "size" is not using @override but is overriding a method in class "base.shapes.Base"
  [explicit-override]` (*observed*, and in `strict-quality.md`). `@override` on a method that
  overrides nothing, such as a misspelt name, failed with `Method "sizes" is marked as an override,
  but no base method was found with this name  [misc]` (*observed*).
- **`__repr__`, `__eq__` and `__hash__` count.** Defined on a plain class they override `object`,
  and `mypy --strict` reported all three with `explicit-override`; an `__init__` that overrides
  another class's `__init__` was not reported (*observed*), which matches the mypy documentation:
  "An error will not be emitted for overrides of `__init__` or `__new__`"
  (`error_code_list2.rst:522-523`).

## `assert_never` closes every `match` over a closed set

- **A `match` over a union or an `Enum` ends `case _: assert_never(x)`** (`from typing import
  assert_never`, available from 3.11: `typing.rst:3083-3118`). The type checker accepts the call
  only when every earlier case has covered the type, so adding an enum member or a union arm makes
  every unclosed `match` an error (`typing.rst:3083-3111`; `unreachable.rst:40-85`).
- *Gate-enforced where the case is present*: a `match` over a two-member `Enum` that handled one
  member and ended `case _: assert_never(colour)` failed `mypy --strict` with `Argument 1 to
  "assert_never" has incompatible type "Literal[Colour.BLUE]"; expected "Never"  [arg-type]`; the
  same `match` handling both members passed every step (*observed*).
- *Held by review where the case is absent.* The same non-exhaustive `match` with no closing case,
  in a function returning `None`, passed every step, and so did a non-exhaustive `match` over
  `int | str` that handled only `int` (*observed*). In a function that returns a value, mypy catches
  the gap by a different route: `Missing return statement  [return]` (*observed*). That is the
  reason the closing case is mandatory: the silent case is the function that only does something.
- **A project may enable `exhaustive-match`.** mypy 2.4.1 with `--enable-error-code
  exhaustive-match` rejected both unclosed `match` statements above with `Match statement has
  unhandled case for values of type "Literal[Colour.BLUE]"  [exhaustive-match]` (*observed*); it is
  documented as opt-in (`error_code_list2.rst:646-653`) and the baseline does not enable it. It does
  not replace `assert_never`: with it enabled, `case _: sink.append("other")` passed every step
  (*observed*; the mypy documentation shows the same, `error_code_list2.rst:679-684`), so the
  wildcard still has to be the `assert_never` call.

## Narrowing functions use `TypeIs`

- **A user-defined narrowing function returns `TypeIs[T]`**, not `TypeGuard[T]`, wherever the floor
  provides it (3.13: `typing.rst:1638`). PEP 742 recommends documentation "emphasize `TypeIs` over
  `TypeGuard`" and that "most users should use `TypeIs`, and `TypeGuard` should be reserved for rare
  cases where its behavior is specifically desired" (`pep-0742.rst:107-111`). `TypeIs` narrows both
  branches and keeps what was already known about the value; `TypeGuard` narrows only the `True`
  branch to exactly its type (`typing.rst:1673-1685`).
- **`TypeGuard` stays for the two cases `TypeIs` cannot express**: the narrowed type is not a
  subtype of the input (`list[object]` to `list[int]`), or the function does not return `True` for
  every instance of the narrowed type (`typing.rst:1581-1587`).
- *Held by review* at a 3.13 or later floor: `-> TypeGuard[int]` on a 3.14 floor passed every step
  (*observed*), and so did `-> TypeIs[int]` on a 3.13 and a 3.14 floor.
- *Gate-enforced* at a 3.12 floor, which lacks the name: `from typing import TypeIs` failed `mypy
  --strict` with `Module "typing" has no attribute "TypeIs"  [attr-defined]` and failed `pytest`
  at collection with `ImportError: cannot import name 'TypeIs' from 'typing'` (exit `2`)
  (*observed*). A 3.12 library either uses `TypeGuard` or declares `typing-extensions` in
  `[project] dependencies` and imports `TypeIs` from it, which passed every step with
  `typing-extensions` 4.16.0 locked (*observed*). At a 3.13 floor the same import failed `ruff check`
  with `UP035` ("Import from `typing` instead: `TypeIs`"), so the backport goes once the floor
  provides the name (*observed*).

## The floor decides the spelling

- **A feature newer than the floor is not used.** `typing.TypeForm` (`typing.rst:1528-1554`) and
  `@disjoint_base` (`typing.rst:3450-3479`) are new in 3.15. *Gate-enforced* while `.python-version`
  equals the floor: `from typing import TypeForm` on a 3.14 floor failed `mypy --strict` with
  `Module "typing" has no attribute "TypeForm"  [attr-defined]` and `pytest` at collection with
  `ImportError` (exit `2`) (*observed*). A project whose floor is below the Python it runs the gate
  on gets no such failure, which is why `strict-quality.md` fixes `.python-version` to the floor.
- **At a 3.14 floor, no `from __future__ import annotations` and no quoted forward references.**
  Annotations are no longer evaluated eagerly and "It is no longer necessary to enclose annotations
  in strings if they contain forward references" (`whatsnew-3.14.rst:151-160`, PEP 749). The future
  import turns annotations back into strings, so deferred evaluation is bypassed "if `from __future__
  import annotations` is used" (`whatsnew-3.14.rst:154`), and the statement "is now deprecated and
  it is expected to be removed in a future version of Python" (`whatsnew-3.14.rst:3428-3429`;
  `pep-0749.rst:83-97`). A class whose method annotation names the class unquoted passed every step
  on a 3.14 floor (*observed*).
  - *Gate-enforced for quoted names*: `parent: "Node | None"` on a 3.14 floor failed `ruff check`
    with `UP037` ("Remove quotes from type annotation"); the same quoted name on a 3.12 floor
    passed every step (*observed*).
  - *Held by review for the future import*: `from __future__ import annotations` on a 3.14 floor
    passed every step (*observed*).
- **Below a 3.14 floor, a forward reference is a quoted name or the future import.** The bare name
  failed `ruff check` with `F821` and `pytest` at collection with `NameError: name 'Node' is not
  defined` on a 3.12 and on a 3.13 floor (*observed*). Google allows either the quoted name or the
  future import (`pyguide.md:3581-3600`) and encourages `from __future__` statements
  (`pyguide.md:1487`). Both forms passed every step on a 3.12 and on a 3.13 floor (*observed*), so
  *review holds* that one of them is present. The future import is documented as deprecated, but its
  behaviour is unchanged in 3.14 and its removal waits until after 3.13 reaches end of life
  (`whatsnew-3.14.rst:3428-3435`; `pep-0749.rst:91-95`), so below the 3.14 floor that is not a
  reason to reject it. A `type` alias needs neither (`pep-0695.rst:334-342`).

## Where this overrides Google

| Google rule | Reference | This guideline |
|---|---|---|
| 2.20: "Use of `from __future__ import` statements is encouraged" (`pyguide.md:1487`) | `pyguide.md:1438-1510` | at a 3.14 floor the annotations future import is not used (see above); below it, the future import or a quoted name, review holds the choice |
| 3.19.3: forward declarations by future import or quoted name (`pyguide.md:3581-3600`) | same | at a 3.14 floor neither |
| 3.19.6: alias "type-annotated as `typing.TypeAlias`" (`pyguide.md:3683-3695`) | same | `type` statement, `TypeAlias` banned |
| 3.19.10: `TypeVar` and `ParamSpec` module-level declarations (`pyguide.md:3798-3830`) | same | bracketed type parameters |
| 3.19.5: `Union` and `Optional` acceptable (`pyguide.md:3649-3650`, `:3662`) | same | `X \| None` and `X \| Y` only |
| 3.19.1: partial annotation allowed (`pyguide.md:3444`) | same | every function annotated |

Google 2.21 "strongly encouraged to enable Python type analysis" (`pyguide.md:1574-1585`) is met and
exceeded by `mypy --strict` in the gate.

## Things to AVOID

- `TypeVar`, `ParamSpec`, `TypeVarTuple` or `Generic[...]` declarations for a new generic.
- `TypeAlias`; an alias written as a plain assignment (`Ident = int`), which the gate does not see.
- `Optional`, `Union`, `List`, `Dict`, `Tuple`, or an ABC imported from `typing`.
- An override with no `@override`; `@override` on a method that overrides nothing.
- A `match` over an enum or union that ends without `case _: assert_never(...)`.
- A bare `case _:` that handles "everything else" for a closed set.
- `TypeGuard` where `TypeIs` expresses the same narrowing.
- `from __future__ import annotations` or a quoted forward reference at a 3.14 floor.
- A name introduced after the floor, imported from `typing`.

## Reviewer checklist

Reject the change if:

- A new generic uses `TypeVar`/`Generic`, or an alias uses `TypeAlias` (the gate also fails it;
  review rejects a `# noqa: UP040`, `UP046` or `UP047` that hides it), or an alias is a plain
  assignment (`Ident = int`) rather than a `type` statement. The gate does not see the last.
- A `match` over a union or enum has no closing `case _: assert_never(...)`, or its wildcard case
  does anything else. The gate does not see the omission.
- A method overrides without `@override`, or a file disables `explicit-override` for itself.
- A narrowing function returns `TypeGuard` at a floor of 3.13 or later and `TypeIs` could express it.
- The floor is 3.14 or later and the change adds `from __future__ import annotations`. The gate does
  not see it.
- Below a 3.14 floor, a forward reference is bare: no quotes, no `from __future__ import
  annotations`, not a `type` alias. The gate also fails it.
- A function has an unannotated parameter or return, or an unparameterised generic.
