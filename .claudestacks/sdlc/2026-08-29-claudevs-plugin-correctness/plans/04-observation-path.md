---
status: draft
created: 2026-08-29
depends-on: [01, 02, 03]
---

# Observation Path Implementation Plan

**Goal:** A hook case's verdict reflects what the hook actually did.

**Architecture:** Four defects sit between a hook running and a verdict meaning anything. An
`expect: output: none` assertion on a script or flow case can never fail, because nothing populates
the field it reads. The default project is a bare temp directory, so a hook that branches on project
state takes its silent branch and the case passes whether the hook works or not.
`harness::semantics` reads two of the four documented decision mechanisms and keys context injection
off one event instead of three. And a failure carries neither the payload the hook was given nor the
argv that ran, so `stdout: expected to contain X` cannot tell "printed something different" from
"printed nothing" from "never ran". Two of the four stop a verdict being earned; two stop it being
read. All four are corrections to the same path.

**Tech Stack:** Rust 2024, `serde_json`, `serde` for the JSON report, the `contract` module from
plan 01. No new dependencies.

**Depends on:** plans 01, 02 and 03. Task 5 reads the catalogue's `stdout_is_context` flag (plan 01);
Tasks 7–9 rewrite `Verdict::Fail`, and plan 02 Task 6 and plan 03 Task 6 both construct it in its
current `Vec<String>` shape, so those two call sites migrate here along with the four that already
exist.

---

## Guideline conformance

- **`strong-types`** — `expect.output` becomes unconstructible on a case kind that cannot falsify it,
  rather than silently skipped at judgement time. That is parse-don't-validate: an assertion that
  cannot fail should not exist, not merely be ignored.
- **`strong-types`** again — `Verdict::Fail` carries a `Vec<Mismatch>`, a typed enum, rather than a
  `Vec<String>`. Rendering derives the sentence; the JSON carries the structure.
- **`modularity`** — `semantics` reads the context-injection flag from `contract::event` rather than
  hardcoding a per-event rule. Do not add a second event table here.
- **`unit-test-mandate`** — every file touched already has `#[cfg(test)] mod tests`; add to those.
- **`doc-comment-discipline`** — `harness/payload.rs:2-6` calls the defaults "provisional … replaced
  as a base layer by captured payloads once capture exists", and `types/hook_event.rs:5-6` says the set
  "grows as capture (P4) grounds more". `P4` is a phase identifier and must not be in source. Task 4
  fixes it.
- **`strict-quality`, and the lint attributes specifically.** `[workspace.lints.clippy]` sets
  `unwrap_used = "deny"`, `panic = "deny"` and `expect_used = "warn"`, and the gate runs `-D warnings`.
  Two directions to watch. A test module using `panic!` — including inside a `let-else` — needs
  `#![expect(clippy::panic, reason = "tests panic to reject an unexpected shape")]`, as
  `crates/claudevs/src/harness/verdict.rs:86` already has; one using `.unwrap()` needs
  `#![expect(clippy::unwrap_used, …)]`. And an `#[expect]` nothing fulfils fires
  `unfulfilled_lint_expectations`, itself a warning. Two specifics, both checked against the source:
  **`crates/claudevs/src/harness/payload.rs:74`'s test module carries neither attribute and uses no
  `.unwrap()` today** — Task 2 adds two, so it needs `unwrap_used`. And
  **`crates/claudevs/src/suite.rs:287` carries `unwrap_used` but not `clippy::panic`** — Task 9's
  tests use `panic!` in a `let-else`, so it needs the second. `project.rs:165`, `case/model.rs:252`
  and `report/render.rs:226` already carry `unwrap_used`. Check each module you touch.

## File map

```
crates/claudevs/src/case/model.rs        — [modify] refuse expect.output on a kind that cannot falsify it
crates/claudevs/src/harness/project.rs   — [modify] the default project is a project, not a bare tempdir
crates/claudevs/src/harness/payload.rs   — [modify] tool_input.file_path points at the tracked file
crates/claudevs/src/types/hook_event.rs  — [modify] drop the phase identifier from the module doc
crates/claudevs/src/harness/semantics.rs — [modify] all four decision mechanisms; catalogue-keyed context
crates/claudevs/src/harness/verdict.rs   — [modify] Verdict::Fail carries typed mismatches
crates/claudevs/src/report/render.rs     — [modify] render a Mismatch into its sentence
crates/claudevs/src/suite.rs             — [modify] the flow producers; payload and handler on a failure
crates/claudevs/src/case/runner.rs       — [modify] the Lua producer and its CaseOutcome literal
crates/claudevs/tests/fixtures/project-branch-plugin/ — [create] a hook that branches on project state
Makefile.toml                            — [modify] the new fixture into the claudevs-check lane
```

| File | Tasks |
|---|---|
| `case/model.rs` | 1 |
| `harness/project.rs` | 2 |
| `harness/payload.rs` | 2 |
| `tests/fixtures/project-branch-plugin/` | 3 |
| `Makefile.toml` | 3 |
| `types/hook_event.rs` | 4 |
| `harness/semantics.rs` | 5, 6 |
| `harness/verdict.rs` | 7 |
| `report/render.rs` | 8 |
| `suite.rs` | 7, 9 |
| `case/runner.rs` | 7, 9 |

---

## Task 1 — `expect.output` becomes falsifiable or is refused

**Files:**
- Modify `crates/claudevs/src/case/model.rs`

**Steps:**

1. Understand the defect before changing anything. `Observed.emitted` is set only by
   `crates/claudevs/src/harness/semantics.rs`, which runs for hook observations.
   `crates/claudevs/src/suite.rs:224-232` builds a script/flow `Observed` from `..Observed::default()`,
   so `emitted` is always `false` there, and the assertion at
   `crates/claudevs/src/harness/verdict.rs:45` — `expect.output.as_deref() == Some("none") &&
   observed.emitted` — can never fire.

   Confirm it for yourself first. Write a throwaway script case asserting `output: none` against a
   command that prints, run it, and watch it pass:

   ```yaml
   invocation:
     argv: ["sh", "-c", "echo loud"]
   expect:
     output: none
   ```

   ```
   $ cargo run -q -p claudevs-cli -- test <that plugin>
     ok    c-script-output-none
   ```

   That `ok` is the defect. Do not proceed until you have seen it.

2. Add the failing test to `case/model.rs`'s existing `#[cfg(test)] mod tests`:

   ```rust
   #[test]
   fn output_none_is_accepted_on_a_hook_case() {
       let parsed = case(serde_json::json!({
           "event": "PreToolUse",
           "expect": { "output": "none" }
       }));
       assert!(parsed.is_ok(), "{parsed:?}");
   }

   #[test]
   fn output_none_is_refused_on_a_script_case_because_it_could_never_fail() {
       let error = case(serde_json::json!({
           "invocation": { "argv": ["true"] },
           "expect": { "output": "none" }
       }))
       .unwrap_err();
       assert!(error.contains("output"), "{error}");
       assert!(error.contains("hook"), "{error}");
   }

   #[test]
   fn output_none_is_refused_on_a_flow_case_for_the_same_reason() {
       let error = case(serde_json::json!({
           "steps": [{ "run": { "argv": ["true"] } }],
           "expect": { "output": "none" }
       }))
       .unwrap_err();
       assert!(error.contains("output"), "{error}");
   }

   #[test]
   fn output_none_is_refused_inside_a_flow_step_too() {
       let error = case(serde_json::json!({
           "steps": [{
               "run": { "argv": ["true"] },
               "expect": { "output": "none" }
           }]
       }))
       .unwrap_err();
       assert!(error.contains("output"), "{error}");
   }
   ```

   The `case(...)` helper already exists at `crates/claudevs/src/case/model.rs:257-260`.

3. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib case::model
   ---- case::model::tests::output_none_is_refused_on_a_script_case_because_it_could_never_fail stdout ----
   called `Result::unwrap_err()` on an `Ok` value: Case { ... }
   ```

4. Implement. `Case::from_raw` at `crates/claudevs/src/case/model.rs:231-237` already rejects any
   `expect.output` value other than `"none"`. Extend that block so the *kind* is checked too, and add
   the same check over a flow's steps. The `kind` binding is in scope by then:

   ```rust
   /// Why `expect.output` cannot be asserted outside a hook case.
   const OUTPUT_IS_A_HOOK_ASSERTION: &str =
       "`expect.output` is a hook assertion: only a hook observation records whether \
        anything was emitted, so this expectation could never fail here";

   if let Some(output) = &raw.expect.output {
       if output != "none" {
           return Err(format!(
               "`expect.output` only accepts \"none\", got `{output}`"
           ));
       }
       if !matches!(kind, CaseKind::Hook { .. }) {
           return Err(String::from(OUTPUT_IS_A_HOOK_ASSERTION));
       }
   }
   if let CaseKind::Flow { steps } = &kind {
       for (index, step) in steps.iter().enumerate() {
           let Some(expect) = &step.expect else {
               continue;
           };
           match expect.output.as_deref() {
               None => {}
               Some("none") => {
                   return Err(format!("flow step {index}: {OUTPUT_IS_A_HOOK_ASSERTION}"));
               }
               Some(other) => {
                   return Err(format!(
                       "flow step {index}: `expect.output` only accepts \"none\", got `{other}`"
                   ));
               }
           }
       }
   }
   ```

   A step's expectations are judged against a script-shaped observation
   (`crates/claudevs/src/suite.rs:224-232` again), so the refusal is the same one for the same reason.

   Asserting that a *script* produced no output is a legitimate thing to want, and it is deliberately
   not added here — the plugin-adoption chain owns negative assertions and the case-authoring
   vocabulary. Adding a second spelling of the same idea in two chains at once is how a duplicate type
   gets born. Do not add the feature.

5. Run and confirm green:

   ```
   $ cargo test -p claudevs --lib case::model
   test result: ok. N passed; 0 failed
   ```

6. **See it fail.** Remove the `matches!(kind, CaseKind::Hook { .. })` check and confirm three of the
   four new tests go red. Restore it.

7. Re-run the throwaway case from step 1 and confirm it is now a named load error rather than a pass:

   ```
   claudevs: cannot load case …: `expect.output` is a hook assertion: only a hook observation
   records whether anything was emitted, so this expectation could never fail here
   ```

8. Commit `fix(claudevs): refuse an expect.output assertion that could never fail`.

---

## Task 2 — The default project is a project, and the payload names a file in it

Spec §3.4 asks for a synthesized project that is git-initialised with a tracked file, carries a
manifest, and whose `tool_input.file_path` points at a path inside it. All three land in one task,
because the falsifiable test is the one that checks the payload and the project *against each other*
— either alone is green against a constant it defined itself.

**Files:**
- Modify `crates/claudevs/src/harness/project.rs`
- Modify `crates/claudevs/src/harness/payload.rs`

**Steps:**

1. Read `crates/claudevs/src/harness/project.rs:17-67` and
   `crates/claudevs/src/suite.rs:131-135`. Four facts decide this task's shape, and the fourth is the
   one that constrains it:

   - `suite.rs:132-135` builds `Project::from_fixture` **only when the case names a fixture** and
     `Project::empty()` otherwise. Most hook cases name no fixture, so `empty()` is the default.
   - `Project::empty()` at `project.rs:23-30` is a bare `tempfile::tempdir()`. Nothing else.
   - `git init` lives inside `from_fixture` at `project.rs:48-65`, behind a `.gitinit` fixture marker
     — and its commit is `--allow-empty`, so there is no tracked file today either. The spec's phrase
     "already runs `git init` plus one commit" is accurate; "with a tracked file" is not yet true of
     anything.
   - **`from_fixture` is built on `empty()`.** `project.rs:45` is `let project = Self::empty()?;`
     before `copy_tree`. So changing `empty()` changes every fixture project too — injecting a manifest
     into a tree whose author may have shipped their own, and running `git init` twice on the
     `.gitinit` path.

   The fourth fact means the change cannot go into `empty()` alone. Split the tempdir from the project
   shape.

2. Add the failing tests to the existing `#[cfg(test)] mod tests` in `project.rs`:

   ```rust
   #[test]
   fn the_default_project_looks_like_a_project_a_hook_could_branch_on() {
       let project = Project::empty().unwrap();
       let root = project.path();

       assert!(
           root.join("Cargo.toml").is_file(),
           "a hook that branches on project type finds nothing without a manifest"
       );
       assert!(
           root.join(super::TRACKED_FILE).is_file(),
           "a hook whose payload names a file needs that file to exist"
       );
       assert!(
           root.join(".git").is_dir(),
           "a hook that shells out to git needs a repository"
       );
   }

   #[test]
   fn the_default_projects_tracked_file_is_committed_not_merely_present() {
       let project = Project::empty().unwrap();
       let output = std::process::Command::new("git")
           .args(["ls-files", "--error-unmatch", super::TRACKED_FILE])
           .current_dir(project.path())
           .output()
           .unwrap();
       assert!(
           output.status.success(),
           "`git ls-files --error-unmatch {}` failed: {}",
           super::TRACKED_FILE,
           String::from_utf8_lossy(&output.stderr)
       );
   }

   #[test]
   fn a_fixture_project_is_left_exactly_as_its_author_wrote_it() {
       // A fixture author owns their tree. A manifest injected into it could
       // collide with one they shipped, and `from_fixture`'s `.gitinit` marker
       // is how a fixture asks for a repository.
       let fixtures = tempfile::tempdir().unwrap();
       std::fs::create_dir_all(fixtures.path().join("plain")).unwrap();
       std::fs::write(fixtures.path().join("plain/README.md"), "x").unwrap();
       let project = Project::from_fixture(fixtures.path(), "plain").unwrap();
       assert!(!project.path().join("Cargo.toml").exists());
       assert!(!project.path().join(super::TRACKED_FILE).exists());
       assert!(!project.path().join(".git").exists());
   }
   ```

   and the cross-check to `payload.rs`'s test module — the one test that pins the payload and the
   project against each other rather than each against its own constant:

   ```rust
   #[test]
   fn the_default_tool_input_resolves_to_a_file_that_exists() {
       let project = crate::harness::Project::empty().unwrap();
       let mut payload = default_payload(HookEvent::PreToolUse);
       substitute_project(&mut payload, &project.path().display().to_string());
       let target = payload["tool_input"]["file_path"].as_str().unwrap();
       assert!(
           std::path::Path::new(target).is_file(),
           "a PreToolUse hook that stats its target must find one: {target}"
       );
   }
   ```

