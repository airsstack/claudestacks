# Python — Workspaces

A uv workspace joins several packages developed together under one root, one lockfile and one
environment. This file says when to use one, what the root and the members each carry, where the
tests go, how members depend on each other, and which part of that the gate sees. Every rule says
whether a gate step enforces it or review holds it.

A single project is `project-layout.md`. The workspace form of the gate is in `../SKILL.md` §
Definition of Done; the test placement is in `test-mandate.md`.

**Evidence.** Behaviour claims below were observed on 2026-10-30 with uv 0.13.6, ruff 0.17.3, mypy
2.4.1 and pytest 9.2.0 on CPython 3.12.16 (3.13.18 where stated), and are marked *observed*. They
were made on a workspace probe: a root carrying the baseline of `strict-quality.md` adapted as
[Root `pyproject.toml`](#root-pyprojecttoml) shows, and two members, `core` and `api`, each made
with `uv init --lib --python 3.12 packages/<member>`, each with a module under `src/<member>/` and
tests in `tests/<member>_tests/`; `api` imports `core`. On it all five gate commands exited `0`,
with the sync step run as `uv sync --locked --all-groups --all-packages`, before any change; the
result was `10 files already formatted`, `All checks passed!`, `Success: no issues found in 8
source files` and `5 passed` (four tests and one doctest). The probe was built twice, once with a
root that declares `[project]` and once with a root that does not (a virtual root); every
observation is of the first unless it says otherwise. Each defect was applied alone to a fresh
copy, and every mypy observation used a cold cache (`.mypy_cache` deleted first). Claims about what
uv documents give the file, line and quoted words of uv's own documentation, fetched on 2026-10-30
from the `0.13.6` tag (`workspaces.md` is
`https://raw.githubusercontent.com/astral-sh/uv/0.13.6/docs/concepts/projects/workspaces.md`;
`dependencies.md` is the same directory).

## Why a workspace, and when not

- **Use a workspace only for packages developed together that can share one lockfile, one
  environment and one `requires-python`.** uv: "Workspaces are intended to facilitate the
  development of multiple interconnected packages within a single repository"
  (`workspaces.md:162-163`), and "the workspace shares a single lockfile, ensuring that the
  workspace operates with a consistent set of dependencies" (`workspaces.md:11-12`).
- **Otherwise keep separate projects joined by path dependencies.** uv: "Workspaces are _not_ suited
  for cases in which members have conflicting requirements, or desire a separate virtual environment
  for each member. In this case, path dependencies are often preferable" (`workspaces.md:177-178`),
  declared as `bird-feeder = { path = "packages/bird-feeder" }` under `[tool.uv.sources]`
  (`workspaces.md:179-196`). The cost is stated in the same place: "`uv run --package` is no longer
  available; instead, commands must be run from the relevant package directory"
  (`workspaces.md:198-200`). Each such project is a single project (`project-layout.md`) and runs the
  single-project gate from its own directory. A path-dependency layout was not probed.
- **The members share one `requires-python`, and it is the intersection.** uv: "uv's workspaces
  enforce a single `requires-python` for the entire workspace, taking the intersection of all
  members' `requires-python` values" (`workspaces.md:202-203`). With `core` and the root at
  `>=3.12` and `api` changed to `>=3.13`, `uv lock` with `.python-version` at `3.13` wrote
  `requires-python = ">=3.13"` into `uv.lock`, and `uv sync --locked --all-groups --all-packages`
  exited `0` on CPython 3.13.18 (*observed*). With `.python-version` set back to `3.12` the same
  sync exited `2`: ``The Python request from `.python-version` resolved to Python 3.12.16, which is
  incompatible with the project's Python requirement: `>=3.13` (from workspace member `api`'s
  `project.requires-python`)`` (*observed*). A member that must test on an older Python than the
  rest does not belong in the workspace; uv's own advice is a separate environment for it
  (`workspaces.md:203-205`).
- **Held by review.** No gate step reads the reason a package joined the workspace. Review rejects a
  workspace whose members have conflicting requirements or need an environment of their own.

## Root `pyproject.toml`

