---
status: approved
created: 2026-10-29
built-on: 1505727386b7
---

# Spec: claudestacks-guideline-python — a Definition of Done and rule references for modern Python

This spec adds `plugins/claudestacks-guideline-python/`, the Python counterpart of
`claudestacks-guideline-rust`: a single lazily-loaded skill, `python-guidelines`, whose
`SKILL.md` holds a five-step command gate and an index of thirteen rule references, plus an
`enforcement.json` that lets the `claudestacks` dispatcher surface the skill when a Python
file is edited inside a `pyproject.toml` project. It rewrites the two lines of the
`claudestacks` agents that assume Rust's test placement and review checklist, wires the new
plugin into the marketplace and the repository text, and deletes the learning document that
currently occupies the plugin directory.

## 1. Design premises

Every premise below was proven on 2026-10-29. External documents were fetched with
`curl -sS -L <url> -o <file>` to session scratch and are cited as `<url> :<line>` at that
fetch; tool behaviour is cited as the command and its output. Tool versions used throughout:
uv 0.13.6 (`uvx --from uv@0.13.6 uv --version` → `uv 0.13.6 (329bf9448 2026-10-26
aarch64-apple-darwin)`), ruff 0.17.3, mypy 2.4.1, pytest 9.2.0, CPython 3.12.16.

### 1.1 The dispatcher needs no change

- A manifest is read for `stack`, `skill`, `detect`, `match`, `phase`
  (`plugins/claudestacks/hooks/lib/enforce.lua:303-322`). `detect` entries are literal file
  names tested in the file's directory and each ancestor (`lib/enforce.lua:341-358`), so a
  glob cannot be a marker.
- **Probe.** A fake plugin directory holding the §2.2 `enforcement.json`, a registry naming it
  through `AIRSSTACK_ENFORCE_REGISTRY`, and `plugins/claudestacks/hooks/enforce.lua --explain`
  run over five paths, each with a fresh `TMPDIR`:

  | Path | Trace |
  |---|---|
  | `proj/src/pkg/m.py` (with `proj/pyproject.toml`) | `EMIT claudestacks-guideline-python:python-guidelines`, `outcome: 1 pointer(s)` |
  | `proj/src/pkg/m.pyi` | `EMIT …`, `outcome: 1 pointer(s)` |
  | `proj/pyproject.toml` | `EMIT …`, `outcome: 1 pointer(s)` |
  | `proj/tests/test_m.py` | `EMIT …`, `outcome: 1 pointer(s)` |
  | `script/s.py` (no `pyproject.toml` anywhere above) | `GATE 2 no detect marker`, `outcome: 0 pointer(s)` |

  `match` was tested against the basename (`match path: m.py`). The dispatcher takes the
  repository from the process's working directory, not from the file: `explain` sets
  `cwd = path.absolute(".")` (`plugins/claudestacks/hooks/enforce.lua:49`), and
  `path_for_matching` falls back to the basename for a file outside the toplevel of that cwd
  (`lib/enforce.lua:176-196`). The probe ran with its working directory in this repository and
  its files outside it. With the working directory at the root of the file's own repository the
  repo-relative path is tested; that case is proven in §8, not here.

### 1.2 The gate's steps fail when they should

A probe project was made with `uv init --lib --python 3.12 base`, given the dev pins and the
exact `pyproject.toml` baseline in §4.1, a Google-docstring `src/base/core.py` with one
doctest, and one test. Every gate step (§3) exited `0` on it. Each defect below was applied
alone to a fresh copy of that final baseline, and the gate run in full:

