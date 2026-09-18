---
status: done
created: 2026-09-13
depends-on: [01]
---

# claudevs Documentation Implementation Plan

**Goal:** Document claudevs for plugin authors and Rust callers in a Diátaxis tree under `crates/claudevs/docs/` whose Rust snippets the Definition of Done runs as doctests.

**Architecture:** Two tracks mirror `crates/clauders/docs/`: `docs/cli/` (tutorial, how-to, reference, explanation) for the `claudevs` binary and `docs/engine/` (tutorial, how-to, explanation) for the library, with rustdoc as the engine reference, plus `docs/architecture.md` and a `docs/README.md` index. A new private module `src/docs_doctests.rs` includes each `docs/engine/*.md` as the doc comment of a `#[cfg(doctest)]` unit struct, so the existing `test-doc` step runs every Rust block; its `#[cfg(test)]` guard test fails when an engine doc is not wired in. Engine snippets run against plan 01's example plugins by paths relative to the crate root, which is the doctest working directory. The crate README's wrong claims are corrected and it links both trees.

**Tech Stack:** Markdown, rustdoc doctests on Rust 1.94.1, the `claudevs` binary.

**Content authority:** `spec.md` §2 (docs tree and what each file covers), §4.2 (snippet gate), §5 first bullet (crate README), §6 (accuracy and wording rules). Depends on plan 01: engine doctests and CLI docs use `crates/claudevs/examples/`.

---

## File structure

```
crates/claudevs/src/lib.rs                — [modify] declare `mod docs_doctests;`
crates/claudevs/src/docs_doctests.rs      — [create] #[cfg(doctest)] structs including docs/engine/*.md + guard test
crates/claudevs/docs/engine/tutorial.md   — [create] run a suite from Rust, render it, map it to an exit code
crates/claudevs/docs/engine/how-to.md     — [create] JSON, filters, installed layout, check, doctor, wiring, single cases, Lua, migrate
crates/claudevs/docs/engine/explanation.md — [create] how the engine's parts relate; #[non_exhaustive] for callers
crates/claudevs/docs/cli/tutorial.md      — [create] from a plugin to a passing check, a failure, and the installed layout
crates/claudevs/docs/cli/how-to.md        — [create] recipes by goal, each linking an example
crates/claudevs/docs/cli/reference.md     — [create] commands, exit codes, case format, t API, claudevs.toml, stages, checkers, probes, JSON
crates/claudevs/docs/cli/explanation.md   — [create] why the harness exists and behaves as it does
crates/claudevs/docs/architecture.md      — [create] module map and data flow for both tracks
crates/claudevs/docs/README.md            — [create] two-track index, mode→file table, examples, rustdoc
crates/claudevs/README.md                 — [modify] fix refs/invocations/matchers/exit-code claims; link docs and examples
```

### How the doc tasks are specified

Each doc task gives, in order: the file's headings; under each heading, the facts it must state, each followed by the source it was checked against; and every code, command and output block word for word. The executor writes the connecting prose. Sources are for the executor to re-open while writing and are **never copied into the doc** (spec §6: shipped text cites symbols, not `file:line`). Paths without a crate prefix are under `crates/claudevs/src/`.

**Output blocks** marked *recorded* come from runs of the named command. Absolute temp or scratch paths are elided as `…`. CLI docs show the command as `claudevs …`; while writing, run it as `target/debug/claudevs …` after `cargo build -p claudevs-cli`, and paste that run's output, elided the same way.

**Wording rules** for every file under `crates/claudevs/docs/` and for `crates/claudevs/README.md` (spec §6): no `file:line`; none of the vocabulary banned by `crates/clauders/CLAUDE.md:150-160`; counts an ordinary edit could change are avoided unless a doctest asserts them; every fence carries a language tag (`rust`, `text`, `console`, `yaml`, `json`, `toml`, `lua`, `sh`). Task 11 greps for all of these.

**Recurring checks:**

- Snippet gate for one crate: `cargo test -p claudevs --doc`.
- Guard test: `cargo test -p claudevs --lib docs_doctests`.

**Commits:** the `execute` skill reserves committing to the user. Task 11 gives a suggested message; no task runs `git commit`.

### Task 1 — Wire the doctest module with its guard test, starting with the engine tutorial

**Files:**
- Create `crates/claudevs/docs/engine/tutorial.md`
- Create `crates/claudevs/src/docs_doctests.rs`
- Modify `crates/claudevs/src/lib.rs`

**Steps:**

1. Confirm plan 01's examples are present, since every engine snippet runs against them:

   ```
   $ ls -d crates/claudevs/examples/01_hook_decision crates/claudevs/examples/02_hook_decision_broken
   ```

   Expected: both paths listed, exit 0.

2. Create `crates/claudevs/docs/engine/tutorial.md` with these headings and content.

   `# Run a plugin's suite from Rust`

   Opening paragraph facts: this tutorial is for a Rust program that depends on the `claudevs` crate; it runs the cases of an example plugin, prints the report, reads the verdicts, and turns the result into a process exit code.

   `## Before you start`
   - The harness spawns hooks with `sh -c` (`harness/spawn.rs:3-5`) and creates each case's temporary project with `git` (`harness/project.rs:66-97`), so both must be on `PATH`.
   - The snippets use `examples/01_hook_decision` and `examples/02_hook_decision_broken`, paths relative to the `claudevs` crate directory; link `../../examples/README.md`.

   `## Run the suite`

   Fact: `run_suite` finds the case files under the plugin's `tests/` directory, runs every case and every native suite, and returns a `SuiteReport` (`suite.rs:71-131`). An `Err` means claudevs could not run; a failing case is part of the report, not an error (`suite.rs:73-76`).

   Block, verbatim:

   ```rust
   use std::path::Path;

   let plugin = Path::new("examples/01_hook_decision");
   let report = claudevs::run_suite(plugin, &claudevs::SuiteOptions::default())?;

   print!("{}", claudevs::render_human(&report));
   assert!(report.all_green());
   assert_eq!(claudevs::exit_code(&report), 0);
   # Ok::<(), claudevs::Error>(())
   ```

   `## Read what it printed`

   Fact: `render_human` writes one line per case and a summary line (`report/render.rs:127-181`). Recorded output of the block above (from a program making the same calls against the same plugin):

   ```text
     ok    allows-other-files
     ok    asks-for-secrets
     ok    blocks-env-file

   3 passed, 0 failed (3 cases, 0 native suites)
   ```

   `## Look at each verdict`

   Facts: each `CaseOutcome` carries a `name` and a `Verdict`, which is `Pass` or `Fail` with the list of `Mismatch`es (`harness/verdict.rs:13-21`); `Verdict` is `#[non_exhaustive]`, so a `match` needs a wildcard arm (`harness/verdict.rs:15`); link `explanation.md` for why.

   Block, verbatim:

   ```rust
   use std::path::Path;

   use claudevs::Verdict;

   let plugin = Path::new("examples/02_hook_decision_broken");
   let report = claudevs::run_suite(plugin, &claudevs::SuiteOptions::default())?;

   for outcome in &report.outcomes {
       match &outcome.verdict {
           Verdict::Pass => println!("pass  {}", outcome.name),
           Verdict::Fail(mismatches) => {
               println!("fail  {} ({} mismatch)", outcome.name, mismatches.len());
           }
           _ => println!("?     {}", outcome.name),
       }
   }
   assert_eq!(claudevs::exit_code(&report), 1);
   # Ok::<(), claudevs::Error>(())
   ```

   `## Turn it into an exit code`

   Facts: `exit_code` is 0 when every case passed and every native suite exited 0, and 1 otherwise (`report/render.rs:202-206`, `suite.rs:60-68`); 2 is reserved for "claudevs could not run" and no report produces it (`report/render.rs:4-5`), so a program maps an `Err` from `run_suite` to 2 itself, as the `claudevs` binary does (`claudevs-cli/src/cli.rs:121-126`).

   `## Where to go next`

   Links: `how-to.md`, `explanation.md`, `../architecture.md`, and the rustdoc command in a `console` block:

   ```console
   $ cargo doc -p claudevs --no-deps --open
   ```

3. Create `crates/claudevs/src/docs_doctests.rs` with the guard test and no structs yet:

   ```rust
   //! Compiles the engine guides under `docs/engine/` as doctests, so a snippet
   //! that stops compiling or stops passing fails `cargo test --doc`.

   #[cfg(test)]
   mod tests {
       #![expect(
           clippy::unwrap_used,
           reason = "tests unwrap a directory the crate ships"
       )]

       #[test]
       fn every_engine_doc_is_compiled_as_a_doctest() {
           let source = include_str!("docs_doctests.rs");
           let dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("docs/engine");
           let mut docs: Vec<String> = std::fs::read_dir(dir)
               .unwrap()
               .map(|entry| entry.unwrap().file_name().into_string().unwrap())
               .filter(|name| {
                   std::path::Path::new(name)
                       .extension()
                       .is_some_and(|ext| ext == "md")
               })
               .collect();
           docs.sort();
           assert!(!docs.is_empty(), "docs/engine holds no markdown");
           for name in docs {
               let wired = format!("include_str!(\"../docs/engine/{name}\")");
               assert!(
                   source.contains(&wired),
                   "docs/engine/{name} is not compiled as a doctest"
               );
           }
       }
   }
   ```

