---
status: done
created: 2026-08-29
depends-on: [01, 02]
---

# Hook Dispatch Implementation Plan

**Goal:** A hook case runs the handler Claude Code would have run for its payload.

**Architecture:** `harness::hooks_file` currently flattens every hook group for an event into a list
of command strings, ignoring both the `matcher` that selects a group and the `args` that decide how
the command is spawned. Two false greens follow: a case can pair an event with a payload the runtime
would route elsewhere and be told it passed, and an `args`-carrying handler silently runs as `sh -c
<command>` with its arguments discarded. Both are fixed by having `hooks_file` parse entries into
`contract::handler::HookCommand` and filter groups with `contract::matcher`, and having
`harness::spawn` dispatch on the handler variant. The `hook:` substring stays as a secondary filter,
applied to the handler's display form.

**Tech Stack:** Rust 2024, `serde_json`, the `contract` module from plan 01. No new dependencies.

**Depends on:** plan 01 (`contract::handler`, `contract::matcher`, `contract::event`) and plan 02
(an unloadable or failing case is one failed case rather than the death of the run — Task 6 of this
plan relies on that shape).

---

## Guideline conformance

- **`strong-types`** — a handler is a `HookCommand`, not a `String`. The spawn path dispatches on the
  variant rather than inspecting a string for shell metacharacters (parse-don't-validate).
- **`modularity`** — `hooks_file` does not re-derive matcher semantics; it calls `contract::matcher`,
  the same evaluator plan 05's checker uses. A second implementation here would be the split-brain the
  contract module exists to prevent.
- **`unit-test-mandate`** — `hooks_file.rs` and `spawn.rs` both already carry `#[cfg(test)] mod
  tests`; add to those.
- **`doc-comment-discipline`** — `hooks_file.rs:3-4` currently says the file shape was "verified
  against this repository's plugins". That sentence is the defect this chain exists to remove; replace
  it with a citation of the documented shape.
- **`strict-quality`, and the lint attributes specifically.** `[workspace.lints.clippy]` in the root
  `Cargo.toml` sets `unwrap_used = "deny"`, `panic = "deny"` and `expect_used = "warn"`, and the gate
  runs `-D warnings`. `crates/claudevs/src/harness/hooks_file.rs:85` and
  `crates/claudevs/src/harness/t_module.rs:540` each declare only
  `#![expect(clippy::unwrap_used, …)]`, so a new test using `panic!` — including inside a `let-else` —
  needs `#![expect(clippy::panic, reason = "tests panic to reject an unexpected shape")]` added to
  that module. `crates/claudevs/src/suite.rs:287` is the third: it declares `unwrap_used` only, and
  Task 6 adds a `panic!` there too. There is no `.expect(…)` anywhere in `crates/claudevs/src/` today;
  keep it that way and use `unwrap_or_else(|| unreachable!(…))` in production code, as
  `suite.rs:250-253` does.

  The modules this plan touches that **already** carry `#![expect(clippy::unwrap_used, …)]`:
  `hooks_file.rs:85`, `suite.rs:287`, `t_module.rs:540`. `spawn.rs`'s test module at `:126` carries it
  as well. None of the four carries `clippy::panic`.

## File map

```
crates/claudevs/src/harness/hooks_file.rs   — [modify] parse to HookCommand, filter groups by matcher
crates/claudevs/src/harness/spawn.rs        — [modify] dispatch on the handler variant
crates/claudevs/src/harness/mod.rs          — [modify] re-export whatever the new signatures need
crates/claudevs/src/suite.rs                — [modify] the hook call site, for the new resolve signature
crates/claudevs/src/harness/t_module.rs     — [modify] the Lua `t.hook()` path, the second hook caller
crates/claudevs/tests/fixtures/exec-args-plugin/  — [create] a plugin whose only output comes from args
crates/claudevs/tests/fixtures/matcher-routing-plugin/ — [create] two groups, two matchers, two outputs
Makefile.toml                                     — [modify] both fixtures into the claudevs-check lane
```

| File | Tasks |
|---|---|
| `tests/fixtures/exec-args-plugin/` | 1 |
| `harness/hooks_file.rs` | 2, 5, 6, 7 |
| `harness/spawn.rs` | 3 |
| `harness/mod.rs` | 2, 3 |
| `suite.rs` | 2, 3, 5, 6 |
| `tests/fixtures/matcher-routing-plugin/` | 4 |
| `harness/t_module.rs` | 7 |
| `Makefile.toml` | 8 |

---

## Task 1 — The paired control for `args`

A single test asserting "the exec handler works" would go green against the unfixed code, because the
unfixed code runs `sh -c <command>` and `sh` with no arguments is not obviously wrong. The control is
what makes the pair falsifiable: one handler whose output comes from `command`, one whose output comes
**only** from `args`. Under the current code the second produces nothing.

**Files:**
- Create `crates/claudevs/tests/fixtures/exec-args-plugin/.claude-plugin/plugin.json`
- Create `crates/claudevs/tests/fixtures/exec-args-plugin/hooks/hooks.json`
- Create `crates/claudevs/tests/fixtures/exec-args-plugin/tests/cases/a-shell-control.yaml`
- Create `crates/claudevs/tests/fixtures/exec-args-plugin/tests/cases/b-exec-args.yaml`

**Steps:**

1. Read `crates/claudevs/tests/fixtures/minimal-plugin/` in full first and copy its layout exactly —
   manifest field names, the case directory, the case-file extension. Do not invent a layout; the
   discovery code (`crates/claudevs/src/case/discover.rs`) decides what is found, and this fixture has
   to be found by it.

2. Write the manifest:

   ```json
   {
     "name": "exec-args-plugin",
     "version": "0.1.0",
     "description": "Two SessionStart handlers: one shell, one exec whose output lives only in args."
   }
   ```

3. Write `hooks/hooks.json` with both handler shapes on one event:

   ```json
   {
     "hooks": {
       "SessionStart": [
         {
           "hooks": [
             { "type": "command", "command": "echo shell-control-ran" },
             { "type": "command", "command": "sh", "args": ["-c", "echo exec-args-ran"] }
           ]
         }
       ]
     }
   }
   ```

   The exec entry is deliberately `sh -c echo…` rather than a bare program: it makes the defect
   visible as a *substitution* rather than an absence. Under the current code the whole entry becomes
   `sh -c sh`, which spawns a shell that reads nothing from stdin and exits 0 silently — a passing
   case with no output.

4. Write the two cases. `a-shell-control.yaml`:

   ```yaml
   event: SessionStart
   hook: shell-control-ran
   expect:
     stdout_contains: shell-control-ran
   ```

   `b-exec-args.yaml`:

   ```yaml
   event: SessionStart
   hook: exec-args-ran
   expect:
     stdout_contains: exec-args-ran
   ```

   The `hook:` disambiguator on the second case is the string `exec-args-ran`, which appears in the
   handler's **args**, not in its `command`. Under the current code `commands_for` collects only
   `entry.get("command")`, so the second handler is stored as `"sh"` and no `hook:` substring can
   select it — `resolve` returns an error naming the event.

5. Run the suite against the fixture and record what happens. Both cases fail today, for different
   reasons, and the second failure is the one that matters:

   ```
   $ cargo run -q -p claudevs-cli -- test crates/claudevs/tests/fixtures/exec-args-plugin
   ```

   Write down the exact output — it is the red you will confirm gone in Task 3.

6. Commit `test(claudevs): add a fixture whose handler output lives only in args`.

---

## Task 2 — `commands_for` returns handlers, not strings

**Files:**
- Modify `crates/claudevs/src/harness/hooks_file.rs`
- Modify `crates/claudevs/src/harness/mod.rs`
- Modify `crates/claudevs/src/suite.rs`

**Steps:**

1. Read the current function, `crates/claudevs/src/harness/hooks_file.rs:19-49`. Its inner loop is:

   ```rust
   for entry in entries {
       if let Some(command) = entry.get("command").and_then(serde_json::Value::as_str) {
           commands.push(command.to_owned());
       }
   }
   ```

   Two things are wrong with it. It reads `command` with no `type` check, so a `type: "prompt"` entry
   is accepted by accident. And it discards `args` entirely.

2. Add the failing test to the existing `#[cfg(test)] mod tests`:

   ```rust
   #[test]
   fn an_args_entry_is_read_as_an_exec_handler_keeping_every_argument() {
       let dir = plugin(
           r#"{"hooks":{"SessionStart":[{"hooks":[
                {"type":"command","command":"sh","args":["-c","echo hi"]}
              ]}]}}"#,
       );
       let handlers = super::commands_for(dir.path(), HookEvent::SessionStart).unwrap();
       assert_eq!(
           handlers,
           vec![HookCommand::Exec {
               program: String::from("sh"),
               args: vec![String::from("-c"), String::from("echo hi")],
           }],
       );
   }

   #[test]
   fn a_handler_type_claudevs_does_not_model_is_skipped_not_collected() {
       let dir = plugin(
           r#"{"hooks":{"SessionStart":[{"hooks":[
                {"type":"prompt","prompt":"summarise","command":"leaked"},
                {"type":"command","command":"true"}
              ]}]}}"#,
       );
       let handlers = super::commands_for(dir.path(), HookEvent::SessionStart).unwrap();
       assert_eq!(handlers, vec![HookCommand::Shell(String::from("true"))]);
   }
   ```

   `plugin(...)` is a helper the test module may not have. If not, copy the one in
   `crates/claudevs/src/wiring/matchers.rs:79-84`, which writes `hooks/hooks.json` into a tempdir.

3. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib harness::hooks_file
   error[E0308]: mismatched types
      expected `Vec<String>`, found `Vec<HookCommand>`
   ```

4. Implement. Change the signature and the inner loop:

   ```rust
   /// The handlers hooks.json declares for one event, in declaration order.
   ///
   /// Entries claudevs does not model are skipped, not rejected: a plugin that
   /// mixes a prompt handler into a hook group still has its command handlers
   /// run. See [`crate::contract::handler::from_entry`].
   ///
   /// # Errors
   ///
   /// [`Error::Io`] / [`Error::HookResolution`] when the file is missing or malformed.
   pub fn commands_for(plugin_dir: &Path, event: HookEvent) -> Result<Vec<HookCommand>> {
   ```

   ```rust
   for entry in entries {
       if let Some(handler) = crate::contract::handler::from_entry(entry) {
           commands.push(handler);
       }
   }
   ```

   Add `use crate::contract::handler::{HookCommand, from_entry};` to the file's imports.

5. Update `resolve`'s return type to `Result<HookCommand>` and its matched-list logic to filter on
   `c.display().contains(needle)` rather than `c.contains(needle)`. Keep the two error arms as they
   are for now — Task 6 changes the zero-match arm.

6. Update the call site in `crates/claudevs/src/suite.rs`. Find it with:

   ```
   $ grep -rn 'hooks_file::resolve\|resolve(' crates/claudevs/src/suite.rs
   ```

   It currently passes the resolved `String` to `crate::harness::run_shell`. Leave that call broken for
   now if it does not compile — Task 3 replaces it. If you prefer a compiling tree at every step,
   temporarily write `crate::harness::run_shell(&handler.display(), …)`, which preserves today's
   behaviour exactly and is replaced in the next task.

7. Re-export whatever the new signature needs from `crates/claudevs/src/harness/mod.rs` so callers do
   not have to reach into `contract` themselves. Read that file before editing — it is export-only and
   must stay so.

8. Run and confirm green:

   ```
   $ cargo test -p claudevs --lib harness::hooks_file
   test result: ok. N passed; 0 failed
   ```

9. **See it fail.** Change `from_entry` back to `entry.get("command").and_then(Value::as_str).map(|c|
   HookCommand::Shell(c.to_owned()))` and confirm both new tests go red. Restore it.

   The prompt entry in step 2 carries a `command` key on purpose. Without one, the naive extractor
   skips it for want of a command rather than for its type, so
   `a_handler_type_claudevs_does_not_model_is_skipped_not_collected` stays green under the mutation
   and pins nothing. With `"command":"leaked"` present, the naive extractor collects
   `[Shell("leaked"), Shell("true")]` and the test bites.

10. Commit `feat(claudevs): read a hooks.json handler as a typed shell or exec command`.

---

## Task 3 — Spawn dispatches on the handler variant

**Files:**
- Modify `crates/claudevs/src/harness/spawn.rs`
- Modify `crates/claudevs/src/harness/mod.rs`
- Modify `crates/claudevs/src/suite.rs`

**Steps:**

1. Read the current spawn helper, `crates/claudevs/src/harness/spawn.rs:113-122`:

   ```rust
   pub fn run_shell(
       command: &str,
       cwd: &Path,
       env: &BTreeMap<String, String>,
       stdin: Option<&str>,
       timeout: Duration,
   ) -> Result<Captured> {
       let argv = vec![String::from("sh"), String::from("-c"), command.to_owned()];
       run(&argv, cwd, env, stdin, timeout)
   }
   ```

2. Add the failing test to the existing test module:

   ```rust
   #[test]
   fn an_exec_handler_spawns_its_argv_directly_with_no_shell() {
       let dir = cwd();
       let handler = HookCommand::Exec {
           program: String::from("sh"),
           args: vec![String::from("-c"), String::from("echo exec-args-ran")],
       };
       let captured = run_handler(
           &handler,
           dir.path(),
           &BTreeMap::new(),
           None,
           DEFAULT_TIMEOUT,
       )
       .unwrap();
       assert_eq!(captured.stdout.trim(), "exec-args-ran");
   }

   #[test]
   fn an_exec_handler_does_not_tokenize_its_arguments() {
       let dir = cwd();
       let handler = HookCommand::Exec {
           program: String::from("echo"),
           args: vec![String::from("one two")],
       };
       let captured = run_handler(
           &handler,
           dir.path(),
           &BTreeMap::new(),
           None,
           DEFAULT_TIMEOUT,
       )
       .unwrap();
       assert_eq!(captured.stdout.trim(), "one two");
   }

   #[test]
   fn a_shell_handler_still_goes_through_sh_so_a_pipeline_works() {
       let dir = cwd();
       let handler = HookCommand::Shell(String::from("echo a | tr a b"));
       let captured = run_handler(
           &handler,
           dir.path(),
           &BTreeMap::new(),
           None,
           DEFAULT_TIMEOUT,
       )
       .unwrap();
       assert_eq!(captured.stdout.trim(), "b");
   }
   ```

   The third test is the control: it fails if you accidentally route shell handlers through the exec
   path, which would break every plugin that writes a pipeline into `command`.

3. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib harness::spawn
   error[E0425]: cannot find function `run_handler` in this scope
   ```

4. Implement, beside `run_shell`:

   ```rust
   /// Runs one hooks.json handler.
   ///
   /// The two variants are two execution models, not two spellings of one. A
   /// shell handler is wrapped in `sh -c`, so its command string may carry
   /// pipelines, redirection and expansion. An exec handler is spawned directly
   /// with its `args` as the argument vector: there is no shell, and each element
   /// is one argument exactly as written, with no tokenization on any platform.
   ///
   /// # Errors
   ///
   /// Same conditions as [`run`].
   pub fn run_handler(
       handler: &HookCommand,
       cwd: &Path,
       env: &BTreeMap<String, String>,
       stdin: Option<&str>,
       timeout: Duration,
   ) -> Result<Captured> {
       match handler {
           HookCommand::Shell(command) => run_shell(command, cwd, env, stdin, timeout),
           HookCommand::Exec { program, args } => {
               let mut argv = Vec::with_capacity(args.len() + 1);
               argv.push(program.clone());
               argv.extend(args.iter().cloned());
               run(&argv, cwd, env, stdin, timeout)
           }
       }
   }
   ```

   Add `use crate::contract::handler::HookCommand;` to the imports. Keep `run_shell` public — it is
   the arm this function delegates to, and `crates/claudevs/src/harness/mod.rs:24` exports it.

   **But drop it from `crates/claudevs/src/suite.rs:17`'s import list when you do step 6.**
   `suite.rs:153` is its only use in that file — `run_invocation` at `:206-220` spawns through `run`,
   not `run_shell` — so once the hook call site moves to `run_handler` the import is unused, and an
   unused import fails `-D warnings`. Task 7 carries the same check for `t_module.rs`.

5. Re-export `run_handler` from `crates/claudevs/src/harness/mod.rs` alongside `run` and `run_shell`.

6. Replace the hook call site in `crates/claudevs/src/suite.rs` with `run_handler(&handler, …)`, undoing
   the temporary `handler.display()` bridge from Task 2 step 6 if you added one.

7. Run and confirm green, then run the fixture from Task 1:

   ```
   $ cargo test -p claudevs --lib harness::spawn
   test result: ok. N passed; 0 failed

   $ cargo run -q -p claudevs-cli -- test crates/claudevs/tests/fixtures/exec-args-plugin
     ok    a-shell-control
     ok    b-exec-args
   ```

   Both green is the paired control satisfied: the case that was already honest still passes, and the
   case that was vacuous now runs the handler it names.

8. **See it fail.** Change the `Exec` arm to `run_shell(program, cwd, env, stdin, timeout)` — which is
   exactly what the unfixed code did — and confirm `b-exec-args` goes red and
   `an_exec_handler_spawns_its_argv_directly_with_no_shell` fails with empty stdout. Restore it.

9. Commit `fix(claudevs): spawn an args-carrying hook handler directly instead of through sh -c`.

---

## Task 4 — The paired control for matcher routing

**Files:**
- Create `crates/claudevs/tests/fixtures/matcher-routing-plugin/.claude-plugin/plugin.json`
- Create `crates/claudevs/tests/fixtures/matcher-routing-plugin/hooks/hooks.json`
- Create `crates/claudevs/tests/fixtures/matcher-routing-plugin/tests/cases/a-routes-here.yaml`
- Create `crates/claudevs/tests/fixtures/matcher-routing-plugin/tests/cases/b-routes-elsewhere.yaml`

**Steps:**

1. Write the manifest, following `minimal-plugin`'s field set:

   ```json
   {
     "name": "matcher-routing-plugin",
     "version": "0.1.0",
     "description": "Two PreToolUse groups behind different matchers, each with its own output."
   }
   ```

2. Write `hooks/hooks.json` with two groups the runtime routes between:

   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Edit",
           "hooks": [{ "type": "command", "command": "echo edit-group-ran" }]
         },
         {
           "matcher": "Bash",
           "hooks": [{ "type": "command", "command": "echo bash-group-ran" }]
         }
       ]
     }
   }
   ```

3. Both cases carry a `hook:` disambiguator, and that is not decoration. `resolve` flattens both
   groups into two commands today, and `crates/claudevs/src/harness/hooks_file.rs:72-79` returns
   `Error::HookResolution` — *"2 PreToolUse hooks match … add a `hook:` substring that matches exactly
   one"* — for any event with more than one match and no reference. Without the disambiguator the
   fixture would demonstrate that error rather than the false pass it exists to demonstrate.

   Write the control case, `a-routes-here.yaml` — a payload the `Edit` matcher selects:

   ```yaml
   event: PreToolUse
   hook: edit-group-ran
   payload:
     tool_name: Edit
   expect:
     stdout_contains: edit-group-ran
   ```

4. Write the formerly-vacuous case, `b-routes-elsewhere.yaml` — a payload the `Edit` matcher does
   **not** select, asserting the `Edit` group's output anyway:

   ```yaml
   event: PreToolUse
   hook: edit-group-ran
   payload:
     tool_name: Bash
   expect:
     stdout_contains: edit-group-ran
   ```

   This case is wrong and must fail. Today it passes: `resolve` never reads `matcher`, so the `hook:`
   substring alone selects the `Edit` group's command whatever the payload says, and the assertion
   holds against a hook the runtime would never have run.

5. Run the fixture and write down the exact current output:

   ```
   $ cargo run -q -p claudevs-cli -- test crates/claudevs/tests/fixtures/matcher-routing-plugin
   ```

6. Commit `test(claudevs): add a fixture whose two hook groups route by matcher`.

---

## Task 5 — `resolve` filters groups by matcher

**Files:**
- Modify `crates/claudevs/src/harness/hooks_file.rs`
- Modify `crates/claudevs/src/suite.rs`

**Steps:**

1. Add the failing unit test:

   ```rust
   #[test]
   fn a_group_whose_matcher_does_not_match_the_payload_is_not_a_candidate() {
       let dir = plugin(
           r#"{"hooks":{"PreToolUse":[
                {"matcher":"Edit","hooks":[{"type":"command","command":"echo edit"}]},
                {"matcher":"Bash","hooks":[{"type":"command","command":"echo bash"}]}
              ]}}"#,
       );
       let payload = serde_json::json!({"tool_name": "Bash"});
       let handler = super::resolve(dir.path(), HookEvent::PreToolUse, None, &payload).unwrap();
       assert_eq!(handler, HookCommand::Shell(String::from("echo bash")));
   }

   #[test]
   fn an_unanchored_regex_matcher_reaches_a_longer_tool_name() {
       let dir = plugin(
           r#"{"hooks":{"PreToolUse":[
                {"matcher":"Edit.*","hooks":[{"type":"command","command":"echo edit"}]}
              ]}}"#,
       );
       let payload = serde_json::json!({"tool_name": "NotebookEdit"});
       assert!(super::resolve(dir.path(), HookEvent::PreToolUse, None, &payload).is_ok());
   }

   #[test]
   fn a_matcher_on_an_event_that_takes_none_is_ignored_the_way_the_runtime_ignores_it() {
       let dir = plugin(
           r#"{"hooks":{"UserPromptSubmit":[
                {"matcher":"NeverMatchesAnything","hooks":[{"type":"command","command":"echo ran"}]}
              ]}}"#,
       );
       let payload = serde_json::json!({"prompt": "hello"});
       let handler =
           super::resolve(dir.path(), HookEvent::UserPromptSubmit, None, &payload).unwrap();
       assert_eq!(handler, HookCommand::Shell(String::from("echo ran")));
   }
   ```

   The third test is not a hypothetical. `UserPromptSubmit` is both one of the ten matcher-less events
   and one of the five claudevs can simulate, so this is a path real cases take — and plan 05 adds a
   warning precisely because plugins do write matchers there. Filtering on a matcher the runtime
   discards would invent a mismatch that cannot happen in production.

2. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib harness::hooks_file
   error[E0061]: this function takes 3 arguments but 4 arguments were supplied
   ```