| Defect | Step that failed (exit) | Evidence |
|---|---|---|
| `dependencies = ["idna"]` added, lock not regenerated | step 1 (1), and steps 2–5 (1) | `error: The lockfile at \`uv.lock\` needs to be updated, but \`--locked\` was provided.` |
| `X=[1,2 ,3]` | 2 `ruff format --check` (1) | `1 file would be reformatted, 3 files already formatted` |
| `fix = true` under `[tool.ruff]` plus `import os` | 3 `ruff check --no-fix` (1) | rule `F401`; `import os` still present afterwards (`grep -c '^import os'` → 1) |
| `def scale(value: int, negate: bool)` | 3 (1) | `FBT001` |
| Google `Args:` section missing parameter `b` | 3 (1) | `D417` |
| `print("hi")` in library code | 3 (1) | `T201` |
| `Y = 1  # noqa: E501` (suppresses nothing) | 3 (1) | `RUF100` |
| `Z: int = 1  # type: ignore` | 3 (1) and 4 (1) | `PGH003`; mypy `Unused "type: ignore" comment [unused-ignore]` |
| `raise ValueError(raw)` inside `except ValueError:` | 3 (1) | `B904` |
| `return double("x")` | 4 `mypy --strict .` (1) | `Argument 1 to "double" has incompatible type "str"; expected "int" [arg-type]` |
| override without `@override` | 4 (1) | `Method "size" is not using @override but is overriding a method in class "base.core.Base" [explicit-override]` |
| test calling `warnings.warn("old", DeprecationWarning)` | 5 `pytest` (1) | `FAILED tests/test_core.py::test_warns - DeprecationWarning: old` |
| doctest expecting `5` from `double(2)` | 5 (1) | `FAILED src/base/core.py::base.core.double` |

Rule codes were read with `uv run --locked ruff check --no-fix --output-format concise`.
Supporting documentation:

- `ruff check` exits `0` "if no violations were found, or if all present violations were fixed
  automatically" (`https://raw.githubusercontent.com/astral-sh/ruff/main/docs/linter.md`
  :745) — why step 3 carries `--no-fix`.
- pytest `strict = true` enables `strict_config`, `strict_markers`,
  `strict_parametrization_ids` and `strict_xfail`, and "If you explicitly set an individual
  strictness option, it takes precedence over ``strict``"
  (`https://raw.githubusercontent.com/pytest-dev/pytest/main/doc/en/reference/reference.rst`
  :2437-2450) — so a project could weaken `strict` key by key, which §4.1 forbids.
- Without `enable_error_code = ["explicit-override"]`, `uvx --python 3.12 mypy@2.4.1 --strict
  o.py` on the same override printed `Success: no issues found in 1 source file`, exit 0; with
  `--enable-error-code explicit-override` it exited 1.
- A separate `uv lock --check` step adds nothing: the stale-lock row shows step 1 already fails,
  and every later `--locked` step fails with it.

### 1.3 The minimum Python version is only checked if the gate runs on it

- mypy's `python_version` "default is the version of the Python interpreter used to run mypy"
  (`https://raw.githubusercontent.com/python/mypy/master/docs/source/config_file.rst`
  :435-436).
- Ruff, with no `target-version`, falls back "to the minimum version compatible with the
  `requires-python` field in a nearby `pyproject.toml`"
  (`https://raw.githubusercontent.com/astral-sh/ruff/main/docs/configuration.md` :308).
- `uv init --lib --python 3.12 base` wrote `.python-version` containing `3.12` and
  `requires-python = ">=3.12"`, plus `src/base/py.typed`.
- uv uses `.python-version` as the default interpreter request: "uv searches for a
  `.python-version` file in the working directory and each of its parents"
  (`https://raw.githubusercontent.com/astral-sh/uv/main/docs/concepts/python-versions.md`
  :59-61). The §1.2 probe ran on CPython 3.12.16 accordingly.

So a project whose `.python-version` sits above its `requires-python` floor type-checks and
tests against the newer interpreter only.

### 1.4 Workspaces need `--all-packages`

Probe: a virtual root (`[tool.uv.workspace] members = ["packages/*"]`, no `[build-system]`) and
one member made with `uv init --lib packages/core`, then `uv lock`.

```
uv sync --locked --all-groups                    exit 0
  import core after plain sync:                  exit 1
uv sync --locked --all-groups --all-packages     exit 0
  import core after --all-packages:              ok
  import core after a later plain sync:          exit 1
uv run --locked python -c "import core"  (after an --all-packages sync)   ok, exit 0
```

