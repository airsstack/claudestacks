---
status: approved
created: 2026-09-13
---

# Spec: claudevs documentation and example plugins

This spec gives `claudevs` a Diátaxis docs tree with two tracks of equal weight: plugin authors using
the `claudevs` binary, and Rust callers of the engine library. It adds a set of runnable example
plugins, some deliberately broken, and puts two gates on them so neither can drift from the code. The
example plugins join the existing `claudevs-check` lane. Every Rust snippet in the engine docs is a
doctest run by the existing Definition-of-Done step. The spec also fixes the README claim that
contradicts the code, and updates the two places that describe the `claudevs-check` lane.

Evidence in this spec is `file:line` in this worktree at the time of writing, or a command run in this
design session with its real output. Probe directories were created under the session scratchpad and
deleted afterwards.

## 1. Premises

Each premise below is something a later section depends on.

**P1 — nothing exists to extend.** `ls crates/claudevs` printed `Cargo.toml README.md src tests`, with
no `docs/` or `examples/`. `find crates/claudevs-cli -type f` printed `Cargo.toml`, `src/cli.rs`,
`src/main.rs`, `tests/cli.rs`, with no README.

**P2 — the README contradicts the code on matchers.** `crates/claudevs/README.md:56-60` says each
`matcher` "must compile. Compilation uses the `regex` crate". `crates/claudevs/src/lib.rs:8-11` says
the matcher check "evaluates each hooks.json `matcher` in the two modes the reference defines rather
than compiling it as a Rust regex; a pattern Rust cannot compile is reported as a warning", and
`src/wiring/matchers.rs:10-11` says the checker "no longer compiles a matcher as a Rust regex on its
own authority". The severities agree with the crate docs: `matchers.rs:54,69,80` emit
`Severity::Warning`.

**P3 — the model to mirror.** `crates/clauders/docs/README.md:36-43` maps the four Diátaxis modes to
files, `*/tutorial.md`, `*/how-to.md`, `*/feature-parity.md` plus rustdoc, and `*/explanation.md`
plus `architecture.md` and `divergences.md`. Each clauders example is a directory holding `main.rs` and `README.md`
(`find crates/clauders/examples`).

**P4 — example plugins under `examples/` are not Cargo targets.** Probe: a directory
`crates/claudevs/examples/01_probe/` with `.claude-plugin/plugin.json`, `hooks/gate.sh` and
`tests/a_test.lua` was created, then
`cargo metadata --no-deps | jq '.packages[]|select(.name=="claudevs").targets[]'` was run. Output
listed `lib claudevs` and the five `test` targets, and no `example`. Control: adding
`examples/01_probe/main.rs` and re-running listed `["example"] 01_probe`. So a plugin directory
becomes a Cargo example only if it contains `main.rs`, and no example plugin may contain one.

**P5 — `test --installed` needs a marketplace manifest above the plugin.** Probe:
`crates/claudevs/tests/fixtures/minimal-plugin` was copied to a scratch directory with no ancestor
`.claude-plugin/marketplace.json`, and `claudevs check` was run on it. Output included:

```
  skip  test --installed
        marketplace `…/nomkt/minimal-plugin/../.claude-plugin/marketplace.json`: no `.claude-plugin/marketplace.json` in any ancestor directory; the installed layout is keyed by the marketplace that hosts the plugin

3 stages run, 0 failed, 1 skipped
exit=0
```

The same plugin inside `tests/fixtures/`, which carries `tests/fixtures/.claude-plugin/marketplace.json`,
reported `ok    test --installed` and `4 stages run, 0 failed, 0 skipped`.

**P6 — `validate` warns on a manifest without `author` or `description`.** On a machine with `claude`
2.1.270, `claudevs check crates/claudevs/tests/fixtures/matcher-routing-plugin` printed
`❯ author: No author information provided…`. The installed-layout probe (P8), whose manifest has an
author but no description, printed `❯ description: No description provided…`. Both still reported
`ok    validate`. Under `check --strict` those warnings fail the stage: `crates/claudevs/src/validate.rs:42-57` says
`--strict` "is `-Werror` over the same findings" and `Strictness::Strict` means "Warnings fail".