3. Run and confirm failure. The `project.rs` tests fail to compile (`TRACKED_FILE` does not exist) and
   the `payload.rs` cross-check fails at runtime:

   ```
   $ cargo test -p claudevs --lib harness::payload::tests::the_default_tool_input_resolves
   ---- harness::payload::tests::the_default_tool_input_resolves_to_a_file_that_exists stdout ----
   a PreToolUse hook that stats its target must find one: /var/folders/…/file.txt
   ```

   That red is the defect: the payload names `{project}/file.txt`, `{project}` resolves, and nothing
   ever created the file.

4. Implement in `project.rs`. Add the two constants and split the constructor:

   ```rust
   /// The one file the default project ships and tracks.
   ///
   /// A hook case's payload names this path, so a hook that stats its target
   /// finds a real file rather than taking the not-found branch. One constant so
   /// the project and the payload cannot drift apart —
   /// [`crate::harness::payload`] reads it.
   pub(crate) const TRACKED_FILE: &str = "file.txt";

   /// The manifest the default project ships.
   ///
   /// A hook guarding a lockfile, or refusing to run outside a package, takes its
   /// silent branch in a bare temp directory — and a case then passes exactly as
   /// well when the hook is broken as when it works. This closes that branch for
   /// the commonest shape; it does not close every one. A hook keyed on a
   /// `package.json` or a `pyproject.toml` still finds nothing, and a case that
   /// asserts too little still passes.
   const PROJECT_MANIFEST: &str = "\
   [package]
   name = \"claudevs-test-project\"
   version = \"0.1.0\"
   edition = \"2024\"
   ";
   ```

   ```rust
   /// A temp directory and nothing else.
   ///
   /// The substrate both constructors share. [`Project::empty`] builds the
   /// default project on top of it; [`Project::from_fixture`] copies a fixture
   /// tree into it and leaves that tree exactly as its author wrote it.
   fn bare() -> Result<Self> {
       let dir = tempfile::tempdir().map_err(|source| Error::Io {
           operation: "create temp project",
           path: String::from("(tempdir)"),
           source,
       })?;
       Ok(Self { dir })
   }

   /// A project with nothing in it but the shape of a project.
   ///
   /// Git-initialised, carrying a manifest and one tracked file. A bare temp
   /// directory would let a hook that branches on project state take its silent
   /// branch, which makes a case pass whether the hook works or not.
   ///
   /// # Errors
   ///
   /// [`Error::Io`] when the temp dir cannot be created or written, or when
   /// `git` is not on `PATH`.
   pub fn empty() -> Result<Self> {
       let project = Self::bare()?;
       let root = project.path();

       write_file(root.join("Cargo.toml"), PROJECT_MANIFEST)?;
       write_file(root.join(TRACKED_FILE), "claudevs test project\n")?;

       git(root, &["init", "-q"])?;
       git(root, &["add", "Cargo.toml", TRACKED_FILE])?;
       git(
           root,
           &[
               "-c",
               "user.email=t@t",
               "-c",
               "user.name=t",
               "commit",
               "-q",
               "-m",
               "init",
           ],
       )?;
       Ok(project)
   }
   ```

   and change `from_fixture`'s first line — `project.rs:45`, `let project = Self::empty()?;` — to:

   ```rust
   let project = Self::bare()?;
   ```

   Everything else in `from_fixture` stays as it is, `.gitinit` marker and `--allow-empty` commit
   included. The third test above is what pins that.

   `write_file` is a small helper mapping `std::fs::write`'s error into `Error::Io`; add one if the
   file has none, following the shape the existing `git` helper's error mapping uses. Read `git`'s
   definition before calling it — the calls at `:50-64` show its signature.

5. Implement in `payload.rs`. Build the `file_path` from the constant rather than from a second
   literal:

   ```rust
   HookEvent::PreToolUse | HookEvent::PostToolUse => serde_json::json!({
       "tool_name": "Edit",
       "tool_input": {
           "file_path": format!("{{project}}/{}", crate::harness::project::TRACKED_FILE),
       },
   }),
   ```

   The `{{project}}` doubling is `format!` escaping, producing the literal `{project}` the
   substitution step looks for. `payload.rs:48-51` already carries an
   `#[expect(clippy::literal_string_with_formatting_args, …)]` for exactly this token; run clippy and
   add the same attribute here only if it fires — an `#[expect]` that is not needed is itself a
   warning.

   `TRACKED_FILE` is `pub(crate)` and `harness::payload` is a descendant of `harness`, so the path
   resolves without a re-export.

6. Rewrite the module doc at `payload.rs:1-6`. It currently calls the defaults "provisional … replaced
   as a base layer by captured payloads once capture exists", which describes a plan rather than the
   code. Say instead that the defaults describe a project that exists on disk, and that the payload and
   the project read one constant so they cannot drift.

7. Run and confirm green — all four tests.

8. **See it fail, twice.** Comment out the `git add` line and confirm
   `the_default_projects_tracked_file_is_committed_not_merely_present` goes red with
   ``error: pathspec 'file.txt' did not match any file(s) known to git``. Restore it. Then change
   `from_fixture`'s first line back to `Self::empty()?` and confirm
   `a_fixture_project_is_left_exactly_as_its_author_wrote_it` goes red on the `Cargo.toml` assertion.
   Restore it. The second is the more important of the two: it is the whole reason this task splits the
   constructor.

9. Run the whole crate. Every fixtureless case now runs inside a git repository with two files in it,
   which is a behaviour change some test may be pinning:

   ```
   $ cargo test -p claudevs --all-targets
   ```

   A test that breaks because it counted the files in a fresh project was asserting the defect. Update
   it and say so in the commit body.

10. Commit `fix(claudevs): give the default test project a manifest, a tracked file and a repository`.

---

## Task 3 — The paired control: one case, run twice

This is the one test in the chain that asserts the *payload and project* did their job, and the spec
calls it "the one that differs in kind" — not two cases but one case run twice, once with the hook's
runtime available and once with it gone.

**Files:**
- Create `crates/claudevs/tests/fixtures/project-branch-plugin/.claude-plugin/plugin.json`
- Create `crates/claudevs/tests/fixtures/project-branch-plugin/hooks/guard.sh`
- Create `crates/claudevs/tests/fixtures/project-branch-plugin/hooks/hooks.json`
- Create `crates/claudevs/tests/fixtures/project-branch-plugin/tests/cases/a-guard-speaks.yaml`
- Modify `Makefile.toml`

**Steps:**