The full gate in a workspace, with the §4.1 baseline in the virtual root's `pyproject.toml`
(`testpaths = ["packages"]`, per-file ignores keyed `"packages/*/tests/**"`) and two members
`core` and `api`, each with `src/<m>/` and the §1.6 test layout:

```
uv sync --locked --all-groups --all-packages     exit 0
uv run --locked ruff format --check              exit 0 | 10 files already formatted
uv run --locked ruff check --no-fix              exit 0 | All checks passed!
uv run --locked mypy --strict .                  exit 0 | Success: no issues found in 8 source files
uv run --locked pytest -q                        exit 0 | 4 passed
```

Defects planted in a member, each in a fresh copy: `import os` appended to
`packages/core/src/core/mod.py` → `ruff check --no-fix` exit 1 (`E402`); a function returning
`"x"` as `int` there → `mypy --strict .` exit 1 (`Incompatible return value type`); a failing
test in `packages/api/tests/api_tests/` → `pytest` exit 1.

uv's documentation: workspaces suit members without conflicting requirements and a shared
environment (`https://raw.githubusercontent.com/astral-sh/uv/main/docs/concepts/projects/workspaces.md`
:177-200); `requires-python` is the intersection of all members' ranges (:202-205); "uv can't
ensure that packages don't import dependencies declared by another workspace member" (:209).

### 1.5 Language and layout facts the references build on

- `typing.TypeAlias`: "deprecated:: 3.12 — `TypeAlias` is deprecated in favor of the `type`
  statement" (`https://raw.githubusercontent.com/python/cpython/3.15/Doc/library/typing.rst`
  :1078-1080).
- PEP 695 (type parameter syntax) and PEP 698 (`@override`) are Python 3.12 features
  (`https://raw.githubusercontent.com/python/cpython/main/Doc/whatsnew/3.12.rst` :187, :538).
- pytest "supports two common test layouts", the first being "Tests outside application code"
  (`https://raw.githubusercontent.com/pytest-dev/pytest/main/doc/en/explanation/goodpractices.rst`
  :124-133), and recommends "``importlib`` import mode" for new projects (:154).
- The Google Python Style Guide numbers its rules (`https://raw.githubusercontent.com/google/styleguide/gh-pages/pyguide.md`):
  2.2 Imports (:145), 2.3 Packages (:230), 2.4 Exceptions (:309), 2.12 Default Argument Values
  (:929), 2.20 Modern Python: from \_\_future\_\_ imports (:1438), 2.21 Type Annotated Code
  (:1519), 3.8 Comments and Docstrings (:2090), 3.16 Naming (:3117), 3.19 Type Annotations
  (:3408).

### 1.6 A mirrored `tests/` tree needs `__init__.py` files for mypy

A mirrored tree can hold two test files with the same name. `mypy --strict .` was run on each
shape below with its cache removed first (`.mypy_cache` deleted):

| Shape | mypy |
|---|---|
| single project, `tests/a/test_models.py` and `tests/b/test_models.py`, no `__init__.py` | exit 2, `Duplicate module named "test_models"` |
| same, with `explicit_package_bases = true` (with or without `mypy_path = ["src"]`) | exit 2, same error |
| same, with `__init__.py` in `tests/`, `tests/a/`, `tests/b/` | exit 0 and the full gate green; a planted wrong-return-type in `src/base/a/models.py` → exit 1 |
| workspace, `__init__.py` in `packages/core/tests/` and `packages/api/tests/` | exit 2, `Duplicate module named "tests"` |
| workspace, each member's tests in `packages/<m>/tests/<m>_tests/` with `__init__.py` | exit 0 (§1.4) |

pytest passed every shape under `--import-mode=importlib`. An earlier run that appeared to
show `explicit_package_bases` fixing the single-project case was an artifact of a warm mypy
cache; the cold-cache rows above supersede it.

## 2. Plugin layout and repository wiring

### 2.1 Files