4. In `crates/claudevs/src/lib.rs`, replace:

   ```rust
   mod error;
   mod native;
   ```

   with:

   ```rust
   mod docs_doctests;
   mod error;
   mod native;
   ```

   `lib.rs` stays export-only: this is a module declaration (`references/mod-rs-export-only.md` in `claudestacks-guideline-rust`).

5. Run the guard test and confirm it fails for the unwired doc:

   ```
   $ cargo test -p claudevs --lib docs_doctests
   ```

   Expected: `test result: FAILED`, with the panic message `docs/engine/tutorial.md is not compiled as a doctest` (the same design failed this way for `how-to.md` in spec P13).

6. In `crates/claudevs/src/docs_doctests.rs`, insert between the module doc and `#[cfg(test)]`:

   ```rust
   #[cfg(doctest)]
   #[doc = include_str!("../docs/engine/tutorial.md")]
   struct EngineTutorial;

   ```

7. Run the guard test again. Expected: `test docs_doctests::tests::every_engine_doc_is_compiled_as_a_doctest ... ok`.

8. Run the snippet gate:

   ```
   $ cargo test -p claudevs --doc
   ```

   Expected: two new lines, each ending `... ok`, of the form `test crates/claudevs/src/../docs/engine/tutorial.md - docs_doctests::EngineTutorial (line N) ... ok`, and `test result: ok`. Both blocks passed as doctests in a probe crate that depended on `claudevs` and held copies of the example plugins.

9. Prove the gate catches a wrong snippet: in `docs/engine/tutorial.md`, change `assert_eq!(claudevs::exit_code(&report), 1);` to `assert_eq!(claudevs::exit_code(&report), 0);` and re-run `cargo test -p claudevs --doc`. Expected: that doctest `... FAILED` and `test result: FAILED`. Change it back and re-run; expected `test result: ok`.

10. Format-check and lint the crate:

    ```
    $ cargo fmt --all -- --check
    $ cargo clippy -p claudevs --all-targets --all-features -- -D warnings
    $ RUSTDOCFLAGS="-D warnings" cargo doc -p claudevs --all-features --no-deps
    ```

    Expected: all three exit 0 with no warning or diff. The module shape passed clippy and rustdoc under the workspace lint set in spec P13. Under the workspace `rustfmt.toml` (`max_width = 100`), `rustfmt --check` rejected the one-line `#![expect(clippy::unwrap_used, reason = …)]` and accepted the four-line form step 3 shows.

### Task 2 — Write docs/engine/how-to.md and wire it in

**Files:**
- Create `crates/claudevs/docs/engine/how-to.md`
- Modify `crates/claudevs/src/docs_doctests.rs`

**Steps:**

1. Create `crates/claudevs/docs/engine/how-to.md`.

   `# claudevs engine how-to`

   Opening facts: recipes for a caller who has done `tutorial.md`; every path is relative to the `claudevs` crate directory and names a plugin under `examples/`.

   `## Produce a JSON report`

   Facts: `render_json` accepts `SuiteReport`, `CheckReport`, `WiringReport` and `Diagnosis`, and nothing else (sealed `Report` trait, `report/render.rs:16-38`); the JSON is the same the binary prints with `--json` (`claudevs-cli/src/cli.rs:111,171,194`); link `../cli/reference.md#json-reports`.

   ```rust
   use std::path::Path;

   let report = claudevs::run_suite(
       Path::new("examples/01_hook_decision"),
       &claudevs::SuiteOptions::default(),
   )?;
   let json = claudevs::render_json(&report)?;
   assert!(json.contains("\"outcomes\""));
   # Ok::<(), claudevs::Error>(())
   ```

   `## Run only some cases`

   Facts: `SuiteOptions` is `#[non_exhaustive]`, so build it with `default()` and set `case_filter` (`suite.rs:22-28`); a case runs when its name contains the filter; a YAML file is matched by its file stem before it is loaded (`suite.rs:93-101`) and a Lua file's cases by entry name (`case/runner.rs:24-36`).

   ```rust
   use std::path::Path;

   let mut options = claudevs::SuiteOptions::default();
   options.case_filter = Some(String::from("blocks"));
   let report = claudevs::run_suite(Path::new("examples/01_hook_decision"), &options)?;
   assert_eq!(report.outcomes.len(), 1);
   # Ok::<(), claudevs::Error>(())
   ```

   `## Run against the installed layout`

   Facts: `run_suite_installed` copies the plugin to `cache/<marketplace>/<plugin>/<version>/` in a temporary directory and runs the same cases with `CLAUDE_PLUGIN_ROOT` pointing there (`suite.rs:133-149`, `layout/installed.rs:1-9,51-56`); it returns `Error::Marketplace` when no ancestor directory holds `.claude-plugin/marketplace.json` (`layout/manifest.rs:110-120`, `error.rs:69-80`); link `../../examples/08_installed_broken/README.md`.

   ```rust
   use std::path::Path;

   let plugin = Path::new("examples/08_installed_broken");
   let options = claudevs::SuiteOptions::default();
   assert!(claudevs::run_suite(plugin, &options)?.all_green());
   assert!(!claudevs::run_suite_installed(plugin, &options)?.all_green());
   # Ok::<(), claudevs::Error>(())
   ```

   `## Run check from code`

   Facts: `claudevs::check::run(plugin_dir, strictness)` runs `validate`, `wiring`, `test` and `test --installed` in that order and always reports all four (`check.rs:85-118`); `Err` only when claudevs itself cannot run, a failing plugin is `Ok` (`check.rs:64-69`); a suite stage is `Skipped` for no case files, no marketplace, or an installed layout that cannot be built, and `Failed` for an unreadable `plugin.json` (`check.rs:141-177`); `Strictness::Strict` fails `validate` on the delegate's warnings (`validate.rs:42-58`); each `Stage.detail` is the human-rendered text of that stage (`check.rs:43,104,162`); `render_check_human` and `check_exit_code` (`report/render.rs:208-248`).

   ```rust
   use std::path::Path;

   use claudevs::{StageStatus, Strictness};

   let report = claudevs::check::run(Path::new("examples/07_wiring_broken"), Strictness::Lenient)?;
   for stage in &report.stages {
       println!("{:<18} {:?}", stage.name, stage.status);
   }
   assert!(
       report
           .stages
           .iter()
           .any(|stage| stage.name == "wiring" && stage.status == StageStatus::Failed)
   );
   assert_eq!(claudevs::check_exit_code(&report), 1);
   # Ok::<(), claudevs::Error>(())
   ```

   `## Diagnose the environment`

   Facts: `claudevs::doctor::run` returns a `Diagnosis`, not a `Result` (`doctor.rs:81-90`); its probes, in order, are `claude binary`, `plugin manifest`, `cases`, `marketplace`, `install layout` (`doctor.rs:99-109`); a probe is `Ok`, `Warning` (only `cases`) or `Gap`, and `all_clear` is false only for a `Gap` (`doctor.rs:11-24,33-45,67-79`); a missing `claude` is a `Gap` (`doctor.rs:112-118`), so code that runs where `claude` may be absent should not require `all_clear`.

   ```rust
   use std::path::Path;

   use claudevs::ProbeStatus;

   let diagnosis = claudevs::doctor::run(Path::new("examples/01_hook_decision"));
   print!("{}", claudevs::render_doctor_human(&diagnosis));
   let marketplace = diagnosis.probes.iter().find(|probe| probe.name == "marketplace");
   assert_eq!(marketplace.map(|probe| probe.status), Some(ProbeStatus::Ok));
   ```

   `## Run the wiring checkers alone`

   Facts: `claudevs::wiring::run` runs `refs`, `invocations` and `matchers` in that order (`wiring/run.rs:1-9`); it returns `Error::Io` when the path is not a directory (`wiring/run.rs:15-30`); each checker is also public as `wiring::refs::check`, `wiring::invocations::check` and `wiring::matchers::check`, each returning `Result<Vec<Finding>>` (`wiring/refs.rs:65`, `wiring/invocations.rs:152`, `wiring/matchers.rs:29`); `Finding` has `severity`, `checker`, `file`, `line` and `message` (`wiring/finding.rs:19-33`); `counts()` is `(errors, warnings)` and `all_clear()` is false only for an error (`wiring/finding.rs:43-60`).

   ```rust
   use std::path::Path;

   use claudevs::Severity;

   let report = claudevs::wiring::run(Path::new("examples/07_wiring_broken"))?;
   for finding in &report.findings {
       if finding.severity == Severity::Error {
           println!("{} {}: {}", finding.checker, finding.file, finding.message);
       }
   }
   assert!(!report.all_clear());
   assert_eq!(report.counts(), (1, 0));
   # Ok::<(), claudevs::Error>(())
   ```

   `## Load and run one YAML case`

   Facts: `case::discover` returns the plugin's case files sorted, as `CaseFile::Yaml` or `CaseFile::Lua` (`case/discover.rs:12-54`); `case::load_yaml_case` names the case after the file stem (`case/yaml.rs:13-21`); `run_case(plugin_dir, fixtures_root, case)` runs one case (`suite.rs:159-164`); pass an absolute plugin directory, because `run_suite` canonicalizes its path before children run inside the temporary project and `run_case` uses the path it is given for `CLAUDE_PLUGIN_ROOT` (`suite.rs:78-86,169-170`).

   ```rust
   use claudevs::case::CaseFile;

   let plugin = std::fs::canonicalize("examples/01_hook_decision")?;
   let fixtures = plugin.join("tests/fixtures");
   for file in claudevs::case::discover(&plugin)? {
       if let CaseFile::Yaml(path) = file {
           let case = claudevs::case::load_yaml_case(&path)?;
           let outcome = claudevs::run_case(&plugin, &fixtures, &case)?;
           assert!(matches!(outcome.verdict, claudevs::Verdict::Pass), "{}", outcome.name);
       }
   }
   # Ok::<(), Box<dyn std::error::Error>>(())
   ```

   `## Run one Lua case file`

   Facts: `case::run_lua_file` runs a Lua file's data cases and its scripted cases (`case/runner.rs:11-55`); `case::load_lua_file` with `case::plain_engine()` loads data cases but the engine it builds has no `t` handle, which only `run_lua_file` installs (`case/lua.rs:83-122`).

   ```rust
   let plugin = std::fs::canonicalize("examples/05_lua_cases")?;
   let outcomes = claudevs::case::run_lua_file(
       &plugin,
       &plugin.join("tests/fixtures"),
       &plugin.join("tests/force_push_test.lua"),
       &claudevs::SuiteOptions::default(),
   )?;
   let names: Vec<&str> = outcomes.iter().map(|outcome| outcome.name.as_str()).collect();
   assert!(names.contains(&"plain_push_emits_nothing"));
   # Ok::<(), Box<dyn std::error::Error>>(())
   ```

   `## Convert a YAML case to Lua`

   Facts: `case::migrate_to_lua` loads the YAML case first and returns `Error::CaseLoad` for one that does not load, then produces `return { [<stem>] = { … } }` (`case/migrate.rs:1-20`).

   ```rust
   use std::path::Path;

   let lua = claudevs::case::migrate_to_lua(Path::new(
       "examples/05_lua_cases/tests/allows-plain-push.yaml",
   ))?;
   assert!(lua.starts_with("return {"));
   assert!(lua.contains("[\"allows-plain-push\"]"));
   # Ok::<(), claudevs::Error>(())
   ```

   Every block above passed as a doctest in the probe crate described in Task 1 step 8.