3. Implement. `resolve` gains a payload parameter and filters groups before flattening:

   ```rust
   /// Resolves the one handler a hook case targets, for `payload`.
   ///
   /// Groups are filtered by their `matcher` against the payload first, the way
   /// the runtime routes, and the optional `reference` substring is a secondary
   /// filter over the handlers that survive — for a plugin wiring several
   /// commands behind one matcher.
   ///
   /// The filter mirrors the runtime, including where the runtime ignores the
   /// matcher. For an event that takes no matcher, one written in hooks.json is
   /// silently ignored, so every group matches; and where the catalogue does not
   /// name what a matcher is compared against, the matcher is ignored on the same
   /// principle — claudevs never guesses a routing rule the documentation does
   /// not state.
   ///
   /// # Errors
   ///
   /// [`Error::HookResolution`] when several handlers match.
   pub fn resolve(
       plugin_dir: &Path,
       event: HookEvent,
       reference: Option<&str>,
       payload: &serde_json::Value,
   ) -> Result<HookCommand> {
   ```

   `commands_for` no longer suffices, because filtering happens at the group level and `commands_for`
   flattens groups. Add a private `groups_for(plugin_dir, event) -> Result<Vec<(Option<String>,
   Vec<HookCommand>)>>` that returns each group's matcher and handlers, and have `commands_for` be
   `groups_for(...).map(|g| g.into_iter().flat_map(|(_, h)| h).collect())` so the two cannot disagree.

   The group filter:

   ```rust
   /// Whether `group_matcher` selects `payload` under `event`'s rules.
   fn group_selects(
       event: HookEvent,
       group_matcher: Option<&str>,
       payload: &serde_json::Value,
   ) -> bool {
       use crate::contract::event::MatcherSupport;

       let Some(matcher) = group_matcher else {
           return true;
       };
       let Some(documented) = crate::contract::event::lookup(event.as_str()) else {
           return true;
       };
       let MatcherSupport::Field(path) = documented.matcher else {
           // Either the event takes no matcher — the runtime ignores one
           // written here — or the reference does not say what the matcher is
           // compared against. Both mean: do not filter.
           return true;
       };
       let Some(subject) = payload.get(path).and_then(serde_json::Value::as_str) else {
           return true;
       };
       crate::contract::matcher::parse(event.as_str(), matcher).matches(subject)
   }
   ```

   `parse` takes the event name as well as the value: `FileChanged` and `StopFailure` use a narrower
   exact-match set than every other event (`hooks.md:301`), so the same matcher string parses
   differently depending on which event it sits under. An earlier draft of this plan called
   `parse(matcher)`; that signature no longer exists. Use whatever spelling of the event name is in
   scope at this point — `event.as_str()` if `event` is a `HookEvent`, the `&str` itself if the caller
   already has one.

   Note the last `let Some(subject) … else { return true }`: a payload that carries no value at the
   matcher's field is not evidence the group should be excluded. A case whose payload omits `tool_name`
   is under-specified, not mis-routed, and plan 04's default payload gives every simulatable event that
   field anyway.

