# Python — Errors

How a project defines, raises, chains and catches exceptions. The bar: one project exception
hierarchy rooted in `Exception`; every `raise` inside an `except` carries a `from` clause; no bare
and no catch-all `except` outside an isolation point; `except*` wherever the code can receive an
exception group.

Each rule below says whether a gate step enforces it (naming the step and rule code) or review holds
it. Gate commands live in `../SKILL.md` § Definition of Done; this file does not restate them.

**Evidence.** Behaviour claims were observed on 2026-10-30 with uv 0.13.6, ruff 0.17.3, mypy 2.4.1
and pytest 9.2.0 on CPython 3.12.16, in a project carrying the `strict-quality.md` baseline whose
five gate commands exit `0` before the defect is added, and are marked *observed*. Sources were
fetched with `curl -sS -L` on 2026-10-30 from URLs that track each project's default branch; the
`:<line>` after a URL is the line in that fetched copy, so the live text can have moved since. Ruff
rule text is what `uvx ruff@0.17.3 rule <CODE>` prints.

## What the gate enforces and what review holds

| Rule | Held by | Observed result |
|---|---|---|
| `raise` inside `except` or `except*` has a `from` clause | gate: `ruff check`, `B904` | plain `raise ParseError` in `except ValueError` and in `except*` flagged; `from exc` and `from None` pass |
| No bare `except:` | gate: `ruff check`, `E722`; review for a bare `except:` whose body only re-raises | flagged, except a body of bare `raise` (exit `0`, *observed*) |
| No `except Exception`, `except BaseException`, or a tuple holding either | gate: `ruff check`, `BLE001` | flagged unless the handler re-raises, calls `logger.exception`, or calls `logger.error(…, exc_info=True)` (which draws `G201` instead) |
| No `except …: pass`; a narrow failure is ignored only through `contextlib.suppress(<specific exception>)` with a comment saying why it is safe | gate for the catch-all: `ruff check`, `S110` and `SIM105` (plus `BLE001`); review for the narrow case | `except Exception: pass` flagged by all three; `except ValueError: pass` flagged by `SIM105` only; `contextlib.suppress(ValueError)` with a comment passed every step |
| Exception names end in `Error` | gate: `ruff check`, `N818` | `class Parse(Exception)` flagged |
| Raised objects derive from `BaseException` | gate: `mypy --strict .`, `[misc]` | `raise NotAnException()` flagged |
| No `assert` for validation in library code | gate: `ruff check`, `S101` | flagged in `src/`; the baseline exempts `tests/**` |
| Message text lives in the exception class | gate: `ruff check`, `TRY003` | flagged for every multi-word message written at the `raise` site that was tried |
| No `raise Exception(…)`; `TypeError` for a wrong type | gate: `ruff check`, `TRY002`, `TRY004` | both flagged |
| `return` in a `try` goes in `else`; no `raise` inside the `try` it would catch | gate: `ruff check`, `TRY300`, `TRY301` | both flagged |
| `raise e` → `raise`; no handler that only re-raises | gate: `ruff check`, `TRY201`, `TRY203` | both flagged |
| `logger.exception`, not `logger.error`, inside a handler | gate: `ruff check`, `TRY400` (and `G201`, a Ruff default rule, for `error(…, exc_info=True)`) | both flagged |
| Mixed `except`/`except*`, bare `except*:`, `return`/`break`/`continue` in `except*`, `except* ExceptionGroup` | gate: the parser and `mypy`; `ruff check` and `pytest` for some | see Exception groups |
| A project exception hierarchy with one base class | review | no step checks it |
| No repetition in exception names (`foo.FooError`) | review | `N818` checks the suffix only |
| A small `try` body | review | no stable rule; `PLW0717` is preview-only |
| `contextlib.suppress(Exception)` is a catch-all too | review | every gate step exits `0` |
| `except*` for exception groups, `except` never aimed at a group | review | every gate step exits `0` when `except ValueError` surrounds a `TaskGroup` |
| `from exc` versus `from None` | review | the gate accepts both |

## A project exception hierarchy

- **Define one base exception per package and derive every other project exception from it**
  (held by review). Callers then catch the package's failures with a single `except`, and
  anything not derived from it is a bug, not a handled failure. The base derives from `Exception`:
  "Exceptions should typically be derived from the `Exception` class, either directly or
  indirectly" (`https://raw.githubusercontent.com/python/cpython/main/Doc/tutorial/errors.rst`
  :369-370), and Google 2.4.4 requires that a library's own exceptions "must inherit from an existing
  exception class"
  (`https://raw.githubusercontent.com/google/styleguide/gh-pages/pyguide.md` :418-420). Never derive
  from `BaseException`: the tutorial says exceptions outside `Exception` "are not typically handled,
  because they are used to indicate that the program should terminate" (`errors.rst` :186-192).
