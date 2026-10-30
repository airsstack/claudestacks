# Python — Strong Types (No Primitive Obsession)

**A public parameter or field that carries a domain meaning carries it in its type.** A bare `str`,
`int` or `bool` on a public API is presumed wrong unless the value is a universal scalar with no
domain semantics. The gate catches the swap of two distinct types and the positional `bool`; it does
not catch the bare `str` itself, nor a missing validation, so most of this file is held by review.

Python differs from the Rust rule (`rust-guidelines/references/strong-types.md`) in two ways that
change what a rule can promise: a `NewType` checks nothing at runtime, and `frozen=True` does not
freeze what a field holds. Both are shown below by probe, not asserted.

Cross-links: `typing.md` (a `match` over an enum closes with `assert_never`), `errors.md` (the
exception a failed validation raises), `docstring-discipline.md` (the `Raises:` and `Attributes:`
sections the examples carry), `strict-quality.md` (the baseline every probe ran on).

**Evidence.** Behaviour claims below were observed on 2026-10-30 with uv 0.13.6, ruff 0.17.3, mypy
2.4.1 and pytest 9.2.0 on CPython 3.12.16, and are marked *observed*. Each observation that names a
gate step was made on a fresh copy of a project carrying the baseline of `strict-quality.md`, on which
all five gate commands exited `0` before the change; the rule codes come from `ruff check --no-fix
--output-format concise`. Claims about what a document says give the file and line, fetched on
2026-10-30 with `curl -sS -L` from URLs that track a default branch, so the live text can have moved
since:

- `aliases.rst` — `https://raw.githubusercontent.com/python/typing/main/docs/spec/aliases.rst`
- `literal.rst` — `https://raw.githubusercontent.com/python/typing/main/docs/spec/literal.rst`
- `typing.rst` — `https://raw.githubusercontent.com/python/cpython/main/Doc/library/typing.rst`
- `dataclasses.rst` — `https://raw.githubusercontent.com/python/cpython/main/Doc/library/dataclasses.rst`
- `enum.rst` — `https://raw.githubusercontent.com/python/cpython/main/Doc/library/enum.rst`
- `pyguide.md` — `https://raw.githubusercontent.com/google/styleguide/gh-pages/pyguide.md`
- `fbt001.rs`, `up042.rs`, `plr2004.rs` — the rule documentation inside Ruff's source, under
  `https://raw.githubusercontent.com/astral-sh/ruff/main/crates/ruff_linter/src/rules/`:
  `flake8_boolean_trap/rules/boolean_type_hint_positional_argument.rs`,
  `pyupgrade/rules/replace_str_enum.rs`, `pylint/rules/magic_value_comparison.rs`

## The bar

Public APIs MUST:

1. **Give an identifier its own type** (`NewType`, or a class when it has an invariant) rather than
   `str` or `int`.
2. **Validate at construction**, not at the point of use, and let downstream code trust the type.
   The validating entry point is a function that returns the `NewType`, or a frozen dataclass's
   `__post_init__`.
3. **Model a closed set as an `Enum`, `StrEnum` or `Literal`**, never as bare strings compared
   against each other.
4. **Take a `bool` only as a keyword-only parameter**, or use a two-member enum when the call site
   needs a name or a third state may follow.

Google's guide asks that "When adding or modifying public APIs, include type annotations"
(`pyguide.md:1581-1582`); this file says what the annotation on a domain value should be. Google
also lists `dataclasses` and `enum` among the standard-library modules that are "okay to use" despite
the ban on power features (`pyguide.md:1430-1431`).

Where a rule below cites no source and no probe (when to introduce a type, which of the allowed
forms to pick), it is this guideline's policy and review holds it.

## `NewType` for identifiers

A `NewType` is a distinct type to the checker and nothing at runtime. The typing specification:
"While at runtime, `NewType('Derived', Base)` returns a dummy object that simply returns its argument
when called" (`aliases.rst:154-155`); the standard library: "calling a `NewType` returns its argument
unchanged" (`typing.rst:2538-2539`).

- **Use one for every identifier** (`UserId`, `OrderId`, `SessionId`). The checker then refuses a
  swap: two `NewType`s over `str`, one passed where the other is expected, failed
  `mypy --strict .` with exit `1` and ``Argument 1 to "cancel" has incompatible type "UserId";
  expected "OrderId"  [arg-type]`` (*observed*). `name_by_id(42)` failing the check while
  `name_by_id(UserId(42))` passes is the specification's own example (`aliases.rst:166-167`).