```
plugins/claudestacks-guideline-python/
├── .claude-plugin/plugin.json     name claudestacks-guideline-python, version 0.1.0,
│                                  description "Python engineering guidelines and
│                                  Definition-of-Done, delivered as a lazily-loaded skill."
│                                  (parallel to the Rust manifest's :4), license Apache-2.0,
│                                  same author/homepage/repository as
│                                  plugins/claudestacks-guideline-rust/.claude-plugin/plugin.json,
│                                  keywords python, guidelines, definition-of-done, code-quality
├── enforcement.json               §2.2
├── README.md                      same sections as the Rust README: install, what it
│                                  provides, how it pairs with claudestacks, license
├── LICENSE                        Apache-2.0, identical text to the Rust plugin's
└── skills/python-guidelines/
    ├── SKILL.md                   frontmatter name: python-guidelines, and a description
    │                              in the Rust skill's form (its SKILL.md:3): "Use when
    │                              writing or editing Python code or pyproject.toml —
    │                              supplies the Python Definition-of-Done … Read the
    │                              matching reference before applying a rule."; §3 gate +
    │                              §5 index
    └── references/                the thirteen files of §5
```

`skills/python-guidelines/modern-python.md` is deleted.

### 2.2 `enforcement.json`

```json
{
  "stack": "python",
  "detect": ["pyproject.toml"],
  "match": ["**/*.py", "**/*.pyi", "**/pyproject.toml"],
  "skill": "claudestacks-guideline-python:python-guidelines",
  "phase": ["code", "design"]
}
```

A standalone PEP 723 script with no `pyproject.toml` above it is not surfaced (§1.1, last row);
this is accepted, not a defect.

### 2.3 Repository text

| File | Change |
|---|---|
| `.claude-plugin/marketplace.json` | add an entry after the Rust one (`:20-22`): name, `./plugins/claudestacks-guideline-python`, a description parallel to the Rust entry's |
| `README.md` | "Five plugins" at `:120` becomes "Six plugins"; add a row after `:127`, a dependency line after `:153`, an install line after `:168` |
| `CLAUDE.md` | add a plugin-table row after `:236` |
| `plugins/claudestacks/README.md` | `:8` names both guideline plugins as examples |
| `.claude/settings.json` | add `"claudestacks-guideline-python@claudestacks": false` to `enabledPlugins`, where every other marketplace plugin is already listed (`:7-13`) |

`CLAUDE.md:173` ("The pass/fail gate … lives in the `claudestacks-guideline-rust` plugin")
describes this repository's own Rust gate and stays as it is.

## 3. The gate — `SKILL.md` § Definition of Done

```bash
uv sync --locked --all-groups                # add --all-packages in a uv workspace
uv run --locked ruff format --check
uv run --locked ruff check --no-fix
uv run --locked mypy --strict .
uv run --locked pytest
```

Rules of the gate, stated in `SKILL.md` the way the Rust skill states its own:

- Every command exits `0`. There is no separate warnings bar to state: pytest turns warnings
  into failures through the baseline (§4.1), and Ruff and mypy have no warning severity that
  exits `0` in this configuration.
- **`--locked` on every step**, so a stale `uv.lock` fails the gate instead of being silently
  rewritten (§1.2, first row).
- **`--no-fix` is what keeps step 3 a check** (§1.2, `fix = true` row).
- **`--strict` stays on the command line** even though the baseline sets `strict = true`, so the
  gate states its own bar as the Rust gate states `-D warnings`.
- **`--all-packages` in a workspace**: without it the gate tests an environment without the
  members (§1.4). In a workspace the gate runs from the root, and the §4.1 baseline lives in
  the root `pyproject.toml` with `testpaths = ["packages"]` and the test ignores keyed
  `"packages/*/tests/**"` (§1.4).
- **No `uv lock --check` step** (§1.2) and **no coverage threshold** (author decision,
  `intent.md` Constraints).
- The gate runs on the interpreter `.python-version` names, which §4.2 fixes to the
  `requires-python` floor.

## 4. `references/strict-quality.md` — the policy behind the gate

### 4.1 The required `pyproject.toml` baseline

Every project carries at least these tables, verbatim from the §1.2 probe:

```toml
[dependency-groups]
dev = ["mypy==<pinned>", "pytest==<pinned>", "ruff==<pinned>"]

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

- Gate tools are pinned exactly (`==`) in the `dev` group so `uv.lock` fixes the versions the
  gate runs.
- A project may add rules or tighten settings; it may not remove any. Review rejects a
  weakened baseline — including a pytest `strict_*` key set to `false`, which overrides
  `strict` (§1.2).
- The list above is the proven starting point. Execution may change it only on recorded
  evidence of a conflict, and re-proves whatever it ships (§8, row 3); the list in the
  shipped `strict-quality.md` is then the required baseline.
- The rule list is `extend-select` on top of Ruff's defaults, never `select = ["ALL"]`
  (author decision).

### 4.2 Policy

- **`.python-version` equals the `requires-python` floor**: `>=3.12` and `3.12` for a library,
  `>=3.14` and `3.14` for an application (§1.3; author decisions). A library is any project
  published to a package index.
- **Suppressions name a code** — `# noqa: <CODE>`, `# type: ignore[<code>]`. Blanket forms fail
  through `PGH`; suppressions that suppress nothing fail through `RUF100` and mypy's
  `unused-ignore` (§1.2). Every suppression also carries a reason comment, held by review: no
  tool requires one.
- **A skipped test** (`pytest.mark.skip`, `skipif`, `xfail`) carries a reason, held by review.
- **Ruff configuration warnings do not fail the gate.** Adding `"COM"` to the baseline's
  `extend-select` made `ruff format --check` print `warning: The following rule may cause
  conflicts when used with the formatter: \`missing-trailing-comma\` (\`COM812\`)…` on stderr
  and exit `0`; `ruff check --no-fix` also exited `0`. Review therefore rejects a configuration
  that prints any warning.
- **Supply chain**: `uv audit` runs as an advisory job outside the gate; a dependency cooldown
  (`[tool.uv] exclude-newer`) is a SHOULD (author decisions). The exact `uv audit` invocation
  and the cooldown syntax are proven when the reference is written (§9).

## 5. The reference set

`SKILL.md` indexes thirteen files under `references/`, each read on demand. Every rule in a
file cites its source — a PEP, the typing specification, a tool's documentation or observed
behaviour, or a Google Python Style Guide section — at the precision §1 uses. The rule text is
written and grounded during execution; this section fixes each file's scope.

