---
status: approved
created: 2026-10-29
---

# Intent: Python projects get no quality gate and no engineering rules from the claudestacks agents

## Problem

**The claudestacks agents have a Definition of Done for Rust only.** The coder loads "whichever
`*-guidelines` skill matches the project's language" and, when none is installed, asks the user
for the quality bar instead of applying one (`plugins/claudestacks/agents/coder.md:18-20`). The
reviewer in the same position "review[s] for correctness only and say[s] the stack rules were
unavailable" (`plugins/claudestacks/agents/reviewer.md:19`). The marketplace ships exactly one
guideline plugin, `claudestacks-guideline-rust` (`.claude-plugin/marketplace.json:20-21`). A
Python change driven through the suite today therefore reaches the user with no command gate run
and no stack rules checked.

**The agents also carry Rust-shaped wording that would contradict a Python guideline.** The coder
is told "Tests are colocated with the code they cover, per the guidelines"
(`coder.md:32`), and the reviewer's checklist names Rust concerns — "dynamic dispatch where static
belongs, table-of-contents modules carrying logic" (`reviewer.md:24`). Python's test convention,
settled below, is a top-level `tests/` tree, not colocation.

**What exists for Python is a learning aid, not a ruleset.** The only file under
`plugins/claudestacks-guideline-python/` is `skills/python-guidelines/modern-python.md`, an
80,607-byte tutorial written for a human returning to Python. It has no `SKILL.md`, so it does not
load as a skill at all, no plugin manifest, and no `enforcement.json`. Research on 2026-10-29
found claims in it refuted against primary sources, including a code sample whose printed output
is wrong (`modern-python.md:277` prints `[1] [2]` when run, not `[1] [1]`).

**Why now.** The author has real Python work coming and wants to drive it through the suite.

## Affected systems

- `plugins/claudestacks-guideline-python/` — the new plugin. Its counterpart and shape model is
  `plugins/claudestacks-guideline-rust/` (`.claude-plugin/plugin.json`, `enforcement.json`,
  `README.md`, `LICENSE`, `skills/rust-guidelines/SKILL.md` plus nine `references/*.md`).
- `plugins/claudestacks/agents/coder.md` and `agents/reviewer.md` — the stack-specific lines at
  `coder.md:32` and `reviewer.md:24`; the plugin is at version `0.2.1`
  (`plugins/claudestacks/.claude-plugin/plugin.json:3`).
- Repository text naming the guideline plugins: `.claude-plugin/marketplace.json:20-22`,
  `README.md:127`, `:153`, `:168`, `CLAUDE.md:173`, `:236`, `plugins/claudestacks/README.md:8`.
- The enforcement dispatcher in `plugins/claudestacks/hooks/lib/enforce.lua`, which reads each
  guideline plugin's `enforcement.json` (`detect`, `match`, `skill`, `phase`;
  `lib/enforce.lua:303-322`). Read by this chain; whether it must change is for `design`.

Not affected (assumed, overridable): `plugins/claudestacks-guideline-rust/`, the other plugins,
and the three crates.

## Desired outcome

**A Python change driven through the suite meets a gate as strict as Rust's.** With
`claudestacks-guideline-python` installed, the coder and reviewer load a Python Definition of Done
— an ordered command set where every step has been seen to fail on a defect and pass on clean
code — and a set of Python rule references, surfaced at edit time by the enforcement dispatcher
the way the Rust skill is.

**Every rule is grounded.** Each rule and gate step traces to an official spec, a tool's own
documentation, the tool's observed behaviour, or the Google Python Style Guide — never to the
learning doc or to recollection.

**The agents carry no Rust-only assumptions.** Test placement and stack-specific review checks
come from whichever guideline skill is loaded.

The chain is finished when the plugin is installable from the in-repo marketplace, its skill
loads and is surfaced for Python files, the agents defer to it, the repository text lists it, and
the learning doc is gone.

## Constraints

Settled by the author in discussion on 2026-10-29:

- **Same shape as the Rust plugin**: a `SKILL.md` holding the gate and a reference index, rule
  detail in `references/`, an `enforcement.json` for the dispatcher.
- **Minimum Python version**: `requires-python >= 3.12` for libraries, `>= 3.14` for applications.
- **Toolchain**: uv for environments and locking; Ruff for formatting and linting; **mypy
  `--strict`** as the gate's type checker (ty is not used: it is beta, and in research it passed
  unannotated code); pytest for tests.
- **Ruff rules**: a named `extend-select` list on top of Ruff's defaults, never `select = ["ALL"]`.
- **Tests**: a top-level `tests/` tree mirroring `src/`; "every logic module has tests" is held by
  review, not by a script. **No coverage threshold** in the gate.
- **Docstrings**: Google convention, enforced through Ruff's `D` rules.
- **Supply chain**: `uv audit` is an advisory job outside the gate; a dependency cooldown
  (`exclude-newer`) is a SHOULD, not a MUST.
- **Upstream sources**: PEP 8 and PEP 257 as the baseline, the Google Python Style Guide as the
  citable rule source. The Azure SDK Python guidelines are not used.
- **uv workspaces** are covered as the counterpart of the Rust workspace reference.
- **The learning doc is deleted**, not moved or shipped.
- **The agent wording is fixed in this chain**, not a separate one.
- **Evidence discipline**: every external claim in the spec is proven against a fetched artifact
  or a run of the tool, per the `design` skill; the 2026-10-29 research is input to re-prove, not a
  source to cite.

Candidate directions, one line each, for `design` to settle and prove:

- gate: `uv lock --check`, `uv sync --locked --all-groups` (`--all-packages` in a workspace), then
  `uv run --locked` for `ruff format --check`, `ruff check --no-fix`, `mypy --strict`, and `pytest`
  with `strict = true` and `filterwarnings = ["error"]`;
- references: strict-quality, strong-types, protocols-and-composition, init-export-only,
  modularity, docstring-discipline, test-mandate, errors, idioms, project-layout, workspace,
  google-style-guide;
- `enforcement.json`: `detect` `pyproject.toml`, `match` `**/*.py`, `**/*.pyi`,
  `**/pyproject.toml` — and how a standalone PEP 723 script with no `pyproject.toml` is surfaced is
  an open question.

## Non-goals

- **Changing the Rust guideline plugin.**
- **Adding Python code or a Python CI lane to this repository** (assumed, overridable).
- **A project template or scaffolder** (assumed, overridable).
- **Shipping the learning doc** in any form, corrected or not.
- **A coverage threshold, ty, `select = ["ALL"]`, or the Azure SDK guidelines** — each decided
  against above.
- **Enforcing "every module has tests" mechanically.**