**P7 — an exit-2 PreToolUse hook satisfies `decision: deny`, and a mismatch fails `test`.** In the P8
probe, a hook that exits 2 and writes to stderr passed a YAML case asserting `decision: deny` and
`stderr_contains` (`ok    test`). When the same case ran where the hook could not work, it reported
`decision: expected Deny, got None` under `FAIL  test --installed`, with exit 1.

**P8 — a plugin can pass `test` and fail only `test --installed`.** Probe: a plugin `p` with hook
`sh "${CLAUDE_PLUGIN_ROOT}/hooks/gate.sh"`, where `gate.sh` sources `"$CLAUDE_PLUGIN_ROOT/../shared/msg.sh"`
(unbraced, outside the plugin), under a marketplace directory holding `shared/msg.sh`. `claudevs check p`
printed `ok    wiring` / `0 errors, 0 warnings`, `ok    test`, then:

```
  FAIL  test --installed
          FAIL  blocks
                decision: expected Deny, got None
                stderr: expected to contain `blocked-by-shared`, got "…/cache/probe-mkt/p/0.1.0/hooks/gate.sh: line 1: …/cache/probe-mkt/p/0.1.0/../shared/msg.sh: No such file or directory\n"
…
4 stages run, 1 failed, 0 skipped
exit=1
```

`wiring` stayed green because `refs` matches only the braced form: `src/wiring/refs.rs:30` is
`\$\{CLAUDE_PLUGIN_ROOT\}(?<tail>/[^\s"'`\\]*)?`.

**P9 — a dangling or escaping braced reference fails `wiring`.** `refs` findings are
`Severity::Error` (`refs.rs:99`), with messages "escapes the plugin root" (`refs.rs:115`) and "does not
exist" (`refs.rs:121`). `claudevs check crates/claudevs/tests/fixtures/escape-plugin` printed
`FAIL  wiring` / `error  refs  hooks/hooks.json:6  \`${CLAUDE_PLUGIN_ROOT}/../gate.sh\` escapes the plugin root`,
with exit 1.

**P10 — the case surface the examples exercise exists as described.**

- A case is exactly one of hook (`event:`), script (`invocation:`) or flow (`steps:`)
  (`src/case/model.rs:125-147`, `:225-232`).
- `Invocation` has `argv` and `env` (`model.rs:37-43`).
- A step has `run`, `expect` and `apply_fixture`, with exactly one of `run` or `apply_fixture`
  (`model.rs:110-120`, `:248-253`).
- `project:` takes a bare or tagged fixture name (`model.rs:199-211`).
- `expect` fields are `exit`, `decision`, `output`, `context_contains`, `stdout_contains`,
  `stderr_contains` and `files_exist` (`model.rs:66-88`). `output` accepts only `"none"` and only on
  hook cases (`model.rs:258-267`).
