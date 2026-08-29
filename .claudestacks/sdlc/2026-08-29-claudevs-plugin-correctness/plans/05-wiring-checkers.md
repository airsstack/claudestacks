---
status: draft
created: 2026-08-29
depends-on: [01]
---

# Wiring Checker Recalibration Plan

**Goal:** Every wiring finding claudevs reports is real.

**Architecture:** Sweeping 156 third-party plugin roots produced 114 wiring findings: 37 errors
(34 `refs`, 3 `matchers`) and 77 `invocations` warnings. Each false class was given a mechanical rule
required to explain the whole population rather than the examples, and both populations account
exactly, each leaving one survivor — an accepted `refs` residual and one genuine `invocations`
finding. The rules move into the three checkers, which read `contract::site` and `contract::matcher`
instead of carrying their own guesses. `refs` and `matchers` produce errors; `invocations` stays a
warning, which never failed a stage anyway (`wiring/finding.rs:43-46`).

**Tech Stack:** Rust 2024, `walkdir`, `regex`, `serde_json`, the `contract` module from plan 01. No
new dependencies.

**Depends on:** plan 01 only. Nothing in this plan reads or writes what plans 02, 03 or 04 change,
so it can be worked in parallel with them — but it is not conflict-free: Task 11 edits
`crates/claudevs/src/lib.rs` (plans 01 and 02 also edit it, in different places) and `Makefile.toml`
(plans 02, 03 and 04 also edit it), and it may edit the committed `bad-matcher-plugin` fixture. Expect
to merge those three files by hand; every other file here is this plan's alone.

---

## Guideline conformance

- **`modularity`** — the three checkers stop deciding what a reference site is and what a matcher
  means; both come from `contract`. No checker gets its own copy.
- **`unit-test-mandate`** — `refs.rs`, `invocations.rs` and `matchers.rs` all already carry
  `#[cfg(test)] mod tests`; add to those.
- **`doc-comment-discipline`** — three doc comments in the tree assert things that stop being true in
  this plan and must be rewritten, not left: `lib.rs:8-10`, `wiring/mod.rs:9`, and
  `wiring/matchers.rs:1-8`. Task 11 owns them.
- **`strict-quality`** — no `#[allow(...)]`, no suppression to get the gate green. All three test
  modules this plan adds to already carry `#![expect(clippy::unwrap_used, …)]`
  (`refs.rs:115`, `invocations.rs:220`, `matchers.rs:74`), so the `.unwrap()` calls in the tests below
  are covered. None carries `clippy::panic`; if you add a test that panics — including inside a
  `let-else` — add `#![expect(clippy::panic, reason = "…")]` to that module, because
  `panic = "deny"` is set workspace-wide. An `#[expect]` nothing fulfils is itself a warning, so do
  not add one speculatively.

## The two populations, and what each task accounts for

| Class | Count | Task |
|---|---|---|
| `refs` — cited line is inside a fenced code block | 29 of 34 | 1 |
| `refs` — file is not one Claude Code loads | 3 of 34 | 2 |
| `refs` — reference extent swallowed a tool-argument matcher | 1 of 34 | 3 |
| `refs` — accepted residual (prose advice in an in-scope file) | 1 of 34 | — |
| `invocations` — the plugin's own `tests/` tree | 40 of 77 | 4 |
| `invocations` — referenced by bare stem, not by filename | 26 of 77 | 5 |
| `invocations` — language index files | 5 of 77 | 6 |
| `invocations` — not executable, outside `hooks/` | 5 of 6 residual | 7 |
| `invocations` — genuine (a shebanged `optimize-prompt.py` nothing names) | 1 | — |
| `matchers` — `Stop` reported as an unknown event | part of 3 | 8 |
| `matchers` — a matcher on an event that takes none | not detectable today | 9 |
| `matchers` — matcher compiled as a Rust regex | latent, 0 in corpus | 10 |

## File map

```
crates/claudevs/src/wiring/refs.rs         — [modify] skip fences, scope to loaded files, fix extent
crates/claudevs/src/wiring/invocations.rs  — [modify] four exemptions replacing the case-file one
crates/claudevs/src/wiring/matchers.rs     — [modify] read the catalogue and the matcher evaluator
crates/claudevs/src/wiring/mod.rs          — [modify] the module doc's description of `matchers`
crates/claudevs/src/lib.rs                 — [modify] the crate doc's claim about matcher regexes
Makefile.toml                              — [modify] the claudevs-check lane, if Task 8 changes it
crates/claudevs/tests/fixtures/bad-matcher-plugin/ — [modify] only if it stops failing (Task 11)
```

| File | Tasks |
|---|---|
| `wiring/refs.rs` | 1, 2, 3 |
| `wiring/invocations.rs` | 4, 5, 6, 7, 11 |
| `wiring/matchers.rs` | 8, 9, 10, 11 |
| `wiring/mod.rs`, `lib.rs` | 11 |
| `Makefile.toml`, `tests/fixtures/bad-matcher-plugin/` | 11 |

---

## Task 1 — A reference inside a fenced block is illustrative