```toml
[dependency-groups]
dev = ["mypy==2.4.1", "pytest==9.2.0", "ruff==0.17.3"]

[tool.uv.workspace]
members = ["packages/*"]

[tool.ruff.lint.per-file-ignores]
"packages/*/tests/**" = ["S101", "PLR2004", "D"]

[tool.pytest]
testpaths = ["packages"]
```

Every other table of the baseline in `strict-quality.md` is carried unchanged (`[tool.ruff.lint]`,
`[tool.ruff.lint.pydocstyle]`, `[tool.mypy]`, and the rest of `[tool.pytest]`). The tables above are
the ones the workspace changes.

- **The root holds the baseline and the `dev` group; the gate runs from the root.** uv: "By default,
  `uv run` and `uv sync` operate on the workspace root" (`workspaces.md:55`), and `uv lock`
  "operates on the entire workspace at once" (`workspaces.md:14`). The gate tools are pinned once, in
  the root's `dev` group; the members' manifests carried no dependency group and no `[tool.ruff]`,
  `[tool.mypy]` or `[tool.pytest]` table (`api` carried `[tool.uv.sources]`, see below), and the gate
  was green (*observed*). **Held by review.** Run from `packages/core` instead of the root, the same
  five commands all exited `0` and covered only that member (`5 files already formatted`, `Success:
  no issues found in 4 source files`, `3 passed`) (*observed*), so no step notices the wrong
  directory; whether the root baseline is complete is `strict-quality.md`'s account.
- **`members = ["packages/*"]`: gate-enforced.** uv: "Every directory included by the `members` globs
  (and not excluded by the `exclude` globs) must contain a `pyproject.toml` file"
  (`workspaces.md:46-47`). With an extra `packages/stray/` holding only a text file, `uv sync
  --locked --all-groups --all-packages` exited `2` and so did every `uv run` step after it, with
  ``error: Workspace member `…/packages/stray` is missing a `pyproject.toml` (matches:
  `packages/*`)`` (*observed*).
- **Both root shapes passed the full gate with `--all-packages`.** A root that declares `[project]`
  (`name`, `version`, `requires-python`, and no `[build-system]`) passed all five commands, and so did
  a virtual root, one with `[tool.uv.workspace]` and `[dependency-groups]` and no `[project]` table:
  `10 files already formatted`, `All checks passed!`, `Success: no issues found in 8 source files`,
  `5 passed` (*observed*, both). uv printed no warning on the virtual root's sync. The flag is
  therefore not tied to the root shape, which is why the gate carries it in any workspace.
- **`testpaths = ["packages"]`: gate-enforced.** With `testpaths = ["tests", "src"]` left in the root,
  the `pytest` step exited `1` with `pytest.PytestConfigWarning: No files were found in testpaths;
  consider removing or adjusting your testpaths configuration`, a warning the baseline's
  `filterwarnings = ["error"]` turns into a failure (*observed*).
- **The ignores keyed `"packages/*/tests/**"`: gate-enforced.** With the key left at `"tests/**"`,
  `ruff format --check` exited `0` and `ruff check --no-fix` exited `1` with `Found 14 errors`:
  `D100`, `D103`, `D104`, `PLR2004` and `S101` on the test files (*observed*).
- **A member's own `[tool.ruff…]` table replaces the root's, and the gate stays green: held by
  review.** With `[tool.ruff.lint] select = ["E"]` added to `packages/core/pyproject.toml` and a
  `print()` in `packages/core/src/core/mod.py`, all five commands exited `0`; with the member's table
  removed, `ruff check --no-fix` exited `1` with ``T201 `print` found`` (*observed*). Members carry no
  `[tool.ruff…]` table. A member `[tool.mypy]` or `[tool.pytest]` table was not probed; keep them out
  of the members as well so the root's baseline is the only one.

## Member `pyproject.toml`

`uv init --lib --python 3.12 packages/core`, run from the root, wrote `pyproject.toml`, `README.md`,
`src/core/__init__.py` and an empty `src/core/py.typed`; it wrote no `.python-version` and no
`uv.lock` in the member (*observed*). In a scratch directory that was not a git repository it also
wrote a `.gitignore` and a `.git/` in the member; a lone `uv init --lib` inside a repository wrote
neither (*observed*), so neither belongs to the layout below. The member's `pyproject.toml` has
`[project]` with `name`, `version`, `requires-python = ">=3.12"` and `dependencies = []`, and
`[build-system]` with `build-backend = "uv_build"` (*observed*).