- Case events are `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `SessionStart` and `SessionEnd`
  (`src/types/hook_event.rs:16-27`).
- A fixture carrying `.gitinit` gets `git init` (`src/harness/project.rs:4`, `:115`).
- Injected context comes from `hookSpecificOutput.additionalContext`, or from bare stdout on events
  whose catalogue entry marks `stdout_is_context` (`src/harness/semantics.rs:16-21`, `:116-125`). There
  are unit tests for SessionStart and UserPromptSubmit bare stdout (`semantics.rs:238`, `:244`).
- The Lua `t` handle registers `fixture`, `project`, `apply_fixture`, `hook`, `script`,
  `skill_command` and `json` (`src/harness/t_module.rs:118,133,155,210,252,310,332`).
- Discovery reads `<plugin>/tests/`, picks up `*.yaml`/`*.yml` and `*_test.lua`/`test_*.lua`, and
  skips `tests/fixtures/` (`src/case/discover.rs:28,57-62,73-77`).
- `claudevs.toml` `[[native]] run = "…"` runs a native suite: `minimal-plugin` printed
  `ok    native: sh -c 'echo native-suite-ok' (exit 0)`.
- An unreferenced script is a `Severity::Warning` (`src/wiring/invocations.rs:187`), and
  `dead-script-plugin` printed `warn   invocations  hooks/orphan.sh …` with exit 0.

**P11 — the CLI surface, from the built binary.** `claudevs --help` lists `test`, `migrate`, `check` and
`doctor`. `claudevs test --help` shows `[PATH]` (default `.`), `--case <CASE>`, `--installed` and `--json`.
`claudevs check --help` shows `[PATH]`, `--strict` and `--json`.

**P12 — report JSON shapes.**

- `claudevs test --json minimal-plugin` has scalar paths `outcomes.[].name`, `outcomes.[].verdict`,
  `native.[].command`, `native.[].exit` and `native.[].output`.
- `claudevs check --json` has `stages.[].name|status|detail`, and every `detail` is a JSON string
  holding the human-rendered stage text. For example, the `test` stage detail begins
  `"  ok    blocks-lockfile\n…"`. It is not a nested report.
- `claudevs doctor --json` has `probes[]` of `{name, status, detail}` for `claude binary`,
  `plugin manifest`, `cases`, `marketplace` and `install layout`.

**P13 — markdown can be compiled as doctests with no new warnings.** Two probe crates on the pinned
toolchain (`rust-toolchain.toml:12`, `1.94.1`):

- Probe A had `#[cfg(doctest)] mod docs;` in `lib.rs` and `src/docs.rs` holding a private
  `#[doc = include_str!("../docs/engine.md")] struct EngineDocs;`. With an `assert_eq!(n, 3)` snippet,
  `cargo +1.94.1 test --doc` printed
  `test src/../docs/engine.md - docs::EngineDocs (line 3) ... FAILED` and
  `error: doctest failed, to rerun pass \`--doc\``. With the snippet corrected, it printed `... ok` /
  `1 passed`.
- Probe B used the shape section 4.2 prescribes: `#[cfg(doctest)] mod docs_doctests;`, and
  `src/docs_doctests.rs` holding a private `#[doc = include_str!("../docs/engine/tutorial.md")] struct EngineTutorial;`.
  Lints were set as in the workspace (`missing_docs`, `unreachable_pub`, clippy `pedantic` and
  `nursery`; `Cargo.toml:67-82`). It printed
  `test src/../docs/engine/tutorial.md - docs_doctests::EngineTutorial (line 3) ... ok`, and both
  `cargo clippy --all-targets -- -D warnings` and `RUSTDOCFLAGS="-D warnings" cargo doc --no-deps`
  finished with no warning.
- Probe C used the shape section 4.2 prescribes, with the full workspace lint set: `mod docs_doctests;`
  not gated, `#[cfg(doctest)]` on each struct, and a `#[cfg(test)]` guard test.
  - An untagged fence holding a file tree failed `cargo test --doc` with
    `error: unknown start of token: \u{2514}` and `error[E0425]: cannot find value \`plugin\` in this scope`.
    Tagged `text`, the same fence passed.
  - A guard test filtering with `name.ends_with(".md")` failed clippy with
    `error: case-sensitive file extension comparison`. A `Path::extension` filter was clean.
  - With `docs/engine/how-to.md` present but not wired in, `cargo test --all-targets` printed
    `docs/engine/how-to.md is not compiled as a doctest` / `test result: FAILED`. With it wired in,
    it printed `... ok`.
  - `cargo test --doc`, `cargo clippy --all-targets -- -D warnings` and
    `RUSTDOCFLAGS="-D warnings" cargo doc --no-deps` then all finished clean.

**P14 — the lane and CI job to extend.**