Twenty-nine of the 34 `refs` errors are this. A schema document that teaches hook authoring cites
`${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh` inside a ` ```json ` block as an example; that is the
document doing its job.

**Files:**
- Modify `crates/claudevs/src/wiring/refs.rs`

**Steps:**

1. Read `crates/claudevs/src/wiring/refs.rs:37-53` (`occurrences`) and `:60-98` (`check`). Note that
   `occurrences` reports a 1-based line number for every match, which is exactly what
   `contract::site::fenced_lines` returns a set of.

2. Add the failing test to the existing `#[cfg(test)] mod tests`:

   ```rust
   #[test]
   fn a_reference_inside_a_fence_is_not_a_finding() {
       let dir = tempfile::tempdir().unwrap();
       std::fs::create_dir_all(dir.path().join("skills/authoring")).unwrap();
       std::fs::write(
           dir.path().join("skills/authoring/SKILL.md"),
           "Declare a hook like this:\n\
            ```json\n\
            {\"command\": \"${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh\"}\n\
            ```\n",
       )
       .unwrap();
       assert!(check(dir.path()).unwrap().is_empty());
   }

   #[test]
   fn a_reference_outside_a_fence_is_still_a_finding() {
       let dir = tempfile::tempdir().unwrap();
       std::fs::create_dir_all(dir.path().join("skills/authoring")).unwrap();
       std::fs::write(
           dir.path().join("skills/authoring/SKILL.md"),
           "Run ${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh before shipping.\n",
       )
       .unwrap();
       let findings = check(dir.path()).unwrap();
       assert_eq!(findings.len(), 1, "{findings:?}");
   }
   ```

   The second test is the control, and it is doing real work: a skill body pointing at a script that
   does not exist is broken wiring, and it is how the skills in this repository refer to their own
   files — in prose, not in fences. If you demote prose references to make the residual go away, this
   test is what stops you.

3. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib wiring::refs
   ---- wiring::refs::tests::a_reference_inside_a_fence_is_not_a_finding stdout ----
   assertion failed: check(dir.path()).unwrap().is_empty()
   ```

4. Implement. In `check`, compute the fenced lines once per file and skip occurrences that land in
   them:

   ```rust
   let fenced = crate::contract::site::fenced_lines(&text);

   for occurrence in occurrences(&text) {
       if occurrence.target.is_empty() || fenced.contains(&occurrence.line) {
           continue;
       }
       // … unchanged …
   }
   ```

5. Document why, in the module doc — this is the half of a distinction the `invocations` checker takes
   the other side of, and a reader who meets only one half will think one of them is wrong:

   ```rust
   //! Fenced code blocks are skipped here and read by the `invocations` checker,
   //! which is not a contradiction. This checker asks "does this path exist?",
   //! and an example path inside a fence is not claiming to. That checker asks
   //! "is this file referenced by anything?", and a command inside a fence is
   //! evidence that it is. Two questions of the same text, two right answers.
   ```

6. Run and confirm green — both tests.

7. **See it fail.** Remove the `fenced.contains(&occurrence.line)` clause and confirm the first test
   goes red while the second stays green. Restore it.

8. Commit `fix(claudevs): stop reporting a fenced example as a broken reference`.

---

## Task 2 — Only files Claude Code loads are wiring

Three of the 34, all in `obra/superpowers` — and one of them is a changelog entry announcing the very
removal it is being blamed for.

**Files:**
- Modify `crates/claudevs/src/wiring/refs.rs`

**Steps:**

1. Add the failing test:

   ```rust
   #[test]
   fn a_plugins_own_changelog_is_not_wiring() {
       let dir = tempfile::tempdir().unwrap();
       std::fs::write(
           dir.path().join("CHANGELOG.md"),
           "Removed ${CLAUDE_PLUGIN_ROOT}/scripts/old.sh in 2.0.\n",
       )
       .unwrap();
       assert!(check(dir.path()).unwrap().is_empty());
   }

   #[test]
   fn a_reference_inside_a_hook_script_is_wiring() {
       let dir = tempfile::tempdir().unwrap();
       std::fs::create_dir_all(dir.path().join("hooks")).unwrap();
       std::fs::write(
           dir.path().join("hooks/guard.sh"),
           "#!/bin/sh\nexec ${CLAUDE_PLUGIN_ROOT}/scripts/missing.sh\n",
       )
       .unwrap();
       let findings = check(dir.path()).unwrap();
       assert_eq!(findings.len(), 1, "{findings:?}");
   }
   ```

   The second test pins the deliberate widening: the scanned set is `hooks/**`, not
   `hooks/hooks.json`. A hook script is executed by Claude Code, so a path inside one is as
   load-bearing as a reference gets. **This class is empty in the corpus** — every
   `${CLAUDE_PLUGIN_ROOT}` occurrence inside a hook script across all 156 roots is a comment or an
   `os.environ.get('CLAUDE_PLUGIN_ROOT')`-style env read, not a path — so widening costs no measured
   finding. It is widened anyway, because this rule is the thinnest-evidenced in the plan (three
   findings, one repository) and the narrow version would stop checking a category nothing measured.

