# claudestacks-guideline-python

Python engineering guidelines and a strict Definition-of-Done for Claude Code, delivered as a single
lazily-loaded skill: `claudestacks-guideline-python:python-guidelines`.

The skill loads only when you (or an agent) are editing Python files or a `pyproject.toml`, so it
costs no context the rest of the time. The `claudestacks` plugin's execution agents invoke it to
obtain the Python DoD and rules when they touch Python code; it is equally useful on its own.

## Install

```
/plugin marketplace add airsstack/claudestacks
/plugin install claudestacks-guideline-python@claudestacks
```

Knowledge + an `enforcement.json` manifest. The skill carries the rules; the
`claudestacks` plugin's dispatcher reads the manifest and surfaces this skill at
edit/design time for `*.py`, `*.pyi` and `pyproject.toml` files in a project that has a
`pyproject.toml`. Installed without the `claudestacks` plugin it degrades to
knowledge-only (the skill still loads on demand, but nothing proactively
surfaces it).

A standalone PEP 723 script with no `pyproject.toml` above it is not surfaced; this is accepted,
not a defect.

## What it provides

- **Definition of Done** — the pass/fail gate for every Python change, run through `uv` with
  `--locked` on every step: `uv sync --locked --all-groups`, then `ruff format --check`,
  `ruff check --no-fix`, `mypy --strict .`, and `pytest`. Every command exits `0`. In a uv workspace
  the sync adds `--all-packages` and the gate runs from the root.
- **Rule references** (progressive disclosure, loaded on demand): strict-quality, typing,
  strong-types, protocols-and-composition, init-export-only, modularity, docstring-discipline,
  test-mandate, errors, idioms, project-layout, workspace.

## How it pairs with `claudestacks`

The main plugin's agents are language-agnostic; they look up the DoD and rules from whichever
`*-guidelines` skill is installed. Install this alongside `claudestacks` to give those agents a Python
DoD; omit it for non-Python projects (the agents degrade gracefully).

## License

Apache-2.0. See [LICENSE](./LICENSE).