2. Run `cargo test -p claudevs --lib docs_doctests`. Expected: `FAILED`, with `docs/engine/how-to.md is not compiled as a doctest`.

3. In `docs_doctests.rs`, add above `EngineTutorial`:

   ```rust
   #[cfg(doctest)]
   #[doc = include_str!("../docs/engine/how-to.md")]
   struct EngineHowTo;

   ```

4. Run `cargo test -p claudevs --lib docs_doctests`; expected `ok`. Run `cargo test -p claudevs --doc`; expected nine `docs/engine/how-to.md - docs_doctests::EngineHowTo (line N) ... ok` lines and `test result: ok`.

### Task 3 — Write docs/engine/explanation.md and wire it in

**Files:**
- Create `crates/claudevs/docs/engine/explanation.md`
- Modify `crates/claudevs/src/docs_doctests.rs`

**Steps:**

1. Create `crates/claudevs/docs/engine/explanation.md`.

   `# How the claudevs engine fits together`

   `## One type means a test case`
   - YAML files and Lua data tables both deserialize into `RawCase` and become a `Case` through `Case::from_raw`; nothing else models a case (`case/model.rs:1-5`, `case/yaml.rs:1-5`, `case/lua.rs:3-5`).
   - A case is one of three kinds, hook, script or flow (`case/model.rs:122-147`).
   - Expectations state meaning, such as `decision: deny`, and the harness owns translating a run into that meaning (`case/model.rs:60-62`, `harness/semantics.rs:1-5`).

   `## The harness spawns, observes, then judges`
   - A hook command without `args` runs through `sh -c`; one with `args` is spawned directly; a script's argv is spawned directly (`contract/handler.rs:15-28`, `harness/spawn.rs:3-5`).
   - Every spawn has a 30-second timeout, and a killed child is never a pass (`harness/spawn.rs:32`, `harness/verdict.rs:120-124`).
   - `observe` reads a run under its event's rules; `judge` compares the observation with the expectations and lists every mismatch rather than stopping at the first (`harness/semantics.rs:76-134`, `harness/verdict.rs:1-6,115-187`).
   - Cases run in temporary projects, never against the plugin's own checkout (`harness/project.rs:1-9`).

   `## A failing plugin is a verdict, not an error`
   - `Error` means claudevs could not produce a verdict (`error.rs:1-4`); give two or three examples, such as a case file that does not load or a missing fixture (`error.rs:15-31`), and point to the rustdoc for the full set rather than listing it.

   `## Wiring reads files and never runs them`
   - `wiring/mod.rs:1-10`.

   `## validate and layout reach outside the plugin`
   - `validate` hands the plugin to `claude plugin validate` rather than reimplementing manifest checks, and reports `Unavailable` when `claude` cannot run (`validate.rs:1-9,17-37,124-131`).
   - `layout` builds the installed copy the second suite stage runs against (`layout/installed.rs:1-15`).

   `## check and doctor compose the rest`
   - `check.rs:1-10`; `doctor.rs:1-9` (each probe runs the code its stage would run).

   `## Reports are data first`
   - Human text and JSON both come from the same report structs; the sealed `Report` trait limits `render_json` to the crate's own report types (`report/render.rs:16-38`). Do not state how many there are.

   `## Two lists of hook events`
   - `types::HookEvent` lists the events a case can run against; `contract::event` catalogues the events Claude Code documents, which the checkers read; the two are separate on purpose (`types/hook_event.rs:1-9`, `contract/mod.rs:15-18`).

   `## What #[non_exhaustive] means for a caller`
   - Every public type carries it except the validated newtypes in `types` (`CaseName`, `MarketplaceName`, `PluginName`, `PluginVersion`) and their error structs, `InvalidHookEvent`, `case::Invocation` and `harness::TModule` (`types/mod.rs:1-29`). Name them; do not count them.
   - A caller cannot build such a struct with a literal, so it starts from `Default` where one exists and sets fields; a `match` on such an enum needs a wildcard arm.

   Blocks, verbatim:

   ```rust
   let mut options = claudevs::SuiteOptions::default();
   options.case_filter = Some(String::from("blocks"));
   assert_eq!(options.case_filter.as_deref(), Some("blocks"));
   ```

   ```rust
   use claudevs::StageStatus;

   fn mark(status: StageStatus) -> &'static str {
       match status {
           StageStatus::Passed => "ok",
           StageStatus::Failed => "FAIL",
           StageStatus::Skipped => "skip",
           _ => "?",
       }
   }
   assert_eq!(mark(StageStatus::Skipped), "skip");
   ```

   Both passed as doctests in the probe crate. Close with a diagram, verbatim:

   ```text
   plugin dir
     ├─ case::discover ─► load (YAML / Lua) ─► Case
     │                                          │
     │            harness: spawn ─► observe ─► judge ─► Verdict
     │                                                    │
     │                              suite ─► SuiteReport ◄┘
     ├─ wiring::run ─────────────────────────► WiringReport
     ├─ validate::run ───────────────────────► Validation
     └─ layout::Installed ─► suite again ────► SuiteReport

   check::run  = validate + wiring + suite + installed suite ─► CheckReport
   doctor::run = one probe per thing those stages need ───────► Diagnosis
   report      = render_* and *exit_code over any of the above
   ```

2. Run `cargo test -p claudevs --lib docs_doctests`. Expected: `FAILED`, with `docs/engine/explanation.md is not compiled as a doctest`.

3. In `docs_doctests.rs`, add above `EngineHowTo`:

   ```rust
   #[cfg(doctest)]
   #[doc = include_str!("../docs/engine/explanation.md")]
   struct EngineExplanation;

   ```

4. Run `cargo test -p claudevs --lib docs_doctests`; expected `ok`. Run `cargo test -p claudevs --doc`; expected two `EngineExplanation (line N) ... ok` lines, no failure. The `text` diagram does not compile as Rust because it is tagged (spec P13).

### Task 4 — Write docs/cli/tutorial.md