4. Update the call site in `crates/claudevs/src/suite.rs` to pass the payload it already builds. Read
   the hook branch of `run_case` before editing — the payload is constructed there from
   `harness::payload::default_payload` plus the case's overlay, and `resolve` must be called **after**
   that construction, with the merged value.

5. Run the unit tests and confirm green:

   ```
   $ cargo test -p claudevs --lib harness::hooks_file
   test result: ok. N passed; 0 failed
   ```

   The fixture does **not** yet show `FAIL b-routes-elsewhere`, and it is worth knowing why before you
   run it. With `tool_name: Bash` only the `Bash` group survives the filter; the case's
   `hook: edit-group-ran` reference then matches none of its handlers; and the zero-match arm still
   returns `Err(Error::HookResolution)`, which `run_case` propagates and
   `crates/claudevs-cli/src/cli.rs:95-107` turns into exit 2 for the whole run. So what you see is:

   ```
   $ cargo run -q -p claudevs-cli -- test crates/claudevs/tests/fixtures/matcher-routing-plugin
   claudevs: no PreToolUse handler matches "edit-group-ran" for this payload; the plugin wires: …
   $ echo $?
   2
   ```

   No per-case lines at all. That is the routing filter working — the case genuinely reaches no
   handler — reported through the path Task 6 exists to fix. Do not read it as the fix having failed,
   and do not weaken the filter to make the output prettier.