1. Read `crates/claudevs/tests/fixtures/minimal-plugin/` and copy its layout — manifest fields, case
   directory, case-file extension. `crates/claudevs/src/case/discover.rs` decides what is found.

2. `.claude-plugin/plugin.json`:

   ```json
   {
     "name": "project-branch-plugin",
     "version": "0.1.0",
     "description": "A PreToolUse hook that only speaks when it finds a real project."
   }
   ```

3. `hooks/guard.sh`, mode 0755:

   ```sh
   #!/bin/sh
   # Speaks only when the payload names a file that exists inside a project that
   # has a manifest. A bare temp directory takes the silent branch — which is
   # what a default payload and a default project have to prevent, or a case
   # passes whether this hook works or not.
   set -eu
   payload=$(cat)
   target=$(printf '%s' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
   [ -n "$target" ] || exit 0
   [ -f "$target" ] || exit 0
   [ -f "$(dirname "$target")/Cargo.toml" ] || exit 0
   echo "guard-saw-a-real-project"
   ```

4. `hooks/hooks.json`:

   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Edit",
           "hooks": [
             { "type": "command", "command": "sh ${CLAUDE_PLUGIN_ROOT}/hooks/guard.sh" }
           ]
         }
       ]
     }
   }
   ```

   The matcher is `Edit` and the default payload's `tool_name` is `Edit`
   (`crates/claudevs/src/harness/payload.rs:21`), so plan 03's matcher routing selects this group.

5. `tests/cases/a-guard-speaks.yaml` — it names **no** `project:` fixture, so it takes the
   `Project::empty()` path Task 2 changed. That is deliberate: the fixtureless default is the path
   spec §3.4 is about.

   ```yaml
   event: PreToolUse
   expect:
     stdout_contains: guard-saw-a-real-project
   ```

6. Run it and confirm green:

   ```
   $ cargo run -q -p claudevs-cli -- test crates/claudevs/tests/fixtures/project-branch-plugin
     ok    a-guard-speaks
   ```

7. **Now the control half.** Make the hook's dependency unavailable and re-run:

   ```
   $ mv crates/claudevs/tests/fixtures/project-branch-plugin/hooks/guard.sh \
        crates/claudevs/tests/fixtures/project-branch-plugin/hooks/guard.sh.disabled
   $ cargo run -q -p claudevs-cli -- test crates/claudevs/tests/fixtures/project-branch-plugin
     FAIL  a-guard-speaks
   $ mv crates/claudevs/tests/fixtures/project-branch-plugin/hooks/guard.sh.disabled \
        crates/claudevs/tests/fixtures/project-branch-plugin/hooks/guard.sh
   ```

   **If it still passes with the hook gone, the fix did not land.** Either the payload is still driving
   the hook down its silent branch, or the case is asserting something that does not depend on the
   hook. Stop and report rather than adjusting the assertion until it goes red.

8. Add the fixture to the `claudevs-check` lane's must-pass list in `Makefile.toml:165` onwards,
   following the lane's existing structure.

9. Commit `test(claudevs): add a hook that only speaks when the project is real`.

---

## ◆ CHECKPOINT — stop here and report

Tasks 1–3 close the half of this plan that makes a case *able to fail*. Report before continuing:

- the exact output of the throwaway `output: none` script case from Task 1, before and after
- whether Task 3's control half went red when `guard.sh` was renamed — quote both runs verbatim
- whether `a_fixture_project_is_left_exactly_as_its_author_wrote_it` went red when you put
  `Self::empty()` back into `from_fixture`
- any existing test that broke in Task 2 step 9 because it was pinning the bare-tempdir project

Wait for a go-ahead. Do not start Task 4.

---

## Task 4 — Drop the phase identifier from the event module's doc

**Files:**
- Modify `crates/claudevs/src/types/hook_event.rs`

**Steps:**

1. Read `crates/claudevs/src/types/hook_event.rs:1-6`. Two problems:

   ```rust
   //! The hook events the harness understands.
   //!
   //! Responsibilities: [`HookEvent`] and [`InvalidHookEvent`]. The variants are
   //! the events observed in real hooks.json files in this repository; the set is
   //! `#[non_exhaustive]` at the parse level (an unknown event is an error naming
   //! the known ones) and grows as capture (P4) grounds more.
   ```

   `(P4)` is a phase identifier, which `doc-comment-discipline` forbids in source. And "the events
   observed in real hooks.json files in this repository" is the habit this chain removes — the variant
   set is *what claudevs can simulate*, which is a different and better reason.

2. Rewrite it to state the invariant that separates this type from the contract catalogue, which is
   what `modularity` requires of two look-alike types:

   ```rust
   //! The hook events claudevs can run a case against.
   //!
   //! A variant here means the harness can synthesize a payload for the event and
   //! interpret what a hook returns from it. That is a narrower set than the
   //! events Claude Code documents, which live in [`crate::contract::event`]: a
   //! documented event claudevs cannot simulate is still one a plugin may
   //! legitimately wire, so a checker reads the catalogue while a case reads this
   //! type. Neither derives from the other, and merging them would make one
   //! answer serve two questions.
   //!
   //! Responsibilities: [`HookEvent`] and [`InvalidHookEvent`].
   ```

   The old text's `#[non_exhaustive]` claim is prose about parse behaviour, not the attribute. Plan 06
   adds the real attribute; do not add it here.

3. Run the doc gate. The intra-doc link to `crate::contract::event` must resolve; if it does not, plan
   01 has not landed and this plan's `depends-on` was not honoured:

   ```
   $ RUSTDOCFLAGS="-D warnings" cargo doc --workspace --all-features --no-deps
   ```

4. Commit `docs(claudevs): say what a HookEvent variant means without naming a phase`.

---

## Task 5 — Context injection is keyed off the catalogue

**Files:**
- Modify `crates/claudevs/src/harness/semantics.rs`

**Steps:**

1. Read `crates/claudevs/src/harness/semantics.rs:64-67`:

   ```rust
   } else if event == HookEvent::SessionStart && !captured.stdout.trim().is_empty() {
       observed.emitted = true;
       observed.context = Some(captured.stdout.trim().to_owned());
   }
   ```

   The reference states that bare stdout is injected as context for **four** events (`hooks.md:786`) —
   `UserPromptSubmit`, `UserPromptExpansion`, `SessionStart` and `PostModelSwitch` — and this reads one.
   Two of the four are simulatable, so this is a live gap.

   Do not hardcode that list here. `contract::event`'s catalogue already carries the fact as
   `DocumentedEvent::stdout_is_context`, verified against the reference, so read it from there — a
   second copy is how the two drift apart. This paragraph originally said three events, on a spec claim
   that turned out to be wrong; reading the catalogue is what makes that class of error impossible to
   repeat here.

2. Add the failing test:

   ```rust
   #[test]
   fn user_prompt_submit_bare_stdout_is_context_too() {
       let observed = observe(HookEvent::UserPromptSubmit, &captured(0, "remember X\n", ""));
       assert_eq!(observed.context.as_deref(), Some("remember X"));
       assert!(observed.emitted);
   }
   ```

   The existing `bare_stdout_on_pretooluse_is_not_context` test at `semantics.rs:164` is the control
   and must keep passing.

3. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib harness::semantics
   ---- harness::semantics::tests::user_prompt_submit_bare_stdout_is_context_too stdout ----
   assertion `left == right` failed
     left: None
    right: Some("remember X")
   ```

4. Implement, reading the flag from the catalogue rather than listing events here:

   ```rust
   } else if crate::contract::event::lookup(event.as_str())
       .is_some_and(|documented| documented.stdout_is_context)
       && !captured.stdout.trim().is_empty()
   {
       observed.emitted = true;
       observed.context = Some(captured.stdout.trim().to_owned());
   }
   ```

5. Run and confirm green, with the control still green.

6. **See it fail.** Set `stdout_is_context: false` on the `UserPromptSubmit` row in
   `contract/event.rs`, confirm the new test goes red, and restore it. That is the check that the
   behaviour really is reading the catalogue and not a coincidence.

7. Update the module doc at `semantics.rs:1-11`, whose third bullet names `SessionStart` specifically.
   Name the catalogue as the source instead of the event.

8. Commit `fix(claudevs): inject bare stdout as context for every event that documents it`.

---

## Task 6 — The two missing decision mechanisms

**Files:**
- Modify `crates/claudevs/src/harness/semantics.rs`

**Steps:**

1. `observe` sets `observed.decision` from exactly two sources today:
   `hookSpecificOutput.permissionDecision` (`semantics.rs:50-59`) and `PreToolUse` exit 2
   (`semantics.rs:69-72`). The reference names four mechanisms. The two unread ones are a top-level
   `decision: "block"` field and `hookSpecificOutput.decision.behavior`.

   This task still does **not** gate on `DocumentedEvent::decision`, but the reason has changed and the
   original one no longer applies. This paragraph used to say the column was `Unspecified` for almost
   every event because the reference stated almost none. That was wrong: the reference carries a
   decision-control table at `hooks.md:1011-1025` covering all 33 events, so the column is fully
   populated with twelve mechanisms and there is no `Unspecified` variant.

   Read every field regardless of what the catalogue says the event supports. Reading a field an event
   does not use costs nothing — a hook that does not write it leaves it absent — whereas gating on the
   catalogue would make claudevs blind to a hook that writes a field the docs do not list for its event,
   which is a real thing a plugin author can do and something the harness should surface rather than
   silently drop. The column exists so a checker can say "this event has no decision control, so a hook
   writing `decision` there is not being served"; that is plan 05's business, not this task's.

2. Add the failing tests:

   ```rust
   #[test]
   fn a_top_level_block_decision_is_read() {
       let json = r#"{"decision":"block","reason":"not allowed"}"#;
       let observed = observe(HookEvent::PreToolUse, &captured(0, json, ""));
       assert_eq!(observed.decision, Some(Decision::Deny));
       assert!(observed.emitted);
   }

   #[test]
   fn a_hook_specific_behavior_field_is_read() {
       let json = r#"{"hookSpecificOutput":{"decision":{"behavior":"deny"}}}"#;
       let observed = observe(HookEvent::PreToolUse, &captured(0, json, ""));
       assert_eq!(observed.decision, Some(Decision::Deny));
       assert!(observed.emitted);
   }

   #[test]
   fn claudevs_prefers_the_more_specific_field_when_a_hook_writes_two() {
       // The reference states no precedence between these. Most-specific-first
       // is claudevs' choice, pinned here so it is a decision rather than an
       // accident of evaluation order.
       let json = r#"{"decision":"block","hookSpecificOutput":{"permissionDecision":"allow"}}"#;
       let observed = observe(HookEvent::PreToolUse, &captured(0, json, ""));
       assert_eq!(observed.decision, Some(Decision::Allow));
   }
   ```

3. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib harness::semantics
   ---- harness::semantics::tests::a_top_level_block_decision_is_read stdout ----
   assertion `left == right` failed
     left: None
    right: Some(Deny)
   ```

4. Implement. Replace the `if let Some(specific) = …` block at `semantics.rs:48-67`:

   ```rust
   /// A decision string as any of the documented mechanisms spell it.
   ///
   /// `"block"` and `"deny"` are the same outcome under different field names.
   /// A value neither the reference nor this function recognises leaves the
   /// decision unset while still counting as an emission — a hook that wrote an
   /// envelope did emit, whatever it put in it.
   fn decision_from(value: &str) -> Option<Decision> {
       match value {
           "allow" => Some(Decision::Allow),
           "deny" | "block" => Some(Decision::Deny),
           "ask" => Some(Decision::Ask),
           "defer" => Some(Decision::Defer),
           _ => None,
       }
   }
   ```

   **Keep the `else` bound to what it is bound to today, or you will drop an emission.** At
   `semantics.rs:48` the `if` condition is
   `envelope.as_ref().and_then(|e| e.get("hookSpecificOutput"))`, so a hook that prints JSON carrying
   *no* `hookSpecificOutput` — `{"foo":1}` — falls into the bare-stdout branch and, on a
   context-injecting event, sets `emitted = true`. Rebinding the `if` to "the stdout parsed as JSON"
   would swallow that case into the envelope branch, which sets neither the decision nor the context —
   turning an `expect: output: none` assertion on such a hook from a correct fail into a vacuous pass.
   That is precisely the class Task 1 exists to remove, reintroduced one branch over.

   So the condition is "an envelope claudevs recognises", meaning `hookSpecificOutput` **or** a
   top-level string `decision`:

   ```rust
   let specific = envelope.as_ref().and_then(|e| e.get("hookSpecificOutput"));
   // `as_str` is what separates the top-level `decision: "block"` string from
   // `hookSpecificOutput.decision`, which is an object. A top-level `decision`
   // that is not a string is not this mechanism.
   let top_level = envelope
       .as_ref()
       .and_then(|e| e.get("decision"))
       .and_then(serde_json::Value::as_str);

   if specific.is_some() || top_level.is_some() {
       observed.emitted = true;

       // Precedence runs most-specific-first: `permissionDecision`, then
       // `hookSpecificOutput.decision.behavior`, then the top-level `decision`
       // field. The reference states no precedence between them, so this is
       // claudevs' choice and not a documented rule.
       let permission = specific
           .and_then(|s| s.get("permissionDecision"))
           .and_then(serde_json::Value::as_str);
       let behavior = specific
           .and_then(|s| s.get("decision"))
           .and_then(|d| d.get("behavior"))
           .and_then(serde_json::Value::as_str);

       observed.decision = permission.or(behavior).or(top_level).and_then(decision_from);
       observed.context = specific
           .and_then(|s| s.get("additionalContext"))
           .and_then(serde_json::Value::as_str)
           .map(str::to_owned);
   } else if crate::contract::event::lookup(event.as_str())
       .is_some_and(|documented| documented.stdout_is_context)
       && !captured.stdout.trim().is_empty()
   {
       observed.emitted = true;
       observed.context = Some(captured.stdout.trim().to_owned());
   }
   ```

   Add the regression test for exactly the case that would have been dropped — no existing test
   covers it, because `sessionstart_bare_stdout_is_context` at `semantics.rs:158` uses
   `"remember X\n"`, which is not JSON:

   ```rust
   #[test]
   fn json_stdout_with_no_envelope_claudevs_knows_is_still_injected_as_context() {
       let observed = observe(HookEvent::SessionStart, &captured(0, r#"{"foo":1}"#, ""));
       assert!(observed.emitted, "a SessionStart hook that printed did emit");
       assert_eq!(observed.context.as_deref(), Some(r#"{"foo":1}"#));
   }
   ```

   The `emitted` condition widened in one direction only: today it is set when `hookSpecificOutput`
   is present (`semantics.rs:49`), and now a top-level string `decision` also counts.
   `exit_two_means_nothing_special_on_other_events` at `:151` asserts `!observed.emitted` for an
   envelope-less run and is unaffected.