- `Makefile.toml:165-324` is task `claudevs-check`. `_run` (`:225-236`) runs
  `cargo run -q -p claudevs-cli -- check "$root/$plugin"` against `root="crates/claudevs/tests/fixtures"`
  (`:212`). `expect_no_fail` (`:252-273`) and `expect_stage_fail` (`:275-284`) assert the exit code
  and a `^  FAIL  <stage>$` or `^  ok    wiring$` line.
- The eight fixture calls are at `:297,298,299,300,301,309,314,323`.
- CI job `claudevs-check` (`.github/workflows/ci.yml:64-91`) is named `claudevs fixture corpus`
  (`:65`), runs `cargo make claudevs-check` (`:91`), and has no `claude` on the runner (`:88-89`).
- The root `CLAUDE.md:182-183` describes the lane as running "over the fixture plugin corpus in
  `crates/claudevs/tests/fixtures/`".

## 2. Docs tree

```
crates/claudevs/docs/
├─ README.md            index
├─ cli/                 plugin-author track
│  ├─ tutorial.md
│  ├─ how-to.md
│  ├─ reference.md
│  └─ explanation.md
├─ engine/              Rust-caller track
│  ├─ tutorial.md
│  ├─ how-to.md
│  └─ explanation.md
└─ architecture.md
```

The tree mirrors P3 with one change of shape. clauders' reference quadrant is `feature-parity.md`
plus rustdoc, because it measures itself against official SDKs. claudevs has no official counterpart,
so it gets no parity or divergences file. Its reference is `cli/reference.md` for the binary and
rustdoc for the engine.

What each file must cover:

| File | Mode | Must cover |
|---|---|---|
| `docs/README.md` | index | A two-track table (who it is for, what it needs, where to start in each mode), the mode→file table, a pointer to `examples/`, and `cargo doc -p claudevs --no-deps --open` for rustdoc. |
| `cli/tutorial.md` | tutorial | One linear path from an existing plugin to a passing `check`: run `doctor`, write a first YAML hook case, `test`, `check`, break the hook and read the FAIL, then `test --installed`. Every command shown is one the reader runs. |
| `cli/how-to.md` | how-to | Recipes indexed by goal: assert a decision, context, or silence (`output: none`); a script case with `env`; a flow with a project fixture, `.gitinit`, `apply_fixture` and `files_exist`; Lua data cases and scripted cases with `t`; native suites; `--case`; `migrate`; `--json` in CI; `--strict`; reading a `skip`. Each recipe links the example that shows it. |
| `cli/reference.md` | reference | Commands, flags, defaults and exit codes; discovery rules; every case field per kind and its validation errors; the `t` API; `claudevs.toml`; the default payload per event and the environment variables given to spawned hooks; `check` stages, statuses and skip conditions; wiring checkers and severities; `doctor` probes; the JSON shape of each report, including that `check`'s `detail` is rendered text (P12). |
| `cli/explanation.md` | explanation | Why a deterministic harness sits between `claude plugin validate` and `claude plugin eval`; cases assert meaning, not mechanics (`model.rs:60-62`); a skip is an environment gap, never a plugin defect; what the installed layout catches (P8); why the case event set is narrower than the event catalogue (`hook_event.rs:1-9`); why matcher divergences are warnings (P2). |
| `engine/tutorial.md` | tutorial | Run a suite from Rust, render it, map it to an exit code. |
| `engine/how-to.md` | how-to | Produce JSON reports; run `check` and `doctor` from code; run the wiring checkers alone; load and migrate cases. |
| `engine/explanation.md` | explanation | How the case model, harness, wiring, layout, validate, check, doctor and report parts relate from a caller's point of view, and what `#[non_exhaustive]` on the public types means for a caller. |
| `docs/architecture.md` | explanation | The module map and the data flow from a plugin directory to a report, for both tracks. |

The engine track's entry points are the crate-root re-exports `run_suite`, `run_suite_installed`,
`run_case`, the `render_*` functions and the `*exit_code` functions (`src/lib.rs:33-37`), plus the
module functions `claudevs::check::run(plugin_dir: &Path, strictness: Strictness) -> Result<CheckReport>`
(`src/check.rs:70`) and `claudevs::doctor::run(plugin_dir: &Path) -> Diagnosis` (`src/doctor.rs:86`).
Both modules are public (`src/lib.rs:19,21`).