6. **See it fail the other way.** Change `group_selects` to `true` unconditionally and confirm
   `b-routes-elsewhere` goes back to passing — that is the false green, reproduced on demand. Restore
   the function.

7. Commit `fix(claudevs): route a hook case through the matcher the runtime would use`.

---

## Task 6 — Both no-match paths converge on one failed case

**Files:**
- Modify `crates/claudevs/src/harness/hooks_file.rs`
- Modify `crates/claudevs/src/suite.rs`

**Steps:**

1. Read the current zero-match arm, `crates/claudevs/src/harness/hooks_file.rs:64-71`. It returns
   `Err(Error::HookResolution { … })`, which `crates/claudevs-cli/src/cli.rs:95-107` turns into exit 2
   for the whole run. There is an existing test named `zero_matches_is_an_error_naming_the_event` that
   pins this; it is about to change.

2. Add the failing test:

   ```rust
   #[test]
   fn a_case_whose_event_wires_nothing_is_one_failed_case_not_the_end_of_the_run() {
       let dir = plugin(r#"{"hooks":{"SessionEnd":[{"hooks":[]}]}}"#);
       let payload = serde_json::json!({});
       let outcome = super::resolve(dir.path(), HookEvent::SessionEnd, None, &payload);
       let Err(error) = outcome else {
           panic!("nothing is wired for SessionEnd");
       };
       let message = error.to_string();
       assert!(message.contains("SessionEnd"), "{message}");
       assert!(
           message.contains("declared") || message.contains("wires"),
           "the failure must list what the plugin does wire: {message}"
       );
   }
   ```

   `hooks_file.rs:85`'s test module declares only `#![expect(clippy::unwrap_used, …)]`. This test's
   `panic!` inside a `let-else` needs the second attribute added there, or `panic = "deny"` fails the
   build:

   ```rust
   #![expect(clippy::panic, reason = "tests panic to reject an unexpected shape")]
   ```