5. Run and confirm green — every existing decision test included. The four at `:103-124` exercise the
   `permissionDecision` path and must not move.

6. **See it fail.** Remove `.or(top_level)` and confirm `a_top_level_block_decision_is_read` goes red;
   restore it, remove `.or(behavior)`, and confirm `a_hook_specific_behavior_field_is_read` goes red.
   Restore both.

7. Update the module doc's bullet list at `semantics.rs:5-11` — it names two mechanisms and there are
   now four, with a stated precedence between them.

8. Commit `fix(claudevs): read every documented way a hook communicates a decision`.

---

## Task 7 — `Verdict::Fail` carries typed mismatches

**Files:**
- Modify `crates/claudevs/src/harness/verdict.rs`
- Modify `crates/claudevs/src/suite.rs`
- Modify `crates/claudevs/src/case/runner.rs`

**Steps:**

1. Find every producer before designing the enum. There are **six**, not one:

   ```
   $ grep -rn 'Verdict::Fail' crates/claudevs/src
   ```

   | Site | What it carries | Variant it needs |
   |---|---|---|
   | `harness/verdict.rs:79` | the eight assertions `judge` makes | eight assertion variants |
   | `suite.rs:262` | a flow step's mismatches, each prefixed `step {index}: ` | a wrapper carrying the index |
   | `suite.rs:277` | "flow: no run step executed …" | `DidNotRun` |
   | `case/runner.rs:42` | an opaque reason a Lua scripted case reported | `Reported` |
   | plan 02 Task 6 | an unloadable case file | `DidNotRun` |
   | plan 03 Task 6 | an unresolvable hook | `DidNotRun` |

   The spec (§3.6) says "one variant per assertion", and three of these are not assertions. Rather than
   force them into an assertion-shaped variant or leave them as strings beside typed siblings, the enum
   carries **eight assertion variants plus three structural ones**, and its doc comment says which are
   which. A reader who meets `Reported` and expects an assertion should find the answer in the type.

2. Add the failing tests to `verdict.rs`:

   ```rust
   #[test]
   fn a_stdout_mismatch_carries_what_was_actually_printed() {
       let dir = tempfile::tempdir().unwrap();
       let mut run = observed();
       run.stdout = String::from("something else entirely");
       let expect = Expectations {
           stdout_contains: Some(String::from("expected-token")),
           ..Expectations::default()
       };
       let Verdict::Fail(mismatches) = judge(&expect, &run, dir.path()) else {
           panic!("expected a failing verdict");
       };
       assert_eq!(
           mismatches[0],
           Mismatch::StdoutMissing {
               expected: String::from("expected-token"),
               observed: String::from("something else entirely"),
           },
       );
   }

   #[test]
   fn a_stdout_mismatch_on_silence_is_distinguishable_from_a_wrong_value() {
       let dir = tempfile::tempdir().unwrap();
       let mut run = observed();
       run.stdout = String::new();
       let expect = Expectations {
           stdout_contains: Some(String::from("expected-token")),
           ..Expectations::default()
       };
       let Verdict::Fail(mismatches) = judge(&expect, &run, dir.path()) else {
           panic!("expected a failing verdict");
       };
       let Mismatch::StdoutMissing { observed, .. } = &mismatches[0] else {
           panic!("{mismatches:?}");
       };
       assert!(observed.is_empty(), "silence must be visible as silence");
   }
   ```

3. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib harness::verdict
   error[E0433]: failed to resolve: use of undeclared type `Mismatch`
   ```

4. Implement:

   ```rust
   /// One way a case failed.
   ///
   /// Eleven variants in two groups. Eight are assertions — one per expectation
   /// [`judge`] can test — and three are structural: a case that never ran
   /// ([`Mismatch::DidNotRun`]), a scripted case that reported its own failure
   /// ([`Mismatch::Reported`]), and a wrapper naming which flow step failed
   /// ([`Mismatch::InStep`]). The three exist because a run's outcomes are one
   /// list, and a caller reading that list should not need a second shape for the
   /// entries that never reached an assertion.
   ///
   /// Typed rather than a rendered sentence, so `--json` carries structure a
   /// consumer can act on and the human text has one place it is derived. The
   /// assertion group grows every time an assertion is added, which is why this
   /// enum is `#[non_exhaustive]`: that is a change claudevs makes routinely, and
   /// a downstream exhaustive `match` should not break on it.
   #[derive(Debug, Clone, PartialEq, Eq, serde::Serialize)]
   #[serde(tag = "kind", rename_all = "snake_case")]
   #[non_exhaustive]
   pub enum Mismatch {
       // ── structural ──────────────────────────────────────────────────────
       /// Nothing ran: the case would not load, its hook resolved to nothing, or
       /// a flow declared no run step.
       DidNotRun {
           /// What stopped it.
           reason: String,
       },
       /// A scripted case reported its own failure.
       Reported {
           /// What it said. Opaque to claudevs — the script decides the wording.
           reason: String,
       },
       /// A flow step failed; which one, and how.
       InStep {
           /// 0-based index of the step, in declaration order.
           index: usize,
           /// The failure inside it.
           mismatch: Box<Mismatch>,
       },

       // ── assertions ──────────────────────────────────────────────────────
       /// The child was killed before it finished.
       TimedOut,
       /// Exit code differed.
       Exit {
           /// What the case asked for.
           expected: i32,
           /// What the run produced.
           observed: i32,
       },
       /// The decision differed.
       Decision {
           /// What the case asked for.
           expected: crate::case::Decision,
           /// What the hook communicated, if anything.
           observed: Option<crate::case::Decision>,
       },
       /// `output: none` was asserted and the hook emitted.
       UnexpectedOutput {
           /// What it emitted, as context or envelope.
           observed: Option<String>,
       },
       /// Injected context did not contain the expected substring.
       ContextMissing {
           /// The substring asked for.
           expected: String,
           /// The context that was injected, if any.
           observed: Option<String>,
       },
       /// stdout did not contain the expected substring.
       StdoutMissing {
           /// The substring asked for.
           expected: String,
           /// Everything the run printed to stdout.
           observed: String,
       },
       /// stderr did not contain the expected substring.
       StderrMissing {
           /// The substring asked for.
           expected: String,
           /// Everything the run printed to stderr.
           observed: String,
       },
       /// A file the case expected is not in the project.
       FileMissing {
           /// The path, relative to the project root.
           expected: String,
       },
   }
   ```

   `Box<Mismatch>` in `InStep` is required — an enum cannot contain itself by value — and also keeps
   the enum small enough that clippy's `large_enum_variant` stays quiet.

   **Export it, in both places.** `mod verdict;` at `crates/claudevs/src/harness/mod.rs:16` is
   private, so a `pub enum` inside it that nothing re-exports trips `unreachable_pub = "warn"`
   (root `Cargo.toml`, `[workspace.lints.rust]`) and fails the gate. Independently of the lint, a
   public `Verdict::Fail(Vec<Mismatch>)` whose payload no consumer can name defeats the whole point of
   typing it. Two lines:

   ```rust
   // crates/claudevs/src/harness/mod.rs:26
   pub use verdict::{Mismatch, Verdict, judge};
   ```

   ```rust
   // crates/claudevs/src/lib.rs — beside the existing suite/validate/wiring re-exports
   pub use harness::Mismatch;
   ```

   Add `[`Mismatch`]` to `harness/mod.rs`'s "Responsibilities:" list at `:4-7` while you are there;
   that list is a table of contents and an unlisted public item makes it wrong.

5. Change `Verdict::Fail(Vec<String>)` to `Verdict::Fail(Vec<Mismatch>)` and migrate all six producers:

   - `verdict.rs:79` — rewrite `judge`'s eight pushes as variant constructions.
   - `suite.rs:262-267` — replace the `format!("step {index}: {m}")` map with
     `.map(|mismatch| Mismatch::InStep { index, mismatch: Box::new(mismatch) })`.
   - `suite.rs:277-280` — `Mismatch::DidNotRun { reason: String::from("flow: no run step executed …") }`,
     keeping the existing wording.
   - `case/runner.rs:42` — `Mismatch::Reported { reason }`.
   - plan 02 Task 6's and plan 03 Task 6's sites — `Mismatch::DidNotRun { reason }`.

   **Do not** put the rendered sentence in the enum as well; deriving it once, in the renderer, is the
   point.

6. Run and confirm green. Existing tests asserting on a `String` mismatch need updating —
   `a_timed_out_run_never_passes` at `:147` asserts `mismatches[0].contains("timed out")` and becomes
   `assert_eq!(mismatches[0], Mismatch::TimedOut)`. `render.rs:246` has a `Verdict::Fail(vec![String::from(…)])`
   test literal that needs the same treatment.

7. Commit `feat(claudevs): make a failing case a typed mismatch, not a sentence`.

---

## Task 8 — Rendering derives the sentence

**Files:**
- Modify `crates/claudevs/src/report/render.rs`

**Steps:**

1. `crates/claudevs/src/report/render.rs:85` is where a `Verdict::Fail`'s contents reach a human. It
   currently prints the strings; it now renders each `Mismatch`.

2. Add the failing tests:

   ```rust
   #[test]
   fn a_stdout_mismatch_renders_both_sides() {
       let line = super::render_mismatch(&Mismatch::StdoutMissing {
           expected: String::from("token"),
           observed: String::from("other"),
       });
       assert!(line.contains("token"), "{line}");
       assert!(line.contains("other"), "{line}");
   }

   #[test]
   fn silence_renders_as_silence_not_as_an_empty_gap() {
       let line = super::render_mismatch(&Mismatch::StdoutMissing {
           expected: String::from("token"),
           observed: String::new(),
       });
       assert!(line.contains("nothing"), "{line}");
   }

   #[test]
   fn a_step_mismatch_names_the_step_and_the_failure_inside_it() {
       let line = super::render_mismatch(&Mismatch::InStep {
           index: 2,
           mismatch: Box::new(Mismatch::Exit {
               expected: 0,
               observed: 1,
           }),
       });
       assert!(line.contains("step 2"), "{line}");
       assert!(line.contains("exit"), "{line}");
   }

   #[test]
   fn every_mismatch_variant_renders_a_non_empty_sentence() {
       for mismatch in [
           Mismatch::DidNotRun { reason: String::from("r") },
           Mismatch::Reported { reason: String::from("r") },
           Mismatch::InStep {
               index: 0,
               mismatch: Box::new(Mismatch::TimedOut),
           },
           Mismatch::TimedOut,
           Mismatch::Exit { expected: 0, observed: 1 },
           Mismatch::Decision {
               expected: crate::case::Decision::Deny,
               observed: None,
           },
           Mismatch::UnexpectedOutput { observed: None },
           Mismatch::ContextMissing {
               expected: String::from("e"),
               observed: None,
           },
           Mismatch::StdoutMissing {
               expected: String::from("e"),
               observed: String::from("o"),
           },
           Mismatch::StderrMissing {
               expected: String::from("e"),
               observed: String::from("o"),
           },
           Mismatch::FileMissing { expected: String::from("f") },
       ] {
           assert!(!super::render_mismatch(&mismatch).is_empty(), "{mismatch:?}");
       }
   }
   ```

   The last test is what stops a new variant reaching a report as a blank line. `Mismatch` is
   `#[non_exhaustive]`, so `render_mismatch`'s `match` is in this crate and stays exhaustive — the
   compiler catches a missing arm, and this test catches an arm that returns nothing.

3. Run and confirm failure, then implement `render_mismatch` — one arm per variant, each producing the
   sentence that variant used to carry. Keep the existing wording where the information is the same, so
   a reader's muscle memory survives; extend only `stdout:`, `stderr:` and `output:`, which now have
   more to say. `InStep` recurses:

   ```rust
   Mismatch::InStep { index, mismatch } => {
       format!("step {index}: {}", render_mismatch(mismatch))
   }
   Mismatch::StdoutMissing { expected, observed } if observed.is_empty() => {
       format!("stdout: expected to contain `{expected}`, but nothing was printed")
   }
   Mismatch::StdoutMissing { expected, observed } => {
       format!("stdout: expected to contain `{expected}`, got {observed:?}")
   }
   ```

4. Confirm the JSON side. `Verdict` derives `serde::Serialize`, so `--json` now emits tagged `Mismatch`
   objects rather than strings:

   ```rust
   #[test]
   fn the_json_report_carries_structured_mismatches() {
       let report = crate::suite::SuiteReport {
           outcomes: vec![crate::suite::CaseOutcome {
               name: String::from("a-case"),
               verdict: crate::harness::Verdict::Fail(vec![Mismatch::StdoutMissing {
                   expected: String::from("token"),
                   observed: String::new(),
               }]),
               payload: None,
               handler: None,
           }],
           native: Vec::new(),
       };
       let json = super::render_json(&report).unwrap();
       // `render_json` is `serde_json::to_string_pretty`
       // (`crates/claudevs/src/report/render.rs:135-136`), so keys and values are
       // separated by `": "`, not `":"`. Assert on the parsed value rather than
       // on the text, which is both correct and immune to formatting changes.
       let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();
       let mismatch = &parsed["outcomes"][0]["verdict"]["Fail"][0];
       assert_eq!(mismatch["kind"], "stdout_missing", "{json}");
       assert_eq!(mismatch["expected"], "token", "{json}");
   }
   ```

   The `["verdict"]["Fail"]` path assumes `Verdict`'s default externally-tagged serialization. Print
   the JSON once and read it before pinning that path — `Verdict` may carry a `#[serde(...)]`
   attribute that changes it.

   `payload` and `handler` are Task 9's fields; drop those two lines if you run this before Task 9.
   `CaseOutcome` is not `#[non_exhaustive]` until plan 06, so the literal compiles either way.

   This is a public report-shape change. It is free before publication and expensive after, which is
   why it lands now.

