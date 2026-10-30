# Python — Strict Quality Bar

Non-negotiable quality gates for every Python change. A change is **not done** until every command
in [Definition of Done](#definition-of-done) exits `0` on a clean checkout.

This file is the policy behind that gate: which configuration a project must carry, how the gate
turns that configuration into pass/fail, and what review holds that no tool does.

**Evidence.** Behaviour claims below were observed on 2026-10-29 with uv 0.13.6, ruff 0.17.3,
mypy 2.4.1 and pytest 9.2.0 on CPython 3.12.16, and are marked *observed*. Claims about what a tool
documents give the document's URL and the words quoted from it; those quotes were fetched on
2026-10-29 from URLs that track each tool's default branch, so the live text can have moved since.

## Zero failures — everywhere

- Every gate command MUST exit `0`. There is no separate warnings bar: Ruff reports violations and
  mypy reports errors, both with a non-zero exit, and pytest turns warnings into failures through
  `filterwarnings = ["error"]`. (Ruff *configuration* warnings are the exception; see below.)
- Formatting, lint, type and test failures are all gate failures; none is advisory.
- Adopting the baseline on a project that does not meet it turns the gate red. There is no weaker
  tier.
- **The gate cannot detect a missing baseline; review holds its presence.** A project that kept the
  `dev` pins but carried none of the `[tool.*]` tables, with a public function that has no
  docstring and calls `print()`, passed all five gate commands with exit `0` (*observed*, uv
  0.13.6).

### The required `pyproject.toml` baseline

Every project carries at least these tables. The pins are the versions the baseline was proven on;
a project pins its own gate tools exactly (`==`) so `uv.lock` fixes the versions the gate runs.

```toml
[dependency-groups]
dev = ["mypy==2.4.1", "pytest==9.2.0", "ruff==0.17.3"]

[tool.ruff.lint]
extend-select = [
  "E", "W", "I", "UP", "B", "SIM", "RUF", "ANN", "D", "PT", "S", "TRY", "PL", "N", "C4",
  "PTH", "RET", "ARG", "ERA", "PGH", "T20", "BLE", "A", "DTZ", "PERF", "FURB", "PIE", "FBT",
]

[tool.ruff.lint.pydocstyle]
convention = "google"

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["S101", "PLR2004", "D"]

[tool.mypy]
strict = true
warn_unreachable = true
enable_error_code = ["explicit-override"]

[tool.pytest]
minversion = "9.0"
strict = true
filterwarnings = ["error"]
addopts = ["--import-mode=importlib", "--doctest-modules"]
testpaths = ["tests", "src"]
```

- **A project may add rules or tighten settings; it may not remove any.** Review rejects a weakened
  baseline, including a pytest `strict_*` key set to `false`: pytest documents that "If you
  explicitly set an individual strictness option, it takes precedence over ``strict``"
  (`https://raw.githubusercontent.com/pytest-dev/pytest/main/doc/en/reference/reference.rst`,
  `strict`), so `strict = true` can be undone key by key.
- **The list is `extend-select` on top of Ruff's defaults, never `select = ["ALL"]`.**
- **Changing the guideline's list.** The list above is the proven starting point. It changes only on
  recorded evidence of a conflict (a family that clashes with another family or with the formatter
  on a real codebase), and whatever the change ships is re-proved by running the gate on a clean
  project and on each defect row below. The list in this file is then the required baseline. This
  governs the guideline's own list, not a project's additions, which the first bullet permits.
- **`explicit-override` is on by hand.** `--strict` does not include it: mypy 2.4.1 with `--strict`
  printed `Success: no issues found in 1 source file` (exit 0) on a method overriding without
  `@override`, and exited 1 with `--enable-error-code explicit-override` (*observed*). Hence
  `enable_error_code` in the baseline.
- **In a uv workspace** the baseline lives in the root `pyproject.toml` with
  `testpaths = ["packages"]` and the test ignores keyed `"packages/*/tests/**"`.

### What the baseline catches

Each defect was applied alone to a fresh copy of a project carrying the baseline and the gate was
run in full; every row failed the step shown (*observed*, exit `1` each).

| Defect | Failing step | Output |
|---|---|---|
| `dependencies = ["idna"]` added, lock not regenerated | sync, and every later `--locked` step | ``error: The lockfile at `uv.lock` needs to be updated, but `--locked` was provided.`` |
| `X=[1,2 ,3]` | `ruff format --check` | `1 file would be reformatted, 3 files already formatted` |
| `fix = true` under `[tool.ruff]` plus an unused `import os` | `ruff check --no-fix` | `F401`; `import os` still in the file afterwards |
| `def scale(value: int, negate: bool)` | `ruff check` | `FBT001` |
| Google `Args:` section missing parameter `b` | `ruff check` | `D417` |
| `print("hi")` in library code | `ruff check` | `T201` |
| `Y = 1  # noqa: E501` (suppresses nothing) | `ruff check` | `RUF100` |
| `Z: int = 1  # type: ignore` | `ruff check` and `mypy` | `PGH003`; ``Unused "type: ignore" comment  [unused-ignore]`` |
| `raise ValueError(raw)` inside `except ValueError:` | `ruff check` | `B904` |
| `return double("x")` for `double(value: int)` | `mypy --strict .` | `Argument 1 to "double" has incompatible type "str"; expected "int"  [arg-type]` |
| override without `@override` | `mypy --strict .` | `Method "size" is not using @override but is overriding a method in class "probe.core.Base"  [explicit-override]` |
| test calling `warnings.warn("old", DeprecationWarning)` | `pytest` | `FAILED tests/test_warn.py::test_warns - DeprecationWarning: old` |
| doctest expecting `5` from `double(2)` | `pytest` | `FAILED src/probe/core.py::probe.core.double` |

Rule codes come from `uv run --locked ruff check --no-fix --output-format concise`.

## How the gate enforces it

Enforcement is split between command flags (in `../SKILL.md`) and project configuration (the
baseline above), the way the Rust gate splits `-D warnings` from the lint table.

- **`ruff check --no-fix`.** Ruff documents that `ruff check` exits `0` "if no violations were
  found, or if all present violations were fixed automatically"
  (`https://raw.githubusercontent.com/astral-sh/ruff/main/docs/linter.md`, exit codes). A project
  setting `fix = true` would therefore pass while rewriting its source: with `fix = true` and an
  unused import, plain `ruff check` printed `Found 1 error (1 fixed, 0 remaining).`, exited `0` and
  deleted the import, while `ruff check --no-fix` exited `1` with `F401` and left it (*observed*).
- **`--locked` on every step.** A stale `uv.lock` fails the step instead of being silently
  rewritten (first row of the table above, *observed*).
- **No separate `uv lock --check` step.** The stale-lock row shows the sync step already fails and
  every later `--locked` step fails with it.
- **`mypy --strict` stays on the command line** although the baseline sets `strict = true`, so the
  gate states its own bar.
- **`--all-packages` in a uv workspace.** Without it a root that declares `[project]` syncs an
  environment lacking the members, and the gate tests that environment: with such a root and one
  member made by `uv init --lib`, `import core` exited `1` after a plain `uv sync --locked
  --all-groups` and `0` after the same command with `--all-packages` (*observed*). A root with no
  `[project]` table installed the member on the plain sync (*observed*); the flag is harmless
  there, and one command set serves both.
- **`.python-version` equals the `requires-python` floor.** `>=3.12` and `3.12` for a library,
  `>=3.14` and `3.14` for an application; a library is any project published to a package index.
  mypy's `python_version` default "is the version of the Python interpreter used to run mypy"
  (`https://raw.githubusercontent.com/python/mypy/master/docs/source/config_file.rst`,
  `python_version`), uv uses `.python-version` as the default interpreter request ("uv searches for
  a `.python-version` file in the working directory and each of its parents",
  `https://raw.githubusercontent.com/astral-sh/uv/main/docs/concepts/python-versions.md`, "Python
  version files"), and Ruff with no `target-version` falls back "to the minimum version compatible
  with the `requires-python` field"
  (`https://raw.githubusercontent.com/astral-sh/ruff/main/docs/configuration.md`, "Inferring the
  Python version").
  A `.python-version` above the floor therefore type-checks and tests against the newer interpreter
  only; the floor is checked only if the gate runs on it. `uv init --lib --python 3.12` wrote
  `.python-version` containing `3.12` and `requires-python = ">=3.12"` (*observed*).

### Ruff configuration warnings do not fail the gate

Adding `"COM"` to the baseline's `extend-select` made `ruff format --check` print on stderr
``warning: The following rule may cause conflicts when used with the formatter:
`missing-trailing-comma` (`COM812`)…`` and exit `0`; `ruff check --no-fix` also exited `0`
(*observed*). No exit code reports the conflict, so review rejects a configuration that prints any
warning.

## Lint suppressions

- **A suppression names a code**: `# noqa: <CODE>`, `# type: ignore[<code>]`. The blanket forms
  fail through the `PGH` family: `# type: ignore` raised `PGH003`; `# noqa` raised `PGH004`
  (*observed*).
- **A suppression that suppresses nothing fails**: `RUF100` for `# noqa`, and mypy's `unused-ignore`
  for `# type: ignore` (both in the table above), so a suppression cannot outlive its cause.
- **Every suppression carries a reason comment.** No tool requires one; review holds it.

## All tests green — including doctests

Every change MUST pass the gate's `pytest` step (`../SKILL.md`) with the baseline's `addopts`:

- `--doctest-modules` with `testpaths = ["tests", "src"]` collects the doctests in `src/` in the
  same run as the unit tests. A doctest expecting the wrong value failed the `pytest` step
  (*observed*, table above), so doctests are real tests, not examples nobody runs.
- `filterwarnings = ["error"]` makes a `DeprecationWarning` raised in a test a failure (*observed*).
- `--import-mode=importlib` and `strict = true` come from the baseline; a project does not loosen
  them.
- **A skipped test** (`pytest.mark.skip`, `skipif`, `xfail`) carries a reason. The gate catches
  only a boolean `skipif` without `reason=`, which fails the pytest step; a bare `skip` or `xfail`
  passes every step, so review holds the rest (*observed*; see `test-mandate.md`).
- There is no coverage threshold. Coverage is not part of the gate.

## Definition of Done

The command set lives in `../SKILL.md` § Definition of Done (the gate) — one canonical copy, so this
file states the policy and never restates the commands. A change is complete when every command
there exits `0` on a clean checkout (no `.venv`, no tool caches).

### Supply chain

- **`uv audit` runs as an advisory job outside the gate**, for example before merging a significant
  change. Run it as `uv audit --locked --preview-features audit-command`. In uv 0.13.6 `uv audit`
  prints "`uv audit` is experimental and may change without warning" unless that preview flag is
  passed (*observed*), and `uv audit --help` describes `--locked` as "Assert that the `uv.lock` will
  remain unchanged" (*observed*). On the clean project it printed `Found no known vulnerabilities
  and no adverse project statuses in 13 packages` and exited `0`; with `urllib3==1.25.8` locked it
  listed the advisories, printed `Found 22 known vulnerabilities and no adverse project statuses in
  14 packages` and exited `1` (*observed*). Keeping it out of the gate is this guideline's policy,
  not a tool fact: the answer depends on an advisory database that moves, so as a gate step it could
  turn red on a commit that changed nothing.
- **A dependency cooldown SHOULD be set** through `[tool.uv]`, so a release published minutes ago
  cannot reach the lock:

  ```toml
  [tool.uv]
  exclude-newer = "7 days"
  ```

  The baseline's exact pins and this cooldown do not lock together while any pin is younger than
  the window. With the baseline's pins (`mypy==2.4.1`, `pytest==9.2.0`, `ruff==0.17.3`) and
  `"7 days"`, `uv lock` exited `1`: ``Because mypy>2.4.0 was published after the exclude newer time
  and clean:dev depends on mypy==2.4.1, we can conclude that clean:dev's requirements are
  unsatisfiable.`` With the pins moved to releases older than the window (`mypy==2.4.0`,
  `pytest==9.1.1`, `ruff==0.17.1`), `uv lock` exited `0`, wrote `exclude-newer-span = "P7D"` into
  `uv.lock`, `uv sync --locked` exited `0` and pytest reported `2 passed` (*observed*, 2026-10-29,
  when mypy 2.4.1 and ruff 0.17.3 were under 7 days old). An absolute timestamp
  (`exclude-newer = "2026-10-26T00:00:00Z"`) also works;
  `exclude-newer-package = { ruff = "2026-10-26T00:00:00Z" }` limits it to one package.
- **A cooldown makes a newer exact pin unsatisfiable.** Nothing is downgraded silently. With ruff
  0.17.3 (uploaded 2026-10-27 per PyPI) and `exclude-newer-package = { ruff =
  "2026-10-26T00:00:00Z" }`, `uv lock` exited `1`: ``Because ruff>0.17.2 was published after the
  exclude newer time and clean:dev depends on ruff==0.17.3, we can conclude that clean:dev's
  requirements are unsatisfiable.`` Relaxing the pin to `ruff>=0.17` made `uv lock` exit `0` with
  `Updated ruff v0.17.3 -> v0.17.2` (*observed*). So when a cooldown is set, pin each gate tool to a
  release older than the cooldown, or the lock cannot be regenerated.

## Reviewer checklist

Reject the change if:

- Any gate command fails, or the configuration prints a warning (Ruff configuration warnings exit
  `0`).
- A baseline table is absent: `[tool.ruff.lint]`, `[tool.ruff.lint.pydocstyle]`, `[tool.mypy]` or
  `[tool.pytest]`. The gate passes without them (see Zero failures).
- The `pyproject.toml` baseline is weakened: a rule removed from `extend-select`, `select = ["ALL"]`
  introduced, a `strict` flag turned off (including any pytest `strict_*` key set to `false`),
  `--strict` dropped from the mypy command, `filterwarnings` loosened, or `--no-fix` removed.
- A `select =` key appears in `[tool.ruff.lint]`. It replaces Ruff's default rule set, which `LOG015`
  and `G201` depend on: the baseline list moved from `extend-select` to `select` dropped both, and
  `ruff check` exited `0` on a file that violates them (*observed*). Use `extend-select`.
- `fix = true` is set under `[tool.ruff]`.
- `.python-version` differs from the `requires-python` floor.
- A suppression is blanket (`# noqa`, `# type: ignore`), names no code, or has no reason comment.
- A skipped or expected-failure test carries no reason.
- A gate tool is not pinned with `==` in the `dev` group, or is missing from `uv.lock`.
- A cooldown is set and a gate tool is pinned to a release newer than the cooldown.