## 3. Example plugins

```
crates/claudevs/examples/
├─ .claude-plugin/marketplace.json     required by P5
├─ README.md                           index table + how to run one
├─ 01_hook_decision/
├─ 02_hook_decision_broken/
├─ 03_session_context/
├─ 04_script_and_flow/
├─ 05_lua_cases/
├─ 06_native_suite/
├─ 07_wiring_broken/
└─ 08_installed_broken/
```

| Example | Shows | `claudevs check` must end |
|---|---|---|
| `01_hook_decision` | a PreToolUse gate; YAML hook cases with `decision` and `stderr_contains`; default and overlaid payloads | exit 0, no FAIL |
| `02_hook_decision_broken` | the same plugin with a defect in the gate, and the verdict lines it produces (P7) | exit 1, `FAIL  test` |
| `03_session_context` | SessionStart / UserPromptSubmit context through `context_contains`, and `output: none` (P10) | exit 0, no FAIL |
| `04_script_and_flow` | a script case with `invocation.env`; a flow with `steps`, a `project` fixture carrying `.gitinit`, `apply_fixture` and `files_exist` | exit 0, no FAIL |
| `05_lua_cases` | data-Lua cases, including generated ones, and scripted cases using `t.hook`, `t.script`, `t.skill_command` and `t.json`; the README quotes `claudevs migrate tests/<case>.yaml` stdout from a real run rather than committing a second copy of the case, since `migrate --write` replaces the YAML with `<stem>_test.lua` (`crates/claudevs-cli/src/cli.rs:131-150`) | exit 0, no FAIL |
| `06_native_suite` | `claudevs.toml` `[[native]]` | exit 0, no FAIL |
| `07_wiring_broken` | a braced `${CLAUDE_PLUGIN_ROOT}/…` reference that does not resolve (P9) | exit 1, `FAIL  wiring` |
| `08_installed_broken` | a hook that reaches outside the plugin root, passing `test` and failing only `test --installed` (P8) | exit 1, `FAIL  test --installed` |

Rules every example follows:

- Its directory is a plugin root: `.claude-plugin/plugin.json` with `name`, `version`, `description`
  and `author`, which avoids the two manifest warnings P6 observed, plus `tests/` and a `README.md`.
  No gate depends on `validate` being warning-free: CI has no `claude`, and a non-strict warning does
  not fail the stage.
- It contains no `main.rs` (P4).
- Its `README.md` shows the run command
  `cargo run -q -p claudevs-cli -- check crates/claudevs/examples/<name>`, what the example shows, and
  the relevant part of the expected output.
- A `*_broken` example's README says what is wrong and which stage reports it.
- `08_installed_broken` needs a file outside its own root to reach. That file lives under
  `crates/claudevs/examples/` beside the example, and that directory's README says why it is there.
- Outputs quoted in any README come from a real run in the same change, with machine-specific temp
  paths elided as `…`.

## 4. Gates

### 4.1 Example gate

The `claudevs-check` task (P14) grows to cover `examples/` without a second task or CI job. This is a
deliberate reading of the intent's "runs in CI next to `cargo make claudevs-check`": the fixtures and
the examples ask the same question, whether `claudevs check` still ends where it should. A second task
would duplicate `_run` and the two assertion functions. One lane and one job also means CI and a local
run stay the same command.

- `_run` takes a full plugin path instead of `root` + name. The eight fixture calls pass
  `crates/claudevs/tests/fixtures/<name>` and keep their current expectations.