| File | The bar | Rust counterpart | Primary sources |
|---|---|---|---|
| `strict-quality.md` | §4 | `strict-quality.md` | §1.2, §1.3 |
| `typing.md` | PEP 695 syntax (`def f[T]`, `class C[T]`, `type X = …`), `X \| None`, `collections.abc` generics, `@override` on every override (enforced, §4.1), `assert_never` closing every `match` over a union or enum, no `TypeAlias` (deprecated, §1.5), `TypeIs` over `TypeGuard` where the floor provides it, 3.15-only features only when the floor allows them, no `from __future__ import annotations` or quoted forward references when the floor is 3.14 | — | PEP 695, 698, 742, 749; typing spec; Google 2.21, 3.19. Google 2.20 recommends `from __future__` imports; the reference cites it as the rule it overrides at a 3.14 floor |
| `strong-types.md` | domain values get types: `NewType` for identifiers, frozen slotted dataclasses that validate in `__post_init__`, `Enum`/`StrEnum`/`Literal` for closed sets, `bool` parameters keyword-only | `strong-types.md` | typing spec; `dataclasses` and `enum` docs; Google 2.21 |
| `protocols-and-composition.md` | prefer, in order: a concrete type, a callable, a `Protocol` at a module boundary, an ABC only to share implementation; composition over inheritance; never rely on `@runtime_checkable` for signature checks | `static-dispatch.md` | PEP 544; typing spec "Protocols"; `abc` docs |
| `init-export-only.md` | `__init__.py` holds a docstring, `__all__`, and re-exports; implementation lives in sibling modules | `mod-rs-export-only.md` | typing spec "Distributing type information"; Google 2.2, 2.3 |
| `modularity.md` | one responsibility per module, one canonical type per concept, no import cycles, no module named after a standard-library module | `modularity.md` | Google 2.2, 2.3; Python import reference |
| `docstring-discipline.md` | Google-convention docstrings on every public module, class and function (PEP 257 underneath); comments and docstrings carry no planning paths, plan identifiers, workflow vocabulary, or AI/agent names | `doc-comment-discipline.md` | PEP 257; Google 3.8; Ruff `D` with `convention = "google"` |
| `test-mandate.md` | every logic-bearing module under `src/` has a matching `tests/…/test_<module>.py`; every directory of the test tree carries an `__init__.py`, and in a workspace each member's tests sit in `tests/<member>_tests/` (§1.6); boundary and error paths are tested, not only the happy path; structural exemptions are named and cited; held by review, not a script | `unit-test-mandate.md` | pytest goodpractices (§1.5); pytest import modes |
| `errors.md` | a project exception hierarchy, `raise … from` inside `except`, no bare or catch-all `except`, `except*` for exception groups | — | Google 2.4; PEP 3134, 654; Ruff `B904`, `BLE`, `TRY` |
| `idioms.md` | no mutable defaults, `pathlib` over `os.path`, explicit `encoding=`, `logging` not `print` in library code, `asyncio.TaskGroup` for concurrent tasks | — | Google 2.12; `pathlib`, `logging`, `asyncio` docs; Ruff `B006`, `PTH`, `T20` |
| `project-layout.md` | `src/` layout, `tests/` at the root, committed files (`pyproject.toml`, `uv.lock`, `.python-version`) and ignored ones (`.venv`, `dist`), `[project]` and `[build-system]` always declared, `py.typed` in libraries, dev tools in `[dependency-groups]`; a short section on standalone PEP 723 scripts | — | PEP 517, 561, 621, 723, 735; packaging guide "src layout vs flat layout"; uv docs |
| `workspace.md` | use a workspace only for packages developed together that can share one lockfile, one environment and one `requires-python`; `--all-packages` in the gate; the baseline in the root `pyproject.toml`; `tests/<member>_tests/` per member; every member declares each package it imports; otherwise separate projects joined by path dependencies | `workspace.md` | §1.4, §1.6 |
| `google-style-guide.md` | a citable index of Google Python Style Guide sections (`G-2.4` …), each pointing at the reference above that applies it, the way `microsoft-guidelines.md` indexes the `M-*` rules | `microsoft-guidelines.md` | §1.5 |

PEP 8 and PEP 257 are the baseline under all of them. The Azure SDK Python guidelines are not
a source (author decision).

## 6. Agent wording

Two lines of the `claudestacks` agents state Rust's rules as instructions
(`plugins/claudestacks/agents/coder.md:32`, `plugins/claudestacks/agents/reviewer.md:24`). A
broader search, `grep -rn -i -e cargo -e "mod\.rs" -e guideline-rust -e colocated -e "dynamic
dispatch" plugins/claudestacks plugins/claudestacks-sdlc`, finds, besides those two, only
worked examples beneath instructions that already generalise to "the matching guideline
skill": `plugins/claudestacks-sdlc/skills/plan/SKILL.md:42-43`, `design/SKILL.md:357-359`,
`execute/SKILL.md:244`, `plan/SKILL.md:193`, `plugins/claudestacks/skills/orchestrate/SKILL.md:61`
(which already names `pyproject.toml`), the sample report lines at
`plugins/claudestacks/agents/reviewer.md:84-85`, and the Rust manifest documented in
`plugins/claudestacks/README.md:148-172`. The rest are tooling lines (`cargo install airsl-cli`, `cargo make`) and the
dispatcher's own Rust test fixtures (`hooks/enforce_test.lua`, `hooks/globs_test.lua`).
None of these changes; `plugins/claudestacks/README.md:8` changes per §2.3.

