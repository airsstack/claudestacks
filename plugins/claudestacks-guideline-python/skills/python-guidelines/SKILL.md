---
name: python-guidelines
description: Use when writing or editing Python code or pyproject.toml — supplies the Python Definition-of-Done (the exact uv, ruff, mypy and pytest command gate every change must pass) and an index of engineering rules (strict quality, modern typing, strong types, protocols and composition, `__init__.py` hygiene, modularity, docstring discipline, the test mandate, errors, idioms, project layout, uv workspaces, and the Google Python Style Guide). Read the matching reference before applying a rule.
---

# Python Guidelines

Engineering rules and the Definition-of-Done for Python work. `SKILL.md` is the gate and the map;
the detail lives in `references/` and is read on demand.

## Definition of Done (the gate)

This block is the gate — the single canonical command set. Every command must exit `0` on a clean
checkout before a change is complete. `references/strict-quality.md` explains the policy behind it;
it does not restate the commands.

```bash
uv sync --locked --all-groups                # add --all-packages in a uv workspace
uv run --locked ruff format --check
uv run --locked ruff check --no-fix
uv run --locked mypy --strict .
uv run --locked pytest
```

Rules of the gate:

- **Every command exits `0`.** There is no separate warnings bar: pytest turns warnings into
  failures through the required `pyproject.toml` baseline, and Ruff and mypy have no warning
  severity that exits `0` in this configuration.
- **A Ruff configuration warning exits `0`, so review rejects it.** Selecting a rule that conflicts
  with the formatter (such as `COM812`) prints a warning on stderr while both Ruff steps still exit
  `0`. A configuration that prints any warning does not pass review.
- **`--locked` on every step**, so a stale `uv.lock` fails the gate instead of being silently
  rewritten.
- **`--no-fix` is what keeps the `ruff check` step a check.** `ruff check` exits `0` when all
  present violations were fixed automatically, so a project that sets `fix = true` would pass
  while rewriting its source; the flag forbids that.
- **`--strict` stays on the command line** even though the baseline sets `strict = true`, so the
  gate states its own bar the way the Rust gate states `-D warnings`.
- **`--all-packages` in a uv workspace.** Without it, a workspace root that declares `[project]`
  syncs an environment without the members, and the gate tests that environment; a virtual root
  installs them either way. The flag covers both. In a workspace the gate runs from the root, and
  the baseline lives in the root `pyproject.toml` with `testpaths = ["packages"]` and the test
  ignores keyed `"packages/*/tests/**"`.
- **There is deliberately no separate `uv lock --check` step.** A stale lock already fails the sync
  step, and every later `--locked` step fails with it.
- **There is no coverage threshold.** Coverage is not part of the gate.
- **The gate runs on the interpreter `.python-version` names.** mypy and pytest use that
  interpreter, so a `.python-version` above the `requires-python` floor type-checks and tests
  against the newer interpreter only. Keep `.python-version` equal to the floor: `3.12` for a
  library (any project published to a package index), `3.14` for an application.
- **`uv` is the one prerequisite, and the `dev` dependency group is where every gate tool comes
  from.** A missing `uv`, or a gate tool absent from the lock, makes the step's command fail and so
  fails the gate. Pin the tools exactly (`==`) in `[dependency-groups] dev` so `uv.lock` fixes the
  versions the gate runs.
- Adopting the baseline on a project that does not meet it turns the gate red; the guideline offers
  no weaker tier. The gate cannot detect a missing baseline, so review holds its presence.

## Reference index

Read the one that matches your task:

- `references/strict-quality.md` — the policy behind the gate above: the required `pyproject.toml`
  baseline, what each gate flag enforces, suppression rules, what "green" means for tests and
  doctests, the supply-chain checks, and the reviewer checklist.
- `references/typing.md` — modern typing: PEP 695 type parameters and `type` aliases, `X | None`
  and `collections.abc` generics, `@override` on every override, `assert_never` closing every
  `match` over a union or enum, `TypeIs` over `TypeGuard`, floor-gated features and forward
  references, what the gate sees and what review holds, and where it overrides the Google guide.
- `references/strong-types.md` — domain values get types: `NewType` for identifiers with a parse
  function that validates, frozen slotted dataclasses that validate in `__post_init__`,
  `StrEnum`/`Enum`/`Literal` for closed sets, keyword-only `bool` parameters; what the gate sees
  and what review holds.
- `references/protocols-and-composition.md` — choosing an abstraction by coupling: a concrete type,
  then a callable, then a `Protocol` owned by the consumer, then an ABC only to share
  implementation; composition over inheritance; what `@runtime_checkable` does and does not check.
- `references/init-export-only.md` — what `src/**/__init__.py` may hold: a docstring, a sorted
  `__all__` and absolute re-exports, nothing else; the re-export forms mypy needs, imports inside
  the package, what the gate sees and what review holds.
- `references/modularity.md` — one responsibility per class, module and function, one canonical
  type per concept, no import cycles, no module named after a standard-library module; what the
  gate sees and what review holds.
- `references/docstring-discipline.md` — a Google-convention docstring on every public module,
  class and function, docstrings and comments that are true of the code, and no planning paths,
  workflow vocabulary or AI names in source; the leakage grep and the reviewer checklist.
- `references/test-mandate.md` — where tests live and what they cover: a `tests/…/test_<module>.py`
  for every logic-bearing module under `src/`, the `__init__.py` files the test tree needs for mypy,
  `tests/<member>_tests/` per workspace member, the exempt module kinds, what the gate sees and
  what review holds, and the reviewer checklist.
- `references/errors.md` — one project exception hierarchy rooted in `Exception`, `raise … from` in
  every handler, no bare or catch-all `except` outside a re-raise or a logged isolation point,
  `except*` for exception groups; which Ruff and mypy codes enforce each rule.
- `references/idioms.md` — no mutable defaults, `pathlib` over `os.path`, explicit `encoding=`,
  `logging` not `print` in library code, `asyncio.TaskGroup` over `gather`; what enforces each and
  the reviewer checklist.
- `references/project-layout.md` — repository shape of a Python project: the `src/` layout, `tests/`
  at the root, committed vs ignored files, `[project]` and `[build-system]` always declared,
  `py.typed` in libraries, dev tools in `[dependency-groups]`, `.python-version` equal to the
  `requires-python` floor, and standalone PEP 723 scripts.
- `references/workspace.md` — uv workspaces: use one only for packages that share a lockfile, an
  environment and a `requires-python`; the root `pyproject.toml` with the baseline, `testpaths =
  ["packages"]` and the `"packages/*/tests/**"` ignores; why the gate needs `--all-packages`;
  `tests/<member>_tests/` per member; every member declaring each package it imports; path
  dependencies between separate projects otherwise; what the gate sees and what review holds.
- `references/google-style-guide.md` — a citable index of Google Python Style Guide sections
  (`G-2.4`, `G-3.16`, …), each pointing at the reference that applies it; where the guideline or the
  gate departs from the guide (lint, imports, exceptions, `from __future__`, line length, TODO
  comments, import order, type annotations), the entry says so and quotes the reference that
  governs.

When a reference cross-mentions another rule, read that reference too if it bears on your change.