5. Run the gate:

   ```
   $ cargo test --workspace --all-targets --all-features
   ```

6. Commit `feat(claudevs): render a mismatch from its type and carry it in --json`.

---

## Task 9 — A failure says what the hook was given and what ran

**Files:**
- Modify `crates/claudevs/src/suite.rs`
- Modify `crates/claudevs/src/case/runner.rs`
- Modify `crates/claudevs/src/report/render.rs`

**Steps:**

1. This is what makes Tasks 2 and 3 survivable. A more realistic default project still cannot tell an
   author *which* branch their hook took; the payload and the argv, printed beside the mismatch, can.
   And spec §3.4 leaves one of the three named absences open on purpose — a hook that consults the
   plugin registry is still exercised against whatever registry the developer's machine has — so a
   diagnosable failure is the mitigation, not a nicety.

2. Add the failing tests to `suite.rs`'s test module:

   ```rust
   #[test]
   fn a_failing_hook_case_reports_the_payload_it_sent_and_the_handler_it_ran() {
       let dir = tempfile::tempdir().unwrap();
       let plugin = dir.path();
       std::fs::create_dir_all(plugin.join(".claude-plugin")).unwrap();
       std::fs::write(
           plugin.join(".claude-plugin/plugin.json"),
           r#"{"name":"p","version":"0.1.0"}"#,
       )
       .unwrap();
       std::fs::create_dir_all(plugin.join("hooks")).unwrap();
       // A hook that prints nothing, against a case that asserts it printed.
       std::fs::write(
           plugin.join("hooks/hooks.json"),
           r#"{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"true"}]}]}}"#,
       )
       .unwrap();
       std::fs::create_dir_all(plugin.join("tests/cases")).unwrap();
       std::fs::write(
           plugin.join("tests/cases/a-silent-hook.yaml"),
           "event: SessionStart\nexpect:\n  stdout_contains: never-printed\n",
       )
       .unwrap();

       let report = super::run_suite(plugin, &super::SuiteOptions::default()).unwrap();
       let outcome = &report.outcomes[0];
       assert!(matches!(outcome.verdict, Verdict::Fail(_)));

       let Some(payload) = outcome.payload.as_ref() else {
           panic!("a failing hook case reports the payload it sent");
       };
       assert_eq!(payload["hook_event_name"], "SessionStart");
       assert_eq!(outcome.handler.as_deref(), Some("true"));

       let text = crate::report::render_human(&report);
       assert!(text.contains("hook_event_name"), "the payload is missing: {text}");
   }

   #[test]
   fn a_passing_hook_case_does_not_echo_its_payload() {
       // A green run stays readable. The payload is diagnostic material, and a
       // case that passed needs no diagnosis.
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
           plugin.join("tests/cases/a-quiet-hook.yaml"),
           "event: SessionStart\nexpect:\n  exit: 0\n",
       )
       .unwrap();

       let report = super::run_suite(plugin, &super::SuiteOptions::default()).unwrap();
       assert!(matches!(report.outcomes[0].verdict, Verdict::Pass));
       assert!(report.outcomes[0].payload.is_none());
       assert!(report.outcomes[0].handler.is_none());
   }
   ```

3. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib suite::tests::a_failing_hook_case_reports
   error[E0609]: no field `payload` on type `&CaseOutcome`
   ```

4. Implement. `CaseOutcome` gains two optional fields:

   ```rust
   /// One case's reported outcome.
   #[derive(Debug, Clone, serde::Serialize)]
   pub struct CaseOutcome {
       /// The case name.
       pub name: String,
       /// Pass or the mismatch list.
       pub verdict: Verdict,
       /// The payload the hook was given — present only for a hook case that
       /// failed, because a case that passed needs no diagnosis and a green run
       /// should stay readable.
       #[serde(skip_serializing_if = "Option::is_none")]
       pub payload: Option<serde_json::Value>,
       /// The handler that ran, in its display form — for an exec handler this is
       /// the argv actually spawned, which a shell-only reading of `hooks.json`
       /// makes invisible. Present under the same condition as `payload`.
       #[serde(skip_serializing_if = "Option::is_none")]
       pub handler: Option<String>,
   }
   ```

   No `#[serde(default)]`: this struct derives `Serialize` only, and `default` is a deserialization
   attribute that would do nothing here.

   Populate both in `run_case`'s hook path, from the payload value plan 03 Task 6 already parses and
   from `handler.display()` (plan 01 Task 7), and only when the verdict is `Fail`.

5. Migrate every other `CaseOutcome` construction — the compiler names them:

   ```
   $ cargo build -p claudevs 2>&1 | grep -B2 'missing fields'
   ```

   `crates/claudevs/src/case/runner.rs:38-44` is one of them, and the two sites plans 02 and 03 add are
   the others. All three take `payload: None, handler: None` — a Lua scripted case and a case that
   never ran have no hook context to report.

6. Update `render_human` to print both under a failing case, indented, and confirm `render_json`
   carries them.

7. Run the gate:

   ```
   $ cargo make dod
   $ cargo make claudevs-check
   ```

8. Commit `feat(claudevs): report the payload and the argv behind a failing hook case`.

---

## Done when

- `cargo make dod` is green with zero warnings.
- `cargo make claudevs-check` is green and covers `project-branch-plugin`.
- **This plan's half of the spec's paired-control table holds.** The spec (§6) names four controls;
  two are plan 03's (`args`, matcher routing) and two are this plan's:

  | Control | Task | Formerly vacuous case that must now fail |
  |---|---|---|
  | §3.1 `output: none` | 1 | the script case asserting `output: none` against `echo` |
  | §3.4 payload realism | 3 | the same case with `guard.sh` renamed away |

  Do not read this plan's completion as the table being satisfied — plan 03 carries the other two rows.
- Task 3's control half was observed failing. If it passed, the payload and project fixes did not land
  and nothing downstream should be trusted.
- `from_fixture` copies a fixture tree and adds nothing to it. `Project::empty()` is the only
  constructor that builds a project.
- All six `Verdict::Fail` producers construct `Mismatch` values; none constructs a `String`.
- `--json` carries tagged mismatch objects; a failing hook case carries its payload and handler, and a
  passing one does not.
- No new assertion vocabulary was added to the case model. An `output: none` for scripts belongs to the
  adoption chain.