- **Every member declares `[project]` and `[build-system]`**, as `project-layout.md` requires of any
  project. A library member ships `py.typed`, as it requires there.
  - `[project]` is gate-enforced. With it removed from `packages/core/pyproject.toml`, the sync
    step exited `2` with ``error: No `project` table found in: …/packages/core/pyproject.toml``
    (*observed*).
  - `[build-system]` is held by review. With it removed from `api` and the lock refreshed, all five
    commands exited `0` and `5 passed`, although `.venv/bin/python -c "import api"` exited `1`
    (``ModuleNotFoundError: No module named 'api'``) (*observed*).
  - `py.typed` is held by review. With the file deleted from `core`, all five commands exited `0`
    (*observed*).
- **Every member has `src/<member>/` and its own `tests/`**, laid out as below.
  - `src/<member>/` is gate-enforced for this backend. With `packages/core/src/` deleted, the sync
    step exited `2` with a failed build of `core` whose cause line read `Expected a Python module
    at: packages/core/src/core/__init__.py` (*observed*).
  - `tests/` is held by review. With `packages/api/tests/` deleted, all five commands exited `0`
    and `3 passed` (*observed*); `test-mandate.md` states the rule.
- **Members share one `requires-python`.** The effective value is the intersection of the members'
  ranges (above), so a member with a narrower range raises the floor for every member. The root's
  `.python-version` equals that floor: `project-layout.md` gives the reason.
  - A file naming an interpreter below the floor is gate-enforced: the sync step above exited `2`
    (*observed*).
  - A file naming one above the floor is held by review. With `.python-version` at `3.13` and every
    range still `>=3.12`, `uv.lock` kept `requires-python = ">=3.12"`, `.venv` held CPython 3.13.18,
    and all five commands exited `0` (*observed*).
- **The workspace has one `uv.lock`, at the root** (`workspaces.md:11-12`); `uv init` wrote none in a
  member. This is held by review: with a copy of the root's `uv.lock` placed in `packages/core/`,
  all five commands exited `0` (*observed*).
