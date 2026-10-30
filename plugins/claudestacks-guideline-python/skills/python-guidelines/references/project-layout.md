# Python — Project Layout

The shape of a Python project: where the source and the tests live, which files are committed and
which are ignored, which `pyproject.toml` tables are always declared, and how the interpreter pin
relates to the version floor. Every rule says whether a gate step enforces it or review holds it.

**Evidence.** Behaviour claims below were observed on 2026-10-29 with uv 0.13.6, ruff 0.17.3,
mypy 2.4.1 and pytest 9.2.0 on CPython 3.12.16 (3.14.10 where stated), and are marked *observed*.
Each observation that names a gate step was made on a copy of a `uv init --lib` project named
`probe` (package `src/probe/`, one module `probe.core`, one test importing it) carrying the baseline
of `strict-quality.md`, on which all five gate commands exited `0` before the change. Claims about
what a standard or a tool documents give the document's URL and line, fetched on 2026-10-29
(`pep-NNNN` is
`https://raw.githubusercontent.com/python/peps/main/peps/pep-NNNN.rst`; `uv/…` is
`https://raw.githubusercontent.com/astral-sh/uv/main/docs/concepts/…`; `packaging/…` is
`https://raw.githubusercontent.com/pypa/packaging.python.org/main/source/discussions/…`).

This file describes one project. The workspace form of the gate is in `../SKILL.md` § Definition of
Done.

## The shape

```text
project/
├── pyproject.toml          committed   [project], [build-system], [dependency-groups], [tool.*]
├── uv.lock                 committed
├── .python-version         committed   equals the requires-python floor
├── README.md
├── src/
│   └── <package>/
│       ├── __init__.py
│       └── py.typed        libraries only
├── tests/                  at the root, outside src/
├── .venv/                  ignored
└── dist/                   ignored
```

`uv init --lib --python 3.12 p` wrote `.gitignore`, `.python-version`, `pyproject.toml`,
`README.md`, `src/p/__init__.py` and an empty `src/p/py.typed`; `uv init --app --python 3.14 a` wrote
the same without `py.typed` (*observed*). Neither writes `tests/` or a dependency group; the project
adds them.

## `src/` layout

- **Importable code lives in `src/<package>/`, not in the project root.** The packaging guide:
  "The src layout helps prevent accidental usage of the in-development copy of the code", because
  "the Python interpreter includes the current working directory as the first item on the import
  path" (`packaging/src-layout-vs-flat-layout.rst:56-68`). uv "prefers to … place source files in a
  dedicated `src/<project_name>/` directory" and "avoids common points of confusion with the Python
  import system" (`uv/projects/init.md:9-12`), and calls the layout "particularly valuable when
  developing libraries" (`uv/projects/init.md:131-135`).
- **The src layout requires the project to be installed to run its code**
  (`packaging/src-layout-vs-flat-layout.rst:48-54`). `uv sync` installs it, which is why the gate
  runs from a synced environment.
- **Enforced by the gate under `uv_build`'s default `module-root`; held by review otherwise.** With
  the `uv_build` backend that `uv init` writes, moving `src/probe/` to `probe/` made the sync step
  exit `2` with `Expected a Python module at: src/probe/__init__.py`, and every later step failed on
  the same error (*observed*). Adding `[tool.uv.build-backend]` with `module-root = ""` to the flat
  layout, `testpaths` untouched, left all five steps at `0`; `pytest` reported `1 passed`, because
  the doctest in the module no longer sat under the `src` entry of `testpaths` (*observed*). Review
  rejects a `module-root` override. Another build backend was not probed; review holds the layout
  there.

## `tests/` at the root

- **Tests live in `tests/` at the project root, beside `src/`.** The baseline's
  `testpaths = ["tests", "src"]` and its `per-file-ignores` key `"tests/**"` both name that
  directory (`strict-quality.md`). This file fixes only where the directory sits.
- **Held by review; the gate catches a displaced test directory only incidentally.** With `tests/`
  renamed `checks/`, the `pytest` step exited `0` having run one test (the doctest in `src/`), and
  `ruff check --no-fix` exited `1`, with `D100`, `D103`, `S101` and `PLR2004` on the moved file
  because the baseline's `"tests/**"` ignores no longer matched it (*observed*). That failure comes
  from the lint ignores, not from a rule about where tests sit, and `pytest` stops collecting the
  moved tests without saying so. Review rejects a project whose tests are not under `tests/`.

