# Python — Protocols and Composition

How a Python module depends on behaviour it does not own. Choose the lightest abstraction that
works, in a fixed order, and prefer holding an object over inheriting from one. The type checker
enforces the shape of a dependency; it does not enforce which abstraction you picked, so most of the
choosing is held by review.

Counterpart of the Rust `static-dispatch.md`, with a different reason. The Rust rule ranks
abstractions by dispatch cost (a vtable indirection for `Box<dyn Trait>`). That reason does not carry
over: PEP 544 states that "No runtime semantics will be imposed for variables or parameters
annotated with a protocol class" (`pep-0544.rst:102-103`), so choosing a concrete class, an ABC or
a `Protocol` as a parameter's annotation does not change how the call runs. What differs between the
options is **coupling**: what an implementer must import or inherit, what a consumer must know, and
how much a change to one forces on the other. The ranking below is by coupling.

**Evidence.** Behaviour claims below were observed on 2026-10-30 with uv 0.13.6, ruff 0.17.3, mypy
2.4.1 and pytest 9.2.0 on CPython 3.12.16, and are marked *observed*. Each observation that names a
gate step was made on a copy of a project carrying the baseline of `strict-quality.md`, on which all
five gate commands exited `0` before the change. Documentation claims give the source line and the
quoted words, fetched on 2026-10-30 with `curl -sS -L` from URLs that track each project's default
branch, so the live text can have moved since: `protocol.rst` is
`https://raw.githubusercontent.com/python/typing/main/docs/spec/protocol.rst`, `pep-0544.rst` is
`https://raw.githubusercontent.com/python/peps/main/peps/pep-0544.rst`, `abc.rst` and `typing.rst`
are `https://raw.githubusercontent.com/python/cpython/main/Doc/library/<name>.rst`, and `pyguide.md`
is `https://raw.githubusercontent.com/google/styleguide/gh-pages/pyguide.md`.

## The rule

When code needs behaviour from something it does not define, choose in this order and stop at the
first that fits:

1. **A concrete type.** One real implementation: depend on it directly. A `Protocol` written for a
   single implementation adds a name and a file and removes no coupling. *Held by review*: a
   `Protocol` with one implementation and no test double passed all five gate commands (*observed*).
2. **A callable.** The dependency is one behaviour: take `Callable[[int], str]` from
   `collections.abc`. mypy checks the callback's signature: passing a `Callable[[str], str]` where
   `Callable[[int], str]` is expected exited `1` with `Argument 1 to "apply" has incompatible type
   "Callable[[str], str]"; expected "Callable[[int], str]"  [arg-type]` (*observed*), so this is
   *gate-enforced*. When the callback needs keyword, variadic or overloaded parameters, use a
   callback protocol instead: "``Callable`` cannot express complex signatures such as functions that
   take a variadic number of arguments, overloaded functions, or functions that have keyword-only
   parameters. However, these signatures can be expressed by defining a ``Protocol`` class with a
   ``__call__`` method" (`typing.rst:252-257`; also `pep-0544.rst:626-627`). Assigning
   `bad_cb(*values, maxitems=None)` to a protocol whose `__call__` takes `maxlen` exited `1` with
   `Incompatible types in assignment … [assignment]` (*observed*).
3. **A `Protocol` at a module boundary.** More than one implementation is genuinely expected (the
   production one and a test double count), and the implementers should not have to import the
   consumer's module. Define the `Protocol` next to the code that consumes it, not next to an
   implementation. "So while it's possible to subclass a protocol explicitly, it's *not necessary* to do
   so for the sake of type-checking" (`protocol.rst:146-147`), so an implementer names nothing from
   the consumer. mypy checks the match: a class missing one protocol member, passed where the
   protocol is expected, exited `1` with `Argument 1 to "render" has incompatible type "Circle";
   expected "Drawable"` and the note `"Circle" is missing following "Drawable" protocol member:
   area` (*observed*), so this is *gate-enforced*. Where the protocol lives and whether a second
   implementation exists are *held by review*.