- **A member declares every package it imports.** See
  [Inter-member dependencies](#inter-member-dependencies).

## Directory layout

```text
workspace/
├── pyproject.toml            [dependency-groups], [tool.uv.workspace], [tool.*] baseline;
│                             [project] optional
├── uv.lock                   one lockfile, committed, at the root only
├── .python-version           equals the workspace requires-python floor
├── .venv/                    one environment, ignored
└── packages/
    ├── core/
    │   ├── pyproject.toml    [project], [build-system]
    │   ├── README.md
    │   ├── src/
    │   │   └── core/
    │   │       ├── __init__.py
    │   │       ├── py.typed  libraries only
    │   │       └── mod.py
    │   └── tests/            no __init__.py here
    │       └── core_tests/   top of the test tree
    │           ├── __init__.py   one here, and in every directory below
    │           └── test_mod.py
    └── api/                  same shape
```

- **Members live under `packages/`.** The root's `members = ["packages/*"]`, `testpaths =
  ["packages"]` and ignore key `"packages/*/tests/**"` all name that directory. uv's own example
  uses the same layout (`workspaces.md:134-155`). The three must name the same directory, and
  review rejects a workspace where they disagree.
- **Each member's tests sit in `packages/<member>/tests/<member>_tests/`, the top of the member's
  test tree: every directory from `<member>_tests/` down carries an `__init__.py`, and the member's
  own `tests/` carries none.** With `__init__.py` in both `packages/core/tests/` and
  `packages/api/tests/`, `ruff format --check`, `ruff check --no-fix` and `pytest` exited `0`, and
  `mypy --strict .` exited `2` with `errors prevented further checking`:
  ``packages/core/tests/__init__.py: error: Duplicate module named "tests" (also at
  "./packages/api/tests/__init__.py")`` (*observed*). Two members cannot each own a package called
  `tests`; the `<member>_tests` name makes each unique. `test-mandate.md` has the full account, the
  rule for the directories below the top, and what a test file covers.
- **Gate-enforced for the duplicate only.** The `mypy --strict .` step reports it, as the run above
  shows. No step reads the name `<member>_tests` itself, and a different unique name was not
  probed, so review holds that form. mypy needs only the top `__init__.py`; the file in each
  directory below it is held by review (`test-mandate.md`, § Where tests live).

## Inter-member dependencies

A member that imports a sibling lists it in its own `[project] dependencies` and names the workspace
as its source:

```toml
[project]
dependencies = ["core"]

[tool.uv.sources]
core = { workspace = true }
```

- **`{ workspace = true }` in the importing member's `[tool.uv.sources]`.** uv: "To declare a
  dependency on a workspace member, add the member name with `{ workspace = true }`. All workspace
  members must be explicitly stated" (`dependencies.md:475-476`); the key "indicates the
  `bird-feeder` dependency should be provided by the workspace, rather than fetched from PyPI or
  another registry" (`workspaces.md:83-85`). A `[tool.uv.sources]` entry in the root applies to all
  members unless a member overrides it (`workspaces.md:94-95`, `workspaces.md:121-124`).
- **Enforced by uv when the entry is missing.** With `dependencies = ["core"]` in `api` and no
  `[tool.uv.sources]` entry, `uv lock` exited `2` with `uv.lock` present, and so did `uv sync
  --locked --all-groups --all-packages`; with `uv.lock` deleted first, `uv lock` exited `1`. The
  last line of those three runs was the same (*observed*):

  ```text
    cause: `core` is included as a workspace member, but is missing an entry in `tool.uv.sources` (e.g., `core = { workspace = true }`)
  ```
- **Dependencies between members are editable.** uv: "Dependencies between workspace members are
  editable" (`workspaces.md:92`).
- **Declaring every imported package is held by review.** uv documents the limit: "uv can't ensure
  that packages don't import dependencies declared by another workspace member"
  (`workspaces.md:209`). Two copies of the probe show it, and the gate was green in both
  (`uv sync --locked --all-groups --all-packages`, then the four checks, all exit `0`, *observed*):
  - `core` declared `idna` and `api` did `import idna` while its own `dependencies` stayed
    `["core"]`; `mypy --strict .` found the types and `pytest` imported it.
  - `api` imported `core.mod` with `dependencies = []` in its manifest and the
    `[tool.uv.sources]` entry left in place; the lock was refreshed and the `--locked` sync passed.

  In the first copy `.venv` held `idna` (``import idna`` ran from
  `.venv/lib/python3.12/site-packages`) although only `core` declared it. Review checks that every top-level import in a member's `src/`
  and `tests/` names a package that member lists, or the standard library, or the member itself.

## Where it differs from a Cargo workspace

The Rust workspace rule has one `Cargo.lock` and says `cargo` commands without `-p` operate on
`default-members` or the whole workspace (`rust-guidelines` `references/workspace.md`, § Why a
workspace and § Inter-crate dependencies, read on 2026-10-30, not re-run). A uv workspace shares one
lockfile too, and three things are particular to uv:

- **`requires-python` is one value for the workspace**, the intersection of the members' ranges
  (see [Why a workspace, and when not](#why-a-workspace-and-when-not)).
- **uv does not stop a member importing a package another member declares** (`workspaces.md:209`,
  see [Inter-member dependencies](#inter-member-dependencies)).
- **A plain sync leaves the members out when the root declares `[project]`.** With the probe root and
  `uv sync --locked --all-groups` (no flag): the sync exited `0`, `.venv/bin/python -c "import core"`
  exited `1` (``ModuleNotFoundError: No module named 'core'``) and so did `import api`; after `uv sync
  --locked --all-groups --all-packages` both imports exited `0`; after a later plain sync `import
  core` exited `1` again (*observed*).
  - **The gate sees the missing members only through `pytest`.** On that environment `ruff format
    --check`, `ruff check --no-fix` and `mypy --strict .` all exited `0` (the last still printed
    `Success: no issues found in 8 source files`) and `pytest` exited `2` with collection errors,
    ``E   ModuleNotFoundError: No module named 'core'`` (*observed*). The module that failed to
    collect was a source module, collected by `--doctest-modules`. A workspace in which no module
    pytest collects imports a sibling passed it too (`3 passed`, *observed*), which is why the flag
    is on the command and not left to the test suite.
  - **A virtual root installs the members on a plain sync.** The copy whose root has no `[project]`
    table: after `uv sync --locked --all-groups`, `import core` and `import api` exited `0`; so they
    did after `--all-packages`, and `import core` did after a later plain sync (*observed*). The
    flag is harmless there.
  - **Full gate with the flag, either root shape: all five commands exit `0`** (*observed*, see
    Evidence).

## What the gate sees and what review holds

| Rule | Gate step | Outcome |
|---|---|---|
| members are installed in the gate's environment | `pytest` (only when a module pytest collects imports a sibling) | exit `2` without `--all-packages` on a root that declares `[project]` (*observed*) |
| the gate runs from the root | none | green from `packages/core` too, covering that member only (*observed*): review |
| `members` globs match only directories with a `pyproject.toml` | `uv sync`, so every `uv run` step | exit `2`, ``Workspace member … is missing a `pyproject.toml` `` (*observed*) |
| a member lacks `[project]` | `uv sync` | exit `2`, ``No `project` table found`` (*observed*) |
| a member lacks `[build-system]` | none | green (*observed*): review |
| a member lacks `py.typed` | none | green (*observed*): review |
| a member lacks `src/<member>/` | `uv sync` (the build) | exit `2`, `Expected a Python module at: packages/core/src/core/__init__.py` (*observed*) |
| a member lacks `tests/` | none | green (*observed*): review |
| `.python-version` below the floor | `uv sync` | exit `2`, ``The Python request from `.python-version` resolved to Python 3.12.16, which is incompatible …`` (*observed*) |
| `.python-version` above the floor | none | green (*observed*): review |
| a member has its own `uv.lock` | none | green (*observed*): review |
| `testpaths = ["packages"]` | `pytest` | exit `1`, `PytestConfigWarning` (*observed*) |
| ignores keyed `"packages/*/tests/**"` | `ruff check --no-fix` | exit `1`, `S101` and others (*observed*) |
| two members each with `tests/__init__.py` | `mypy --strict .` | exit `2`, `Duplicate module named "tests"` (*observed*) |
| a member declares a sibling in `dependencies` without a `[tool.uv.sources]` entry | `uv lock`, so every `--locked` step | exit `2` with `uv.lock` present, `1` with it deleted (*observed*) |
| unused import in a member | `ruff check --no-fix` | exit `1`, `E402` and `F401` on `packages/core/src/core/mod.py`; `ruff format --check` also exits `1` on that file (*observed*) |
| wrong return type in a member | `mypy --strict .` | exit `1`, ``Incompatible return value type (got "str", expected "int")  [return-value]`` (*observed*) |
| failing test in a member | `pytest` | exit `1`, `FAILED packages/api/tests/api_tests/test_mod.py::test_broken - assert 4 == 5` (*observed*) |
| a member imports a package it does not declare, a sibling included when it has no `dependencies` entry | none | green, all five exit `0` (*observed*): review |
| a member carries its own `[tool.ruff…]` table | none | green (*observed*): review |
| the packages share one lockfile, environment and `requires-python` | none | review |
| `tests/<member>_tests/` form | `mypy --strict .` for the `tests` duplicate only; other names not probed | review |
| an `__init__.py` in each directory below `<member>_tests/` | none: mypy needs only the top file | review |

## Reviewer checklist

Reject the change if:

- The workspace joins packages with conflicting requirements, or members that need an environment of
  their own or an older Python than the rest, instead of separate projects with path dependencies.
- The gate's sync step lacks `--all-packages`, or the gate is run from a member directory instead of
  the root.
- The root's `testpaths` is not `["packages"]` (or the chosen members directory), or the test ignores
  are not keyed to the same directory, or the baseline of `strict-quality.md` is weakened.
- A member carries a `[tool.ruff…]` table, or its own `uv.lock`.
- `.python-version` differs from the workspace floor, the intersection of the members' ranges.
- A directory of a member's test tree (`<member>_tests/` and every directory below it) has no
  `__init__.py`, or the member's own `tests/` has one, or the tests are not in
  `tests/<member>_tests/`.
- A member imports a package, its own or a sibling's, that its own `[project] dependencies` does not
  list, or depends on a sibling without `{ workspace = true }`.
- A new member lacks `[project]`, `[build-system]`, `src/<member>/` or its tests directory.
