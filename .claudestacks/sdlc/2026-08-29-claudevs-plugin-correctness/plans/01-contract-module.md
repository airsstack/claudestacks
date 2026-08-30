---
status: done
created: 2026-08-29
---

# Contract Module Implementation Plan

**Goal:** State the Claude Code hook contract once, in a `contract` module every other component
reads from.

**Architecture:** A new `crates/claudevs/src/contract/` module holds what Claude Code specifies and
nothing about how claudevs behaves. Four logic-bearing files — `event.rs` (the documented event
catalogue), `matcher.rs` (how a matcher value is evaluated against a payload), `handler.rs` (the
`hooks.json` handler-entry shape), `site.rs` (what counts as a wiring reference site) — plus an
export-only `mod.rs`. Nothing outside the module changes in this plan: the callers are rewired in
plans 03, 04 and 05. That is deliberate, so the module is written against the documentation rather
than shaped by whichever caller happened to be edited first.

**Tech Stack:** Rust 2024, `serde_json` for payload values, `regex` for the regex-mode matcher path,
`thiserror` for the module's error types. No new dependencies. The workspace is featureless — do not
introduce a Cargo `[feature]`.

---

## Corrections found while executing this plan

Tasks 1–5 were executed against the reference itself rather than against the spec, and four of the
spec's claims did not survive. The tasks below still carry the original wording; what shipped differs,
and the delivered code is right. Read this table before reading any task.

| Task text says | Reality | Citation |
|---|---|---|
| 31 documented events | **33** | summary table, 33 rows |
| `stdout_is_context` true for three events | **four** — adds `PostModelSwitch` | `hooks.md:786` |
| `DecisionMechanism` is five variants, mostly `Unspecified` | **twelve variants, no `Unspecified`** — the reference's decision-control table covers all 33 events | `hooks.md:1011-1025` |
| `parse(value)`, one exact-match set for all events | **`parse(event, value)`** — `FileChanged` and `StopFailure` use a narrower set | `hooks.md:301` |

The catalogue rows sketched in Task 3 are illustrative only; the delivered catalogue resolves 20 rows
to `MatcherSupport::Field`, three to `Unresolved` (derived-value subjects) and ten to `None`. `spec.md`
carries the same corrections in its Amendments section.

Fetch the reference as raw markdown and grep it — `curl -sS -L
'https://code.claude.com/docs/en/hooks.md' -o "${TMPDIR:-/tmp}/hooks.md"`. Do not use a summarizing
fetch tool: truncation plus a summarizer is what produced all four errors above.

## Guideline conformance

Every code block here already conforms to `claudestacks-guideline-rust:rust-guidelines`. The rules
that shaped this plan, so a reviewer can check the shape rather than re-derive it:

- **`mod-rs-export-only`** — `contract/mod.rs` carries module docs plus `mod` / `pub use` and nothing
  else. It therefore takes the unit-test-mandate's structural exemption #1 (export-only file) and
  ships no `#[cfg(test)] mod tests`.
- **`unit-test-mandate`** — `event.rs`, `matcher.rs`, `handler.rs` and `site.rs` are logic-bearing and
  each ships a colocated `#[cfg(test)] mod tests`.
