---
status: done
created: 2026-08-29
---

# Verdict Gates Implementation Plan

**Goal:** A plugin reaches a verdict on every stage unless it has a defect that is real.

**Architecture:** Four gates currently stop a plugin short of a verdict for something that is not a
plugin defect. The delegate is invoked with `--strict`, which turns a style warning into a failure;
a failed stage returns early, so the three deterministic stages never run; there is no way to ask for
strictness back; and case selection loads every case file before testing whether it was wanted, so one
unloadable file kills the run. All four are changed here. Nothing about how a real defect is
classified changes — in particular a malformed `plugin.json` stays `Failed`.

**Tech Stack:** Rust 2024, `clap` (derive) for the CLI flag, `serde` for the report shape. No new
dependencies.

---

## Guideline conformance

- **`strong-types`** — strictness reaches `validate::run` as a two-variant enum, not a `bool`
  parameter. The guideline is explicit that a `bool` parameter for a semantic flag is primitive
  obsession: `validate::run(dir, true)` is unreadable at the call site and `validate::run(dir,
  Strictness::Strict)` is not.
- **`unit-test-mandate`** — every file touched here already carries `#[cfg(test)] mod tests`; each
  task adds to the existing module rather than creating one.
- **`strict-quality`** — no `#[allow(...)]` is added anywhere in this plan.
- **`doc-comment-discipline`** — the doc comments you rewrite must not name a plan, a phase, or this
  workflow. Say what the code does and why.

## File map

```
crates/claudevs/src/validate.rs      — [modify] Strictness parameter; --strict leaves the default argv
crates/claudevs/src/lib.rs           — [modify] export Strictness
crates/claudevs/src/doctor.rs        — [modify] its delegate call site, which the new signature breaks
crates/claudevs/src/check.rs         — [modify] drop three early returns; thread strictness through run
crates/claudevs-cli/src/cli.rs       — [modify] its check::run call site, then the `--strict` flag
crates/claudevs/src/suite.rs         — [modify] select before loading, so one bad case file fails alone
Makefile.toml                        — [modify] the claudevs-check lane's expectations and its comment
```

| File | Tasks |
|---|---|
| `validate.rs` | 1, 2 |
| `lib.rs` | 2 |
| `doctor.rs` | 2 |
| `check.rs` | 2, 3, 4 |
| `cli.rs` | 4, 5 |
| `suite.rs` | 6 |
| `Makefile.toml` | 7 |

---

## Task 1 — `--strict` leaves the default delegate argv

This is the single highest-value change in the chain: it is what rejected 35 of 156 third-party
plugins, none of which had a defect that would stop them working.

**Files:**
- Modify `crates/claudevs/src/validate.rs`

**Steps:**

1. Read the current argv construction. `crates/claudevs/src/validate.rs:68-74` is:

   ```rust
   let argv = [
       String::from(program),
       String::from("plugin"),
       String::from("validate"),
       String::from("--strict"),
       resolved.display().to_string(),
   ];
   ```

2. Add the failing test to the existing `#[cfg(test)] mod tests` in that file. The delegate is already
   a parameter (`run_program` takes `program`), so the test drives a script that records its own argv:

   ```rust
   #[test]
   fn the_default_delegate_invocation_carries_no_strict_flag() {
       let dir = tempfile::tempdir().unwrap();
       let log = dir.path().join("argv.txt");
       let recorder = dir.path().join("recorder.sh");
       std::fs::write(
           &recorder,
           format!("#!/bin/sh\nprintf '%s\\n' \"$@\" > {}\n", log.display()),
       )
       .unwrap();
       std::fs::set_permissions(
           &recorder,
           std::os::unix::fs::PermissionsExt::from_mode(0o755),
       )
       .unwrap();

       let _ = super::run_program(
           recorder.to_str().unwrap(),
           dir.path(),
           super::Strictness::Lenient,
       );

       let recorded = std::fs::read_to_string(&log).unwrap();
       assert!(
           !recorded.contains("--strict"),
           "the default invocation must not be strict: {recorded}"
       );
       assert!(recorded.contains("validate"), "{recorded}");
   }

   #[test]
   fn strict_puts_the_flag_back() {
       let dir = tempfile::tempdir().unwrap();
       let log = dir.path().join("argv.txt");
       let recorder = dir.path().join("recorder.sh");
       std::fs::write(
           &recorder,
           format!("#!/bin/sh\nprintf '%s\\n' \"$@\" > {}\n", log.display()),
       )
       .unwrap();
       std::fs::set_permissions(
           &recorder,
           std::os::unix::fs::PermissionsExt::from_mode(0o755),
       )
       .unwrap();

       let _ = super::run_program(
           recorder.to_str().unwrap(),
           dir.path(),
           super::Strictness::Strict,
       );

       assert!(std::fs::read_to_string(&log).unwrap().contains("--strict"));
   }
   ```

   Add `use std::os::unix::fs::PermissionsExt as _;` to the test module's imports if the inline path
   form above does not resolve. These tests are Unix-only; the crate already targets Unix in
   `crates/claudevs/src/harness/spawn.rs` (it spawns `sh`), so no `#[cfg(unix)]` gate is needed beyond
   what the crate already assumes.

3. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib validate
   error[E0433]: failed to resolve: could not find `Strictness` in `super`
      --> crates/claudevs/src/validate.rs
       |
       |             super::Strictness::Strict,
       |                    ^^^^^^^^^^ could not find `Strictness` in `super`
   ```

   E0433 quotes the path segment as written, so a `super::` path reports "could not find X in `super`",
   naming `super` itself rather than the module it resolves to. A second error for `run_program`'s
   arity (`E0061`) appears alongside it; either is the red you are looking for.

4. Implement. Add the type above `PROGRAM` in `validate.rs`:

   ```rust
   /// Whether the delegate treats its own warnings as failures.
   ///
   /// `claude plugin validate --strict` is `-Werror` over the same findings: a
   /// strict run and a plain run report identical text, and differ only in the
   /// verdict line and the exit code. So this is not "check more"; it is "fail on
   /// what was already reported". Default is [`Strictness::Lenient`], because a
   /// plugin whose only defect is a missing `author` field works, and a gate that
   /// stops it never reaches the deterministic stages that would find a real one.
   #[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
   pub enum Strictness {
       /// Warnings stay warnings; the delegate exits 0.
       #[default]
       Lenient,
       /// Warnings fail. Passes `--strict` to the delegate.
       Strict,
   }
   ```

   Change `run` and `run_program`:

   ```rust
   /// Runs `claude plugin validate [--strict] <plugin_dir>`.
   #[must_use]
   pub fn run(plugin_dir: &Path, strictness: Strictness) -> Validation {
       run_program(PROGRAM, plugin_dir, strictness)
   }
   ```

   ```rust
   fn run_program(program: &str, plugin_dir: &Path, strictness: Strictness) -> Validation {
   ```

   and replace the argv array with:

   ```rust
   let mut argv = vec![
       String::from(program),
       String::from("plugin"),
       String::from("validate"),
   ];
   if strictness == Strictness::Strict {
       argv.push(String::from("--strict"));
   }
   argv.push(resolved.display().to_string());
   ```

   Update the `spawn(&argv, …)` call below it — `&argv` on a `Vec<String>` still coerces to `&[String]`,
   so that line is unchanged.

   Update the module doc comment at `validate.rs:1-8` — it currently describes the stage without
   mentioning strictness, and the `run` doc comment above says `--strict` unconditionally. Both must
   now match the code.

5. Run and confirm green:

   ```
   $ cargo test -p claudevs --lib validate
   running N tests
   test validate::tests::strict_puts_the_flag_back ... ok
   test validate::tests::the_default_delegate_invocation_carries_no_strict_flag ... ok

   test result: ok. N passed; 0 failed
   ```

   Every existing test in this module that calls `run_program` now needs the third argument; add
   `Strictness::Lenient` to each.

6. **See it fail.** Change the `if` to `if strictness == Strictness::Lenient` and confirm both new
   tests go red — each with the other's expectation. Restore it.

7. Commit `fix(claudevs): stop the validate gate rejecting a plugin for a style warning`.

---

## Task 2 — Export `Strictness`, and fix the callers Task 1 broke

`validate::run` has two callers that pass it as a bare function item — `check::run` and
`doctor::run`. Task 1's signature change is a type error at both the moment it lands.

**Files:**
- Modify `crates/claudevs/src/lib.rs`
- Modify `crates/claudevs/src/doctor.rs`
- Modify `crates/claudevs/src/check.rs`

**Steps:**

1. Build and read the errors. There are exactly two, one per call site:

   ```
   $ cargo build -p claudevs
   error[E0593]: function is expected to take 1 argument, but it takes 2 arguments
      --> crates/claudevs/src/check.rs:69:26
       |
    69 |     run_with(plugin_dir, crate::validate::run)
       |     -------- ^^^^^^^^^^^^^^^^^^^^ expected function that takes 1 argument
       |     |
       |     required by a bound introduced by this call
       |
   note: required by a bound in `run_with`

   error[E0593]: function is expected to take 1 argument, but it takes 2 arguments
      --> crates/claudevs/src/doctor.rs:81:26
       |
    81 |     run_with(plugin_dir, crate::validate::run)
       |     -------- ^^^^^^^^^^^^^^^^^^^^ expected function that takes 1 argument
       |     |
       |     required by a bound introduced by this call
       |
   note: required by a bound in `run_with`

   error: could not compile `claudevs` (lib) due to 2 previous errors
   ```

   E0593 is the arity code. E0631 — "type mismatch in function arguments" — is the same-arity case
   and is not what this produces; do not match on it.

   `crates/claudevs/src/doctor.rs:78-81` is:

   ```rust
   pub fn run(plugin_dir: &Path) -> Diagnosis {
       run_with(plugin_dir, crate::validate::run)
   }
   ```

   and `doctor::run_with` at `:91` takes `validate: impl Fn(&Path) -> Validation`.

2. Fix it by closing over the strictness rather than widening `doctor`'s own signature:

   ```rust
   /// Reports what this environment can and cannot do.
   ///
   /// The delegate runs lenient. `doctor` asks whether the binary is reachable
   /// at all, and a plugin's style warnings are not part of that answer.
   #[must_use]
   pub fn run(plugin_dir: &Path) -> Diagnosis {
       run_with(plugin_dir, |dir| {
           crate::validate::run(dir, crate::validate::Strictness::Lenient)
       })
   }
   ```

   Do **not** add a `Strictness` parameter to `doctor::run`. `claudevs doctor` takes no `--strict`
   flag and gains nothing from one; widening its signature would push the choice out to a caller who
   has no basis for making it.

3. Fix `crates/claudevs/src/check.rs:68-70` the same way, so the crate compiles again at this
   commit. `check::run_with` keeps its one-argument delegate bound; only the closure changes:

   ```rust
   pub fn run(plugin_dir: &Path) -> Result<CheckReport> {
       run_with(plugin_dir, |dir| {
           crate::validate::run(dir, crate::validate::Strictness::Lenient)
       })
   }
   ```

   This is a stopgap that keeps this commit coherent on its own, not the final shape. Task 4
   replaces it with a `Strictness` parameter threaded through `check::run`, and Task 5 wires that
   to the CLI flag. Do not widen `check::run`'s signature here — that is Task 4's work, and doing
   it now would leave Task 4 with nothing to do and its test with nothing to prove.

4. Add to the `pub use validate::…` line in `crates/claudevs/src/lib.rs:35`:

   ```rust
   pub use validate::{Strictness, Validation};
   ```

5. Confirm the crate is whole again — this is the property this task exists to restore:

   ```
   $ cargo build -p claudevs
       Finished `dev` profile [unoptimized + debuginfo] target(s)
   ```

6. Run the doc gate — a new public item with no doc comment fails it:

   ```
   $ RUSTDOCFLAGS="-D warnings" cargo doc --workspace --all-features --no-deps
       Generated .../target/doc/claudevs/index.html
   ```

7. Commit `feat(claudevs): export the validate strictness selector`.

---

## Task 3 — A failed stage no longer truncates the report

**Files:**
- Modify `crates/claudevs/src/check.rs`

**Steps:**

1. Read the current pipeline. `crates/claudevs/src/check.rs:83-119` runs four stages with three early
   returns between them:

   ```rust
   report.stages.push(validation_stage(validate(plugin_dir)));
   if !report.all_clear() {
       return Ok(report);
   }
   ```

   …and the same shape after the wiring stage (`:101-103`) and after the `test` stage (`:110-112`).

2. Add the failing test to the existing `#[cfg(test)] mod tests`:

   ```rust
   #[test]
   fn a_failing_first_stage_does_not_hide_the_three_that_follow() {
       let plugin = PathBuf::from("tests/fixtures/minimal-plugin");
       let report = super::run_with(&plugin, |_| Validation::Failed {
           output: String::from("✘ Validation failed"),
       })
       .unwrap();
       let names: Vec<&str> = report.stages.iter().map(|s| s.name).collect();
       assert_eq!(names, ["validate", "wiring", "test", "test --installed"]);
       assert_eq!(report.stages[0].status, super::StageStatus::Failed);
   }
   ```

   `run_with` is private but the test module is inside `check.rs`, so `super::run_with` reaches it. The
   fixture path is relative to the crate root, which is where `cargo test -p claudevs` runs.

   This is the **two-argument** form, which is what `check.rs:83` has today —
   `fn run_with(plugin_dir: &Path, validate: impl Fn(&Path) -> Validation) -> Result<CheckReport>`.
   Task 3 runs before Task 4 so that each commit is coherent on its own: this one fixes the
   truncation against the signature that exists, and Task 4 widens this call along with every other
   one when it adds the strictness parameter. Do not write the three-argument form here — nothing
   defines it yet.

3. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib check::tests::a_failing_first_stage
   ---- check::tests::a_failing_first_stage_does_not_hide_the_three_that_follow stdout ----
   assertion `left == right` failed
     left: ["validate"]
    right: ["validate", "wiring", "test", "test --installed"]
   ```

   That red is the defect: one failed stage and the other three never ran.

4. Delete all three `if !report.all_clear() { return Ok(report); }` blocks. The function becomes a
   straight-line push of four stages.

   Then rewrite the three doc comments that assert the behaviour you just removed. `cargo doc` cannot
   catch a doc comment that is merely untrue, so nothing downstream will find these — they are listed
   here because they are the whole of the debt:

   - `crates/claudevs/src/check.rs:3-6`, the module doc, reads "Four stages in order — delegated
     manifest validation, static wiring, the case suite, the case suite again from the simulated
     install layout — **stopping at the first failure, because a plugin whose wiring is broken has
     nothing to learn from a suite run.**" Drop the clause from "stopping" onward and say the four
     stages all run and the report aggregates their results.
   - `crates/claudevs/src/check.rs:28-29`, on `StageStatus::Failed`, reads "Something wrong; **the
     pipeline stops here.**" It becomes: something wrong; the remaining stages still run.
   - `run_with`'s own doc comment DOES claim truncation — it reads "would otherwise turn the first
     stage red and truncate every pipeline under test." Drop the "and truncate" clause; the rest of
     the sentence stays true once the returns are gone.

   Per the `doc-comment-discipline` bullet above, none of these may name a plan, a phase, or this
   workflow — say what the code does and why.

5. Run and confirm green:

   ```
   $ cargo test -p claudevs --lib check
   test check::tests::a_failing_first_stage_does_not_hide_the_three_that_follow ... ok
   test result: ok. N passed; 0 failed
   ```

   One existing test in this module encoded the truncation, and its **name** encodes it too:
   `wiring_failing_stops_the_pipeline_before_the_suite_runs` at `crates/claudevs/src/check.rs:212-219`.

   ```rust
   #[test]
   fn wiring_failing_stops_the_pipeline_before_the_suite_runs() {
       let report = run_with(&fixture("escape-plugin"), delegate_passes).unwrap();
       let names: Vec<&str> = report.stages.iter().map(|s| s.name).collect();
       assert_eq!(names, vec!["validate", "wiring"], "{report:?}");
       assert_eq!(report.stages[1].status, StageStatus::Failed);
       assert!(!report.all_clear());
   }
   ```

   Rename it to `wiring_failing_is_reported_without_stopping_the_stages_that_follow` and widen the
   first assertion to `vec!["validate", "wiring", "test", "test --installed"]`. The other two
   assertions — the `Failed` status at index 1 and `!all_clear()` — stay exactly as they are; they are
   what still has to hold. Editing only the assertion would leave a test whose name says the opposite
   of what it now proves.

   `a_dead_file_warning_does_not_stop_the_pipeline` (`check.rs:222`) asserts
   `report.stages.len() > 2` and survives unchanged. It is the only other test in the module that
   touches stage count.

   Say the rename and the widened assertion in the commit body.

6. Commit `fix(claudevs): run every check stage instead of stopping at the first failure`.

---

## Task 4 — Thread strictness through `check::run`

**Files:**
- Modify `crates/claudevs/src/check.rs`
- Modify `crates/claudevs-cli/src/cli.rs` — its one call site, so the workspace still builds

**Steps:**

1. Decide where the seam goes before writing the test, because the obvious test is vacuous. A closure
   handed to `run_with` that hardcodes `Strictness::Strict` and then reads it back proves nothing:
   `check::run` — the function whose forwarding is under test — is never called, so deleting its
   parameter leaves the test green.

   The falsifiable seam is `run_with` itself. Widen the delegate it takes from
   `impl Fn(&Path) -> Validation` to `impl Fn(&Path, Strictness) -> Validation`, and have `run_with`
   pass the strictness it was given. Then a test that hands `run_with` a `Strictness::Strict` and
   asserts the closure *received* `Strict` fails the moment `run_with` drops or hardcodes the value.

2. Add the failing test:

   ```rust
   #[test]
   fn the_pipeline_hands_the_delegate_the_strictness_it_was_given() {
       let plugin = PathBuf::from("tests/fixtures/minimal-plugin");
       let seen = std::cell::RefCell::new(Vec::new());

       let _ = super::run_with(&plugin, Strictness::Strict, |_, strictness| {
           seen.borrow_mut().push(strictness);
           Validation::Passed {
               output: String::new(),
           }
       });
       assert_eq!(seen.borrow().as_slice(), [Strictness::Strict]);

       seen.borrow_mut().clear();
       let _ = super::run_with(&plugin, Strictness::Lenient, |_, strictness| {
           seen.borrow_mut().push(strictness);
           Validation::Passed {
               output: String::new(),
           }
       });
       assert_eq!(seen.borrow().as_slice(), [Strictness::Lenient]);
   }
   ```

   Both halves matter. A `run_with` that hardcodes `Strict` passes the first and fails the second;
   one that hardcodes `Lenient` does the reverse; one that drops the parameter fails whichever it is
   not.

3. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib check::tests::the_pipeline_hands_the_delegate
   error[E0061]: this function takes 2 arguments but 3 arguments were supplied
      --> crates/claudevs/src/check.rs
       |
       |         let _ = super::run_with(&plugin, Strictness::Strict, |_, strictness| {
       |                 ^^^^^^^^^^^^^^^
   ```

4. Implement:

   ```rust
   /// Runs the check pipeline over the plugin at `plugin_dir`.
   ///
   /// # Errors
   ///
   /// Only conditions that stop claudevs itself: an unwalkable plugin directory, an
   /// unloadable case file. A failing plugin is a report, not an error.
   pub fn run(plugin_dir: &Path, strictness: Strictness) -> Result<CheckReport> {
       run_with(plugin_dir, strictness, crate::validate::run)
   }
   ```

   ```rust
   fn run_with(
       plugin_dir: &Path,
       strictness: Strictness,
       validate: impl Fn(&Path, Strictness) -> Validation,
   ) -> Result<CheckReport> {
       let mut report = CheckReport::default();
       report.stages.push(validation_stage(validate(plugin_dir, strictness)));
       // … the remaining three stages, unchanged from Task 3 …
   }
   ```

   `crate::validate::run` now has exactly the delegate's signature, so `run` passes it by name rather
   than wrapping it in a closure — which is also what makes the last hop inspectable at a glance.

   Add `use crate::validate::Strictness;` to `check.rs`'s imports. Every existing test in this module
   that calls `run_with` gains a strictness argument and a two-parameter closure; `Strictness::Lenient`
   is the right value for all of them.

5. **See it fail.** Change `run_with`'s body to `validate(plugin_dir, Strictness::Lenient)`, ignoring
   its own parameter, and confirm the first half of the test goes red:

   ```
   assertion `left == right` failed
     left: [Lenient]
    right: [Strict]
   ```

   Restore it.

6. Fix the one caller outside this crate, in the same commit. `check::run` is public, and
   `crates/claudevs-cli/src/cli.rs:150` is `match claudevs::check::run(path) {`. Leave it and this
   commit ships a workspace that does not compile.

   Change that one line, and nothing else in the file:

   ```rust
   match claudevs::check::run(path, claudevs::Strictness::Lenient) {
   ```

   `Lenient` is the value that preserves today's behaviour exactly — `check` has no `--strict` flag
   until Task 5, which replaces this literal with the flag-derived value. `run_check`'s own signature
   does not change here, so its caller at `cli.rs:77` is untouched.

7. Run and confirm green. Use the **workspace** form, not `-p claudevs`: a crate-scoped run passes
   while `claudevs-cli` is broken, which is exactly the failure this step exists to catch.

   ```
   $ cargo test --workspace --all-targets
   test result: ok. N passed; 0 failed
   ```

8. Commit `feat(claudevs): let a caller ask the check pipeline for a strict validate`.

---

## Task 5 — `claudevs check --strict`

**Files:**
- Modify `crates/claudevs-cli/src/cli.rs`

**Steps:**

1. Read the current subcommand. `crates/claudevs-cli/src/cli.rs:47-55`:

   ```rust
   /// Validate, check wiring, then run the suite in both layouts.
   Check {
       /// Emit the machine-readable report instead of the human one.
       #[arg(long)]
       json: bool,
       /// The plugin directory.
       #[arg(default_value = ".")]
       path: PathBuf,
   },
   ```

2. Add the failing test to the existing test module — the file already has a
   `Cli::try_parse_from(["claudevs", "check", "--json", "some/plugin"])` test at `:250`, so follow that
   shape:

   ```rust
   #[test]
   fn check_accepts_a_strict_flag_and_defaults_to_lenient() {
       let Cli { command } =
           Cli::try_parse_from(["claudevs", "check", "--strict", "some/plugin"]).unwrap();
       let Command::Check { strict, .. } = command else {
           panic!("expected a check command");
       };
       assert!(strict);

       let Cli { command } = Cli::try_parse_from(["claudevs", "check", "some/plugin"]).unwrap();
       let Command::Check { strict, .. } = command else {
           panic!("expected a check command");
       };
       assert!(!strict, "check is lenient unless asked");
   }
   ```

3. Run and confirm failure:

   ```
   $ cargo test -p claudevs-cli
   error[E0026]: variant `Command::Check` does not have a field named `strict`
   ```

4. Implement. Add the flag to the variant:

   ```rust
   /// Validate, check wiring, then run the suite in both layouts.
   Check {
       /// Fail on the delegate's warnings as well as its errors.
       #[arg(long)]
       strict: bool,
       /// Emit the machine-readable report instead of the human one.
       #[arg(long)]
       json: bool,
       /// The plugin directory.
       #[arg(default_value = ".")]
       path: PathBuf,
   },
   ```

   Convert the clap `bool` into the domain type **at the dispatch site**, not inside `run_check`. Two
   adjacent `bool` parameters (`run_check(strict, json, &path)`) are a pair a reader can transpose
   without the compiler noticing, which is the primitive obsession `strong-types` names:

   ```rust
   Command::Check { strict, json, path } => {
       let strictness = if strict {
           claudevs::Strictness::Strict
       } else {
           claudevs::Strictness::Lenient
       };
       run_check(strictness, json, &path)
   }
   ```

   ```rust
   /// `claudevs check`.
   fn run_check(strictness: claudevs::Strictness, json: bool, path: &std::path::Path) -> i32 {
       match claudevs::check::run(path, strictness) {
           // … unchanged body
       }
   }
   ```

   Read `run_check`'s existing body before editing and keep it as it is; only the signature and the
   `check::run` call change.

5. Run and confirm green:

   ```
   $ cargo test -p claudevs-cli
   test cli::tests::check_accepts_a_strict_flag_and_defaults_to_lenient ... ok
   test result: ok. N passed; 0 failed
   ```

6. Verify by hand that the flag reaches the delegate, since that is the whole point:

   ```
   $ cargo run -q -p claudevs-cli -- check --help
   Validate, check wiring, then run the suite in both layouts

   Usage: claudevs check [OPTIONS] [PATH]

   Arguments:
     [PATH]  The plugin directory [default: .]

   Options:
         --strict  Fail on the delegate's warnings as well as its errors
         --json    Emit the machine-readable report instead of the human one
     -h, --help    Print help
   ```

7. Commit `feat(claudevs-cli): add check --strict to restore the delegate's own flag`.

---

## Task 6 — One unloadable case file fails alone

**Files:**
- Modify `crates/claudevs/src/suite.rs`

**Steps:**

1. Read the current loop. `crates/claudevs/src/suite.rs:77-94` loads every discovered YAML case and
   *then* tests whether the filter wanted it:

   ```rust
   CaseFile::Yaml(path) => {
       let case = crate::case::load_yaml_case(&path)?;
       if selected(options, case.name.as_str()) {
           outcomes.push(run_case(plugin_dir, &fixtures_root, &case)?);
       }
   }
   ```

   The `?` on `load_yaml_case` is the defect: one file that does not load ends the whole run with an
   error, which `crates/claudevs-cli/src/cli.rs` turns into exit 2 — including for the cases the user
   asked for by name.

2. Add the failing test to the existing test module. It needs a plugin with two case files, one valid
   and one not:

   ```rust
   #[test]
   fn one_unloadable_case_file_does_not_take_its_valid_sibling_down() {
       let dir = tempfile::tempdir().unwrap();
       let plugin = dir.path();
       std::fs::create_dir_all(plugin.join(".claude-plugin")).unwrap();
       std::fs::write(
           plugin.join(".claude-plugin/plugin.json"),
           r#"{"name":"p","version":"0.1.0"}"#,
       )
       .unwrap();
       std::fs::create_dir_all(plugin.join("hooks")).unwrap();
       std::fs::write(
           plugin.join("hooks/hooks.json"),
           r#"{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"true"}]}]}}"#,
       )
       .unwrap();
       std::fs::create_dir_all(plugin.join("tests/cases")).unwrap();
       std::fs::write(
           plugin.join("tests/cases/a-valid.yaml"),
           "event: SessionStart\nexpect:\n  exit: 0\n",
       )
       .unwrap();
       std::fs::write(
           plugin.join("tests/cases/b-broken.yaml"),
           "event: SessionStart\nexpect:\n  output: banana\n",
       )
       .unwrap();

       let report = super::run_suite(plugin, &super::SuiteOptions::default()).unwrap();
       let names: Vec<&str> = report.outcomes.iter().map(|o| o.name.as_str()).collect();
       assert_eq!(names.len(), 2, "{names:?}");
       assert!(names.contains(&"a-valid"));
       assert!(
           matches!(
               report.outcomes.iter().find(|o| o.name == "b-broken").map(|o| &o.verdict),
               Some(crate::harness::Verdict::Fail(_)),
           ),
           "the unloadable case is one failed case, not the death of the run"
       );
   }
   ```

   `b-broken.yaml` is unloadable for a reason the loader already rejects:
   `crates/claudevs/src/case/model.rs:231-237` refuses any `expect.output` other than `"none"` with
   ``` `expect.output` only accepts "none", got `banana` ```. Confirm that is still the message before
   relying on it.

   `tests/cases/*.yaml` is the right place for these fixtures and needs no adjusting:
   `crates/claudevs/src/case/discover.rs:26-46` walks all of `<plugin>/tests` with
   `WalkDir::new(&root).sort_by_file_name()`, skipping only what `under_fixtures` excludes
   (`tests/fixtures/`), and classifies every remaining file by extension.

3. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib suite::tests::one_unloadable_case_file
   ---- suite::tests::one_unloadable_case_file_does_not_take_its_valid_sibling_down stdout ----
   called `Result::unwrap()` on an `Err` value: CaseLoad { path: ".../tests/cases/b-broken.yaml", reason: "`expect.output` only accepts \"none\", got `banana`" }
   ```

4. Implement. Replace the `Yaml` arm so a load failure becomes an outcome:

   ```rust
   CaseFile::Yaml(path) => {
       // The case name a filter matches against is the file stem, because a
       // file that does not load has no name of its own — and selection must
       // happen before loading, or one unloadable file decides the fate of
       // every case the user actually asked for.
       let stem = path
           .file_stem()
           .map_or_else(String::new, |s| s.to_string_lossy().into_owned());
       if !selected(options, &stem) {
           continue;
       }
       match crate::case::load_yaml_case(&path) {
           Ok(case) => outcomes.push(run_case(plugin_dir, &fixtures_root, &case)?),
           Err(error) => outcomes.push(CaseOutcome {
               name: stem,
               verdict: Verdict::Fail(vec![format!(
                   "load: {} could not be loaded: {error}",
                   path.display()
               )]),
           }),
       }
   }
   ```

   Filtering on the file stem rather than the loaded `case.name` changes nothing, because the two can
   never differ. `crates/claudevs/src/case/yaml.rs:15` states it — "The case name is the file stem" —
   and `:32-36` is where it happens: the loader takes `path.file_stem()` and builds
   `CaseName::new(stem)`. `RawCase` (`crates/claudevs/src/case/model.rs:150-175`) carries no `name:`
   field at all, so there is no way for a case to be called anything else. Write the single filter
   shown above; do not add a second one for the success path.

   The `Verdict::Fail(Vec<String>)` shape used here is the current one. Plan 04 replaces it with a
   typed `Mismatch` enum; that plan carries the migration of this call site, so write it against the
   shape that exists now.

   **The `CaseFile::Lua` arm keeps its `?`, deliberately.** `crates/claudevs/src/suite.rs:85-92` is

   ```rust
   CaseFile::Lua(path) => {
       outcomes.extend(crate::case::run_lua_file(
           plugin_dir,
           &fixtures_root,
           &path,
           options,
       )?);
   }
   ```

   and `discover` classifies both extensions, so an unloadable `.lua` file still ends the whole run.
   That is the same defect on the other path. It is out of scope here because the spec cites the YAML
   arm specifically (`suite.rs:80-81`) and because the fix is not the same shape: `run_lua_file`
   returns *many* outcomes from one file and does its own selection internally, so "one failed case
   named for its file" has to be decided differently there. Do not widen this task to cover it, and do
   not leave it unrecorded — no sibling plan owns it either.

5. Run and confirm green:

   ```
   $ cargo test -p claudevs --lib suite
   test suite::tests::one_unloadable_case_file_does_not_take_its_valid_sibling_down ... ok
   test result: ok. N passed; 0 failed
   ```

6. **See it fail.** Put the `?` back on `load_yaml_case` and confirm the test goes red on the unwrap
   again. Restore it.

7. Commit `fix(claudevs): let one unloadable case file fail alone instead of ending the run`.

---

## Task 7 — Definition of Done and the fixture corpus

**Files:**
- Modify `Makefile.toml` — the `claudevs-check` lane's expectations and the comment block at `:174-182`
- No Rust source changes; the rest of this task verifies.

**Steps:**

1. Run the full gate:

   ```
   $ cargo make dod
   ```

   or the five commands directly:

   ```
   $ cargo fmt --all -- --check
   $ cargo clippy --workspace --all-targets --all-features -- -D warnings
   $ RUSTDOCFLAGS="-D warnings" cargo doc --workspace --all-features --no-deps
   $ cargo test --workspace --all-targets --all-features
   $ cargo test --workspace --all-features --doc
   ```

   Every one exits 0 with no warnings.

2. Run the fixture corpus lane, which asserts the checkers still report:

   ```
   $ cargo make claudevs-check
   ```

   **This lane will need updating.** Read `Makefile.toml:165` onwards before running it. Its comment
   block records that on a machine with `claude` installed, `bad-matcher-plugin` is rejected by the
   delegate at the validate stage and the pipeline stops before wiring runs. Task 3 removed that stop,
   so on such a machine the wiring stage now also runs and the lane's expected output changes. Update
   the lane's expectations to match, and update that comment block — it documents behaviour this plan
   just changed, and leaving it would make it a lie for the next reader.

3. Sanity-check the headline number by hand if you have a third-party plugin to hand:

   ```
   $ cargo run -q -p claudevs-cli -- check <some/plugin/that/only/lacks/an/author/field>
   ```

   It should now reach the wiring, test and `test --installed` stages instead of stopping at validate.

4. Commit `test(claudevs): update the fixture lane for a pipeline that no longer truncates`.

---

## Done when

- `cargo make dod` is green with zero warnings.
- `cargo make claudevs-check` is green, and its comment block describes the pipeline as it now behaves.
- `claudevs check` runs `claude plugin validate` without `--strict`; `claudevs check --strict` runs it
  with.
- A failing stage produces a four-stage report.
- Tasks 1, 3 and 6 were each watched go red before they went green.
- `check.rs:144-149` and `check.rs:172-175` are **unchanged**. A malformed `plugin.json` is still
  `Failed`, not `Skipped` — that reasoning is sound and this plan does not touch it.
- The `CaseFile::Lua` arm at `suite.rs:85-92` still aborts the run on an unloadable file. That is a
  stated deferral, not an oversight, and no plan in this chain owns it yet.

---

## Review findings

One review pass over the complete diff, after all seven tasks landed. The reviewer re-ran the gate
itself rather than reading anyone's receipt. Verdict: plan-compliant, spec-compliant, **0 blocking**,
6 risk, 9 nit. Every finding is dispositioned below — a finding reported and then quietly dropped is
the failure this table exists to prevent.

| # | Tier | Finding | Disposition |
|---|---|---|---|
| 1 | 🟡 | `suite.rs:87` — the select-before-load reorder is untested; moving the guard back keeps every test green | applied — added a test with an unloadable-but-unselected case file, mutation watched red |
| 2 | 🟡 | `cli.rs:81` — the `bool` → `Strictness` mapping is untested; swapping the arms leaves the workspace green | applied — extracted `strictness_from_flag`, both directions asserted, swap watched red |
| 3 | 🟢 | `cli.rs:269` — test named for "defaults to lenient" asserts only the clap `bool` | applied — renamed to `..._defaults_to_absent`; the real claim is now finding 2's test |
| 4 | 🟡 | `README.md:22` — still says `check` stops "at the first failing stage" | applied |
| 5 | 🟡 | `README.md:62` — still says the delegate runs `--strict`; the new flag is undocumented | applied — corrected, and `--strict` documented alongside `--json` |
| 6 | 🟡 | `Makefile.toml:288` — `"validate\|wiring"` is weaker than achievable; deleting the matcher checker keeps the lane green locally | applied — pinned to `wiring`, which FAILs on every machine; `expect_stage_fail_either` removed as now-dead |
| 7 | 🟡 | `Makefile.toml:181` — comment asserts a property the lane never checked | applied — true as written once finding 6 landed |
| 8 | 🟡 | `Makefile.toml:346` — `dod-crate`'s fifth step is an unguarded `cargo test --doc`, so the crate-scoped gate cannot complete on any binary-only member | **declined** — pre-existing, outside this diff, and not this plan's to fix. Own it in a separate chain |
| 9 | 🟡 | `check.rs:104` — `check` now executes a plugin's own hook commands even after validate and wiring have declared it defective | **declined** — spec §5 mandates the non-truncating pipeline, so this is the specified behaviour, not a defect. Recorded because the widened exposure is documented nowhere |
| 10 | 🟢 | `suite.rs:86` — a stem-less file yields `String::new()` as a case name, bypassing `CaseName` validation | **declined** — pre-existing, beyond this plan's scope |
| 11 | 🟢 | `validate.rs:49` — `Default` derived on `Strictness` and never used | **declined** — the plan specifies that derive |
| 12 | 🟢 | `check.rs:210`, `:322` — hardcoded fixture paths beside a `fixture()` helper that anchors on `CARGO_MANIFEST_DIR` | **declined** — cosmetic |
| 13 | 🟢 | `check.rs:211` — `super::` qualification on items already imported | **declined** — cosmetic |
| 14 | 🟢 | `validate.rs:180` — recorder-script setup duplicated across two tests | **declined** — cosmetic |
| 15 | 🟢 | `validate.rs:202` — matches `--strict` anywhere in the joined argv, so flag position is unchecked | **declined** — cosmetic |
| 16 | 🟢 | `validate.rs:215` — log path interpolated unquoted into a shell redirect; a temp dir with a space fails obscurely | **declined** — latent only under a path shape this repo does not produce |
| 17 | 🟢 | `validate.rs:230` — bare `assert!` with no message, unlike its sibling | **declined** — cosmetic |
| 18 | 🟡 | plan Task 3 step 4 under-scoped the doc debt: it named three doc comments as "the whole of it" while `README.md:22` and `:62` carried the same two false claims and no task owned them | applied — findings 4 and 5 close it; the plan text is corrected above |

## Probe results

Each claim the plan asserted about something it did not itself create, and the throwaway test that
settled it. Two came out against the plan.

| Claim | How it was tested | Result |
|---|---|---|
| `.unwrap()` in the new tests trips the workspace `unwrap_used = "deny"` lint | `rg` for `expect(clippy` across the five target files; `ls clippy.toml` | **Held against the worry.** All five carry `#![expect(clippy::unwrap_used, …)]` inside `mod tests` (`validate.rs:95`, `doctor.rs:189`, `check.rs:183`, `cli.rs:191`, `suite.rs:287`). No `clippy.toml` exists |
| E0433 for `super::Strictness` names the resolved module, so the message reads `` in `validate` `` | Standalone repro: `rustc --test --edition 2024` over a file with `mod validate { mod tests { super::Strictness::Strict } }` | **Against the plan.** rustc quotes the path segment as written: ``could not find `Strictness` in `super` `` |
| `doctor.rs` is the only call site Task 1 breaks | `cargo build -p claudevs` after Task 1 landed | **Against the plan.** Two E0593s — `check.rs:69` and `doctor.rs:81`, both `run_with(plugin_dir, crate::validate::run)` |
| The spec enumerates the broken call sites, so this omission is a spec defect too | `rg` for `validate::run`, `Strictness`, `doctor::run` in `spec.md`, with `rg -c strict` as the control that the search works | **Held.** Control returns 7; all three targets return 0. The spec never names call sites, so this was plan-level only |
| `run_with`'s doc comment does not claim truncation | `git diff -- crates/claudevs/src/check.rs` grepped for `truncate` | **Against the plan.** `-/// the first stage red and truncate every pipeline under test.` |
| Pinning the fixture assertion to `wiring` is machine-independent | `env PATH=/usr/bin:/bin ./target/debug/claudevs check …/bad-matcher-plugin` | **Held.** With `claude` absent, validate skips and `FAIL wiring` still appears — so `wiring` FAILs in both environments |
| The strengthened assertion actually discriminates rather than passing vacuously | Repointed it at `test`, a stage that only ever skips, and re-ran the lane | **Held.** Lane exits 1; reverted, lane green again |
| `check.rs`'s two must-not-change regions survived | `git diff` grepped for `Error::Manifest`, `Validation::Failed`, "three skippable conditions" | **Held.** Absent from the diff; a malformed `plugin.json` still classifies `Failed` |

## Deviations

- **Task 2 was amended mid-execution** to fix `check.rs:69` as well as `doctor.rs:81`, and gained
  `check.rs` in its file list. As originally written its commit would have left the crate
  uncompilable until Task 4. The stopgap closure it installs is superseded wholesale by Task 4.
- **Three expected-output blocks were wrong** and are corrected in the task text above: Task 1's
  E0433 message, Task 3's claim about the `run_with` doc comment, and Task 6's panic variant
  (`Case { … }` → `CaseLoad { path, reason }`).
- **Task 7 needed less than the plan predicted.** The plan expected the fixture lane's stage and
  exit-code assertions to need updating for a non-truncating pipeline; in reality only the prose
  comments were stale — `expect_stage_fail_either` already tolerated two FAIL lines. The lane's
  assertion was nonetheless strengthened afterwards, as review finding 6.
- **Verification ran crate-scoped, not workspace-wide, during the tasks**, because the machine this
  executed on is resource-constrained. The unscoped `cargo make dod` was run once at the end and is
  green; that is the gate of record.
- **`cargo make dod-crate claudevs-cli` cannot pass** — see review finding 8. Crate-scoped
  verification of the CLI used the five DoD commands with `-p` instead.
- **Task 6 ran in parallel** with the Task 1→2 chain; the two touch disjoint files and share no
  symbols. Tasks 3, 4, 5 and 7 were sequential, and the four review fixes ran three-way parallel.
