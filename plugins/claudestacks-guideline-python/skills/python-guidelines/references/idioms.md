# Python — Idioms

Five places where Python's easy spelling is the wrong one: mutable default arguments, `os.path`
string handling, text I/O with no `encoding=`, `print` in library code, and `asyncio.gather` where a
`TaskGroup` belongs. Each rule below says whether a gate step enforces it (naming the step and the
Ruff code) or review holds it, and for the held ones it says what the gate does instead of catching
them.

**Evidence.** Behaviour claims below were observed on 2026-10-30 with uv 0.13.6, ruff 0.17.3, mypy
2.4.1 and pytest 9.2.0 on CPython 3.12.16, and are marked *observed*. Each observation that names a
gate step was made on a fresh copy of a `uv init --lib --python 3.12` project (package `base`, one
module with a doctest, one test) carrying the baseline of `strict-quality.md`, on which all five
gate commands exited `0` before the change. Rule text quoted from Ruff comes from `uvx ruff@0.17.3
rule <CODE>`. Claims about what a document says give the file and line, fetched on 2026-10-30 with
`curl -sS -L`: `pyguide.md` is
`https://raw.githubusercontent.com/google/styleguide/gh-pages/pyguide.md`; `py312/…` is
`https://raw.githubusercontent.com/python/cpython/3.12/Doc/…` (the floor of a library, so the text
that applies to it); `pymain/…` is the same under `…/cpython/main/Doc/…`, used only where the 3.12
text lacks the passage; `pep-0686.rst` is
`https://raw.githubusercontent.com/python/peps/main/peps/pep-0686.rst`. Branch URLs move, so the
live text can have changed since.

## No mutable default arguments

A default value is evaluated once, when the function is defined, and every call that omits the
argument receives that same object. Use `None` and build the object in the body, or use an immutable
default such as `()`.

```python
def collect(items: list[int] | None = None) -> list[int]:
    if items is None:
        items = []
    items.append(1)
    return items
```

- **The rule is Google 2.12.4**: "Do not use mutable objects as default values in the function or
  method definition" (`pyguide.md:979`), with `b=None` and `b: Sequence = ()` as the accepted forms
  and `b=[]`, `b=time.time()` and `b: Mapping = {}` as the rejected ones (`pyguide.md:988-1008`). The
  stated cost: "Default arguments are evaluated once at module load time" (`pyguide.md:965`).
- **Why it bites** (*observed*): `def collect(x: list[int] = [])` appending `1`, called twice with no
  argument, returned `[1, 1]` both times, `a is b` was `True`, and `collect.__defaults__` held
  `([1, 1],)`.
- **Enforced by the gate: `ruff check`, `B006`.** The probe above, alone in a fresh copy, failed
  step 3 with `src/base/defaults.py:4:28: B006 Do not use mutable data structures for argument
  defaults` and left steps 1, 2, 4 and 5 at `0` (*observed*). A `dict[str, int] = {}` default and a
  `set[int] = set()` default were reported the same way; `Sequence[int] = ()` and `list[int] | None =
  None` were not (*observed*).
- **Enforced by the gate: a dataclass field.** `bad: list[int] = []` in a `@dataclass` was reported
  as `RUF008 Do not use mutable default values for dataclass attributes` at step 3, and step 5 also
  failed at collection with `ValueError: mutable default <class 'list'> for field bad is not
  allowed: use default_factory` (*observed*). Write `field(default_factory=list)`.
- **Held by review: a mutable default behind an immutable annotation.** Ruff documents that
  "Arguments with immutable type annotations will be ignored by this rule" (`ruff rule B006`; `B008`
  says the same). All five gate commands exited `0` with `a: Mapping[str, int] = {}`,
  `a: Sequence[int] = []` and `a: float = time.time()` (*observed*). Google rejects the first form
  (`pyguide.md:1007`: "Could still get passed to unchecked code") and the third (`pyguide.md:1003`).
  The annotation does not make the default safe, so review rejects these exactly as it rejects
  `list[int] = []`.