2. Run and confirm failure.

3. Implement. In `check`'s walk, skip files `contract::site` says Claude Code does not load.
   `refs.rs:75-80` already computes the plugin-relative path above the occurrence loop, but it lands
   as a `String` (`let file = entry.path().strip_prefix(…).display().to_string()`) and
   `is_loaded_file` takes a `&Path`. Keep the `&Path` and derive the `String` from it, so there is one
   binding rather than two computations of the same thing:

   ```rust
   let relative = entry
       .path()
       .strip_prefix(plugin_dir)
       .unwrap_or_else(|_| entry.path());
   if !crate::contract::site::is_loaded_file(relative) {
       continue;
   }
   let file = relative.display().to_string();
   ```

   Place this before the `read_to_string` at `:72-74`, not after: a file Claude Code does not load
   need not be read at all.

4. Run and confirm green.

5. **See it fail.** Invert the guard and confirm `a_plugins_own_changelog_is_not_wiring` goes red.
   Restore it.

6. Commit `fix(claudevs): scope reference checking to the files Claude Code loads`.

---

## Task 3 — A reference ends where the path ends

One of the 34, and the only one of the three cuts that is a defect in *what claudevs reads* rather
than *where it reads*. This corrects the intent, whose Evidence reads "All 34 `refs` errors point into
Markdown files, none at a wiring site" — command frontmatter is a wiring site, and this one is in it.

**Files:**
- Modify `crates/claudevs/src/wiring/refs.rs`

**Steps:**

1. Read the current extraction, `crates/claudevs/src/wiring/refs.rs:41-45`:

   ```rust
   let tail = capture.name("tail").map_or("", |m| m.as_str());
   let target = tail
       .trim_start_matches('/')
       .trim_end_matches(['.', ',', ';', ':', ')'])
       .to_owned();
   ```

   `trim_end_matches` strips a *trailing run* of those characters. For
   `${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)` the last character is `)`, which is
   stripped, then `*`, which is not in the set — so trimming stops and the target keeps `…sh:*`.

2. Add the failing test, reproducing `anthropics/ralph-wiggum` exactly:

   ```rust
   #[test]
   fn a_tool_argument_matcher_is_not_part_of_the_referenced_path() {
       let dir = tempfile::tempdir().unwrap();
       std::fs::create_dir_all(dir.path().join("commands")).unwrap();
       std::fs::create_dir_all(dir.path().join("scripts")).unwrap();
       std::fs::write(dir.path().join("scripts/setup-ralph-loop.sh"), "#!/bin/sh\n").unwrap();
       std::fs::write(
           dir.path().join("commands/ralph.md"),
           "---\nallowed-tools: [\"Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)\"]\n---\n",
       )
       .unwrap();
       let findings = check(dir.path()).unwrap();
       assert!(
           findings.is_empty(),
           "the script exists; `:*` is a tool-argument matcher, not part of the path: {findings:?}"
       );
   }
   ```

3. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib wiring::refs::tests::a_tool_argument_matcher
   ---- wiring::refs::tests::a_tool_argument_matcher_is_not_part_of_the_referenced_path stdout ----
   the script exists; `:*` is a tool-argument matcher, not part of the path:
   [Finding { severity: Error, checker: "refs", ...
     message: "`${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*` does not exist" }]
   ```

   That red is the third-party false error, reproduced.

4. Implement. Replace the `trim_end_matches` with `contract::site::reference_extent`, which scans
   forward to the first terminator rather than trimming backwards from the end:

   ```rust
   let tail = capture.name("tail").map_or("", |m| m.as_str());
   let target = crate::contract::site::reference_extent(tail)
       .trim_start_matches('/')
       .to_owned();
   ```

   Check the argument shape before writing this: `reference_extent` as specified in plan 01 Task 10
   expects text starting at the `$` of the variable and steps over `${CLAUDE_PLUGIN_ROOT}` itself,
   while `tail` here is already past it. Either pass the whole match rather than the tail, or confirm
   that `reference_extent` handles a bare tail correctly (its `scan_from` is 0 when the text does not
   start with the variable, which is the case here). Read plan 01's implementation and pick one
   deliberately; do not guess.

5. Run and confirm green, and confirm the existing extraction tests in this module still pass — a
   sentence-final period after a reference must still be dropped.

6. **See it fail.** Put the `trim_end_matches` back and confirm the new test goes red. Restore it.

7. Commit `fix(claudevs): stop swallowing a tool-argument matcher into a reference path`.

---

## Task 4 — A plugin's own tests are not wired into it

Forty of the 77 dead-file warnings.

**Files:**
- Modify `crates/claudevs/src/wiring/invocations.rs`

**Steps:**

1. Read `crates/claudevs/src/wiring/invocations.rs:128-158`. The only exemption today is
   `case_files.contains(path)` at `:138`, which exempts files matching *claudevs' own* case-file
   naming. A plugin whose tests are named by any other convention is reported.

2. Add the failing test:

   ```rust
   #[test]
   fn a_plugins_own_tests_directory_is_exempt_whatever_the_files_are_called() {
       let dir = tempfile::tempdir().unwrap();
       std::fs::create_dir_all(dir.path().join("tests")).unwrap();
       std::fs::write(dir.path().join("tests/test_guard.py"), "# nothing names me\n").unwrap();
       std::fs::write(dir.path().join("tests/helpers.sh"), "# nor me\n").unwrap();
       assert!(check(dir.path()).unwrap().is_empty());
   }

   #[test]
   fn a_script_outside_tests_that_nothing_names_is_still_reported() {
       let dir = tempfile::tempdir().unwrap();
       std::fs::create_dir_all(dir.path().join("scripts")).unwrap();
       std::fs::write(dir.path().join("scripts/orphan.sh"), "#!/bin/sh\n").unwrap();
       let findings = check(dir.path()).unwrap();
       assert_eq!(findings.len(), 1, "{findings:?}");
   }
   ```

3. Run and confirm failure.

4. Implement. Replace the `case_files.contains(path)` condition with a broader one and keep the
   case-file set as a second clause (a case file outside `tests/` is still exempt):

   ```rust
   /// Whether `relative` sits in the plugin's own test tree.
   ///
   /// A plugin's tests are not wired into the plugin, and claudevs' case-file
   /// naming is not the only convention — a plugin with a `tests/test_guard.py`
   /// is testing itself, not shipping dead wiring.
   fn is_in_tests_tree(relative: &str) -> bool {
       relative == "tests"
           || relative.starts_with("tests/")
           || relative.starts_with("tests\\")
   }
   ```

   and in the loop:

   ```rust
   if !is_script || case_files.contains(path) || is_in_tests_tree(relative) {
       continue;
   }
   ```

   `relative` is already in scope at `:133` as the second element of the tuple.

5. Run and confirm green — including the control, which must still report `scripts/orphan.sh`.

6. Commit `fix(claudevs): stop reporting a plugin's own tests as dead files`.