## Committed and ignored files

| Path | In version control | Source |
|---|---|---|
| `pyproject.toml` | yes | uv "requires this file to identify the root directory of a project" (`uv/projects/layout.md:5-7`) |
| `uv.lock` | yes | "This file should be checked into version control, allowing for consistent and reproducible installations across machines" (`uv/projects/layout.md:85-86`) |
| `.python-version` | yes | written by `uv init`, which does not list it in its `.gitignore` (*observed*); it fixes the interpreter the gate runs on (below) |
| `.venv/` | no | "It is not recommended to include the `.venv` directory in version control" (`uv/projects/layout.md:35-36`) |
| `dist/` | no | listed by the `.gitignore` that `uv init` writes, with `build/`, `wheels/`, `*.egg-info`, `__pycache__/`, `*.py[oc]` and `.venv` (*observed*) |

- `.mypy_cache/`, `.ruff_cache/` and `.pytest_cache/` each wrote their own `.gitignore` containing
  `*`, and so did `.venv/` (*observed*); they need no entry of their own.
- **Held by review**: no gate step reads version control. Review rejects a committed `.venv/` or
  `dist/`, an ignored `uv.lock`, and an ignored `.python-version`.

## `[project]` and `[build-system]` are always declared

- **`[project]` carries the project's metadata.** "Tools MUST specify fields defined by this PEP in
  a table named `[project]`", and "the lack of a `[project]` table implicitly means the build
  back-end will dynamically provide all fields" (`pep-0621.rst:113-119`).
- **`[build-system]` names the backend.** PEP 517 extends the `[build-system]` table with
  `build-backend` (`pep-0517.rst:102-104`). uv documents that a `pyproject.toml` that "does not
  define a build system" makes the project one that "will not be installed into the environment"
  (`uv/projects/init.md:282-283`), which the `src/` layout needs.
- **`uv init --app` declares `[build-system]`; no extra step is needed.** `uv init --app --python
  3.14 a` wrote `.gitignore`, `.python-version` (`3.14`), `README.md`, `pyproject.toml` and
  `src/a/__init__.py`; the `pyproject.toml` has `requires-python = ">=3.14"`, `[project.scripts]` and
  `[build-system]` with `build-backend = "uv_build"` (*observed*). `uv init --package` wrote the same
  table. uv documents the change: "Prior to v0.12, uv did not define a build system for applications
  by default" (`uv/projects/init.md:18`), so on an older uv add the table by hand.
- **Do not create an application with `--no-package`.** `uv init --app --no-package --python 3.14 n`
  wrote `main.py` in the project root and a `pyproject.toml` with no `[build-system]` (*observed*),
  which breaks both this rule and the `src/` layout.
- **Enforced by the gate only through the tests.** With the lock refreshed (`uv lock`) before the
  gate ran, deleting `[build-system]` left the sync, format, lint and mypy steps at `0` and failed
  the `pytest` step with exit `2`, a collection `ImportError` on `from probe.core import double`.
  Deleting `[project]` left those four steps at `0`, with ``warning: No `requires-python` value
  found in the workspace. Defaulting to `>=3.12`.`` on stderr, and failed `pytest` with
  `ModuleNotFoundError: No module named 'probe'` (*observed*). A project whose tests import its
  package is caught; review holds the rule otherwise.

## `py.typed` in libraries

- **A library ships a `py.typed` marker.** PEP 561: "Package maintainers who wish to support type
  checking of their code MUST add a marker file named `py.typed` to their package"
  (`pep-0561.rst:107-108`). `uv init --lib` writes it (an empty file) and documents it as "a
  `py.typed` marker … to indicate to consumers that types can be read from the library"
  (`uv/projects/init.md:117`).
- **It must reach the built wheel.** `uv build` on the `uv init --lib` project produced a wheel
  containing `probe/py.typed` and no `tests/` (*observed*).
- **`uv init --app` writes no `py.typed`** (*observed*). The rule is for a library, which is any
  project published to a package index.
- **Held by review.** Deleting `py.typed` left all five gate commands at exit `0` (*observed*).

## Dev tools in `[dependency-groups]`