## `pathlib` over `os.path`

Filesystem paths are `Path` objects. Do not build, split or test a path with `os.path.*`, and do not
reach for `os.getcwd`, `os.listdir`, `os.makedirs`, `os.remove`, `os.rename`, `os.stat`,
`glob.glob` or a builtin `open(path)`; each has a `Path` equivalent.

- **The mapping is the standard library's own**: `pathlib` documents a table from `os.path.dirname`
  to `PurePath.parent`, `os.path.join` to `PurePath.joinpath`, `os.path.exists` to `Path.exists`,
  `os.getcwd` to `Path.cwd`, `os.listdir` to `Path.iterdir`, `os.walk` to `Path.walk`, `os.makedirs`
  to `Path.mkdir`, `os.remove` to `Path.unlink` and others (`py312/library/pathlib.rst:1522-1564`).
  `Path.walk` is new in 3.12 (`py312/library/pathlib.rst:1337`), so it is available at both floors.
- **Enforced by the gate: `ruff check`, the `PTH` codes.** Each call below, planted in a function
  of its own in one file of a fresh copy, was reported at step 3, and steps 1, 2, 4 and 5 stayed at
  `0` (*observed*):

  | Call | Code |
  |---|---|
  | `os.path.abspath` | `PTH100` |
  | `os.makedirs` | `PTH103` |
  | `os.rename` | `PTH104` |
  | `os.remove` | `PTH107` |
  | `os.getcwd` | `PTH109` |
  | `os.path.exists` | `PTH110` |
  | `os.path.expanduser` | `PTH111` |
  | `os.path.isfile` | `PTH113` |
  | `os.stat` | `PTH116` |
  | `os.path.join` | `PTH118` |
  | `os.path.basename` | `PTH119` |
  | `os.path.dirname` | `PTH120` |
  | `os.path.splitext` | `PTH122` |
  | builtin `open(path, "rb")` | `PTH123` |
  | `glob.glob` | `PTH207` |
  | `os.listdir` | `PTH208` |

  `return os.path.join(root, "config.toml")` on its own failed step 3 with `PTH118 os.path.join()
  should be replaced by Path with / operator` (*observed*).
- **Held by review: the calls with no `PTH` rule.** `os.walk` (use `Path.walk`), `shutil.rmtree` and
  `os.environ` lookups were not reported (*observed*). `os.environ` is not a path operation and
  stays; `os.walk` is the one review rejects.
- **`pathlib` is not a drop-in replacement, and the exceptions are documented.** It has no `bytes`
  paths and no paths relative to a directory descriptor, and it normalises `Path("my_folder/")` to
  `Path("my_folder")` and `Path("./my_program")` to `Path("my_program")`, which changes the meaning
  of the path to an OS call or an executable search (`pymain/library/pathlib.rst:1901-1937`). On
  CPython 3.12.16 these held: `str(Path('my_folder/'))` was `my_folder`, `str(Path('./my_program'))`
  was `my_program`, `Path(b'bytes')` raised `TypeError`, `os.path.join(b'a', b'b')` returned
  `b'a/b'`, and `os.path.abspath('a/../b')` collapsed to `/b` where `Path('a/../b').absolute()` kept
  `/a/../b` (*observed*).
- **Where `os.path` is genuinely required, suppress the one line.** `# noqa: PTH118 - <reason>` with
  the code and the reason, as `strict-quality.md` § Lint suppressions requires. A trailing reason
  after the code was accepted by Ruff and the line was not reported (*observed*, with `T201`).

## Text I/O names its `encoding=`

Every call that opens text — `Path.read_text`, `Path.write_text`, `Path.open` and `open` in a text
mode, `io.TextIOWrapper`, `tempfile.NamedTemporaryFile` in a text mode, `subprocess.run(text=True)`
— passes `encoding=`, `"utf-8"` unless the format says otherwise. Binary modes need none.