---

## Task 5 — A file referenced by its bare stem is referenced

Twenty-six of the 77. Module systems import by stem: `from hookify.core.config_loader import
load_rules` never spells `config_loader.py`, and Lua's `require("lib.globs")` never spells `globs.lua`.

**Files:**
- Modify `crates/claudevs/src/wiring/invocations.rs`

**Steps:**

1. Find every place the filename is compared. There are **three**, and a fix that reaches only one or
   two leaves the class open:

   - `crates/claudevs/src/wiring/invocations.rs:145` — `other_text.contains(name)`
   - `crates/claudevs/src/wiring/invocations.rs:186` — inside `mentions`, the fenced-command clause
   - `crates/claudevs/src/wiring/invocations.rs:189` — inside `mentions`, the reference-tail clause

   All three compare against the filename **with** its extension, so none can see a stem reference.

2. Add the failing test:

   ```rust
   #[test]
   fn a_python_module_imported_by_stem_is_referenced() {
       let dir = tempfile::tempdir().unwrap();
       std::fs::create_dir_all(dir.path().join("hookify/core")).unwrap();
       std::fs::write(dir.path().join("hookify/core/config_loader.py"), "RULES = []\n").unwrap();
       std::fs::write(
           dir.path().join("hookify/core/main.py"),
           "from hookify.core.config_loader import load_rules\n",
       )
       .unwrap();
       let findings = check(dir.path()).unwrap();
       assert!(
           findings.iter().all(|f| !f.message.contains("config_loader")),
           "{findings:?}"
       );
   }

   #[test]
   fn a_lua_module_required_by_stem_is_referenced() {
       let dir = tempfile::tempdir().unwrap();
       std::fs::create_dir_all(dir.path().join("lib")).unwrap();
       std::fs::write(dir.path().join("lib/globs.lua"), "return {}\n").unwrap();
       std::fs::write(dir.path().join("init.lua"), "local g = require(\"lib.globs\")\n").unwrap();
       let findings = check(dir.path()).unwrap();
       assert!(
           findings.iter().all(|f| !f.message.contains("globs")),
           "{findings:?}"
       );
   }

   #[test]
   fn a_stem_that_appears_nowhere_is_still_reported() {
       let dir = tempfile::tempdir().unwrap();
       std::fs::create_dir_all(dir.path().join("lib")).unwrap();
       std::fs::write(dir.path().join("lib/orphan.lua"), "return {}\n").unwrap();
       std::fs::write(dir.path().join("driver.lua"), "local g = require(\"lib.other\")\n").unwrap();
       let findings = check(dir.path()).unwrap();
       assert!(
           findings.iter().any(|f| f.message.contains("orphan.lua")),
           "{findings:?}"
       );
   }
   ```

   The driver is named `driver.lua`, not `init.lua`, and the assertion names the file rather than
   counting findings. `init.lua` is one of the index files Task 6 exempts, so at this point in the
   plan it would itself be reported and a `len() == 1` assertion would fail for a reason that has
   nothing to do with stems.

3. Run and confirm the first two fail and the third already passes.