- **A `NewType` checks nothing, so it cannot carry an invariant.** `Port = NewType("Port", int)`
  followed by `Port(-5)` returned `-5`, and `type(Port(-5))` was `int` (*observed*). Where the value
  has an invariant, the constructor is a function that checks and then wraps:

  ```python
  """Identifier types."""

  from typing import NewType

  UserId = NewType("UserId", str)


  def parse_user_id(raw: str) -> UserId:
      """Check a raw string and mark it as a user id.

      Args:
          raw: The text to check.

      Returns:
          The same text, typed as a user id.

      Raises:
          ValueError: If `raw` is empty.

      Examples:
          >>> parse_user_id("u-1")
          'u-1'
          >>> parse_user_id("")
          Traceback (most recent call last):
              ...
          ValueError: user id is empty
      """
      if not raw:
          msg = "user id is empty"
          raise ValueError(msg)
      return UserId(raw)
  ```

  This file passed all five gate commands with its test (*observed*). The rest of the code calls
  `parse_user_id` at the boundary; a bare `UserId(raw)` elsewhere skips the check, and no tool sees
  it, so review holds that.
- **A `NewType` is not a class.** `isinstance(p, Port)` raised `TypeError: isinstance() arg 2 must
  be a type, a tuple of types, or a union` (*observed*); the specification says the same:
  "`isinstance` and `issubclass`, as well as subclassing will fail" (`aliases.rst:190-192`). A value
  that needs an `isinstance` test, extra methods or a `__repr__` is a class, not a `NewType`.

### When NOT to introduce a type

- The value is a universal scalar at this layer: a count, an index, a buffer size.
- The type would have no invariant and no distinguishing method and has one use site. Wait for the
  second use.

## Frozen, slotted dataclasses that validate

A value with an invariant is a frozen, slotted dataclass whose `__post_init__` checks it. The
mechanism is documented: `__post_init__` is "called by the generated `__init__`"
(`dataclasses.rst:579-580`); `frozen=True` makes "assigning to fields … generate an exception"
(`dataclasses.rst:173-174`); `slots=True` makes the class generate `__slots__` (`dataclasses.rst:201`).

```python
"""Network ports."""

from dataclasses import dataclass
from typing import Final

MIN_PORT: Final = 1
MAX_PORT: Final = 65535


@dataclass(frozen=True, slots=True)
class Port:
    """A TCP or UDP port number.

    Attributes:
        number: The port number, 1 to 65535.

    Examples:
        >>> Port(8080).number
        8080
        >>> Port(0)
        Traceback (most recent call last):
            ...
        ValueError: port 0 is outside 1..65535
    """

    number: int

    def __post_init__(self) -> None:
        """Reject a number outside 1..65535.

        Raises:
            ValueError: If `number` is outside 1..65535.
        """
        if not MIN_PORT <= self.number <= MAX_PORT:
            msg = f"port {self.number} is outside 1..65535"
            raise ValueError(msg)
```

This passed all five gate commands with a test (*observed*). What each part buys, and who holds it:

- **`frozen=True`: assignment after construction is a type error.** `port.number = 1` failed
  `mypy --strict .` with ``Property "number" defined in "Port" is read-only  [misc]`` (*observed*).
- **Normalise with `object.__setattr__`, never `self.x = …`.** Inside a frozen class's
  `__post_init__`, `self.value = self.value.lower()` failed mypy with the same `[misc]` error and
  raised `FrozenInstanceError: cannot assign to field 'value'` when the test ran (*observed*).
  Python documents why: "`__init__` cannot use simple assignment to initialize fields, and must use
  `object.__setattr__`" (`dataclasses.rst:681-682`). The form that passed the gate:

  ```python
  def __post_init__(self) -> None:
      """Normalise `value` in place."""
      object.__setattr__(self, "value", self.value.strip().lower())
  ```
- **`slots=True`: held by review.** `@dataclass(frozen=True)` without `slots=True` passed all five
  gate commands (*observed*); only the slotted class lacks a `__dict__` (`hasattr(A(1), "__dict__")`
  was `False` with `__slots__ == ('n',)`, `True` without; *observed*).
- **The validation itself: held by review.** A `Port` with no `__post_init__` accepted `Port(-1)` and
  passed all five gate commands (*observed*). Every frozen value type with an invariant has a test
  that constructs an invalid value and expects the exception (`test-mandate.md`).