**Files:**
- Create `crates/claudevs/docs/cli/tutorial.md`

**Steps:**

1. Create `crates/claudevs/docs/cli/tutorial.md`. Before writing, run every command below in a fresh temporary directory, in order, with `target/debug/claudevs` (after `cargo build -p claudevs-cli`), and paste those outputs in place of the recorded ones.

   `# Test a plugin with claudevs`

   Opening facts: one path from a plugin with a hook to a passing `claudevs check`, a deliberate failure, and a run against the installed layout.

   `## Install claudevs`

   From a checkout of this repository (recorded: `Installed package `claudevs-cli v0.1.0 …` (executable `claudevs`)`):

   ```console
   $ cargo install --locked --path crates/claudevs-cli
   ```

   Facts: hooks run through `sh` and cases need `git` (`harness/spawn.rs:3-5`, `harness/project.rs:66-97`); `claude` is optional and only the `validate` stage uses it (`validate.rs:1-7`).

   `## The plugin`

   Tree, verbatim:

   ```text
   my-marketplace/
   └── my-plugin/
       ├── .claude-plugin/plugin.json
       └── hooks/
           ├── hooks.json
           └── protect-env.sh
   ```

   `my-marketplace/my-plugin/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "my-plugin",
     "version": "0.1.0",
     "description": "Guards .env files from edits",
     "author": { "name": "You" }
   }
   ```

   `my-marketplace/my-plugin/hooks/hooks.json` and `hooks/protect-env.sh`: exactly the two files of `crates/claudevs/examples/01_hook_decision/hooks/` (plan 01, Task 2 steps 5–6), shown in full in the doc.

   `## Ask what is missing`

   ```console
   $ claudevs doctor my-marketplace/my-plugin
   ```

   Recorded (exit 1):

   ```text
     ok    claude binary: present; `check` delegates its validate stage
     ok    plugin manifest: my-plugin 0.1.0
     warn  cases: no case files found under `…/my-plugin/tests` (cases are `*.yaml`, `*_test.lua` or `test_*.lua` in tests/)
     gap   marketplace: marketplace `…/my-plugin/../.claude-plugin/marketplace.json`: no `.claude-plugin/marketplace.json` in any ancestor directory; the installed layout is keyed by the marketplace that hosts the plugin
     gap   install layout: marketplace `…/my-plugin/../.claude-plugin/marketplace.json`: no `.claude-plugin/marketplace.json` in any ancestor directory; the installed layout is keyed by the marketplace that hosts the plugin

   2 gaps, 1 warning
   ```

   Facts: a `gap` is something the environment lacks and makes the exit code 1; `warn` is about the plugin's content and does not (`doctor.rs:11-24`, `report/render.rs:281-285`). Without `claude` on `PATH` the first line is a gap too (`doctor.rs:112-118`).

   `## Put the plugin in a marketplace`

   `my-marketplace/.claude-plugin/marketplace.json`:

   ```json
   {
     "name": "my-marketplace",
     "owner": { "name": "You" },
     "plugins": []
   }
   ```

   Fact: the installed layout is keyed by the name of the nearest marketplace manifest above the plugin (`layout/manifest.rs:90-106`, `layout/installed.rs:51-56`).

   `## Write your first case`

   `my-marketplace/my-plugin/tests/blocks-env-file.yaml`:

   ```yaml
   event: PreToolUse
   payload:
     tool_input:
       file_path: .env
   expect:
     decision: deny
     stderr_contains: refusing to edit a .env file
   ```

   Facts: `event` makes it a hook case (`case/model.rs:225-243`); `payload` is laid over the event's default payload (`harness/payload.rs:14-49`); `decision: deny` holds for exit code 2 on `PreToolUse` (`harness/semantics.rs:128-131`); YAML files under `tests/` are cases and the file stem is the case name (`case/discover.rs:73-75`, `case/yaml.rs:13-15`).

   `## Run it`

   ```console
   $ claudevs test my-marketplace/my-plugin
   ```

   Recorded (exit 0):

   ```text
     ok    blocks-env-file

   1 passed, 0 failed (1 cases, 0 native suites)
   ```

   `## Run the gate`

   ```console
   $ claudevs check my-marketplace/my-plugin
   ```

   Recorded (exit 0):

   ```text
     ok    validate
           Validating plugin manifest: …/my-plugin/.claude-plugin/plugin.json
           ✔ Validation passed
     ok    wiring
           0 errors, 0 warnings
     ok    test
             ok    blocks-env-file
           1 passed, 0 failed (1 cases, 0 native suites)
     ok    test --installed
             ok    blocks-env-file
           1 passed, 0 failed (1 cases, 0 native suites)

   4 stages run, 0 failed, 0 skipped
   ```

   Fact: the four stages and what each does (`check.rs:1-10`); without `claude` the first reads `skip  validate` and the run still ends at 0 (recorded in plan 01, Task 12 step 2).

   `## Break the hook`

   Instruction: in `protect-env.sh` change `exit 2` to `exit 1`, then:

   ```console
   $ claudevs test my-marketplace/my-plugin
   ```

   Recorded (exit 1):

   ```text
     FAIL  blocks-env-file
           decision: expected Deny, got None
           payload: {"cwd":"…","hook_event_name":"PreToolUse","session_id":"claudevs-test","tool_input":{"file_path":".env"},"tool_name":"Edit"}
           handler: sh "${CLAUDE_PLUGIN_ROOT}/hooks/protect-env.sh"

   0 passed, 1 failed (1 cases, 0 native suites)
   ```

   Facts: read the three lines: the mismatch, the payload the hook received with the default fields filled in, and the handler that ran (`suite.rs:36-47`, `report/render.rs:138-154`); exit 1 is not a `PreToolUse` denial to claudevs (`harness/semantics.rs:128-131`); link `../../examples/02_hook_decision_broken/README.md`.

   `## Fix it and test the installed copy`

   Instruction: change `exit 1` back to `exit 2`, then:

   ```console
   $ claudevs test --installed my-marketplace/my-plugin
   ```

   Recorded (exit 0):

   ```text
     ok    blocks-env-file

   1 passed, 0 failed (1 cases, 0 native suites)
   ```

   Fact: `--installed` runs the same cases against a copy at `cache/<marketplace>/<plugin>/<version>/` (`suite.rs:133-149`); link `../../examples/08_installed_broken/README.md` for a plugin that passes `test` and fails here.

   `## Where to go next`

   Links: `how-to.md`, `reference.md`, `explanation.md`, `../../examples/README.md`.

2. Check the doc's commands match what was run: `grep -n '^\$ claudevs' crates/claudevs/docs/cli/tutorial.md`. Expected: five lines (`doctor`, `test`, `check`, `test`, `test --installed`), in that order.

### Task 5 — Write docs/cli/how-to.md

**Files:**
- Create `crates/claudevs/docs/cli/how-to.md`

**Steps:**