- **The default is the machine's locale on both floors.** "The default encoding of `TextIOWrapper`
  and `open` is locale-specific" and "it is highly recommended that you specify the encoding
  explicitly when opening text files" (`py312/library/io.rst:114-115`, `:126-129`). The UTF-8
  default arrives with Python 3.15 (`pep-0686.rst:5` `Status: Final`, `:8` `Python-Version: 3.15`;
  `pymain/library/io.rst:121`, `:132`), after both the 3.12 and 3.14 floors, so the rule holds at
  both.
- **Why it bites** (*observed*): with the file `b'caf\xc3\xa9'` written as UTF-8, `Path.read_text()`
  returned `'caf\xe9'` under a UTF-8 locale and `'caf\xc3\xa9'` under `LC_ALL=en_IE.ISO8859-1` with
  `-X utf8=0`, with no error in either case; `read_text(encoding='utf-8')` returned `'caf\xe9'` in
  both. The same file read cleanly on one machine and as mojibake on the next.
- **Held by review.** `return p.read_text()` with no `encoding=` exited `0` at all five gate steps
  (*observed*). A file holding `read_text`, `write_text`, `Path.open`, `io.open`,
  `subprocess.run(text=True)`, `NamedTemporaryFile("w")`, `io.TextIOWrapper` and a builtin `open(p)`,
  none with `encoding=`, drew no finding about encoding at step 3: the reports were `UP020`, `S607`,
  `E501` and `PTH123`, and a formatting failure at step 2, all unrelated to it (*observed*).
- **A tool exists but is outside the gate.** Ruff's `PLW1514` `unspecified-encoding` "is in preview
  and is not stable" (`ruff rule PLW1514`), so the baseline's `PL` selection does not turn it on.
  With `--preview --config 'lint.explicit-preview-rules = true' --extend-select PLW1514` it reported
  `Path.read_text`, `Path.write_text`, `Path.open`, `NamedTemporaryFile`, `io.TextIOWrapper` and the
  builtin `open`, and did not report `io.open` or `subprocess.run(text=True)` (*observed*, command
  line only; not tried as a `pyproject.toml` setting). A project may add it; it narrows what review
  must hold without removing it.
- **Python can fail on it at run time.** `-X warn_default_encoding -W error::EncodingWarning`
  turned the first no-`encoding=` call into `EncodingWarning: 'encoding' argument not specified`
  (*observed*; `py312/library/io.rst:148-151`). The gate sets neither option, so this finds the call
  only in a run that does.

## `logging`, not `print`, in library code

Code under `src/` that is not a command-line entry point reports through a module logger,
`logger = logging.getLogger(__name__)`. `print` is for the console output of a command-line program.

- **The split is the standard library's own.** The logging how-to lists `print` as "the best tool"
  to "display console output for ordinary usage of a command line script or program", and a logger's
  `info` (or `debug`) for events "that occur during normal operation of a program"
  (`pymain/howto/logging.rst:35-46`). Ruff says the same of the rule that enforces it: `print`
  statements "are not configurable by clients, unlike `logging` statements", while those that "produce
  output as a part of a command-line interface program are not typically a problem" (`ruff rule
  T201`).
- **Enforced by the gate: `ruff check`, `T201`.** `print("hi")` in library code failed step 3
  (`strict-quality.md` § What the baseline catches). It is not limited to bare calls or to `src/`:
  `print("hi", file=sys.stderr)` was reported, and so was `print(...)` inside `tests/`, because the
  baseline's per-file ignores do not exempt `T201`; `sys.stdout.write("hi\n")` was not (*observed*).
- **A command-line entry point that prints keeps the `print` and suppresses the line**:
  `print(result)  # noqa: T201 - <reason>`. The suppression keeps the exception visible where
  `sys.stdout.write` would hide it. Held by review: that such lines sit only in the entry point.