- **The bounds are named constants.** Comparing against the literal `65535` in `__post_init__`
  failed `ruff check --no-fix` with ``PLR2004 Magic value used in comparison, consider replacing
  `65535` with a constant variable`` (*observed*). Ruff exempts only a short list of values such as
  `0` and `1` (`plr2004.rs:23-25`), so a validated range needs `Final` constants.
- **`dataclasses.replace` re-runs the check; `object.__setattr__` bypasses it.** `replace(port,
  number=0)` raised `ValueError: port 0 is outside 1..65535`, because the new object is "created by
  calling the `__init__` method" and so `__post_init__` runs (`dataclasses.rst:493-495`, *observed*).
  `object.__setattr__(port, "number", 0)` from outside the class changed the value (*observed*).
  So a frozen class guards against accident, not against a caller who means to bypass it. Review
  rejects `object.__setattr__` outside a `__post_init__` that normalises.

### Field types must be immutable

`frozen=True` freezes the attribute binding and nothing else. Python's own documentation: "It is not
possible to create truly immutable Python objects. However, by passing `frozen=True` … you can
emulate immutability" (`dataclasses.rst:674-675`). A frozen dataclass with a `list[str]` field:

- `tags.names.append("b")` succeeded and the list grew (*observed*), while `tags.names = []` raised
  `FrozenInstanceError: cannot assign to field 'names'` (*observed*).
- `hash(tags)` raised `TypeError: unhashable type: 'list'` (*observed*): with `eq` and `frozen` both
  true `@dataclass` generates `__hash__` from the fields (`dataclasses.rst:165-167`), so a mutable
  field makes the "frozen" value unusable as a dict key or set member.
- With `names: tuple[str, ...]`, `append` raised `AttributeError: 'tuple' object has no attribute
  'append'` and `hash` returned an `int` (*observed*).
- **Held by review.** The list-field version passed all five gate commands, including a function that
  appended to the field (*observed*).

So a frozen dataclass field is `tuple[T, ...]`, `frozenset[T]`, another frozen value, or a scalar —
not `list`, `dict` or `set`. The caller converts at the boundary (`tuple(items)`).

## Closed sets: `StrEnum`, `Enum`, `Literal`

A set of values known in advance is a type, not a convention between strings.

- **`StrEnum` for a set of strings that crosses a boundary** (wire values, config values,
  command-line choices). `Color("red")` returned `Color.RED` and `Color("blue")` raised `ValueError:
  'blue' is not a valid Color` (*observed*): call syntax "return[s] members by value"
  (`enum.rst:27`), so one line parses untrusted input into the closed set. The members "are also
  strings" (`enum.rst:566`), so they pass where a `str` is expected and compare equal to the string
  (`Color.RED == "red"` was `True`, *observed*).
- **`Enum` for a set whose members need no string value**, or that carry behaviour.
- **`Literal[...]` for a small set that appears in one signature and has no behaviour.** A literal
  type "indicate[s] that a variable has a specific and concrete value" (`literal.rst:22-23`). It is
  erased at runtime: `open_in("x")` against `Literal["r", "w"]` returned `"x"` (*observed*), so a
  `Literal` is checked by mypy only, and a value arriving from outside is validated by an enum or a
  parse function first.
- **The checker enforces the set.** A call `open_in("x")` against `Literal["r", "w"]` failed
  `mypy --strict .` with ``Argument 1 to "open_in" has incompatible type "Literal['x']"; expected
  "Literal['r', 'w']"  [arg-type]``; `paint("red")` for a parameter of type `Color(StrEnum)` failed
  with ``Argument 1 to "paint" has incompatible type "str"; expected "Color"  [arg-type]`` (both
  *observed*, exit `1`).
- **Use `StrEnum`, not `class C(str, Enum)`.** The `str` mixin failed `ruff check --no-fix` with
  ``UP042 Class Color inherits from both `str` and `enum.Enum` `` (*observed*); Ruff's documentation:
  `StrEnum` "is preferred over inheriting from both `str` and `enum.Enum`" (`up042.rs:15-16`).
- **Do not repeat a value.** An `Enum` with `OPEN = 1` and `ACTIVE = 1` failed with ``PIE796 Enum
  contains duplicate value: `1` `` (*observed*); the second name would otherwise silently alias the
  first.
- **Iterate the set from the enum.** An enum "can be iterated over" (`enum.rst:25-26`), so
  `[c.value for c in Color]` gives the list of accepted values without a second copy.