4. Implement. Compute the stem alongside the name and test both, at all three sites:

   ```rust
   let Some(name) = path.file_name().and_then(|n| n.to_str()) else {
       continue;
   };
   // Module systems import by stem: a Python `from … import config_loader` and a
   // Lua `require("lib.globs")` never spell the extension. Matching only the
   // filename reports such a file as dead when it is the most-used file in the
   // plugin.
   let stem = path.file_stem().and_then(|n| n.to_str()).unwrap_or(name);
   let referenced = files.iter().any(|(other, _, other_text)| {
       other != path
           && (other_text.contains(name)
               || other_text.contains(stem)
               || mentions(other_text, name)
               || mentions(other_text, stem))
   });
   ```

   A bare-stem match is broader than a filename match and will occasionally be satisfied by an
   unrelated word. That is the right trade for a **warning**: `wiring/finding.rs:43-46` means a warning
   never fails a stage, so the cost of a missed dead file is a report that is quieter than it could be,
   while the cost of a false one is 26 wrong findings across 156 plugins.

5. Run and confirm all three green.

6. **See it fail.** Remove the two `stem` clauses and confirm the first two tests go red while the
   third stays green. Restore them.

7. Commit `fix(claudevs): count a module imported by its bare stem as referenced`.

---

## Task 6 — Language index files are referenced by their directory

Five of the 77, all `__init__.py`.

**Files:**
- Modify `crates/claudevs/src/wiring/invocations.rs`

**Steps:**

1. Add the failing test:

   ```rust
   #[test]
   fn a_language_index_file_is_exempt_because_its_directory_is_the_reference() {
       let dir = tempfile::tempdir().unwrap();
       std::fs::create_dir_all(dir.path().join("pkg")).unwrap();
       std::fs::write(dir.path().join("pkg/__init__.py"), "").unwrap();
       assert!(check(dir.path()).unwrap().is_empty());
   }
   ```

2. Run and confirm failure.

3. Implement:

   ```rust
   /// Files a language reaches by importing their directory rather than by name.
   ///
   /// One per scanned language. `mod.rs` is deliberately absent: `.rs` is not in
   /// [`SCRIPT_EXTENSIONS`], so a Rust file is never a candidate here and the
   /// entry would be dead code. Only `__init__.py` is backed by the corpus that
   /// motivated this exemption; `index.js` and `init.lua` are the same convention
   /// in the other two scanned languages and are included on that basis rather
   /// than on measurement.
   const INDEX_FILES: [&str; 3] = ["__init__.py", "index.js", "init.lua"];
   ```

   and add `|| INDEX_FILES.contains(&name)` to the skip condition.

4. Run and confirm green.

5. Commit `fix(claudevs): exempt a language index file from the dead-file report`.

---

## Task 7 — Sample material a skill ships for reading is not dead wiring

Five of the six residual.

**Files:**
- Modify `crates/claudevs/src/wiring/invocations.rs`

**Steps:**

1. Add the failing test, with its control:

   ```rust
   #[test]
   fn a_non_executable_sample_outside_hooks_is_not_dead_wiring() {
       let dir = tempfile::tempdir().unwrap();
       std::fs::create_dir_all(dir.path().join("skills/x")).unwrap();
       std::fs::write(dir.path().join("skills/x/example.sh"), "echo sample\n").unwrap();
       assert!(check(dir.path()).unwrap().is_empty());
   }

   #[test]
   fn a_shebanged_script_outside_hooks_that_nothing_names_is_still_reported() {
       let dir = tempfile::tempdir().unwrap();
       std::fs::create_dir_all(dir.path().join("scripts")).unwrap();
       std::fs::write(
           dir.path().join("scripts/optimize-prompt.py"),
           "#!/usr/bin/env python3\nprint('hi')\n",
       )
       .unwrap();
       let findings = check(dir.path()).unwrap();
       assert_eq!(findings.len(), 1, "{findings:?}");
   }

   #[test]
   fn a_non_executable_file_inside_hooks_is_still_reported() {
       let dir = tempfile::tempdir().unwrap();
       std::fs::create_dir_all(dir.path().join("hooks")).unwrap();
       std::fs::write(dir.path().join("hooks/helper.sh"), "echo helper\n").unwrap();
       let findings = check(dir.path()).unwrap();
       assert_eq!(findings.len(), 1, "{findings:?}");
   }
   ```

   The second test is the one genuine finding this checker produces across the whole 156-plugin corpus
   — a shebanged `optimize-prompt.py` under `scripts/` that nothing references. It is the thing the
   check was for, and it must survive every exemption above.

2. Run and confirm the first fails and the other two pass.