- **Never the root logger.** "It is strongly advised that you *do not log to the root logger* in your
  library"; use a logger named for the module or package (`pymain/howto/logging.rst:846-851`).
  **Enforced by the gate: `LOG015`** for the module-level functions: `logging.info("n is %s", n)`
  failed step 3 with ``LOG015 `info()` call on root logger`` (*observed*). `LOG015` is in Ruff's
  default rule set rather than the baseline's list (`ruff check --isolated --show-settings` lists
  `root-logger-call (LOG015)` among the enabled rules, *observed*), so it holds without `LOG` in
  `extend-select`.
- **Held by review: configuring logging from a library.** `logging.getLogger()` (the root logger)
  and `logging.basicConfig(level=logging.INFO)` in library code drew no finding at any step
  (*observed*). `basicConfig` works by "adding it to the root logger"
  (`pymain/library/logging.rst:1351-1354`), and the how-to puts handler configuration with the
  application: "It is strongly advised that you *do not add any handlers other than* `NullHandler` *to
  your library's loggers*. This is because the configuration of handlers is the prerogative of the
  application developer who uses your library" (`pymain/howto/logging.rst:852-858`).
- **Held by review: lazy arguments.** Pass values as arguments, `logger.info("n is %s", n)`, because
  "Formatting of message arguments is deferred until it cannot be avoided"
  (`pymain/howto/logging.rst:1071`). An f-string message, `root.info(f"n is {n}")`, drew no finding
  at any step (*observed*): Ruff's `G004` is not among the rules the baseline enables.
- **Enforced by the gate: `TRY400`.** `logger.error("bad value")` inside `except ValueError:` failed
  step 3 with ``TRY400 Use `logging.exception` instead of `logging.error` `` (*observed*); the
  `logger.exception(...)` form was not reported.

## `asyncio.TaskGroup` for concurrent tasks

Tasks that run concurrently and belong together are created in
`async with asyncio.TaskGroup() as tg:` through `tg.create_task(...)`, not through `asyncio.gather`
and not through a bare `asyncio.create_task`.

- **The documentation prefers it.** "*TaskGroup* provides stronger safety guarantees than *gather*
  for scheduling a nesting of subtasks: if a task ... raises an exception, *TaskGroup* will, while
  *gather* will not, cancel the remaining scheduled tasks"
  (`py312/library/asyncio-task.rst:509-516`). `TaskGroup` is new in 3.11
  (`py312/library/asyncio-task.rst:129-131`, `:331`), so both floors have it.
- **Why it matters** (*observed*, CPython 3.12.16): with one task raising `ValueError` after 10 ms
  and a sibling sleeping 200 ms, `gather` raised the `ValueError` to the caller at once and the
  sibling kept running to completion afterwards; the `TaskGroup` cancelled the sibling.
- **A task nobody holds can vanish.** "The event loop only keeps weak references to tasks. A task
  that isn't referenced elsewhere may get garbage collected at any time, even before it's done"
  (`py312/library/asyncio-task.rst:265-269`); a `TaskGroup` "keeps a strong reference to each task,
  awaits them and propagates their exceptions" (`pymain/library/asyncio-task.rst:297-300`; the 3.12
  text names no such property). **Enforced by the gate: `ruff check`, `RUF006`.** A bare `asyncio.create_task(work())`
  failed step 3 with ``RUF006 Store a reference to the return value of `asyncio.create_task` ``;
  `task = asyncio.create_task(work())` and the unreferenced `tg.create_task(work())` were not
  reported (*observed*).
- **Held by review: `gather` where a `TaskGroup` belongs.** `await asyncio.gather(fetch(1),
  fetch(2))` in an `async def` exited `0` at all five gate steps (*observed*); no selected rule
  names it. The one case review accepts is `gather(..., return_exceptions=True)`, where the caller
  wants every outcome, failures included (`py312/library/asyncio-task.rst:498-500`); a group cancels
  its remaining tasks on the first failure, so it does not collect them by itself. The call site
  states that reason.