- The example calls are:

  ```
  expect_no_fail    crates/claudevs/examples/01_hook_decision   0
  expect_stage_fail crates/claudevs/examples/02_hook_decision_broken 1 test
  expect_no_fail    crates/claudevs/examples/03_session_context 0
  expect_no_fail    crates/claudevs/examples/04_script_and_flow 0
  expect_no_fail    crates/claudevs/examples/05_lua_cases       0
  expect_no_fail    crates/claudevs/examples/06_native_suite    0
  expect_stage_fail crates/claudevs/examples/07_wiring_broken   1 wiring
  expect_stage_fail crates/claudevs/examples/08_installed_broken 1 "test --installed"
  ```

- The task's `description` and the CI job `name` (`ci.yml:65`) name both fixtures and examples.
- The passing expectations must not depend on `claude` being installed, because the runner has none
  (P14). `expect_no_fail` already anchors on `ok    wiring` for that reason (`Makefile.toml:260-271`).

Every broken example's expectation is proven red before it is trusted. It must be seen failing its
expectation with the defect removed, and passing with the defect present.

### 4.2 Snippet gate

- `crates/claudevs/src/lib.rs` gains `mod docs_doctests;`, a module declaration, which keeps `lib.rs`
  export-only.
- `crates/claudevs/src/docs_doctests.rs` holds one private unit struct per `docs/engine/*.md` file,
  each gated `#[cfg(doctest)]` and carrying `#[doc = include_str!("../docs/engine/<file>.md")]`.
- The file claims no unit-test exemption, because none of the five categories fits it
  (`unit-test-mandate.md:19-23`). It carries a `#[cfg(test)] mod tests` instead. That test lists
  `docs/engine/*.md` under `CARGO_MANIFEST_DIR` and asserts the file's own source
  (`include_str!("docs_doctests.rs")`) holds an `include_str!` for each one. A new engine doc that is
  not wired in as a doctest then fails `cargo test --all-targets` (P13).
- The extension filter compares with `Path::extension`, not `ends_with(".md")`. Clippy pedantic
  rejects the latter (P13).
- The `test-doc` step of the Definition of Done (`cargo test --workspace --all-features --doc`,
  `Makefile.toml:88-91`) then compiles and runs every Rust block in those files.
- rustdoc compiles an untagged fence as Rust (P13), so every non-Rust fence in `docs/engine/*.md`
  carries a language tag (`text`, `console`, `yaml`, `lua`, `json`).
- A snippet that cannot run meaningfully, such as one needing a real plugin on disk, is marked
  `no_run` so it still type-checks. `ignore` is not used.

## 5. Fixes to existing text

- `crates/claudevs/README.md`: replace the matcher paragraph (`:56-60`) with a description that
  matches P2, and link `docs/README.md` and `examples/README.md`. Every other behavioural sentence in
  the README is re-checked against the source or a run in the same change, and corrected if wrong.
- Root `CLAUDE.md:182-183`: say that `cargo make claudevs-check` covers the fixtures and the example
  plugins.

## 6. Accuracy and wording rules for the shipped text

These apply to everything under `crates/claudevs/docs/`, `crates/claudevs/examples/`, and the crate
README:

- Every behavioural claim is checked in the same change against the source, or against a real run of
  the built binary. Quoted output is pasted from that run.
- Counts that an ordinary edit could change are avoided or re-counted.
- Shipped text cites symbols, never `file:line`: `doc-comment-discipline.md:44` rule 5, and the
  forbidden zone at `:89`.
- The banned development vocabulary in `crates/clauders/CLAUDE.md` ("Docs describe the software, never
  the work that produced it") applies unchanged.
- Where the docs and the code disagree, the code is right and the docs are fixed. A disagreement that
  reveals a behaviour defect is reported to the author, not fixed under this spec.

## 7. Non-goals

- Changing the case format, the CLI, the checkers, or any claudevs behaviour.
- The adoption flow, a case-generation skill, and cases for the plugins under `plugins/`. These belong
  to `2026-08-29-claudevs-plugin-adoption`.
- A README or docs tree for `crates/claudevs-cli`.
- Rust `[[example]]` programs for the engine.
- Restructuring `crates/claudevs/tests/fixtures/`, the corpus lane, or `crates/clauders/docs/`.
- A new CI job or cargo-make task.