- **Gate tools and test dependencies go in a dependency group, not in `[project.dependencies]` or
  `[project.optional-dependencies]`.** PEP 735 specifies groups "such that they are not included in
  any built distribution of the project" (`pep-0735.rst:20-22`): they are "not published as
  distinct metadata in any built distribution", and "installation of a dependency group does not
  imply installation of a package's dependencies or the package itself"
  (`pep-0735.rst:157-160`). The wheel built from the probe project listed none of ruff, mypy or
  pytest in its `METADATA` (*observed*).
- **Enforced by the gate for `[project.optional-dependencies]`.** With the same three pins under
  `[project.optional-dependencies] dev` instead, `uv sync --locked --all-groups` exited `0` but
  installed none of them, and the format, lint, mypy and pytest steps each exited `2` with `Failed
  to spawn: <tool>` (*observed*). The pins and the group name come from `strict-quality.md`.
- **Held by review for `[project.dependencies]`.** With the three pins moved into `[project]
  dependencies` and the dependency group removed, the lock refreshed (`uv lock`), all five gate
  commands exited `0` (*observed*), so the gate does not tell that declaration from the correct one.

## `.python-version` equals the `requires-python` floor

- **`3.12` and `>=3.12` for a library, `3.14` and `>=3.14` for an application.** A library is any
  project published to a package index. `uv init --lib --python 3.12` wrote `.python-version`
  containing `3.12` and `requires-python = ">=3.12"`; `uv init --app --python 3.14` wrote `3.14` and
  `>=3.14` (*observed*). uv reads the file as "a default Python version request"
  (`uv/python-versions.md:61-62`); `strict-quality.md` gives the mypy and Ruff citations for why the
  gate then checks only that interpreter.
- **Held by review.** On a project with `requires-python = ">=3.12"` and `.python-version`
  containing `3.14`, whose module did `from warnings import deprecated`, all five gate commands
  exited `0`; the gate ran on `Python 3.14.10`, and the same source imported on 3.12.16 raised
  `ImportError: cannot import name 'deprecated' from 'warnings'`. With `.python-version` set back to
  `3.12`, `mypy --strict .` exited `1` (`Module "warnings" has no attribute "deprecated"
  [attr-defined]`) and `pytest` exited `2` (*observed*). Nothing in the gate compares the two
  versions; review does.

## Standalone PEP 723 scripts

A single-file script with an inline metadata block (`# /// script`) and no `pyproject.toml` above it
is not a project, and this guideline is not surfaced for it; that is accepted, not a defect. The
block holds `dependencies`, `requires-python` and a `[tool]` table (`pep-0723.rst:148-167`). The
plugin's `enforcement.json` sets `"detect": ["pyproject.toml"]`; the dispatcher's trace for a `.py`
file with no `pyproject.toml` above it ended `GATE 2 no detect marker` with `outcome: 0 pointer(s)`,
and the same dispatcher emitted the pointer for a `.py` file under a project (*observed*).

- **The code rules still apply when this guideline is loaded by hand**: typing, docstrings, errors
  and idioms are properties of the source, not of the project.
- **The gate does not run on a script.** In a directory holding only `tool.py` with a `script`
  block, `uv run --script tool.py` exited `0`; `uv sync --locked --all-groups` exited `2` with
  `error: No pyproject.toml found in current directory or any parent directory`; `uv run --locked
  ruff format --check` and `uv run --locked pytest` exited `2` with `Failed to spawn: ruff` and
  `Failed to spawn: pytest`, each after ``warning: `--locked` has no effect when used outside of
  a project`` (*observed*).
- **A script that needs the gate becomes a project**: run `uv init` for it, so the layout above and
  the baseline in `strict-quality.md` apply.

## Reviewer checklist

Reject the change if:

- Importable code sits outside `src/<package>/`, or tests sit outside `tests/`.
- `pyproject.toml` lacks `[project]` or `[build-system]`, or an application was created with
  `--no-package`.
- A library lacks `py.typed`, or the built wheel does not contain it.
- Gate tools or test dependencies are declared in `[project.dependencies]` or
  `[project.optional-dependencies]` instead of `[dependency-groups]`.
- `.venv/` or `dist/` is committed, or `uv.lock` or `.python-version` is ignored.
- `.python-version` differs from the `requires-python` floor: `3.12` for a library, `3.14` for an
  application.