3. The behaviour change is at the **call site**, not in `resolve`: `resolve` still returns an `Err`,
   and `suite::run_case` turns a `HookResolution` error into a failed `CaseOutcome` rather than
   propagating it. Add the suite-level test to `crates/claudevs/src/suite.rs`'s test module:

   ```rust
   #[test]
   fn a_case_that_resolves_to_nothing_does_not_take_the_suite_down() {
       let dir = tempfile::tempdir().unwrap();
       let plugin = dir.path();
       std::fs::create_dir_all(plugin.join(".claude-plugin")).unwrap();
       std::fs::write(
           plugin.join(".claude-plugin/plugin.json"),
           r#"{"name":"p","version":"0.1.0"}"#,
       )
       .unwrap();
       std::fs::create_dir_all(plugin.join("hooks")).unwrap();
       // SessionStart is wired; SessionEnd is not.
       std::fs::write(
           plugin.join("hooks/hooks.json"),
           r#"{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"true"}]}]}}"#,
       )
       .unwrap();
       std::fs::create_dir_all(plugin.join("tests/cases")).unwrap();
       std::fs::write(
           plugin.join("tests/cases/a-resolves.yaml"),
           "event: SessionStart\nexpect:\n  exit: 0\n",
       )
       .unwrap();
       std::fs::write(
           plugin.join("tests/cases/b-wires-nothing.yaml"),
           "event: SessionEnd\nexpect:\n  exit: 0\n",
       )
       .unwrap();

       let report = super::run_suite(plugin, &super::SuiteOptions::default()).unwrap();
       let names: Vec<&str> = report.outcomes.iter().map(|o| o.name.as_str()).collect();
       assert_eq!(names.len(), 2, "{names:?}");
       assert!(names.contains(&"a-resolves"));
       let Some(unresolved) = report.outcomes.iter().find(|o| o.name == "b-wires-nothing") else {
           panic!("the unresolvable case is still an outcome: {names:?}");
       };
       assert!(
           matches!(unresolved.verdict, crate::harness::Verdict::Fail(_)),
           "an unwired event is one failed case, not the death of the run: {:?}",
           unresolved.verdict
       );
   }
   ```

   Read `crates/claudevs/src/case/discover.rs` before running this: it decides which directory and
   which extensions are searched, and `tests/cases/*.yaml` above is an assumption about it. If
   discovery looks elsewhere, move the two case files rather than changing the test's assertions.

4. Run and confirm failure — `run_suite` returns `Err` today, so the `unwrap` panics:

   ```
   $ cargo test -p claudevs --lib suite::tests::a_case_that_resolves_to_nothing
   called `Result::unwrap()` on an `Err` value: HookResolution { reason: "no SessionEnd hook matches ..." }
   ```

