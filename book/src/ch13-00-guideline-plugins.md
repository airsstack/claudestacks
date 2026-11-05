# Guidelines (Rust and Python)

Each guideline plugin holds one skill: the engineering rules for a language and the Definition of Done
for it. The Definition of Done is the exact list of commands a change must pass before it counts as
finished. The agents in [claudestacks](ch11-00-claudestacks-plugin.md) read it, run it, and check
their work against it.

| Plugin | Skill | Fires for |
|---|---|---|
| `claudestacks-guideline-rust` | `claudestacks-guideline-rust:rust-guidelines` | `*.rs` files and `Cargo.toml`, in a project with a `Cargo.toml` |
| `claudestacks-guideline-python` | `claudestacks-guideline-python:python-guidelines` | `*.py` and `*.pyi` files and `pyproject.toml`, in a project with a `pyproject.toml` |

Install the one you need, or both. These are commands for a Claude Code session, so there is no output
to show.

```text
/plugin install claudestacks-guideline-rust@claudestacks
/plugin install claudestacks-guideline-python@claudestacks
```

The [Getting Started](ch10-00-plugins-getting-started.md) chapter adds the marketplace first. These
plugins have no hooks and no scripts, so they need no `airsl`.

## How the pieces fit

A guideline plugin carries knowledge and a small `enforcement.json` file. The skill holds the rules.
The [dispatcher in `claudestacks`](ch11-00-claudestacks-plugin.md#the-enforcement-dispatcher) reads the
file, and when you read or edit a matching file it tells Claude to load the skill. The `coder` and
`reviewer` agents also load the guideline for your language when they start, and run its Definition of
Done.

Install a guideline alongside `claudestacks`. Without `claudestacks` the skill still loads when asked
for, but nothing points Claude at it. For a language with no guideline installed, the agents carry on
without one: the `coder` asks you for the quality bar, and the `reviewer` reviews for correctness only
and says the stack rules were unavailable.

The Python plugin does not fire for a standalone script that has no `pyproject.toml` above it.

## Rust

### The Definition of Done

The Rust skill's gate is five commands. Every one must exit `0` with no warnings on a clean checkout.
These are the skill's own list, and this page does not run them.

- `cargo fmt --all -- --check`
- `cargo clippy --workspace --all-targets --all-features -- -D warnings`
- `RUSTDOCFLAGS="-D warnings" cargo doc --workspace --all-features --no-deps`
- `cargo test --workspace --all-targets --all-features`
- `cargo test --workspace --all-features --doc`

The skill states why each is shaped this way:

- Warnings from clippy, rustdoc and the test build are failures, test code included.
- `RUSTDOCFLAGS="-D warnings"` is what makes the doc step a gate. Plain `cargo doc` exits `0` even
  when rustdoc warns.
- There is no separate `cargo build`. Clippy with `-D warnings` already turns compiler warnings into
  errors, and `cargo test --all-targets` does the full build.
- `--all-targets` is required for clippy and the test run. Without it, a failure that lives only in test
  code passes.
- Doctests need their own `--doc` run, because `--all-targets` leaves them out.
- `--all-features` stays in every command so the gate is still correct the day a feature is added.
- While you work on one crate, `-p <crate>` replaces `--workspace`. Use the workspace form for changes
  across crates and before a release.
- A change does not add `#[allow(...)]` to silence the gate. Use `#[expect(...)]` with a reason when
  a suppression is temporary, because it fails once it is no longer needed.

### The rules

The skill loads the reference that matches your task:

| Reference | What it covers |
|---|---|
| `strict-quality` | The policy behind the gate: what zero warnings covers, where a suppression is allowed, and what "green" means for tests and doctests. |
| `strong-types` | No primitive obsession: newtypes for domain values, parsing at construction, builders that enforce required fields, no `bool` parameters for meaning. |
| `static-dispatch` | Generics over `Box<dyn Trait>`, and the narrow cases where a trait object is justified. |
| `mod-rs-export-only` | `mod.rs` and `lib.rs` hold module docs and `mod` and `pub use` lines, and no implementation. |
| `modularity` | One responsibility per unit and one canonical type per concept. |
| `doc-comment-discipline` | Rustdoc and `//` comments are written for downstream engineers, with no internal planning paths, workflow vocabulary or AI names. |
| `unit-test-mandate` | Every source file with logic carries its own `#[cfg(test)] mod tests`, with five named exemptions that must be cited. |
| `microsoft-guidelines` | The Microsoft Pragmatic Rust Guidelines (the `M-*` rules) that this rule set builds on. |
| `workspace` | Workspace layout, the root and member `Cargo.toml`, shared `[workspace.package]`, `[workspace.dependencies]` and `[workspace.lints]`, naming and publishing order. |

## Python

### The Definition of Done

The Python skill's gate runs through `uv`, with `--locked` on every step. Every command must exit `0`
on a clean checkout. These are the skill's own list, and this page does not run them.

- `uv sync --locked --all-groups`, with `--all-packages` added in a uv workspace
- `uv run --locked ruff format --check`
- `uv run --locked ruff check --no-fix`
- `uv run --locked mypy --strict .`
- `uv run --locked pytest`

The skill states why:

- There is no separate warnings bar. pytest turns warnings into failures through the required
  `pyproject.toml` baseline, and Ruff and mypy have no warning level that exits `0`.
- A Ruff configuration warning, such as selecting a rule that conflicts with the formatter, still exits
  `0`. A configuration that prints one fails review.
- `--locked` makes a stale `uv.lock` fail the gate instead of being rewritten.
- `--no-fix` keeps the `ruff check` step a check. Without it, a project that sets `fix = true` would pass
  while rewriting its source.
- `--strict` stays on the `mypy` command line even though the baseline also sets it, so the gate states
  its own bar.
- In a uv workspace the gate runs from the root, and `--all-packages` makes the sync include every
  member.
- There is no separate `uv lock --check`, because a stale lock already fails the sync step. There is no
  coverage threshold.
- The gate runs on the interpreter that `.python-version` names. Keep it equal to the `requires-python`
  floor: `3.12` for a library, `3.14` for an application.
- `uv` is the one prerequisite. Every other gate tool comes from the `dev` dependency group, pinned
  exactly so `uv.lock` fixes the versions.
- Adopting the baseline on a project that does not meet it turns the gate red. The guideline offers no
  weaker tier. The gate cannot detect a missing baseline, so a review has to check that it is there.

### The rules

| Reference | What it covers |
|---|---|
| `strict-quality` | The policy behind the gate: the required `pyproject.toml` baseline, what each flag enforces, suppression rules and the reviewer checklist. |
| `typing` | Modern typing: PEP 695 type parameters, `X \| None`, `@override`, `assert_never` over unions, `TypeIs` over `TypeGuard`. |
| `strong-types` | `NewType` for identifiers, frozen dataclasses that validate, enums and `Literal` for closed sets, keyword-only `bool` parameters. |
| `protocols-and-composition` | Choose an abstraction by coupling: a concrete type, then a callable, then a `Protocol` the consumer owns, then an ABC only to share code. |
| `init-export-only` | What an `__init__.py` may hold: a docstring, a sorted `__all__` and absolute re-exports. |
| `modularity` | One responsibility per class, module and function, no import cycles, and no module named after a standard-library module. |
| `docstring-discipline` | A Google-convention docstring on every public item, docstrings and comments that are true of the code, and no planning paths or AI names. |
| `test-mandate` | A `tests/…/test_<module>.py` for every module with logic, and the exempt kinds. |
| `errors` | One project exception hierarchy, `raise … from` in every handler, and no catch-all `except` outside a re-raise or a logged isolation point. |
| `idioms` | No mutable defaults, `pathlib` over `os.path`, explicit `encoding=`, `logging` over `print` in libraries, `asyncio.TaskGroup` over `gather`. |
| `project-layout` | The `src/` layout, `tests/` at the root, which files are committed, and `py.typed` in libraries. |
| `workspace` | uv workspaces: when to use one, the root `pyproject.toml`, and why the gate needs `--all-packages`. |
| `google-style-guide` | An index of Google Python Style Guide sections, each pointing at the reference that applies it and noting where the guideline departs from the guide. |