1. Create `crates/claudevs/docs/cli/how-to.md`. Each recipe: a goal heading, the minimum case or command, one or two sentences of facts, and a link to the example that shows it in full. Recorded outputs: re-run and paste.

   `# claudevs how-to`

   `## Assert a hook's decision` — show `tests/blocks-env-file.yaml` from `01_hook_decision`; facts: `decision` is `allow`, `deny`, `ask` or `defer` (`case/model.rs:45-58`); read from exit 2 on `PreToolUse`, `hookSpecificOutput.permissionDecision`, `hookSpecificOutput.decision.behavior`, or a top-level `decision: "block"` (`harness/semantics.rs:7-19,48-74,97-131`). Link `../../examples/01_hook_decision/README.md`.

   `## Assert context a hook adds` — show `tests/deploy-prompt-gets-reminder.yaml` from `03_session_context`; facts: context is `hookSpecificOutput.additionalContext`, or plain stdout on `SessionStart` and `UserPromptSubmit` (`harness/semantics.rs:116-126`, `contract/event.rs:94,106`). Link `03_session_context`.

   `## Assert a hook stays silent` — `expect: { output: none }` in YAML block form; facts: fails on any envelope or context; hook cases only (`harness/verdict.rs:141-145`, `case/model.rs:258-267`). Link `03_session_context`.

   `hook` and `payload_raw` have no recipe here: no example uses them, and spec §2 ties each recipe to an example. `reference.md` documents both fields.

   `## Test a script with its environment` — show `greets-by-name.yaml` from `04_script_and_flow`; facts: argv spawned without a shell, `{project}` in argv and env values is replaced with the project path (`suite.rs:319-340`). Link `04_script_and_flow`.

   `## Test a multi-step flow in a project` — show `new-note-flow.yaml`; facts as in `04_script_and_flow`'s README. Link.

   `## Generate cases in Lua` and `## Script a case with t` — show the loop and one scripted entry from `force_push_test.lua`; link `05_lua_cases` and `reference.md#lua-cases`.

   `## Run the plugin's own test command` — show `claudevs.toml` from `06_native_suite`. Link.

   `## Run only some cases`

   ```console
   $ claudevs test --case blocks crates/claudevs/examples/01_hook_decision
   ```

   Recorded (exit 0):

   ```text
     ok    blocks-env-file

   1 passed, 0 failed (1 cases, 0 native suites)
   ```

   Fact: substring of the case name (`claudevs-cli/src/cli.rs:26-28`, `suite.rs:151-157`). Link `../../examples/01_hook_decision/README.md`.

   `## Convert a YAML case to Lua` — `claudevs migrate <file>` prints, `--write` writes `<stem>_test.lua` with `-` replaced by `_` and deletes the YAML (`claudevs-cli/src/cli.rs:130-164`). Link `05_lua_cases`.

   `## Use JSON in CI`

   ```console
   $ claudevs check --json crates/claudevs/examples/07_wiring_broken | jq -r '.stages[] | select(.status == "failed") | .name'
   wiring
   ```

   Recorded as shown. Facts: `status` is `passed`, `failed` or `skipped`, and `detail` is the stage's rendered text, not nested JSON (`check.rs:21-44`); the exit code of `claudevs check` is the gate, so keep it (for example with `set -o pipefail`). Link `reference.md#json-reports` and `../../examples/07_wiring_broken/README.md`.

   `## Fail on manifest warnings`

   ```console
   $ claudevs check --strict my-marketplace/my-plugin
   ```

   Recorded (exit 1) against a plugin whose `plugin.json` has no `author`, no marketplace above it and no cases:

   ```text
     FAIL  validate
           Validating plugin manifest: …/my-plugin/.claude-plugin/plugin.json
           ⚠ Found 1 warning:
             ❯ author: No author information provided. Consider adding author details for plugin attribution
           ✘ Validation failed (--strict treats warnings as errors)
     ok    wiring
           0 errors, 0 warnings
     skip  test
           no case files found under `…/my-plugin/tests` (cases are `*.yaml`, `*_test.lua` or `test_*.lua` in tests/)
     skip  test --installed
           marketplace `…/my-plugin/../.claude-plugin/marketplace.json`: no `.claude-plugin/marketplace.json` in any ancestor directory; the installed layout is keyed by the marketplace that hosts the plugin

   2 stages run, 1 failed, 2 skipped
   ```

   Facts: without `--strict` the same plugin's `validate` is `ok` with the warning shown and the run ends at 0 (recorded: `✔ Validation passed with warnings`, `2 stages run, 0 failed, 2 skipped`, exit 0); `--strict` only changes anything when `claude` runs (`validate.rs:42-58,124-131`). To reproduce: the tutorial's plugin with `author` removed, before its marketplace manifest and case exist. No example ships a plugin missing `author` (plan 01 gives every manifest one), so this recipe and the next link `tutorial.md` instead of an example.

   `## Read a skip` — use the two `skip` stages from the block above, plus `skip  validate` / ``cannot run `claude`: No such file or directory (os error 2)``; facts: a skip names what the environment lacks and never fails the run; the fixes are a case file, a marketplace manifest, or `claude` on `PATH` (`check.rs:7-10,141-170`, `validate.rs:124-131`). Link `tutorial.md#put-the-plugin-in-a-marketplace` and `../../examples/README.md#without-a-claude-binary`.

2. Verify each linked example exists: `grep -o 'examples/[0-9][0-9]_[a-z_]*' crates/claudevs/docs/cli/how-to.md | sort -u`; expected only names listed by `ls crates/claudevs/examples`.

### Task 6 — Write docs/cli/reference.md

**Files:**
- Create `crates/claudevs/docs/cli/reference.md`

**Steps:**