5. Implement, in two places.

   **In `resolve`.** `groups` is the binding Task 5 introduced — `groups_for` returns
   `Vec<(Option<String>, Vec<HookCommand>)>` — and it has to stay alive past the filter so the
   zero-match arm can report what the plugin does wire:

   ```rust
   pub fn resolve(
       plugin_dir: &Path,
       event: HookEvent,
       reference: Option<&str>,
       payload: &serde_json::Value,
   ) -> Result<HookCommand> {
       let groups = groups_for(plugin_dir, event)?;
       let candidates: Vec<&HookCommand> = groups
           .iter()
           .filter(|(matcher, _)| group_selects(event, matcher.as_deref(), payload))
           .flat_map(|(_, handlers)| handlers)
           .filter(|handler| {
               reference.is_none_or(|needle| handler.display().contains(needle))
           })
           .collect();

       match candidates.as_slice() {
           [one] => Ok((*one).clone()),
           [] => Err(Error::HookResolution {
               reason: format!(
                   "no {} handler matches {:?} for this payload; the plugin wires: {}",
                   event.as_str(),
                   reference.unwrap_or("<any>"),
                   describe_groups(&groups),
               ),
           }),
           several => Err(Error::HookResolution {
               reason: format!(
                   "{} {} handlers match {:?}; add a `hook:` substring that matches exactly one",
                   several.len(),
                   event.as_str(),
                   reference.unwrap_or("<any>"),
               ),
           }),
       }
   }

   /// Every group an event declares, as `matcher -> handler` pairs.
   ///
   /// Shown when nothing matches, so an author sees what the plugin wires rather
   /// than only that their case reached none of it.
   fn describe_groups(groups: &[(Option<String>, Vec<HookCommand>)]) -> String {
       if groups.is_empty() {
           return String::from("nothing");
       }
       groups
           .iter()
           .flat_map(|(matcher, handlers)| {
               let matcher = matcher.as_deref().unwrap_or("*");
               handlers
                   .iter()
                   .map(move |handler| format!("matcher={matcher} -> {}", handler.display()))
           })
           .collect::<Vec<_>>()
           .join(", ")
   }
   ```

   If clippy on the toolchain in `rust-toolchain.toml` lints `is_none_or`, use whichever of it and
   `map_or(true, …)` is not linted.

   **In `suite::run_case`.** This needs a small restructure rather than a changed line. The hook
   branch is one arm of a `match &case.kind` whose value is a `Verdict`
   (`crates/claudevs/src/suite.rs:139-174`), and a `Verdict` has nowhere to put a case name — so the
   resolution has to happen before that match, where an early `return` can produce a whole
   `CaseOutcome`:

   ```rust
   pub fn run_case(plugin_dir: &Path, fixtures_root: &Path, case: &Case) -> Result<CaseOutcome> {
       let project = match &case.project {
           Some(fixture) => Project::from_fixture(fixtures_root, &fixture.0)?,
           None => Project::empty()?,
       };
       let project_str = project.path().display().to_string();
       let env = base_env(plugin_dir, project.path());

       // Resolved ahead of the kind match so an unresolvable hook becomes one
       // failed case rather than the end of the run.
       let resolved = match &case.kind {
           CaseKind::Hook {
               event,
               hook,
               payload,
               payload_raw,
           } => {
               let stdin =
                   stdin_for(*event, payload.as_ref(), payload_raw.as_deref(), &project_str);
               // A `payload_raw` case deliberately sends text that is not JSON.
               // `group_selects` treats a payload with no value at the matcher's
               // field as unfiltered, so such a case routes as it does today.
               let value: serde_json::Value =
                   serde_json::from_str(&stdin).unwrap_or(serde_json::Value::Null);
               match resolve(plugin_dir, *event, hook.as_deref(), &value) {
                   Ok(handler) => Some((handler, stdin)),
                   Err(Error::HookResolution { reason }) => {
                       return Ok(CaseOutcome {
                           name: case.name.to_string(),
                           verdict: Verdict::Fail(vec![reason]),
                       });
                   }
                   Err(other) => return Err(other),
               }
           }
           _ => None,
       };

       let verdict = match &case.kind {
           CaseKind::Hook { event, .. } => {
               // `resolved` is `Some` for exactly this arm, set above. `expect`
               // is not available: `clippy::expect_used` is `warn` workspace-wide
               // (root `Cargo.toml`, `[workspace.lints.clippy]`) and the gate
               // runs `-D warnings`. `unreachable!` is the idiom already used at
               // `crates/claudevs/src/suite.rs:250-253`.
               let (handler, stdin) = resolved
                   .unwrap_or_else(|| unreachable!("a hook case resolves above the kind match"));
               let captured = run_handler(
                   &handler,
                   project.path(),
                   &env,
                   Some(&stdin),
                   DEFAULT_TIMEOUT,
               )?;
               judge(&case.expect, &observe(*event, &captured), project.path())
           }
           // … the Script and Flow arms, unchanged …
       };

       Ok(CaseOutcome {
           name: case.name.to_string(),
           verdict,
       })
   }
   ```

   `Verdict::Fail(vec![reason])` is the `Vec<String>` shape that exists at this point in the sequence.
   Plan 04 Task 7 replaces it with `Vec<Mismatch>` and migrates this site to
   `Mismatch::DidNotRun { reason }`; write it against the shape in front of you.

   Every error that is not `HookResolution` still propagates.

6. Update the existing `zero_matches_is_an_error_naming_the_event` test. It still holds at the
   `resolve` level — `resolve` does still return an error — so it should need only the new payload
   argument. Read it before assuming; if it asserts on the exact message, update the expectation to the
   new text.

7. Run and confirm green, then the fixture — this is where the paired control finally reads as one:

   ```
   $ cargo test -p claudevs --all-targets
   test result: ok. N passed; 0 failed

   $ cargo run -q -p claudevs-cli -- test crates/claudevs/tests/fixtures/matcher-routing-plugin
     ok    a-routes-here
     FAIL  b-routes-elsewhere
           no PreToolUse handler matches "edit-group-ran" for this payload; the plugin wires:
           matcher=Edit -> echo edit-group-ran, matcher=Bash -> echo bash-group-ran
   ```

   One green, one red, and the red names the alternatives. `b-routes-elsewhere` asserts the `Edit`
   group's output for a `Bash` payload, which is wrong, and now fails as one case rather than ending
   the run.

8. **See it fail the other way.** Make `group_selects` return `true` unconditionally and confirm
   `b-routes-elsewhere` goes back to passing. That is the false green this fixture exists to
   demonstrate, reproduced on demand. Restore the function.

9. Commit `fix(claudevs): report an unresolvable hook case as one failure, not as exit 2`.

---

## Task 7 — The Lua `t.hook()` path

`crates/claudevs/src/harness/t_module.rs` is a **second hook execution path**, and it is the one this
plan would otherwise break and leave broken. Read it before doing anything else in this task.

**Files:**
- Modify `crates/claudevs/src/harness/t_module.rs`

**Steps:**

1. Read `crates/claudevs/src/harness/t_module.rs:160-200` and `:351-380`. Three things matter:

   - `:181` calls `run_shell(&command, …)`, so the `args` defect Task 3 closed for YAML cases is
     **still open here**. A Lua `t.hook()` against an exec handler still runs `sh -c sh`.
   - `:357` and `:368` call `crate::harness::resolve_hook(plugin_dir, event, …)` with the three-argument
     signature. Task 5 added a fourth parameter and changed the return type to `HookCommand`, so
     without this task the crate does not compile.
   - `resolve_ref` at `:352` resolves **before** the payload exists: `:168` calls it, and the payload
     is built at `:172-178`. Task 5's routing needs the payload, so this is an ordering problem, not
     only a signature one.

2. **Migrate the four existing `resolve_ref` tests first.** `t_module.rs:539` already has a test
   module, and four of its tests call `resolve_ref` with two arguments and destructure a two-tuple:

   | Test | Line | What breaks |
   |---|---|---|
   | `resolve_ref_matches_an_event_name_directly` | `:564` | 2 args; `assert_eq!(command, "sh gate.sh")` |
   | `resolve_ref_matches_a_command_substring_unique_across_events` | `:572` | 2 args; `assert_eq!(command, "sh audit.sh")` |
   | `resolve_ref_reports_a_zero_match_naming_the_reference` | `:580` | 2 args |
   | `resolve_ref_reports_a_reference_matching_across_events` | `:589` | 2 args |

   Each gains the two new arguments and a three-tuple, and the two that compare against a string
   compare against a `HookCommand` instead:

   ```rust
   #[test]
   fn resolve_ref_matches_an_event_name_directly() {
       let dir = plugin(TWO_EVENTS);
       let (event, handler, _payload) =
           resolve_ref(dir.path(), "PreToolUse", None, "/tmp/p").unwrap();
       assert_eq!(event, HookEvent::PreToolUse);
       assert_eq!(handler, HookCommand::Shell(String::from("sh gate.sh")));
   }
   ```

   The other three follow the same shape. `TWO_EVENTS` at `:559` declares no `matcher`, so every group
   is unfiltered and all four keep their existing outcomes — the migration is mechanical, and if any
   of the four changes verdict, stop and work out why before adjusting it.