| Line | After |
|---|---|
| `coder.md:32` | Tests go where the loaded guideline places them — beside the code or in a separate tree — unless a structural exemption it defines applies; cite it inline. |
| `reviewer.md:24` | 2. **Then review the diff** against the guidelines and for correctness: wrong output, crashes, unsoundness, missing tests, workflow/AI vocabulary in comments, leaked external types, and every rule in the loaded guideline's references (for Rust, e.g. primitive obsession, dynamic dispatch where static belongs, table-of-contents modules carrying logic). |

`plugins/claudestacks/.claude-plugin/plugin.json` goes from `0.2.1` (`:3`) to `0.2.2`. A user
who installed from the GitHub marketplace runs a cached copy, and "a manifest that pins
`"version": "1.0.0"` keeps every user on the cached copy until its author changes the string"
(`https://code.claude.com/docs/en/plugins/loading.md` :326; `claude plugin update` "don't
replace the cached copy when it matches", :298). A marketplace added from a local path, as
this repository's own `.claude/settings.json:14-21` does, loads plugins in place "whatever its
version string says" (:304, :211), so the bump matters for installed users only.

## 7. Error handling

- **Plugin not installed.** Unchanged: the coder asks for the quality bar and the reviewer
  reviews for correctness only (`coder.md:18-20`, `reviewer.md:19`).
- **`uv` missing, or a gate tool missing from the lock.** The step's command fails, which fails
  the gate; `SKILL.md` names `uv` as the one prerequisite and the `dev` group as where the
  tools come from.
- **An existing project that does not meet the baseline.** The gate goes red, as intended; the
  guideline does not offer a weaker tier.

## 8. Proof

| Claim | How it is shown |
|---|---|
| The plugin is valid | `claudevs check plugins/claudestacks-guideline-python` exits 0. Today it exits 1: `FAIL validate … No manifest found in directory`. The Rust plugin, as a control, exits 0 (`2 stages run, 0 failed, 2 skipped`). |
| The skill is surfaced inside a git repository | `enforce.lua --explain` with `AIRSSTACK_ENFORCE_REGISTRY` naming a registry whose record points at `plugins/claudestacks-guideline-python` (the §1.1 method, no install into the author's Claude Code), run with its working directory at the root of a throwaway git repository holding a `pyproject.toml`, on a `.py` file in that repository, reports `EMIT claudestacks-guideline-python:python-guidelines`; a `.py` file with no `pyproject.toml` above it reports `GATE 2`. |
| The gate in `SKILL.md` is the gate that was proven | The §1.2 probe re-run from the shipped `SKILL.md` commands and the shipped §4.1 baseline: clean project all `0`, each §1.2 defect fails its step. |
| Every reference rule is grounded | Each rule carries a citation; the reviewer rejects one that does not. |
| The agents defer to the guideline | `grep -n "colocated" plugins/claudestacks/agents/coder.md` finds nothing; `reviewer.md:24` reads as §6. |
| The learning doc is gone | `test ! -e plugins/claudestacks-guideline-python/skills/python-guidelines/modern-python.md` |

## 9. Open risks for the plan

- **The `extend-select` list was proven on small probes.** On a real codebase some families
  may conflict with each other or with the formatter, and Ruff reports formatter conflicts only
  on stderr (§4.2). §4.1 governs how the list may change.
- **Commands not yet run**: `uv audit`, the `exclude-newer` cooldown syntax, and a
  `[tool.uv] required-version` pin. Each enters a reference only once run; until then none is
  in this spec.
- **Pinned versions date.** The references name the versions proven here (§1); the gate pins
  versions per project through the lock, so a later tool release changes nothing until a
  project re-locks.

## 10. Non-goals

- Changing `plugins/claudestacks-guideline-rust/` or the enforcement dispatcher.
- Surfacing the skill for standalone PEP 723 scripts without a `pyproject.toml`.
- Python code, a Python CI lane, or a project template in this repository.
- A coverage threshold, ty, pyright or pyrefly as the gate's checker, `select = ["ALL"]`, or the
  Azure SDK guidelines.
- Enforcing "every module has tests" or suppression reasons with a script.
- Shipping the learning document in any form.