1. Create `crates/claudevs/docs/cli/reference.md` with these sections, in order. Use tables where a section lists items.

   `# claudevs CLI reference`

   `## Commands` — one subsection per command, each with its `--help` text verbatim in a `text` block. Recorded:

   ```text
   Usage: claudevs <COMMAND>

   Commands:
     test     Run a plugin's case suite plus its declared native suites
     migrate  Convert a YAML case to its data-Lua form
     check    Validate, check wiring, then run the suite in both layouts
     doctor   Report what this environment can and cannot do
     help     Print this message or the help of the given subcommand(s)

   Options:
     -h, --help     Print help
     -V, --version  Print version
   ```

   ```text
   Usage: claudevs test [OPTIONS] [PATH]

   Arguments:
     [PATH]  The plugin directory [default: .]

   Options:
         --case <CASE>  Only run cases whose name contains this substring
         --installed    Run against a throwaway copy in the installed cache layout
         --json         Emit the machine-readable report instead of the human one
     -h, --help         Print help
   ```

   ```text
   Usage: claudevs check [OPTIONS] [PATH]

   Arguments:
     [PATH]  The plugin directory [default: .]

   Options:
         --strict  Fail on the delegate's warnings as well as its errors
         --json    Emit the machine-readable report instead of the human one
     -h, --help    Print help
   ```

   ```text
   Usage: claudevs doctor [OPTIONS] [PATH]

   Arguments:
     [PATH]  The plugin directory [default: .]

   Options:
         --json  Emit the machine-readable report instead of the human one
     -h, --help  Print help
   ```

   ```text
   Usage: claudevs migrate [OPTIONS] <FILE>

   Arguments:
     <FILE>  The YAML case file

   Options:
         --write  Replace the .yaml file with the .lua file instead of printing
     -h, --help   Print help
   ```

   `## Exit codes` — table, rows and sources:

   | Command | 0 | 1 | 2 |
   |---|---|---|---|
   | `test` | every case passed and every native suite exited 0 (`report/render.rs:202-206`, `suite.rs:60-68`) | a case failed, including a YAML case file that does not load (recorded: `did not run: load: …` for an unknown field, exit 1; `suite.rs:103-116`), or a native suite exited non-zero | claudevs could not run: a usage error (recorded: `error: unexpected argument '--bogus' found`, exit 2), a plugin path that does not resolve, no case files (recorded with the tutorial plugin, exit 2), a Lua case file that does not load (recorded: ``cannot load case `…/bad_test.lua` … a case file must return a table``, exit 2), a `hooks/hooks.json` that is not JSON (`suite.rs:189-210`), or a native suite that cannot start (`native/declared.rs:59-76`) — all through `claudevs-cli/src/cli.rs:123-126` |
   | `check` | no stage failed; skips allowed (`check.rs:54-62`, `report/render.rs:244-248`) | at least one stage failed | a plugin path that is not a directory (`wiring/run.rs:15-30`), or any other error a suite stage does not turn into a skip or a failure (`check.rs:176`) |
   | `doctor` | no probe is a gap (`doctor.rs:67-79`) | a probe is a gap; a warning alone never gives 1 | only when `--json` cannot render the report (`claudevs-cli/src/cli.rs:193-199`), which the report types never cause (`error.rs:105-110`) |
   | `migrate` | printed, or written with `--write` | — | the file is not a loadable YAML case, or writing or removing a file failed (`claudevs-cli/src/cli.rs:130-164`) |

   The parenthesised "recorded" notes and sources in the table are evidence for the writer and are not copied into the doc. If the doc quotes an error message, re-run it on a path that does not exist, such as `claudevs check no-such-plugin` (the recorded run printed ``claudevs: walk plugin `…`: No such file or directory (os error 2)``, exit 2).

   `## Case discovery` — `<plugin>/tests/`, recursively, sorted; `*.yaml` and `*.yml` are one case each named by file stem; `*_test.lua` and `test_*.lua` return a table of cases; everything under `tests/fixtures/` is skipped; no case files is an error (`case/discover.rs:1-80`, `case/yaml.rs:13-21`, `error.rs:40-47`). Case names are non-empty and use only `A-Z a-z 0-9 . _ -` (`types/case_name.rs:6-33`).

   `## Case fields` — three tables.
   - Common: `project` (fixture name, or `fixture: <name>`; `case/model.rs:199-211`), `expect`.
   - Hook: `event` (one of `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `SessionStart`, `SessionEnd`; `types/hook_event.rs:14-27`), `hook` (`harness/hooks_file.rs:112-118`), `payload` (object overlaid on the default: objects merge recursively, other values replace; `harness/payload.rs:36-49`), `payload_raw` (`case/model.rs:134-135`).
   - Script: `invocation.argv`, `invocation.env` (`case/model.rs:34-43`); `{project}` substituted in both (`suite.rs:319-340`).
   - Flow: `steps`, each with exactly one of `run` (an invocation) or `apply_fixture` (a fixture name), and an optional `expect` for a `run` step (`case/model.rs:106-120`); a failing step's expectation stops the flow; the top-level `expect` is judged against the last run step, and a flow with no run step accepts only `files_exist` (`suite.rs:353-407`).
   - `expect`: `exit`, `decision`, `output`, `context_contains`, `stdout_contains`, `stderr_contains`, `files_exist` (`case/model.rs:63-88`); every expectation is checked and all mismatches are reported (`harness/verdict.rs:1-6,115-187`).
   - Unknown fields are rejected in cases, invocations, steps and expectations (`case/model.rs:36,64,108,170`).

   `## Case load errors` — the messages, verbatim, in a `text` block:

   ```text
   a case is exactly one of hook (`event:`), script (`invocation:`) or flow (`steps:`); found N
   `payload` and `payload_raw` are mutually exclusive
   flow step N: exactly one of `run` or `apply_fixture`
   `expect.output` only accepts "none", got `VALUE`
   `expect.output` is a hook assertion: only a hook observation records whether anything was emitted, so this expectation could never fail here
   unknown hook event `NAME` (known: PreToolUse, PostToolUse, UserPromptSubmit, SessionStart, SessionEnd)
   invalid case name `NAME`: names are non-empty [A-Za-z0-9._-]
   ```

   Sources: `case/model.rs:214-215,229-231,236,250-252,260-262`, `types/hook_event.rs:30-34`, `types/case_name.rs:11-13`. Also the recorded unknown-field message: ``unknown field `expct`, expected one of `event`, `hook`, `payload`, `payload_raw`, `invocation`, `steps`, `project`, `expect` ``.

   `## Default payloads` — `json` block per event, from `harness/payload.rs:14-31`; `{project}` in any string becomes the temporary project path, in overlays too (`harness/payload.rs:51-75`, `suite.rs:310-316`):

   ```json
   {
     "session_id": "claudevs-test",
     "cwd": "{project}",
     "hook_event_name": "PreToolUse",
     "tool_name": "Edit",
     "tool_input": { "file_path": "{project}/file.txt" }
   }
   ```

   `PostToolUse` has the same shape; `UserPromptSubmit` adds `"prompt": "hello"`; `SessionStart` adds `"source": "startup"`; `SessionEnd` adds `"reason": "exit"`.

   `## How a hook run is read` — decision sources and precedence, context, `emitted` (`harness/semantics.rs:1-134`).

   `## What a spawned command gets` — working directory is the case's project (`suite.rs:165-170,225-244`); environment adds `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PROJECT_DIR` to the inherited one, plus `invocation.env` (`harness/environment.rs`, `harness/spawn.rs:34-58`, `suite.rs:335-338`); hook handler forms (`contract/handler.rs:15-53`); 30-second timeout and its message `timeout: the child timed out and was killed before completing` (`harness/spawn.rs:32`, `report/render.rs:89-91`).

   `## Projects and fixtures` — default project: git repository with `Cargo.toml` and a committed `file.txt` (`harness/project.rs:15-40,64-97`); `project:` copies `tests/fixtures/<name>/`; a `.gitinit` file there runs `git init` and one empty commit and is not copied (`harness/project.rs:99-134`); `apply_fixture` copies a fixture over the project (`harness/project.rs:136-140`).

   `## Lua cases` — data entries (tables) and scripted entries (functions); a scripted case passes by returning (`case/lua.rs:1-81,124-161`). `t` table, from `harness/t_module.rs:4-14`:

   | Function | Returns |
   |---|---|
   | `t.fixture(name)` | path of a fresh temp project seeded from the fixture |
   | `t.project()` | path of a fresh empty temp project |
   | `t.apply_fixture(name, dir)` | overlays a fixture into `dir` |
   | `t.hook(ref, payload?)` | `{exit, stdout, stderr, decision?, context?, emitted}`; `ref` is an event name or a command substring unique across all events |
   | `t.script(argv, opts?)` | `{exit, stdout, stderr}`; `opts.env`, `opts.cwd` (default: the plugin directory, `harness/t_module.rs:224-227`), `opts.stdin` |
   | `t.skill_command(skill, n)` | the n-th fenced command (from 1) in `skills/<skill>/SKILL.md` |
   | `t.json(path)` | the decoded JSON file |

   Path rules: `t.json` and `t.script`'s `cwd` must be inside the plugin directory or a temp project the case created; `t.apply_fixture`'s `dir` only a temp project; `t.skill_command` only the plugin (`harness/t_module.rs:26-40`). The Lua runs confined with no grants; `t` runs on the host and `t.script` can start any program (`harness/t_module.rs:16-24`).

   `## claudevs.toml` — `[[native]]` entries with one key, `run`; spawned with `sh -c` in the plugin directory; only the exit code is asserted; output shown when it is not 0; no file means no native suites; an unknown key is an error (`native/declared.rs:1-84`, `report/render.rs:157-168`).

   `## check stages` — table: stage, what it runs, when it is `skip`, when it is `FAIL`:
   - `validate`: `claude plugin validate [--strict] <path>`; skip when `claude` cannot run; FAIL on non-zero exit (`validate.rs:60-131`, `check.rs:120-139`).
   - `wiring`: the three checkers; never skips; FAIL on any error finding (`check.rs:96-105`).
   - `test`, `test --installed`: the suite, and the suite in the installed layout; skip for no case files, no marketplace manifest above the plugin, or a layout that cannot be built; FAIL when a case or native suite fails, or `plugin.json` cannot be read (`check.rs:107-177`).
   - Human output marks are `ok`, `FAIL`, `skip`; summary `N stages run, N failed, N skipped`, where skipped stages are not counted as run (`report/render.rs:208-242`).

   `## Wiring checkers` — table: checker, severity, what it reports, message form.
   - `refs` (error): `${CLAUDE_PLUGIN_ROOT}/…` references in `.claude-plugin/*.json` and under `hooks/`, `skills/`, `agents/`, `commands/`, outside fenced code blocks; messages ``` `${CLAUDE_PLUGIN_ROOT}/PATH` escapes the plugin root ``` and ``` `${CLAUDE_PLUGIN_ROOT}/PATH` does not exist ``` (`wiring/refs.rs:60-122`, `contract/site.rs:10-66`). The unbraced `$CLAUDE_PLUGIN_ROOT` is not read (`wiring/refs.rs:24-32`).
   - `invocations` (warning): `.sh`, `.lua`, `.py`, `.js` files nothing else in the plugin names; exempt: case files, anything under `tests/`, `__init__.py`/`index.js`/`init.lua`, and files outside `hooks/` with neither a `#!` line nor an executable bit; message ``` `NAME` is referenced by nothing in this plugin ``` (`wiring/invocations.rs:118-213`).
   - `matchers` (error): `hooks/hooks.json` is not JSON, or has no top-level `hooks` object. (warning): an event not in the catalogue, a matcher on an event that takes none, a matcher claudevs cannot evaluate (`wiring/matchers.rs:1-90`).
   - Human form: `  error  CHECKER  FILE[:LINE]  MESSAGE` / `  warn   …`, then `N error(s), N warning(s)` (`report/render.rs:40-67`).

   `## doctor probes` — table of every probe (no count in prose), what each checks, and which status it can take (`doctor.rs:99-193`); marks `ok`, `warn`, `gap`; summary `N gaps, N warnings` (`report/render.rs:250-279`).

   `## JSON reports` — one recorded sample per command, with prose facts: `test` → `outcomes[]` of `{name, verdict}` plus `payload` and `handler` only on a failing hook case, and `native[]` of `{command, exit, output}` (`suite.rs:30-58`, `native/declared.rs:22-32`); `verdict` is the string `"Pass"` or `{"Fail": [mismatch, …]}`, each mismatch an object tagged by `kind` in snake_case (`harness/verdict.rs:13-41`); `check` → `stages[]` of `{name, status, detail}` with `detail` rendered text (`check.rs:34-52`); `doctor` → `probes[]` of `{name, status, detail}` (`doctor.rs:47-65`). Recorded samples:

   `claudevs test --json crates/claudevs/examples/02_hook_decision_broken` (exit 1):

   ```json
   {
     "outcomes": [
       {
         "name": "allows-other-files",
         "verdict": "Pass"
       },
       {
         "name": "asks-for-secrets",
         "verdict": "Pass"
       },
       {
         "name": "blocks-env-file",
         "verdict": {
           "Fail": [
             {
               "kind": "decision",
               "expected": "deny",
               "observed": null
             }
           ]
         },
         "payload": {
           "cwd": "…",
           "hook_event_name": "PreToolUse",
           "session_id": "claudevs-test",
           "tool_input": {
             "file_path": ".env"
           },
           "tool_name": "Edit"
         },
         "handler": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/protect-env.sh\""
       }
     ],
     "native": []
   }
   ```

   `claudevs check --json crates/claudevs/examples/07_wiring_broken` (exit 1):

   ```json
   {
     "stages": [
       {
         "name": "validate",
         "status": "passed",
         "detail": "Validating plugin manifest: …/07_wiring_broken/.claude-plugin/plugin.json\n\n✔ Validation passed\n"
       },
       {
         "name": "wiring",
         "status": "failed",
         "detail": "  error  refs  hooks/hooks.json:9  `${CLAUDE_PLUGIN_ROOT}/hooks/format-on-write.sh` does not exist\n\n1 error, 0 warnings\n"
       },
       {
         "name": "test",
         "status": "passed",
         "detail": "  ok    session-banner\n\n1 passed, 0 failed (1 cases, 0 native suites)\n"
       },
       {
         "name": "test --installed",
         "status": "passed",
         "detail": "  ok    session-banner\n\n1 passed, 0 failed (1 cases, 0 native suites)\n"
       }
     ]
   }
   ```

   `claudevs doctor --json crates/claudevs/examples/01_hook_decision` (exit 0):

   ```json
   {
     "probes": [
       {
         "name": "claude binary",
         "status": "ok",
         "detail": "present; `check` delegates its validate stage"
       },
       {
         "name": "plugin manifest",
         "status": "ok",
         "detail": "hook-decision 0.1.0"
       },
       {
         "name": "cases",
         "status": "ok",
         "detail": "3 case file(s) found"
       },
       {
         "name": "marketplace",
         "status": "ok",
         "detail": "claudevs-examples"
       },
       {
         "name": "install layout",
         "status": "ok",
         "detail": "simulated at …/cache/claudevs-examples/hook-decision/0.1.0"
       }
     ]
   }
   ```

2. Verify every command subsection's help text against the binary: run `target/debug/claudevs --help`, and `target/debug/claudevs <cmd> --help` for `test`, `check`, `doctor`, `migrate`, and diff each against the doc's block (the first line of each command's help, its description, is outside the `Usage:` block and not quoted). Expected: identical.

3. Verify the anchor used by other docs: `grep -n '^## JSON reports$\|^## Lua cases$' crates/claudevs/docs/cli/reference.md`. Expected: two matches (GitHub anchors `#json-reports`, `#lua-cases`).

### Task 7 — Write docs/cli/explanation.md

**Files:**
- Create `crates/claudevs/docs/cli/explanation.md`

**Steps:**

1. Create `crates/claudevs/docs/cli/explanation.md`.

   `# Why claudevs works the way it does`

   `## What sits between validate and a live session` — `claude plugin validate` validates "a plugin or marketplace manifest, or the skills, agents, and commands in a directory" (recorded `claude plugin validate --help`, claude 2.1.270); it does not run a hook. claudevs spawns a plugin's hooks and scripts the way Claude Code would, with fixed payloads in throwaway projects, so the same case gives the same verdict on every run (`lib.rs:1-6`, `harness/project.rs:1-9`). Say nothing about `claude plugin eval` beyond its name.

   `## Cases assert meaning, not mechanics` — `case/model.rs:60-62`, `harness/semantics.rs:1-22`; example: exit 2 and a JSON `permissionDecision` both satisfy `decision`.

   `## A skip is an environment gap` — `check.rs:7-10,141-152`; why a malformed `plugin.json` is a failure rather than a skip (`check.rs:145-148`).

   `## Every stage runs` — a failed stage does not stop later ones, so one run shows every problem (`check.rs:28`, recorded in `07_wiring_broken`).

   `## What the installed layout catches` — `layout/installed.rs:1-15`; link `../../examples/08_installed_broken/README.md`.

   `## Why validation is handed to claude` — `validate.rs:1-9`; lenient by default so a missing `author` does not stop the deterministic stages (`validate.rs:42-49`).

   `## Why cases cover fewer events than hooks.json may use` — `types/hook_event.rs:1-9`.

   `## Why a matcher claudevs cannot evaluate is a warning` — `wiring/matchers.rs:5-11`, `lib.rs:8-11`.

### Task 8 — Write docs/architecture.md

**Files:**
- Create `crates/claudevs/docs/architecture.md`

**Steps:**

1. Create `crates/claudevs/docs/architecture.md`.

   `# claudevs architecture`

   `## Two crates` — `claudevs-cli` builds the `claudevs` binary and is the only crate that uses `clap` (`claudevs-cli/src/cli.rs:1`); `claudevs` is the engine it calls.

   `## Module map` — table of every module in `lib.rs:13-26` with public/private and one line from its module doc: `case` (`case/mod.rs:1`), `check` (`check.rs:1-5`), `contract` (`contract/mod.rs:1-18`), `doctor` (`doctor.rs:1-9`), `harness` (`harness/mod.rs:1-6`), `layout` (`layout/mod.rs:1`), `types` (`types/mod.rs:1`), `validate` (`validate.rs:1-7`), `wiring` (`wiring/mod.rs:1-10`); private, reached through crate-root re-exports: `error` (`error.rs:1-4`), `native` (`native/mod.rs:1`), `report` (`report/mod.rs:1-2`), `suite` (`suite.rs:1-4`). Crate-root re-exports listed from `lib.rs:28-39`.

   `## From a plugin directory to a report` — the diagram from `engine/explanation.md` (Task 3), plus a second `text` diagram for the binary, verbatim:

   ```text
   claudevs test [--installed] ─► run_suite / run_suite_installed ─► render_human | render_json ─► exit_code
   claudevs check              ─► check::run                        ─► render_check_human | render_json ─► check_exit_code
   claudevs doctor             ─► doctor::run                       ─► render_doctor_human | render_json ─► doctor_exit_code
   claudevs migrate            ─► case::migrate_to_lua              ─► stdout, or <stem>_test.lua
   ```

   Sources: `claudevs-cli/src/cli.rs:99-205`.

   `## Where to read next` — links `cli/explanation.md`, `engine/explanation.md`.

### Task 9 — Write docs/README.md

**Files:**
- Create `crates/claudevs/docs/README.md`

**Steps:**

1. Create `crates/claudevs/docs/README.md`, modelled on `crates/clauders/docs/README.md`.

   `# claudevs documentation`

   Opening facts: claudevs tests Claude Code plugins deterministically (`lib.rs:1-6`); two ways to use it; the docs follow Diátaxis, one job per document.

   `## Start here` — table, verbatim structure:

   | | Plugin author | Rust caller |
   |---|---|---|
   | What you use | the `claudevs` binary | the `claudevs` crate |
   | Needs | `sh` and `git` on `PATH`; `claude` for the `validate` stage | `sh` and `git` on `PATH` |
   | Learn it | [tutorial](cli/tutorial.md) | [tutorial](engine/tutorial.md) |
   | Do a specific thing | [how-to](cli/how-to.md) | [how-to](engine/how-to.md) |
   | Look something up | [reference](cli/reference.md) | the rustdoc |
   | Understand the design | [explanation](cli/explanation.md) | [explanation](engine/explanation.md) |

   Sources for "Needs": `harness/spawn.rs:3-5`, `harness/project.rs:66-97`, `validate.rs:1-7`.

   `## Cross-cutting` — [architecture](architecture.md).

   `## The four modes, and which file is which` — table: Tutorial → `*/tutorial.md`; How-to → `*/how-to.md` plus `../examples/`; Reference → `cli/reference.md` plus the rustdoc; Explanation → `*/explanation.md`, `architecture.md`. Then:

   ```console
   $ cargo doc -p claudevs --no-deps --open
   ```

   `## Examples` — link `../examples/README.md`; facts: each example is a plugin run with `claudevs check`, and `cargo make claudevs-check` asserts its outcome.

2. Verify every relative link in the tree resolves:

   ```
   $ grep -rnoE '\]\([^)#]+' crates/claudevs/docs
   ```

   Each output line is `FILE:LINE:](LINK`. For each line, resolve `LINK` against `dirname FILE` and confirm it exists with `ls "$(dirname FILE)/LINK"`, skipping `http` links. The same link text resolves differently from `docs/`, `docs/cli/` and `docs/engine/`, so each line is checked against its own file. Expected: every one exists.

### Task 10 — Correct and link the crate README

**Files:**
- Modify `crates/claudevs/README.md`

**Steps:**

1. After the code block ending at `crates/claudevs/README.md:14`, insert:

   ```markdown

   ## Documentation

   - [`docs/README.md`](docs/README.md) — tutorials, how-to guides, reference and explanation, for plugin
     authors using the `claudevs` binary and for Rust callers of this crate.
   - [`examples/README.md`](examples/README.md) — runnable example plugins, each with its case files and
     the `claudevs check` outcome it produces.
   ```

2. Replace the exit-code sentences at `:34-39`:

   ```markdown
   `test` exits 2 on a usage error, an unreadable plugin directory, or a suite with
   no cases to discover — a plugin with no cases is a broken discovery convention,
   not a green suite. Inside `check` that same condition is an environment gap for
   one stage, so it skips with a reason and the run can still end at 0. `doctor`
   never exits 2 at all: every failure it can meet is something it reports as a
   gap, which is a 1.
   ```

   with:

   ```markdown
   `test` exits 2 whenever claudevs cannot run — for example on a usage error, an
   unreadable plugin directory, a Lua case file that does not load, or a suite
   with no cases to discover; the CLI reference lists every case. A plugin with no
   cases is a broken discovery convention, not a green suite. Inside `check` that
   condition is an environment gap for one stage, so it skips with a reason and
   the run can still end at 0. `doctor` reports every environment problem it
   meets as a gap, which is a 1; it exits 2 only when `--json` cannot render its
   report, which its report types never cause.
   ```

   Sources: recorded runs in Task 6 step 1's exit-code table; `claudevs-cli/src/cli.rs:193-199`; `error.rs:105-110`.

3. Replace the `refs` bullet at `:46-49` with:

   ```markdown
   - **refs** — every `${CLAUDE_PLUGIN_ROOT}/…` reference in the files Claude Code
     loads from a plugin (`.claude-plugin/*.json` and everything under `hooks/`,
     `skills/`, `agents/` and `commands/`) must resolve to a file that exists.
     References inside fenced code blocks are examples and are skipped. A `..`
     segment that leaves the plugin root is a finding even when the path it names
     happens to resolve today: the file is not part of the plugin and will not be
     there once it is installed.
   ```

   Sources: `wiring/refs.rs:84-121`, `contract/site.rs:10-66`. The old text says "anywhere in the plugin" (contradicted by `contract/site.rs:24,29-39`) and uses "shipped" (banned vocabulary).

4. Replace the `invocations` bullet at `:50-55` with:

   ```markdown
   - **invocations** — fenced command blocks in skill markdown are parsed into
     invocations by the crate's one fenced-command parser, the same one
     `t.skill_command` uses. A script (`.sh`, `.lua`, `.py` or `.js`) that nothing
     else in the plugin names is reported as a dead file. That one is a
     **warning**, not an error: it does not fail the stage. Case files, anything
     under `tests/`, language index files such as `__init__.py`, and files outside
     `hooks/` that neither start with `#!` nor are executable are not reported.
   ```

   Sources: `wiring/invocations.rs:118-213`, `harness/t_module.rs:279`.

5. Replace the `matchers` bullet at `:56-60` with:

   ```markdown
   - **matchers** — `hooks/hooks.json` must be JSON with a top-level `hooks`
     object; either failure is an error. Everything else this checker reports is a
     warning: an event name claudevs does not know, a `matcher` on an event that
     takes none, and a `matcher` claudevs cannot evaluate in the exact-match and
     pattern modes the hooks reference defines. The event catalogue can lag a
     Claude Code release, and a matcher claudevs cannot evaluate is not proof the
     runtime rejects it.
   ```

   Sources: `wiring/matchers.rs:1-90`, `lib.rs:8-11` (spec P2).

6. The remaining behavioural sentences were checked against source and stay unchanged:

   | README | Claim | Source |
   |---|---|---|
   | `:3-8` | case model, harness, native suites, wiring, installed layout, rendering | `lib.rs:1-26` |
   | `:10-14` | `run_suite` + `render_human` snippet | signatures `suite.rs:77`, `report/render.rs:129`; same calls ran in Task 1's doctest |
   | `:18-24` | command table | recorded `--help` in Task 6 |
   | `:26-29` | `--json` on `test`, `check`, `doctor`; `--strict` on `check` | `claudevs-cli/src/cli.rs:24-67` |
   | `:31-33` | 0 / 1 / 2 meaning | `report/render.rs:4-5` |
   | `:41-44` | three checkers, none executes anything | `wiring/mod.rs:1-10` |
   | `:62-72` | validate delegation, lenient default, `--strict`, skip when `claude` cannot run | `validate.rs:1-9,42-58,124-131`, `check.rs:120-139` |
   | `:74-78` | skip means environment; malformed `plugin.json` fails | `check.rs:141-177` |

7. Verify:

   ```
   $ grep -n 'regex\|anywhere in the plugin\|shipped\|never exits 2' crates/claudevs/README.md
   ```

   Expected: no output, exit 1.

### Task 11 — Verify the whole plan and hand off for commit

**Steps:**

1. Run the full Definition of Done:

   ```
   $ cargo make dod
   ```

   Expected: exit 0, no warnings; the `test-doc` step (`Makefile.toml:87-91`) lists the `docs/engine/tutorial.md`, `how-to.md` and `explanation.md` doctests, all `ok`.

2. Run the doctests without `claude` on `PATH`, as the CI `dod` job does:

   ```
   $ env PATH="$HOME/.cargo/bin:/usr/bin:/bin" cargo test -p claudevs --doc
   ```

   Expected: `test result: ok`. The `check` snippet asserts only the `wiring` stage and the exit code, both independent of `validate`; the `doctor` snippet asserts only the `marketplace` probe.

3. Confirm the example lane still passes: `cargo make claudevs-check`; expected exit 0 with the sixteen lines from plan 01, Task 12 step 1.

4. Check the shipped text:

   ```
   $ grep -rnE '\.rs:[0-9]' crates/claudevs/docs crates/claudevs/README.md
   $ grep -rnwiE 'phases?|workstreams?|epics?|milestones?|sprints?|tasks?|backlog|todo|plans?|specs?|rfcs?|roadmaps?|delivered|landed|shipped|closed|planned' crates/claudevs/docs crates/claudevs/README.md
   $ grep -rniE 'now supports|no longer|used to|as of|was wrong|coming soon|not yet|future work|prior revision|this revision' crates/claudevs/docs crates/claudevs/README.md
   $ grep -rnE '^[[:space:]]*```$' crates/claudevs/docs | wc -l
   $ grep -rnE '^[[:space:]]*```[a-z]' crates/claudevs/docs | wc -l
   ```

   Expected: no output from the first three. The last two counts are equal: every fence, indented or not, closes with a bare ```` ``` ```` and opens with a tag, so a bare count higher than the tagged count means an untagged opening fence. A hit on `closed` or `as of` that is plain English rather than change history (a *closed* enum, say) is allowed by `crates/clauders/CLAUDE.md:162-164`; reword where possible.

5. Confirm the change set: `git status --short`. Expected, besides plan 01's files if still uncommitted and the chain directory:

   ```text
    M crates/claudevs/README.md
    M crates/claudevs/src/lib.rs
   ?? crates/claudevs/docs/
   ?? crates/claudevs/src/docs_doctests.rs
   ```

6. Hand the change to the user. Suggested message, if they commit it:

   ```text
   docs(claudevs): add CLI and engine documentation with doctested snippets

   A Diátaxis tree under crates/claudevs/docs/ for plugin authors and Rust
   callers. docs_doctests.rs includes each docs/engine/*.md as a doctest and
   a guard test fails when one is not wired in. The crate README's refs,
   invocations, matchers and exit-code claims are corrected and it links
   the docs and examples.
   ```

---

## Verification summary (plan-level)

- `cargo make dod` passes, and the engine docs' Rust blocks run as doctests with and without `claude` on `PATH`.
- `every_engine_doc_is_compiled_as_a_doctest` was seen failing for each engine doc before it was wired in (Tasks 1–3), and a deliberately wrong snippet was seen failing the doctest step (Task 1 step 9).
- Every CLI doc output block is pasted from a run made while writing it; the recorded blocks in this plan came from runs of the same commands.
- No `file:line`, banned vocabulary or untagged opening fence under `crates/claudevs/docs/` or in the crate README; every relative link resolves.

## Review findings

- accuracy — three sentences drafted for `docs/architecture.md` and `docs/cli/explanation.md` asserted
  behaviour of the `claude` binary and of handler resolution that nothing in this repository can show.
  Dropped rather than shipped.
- accuracy — the crate README's matcher claim and three others were corrected against the source; see
  plan 01's findings.
- gap — nothing in `docs/cli/reference.md` said a clean `doctor` diagnosis is not a verdict on the
  plugin. Added, pointing at `examples/09_doctor_gaps`.
- stale — spec P6 records `claude 2.1.270`; the machine that wrote these docs has `2.1.276`. No claim
  depends on the difference; the version stamp is stale and left as written.

## Probe results

- Claim: every engine guide is compiled as a doctest and the guard test fails when one is not wired in.
  Command: `cargo test -p claudevs --lib docs_doctests`, run with each guide unwired in turn. Output:
  the guard test failed with the named panic each time, then passed once wired. Final state: 1 passed.
- Claim: a wrong snippet in a guide fails the gate. Command: flipped an `exit_code` assertion in
  `docs/engine/tutorial.md` and ran `cargo test -p claudevs --all-features --doc`. Output: the doctest
  failed with the left/right values, then passed again on revert.
- Claim: the engine guides' snippets compile and pass as written. Command:
  `cargo test -p claudevs --all-features --doc`. Output: `13 passed; 0 failed`, plus one pre-existing
  `compile_fail` doctest in `report/render.rs`.

## Deviations

- 2026-09-18 — Tasks 1 through 10 ran as parallel agents rather than in plan order, to meet a same-day
  deadline. Tasks 1-3 were kept sequential in one agent because they share the doctest module.
- 2026-09-18 — no independent reviewer pass. Each task's own verification ran and the workspace
  Definition of Done ran once at the end, green; the diff has not been read by a reviewer agent.