- **Mypy enforces the root** (*observed*): `raise NotAnException()` for a class with no exception
  base printed `Exception must be derived from BaseException  [misc]` and exited `1`.
- **Names end in `Error` and do not repeat the package** (`pyguide.md` :419-420: "Exception names
  should end in `Error` and should not introduce repetition (`foo.FooError`)"; `errors.rst` :376-377).
  `N818` enforces the suffix: `class Parse(Exception)` printed ``Exception name `Parse` should be named
  with an Error suffix`` (*observed*). The repetition half is held by review.
- **Use a built-in where one fits.** `pyguide.md` :354-356: "raise a `ValueError` to indicate a
  programming mistake like a violated precondition". Add a project exception when callers need to
  tell the failure apart from any other `ValueError`.
- **The exception owns its message** (gate: `TRY003`). A multi-word message written at the
  `raise` site failed `ruff check`, for a built-in and for a project exception alike
  (*observed*): `raise ValueError(f"bad value {x}")`, `raise ParseError("value is negative")` and
  `raise ValueError("not an int")` each printed `TRY003 Avoid specifying long messages outside the
  exception class`. Passing forms (*observed*): a project exception whose `__init__` builds the
  message; the message bound to a name first (`msg = f"bad value {x}"` then `raise ValueError(msg)`);
  a one-word literal (`raise ValueError("negative")`); `raise NotImplementedError("not done yet")`,
  which Ruff documents as exempt.
- **This is stricter than Google 2.4.** The example at `pyguide.md` :386 raises `ValueError(f'Min.
  port must be at least 1024, not {minimum}.')` at the raise site; under the baseline that line
  printed `TRY003` (*observed*). The baseline governs: write the message into the exception class,
  or bind it to a name first.
- **Document in `Raises:` only the exceptions the caller may rely on.** `pyguide.md` :383-385 leaves
  the precondition `ValueError` out of the docstring "because it is not appropriate to guarantee this
  specific behavioral reaction to API misuse". See `docstring-discipline.md` for the docstring rules.
- **Validate with a raised exception, not `assert`.** `pyguide.md` :358-361: "Do not use `assert`
  statements in place of conditionals or validating preconditions"; the litmus test is that the
  `assert` "could be removed without breaking the code". `S101` flags `assert` in `src/`
  (*observed*: ``Use of `assert` detected``). The baseline exempts `tests/**`, where pytest relies on it.

## Chaining: `raise … from` inside `except`

- **Every `raise` inside an `except` or `except*` handler carries `from`** (gate: `ruff check`,
  `B904`). The row for `raise ValueError(raw)` inside `except ValueError:` is in `strict-quality.md`
  § What the baseline catches. Here, plain `raise ParseError` in `except ValueError` printed ``B904
  Within an `except` clause, raise exceptions with `raise ... from err` or `raise ... from None` to
  distinguish them from errors in exception handling``, and the same statement in an `except*` handler printed the `except*` variant of the message; both
  forms `from exc` and `from None` passed (*observed*).
- **What `from` sets.** PEP 3134: `raise EXCEPTION from CAUSE` "is equivalent to" setting
  `exc.__cause__ = CAUSE` and raising (`https://raw.githubusercontent.com/python/peps/main/peps/pep-3134.rst`
  :217-225). Without it the interpreter chains implicitly through `__context__` and prints "During
  handling of the above exception, another exception occurred"; with it the traceback says "The
  above exception was the direct cause of the following exception" (`errors.rst` :295-345). Observed
  attributes on a `ValueError` handled and replaced by a project exception:

  | Statement in the handler | `__cause__` | `__context__` | `__suppress_context__` |
  |---|---|---|---|
  | `raise E('…')` | `None` | the `ValueError` | `False` |
  | `raise E('…') from exc` | the `ValueError` | the `ValueError` | `True` |
  | `raise E('…') from None` | `None` | the `ValueError` | `True` |

- **Choose `from exc` when the original failure helps whoever debugs the new one**, which is the
  usual case when translating a lower-level exception into a project exception (PEP 3134
  :234-248 shows exactly that). **Choose `from None` only when the original is an implementation
  detail the caller must not see** (`errors.rst` :347-361: "disabling automatic exception chaining").
  The gate accepts both, so the choice is held by review.
- **Re-raise with a bare `raise`, never `raise e`** (`TRY201`), and do not write a handler whose
  only job is to re-raise (`TRY203`): `except Exception: raise` printed `TRY203 Remove exception
  handler; error is immediately re-raised` (*observed*).

## No bare or catch-all `except`

- **`except:` fails** (gate: `ruff check`, `E722`): ``E722 Do not use bare `except` `` (*observed*,
  exit `1`). Google 2.4.4 gives the reason: `except:` "will really catch
  everything including misspelled names, sys.exit() calls, Ctrl+C interrupts, unittest failures"
  (`pyguide.md` :422-433).
- **`except Exception`, `except BaseException` and a tuple containing either fail** (gate: `ruff
  check`, `BLE001`; *observed* for all three). `except Exception: pass` printed `BLE001`, `S110` and
  `SIM105` together. `errors.rst` :195-197 gives the rule: "it is good practice to be as specific as
  possible with the types of exceptions that we intend to handle, and to allow any unexpected
  exceptions to propagate on".
- **Catch the narrowest type the `try` body can raise**, and let anything else propagate.
- **Ignore a narrow failure only through `contextlib.suppress(<specific exception>)`, with a comment
  saying why the failure is safe to ignore** (held by review). `except ValueError: pass` printed
  `SIM105` and neither `S110` nor `BLE001`, and `SIM105`'s own rewrite, `with
  contextlib.suppress(ValueError):` under a comment, passed all five gate steps (*observed*). The gate
  therefore pushes the narrow case toward `suppress` but cannot tell a reasoned one from an
  unreasoned one, and a narrow `except …: pass` handler is never the accepted spelling.
- **The two shapes `BLE001` accepts match Google's two exceptions** (`pyguide.md` :422-429:
  "re-raising the exception, or creating an isolation point … where exceptions are not propagated but
  are recorded and suppressed"). Observed to pass: a handler ending in a bare `raise` (but see
  `TRY203` above if that is all it does), `raise WrapError from exc`, and `logger.exception(…)`.
  Observed to fail: `logger.error(…)` (`BLE001` and `TRY400`) and `logger.error(…, exc_info=True)`
  (`G201`; `BLE001` did not fire). `G201` is in Ruff's default rule set rather than the baseline's
  list (`ruff check --isolated --show-settings` lists `logging-exc-info (G201)` among the enabled
  rules, *observed*), so it holds without `G` in `extend-select`; a `select =` key would replace
  that default set and drop it (*observed*; see `strict-quality.md` § Reviewer checklist).
- **An isolation point records the failure with `logger.exception(…)`** and then suppresses. The
  outermost guard of a thread or task runner is the legitimate case. If a handler must stay a
  catch-all without that call, it carries `# noqa: BLE001 - <reason>`; the reason comment is review's
  (see `strict-quality.md` § Lint suppressions), and `RUF100` reports the suppression if it ever
  stops being needed. A reasoned `# noqa: BLE001 - outermost guard; …` raised no `RUF100` or `PGH004`
  (*observed*).
- **`contextlib.suppress(Exception)` is the same defect and no step flags it** (*observed*: every
  gate step exited `0` on `with contextlib.suppress(Exception): int("x")`). Review holds it to the
  same rule.
- **Keep the `try` body to the one call that can raise.** `pyguide.md` :435-438: the larger the body,
  "the more likely that an exception will be raised by a line of code that you didn't expect to raise
  an exception". The gate holds only the edges of this rule: `TRY300` flags a `return` in a `try`
  that has other statements before it ("Consider moving this statement to an `else` block"), and
  `TRY301` flags a `raise` caught by the same `try`. Ruff's rule for statement count, `PLW0717`, is
  preview-only (`uvx ruff@0.17.3 rule PLW0717`: "The `--preview` flag is required"), and a twelve-
  statement `try` body passed every step (*observed*). Review holds the length.
- **Clean up with `finally` or a `with` block** (`pyguide.md` :440-442; `errors.rst` tutorial
  "Defining Clean-up Actions"), not with duplicated code in each handler. Held by review.

## Exception groups: `except*`

An `ExceptionGroup` is what `asyncio.TaskGroup` raises when a task fails, and the way to "collect
multiple errors rather than raise the first exception" (`errors.rst` :519-526). PEP 654 is Final,
`Python-Version: 3.11` (`https://raw.githubusercontent.com/python/peps/main/peps/pep-0654.rst` :7,
:10), so `except*` is available at every floor the guideline permits.

- **Handle failures from a group with `except*`, not `except`.** A plain `except ValueError` around
  an `asyncio.TaskGroup` whose task raised `ValueError` did not match: the call raised `ExceptionGroup:
  unhandled errors in a TaskGroup (1 sub-exception)`, while the same code with `except* ValueError`
  caught it (*observed*, `python -I`). All five gate steps exited `0` on both versions, so the gate
  cannot tell them apart and review holds the rule.
- **`except*` matching is per exception, not per group.** "a single exception group can cause several
  `except*` clauses to execute, but each such clause executes at most once" (`pep-0654.rst` :554-556);
  unmatched members propagate on in a remaining group. A "naked" exception that matches is wrapped:
  `except* OSError` bound `ExceptionGroup('', (OSError(1),))` for a plain `raise OSError(1)` (*observed*;
  `pep-0654.rst` :668-683). Code in the handler reads `eg.exceptions`, not the exception itself.
- **Use `except` only to catch the group type itself**, for example to let a boundary translate any
  group into one project exception. `pep-0654.rst` :1046-1048: that works with `except`, and is
  ambiguous with `except*`.
- **Forms the language rejects, and which step reports them** (*observed*, CPython 3.12.16):

  | Source | CPython | `ruff check` | `mypy` |
  |---|---|---|---|
  | `except ValueError:` and `except* OSError:` on one `try` | `SyntaxError: cannot have both 'except' and 'except*' on the same 'try'` | `invalid-syntax` | `[syntax]` |
  | bare `except*:` | `SyntaxError` (compile: `expected one or more exception types`) | `invalid-syntax` | `[syntax]` |
  | `return` inside `except*` | `SyntaxError: 'break', 'continue' and 'return' cannot appear in an except* block` | no finding | `"return" not allowed in except* block  [misc]` |
  | `except* ExceptionGroup:` | `TypeError: catching ExceptionGroup with except* is not allowed. Use except instead.` when an `ExceptionGroup` raised in the `try` body reached the clause | no finding | `Exception type in except* cannot derive from BaseExceptionGroup  [misc]` |

  PEP 654 lists these forms at `pep-0654.rst` :1029-1084 ("Forbidden Combinations"). Each one failed
  `mypy --strict .`, so the gate rejects all four (*observed*); the mixed form and
  the `return` also stopped `pytest` at collection with the `SyntaxError` shown.
- **Set a result variable inside `except*` and `return` after the block**, since `return`, `break`
  and `continue` are disallowed in it (`pep-0654.rst` :1079-1084).
- **`raise` inside `except*` follows the chaining rule above** (`B904` applies, *observed*).

## Things to AVOID

- A second, unrelated exception base in the same package, or a project exception derived from
  `BaseException`.
- Raising `Exception`, `BaseException` or a bare class with no message to signal a project failure
  (`TRY002`).
- `except:`, `except Exception:` and `except BaseException:` outside a re-raise or an isolation
  point; the same through `contextlib.suppress(Exception)`.
- An empty handler (`pass`) that discards the failure with no record, and a
  `contextlib.suppress(<specific exception>)` with no comment saying why the failure is safe to
  ignore.
- `raise NewError(…)` inside `except` with no `from`.
- `raise e` where a bare `raise` is meant; a handler that only re-raises.
- `assert` for argument validation in library code.
- Messages formatted at the `raise` site when the exception class could own them.
- A `try` body holding more than the call that can raise.
- `return` or `break` inside `except*`; mixing `except` and `except*` on one `try`.
- An `except` clause aimed at the failures of a `TaskGroup`.

## Reviewer checklist

Reject the change if:

- Any gate command fails, or a suppression of `B904`, `E722`, `BLE001`, `S110`, `TRY*` or `S101`
  carries no reason comment.
- A new exception derives from `BaseException`, does not end in `Error`, repeats the package name,
  or does not descend from the package's base exception.
- A `raise` inside a handler chains with neither `from exc` nor `from None`, or `from None` hides a
  cause the caller needs.
- A catch-all handler is neither a re-raise nor an isolation point that records the failure, or the
  catch-all is spelled `contextlib.suppress(Exception)`.
- A narrow failure is ignored with an `except …: pass` handler, or with `contextlib.suppress(…)`
  that carries no comment saying why the failure is safe to ignore.
- A `try` body holds statements that cannot raise the caught type.
- Code receiving failures from a `TaskGroup` or other exception group uses `except` where `except*`
  is meant.
- A handler discards the original exception where it should keep it as the cause.