- **Close every `match` over an enum with `assert_never`** (`typing.md`); the gate does not notice a
  missing member otherwise.

## `bool` parameters are keyword-only

Ruff documents why: a boolean positional argument "is confusing as the meaning of the boolean value
is not clear to the caller", and "will also limit the function to only two possible behaviors"
(`fbt001.rs:21-27`); the remedies it lists are separate functions, "an `Enum`, or making the argument
a keyword-only argument" (`fbt001.rs:28-30`). The gate enforces it in three places (each *observed*,
exit `1`):

| Code | Defect |
|---|---|
| `FBT001` | `def scale(value: int, negate: bool)` — a `bool`-annotated positional parameter |
| `FBT002` | `def scale(value: int, negate: bool = False)` — reports `FBT001` and `FBT002` |
| `FBT003` | `scale(1, True)` — a literal boolean passed positionally at the call site |

`def scale(value: int, *, negate: bool = False)` called as `scale(1, negate=True)` passed all five
gate commands (*observed*). Choose between the two forms the rule allows:

- **Keyword-only `bool`** when the parameter is a plain yes/no and the name reads at the call site.
- **A two-member enum** when the decision needs its own name, or a third case may follow: a `bool`
  fixes the function at two behaviours and makes it "difficult to extend" (`fbt001.rs:25-26`).
- **A `bool` return value or a `bool` field is not a parameter.** `def is_even(number: int) -> bool`
  and a frozen dataclass field `enabled: bool` passed all five gate commands (*observed*). A
  predicate that answers a yes/no question is fine; a `bool` field that records a decision between
  behaviours is the same smell as the parameter, and review holds it.
- Ruff exempts "dunder methods that define operators", setters and `@override` definitions
  (`fbt001.rs:33-34`, from the documentation only; not probed).

## What the gate sees and what review holds

| Rule | Held by | Evidence |
|---|---|---|
| Two `NewType`s not swapped | gate: mypy `arg-type` | *observed* |
| `Literal` / `StrEnum` value from the declared set | gate: mypy `arg-type` | *observed* |
| `bool` parameter keyword-only | gate: ruff `FBT001`, `FBT002`, `FBT003` | *observed* |
| `StrEnum`, not `str` + `Enum` | gate: ruff `UP042` | *observed* |
| No duplicate enum value | gate: ruff `PIE796` | *observed* |
| No assignment to a frozen field | gate: mypy `[misc]` (and pytest when run) | *observed* |
| Range bounds as named constants | gate: ruff `PLR2004` | *observed* |
| A domain value typed `str` or `int` instead of its own type | review | `cancel(user_id: str, order_id: str)` called with the arguments swapped passed all five gate commands (*observed*) |
| Validation present in the constructor | review | `Port` without `__post_init__` passed (*observed*) |
| `slots=True` | review | `@dataclass(frozen=True)` passed (*observed*) |
| Field types immutable | review | `list[str]` field mutated in a function passed (*observed*) |
| `parse_user_id` used instead of a bare `UserId(raw)` | review | `NewType` call checks nothing (*observed*) |
| `object.__setattr__` only to normalise | review | bypass works (*observed*) |

## Things to AVOID

- Public signatures with bare `str` or `int` for an identifier or a bounded number.
- `UserId = NewType("UserId", str)` used as if it validated; call a checking function.
- `@dataclass` without `frozen=True, slots=True` for a value type.
- A `list`, `dict` or `set` field on a frozen dataclass.
- `self.x = …` in a frozen `__post_init__`; use `object.__setattr__`.
- `class C(str, Enum)` and enum members that repeat a value.
- Closed sets written as string constants compared with `==`.
- A positional `bool` parameter.
- Re-validating inside library functions what the constructor already validated.

## Reviewer checklist

In addition to the `strict-quality.md` checklist, reject the change if:

- A new public parameter or field holds a domain value as a bare `str`, `int` or `float`.
- A new identifier is a `str` or a `NewType` whose invariant is not checked anywhere.
- A new value type with an invariant has no validation in `__post_init__` or a parse function, or has
  no test that builds an invalid value.
- A new frozen dataclass lacks `slots=True`, holds a mutable field type, or calls
  `object.__setattr__` for anything but normalisation.
- A new closed set is a run of string constants, a `(str, Enum)` class, or an `Enum` that repeats a
  value.
- A new `bool` parameter is positional.