4. **An ABC, only to share implementation.** Concrete methods built on a few abstract ones, so each
   subclass writes only the abstract part. "An ABC can be subclassed directly, and then acts as a
   mix-in class" (`abc.rst:55-56`). The standard library's own example is
   `collections.abc.MutableMapping`: a class that defined `__getitem__`, `__setitem__`, `__delitem__`,
   `__iter__` and `__len__` and nothing else got `update` and `setdefault` that both went through its
   own `__setitem__` (`UpperMap` upper-cased the value on `b.update(k="v")` and on
   `c.setdefault("k", "v")`; the gate was green, *observed*). Two gate rules keep an ABC honest:
   Ruff `B024` (an ABC with no abstract method) and `B027` (an empty method in an ABC without
   `@abstractmethod`) both fired, exit `1` (*observed*); and instantiating a subclass that left an
   abstract method unimplemented exited `1` in mypy with `Cannot instantiate abstract class "Square"
   with abstract attribute "area"  [abstract]` and raised `TypeError: Can't instantiate abstract
   class Square without an implementation for abstract method 'area'` at runtime (*observed*). An
   ABC used only as an interface, with nothing shared, is a `Protocol` (step 3) that costs every
   implementer an import and a base class.

A comment or docstring on a new abstraction names the second implementation (or the test double) that
justifies it. "For flexibility" justifies nothing.

### What the three checked steps look like

```python
"""Report publishing; the consumer owns the ``Sink`` protocol."""

from typing import Protocol


class Sink(Protocol):
    """Where a finished report goes."""

    def write(self, text: str) -> None:
        """Store one report.

        Args:
            text: The report body.
        """
        ...


def publish(sink: Sink, text: str) -> None:
    """Send a report to a sink.

    Args:
        sink: Where the report goes.
        text: The report body.
    """
    sink.write(text.strip())
```

Saved as `src/base/reports.py`, this file passed `ruff format --check` and `ruff check --no-fix`
(both exit `0`). With a `FileSink` in its own module (importing nothing from `reports.py`) and a
`ListSink` test double in `tests/`, each with a test, both satisfying `Sink` without naming it, all
five gate commands exited `0` (*observed*).

## Composition over inheritance

Hold the object you want to reuse as an attribute; subclass only when the language, a framework or an
ABC (step 4) asks you to. This is the guideline's policy, held by review; three points support it.

- **Overriding a built-in container's method does not change the other paths into it.** `UpperDict`
  subclassed `dict[str, str]` and overrode `__setitem__` with `@override` to upper-case the value.
  `a["k"] = "v"` gave `{'k': 'V'}`, but `UpperDict(k="v")`, `.update(k="v")` and
  `.setdefault("k", "v")` each gave `{'k': 'v'}`, and all four gate steps exited `0` (*observed*).
  The fix is the ABC route above (`MutableMapping`, whose mixin methods call your `__setitem__`) or an
  attribute plus the methods you want. Do not subclass `dict`, `list`, `set` or `str` to change what
  they do.
- **Multiple inheritance from an ABC risks a metaclass conflict.** "inheriting from ABC requires the
  usual precautions regarding metaclass usage, as multiple inheritance may lead to metaclass
  conflicts" (`abc.rst:37-39`).
- **Overridable behaviour is hard to read.** Google's guide warns about properties: "Inheritance
  with properties can be non-obvious" (`pyguide.md:1078`). Extending that to any method a subclass
  is meant to extend is this guideline's own reasoning, not Google's: the base class's call order
  becomes part of its interface.

Subclassing the language requires (exceptions, `Enum`, `NamedTuple`, `TypedDict`) or a library
documents as its extension point is outside this rule. `@override` on every override is required
(`typing.md`); mypy rejects a missing one under the baseline's `explicit-override`.

## `@runtime_checkable`: presence only, never signatures

A `Protocol` is a static concept. "The default semantics is that ``isinstance()`` and
``issubclass()`` fail for protocol types" (`protocol.rst:597-598`), and
`@runtime_checkable` is the opt-in. What it checks is narrow: such protocols "check only the presence
of given attributes, ignoring their type signatures" (`typing.rst:2586-2587`) and the decorator "will
check only the presence of the required methods or attributes, not their type signatures or types"
(`typing.rst:2651-2653`).