3. Implement:

   ```rust
   /// Whether a file presents as something meant to be run.
   ///
   /// A shebang or an executable bit. Sample material a skill ships for a reader
   /// has neither, and reporting it as dead wiring is reporting the skill for
   /// doing its job. Inside `hooks/`, everything is treated as executable
   /// regardless: that tree is what Claude Code runs, so a stray file there is
   /// worth a warning even without a bit set.
   fn presents_as_executable(path: &Path, text: &str, relative: &str) -> bool {
       if relative.starts_with("hooks/") || relative.starts_with("hooks\\") {
           return true;
       }
       if text.starts_with("#!") {
           return true;
       }
       std::fs::metadata(path).is_ok_and(|meta| {
           std::os::unix::fs::PermissionsExt::mode(&meta.permissions()) & 0o111 != 0
       })
   }
   ```

   The loop at `:133` already destructures `(path, relative, _)`; change the third binding from `_` to
   `text` so this function can read the shebang without a second file read, and add the call to the
   skip condition:

   ```rust
   if !is_script
       || case_files.contains(path)
       || is_in_tests_tree(relative)
       || INDEX_FILES.contains(&name)
       || !presents_as_executable(path, text, relative)
   {
       continue;
   }
   ```

   `name` is bound below the current skip condition (`:141-143`); move that `let Some(name) = …`
   binding above it, since two of the four clauses now need it.

   Add `use std::os::unix::fs::PermissionsExt as _;` at the top rather than the inline path if clippy
   prefers it. This is Unix-only, which the crate already is.

4. Run and confirm all three green.

5. **See it fail.** Return `true` unconditionally from `presents_as_executable` and confirm the first
   test goes red; return `false` unconditionally and confirm the other two go red. Restore it.

6. Commit `fix(claudevs): stop reporting non-executable sample material as dead wiring`.

---

## Task 8 — A documented event is not an unknown event

**Files:**
- Modify `crates/claudevs/src/wiring/matchers.rs`

**Steps:**

1. Read `crates/claudevs/src/wiring/matchers.rs:43-46`. The checker parses each event name with
   `HookEvent::from_str` — the *simulatable* five — and reports anything else as an error. `Stop` is a
   documented event claudevs cannot simulate, so a plugin wiring a `Stop` hook is failed for being
   correct.

2. Add the failing test:

   ```rust
   #[test]
   fn a_documented_event_claudevs_cannot_simulate_is_not_a_finding() {
       let dir = plugin(
           r#"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"true"}]}]}}"#,
       );
       assert!(check(dir.path()).unwrap().is_empty());
   }

   #[test]
   fn an_event_name_the_catalogue_does_not_know_is_a_warning_not_an_error() {
       let dir = plugin(r#"{"hooks":{"PreToolUseX":[{"hooks":[]}]}}"#);
       let findings = check(dir.path()).unwrap();
       assert_eq!(findings.len(), 1, "{findings:?}");
       assert_eq!(findings[0].severity, Severity::Warning);
   }
   ```

   The second test changes an existing behaviour deliberately. claudevs' catalogue can lag a Claude
   Code release, and a plugin using a newer event than claudevs knows about is not thereby broken. The
   existing test `an_unknown_event_name_is_an_error_naming_the_known_set` at `matchers.rs:95` asserts
   `Severity::Error` and must be updated — rename it to `..._is_a_warning_...` and change the
   assertion, in the same commit, so the change is visible in one diff.

3. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib wiring::matchers
   ---- wiring::matchers::tests::a_documented_event_claudevs_cannot_simulate_is_not_a_finding stdout ----
   assertion failed: check(dir.path()).unwrap().is_empty()
   ```

4. Implement. Replace the `HookEvent::from_str` check with a catalogue lookup:

   ```rust
   let documented = crate::contract::event::lookup(event);
   if documented.is_none() {
       findings.push(warning(format!(
           "`{event}` is not an event this version of claudevs knows about; \
            it may be newer than the catalogue"
       )));
   }
   ```

   Add a `warning(...)` constructor beside the existing `finding(...)` at `matchers.rs:62-70`, or
   change `finding` to take a `Severity`. The second is tidier and touches fewer call sites.

   `use std::str::FromStr as _;` and `use crate::types::HookEvent;` at `matchers.rs:11,15` become
   unused. Remove them — an unused import fails the gate.

5. Run and confirm green.

6. **See it fail.** Point `lookup` at `HookEvent::from_str(event).ok()` instead and confirm the `Stop`
   test goes red. Restore it.

7. Commit `fix(claudevs): stop failing a plugin for wiring a documented event`.

---

## Task 9 — A matcher on an event that takes none

A finding claudevs cannot make at all today. The reference states such a matcher "is silently
ignored", so the author's intent is not being served.

**Files:**
- Modify `crates/claudevs/src/wiring/matchers.rs`

**Steps:**

1. Add the failing test. It reproduces the intent's own probe, corrected — that probe carried bogus
   matchers on `UserPromptSubmit` **and** `SessionEnd` and expected both to be ignored, but the matcher
   table gives `SessionEnd` a matcher row and it is not in the matcher-less ten. So this test expects
   **one** finding, not two:

   ```rust
   #[test]
   fn a_matcher_on_an_event_that_takes_none_is_a_warning() {
       let dir = plugin(
           r#"{"hooks":{
                "UserPromptSubmit":[{"matcher":"Edit","hooks":[{"type":"command","command":"true"}]}],
                "SessionEnd":[{"matcher":"clear","hooks":[{"type":"command","command":"true"}]}]
              }}"#,
       );
       let findings = check(dir.path()).unwrap();
       assert_eq!(
           findings.len(),
           1,
           "SessionEnd does take a matcher; only UserPromptSubmit's is ignored: {findings:?}"
       );
       assert_eq!(findings[0].severity, Severity::Warning);
       assert!(findings[0].message.contains("UserPromptSubmit"), "{findings:?}");
       assert!(findings[0].message.contains("ignored"), "{findings:?}");
   }
   ```

2. Run and confirm failure — zero findings today.

3. Implement, inside the group loop where `matcher` is already extracted:

   ```rust
   if let Some(documented) = documented
       && documented.matcher == crate::contract::event::MatcherSupport::None
   {
       findings.push(warning(format!(
           "`{event}` takes no matcher, so `{matcher}` is silently ignored by the runtime"
       )));
   }
   ```

4. Run and confirm green.

5. **See it fail.** Add `SessionEnd` to the matcher-less set in `contract/event.rs` and confirm the
   test goes red with two findings — that is the intent's original claim, shown to be wrong. Restore
   the catalogue row.

6. Commit `feat(claudevs): warn when a matcher is written on an event that ignores it`.

---

## Task 10 — Well-formedness is judged by the matcher's own rules

Latent: no plugin in the 156 trips this today. It is settled here because it is the rule dispatch is
built on (plan 03), not because it was measured.

**Files:**
- Modify `crates/claudevs/src/wiring/matchers.rs`

**Steps:**

1. `crates/claudevs/src/wiring/matchers.rs:51` runs `regex::Regex::new(matcher)` on every matcher
   value. That is wrong twice over. `a, b` is a *list of two exact strings* and compiling it as a regex
   matches the literal `a, b` and nothing else — but it compiles, so no finding is produced and the
   error is silent. And a pattern using lookahead is valid in Claude Code's JavaScript engine and
   rejected by Rust's `regex` crate, so claudevs would report a plugin that is correct.

2. Add the failing tests:

   ```rust
   #[test]
   fn a_comma_list_is_not_compiled_as_a_pattern() {
       let dir = plugin(
           r#"{"hooks":{"PreToolUse":[{"matcher":"Edit, Write","hooks":[{"type":"command","command":"true"}]}]}}"#,
       );
       assert!(check(dir.path()).unwrap().is_empty());
   }

   #[test]
   fn a_pattern_rust_rejects_and_javascript_accepts_is_a_warning_naming_the_engine() {
       let dir = plugin(
           r#"{"hooks":{"PreToolUse":[{"matcher":"(?<=Edit)Write","hooks":[{"type":"command","command":"true"}]}]}}"#,
       );
       let findings = check(dir.path()).unwrap();
       assert_eq!(findings.len(), 1, "{findings:?}");
       assert_eq!(
           findings[0].severity,
           Severity::Warning,
           "a plugin whose pattern the runtime accepts must not be failed: {findings:?}"
       );
   }
   ```

   The existing test `a_matcher_that_does_not_compile_is_an_error` at `matchers.rs:104` uses `Edit(`
   and asserts an error. `Edit(` contains `(`, so it is regex-mode, and Rust rejects it — but so would
   JavaScript, since an unclosed group is invalid in both. Decide deliberately whether that stays an
   error (defensible: both engines reject it, so the plugin really is broken) or becomes a warning
   (defensible: claudevs cannot prove JavaScript rejects it without a JavaScript engine). Whichever you
   choose, say why in the test name and in the commit body. Erring toward the warning is consistent
   with the rest of this plan; erring toward the error keeps a real defect at the severity that fails a
   stage. **Raise this rather than deciding it silently** if you are unsure.

3. Run and confirm failure.

4. Implement, replacing the `regex::Regex::new` call:

   ```rust
   if let crate::contract::matcher::MatcherRule::Unsupported { value, reason } =
       crate::contract::matcher::parse(event_name, matcher)
   {
       findings.push(warning(format!(
           "claudevs cannot evaluate matcher `{value}` ({reason}), so it cannot tell whether \
            the runtime accepts it"
       )));
   }
   ```

   Two things changed since this block was drafted, and both matter here.

   `parse` takes the event name as well as the value, because `FileChanged` and `StopFailure` use a
   narrower exact-match set than every other event (`hooks.md:301`). The checker is already iterating
   `hooks.json` per event, so pass the name it is currently checking — `parse(matcher)` no longer
   compiles.

   `Unsupported` no longer means only "Rust's `regex` crate rejected this". It also covers a value made
   entirely of separator characters (`","`, `"|"`, `" "`), which the reference does not define: it grants
   match-all to `"*"`, `""` and an omitted matcher alone (`hooks.md:291`). So the message must not
   assert a regex cause. Keep the wording general and let `reason` carry the specifics — it already
   says whether the regex engine refused it or the value held only separators. If you want the
   regex-divergence explanation in the output, gate it on the reason rather than stating it
   unconditionally.

5. Run and confirm green.

6. **See it fail.** Restore `regex::Regex::new(matcher)` and confirm
   `a_pattern_rust_rejects_and_javascript_accepts_is_a_warning_naming_the_engine` goes red on the
   severity assertion. Restore the fix.

7. Commit `fix(claudevs): judge a matcher by its own rules, not as a Rust regex`.

---

## Task 11 — Correct the doc comments this plan falsified, and run the gate

Three doc comments in the tree assert that a matcher is compiled as a Rust regex. All three are now
wrong, and a wrong doc comment is worse than none.

**Files:**
- Modify `crates/claudevs/src/lib.rs`
- Modify `crates/claudevs/src/wiring/mod.rs`
- Modify `crates/claudevs/src/wiring/matchers.rs`

**Steps:**

1. `crates/claudevs/src/lib.rs:8-10`:

   ```rust
   //! Wiring's matcher check compiles each hooks.json `matcher` with the `regex`
   //! crate, which has no lookaround and no backreferences; a pattern relying on
   //! either is reported as a finding even where the runtime would accept it.
   ```

   Rewrite: a matcher is evaluated in the two modes the reference defines, and a pattern Rust cannot
   compile is a warning naming the divergence rather than an error against the plugin.

2. `crates/claudevs/src/wiring/mod.rs:9`:

   ```rust
   //! - [`matchers`] — does hooks.json declare known events and compiling regexes?
   ```

   Rewrite: does hooks.json declare documented events, with matchers the events accept and claudevs can
   evaluate?

3. `crates/claudevs/src/wiring/matchers.rs:1-8` — the whole module doc, which is four sentences about
   regex flavour. Replace with a description of what the checker now asks, pointing at
   `crate::contract` for the rules.

4. `crates/claudevs/src/wiring/invocations.rs` — the module doc carries the **other half** of the
   fence distinction Task 1 step 5 wrote into `refs.rs`. Spec §4.1 requires both: "each says so in its
   own module doc". A reader who meets only one half is left thinking one of the two checkers is
   wrong. Add:

   ```rust
   //! Fenced code blocks are read here and skipped by the `refs` checker, which
   //! is not a contradiction. This checker asks "is this file referenced by
   //! anything?", and a command inside a fence is evidence that it is. That one
   //! asks "does this path exist?", and an example path inside a fence is not
   //! claiming to. Two questions of the same text, two right answers.
   ```

   While you are in that doc comment, correct `:120-123`, which says a case file "is exempt even when
   nothing names it" as though that were the only exemption. There are now five.

5. Run the full gate:

   ```
   $ cargo make dod
   ```

6. Run the fixture lane:

   ```
   $ cargo make claudevs-check
   ```

   `bad-matcher-plugin` is a must-fail fixture whose `hooks.json` declares `PreToolUseX`. Task 8 made
   an unknown event a **warning**, and `wiring/finding.rs:43-46` means a warning does not fail the
   stage — so that fixture may now pass where the lane expects it to fail. If so, the fixture needs a
   defect that is still an error: give it a genuinely broken reference (a `${CLAUDE_PLUGIN_ROOT}` path
   that does not exist, outside a fence, in a loaded file) so it still fails at the wiring stage for a
   real reason. Update the lane's comment block to say what the fixture now fails on.

7. Commit `docs(claudevs): describe matcher checking as the contract defines it`.

---

## Task 12 — Sweep the corpus and record the residual

**Files:**
- No source changes.

**Steps:**

1. If a corpus checkout is available, re-sweep it and compare against the spec's numbers. Plan 06 adds
   `cargo make corpus-fetch` and `cargo make corpus-check`; if that plan has landed, use them. If it
   has not, clone the pinned SHAs from `crates/claudevs/tests/corpus/corpus.toml` by hand into a
   scratch directory and run `claudevs check` over each of the 156 roots.

2. The expected result after this plan:

   | Checker | Before | After |
   |---|---|---|
   | `refs` errors | 34 | 1 (the accepted residual) |
   | `invocations` warnings | 77 | 1 (the genuine `optimize-prompt.py`) |
   | `matchers` errors | 3 | 0 errors; some warnings are expected |

   The `refs` residual is a "Red Flags" list in `skills/plugin-authoring/SKILL.md` writing
   "**USE** `${CLAUDE_PLUGIN_ROOT}/scripts/format.sh`" as prose advice: an in-scope file, outside a
   fence, illustrative anyway. Separating that from a real reference needs authorial intent, not a
   rule. It stays reported. The target is one false positive across 156 plugins, not zero.

3. **If the numbers do not land, report them rather than adjusting a rule to fit.** Each rule here was
   required to explain its whole population; a rule that now over- or under-fires is evidence the
   population was misread, which is a fact worth more than a matching number.

4. Commit nothing from this task unless the sweep changed a rule; report the numbers.

---

## Done when

- `cargo make dod` is green with zero warnings.
- `cargo make claudevs-check` is green, and `bad-matcher-plugin` still fails at the wiring stage for a
  reason that is genuinely an error.
- Every fix in Tasks 1, 2, 3, 5, 7, 8, 9 and 10 was watched go red before it went green.
- No checker states plugin knowledge of its own; the reference-site rules come from `contract::site`
  and the matcher rules from `contract::matcher`.
- `lib.rs`, `wiring/mod.rs` and `wiring/matchers.rs` no longer claim a matcher is a Rust regex.