- **`strong-types`** — matcher support is not a `bool` and the decision mechanism is not a `String`;
  both are enums whose variants carry the distinction. A matcher value is parsed into a `MatcherRule`
  once, at construction, rather than re-inspected at each use (parse-don't-validate).
- **`modularity`** — `contract::event` and `types::HookEvent` are look-alikes kept apart on purpose;
  each doc comment states the invariant that separates them (spec §2.3). Do not merge them, and do
  not add a "can claudevs simulate this?" field to the catalogue.
- **`doc-comment-discipline`** — no plan numbers, no phase identifiers, no workflow vocabulary, and no
  agent names in any doc comment or `//` comment you write. Cite the documentation by URL where a
  claim comes from it.
- **`strict-quality`, and the lint attributes specifically.** The root `Cargo.toml`
  `[workspace.lints.clippy]` sets `unwrap_used = "deny"`, `panic = "deny"` and `expect_used = "warn"`,
  and the gate runs `-D warnings`. So a test module needs
  `#![expect(clippy::unwrap_used, reason = "…")]` if it calls `.unwrap()`, and
  `#![expect(clippy::panic, reason = "…")]` if it uses `panic!` — including inside a `let-else`.
  The reverse also bites: an `#[expect]` nothing fulfils fires `unfulfilled_lint_expectations`, which
  is itself a warning and therefore a failure. Add each attribute only to the module that earns it,
  and re-check after editing a test module. Note that `unwrap_or_default()`, `unwrap_or_else()` and
  `.ok()` do **not** fulfil `clippy::unwrap_used`.

## File map

```
crates/claudevs/src/contract/mod.rs      — [create] module docs, `mod` + `pub use` only
crates/claudevs/src/contract/event.rs    — [create] the documented event catalogue and its lookup
crates/claudevs/src/contract/matcher.rs  — [create] matcher parsing and evaluation, both modes
crates/claudevs/src/contract/handler.rs  — [create] HookCommand: the hooks.json handler entry
crates/claudevs/src/contract/site.rs     — [create] reference-site scope, fence position, extent
crates/claudevs/src/lib.rs               — [modify] declare `pub mod contract;`
```

Task ownership, so no file is edited by two tasks and no task edits a file it does not list:

| File | Tasks |
|---|---|
| `contract/event.rs` | 1, 2, 3 |
| `contract/matcher.rs` | 4, 5 |
| `contract/handler.rs` | 6, 7 |
| `contract/site.rs` | 8, 9, 10 |
| `contract/mod.rs` | 11 |
| `lib.rs` | 11 |

---

## Task 1 — Derive the documented event catalogue from the reference

This task produces **data you read**, not data you recall. Do not write an event name into the source
that you have not seen on the documentation page in this task.

**Files:**
- Create `crates/claudevs/src/contract/event.rs`

**Steps:**

1. Open the Claude Code hooks reference. Find it by searching the official documentation for the hook
   events reference page; if a `claude-code-guide` agent is available, ask it for the canonical URL of
   the hooks reference and the list of event headings. Record the URL you actually used — it goes into
   the module doc comment in step 5 and is the citation for every row.

2. From that page, extract four columns for every event:
   - the event name exactly as it appears in `hooks.json`
   - whether it accepts a `matcher`, and if so what the matcher is matched against
   - whether the event's bare stdout is injected as context
   - **how that event's output may communicate a decision**, if the reference states it at all

   Write the raw extraction to a scratch file first. You will need to count it.

   The fourth column will be mostly empty, and that is the expected result rather than a failed
   extraction. Spec §1 records that the reference does **not** carry a per-event decision-control
   table — the guide links a reference section that is not present on the page — so a mechanism is
   recorded only where that event's own section states it. Anywhere else the row is `Unspecified`.
   Do not fill a gap by reasoning from what a similar event does, and do not fill one from what
   `crates/claudevs/src/harness/semantics.rs` happens to read today: that file is one of the things
   this chain is correcting, so treating it as a source would make the correction circular.

3. Assert the count before writing any Rust. The spec (§1) records 31 documented events and names the
   ten that take no matcher verbatim:

   ```
   UserPromptSubmit  PostToolBatch  Stop        TeammateIdle    TaskCreated
   TaskCompleted     WorktreeCreate WorktreeRemove  MessageDisplay  CwdChanged
   ```

   If your extraction disagrees with either the count or that list, **stop and report it** rather than
   reconciling silently. The documentation may have moved since the spec was written, and a
   disagreement is a fact the spec's author needs — not something to paper over. Note it, and carry on
   with what the page actually says.

4. Write the failing test first, in `crates/claudevs/src/contract/event.rs`:

   ```rust
   #[cfg(test)]
   mod tests {
       #![expect(clippy::unwrap_used, reason = "tests unwrap known-valid fixtures")]

       use super::{MatcherSupport, lookup};

       #[test]
       fn the_catalogue_holds_every_documented_event() {
           assert_eq!(super::CATALOGUE.len(), 31);
       }

       #[test]
       fn exactly_ten_documented_events_take_no_matcher() {
           let matcherless: Vec<&str> = super::CATALOGUE
               .iter()
               .filter(|row| matches!(row.matcher, MatcherSupport::None))
               .map(|row| row.name)
               .collect();
           assert_eq!(matcherless.len(), 10, "{matcherless:?}");
           for name in [
               "UserPromptSubmit",
               "PostToolBatch",
               "Stop",
               "TeammateIdle",
               "TaskCreated",
               "TaskCompleted",
               "WorktreeCreate",
               "WorktreeRemove",
               "MessageDisplay",
               "CwdChanged",
           ] {
               assert!(matcherless.contains(&name), "{name} should take no matcher");
           }
       }

       #[test]
       fn an_undocumented_event_name_is_not_in_the_catalogue() {
           assert!(lookup("Frobnicate").is_none());
       }

       #[test]
       fn stop_is_documented_even_though_claudevs_cannot_simulate_it() {
           assert!(lookup("Stop").is_some());
       }
   }
   ```

5. Run it and confirm it fails — the module does not compile yet:

   ```
   $ cargo test -p claudevs --lib contract::event
   error[E0433]: failed to resolve: use of undeclared crate or module `contract`
   ```

   (You will see a different error once `mod.rs` exists; at this point the file is not reachable from
   `lib.rs` at all, which is expected — Task 11 wires it. To run these tests before Task 11, add
   `mod contract;` to `lib.rs` temporarily and remove it again before committing. Do not commit a
   temporary `mod` line.)

6. Do not implement yet — Task 2 writes the types, Task 3 writes the rows. Commit nothing from this
   task; it produces the scratch extraction and the test bodies only.

---

## Task 2 — The catalogue types

**Files:**
- Modify `crates/claudevs/src/contract/event.rs`

**Steps:**

1. Write the types above the test module you added in Task 1:

   ```rust
   //! The hook events Claude Code documents.
   //!
   //! This is a description of Claude Code, not of claudevs. It answers "does
   //! this event exist, does it take a matcher, how may its output decide, is its
   //! bare stdout injected as context" — and nothing about whether claudevs can
   //! run a case against it. That second question belongs to
   //! [`crate::types::HookEvent`], whose variants are the events the harness can
   //! synthesize a payload for; the two sets are different and neither derives
   //! from the other.
   //!
   //! Every row is transcribed from the Claude Code hooks reference at
   //! <RECORD THE URL YOU READ IN TASK 1>. Where that page does not state a
   //! fact, the row says so ([`DecisionMechanism::Unspecified`]) rather than
   //! guessing — a checker must produce no finding from an unstated fact.

   /// Whether an event accepts a `matcher`, and what the matcher is compared to.
   #[derive(Debug, Clone, Copy, PartialEq, Eq)]
   pub enum MatcherSupport {
       /// The event takes no matcher; one written here is silently ignored by
       /// the runtime, so a plugin that writes one is not being served.
       None,
       /// The event takes a matcher, and the harness knows which payload field
       /// it is compared against.
       Field(&'static str),
       /// The event takes a matcher, and the reference does not resolve its
       /// subject to a named payload field — it describes what the matcher
       /// matches in prose ("agent type", "the compaction trigger") without
       /// naming the key it is read from. A caller that routes by matcher
       /// treats such an event as unfiltered rather than guessing the key.
       Unresolved,
   }

   /// How an event's output may communicate a decision.
   #[derive(Debug, Clone, Copy, PartialEq, Eq)]
   #[non_exhaustive]
   pub enum DecisionMechanism {
       /// `hookSpecificOutput.permissionDecision`.
       PermissionDecision,
       /// A top-level `decision: "block"` field.
       TopLevelBlock,
       /// `hookSpecificOutput.decision.behavior`.
       BehaviorField,
       /// Exit code 2.
       ExitTwo,
       /// The reference does not say. No checker may emit a finding from this.
       Unspecified,
   }

   /// One documented event.
   #[derive(Debug, Clone, Copy, PartialEq, Eq)]
   #[non_exhaustive]
   pub struct DocumentedEvent {
       /// The event name exactly as it appears in `hooks.json`.
       pub name: &'static str,
       /// Whether a `matcher` applies, and against what.
       pub matcher: MatcherSupport,
       /// How this event's output may decide.
       pub decision: DecisionMechanism,
       /// Whether bare stdout (no JSON envelope) is injected as context.
       pub stdout_is_context: bool,
   }

   /// The documented event whose name is `name`, if any.
   #[must_use]
   pub fn lookup(name: &str) -> Option<&'static DocumentedEvent> {
       CATALOGUE.iter().find(|row| row.name == name)
   }
   ```

2. Run and confirm the failure has moved from "no such module" to "no such item `CATALOGUE`":

   ```
   $ cargo test -p claudevs --lib contract::event
   error[E0425]: cannot find value `CATALOGUE` in this scope
   ```

3. Commit nothing yet; Task 3 adds the rows and this is the first point the file compiles.

---

## Task 3 — The catalogue rows

**Files:**
- Modify `crates/claudevs/src/contract/event.rs`

**Steps:**

1. Write `CATALOGUE` from the Task 1 extraction.

   **How far to take the English → field translation.** Fill `MatcherSupport::Field` for a row only
   where your Task 1 extraction found the reference naming a payload key; everywhere else the row is
   `Unresolved`. In practice that resolves four rows — `PreToolUse` and `PostToolUse` to `tool_name`,
   `SessionStart` to `source`, `SessionEnd` to `reason`, all three keys confirmed against
   `crates/claudevs/src/harness/payload.rs:20-27`, which already emits exactly them.

   Nothing in this module records *why* those four and not others. The catalogue describes Claude
   Code; whether claudevs can run a case against an event is `types::HookEvent`'s answer, and putting
   that fact here too would be the same fact in two places. If a later row's subject turns out to be
   named in the reference after all, fill it — the fact that no caller reads it yet is not a reason to
   leave it `Unresolved`.

   ```rust
   /// Every event the reference documents, in the order the reference lists them.
   ///
   /// `MatcherSupport::Field` carries a payload key only where the reference
   /// names one. Where it describes the matcher's subject in prose without
   /// naming a key, the row is `Unresolved` — inventing a key to fill the gap
   /// would put a routing rule in this table that the documentation does not
   /// state, which is the failure this module exists to prevent.
   static CATALOGUE: &[DocumentedEvent] = &[
       DocumentedEvent {
           name: "PreToolUse",
           matcher: MatcherSupport::Field("tool_name"),
           // Whatever your Task 1 extraction found at this event's own section,
           // or `Unspecified`. Do not write `PermissionDecision` here because
           // `harness/semantics.rs` reads that field today — that file is one of
           // the things this chain corrects.
           decision: DecisionMechanism::Unspecified,
           stdout_is_context: false,
       },
       DocumentedEvent {
           name: "PostToolUse",
           matcher: MatcherSupport::Field("tool_name"),
           decision: DecisionMechanism::Unspecified,
           stdout_is_context: false,
       },
       DocumentedEvent {
           name: "UserPromptSubmit",
           matcher: MatcherSupport::None,
           decision: DecisionMechanism::Unspecified,
           stdout_is_context: true,
       },
       DocumentedEvent {
           name: "UserPromptExpansion",
           matcher: MatcherSupport::Unresolved,
           decision: DecisionMechanism::Unspecified,
           stdout_is_context: true,
       },
       DocumentedEvent {
           name: "SessionStart",
           matcher: MatcherSupport::Field("source"),
           decision: DecisionMechanism::Unspecified,
           stdout_is_context: true,
       },
       DocumentedEvent {
           name: "SessionEnd",
           matcher: MatcherSupport::Field("reason"),
           decision: DecisionMechanism::Unspecified,
           stdout_is_context: false,
       },
       // … the remaining 25 rows, transcribed from the reference in Task 1.
       // Every one of the ten matcher-less events takes MatcherSupport::None.
       // Every event whose decision mechanism the reference does not state takes
       // DecisionMechanism::Unspecified — that is the honest value, not a
       // placeholder, and no checker may emit a finding from it.
   ];
   ```

   No test in this task asserts a specific `DecisionMechanism`, deliberately. A test pinning
   `PreToolUse` to `PermissionDecision` would pin whatever the transcriber believed rather than what
   the reference says, and the whole point of the column is that it is allowed to be empty. If your
   extraction did find mechanisms stated per event, add a test naming the events it found and the
   page section it found them in.

   **`SessionEnd` takes a matcher.** The spec (§1) corrects the intent on this: the matcher table
   gives `SessionEnd` a matcher row with values `clear`, `resume`, `logout`, `prompt_input_exit`,
   `other`, and `SessionEnd` is not in the matcher-less ten. Do not copy the intent's claim.

   **`stdout_is_context` is true for exactly three events** — `UserPromptSubmit`,
   `UserPromptExpansion` and `SessionStart` — per the reference. Everything else is `false`.

2. Add one more test asserting the fact plan 04 depends on:

   ```rust
   #[test]
   fn exactly_three_events_inject_bare_stdout_as_context() {
       let injecting: Vec<&str> = super::CATALOGUE
           .iter()
           .filter(|row| row.stdout_is_context)
           .map(|row| row.name)
           .collect();
       assert_eq!(
           injecting,
           ["UserPromptSubmit", "UserPromptExpansion", "SessionStart"],
       );
   }

   #[test]
   fn a_matcher_subject_the_reference_names_as_a_field_is_recorded_as_one() {
       use super::MatcherSupport::{Field, None as NoMatcher};
       assert_eq!(lookup("PreToolUse").unwrap().matcher, Field("tool_name"));
       assert_eq!(lookup("PostToolUse").unwrap().matcher, Field("tool_name"));
       assert_eq!(lookup("SessionStart").unwrap().matcher, Field("source"));
       assert_eq!(lookup("SessionEnd").unwrap().matcher, Field("reason"));
       assert_eq!(lookup("UserPromptSubmit").unwrap().matcher, NoMatcher);
   }
   ```

   The `injecting` assertion compares against a fixed order, so it also pins that the catalogue lists
   events in the reference's order. If your transcription orders them differently, change the expected
   array to match your order rather than reordering the catalogue.

3. Run and confirm green:

   ```
   $ cargo test -p claudevs --lib contract::event
   running 6 tests
   test contract::event::tests::an_undocumented_event_name_is_not_in_the_catalogue ... ok
   test contract::event::tests::exactly_ten_documented_events_take_no_matcher ... ok
   test contract::event::tests::exactly_three_events_inject_bare_stdout_as_context ... ok
   test contract::event::tests::stop_is_documented_even_though_claudevs_cannot_simulate_it ... ok
   test contract::event::tests::the_catalogue_holds_every_documented_event ... ok
   test contract::event::tests::the_five_simulatable_events_resolve_their_matcher_to_a_payload_field ... ok

   test result: ok. 6 passed; 0 failed
   ```

4. **See it fail.** Delete the `"Stop"` row, re-run, and confirm two tests go red
   (`the_catalogue_holds_every_documented_event` and
   `stop_is_documented_even_though_claudevs_cannot_simulate_it`). Restore the row. A catalogue test
   that has only ever been green is the instrument that missed the original defect.

5. Commit `feat(claudevs): add the documented Claude Code hook event catalogue`.

---

## Task 4 — Matcher parsing: the two modes

**Files:**
- Create `crates/claudevs/src/contract/matcher.rs`

**Steps:**

1. Write the failing test first:

   ```rust
   #[cfg(test)]
   mod tests {
       use super::{MatcherRule, parse};

       #[test]
       fn a_bare_word_is_an_exact_string_not_a_pattern() {
           assert_eq!(parse("Edit"), MatcherRule::Exact(vec![String::from("Edit")]));
       }

       #[test]
       fn a_pipe_separated_value_is_a_list_of_exact_strings() {
           assert_eq!(
               parse("Edit|Write"),
               MatcherRule::Exact(vec![String::from("Edit"), String::from("Write")]),
           );
       }

       #[test]
       fn a_comma_separated_value_is_a_list_and_surrounding_space_is_trimmed() {
           assert_eq!(
               parse("Edit, Write"),
               MatcherRule::Exact(vec![String::from("Edit"), String::from("Write")]),
           );
       }

       #[test]
       fn a_value_carrying_any_other_character_is_a_regex() {
           assert!(matches!(parse("Edit.*"), MatcherRule::Regex(_)));
           assert!(matches!(parse("^Notebook"), MatcherRule::Regex(_)));
       }

       #[test]
       fn a_star_an_empty_string_and_nothing_all_match_everything() {
           assert_eq!(parse("*"), MatcherRule::All);
           assert_eq!(parse(""), MatcherRule::All);
       }
   }
   ```

2. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib contract::matcher
   error[E0432]: unresolved import `super::parse`
   ```

3. Implement:

   ```rust
   //! How a `matcher` value in `hooks.json` is evaluated.
   //!
   //! A matcher is not a regular expression. The Claude Code hooks reference
   //! defines two modes, chosen by the characters in the value: a value made only
   //! of letters, digits, `_`, `-`, spaces, `,` and `|` is an exact string — or a
   //! list of exact strings separated by `|` or `,` — and any other character
   //! makes the whole value a regular expression, matched **unanchored**. `"*"`,
   //! the empty string and an absent matcher all match everything.
   //!
   //! The regex mode is JavaScript's, tested with `RegExp.prototype.test`. Rust's
   //! `regex` crate is a narrower dialect: it has no lookaround and no
   //! backreferences, so a pattern that is valid in Claude Code can fail to
   //! compile here. That divergence is reported as a warning naming the engine,
   //! never as an error, because the plugin is not the thing that is wrong.
   //!
   //! One module owns this so that dispatch and the static checker can never
   //! disagree about what a matcher means.

   /// A parsed matcher value.
   #[derive(Debug, Clone)]
   pub enum MatcherRule {
       /// Matches every payload.
       All,
       /// Matches when the subject equals any of these strings.
       Exact(Vec<String>),
       /// Matches when the pattern is found anywhere in the subject.
       Regex(Box<regex::Regex>),
       /// The value is regex-mode but Rust's `regex` crate rejects it. Carries
       /// the value and the compile error so a caller can report which engine
       /// refused it.
       Unsupported {
           /// The matcher value as written.
           value: String,
           /// What Rust's `regex` crate said.
           reason: String,
       },
   }

   /// The characters that keep a matcher on the exact-string path.
   fn is_exact_mode_char(c: char) -> bool {
       c.is_ascii_alphanumeric() || matches!(c, '_' | '-' | ' ' | ',' | '|')
   }

   /// Parses a `matcher` value into the rule that evaluates it.
   #[must_use]
   pub fn parse(value: &str) -> MatcherRule {
       if value.is_empty() || value == "*" {
           return MatcherRule::All;
       }
       if value.chars().all(is_exact_mode_char) {
           let alternatives: Vec<String> = value
               .split(['|', ','])
               .map(|part| part.trim().to_owned())
               .filter(|part| !part.is_empty())
               .collect();
           return if alternatives.is_empty() {
               MatcherRule::All
           } else {
               MatcherRule::Exact(alternatives)
           };
       }
       match regex::Regex::new(value) {
           Ok(compiled) => MatcherRule::Regex(Box::new(compiled)),
           Err(error) => MatcherRule::Unsupported {
               value: value.to_owned(),
               reason: error.to_string(),
           },
       }
   }
   ```

   `MatcherRule` cannot derive `PartialEq` because `regex::Regex` does not implement it. The tests
   above compare `MatcherRule::Exact(...)` with `assert_eq!`, so add a hand-written `PartialEq` that
   compares `Regex` by its `as_str()`:

   ```rust
   impl PartialEq for MatcherRule {
       fn eq(&self, other: &Self) -> bool {
           match (self, other) {
               (Self::All, Self::All) => true,
               (Self::Exact(a), Self::Exact(b)) => a == b,
               (Self::Regex(a), Self::Regex(b)) => a.as_str() == b.as_str(),
               (
                   Self::Unsupported { value: a, .. },
                   Self::Unsupported { value: b, .. },
               ) => a == b,
               _ => false,
           }
       }
   }
   ```

   `Box<regex::Regex>` rather than a bare `Regex` keeps `MatcherRule` small enough that clippy's
   `large_enum_variant` stays quiet; a compiled `Regex` is several hundred bytes.

4. Run and confirm green:

   ```
   $ cargo test -p claudevs --lib contract::matcher
   running 5 tests
   test result: ok. 5 passed; 0 failed
   ```

5. **See it fail.** Change `is_exact_mode_char` to `|c: char| c.is_ascii_alphanumeric()` and confirm
   `a_pipe_separated_value_is_a_list_of_exact_strings` goes red with
   ``assert_eq! left: Regex(Edit|Write) right: Exact(["Edit", "Write"])``. Restore it.

6. Commit `feat(claudevs): parse a hooks.json matcher in both its documented modes`.

---

## Task 5 — Matcher evaluation against a subject

**Files:**
- Modify `crates/claudevs/src/contract/matcher.rs`

**Steps:**

1. Add the failing tests:

   ```rust
   #[test]
   fn an_exact_list_matches_only_a_whole_element() {
       let rule = parse("Edit|Write");
       assert!(rule.matches("Edit"));
       assert!(rule.matches("Write"));
       assert!(!rule.matches("NotebookEdit"));
       assert!(!rule.matches("Edit|Write"));
   }

   #[test]
   fn a_regex_is_unanchored_so_edit_star_reaches_notebookedit() {
       assert!(parse("Edit.*").matches("NotebookEdit"));
   }

   #[test]
   fn all_matches_anything_including_the_empty_subject() {
       assert!(parse("*").matches("Edit"));
       assert!(parse("*").matches(""));
   }

   #[test]
   fn an_unsupported_pattern_matches_nothing_and_says_which_engine_refused_it() {
       let rule = parse("(?<=Edit)Write");
       let MatcherRule::Unsupported { value, reason } = &rule else {
           panic!("a lookbehind is not supported by Rust's regex crate: {rule:?}");
       };
       assert_eq!(value, "(?<=Edit)Write");
       assert!(!reason.is_empty());
       assert!(!rule.matches("EditWrite"));
   }
   ```

   The last test needs `#![expect(clippy::panic, reason = "tests panic to reject an unexpected
   shape")]` at the top of the test module, matching the convention already used in
   `crates/claudevs/src/harness/verdict.rs:86`.

2. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib contract::matcher
   error[E0599]: no method named `matches` found for enum `MatcherRule`
   ```

3. Implement:

   ```rust
   impl MatcherRule {
       /// Whether this rule matches `subject`.
       ///
       /// The exact path compares whole strings; the regex path searches, since
       /// the documented semantics are `RegExp.prototype.test` on an unanchored
       /// pattern — the reference's own example has `Edit.*` reaching
       /// `NotebookEdit`. An [`MatcherRule::Unsupported`] value matches nothing:
       /// claudevs cannot evaluate it, and pretending it matched would route a
       /// case to a handler the runtime might not have chosen.
       #[must_use]
       pub fn matches(&self, subject: &str) -> bool {
           match self {
               Self::All => true,
               Self::Exact(alternatives) => alternatives.iter().any(|a| a == subject),
               Self::Regex(pattern) => pattern.is_match(subject),
               Self::Unsupported { .. } => false,
           }
       }
   }
   ```

4. Run and confirm green:

   ```
   $ cargo test -p claudevs --lib contract::matcher
   running 9 tests
   test result: ok. 9 passed; 0 failed
   ```

5. **See it fail.** Change the `Exact` arm to `alternatives.iter().any(|a| subject.contains(a))` and
   confirm `an_exact_list_matches_only_a_whole_element` goes red on the `NotebookEdit` assertion.
   Restore it.

6. Commit `feat(claudevs): evaluate a parsed matcher against a payload subject`.

---

## ◆ CHECKPOINT — stop here and report

The catalogue and the matcher evaluator now exist and are tested. This is the point where the
design's least-reviewed half either holds or does not: spec §2.2 was written after the last
independent review pass, and everything from Task 6 on assumes its two-mode reading is right.

Report before continuing:

- the URL you transcribed the catalogue from, and whether the count came out at 31
- whether the matcher-less ten matched the spec's list exactly
- anything in the reference that contradicts §2.2's two-mode table

Wait for a go-ahead. Do not start Task 6.

---

## Task 6 — `HookCommand`: the handler entry as a type

**Files:**
- Create `crates/claudevs/src/contract/handler.rs`

**Steps:**

1. Write the failing test:

   ```rust
   #[cfg(test)]
   mod tests {
       use super::{HookCommand, from_entry};

       #[test]
       fn an_entry_with_only_a_command_is_a_shell_handler() {
           let entry = serde_json::json!({"type": "command", "command": "echo hi"});
           assert_eq!(
               from_entry(&entry),
               Some(HookCommand::Shell(String::from("echo hi"))),
           );
       }

       #[test]
       fn an_entry_with_args_is_an_exec_handler_and_keeps_every_element() {
           let entry = serde_json::json!({
               "type": "command",
               "command": "sh",
               "args": ["-c", "echo hi"]
           });
           assert_eq!(
               from_entry(&entry),
               Some(HookCommand::Exec {
                   program: String::from("sh"),
                   args: vec![String::from("-c"), String::from("echo hi")],
               }),
           );
       }

       #[test]
       fn a_handler_type_claudevs_does_not_model_is_skipped_not_an_error() {
           let entry = serde_json::json!({"type": "prompt", "prompt": "summarise"});
           assert_eq!(from_entry(&entry), None);
       }

       #[test]
       fn an_entry_with_no_type_at_all_is_skipped() {
           let entry = serde_json::json!({"command": "echo hi"});
           assert_eq!(from_entry(&entry), None);
       }

       #[test]
       fn an_entry_that_cannot_be_parsed_is_skipped_not_an_error() {
           assert_eq!(from_entry(&serde_json::json!(42)), None);
           assert_eq!(from_entry(&serde_json::json!({"type": "command"})), None);
       }
   }
   ```

   Note `an_entry_with_no_type_at_all_is_skipped`. Today `crates/claudevs/src/harness/hooks_file.rs:40`
   reads `entry.get("command")` with no `type` check, so an entry with no `type` is accepted. Once the
   entry is parsed into an enum, that has to be chosen; it is chosen as **skip**, because the
   documented shape names `type` and an entry without one is a shape claudevs does not model. Plan 03
   carries the corresponding change at the call site.

2. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib contract::handler
   error[E0432]: unresolved import `super::from_entry`
   ```

3. Implement:

   ```rust
   //! The `hooks.json` handler entry.
   //!
   //! The reference specifies two execution models for a `type: "command"`
   //! handler, and they are genuinely different rather than a flag on one shape:
   //! a `command` alone is run through a shell, while a `command` with `args` is
   //! resolved as an executable and spawned directly — "There is no shell, so
   //! each `args` element is one argument exactly as written … No shell
   //! tokenization happens on any platform."
   //!
   //! Handler types claudevs does not model — prompt, agent, `http`, `mcp_tool` —
   //! are skipped rather than rejected. claudevs not modelling a handler is a
   //! limit of claudevs, and turning it into a parse failure would fail a plugin
   //! that is correct.

   /// One `type: "command"` handler from `hooks.json`.
   #[derive(Debug, Clone, PartialEq, Eq)]
   #[non_exhaustive]
   pub enum HookCommand {
       /// `command` alone: run through `sh -c`.
       Shell(String),
       /// `command` plus `args`: spawned directly, no shell.
       Exec {
           /// The executable.
           program: String,
           /// The argument vector, each element passed exactly as written.
           args: Vec<String>,
       },
   }

   /// The handler an entry declares, or `None` when claudevs does not model it.
   ///
   /// `None` is not an error. An entry whose `type` is not `command`, an entry
   /// with no `type`, and an entry claudevs cannot parse are all skipped, so a
   /// plugin mixing a prompt handler into a hook group still runs its command
   /// handlers.
   #[must_use]
   pub fn from_entry(entry: &serde_json::Value) -> Option<HookCommand> {
       if entry.get("type").and_then(serde_json::Value::as_str) != Some("command") {
           return None;
       }
       let command = entry.get("command").and_then(serde_json::Value::as_str)?;
       let Some(args) = entry.get("args").and_then(serde_json::Value::as_array) else {
           return Some(HookCommand::Shell(command.to_owned()));
       };
       let args: Vec<String> = args
           .iter()
           .filter_map(|a| a.as_str().map(str::to_owned))
           .collect();
       Some(HookCommand::Exec {
           program: command.to_owned(),
           args,
       })
   }
   ```

4. Run and confirm green:

   ```
   $ cargo test -p claudevs --lib contract::handler
   running 5 tests
   test result: ok. 5 passed; 0 failed
   ```

5. **See it fail.** Delete the `type` check (the first `if`), re-run, and confirm
   `a_handler_type_claudevs_does_not_model_is_skipped_not_an_error` and
   `an_entry_with_no_type_at_all_is_skipped` both go red. Restore it.

6. Commit `feat(claudevs): model the hooks.json handler entry as shell or exec`.

---

## Task 7 — The handler's display form

**Files:**
- Modify `crates/claudevs/src/contract/handler.rs`

**Steps:**

1. Add the failing test:

   ```rust
   #[test]
   fn a_shell_handler_displays_as_its_command_string() {
       assert_eq!(
           HookCommand::Shell(String::from("echo hi")).display(),
           "echo hi",
       );
   }

   #[test]
   fn an_exec_handler_displays_as_the_argv_it_spawns() {
       let handler = HookCommand::Exec {
           program: String::from("sh"),
           args: vec![String::from("-c"), String::from("echo hi")],
       };
       assert_eq!(handler.display(), "sh -c echo hi");
   }

   #[test]
   fn an_exec_handler_with_no_args_displays_as_its_program_alone() {
       let handler = HookCommand::Exec {
           program: String::from("true"),
           args: Vec::new(),
       };
       assert_eq!(handler.display(), "true");
   }
   ```

2. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib contract::handler
   error[E0599]: no method named `display` found for enum `HookCommand`
   ```

3. Implement:

   ```rust
   impl HookCommand {
       /// The handler as text, for substring matching and for reporting.
       ///
       /// One definition so the `hook:` disambiguator and a failure message can
       /// never disagree about what a handler is called. For an exec handler
       /// this is the argv actually spawned, joined by single spaces — the thing
       /// a shell-only reading of `hooks.json` makes invisible.
       #[must_use]
       pub fn display(&self) -> String {
           match self {
               Self::Shell(command) => command.clone(),
               Self::Exec { program, args } if args.is_empty() => program.clone(),
               Self::Exec { program, args } => format!("{program} {}", args.join(" ")),
           }
       }
   }
   ```

   Do not implement `std::fmt::Display` instead: clippy's `inherent_to_string` and the guideline both
   allow an inherent method here, and a `Display` impl would invite `{handler}` interpolation in
   contexts where the argv join is misleading. Keep it named.

4. Run and confirm green:

   ```
   $ cargo test -p claudevs --lib contract::handler
   running 8 tests
   test result: ok. 8 passed; 0 failed
   ```

5. Commit `feat(claudevs): give a hook handler one display form for filtering and reporting`.

---

## Task 8 — Reference-site scope: which files Claude Code loads

**Files:**
- Create `crates/claudevs/src/contract/site.rs`

**Steps:**

1. Write the failing test:

   ```rust
   #[cfg(test)]
   mod tests {
       use super::is_loaded_file;
       use std::path::Path;

       #[test]
       fn the_five_loaded_trees_are_in_scope() {
           for rel in [
               ".claude-plugin/plugin.json",
               "hooks/hooks.json",
               "hooks/guard.py",
               "skills/authoring/SKILL.md",
               "agents/reviewer.md",
               "commands/ship.md",
           ] {
               assert!(is_loaded_file(Path::new(rel)), "{rel} should be in scope");
           }
       }

       #[test]
       fn a_plugins_own_prose_is_not_wiring() {
           for rel in [
               "README.md",
               "CHANGELOG.md",
               "RELEASE-NOTES.md",
               "docs/design.md",
               "tests/fixtures/x/README.md",
           ] {
               assert!(!is_loaded_file(Path::new(rel)), "{rel} should be out of scope");
           }
       }

       #[test]
       fn a_hook_script_is_in_scope_because_claude_code_executes_it() {
           assert!(is_loaded_file(Path::new("hooks/lib/paths.sh")));
       }
   }
   ```

   The last test pins spec §4.1 item 2's deliberate widening: the scanned set is `hooks/**`, not
   `hooks/hooks.json`. A `${CLAUDE_PLUGIN_ROOT}` path inside a hook script is as load-bearing as a
   reference gets.

2. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib contract::site
   error[E0432]: unresolved import `super::is_loaded_file`
   ```

3. Implement:

   ```rust
   //! What counts as a wiring reference site.
   //!
   //! Three questions, one place: is this a file Claude Code loads, is this
   //! position inside it load-bearing or illustrative, and where does a
   //! reference end. Answering them once is what keeps the reference checker
   //! from re-deriving the plugin layout from the plugins in front of it.

   use std::path::Path;

   /// The trees Claude Code loads from a plugin root.
   ///
   /// `hooks/**` rather than `hooks/hooks.json`: a hook script is executed by
   /// Claude Code, so a path inside one is wiring. A plugin's README, changelog,
   /// release notes and `docs/` tree are not — nothing loads them, and a path
   /// mentioned there is prose about the plugin rather than part of it.
   const LOADED_TREES: [&str; 4] = ["hooks", "skills", "agents", "commands"];

   /// Whether `relative` — a path relative to the plugin root — is a file Claude
   /// Code loads.
   #[must_use]
   pub fn is_loaded_file(relative: &Path) -> bool {
       let mut components = relative.components();
       let Some(first) = components.next() else {
           return false;
       };
       let first = first.as_os_str();
       if first == ".claude-plugin" {
           return relative.extension().is_some_and(|e| e == "json");
       }
       LOADED_TREES.iter().any(|tree| first == *tree)
   }
   ```

4. Run and confirm green:

   ```
   $ cargo test -p claudevs --lib contract::site
   running 3 tests
   test result: ok. 3 passed; 0 failed
   ```

5. **See it fail.** Replace `LOADED_TREES` with `["skills", "agents", "commands"]` and confirm both
   `the_five_loaded_trees_are_in_scope` and
   `a_hook_script_is_in_scope_because_claude_code_executes_it` go red. Restore it.

6. Commit `feat(claudevs): decide once which plugin files Claude Code loads`.

---

## Task 9 — Fenced positions are illustrative

**Files:**
- Modify `crates/claudevs/src/contract/site.rs`

**Steps:**

1. Add the failing test:

   ```rust
   #[test]
   fn a_line_inside_a_fence_is_illustrative() {
       let text = "prose\n```json\nfenced\n```\nmore prose\n";
       let fenced = super::fenced_lines(text);
       assert!(!fenced.contains(&1), "line 1 is prose");
       assert!(fenced.contains(&3), "line 3 is inside the fence");
       assert!(!fenced.contains(&5), "line 5 is prose again");
   }

   #[test]
   fn the_fence_markers_themselves_count_as_fenced() {
       let text = "```\nx\n```\n";
       let fenced = super::fenced_lines(text);
       assert!(fenced.contains(&1));
       assert!(fenced.contains(&2));
       assert!(fenced.contains(&3));
   }

   #[test]
   fn a_tilde_fence_is_a_fence_too() {
       let text = "prose\n~~~\nfenced\n~~~\n";
       assert!(super::fenced_lines(text).contains(&3));
   }

   #[test]
   fn an_unclosed_fence_swallows_the_rest_of_the_file() {
       let text = "prose\n```\nfenced\nstill fenced\n";
       let fenced = super::fenced_lines(text);
       assert!(!fenced.contains(&1));
       assert!(fenced.contains(&4));
   }
   ```

2. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib contract::site
   error[E0425]: cannot find function `fenced_lines` in module `super`
   ```

3. Implement:

   ```rust
   /// The 1-indexed lines of `text` that sit inside a fenced code block.
   ///
   /// A fenced block is illustrative: a schema document teaching hook authoring
   /// cites a `${CLAUDE_PLUGIN_ROOT}` path inside a ```` ```json ```` block as an
   /// example, and that path is not claiming to exist. The fence markers
   /// themselves are counted as fenced, since an info string can carry a path
   /// too. An unclosed fence takes the rest of the file: a document that opens a
   /// block and never closes it is not making load-bearing claims below it.
   #[must_use]
   pub fn fenced_lines(text: &str) -> std::collections::BTreeSet<usize> {
       let mut inside = false;
       let mut fenced = std::collections::BTreeSet::new();
       for (index, line) in text.lines().enumerate() {
           let trimmed = line.trim_start();
           let is_marker = trimmed.starts_with("```") || trimmed.starts_with("~~~");
           if is_marker {
               fenced.insert(index + 1);
               inside = !inside;
               continue;
           }
           if inside {
               fenced.insert(index + 1);
           }
       }
       fenced
   }
   ```

4. Run and confirm green:

   ```
   $ cargo test -p claudevs --lib contract::site
   running 7 tests
   test result: ok. 7 passed; 0 failed
   ```

5. **See it fail.** Remove the `fenced.insert(index + 1)` inside the `is_marker` branch and confirm
   `the_fence_markers_themselves_count_as_fenced` goes red. Restore it.

6. Commit `feat(claudevs): tell a fenced example from a load-bearing reference`.

---

## Task 10 — Where a reference ends

**Files:**
- Modify `crates/claudevs/src/contract/site.rs`

**Steps:**

1. Add the failing test. The third assertion is the `anthropics/ralph-wiggum` defect from spec §4.1
   item 3, reproduced exactly:

   ```rust
   #[test]
   fn a_plain_path_reference_ends_at_whitespace() {
       assert_eq!(
           super::reference_extent("${CLAUDE_PLUGIN_ROOT}/scripts/run.sh and then"),
           "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh",
       );
   }

   #[test]
   fn a_reference_ends_before_a_closing_quote_or_bracket() {
       assert_eq!(
           super::reference_extent("${CLAUDE_PLUGIN_ROOT}/scripts/run.sh\")"),
           "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh",
       );
   }

   #[test]
   fn a_tool_argument_matcher_is_not_part_of_the_path() {
       // anthropics/ralph-wiggum declares:
       //   allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)"]
       // The script exists; `:*` is Claude Code's tool-argument matcher.
       assert_eq!(
           super::reference_extent("${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)"),
           "${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh",
       );
   }
   ```

2. Run and confirm failure:

   ```
   $ cargo test -p claudevs --lib contract::site
   error[E0425]: cannot find function `reference_extent` in module `super`
   ```

3. Implement:

   ```rust
   /// Characters that end a `${CLAUDE_PLUGIN_ROOT}` reference.
   ///
   /// `:` is here because of Claude Code's tool-argument matcher: a command
   /// declares `allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/x.sh:*)"]`,
   /// where `:*` says "any arguments" and is not part of the path. Swallowing it
   /// reports a script that exists as missing.
   const REFERENCE_TERMINATORS: [char; 12] =
       [' ', '\t', '"', '\'', '`', ')', ']', '}', ',', ';', ':', '\\'];

   /// The reference at the start of `text`, up to where it ends.
   ///
   /// `text` begins at the `$` of a `${CLAUDE_PLUGIN_ROOT}` occurrence. The
   /// leading `${…}` is stepped over before scanning for a terminator, so the
   /// `}` closing the variable does not end the reference it opens.
   #[must_use]
   pub fn reference_extent(text: &str) -> &str {
       const VARIABLE: &str = "${CLAUDE_PLUGIN_ROOT}";
       let scan_from = if text.starts_with(VARIABLE) {
           VARIABLE.len()
       } else {
           0
       };
       let end = text[scan_from..]
           .find(REFERENCE_TERMINATORS)
           .map_or(text.len(), |offset| scan_from + offset);
       text[..end].trim_end_matches('.')
   }
   ```

   The trailing `trim_end_matches('.')` drops a sentence-final period, which is a real shape in prose
   references ("see `${CLAUDE_PLUGIN_ROOT}/scripts/run.sh`."). It cannot eat a file extension, because
   an extension is never last.

4. Run and confirm green:

   ```
   $ cargo test -p claudevs --lib contract::site
   running 10 tests
   test result: ok. 10 passed; 0 failed
   ```

5. **See it fail.** Remove `':'` from `REFERENCE_TERMINATORS` and confirm
   `a_tool_argument_matcher_is_not_part_of_the_path` goes red with
   ``left: "${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*"``. That red is the
   `anthropics/ralph-wiggum` false error reproduced in a unit test. Restore the character.

6. Commit `fix(claudevs): stop a tool-argument matcher being swallowed into a reference path`.

---

## Task 11 — Wire the module in

**Files:**
- Create `crates/claudevs/src/contract/mod.rs`
- Modify `crates/claudevs/src/lib.rs`

**Steps:**

1. Write `crates/claudevs/src/contract/mod.rs`. It is export-only — module docs plus `mod` and
   `pub use`, nothing else, and no `#[cfg(test)] mod tests` (unit-test-mandate structural exemption
   #1, export-only file):

   ```rust
   //! What Claude Code specifies about plugin hooks.
   //!
   //! One module owns the contract so no other component has to guess at it.
   //! Four questions, four files:
   //!
   //! - [`event`] — which events exist, which take a matcher, how their output
   //!   may decide, whose bare stdout is injected as context.
   //! - [`matcher`] — how a `matcher` value is evaluated, in both its documented
   //!   modes.
   //! - [`handler`] — the `hooks.json` handler entry and its two execution
   //!   models.
   //! - [`site`] — which plugin files Claude Code loads, which positions in them
   //!   are load-bearing, and where a reference ends.
   //!
   //! Everything here describes Claude Code. Nothing here describes what claudevs
   //! can do about it: whether a case can be run against an event is
   //! [`crate::types::HookEvent`]'s answer, and the two are deliberately separate
   //! types over overlapping sets.
   //!
   //! Export-only: module docs plus `mod` and `pub use`, no logic, and therefore
   //! no colocated test module.

   pub mod event;
   pub mod handler;
   pub mod matcher;
   pub mod site;

   pub use event::{DecisionMechanism, DocumentedEvent, MatcherSupport, lookup};
   pub use handler::HookCommand;
   pub use matcher::MatcherRule;
   ```

2. Add the module declaration to `crates/claudevs/src/lib.rs`, in the existing alphabetical `pub mod`
   block (after `pub mod check;`, before `pub mod doctor;`):

   ```rust
   pub mod case;
   pub mod check;
   pub mod contract;
   pub mod doctor;
   pub mod harness;
   ```

   Do **not** add a `pub use contract::…` re-export line to `lib.rs`. The contract's items are reached
   as `claudevs::contract::…`; flattening them into the crate root would put `lookup` and `MatcherRule`
   beside `render_human` and `run_suite`, which are a different kind of thing.

3. Run the full Definition of Done and confirm every step is clean:

   ```
   $ cargo fmt --all -- --check
   $ cargo clippy --workspace --all-targets --all-features -- -D warnings
       Finished `dev` profile [unoptimized + debuginfo] target(s)
   $ RUSTDOCFLAGS="-D warnings" cargo doc --workspace --all-features --no-deps
       Generated .../target/doc/claudevs/index.html
   $ cargo test --workspace --all-targets --all-features
   test result: ok. 0 failed
   $ cargo test --workspace --all-features --doc
   test result: ok. 0 failed
   ```

   `cargo make dod` runs all five; use that if cargo-make is installed.

4. Commit `feat(claudevs): expose the contract module from the crate root`.

---

## Done when

- `cargo make dod` is green with zero warnings.
- `contract/mod.rs` contains only module docs, `mod` and `pub use` lines.
- `event.rs`, `matcher.rs`, `handler.rs` and `site.rs` each carry `#[cfg(test)] mod tests`.
- Every fix in Tasks 3, 4, 5, 6, 8, 9 and 10 was watched go red before it went green.
- No caller outside `contract/` was changed. If you found yourself editing `wiring/` or `harness/`,
  that is plan 03 or plan 05 and does not belong here.