- **Never use `isinstance` against a `@runtime_checkable` protocol to establish that a call is valid.**
  A `Closer` protocol with `close(self) -> None` and a `WrongSignature` class whose
  `close(self, force: int, reason: str)` needs two arguments: `isinstance(WrongSignature(), Closer)`
  was `True`, and then `.close()` raised `TypeError: WrongSignature.close() missing 2 required
  positional arguments: 'force' and 'reason'`; all four gate steps exited `0` on the module
  (*observed*). Nothing in the gate notices the misuse, so it is *held by review*.
- **Using `isinstance` against a protocol that lacks the decorator is a gate failure.** mypy exited
  `1` with `Only @runtime_checkable protocols can be used with instance and class checks  [misc]`
  and, at runtime, `TypeError: Instance and class checks can only be used with @runtime_checkable
  protocols` (*observed*). `pep-0544.rst:96-98` states the intent: "There is no intent to provide
  sophisticated runtime instance and class checks against protocol classes."
- **Where a presence check is the real requirement** (an optional capability on an object you do not
  control), `@runtime_checkable` is allowed, with a comment saying the check is presence only and
  where the signature is verified. The decorator is not inherited: "A subclass of a runtime-checkable
  protocol is only runtime-checkable if it is explicitly marked as such" (`typing.rst:2635-2636`), and
  Python 3.15 deprecates `isinstance` on an undecorated subclass of one, to raise `TypeError` in 3.20
  (`typing.rst:2608-2611`). Decorate every protocol you use with `isinstance`.
- `isinstance` against a runtime protocol "can be surprisingly slow compared to an ``isinstance()``
  check against a non-protocol class"; the documentation suggests `hasattr` for structural checks in
  performance-sensitive code (`typing.rst:2662-2666`).
- To pick between known alternatives, use a union and a `match` closed by `assert_never`
  (`typing.md`), not a chain of runtime protocol checks.

## Things to AVOID

- A `Protocol` or ABC with one implementation and no test double.
- An ABC that shares nothing: no concrete method built on its abstract ones (`B024`, `B027` fire on
  the clear cases).
- Defining the `Protocol` beside an implementation, so the consumer imports a module it only needs a
  shape from.
- Subclassing `dict`, `list`, `set` or `str` to change behaviour.
- `isinstance` against a `@runtime_checkable` protocol as a substitute for the type checker.
- Explaining a new abstraction as "flexibility" or "in case we swap it".

## What the gate sees, and what review holds

| Rule | Gate | Observed |
|---|---|---|
| Missing protocol member at a call site | `mypy --strict .` | exit `1`, `[arg-type]` |
| Wrong callback signature | `mypy --strict .` | exit `1`, `[arg-type]` / `[assignment]` |
| Subclass leaves an abstract method unimplemented | `mypy --strict .` | exit `1`, `[abstract]` |
| ABC with no abstract method / empty hook | `ruff check --no-fix` | exit `1`, `B024` / `B027` |
| `isinstance` on a non-runtime protocol | `mypy --strict .` | exit `1`, `[misc]` |
| `isinstance` on a runtime protocol with a wrong signature | none | every step exit `0` |
| `Protocol` with one implementation | none | every step exit `0` |
| `dict` subclass overriding one method | none | every step exit `0` |

## Reviewer checklist

Reject the change if:

- A new `Protocol` or ABC has one implementation and no test double, or its justification is
  "flexibility".
- A `Protocol` is defined in the implementer's module rather than the consumer's.
- A callback `Protocol` stands where `Callable[...]` expresses the signature: the documentation lists
  what `Callable` cannot express (`typing.rst:252-257`), and nothing else needs the protocol.
- `isinstance` against a `@runtime_checkable` protocol guards a call whose signature matters, or the
  check carries no comment saying it is presence only.
- A class subclasses a built-in container to change its behaviour.
- A new class inherits to reuse code that an attribute would reuse.