3. Add the two new tests. `t.hook()` is a Lua-facing function, so drive it the way this module's Lua
   tests do — read the rest of the test module at `:539` onwards for the `airsl` harness it builds:

   ```rust
   #[test]
   fn a_lua_hook_call_runs_an_exec_handler_with_its_arguments() {
       // A plugin whose only SessionStart handler carries its output in `args`.
       // Under `run_shell` this spawns `sh -c sh` and prints nothing.
       let dir = plugin(
           r#"{"hooks":{"SessionStart":[{"hooks":[
                {"type":"command","command":"sh","args":["-c","echo exec-args-ran"]}
              ]}]}}"#,
       );
       let (event, handler, _payload) =
           resolve_ref(dir.path(), "SessionStart", None, "/tmp/p").unwrap();
       assert_eq!(event, HookEvent::SessionStart);
       assert_eq!(
           handler,
           HookCommand::Exec {
               program: String::from("sh"),
               args: vec![String::from("-c"), String::from("echo exec-args-ran")],
           },
       );
   }

   #[test]
   fn a_lua_hook_call_routes_by_matcher_the_way_a_yaml_case_does() {
       let dir = plugin(
           r#"{"hooks":{"PreToolUse":[
                {"matcher":"Edit","hooks":[{"type":"command","command":"echo edit"}]},
                {"matcher":"Bash","hooks":[{"type":"command","command":"echo bash"}]}
              ]}}"#,
       );
       let overlay = serde_json::json!({ "tool_name": "Bash" });
       let (_event, handler, payload) =
           resolve_ref(dir.path(), "PreToolUse", Some(&overlay), "/tmp/p").unwrap();
       assert_eq!(handler, HookCommand::Shell(String::from("echo bash")));
       assert_eq!(payload["tool_name"], "Bash");
   }
   ```

   Both test `resolve_ref` directly rather than through Lua. That is deliberate: routing is what this
   task changes, the Lua layer above it is unchanged, and a test that goes through `airsl` to assert a
   routing decision is testing two things at once. If you want end-to-end coverage of `t.hook()` as
   well, add it — but not instead of these.

   `HookCommand` needs importing into the test module's `use super::{…}` line.

4. Run and confirm failure. Before any edit the crate does not compile at all (Task 5 changed
   `resolve_hook`), so the first failure you see is:

   ```
   $ cargo test -p claudevs --lib harness::t_module
   error[E0061]: this function takes 4 arguments but 3 arguments were supplied
      --> crates/claudevs/src/harness/t_module.rs:357:23
   ```

5. Implement. Reorder so the payload is built before resolution, and pass it through:

   ```rust
   /// `ref` is an event name, or a substring unique across all events' handlers.
   ///
   /// The payload is built before resolution rather than after, because routing
   /// reads it: a group's matcher is compared against a payload field, so a
   /// handler cannot be chosen without one. For the substring form each
   /// candidate event is tried with that event's own payload, since the default
   /// payload differs per event.
   fn resolve_ref(
       plugin_dir: &std::path::Path,
       reference: &str,
       overlay: Option<&serde_json::Value>,
       project: &str,
   ) -> crate::error::Result<(HookEvent, HookCommand, serde_json::Value)> {
       let payload_for = |event: HookEvent| {
           let mut value = default_payload(event);
           if let Some(overlay) = overlay {
               merge(&mut value, overlay);
           }
           substitute_project(&mut value, project);
           value
       };

       if let Ok(event) = reference.parse::<HookEvent>() {
           let payload = payload_for(event);
           let handler = crate::harness::resolve_hook(plugin_dir, event, None, &payload)?;
           return Ok((event, handler, payload));
       }

       let mut matches = Vec::new();
       for event in [
           HookEvent::PreToolUse,
           HookEvent::PostToolUse,
           HookEvent::UserPromptSubmit,
           HookEvent::SessionStart,
           HookEvent::SessionEnd,
       ] {
           let payload = payload_for(event);
           if let Ok(handler) =
               crate::harness::resolve_hook(plugin_dir, event, Some(reference), &payload)
           {
               matches.push((event, handler, payload));
           }
       }
       match matches.len() {
           1 => Ok(matches.remove(0)),
           0 => Err(Error::HookResolution {
               reason: format!("`{reference}` matches no hook handler"),
           }),
           n => Err(Error::HookResolution {
               reason: format!("`{reference}` matches {n} hook handlers across events"),
           }),
       }
   }
   ```

   Then at `:166-190`, build the project and overlay first, hand them to `resolve_ref`, and spawn the
   returned handler with `run_handler` instead of `run_shell`:

   ```rust
   move |lua, (reference, payload): (String, Option<mlua::Table>)| {
       let project = Project::empty().map_err(lua_err)?;
       let project_str = project.path().display().to_string();

       let overlay = match payload {
           Some(table) => Some(
               serde_json::to_value(mlua::Value::Table(table))
                   .map_err(mlua::Error::external)?,
           ),
           None => None,
       };

       let (event, handler, value) =
           resolve_ref(&plugin_dir, &reference, overlay.as_ref(), &project_str)
               .map_err(lua_err)?;

       let env = base_env(&plugin_dir, project.path());
       let captured = run_handler(
           &handler,
           project.path(),
           &env,
           Some(&value.to_string()),
           DEFAULT_TIMEOUT,
       )
       .map_err(lua_err)?;
       let observed = observe(event, &captured);
       // … the result table, unchanged …
   }
   ```

   `Project::empty()` moves above the overlay conversion because `project_str` is now needed for
   `substitute_project` inside `resolve_ref`. Update the `use` at `:53` — `run_shell` may become
   unused, and an unused import fails the gate.

   `overlay` is converted once and borrowed per candidate event, rather than converted inside the
   loop: an `mlua::Table` is consumed by `to_value`, so converting it five times is not possible
   anyway.

6. Run and confirm green — all six tests in this module, and the whole crate:

   ```
   $ cargo test -p claudevs --all-targets
   test result: ok. N passed; 0 failed
   ```

7. **See it fail.** Put `run_shell(&handler.display(), …)` back in place of `run_handler` and confirm
   the mutation is caught. Restore it. That is the `args` defect, reproduced on the path that would
   have kept it.

   **`a_lua_hook_call_runs_an_exec_handler_with_its_arguments` does not catch it.** That test
   exercises `resolve_ref` only, so reverting the `install_hook` call site to `run_shell` leaves it
   green — the step above over-predicted, and a test that stays green under the exact mutation it
   names pins nothing. Catching this needs a test that drives the real `t.hook()` Lua path through a
   confined `airsl` engine, end to end, rather than the resolution helper on its own.