- **The group raises an exception group.** When tasks fail, "those exceptions are combined in an
  `ExceptionGroup` or `BaseExceptionGroup` ... which is then raised"
  (`py312/library/asyncio-task.rst:362-368`). `except ValueError:` around the `async with` did not
  catch it — the handler for `ExceptionGroup` ran instead and held `['ValueError']` — and
  `except* ValueError as eg:` did (*observed*). Callers handle a group with `except*`; see
  `errors.md`.
- **Gate versions to the floor.** `TaskGroup.cancel()` is marked "versionadded:: 3.15"
  (`pymain/library/asyncio-task.rst:398`), which neither the 3.12 nor the 3.14 floor provides.

## What the gate sees and what review holds

| Rule | Gate step | Code | Status |
|---|---|---|---|
| No mutable default (literal or constructor call) | `ruff check` | `B006` | enforced |
| No mutable dataclass field default | `ruff check`, `pytest` | `RUF008`; `ValueError` at import | enforced |
| No mutable default behind `Mapping`, `Sequence` or `float` | none | — | held by review |
| `pathlib` over `os.path`, `os.getcwd`, `os.listdir`, `open`, `glob.glob` ... | `ruff check` | `PTH100`–`PTH208` | enforced |
| `Path.walk` over `os.walk` | none | — | held by review |
| `encoding=` on text I/O | none | — | held by review (`PLW1514` is preview-only) |
| No `print` | `ruff check` | `T201` | enforced |
| Command-line `print` carries a named suppression with a reason | none | — | held by review |
| No root-logger functions | `ruff check` | `LOG015` | enforced |
| No root `getLogger()`, no `basicConfig` in a library | none | — | held by review |
| Lazy logging arguments | none | — | held by review |
| `logger.exception` in an `except` block | `ruff check` | `TRY400` | enforced |
| `TaskGroup` over `gather` | none | — | held by review |
| No dropped `create_task` result | `ruff check` | `RUF006` | enforced |

## Things to AVOID

- A mutable default argument, including one behind a `Mapping` or `Sequence` annotation, and a
  default that is a call evaluated once at import time (`time.time()`).
- `os.path`, `os.getcwd`, `os.listdir`, `os.walk`, `glob.glob` or a builtin `open(path)` where a
  `Path` method exists, without a named suppression and its reason.
- `read_text()`, `write_text()`, `open()` or `subprocess.run(text=True)` in text mode with no
  `encoding=`.
- `print` in library code; `logging.info(...)` and the other module-level functions, which log to the
  root logger; `logging.basicConfig` or a handler other than `NullHandler` in a library.
- An f-string as a log message, where lazy `%s` arguments would defer the formatting.
- `asyncio.gather` for tasks that belong together, and a bare `asyncio.create_task` whose result
  nobody holds.
- `except ValueError:` around the `async with asyncio.TaskGroup()` block, which does not catch the
  exception group it raises.
- A feature newer than the `requires-python` floor.

## Reviewer checklist

Reject the change if:

- A function default is a mutable value, including one behind an abstract annotation such as
  `Mapping` or `Sequence`, or a call evaluated at import time.
- A path is built or tested with `os.path`, `os.getcwd`, `os.listdir`, `glob.glob` or a builtin
  `open`, or a tree is walked with `os.walk`, with no named suppression and reason.
- A text-mode `read_text`, `write_text`, `open`, `Path.open`, `io.TextIOWrapper`,
  `NamedTemporaryFile` or `subprocess.run(text=True)` passes no `encoding=`.
- Library code calls `print`, logs to the root logger, calls `logging.basicConfig`, adds a handler
  other than `NullHandler`, or builds a log message with an f-string.
- A `print` in a command-line entry point has no `# noqa: T201` carrying a reason, or sits outside
  the entry point.
- Concurrent tasks are started with `asyncio.gather` (other than `return_exceptions=True` with the
  reason stated) or a bare `asyncio.create_task`, or a `TaskGroup` failure is caught with a plain
  `except`.
- A feature newer than the `requires-python` floor is used (`TaskGroup.cancel()` before 3.15, the
  UTF-8 default encoding before 3.15).