8. Run the Lua suite, which is what actually exercises this module end to end:

   ```
   $ cargo make plugins
   ```

   It needs the `airsl` binary (`cargo make install-airsl`). If a plugin's Lua case starts failing
   because its `t.hook()` call now routes by matcher, that case was relying on the unfiltered
   behaviour — read it before changing it, and say in the commit body which case and why.

9. Commit `fix(claudevs): route and spawn the Lua t.hook() path the way a YAML case does`.

---

## Task 8 — Correct the module's own claims and run the gate

**Files:**
- Modify `crates/claudevs/src/harness/hooks_file.rs`

**Steps:**

1. Rewrite the module doc comment at `crates/claudevs/src/harness/hooks_file.rs:1-7`. The current text
   says the file shape was "verified against this repository's plugins" and describes resolution as
   flattening plus substring matching. Both statements are now false, and the first is the exact habit
   this chain exists to break. Replace with a description of the documented shape and of routing by
   matcher, citing `crate::contract` for where the contract lives.

2. Run the full gate:

   ```
   $ cargo make dod
   ```

3. Run both corpus lanes:

   ```
   $ cargo make claudevs-check
   ```

   The two new fixtures are not in that lane yet. Add `exec-args-plugin` to its must-pass list and
   `matcher-routing-plugin` to its must-fail list, naming the stage each is expected to fail at — read
   the lane's existing structure at `Makefile.toml:165` onwards and follow it. `matcher-routing-plugin`
   is a must-fail fixture on purpose: one of its two cases asserts something untrue, and a corpus of
   only-passing fixtures goes green the day the checkers stop reporting.

4. Commit `docs(claudevs): describe hook resolution as routing rather than flattening`.

---

## Done when

- `cargo make dod` is green with zero warnings.
- `cargo make claudevs-check` is green and covers both new fixtures in the right directions.
- Both paired controls hold: `exec-args-plugin` has two passing cases, `matcher-routing-plugin` has one
  passing and one failing.
- Tasks 3, 5, 6 and 7 were each watched go red before they went green, and Tasks 3, 6 and 7 were each
  watched go *back* to the false behaviour when the fix was reverted.
- **Both hook execution paths were changed.** `suite::run_case` and the Lua `t.hook()` bridge in
  `harness/t_module.rs` both parse handlers into `HookCommand`, both spawn through `run_handler`, and
  both route by matcher against a payload built before resolution. A fix that reaches only the YAML
  path leaves the `args` defect open for every Lua case.
- `cargo make plugins` is green.
- `hooks_file.rs` states no plugin knowledge of its own; every contract fact it uses comes from
  `crate::contract`.

---

## Review findings

One reviewer pass over the completed diff. Verdict: spec compliant with amendments; the gate green,
re-run by the reviewer rather than taken on the coders' word. Totals: code 2🔴 7🟡 6🔵, spec 1🔴 2🟡 2🔵.

| # | Sev | Finding | Disposition |
|---|---|---|---|
| 1 | 🔴 | `describe_groups` guards on `groups.is_empty()`, so an event whose groups declare no modeled handler renders `wires: ` and ends mid-sentence | fixed — guards on the rendered list; reads `wires: nothing declared` |
| 2 | 🔴 | the test pinning that message is satisfied by the format string's own literal `wires:`, and its fixture is exactly the shape that renders nothing | fixed — asserts the interpolated tail, renamed to what it tests, watched red against the reverted fix |
| 3 | 🟡 | a matcher Rust's `regex` cannot compile (lookahead, backreference) silently excludes its group, and the failure blames the payload | deferred to plan 05, which owns matcher semantics and the checker's engine-naming warning (spec §4.3); latent — no plugin in the 156-root corpus triggers it |
| 4 | 🟡 | `Error::HookResolution` is overloaded, so a malformed `hooks.json` degraded into N identical per-case failures while a *missing* one still aborted the run | fixed inside `suite.rs`; `error.rs` untouched |
| 5 | 🟡 | `resolve`'s `# Errors` section describes errors it no longer returns | fixed |
| 6 | 🟡 | workflow vocabulary in shipped source (`doc-comment-discipline`) | fixed; a full-file grep found no other instance |
| 7 | 🟡 | a stale self-referencing line range and gate narration in a source comment | fixed |
| 8 | 🟡 | `an_exec_handler_does_not_tokenize_its_arguments` did not pin non-tokenization | fixed — `args: ["a; echo b"]`, watched fail as `left: "a\nb"` under shell routing |
| 9 | 🟡 | the test-local `engine_for` stated a reason that was not the reason, and forks the engine wiring | doc fixed; the fork stands — reducing it needs `case/lua.rs`, outside this plan |
| 10 | 🔵 | `commands_for` has no production caller left | open — resolving it is an export decision in `harness/mod.rs` |
| 11 | 🔵 | `path` names a path but holds a key | fixed |
| 12 | 🔵 | the payload is serialized and immediately re-parsed | fixed |
| 13 | 🔵 | `an_unanchored_regex_matcher_reaches_a_longer_tool_name` asserts only `is_ok()` | fixed |
| 14 | 🔵 | an entry with no `type` key is now skipped where the pre-diff loop collected it | declined — `type` is required by the documented handler shape, so skipping it is the contract, not a regression |
| 15 | 🔵 | a `payload_raw` case bypasses matcher routing entirely | open — a behavioural question about what `payload_raw` means, not a tidy-up; changing routing semantics needs its own decision |

Spec §3.3's 🔴 is closed by finding 1. Spec §2.2's 🟡 travels with finding 3 to plan 05.

## Deviations

- **Three of this plan's prescribed tests pinned nothing, and each was found only by running the
  mutation it named.** Task 2 step 9 predicted both new tests go red under the naive extractor; only
  one did, because the prompt-entry fixture carried no `command` key and was skipped for the wrong
  reason. Task 7 step 7 named a test that stays green when the real `install_hook` call site is
  reverted, because it exercises `resolve_ref` alone. Task 6's regression test was satisfied by a
  literal in the format string. All three are corrected in the plan text above, and the reviewer
  found a fourth of the same class in `spawn.rs`. The lesson is the plan's own: a prescribed mutation
  check is a claim, and writing one into a plan does not make the test bite.
- **A latent false green was found in the crate's own test suite.** `suite.rs`'s fixture declared
  `matcher: "Write"` while its cases sent `tool_name: "Edit"` — the very defect class this chain
  exists to remove, sitting in the tests. Fixed to `"Edit|Write"`.
- **Task 6 step 5 specified `"nothing"`; the implementation returns `"nothing declared"`.** Harmless,
  but the test's `contains("declared") || contains("wires")` disjunction was written to tolerate
  either, which is part of why it pinned nothing.
- **The plan's `#![expect(clippy::panic, …)]` prediction for `suite.rs` was wrong** — the module still
  declares `unwrap_used` only and the gate is green; `panic!` already sat in that module beforehand.
- **Finding 9's engine fork and findings 10 and 15 are left open**, each recorded above with why.
