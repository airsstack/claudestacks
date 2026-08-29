---
status: approved
created: 2026-08-29
source: triage
---

# Intent: claudevs is wrong about plugins it has never met

## Problem

`claudevs` treats the plugins in this repository as if they were the specification for what a Claude
Code plugin is. The source says so outright — `crates/claudevs/src/types/hook_event.rs:4-5` describes
its five variants as "the events observed in real hooks.json files in this repository", and
`crates/claudevs/src/harness/hooks_file.rs:3` records that the hooks.json shape was "verified against
this repository's plugins".

That has two consequences, and both are now measured rather than suspected.

**It reports verdicts it has not earned.** Four separate paths produce a passing result without
testing anything: `expect: {output: none}` cannot fail on a script or flow case; a hook's `args`
argument vector is dropped and a different process is executed in its place; `hooks.json` matchers are
ignored when dispatching, so a case can assert behaviour for an event/matcher pair the runtime can
never produce and be told it passed; and the default synthesized payload points at a bare temp
directory, which drives hooks down their silent branch so the case would pass equally if the hook were
broken or its runtime uninstalled. For a tool whose entire product is a verdict, a false green is the
tool lying.

**It reports findings that are not real on plugins it did not author.** Swept across 156 third-party
plugin roots from 13 public repositories, `claudevs check` fails 43 of them. Three of those failures
are genuine. The other 40 are the tool being wrong: 35 plugins are rejected solely because
`crates/claudevs/src/validate.rs:72` hardcodes `--strict`, and the five that reach the wiring stage
collect 114 findings between them, every one examined being a false positive. Three of those five are
Anthropic's own plugins.

The two are the same defect wearing different clothes, and the crate's 201 tests structurally cannot
catch either, because the corpus that defines correctness is the same corpus the code was fitted to.

This matters now because the crate has not been published yet. At publication the public API, the JSON
report shape, and the exit-code contract all freeze, and `#[non_exhaustive]` currently appears exactly
once in the whole crate.

## Affected systems

`crates/claudevs` only. Within it:

- the run path — `harness/hooks_file.rs`, `harness/spawn.rs`, `harness/semantics.rs`,
  `harness/payload.rs`, `harness/verdict.rs`, `suite.rs`
- the static checkers — `wiring/refs.rs`, `wiring/invocations.rs`, `wiring/matchers.rs`
- the gates that decide whether a verdict is reached at all — `validate.rs`, `check.rs`
- the type surface that freezes at publication — `types/hook_event.rs`, and the `#[non_exhaustive]`
  audit across every public enum and struct

`crates/claudevs-cli` is affected only where a flag has to surface. `crates/clauders` is untouched.

## Desired outcome

An engineer can point `claudevs` at a plugin nobody in this repository wrote and trust what comes back.

Concretely, that means three things hold. Every passing verdict was earned — no assertion can silently
succeed without observing what it claims to observe, and the harness executes the hook the plugin
actually declared. Every reported finding is real, or is a warning that a reasonable plugin author
would agree with. And nothing stops `claudevs` reaching a verdict for a cosmetic reason: a plugin is
not rejected over a missing `author` field before its hooks have been looked at.

Once that holds, a corpus of plugins this repository did not author becomes a standing check on the
root cause, so the corpus can no longer quietly serve as the specification.

## Constraints

- Must land before the crates.io publication of `0.1.0`. Public API shape, the `--json` report
  structure, and the exit-code contract freeze at that point; `#[non_exhaustive]` is the mitigation and
  currently exists on `Error` alone.
- Breaking the public API is free until then, and breaking the case file format costs nothing today —
  the repository ships zero case files.
- The workspace is featureless. No crate declares Cargo `[features]`, and nothing here may introduce
  one.
- The Definition of Done in the `claudestacks-guideline-rust` plugin is the pass/fail gate.
- Per repository policy, every fix carries a test that was watched fail before it passed. Four of these
  defects are silent false greens; a test that has only ever been green is exactly the instrument that
  missed them.
- Whatever third-party corpus is used as a standing check must not require network access at test time.
  Live `git clone` in CI is not acceptable.

## Non-goals

- The adoption path for an existing plugin — the scaffold, the inventory command, the adoption skill,
  and documenting the case file format. Separate chain, sequenced after this one.
- Plugin cache staleness and dead registry entries. Separate chain, independent of this one.
- Widening `HookEvent` to all 31 documented events for completeness. Across 156 real plugins only five
  distinct events appear and `claudevs` already knows four; the work here is about how unknown events
  are handled and about `#[non_exhaustive]`, not about exhaustive coverage.
- Anything in `crates/clauders`, and anything touching the Managed Agents pillar.
- Prompt-based, agent-based, `http`, and `mcp_tool` hook handler types. Only `type: command` is in
  scope.

## Evidence

All of the following was produced in a spike session on 2026-08-29 against
`target/debug/claudevs` built from the current `main`. Durable write-ups live in the journal notes
`claudevs-silent-false-green-paths` and `claudevs-wiring-corpus-calibration`.

### `args` is dropped and the wrong process runs

The Claude Code hooks reference defines the field: "`args` | no | Argument list. When present,
`command` is resolved as an executable and spawned directly with `args` as the argument vector, with no
shell involved."

`crates/claudevs/src/harness/hooks_file.rs:40` reads only `command`:

```rust
if let Some(command) = entry.get("command").and_then(serde_json::Value::as_str)
```

and `crates/claudevs/src/harness/spawn.rs:120` unconditionally wraps it in a shell:

```rust
let argv = vec![String::from("sh"), String::from("-c"), command.to_owned()];
```

Probe plugin with the hook `{"type": "command", "command": "sh", "args": ["-c", "echo
CORRECT-ARGS-HONOURED"]}` and a case asserting `context_contains: CORRECT-ARGS-HONOURED`:

```
  FAIL  args
        context: expected to contain `CORRECT-ARGS-HONOURED`, got None

0 passed, 1 failed (1 cases, 0 native suites)
CLAUDEVS_EXIT=1
```

`sh -c sh` was executed. No error and no warning was raised about the ignored `args`. The failure
message shows neither the captured stdout/stderr nor the argv actually spawned, so there is no route
from this output to the cause. `AgriciDaniel/claude-seo` (15.7k stars) uses this hook form in
production.

### `expect: {output: none}` cannot fail on a script or flow case

`crates/claudevs/src/suite.rs:224-232`:

```rust
fn script_observed(captured: &crate::harness::Captured) -> Observed {
    Observed {
        exit: captured.exit,
        stdout: captured.stdout.clone(),
        stderr: captured.stderr.clone(),
        timed_out: captured.timed_out,
        ..Observed::default()
    }
}
```

`emitted` therefore always defaults to `false`. `crates/claudevs/src/harness/verdict.rs:45` gates the
assertion on it:

```rust
if expect.output.as_deref() == Some("none") && observed.emitted {
    mismatches.push(String::from("output: expected none, but the hook emitted"));
```

The assertion reads like a real one and passes unconditionally, whatever the command printed.

### Matchers are ignored when dispatching

`resolve` in `crates/claudevs/src/harness/hooks_file.rs` flattens every group's commands and never
reads `matcher`; disambiguation is a substring match on the command string via `hook:`. A case pairing
`hook: preflight.sh` with `payload: {source: compact}` — a combination the runtime cannot produce,
because the `compact` matcher routes to `rearm.sh` — was run against `plugins/claudestacks`:

```
  ok    zz-matcher-probe
1 passed, 0 failed (1 cases, 0 native suites)
EXIT=0
```

The `check` command's wiring stage does compile matchers, so the tool holds the information; it simply
does not use it to dispatch.

### The default payload drives hooks down their silent branch

`harness/payload.rs` `default_payload` sets `cwd` and `tool_input.file_path` to a bare temp directory —
no git repository, no `Cargo.toml`, no registry record bound to it. A `PreToolUse` case against
`plugins/claudestacks`'s `enforce.sh` passes on that payload, and would pass identically if `airsl`
were uninstalled, if `enforce.lua` had a syntax error, or if the registry were empty.

### The matchers checker never asks whether an event accepts a matcher

Ten of the 31 documented hook events take no matcher; a matcher written on one of them is silently
ignored by the runtime. `crates/claudevs/src/wiring/matchers.rs` checks only that the event name parses
and that the matcher compiles as a regex. A probe plugin carrying deliberately bogus matchers on
`UserPromptSubmit` and `SessionEnd` — both of which the runtime would ignore:

```
  ok    validate
  ok    wiring
        0 errors, 0 warnings
```

### The third-party corpus sweep

13 public repositories, 156 plugin roots, 17 of them shipping a `hooks/hooks.json`. `claudevs check`
run against every root:

```
swept 156 plugins
=== exit code distribution ===
 113 0
  43 1
=== first failing stage distribution ===
 113 -
  38 validate
   5 wiring
```

Re-running `claude plugin validate` without `--strict` on every plugin that failed with it:

```
pass --strict outright:                          118
fail --strict but pass without it:               35
fail even without --strict (genuine errors):     3
```

The three genuine failures are `anthropics/claude-code/plugins/pr-review-toolkit`,
`trailofbits/skills-curated/plugins/planning-with-files`, and
`wshobson/agents/plugins/pptx-deck-creation`. `crates/claudevs/src/validate.rs:72` hardcodes `--strict`
with no opt-out, and a failed stage aborts the pipeline — verified with a probe plugin whose only
defect was a missing `author` field, which stopped `check` before `wiring` ran.

Findings emitted by claudevs' own checkers across the corpus:

```
   3 error matchers
  34 error refs
  77 warn invocations
```

All three `matchers` errors are `unknown hook event `Stop``. All 34 `refs` errors point into Markdown
files, none at a wiring site. All 77 dead-file warnings are `.py` (67) or `.sh` (10).

Three of the five wiring failures are official Anthropic plugins. `hookify`:

```
  FAIL  wiring
          warn   invocations  core/__init__.py  `__init__.py` is referenced by nothing in this plugin
          warn   invocations  core/config_loader.py  `config_loader.py` is referenced by nothing in this plugin
          warn   invocations  core/rule_engine.py  `rule_engine.py` is referenced by nothing in this plugin
          warn   invocations  hooks/__init__.py  `__init__.py` is referenced by nothing in this plugin
          warn   invocations  matchers/__init__.py  `__init__.py` is referenced by nothing in this plugin
          warn   invocations  utils/__init__.py  `__init__.py` is referenced by nothing in this plugin
          error  matchers  hooks/hooks.json  unknown hook event `Stop` (known: PreToolUse, PostToolUse, UserPromptSubmit, SessionStart, SessionEnd)
        1 error, 6 warnings
```

Those modules are imported — `hooks/pretooluse.py:26` reads
`from hookify.core.config_loader import load_rules`. The reference never spells `config_loader.py`,
which is the same root cause as the known Lua `require("lib.globs")` case.

`obra/superpowers` (279k stars) collects 3 errors and 13 warnings, all false:

```
          error  refs  RELEASE-NOTES.md:425  `${CLAUDE_PLUGIN_ROOT}/lib/brainstorm-server/` does not exist
          error  refs  docs/superpowers/plans/2026-02-19-visual-brainstorming-refactor.md:474  `${CLAUDE_PLUGIN_ROOT}/lib/brainstorm-server/frame-template.html` does not exist
          error  refs  docs/superpowers/plans/2026-02-19-visual-brainstorming-refactor.md:475  `${CLAUDE_PLUGIN_ROOT}/lib/brainstorm-server/helper.js` does not exist
```

`RELEASE-NOTES.md:425` sits under a heading whose own text reads "All
`${CLAUDE_PLUGIN_ROOT}/lib/brainstorm-server/` references replaced with relative `scripts/` paths" —
claudevs is flagging a changelog entry announcing the removal as a broken reference. The 13 warnings
are that plugin's own `tests/` scripts; the test-file exemption covers only claudevs' own case-file
naming convention.

Thirteen of the 34 `refs` errors are inside
`skills/plugin-authoring/schemas/hooks-schema.md`, a document that teaches hook authoring:

```
error  refs  skills/plugin-authoring/schemas/hooks-schema.md:42  `${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh` does not exist
error  refs  skills/plugin-authoring/schemas/hooks-schema.md:88  `${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh` does not exist
error  refs  skills/plugin-authoring/schemas/hooks-schema.md:120  `${CLAUDE_PLUGIN_ROOT}/scripts/auto-approve.sh` does not exist
```

The paths are illustrative examples in a schema document.

### Report evidence is asymmetric

`judge` in `harness/verdict.rs` interpolates `observed.context` and `observed.decision` into mismatch
messages but never `observed.stdout` or `observed.stderr`. A `context:` failure is diagnosable at a
glance:

```
        context: expected to contain `STATUS: the airsl runtime was not found`, got Some("Reminder: run /claudestacks:snapshot-load for the current git branch to rehydrate relevant project memory before starting work.")
```

A `stdout:` failure is not, and "printed something different", "printed nothing", and "never ran"
become indistinguishable:

```
        stdout: expected to contain `run /claudestacks:journal-capture`
```

`--json` carries no more than the rendered form:

```json
{
  "outcomes": [
    {
      "name": "zz-deliberately-wrong",
      "verdict": {
        "Fail": [
          "exit: expected 3, got 0",
          "stdout: expected to contain `run /claudestacks:journal-capture`"
        ]
      }
    }
  ],
  "native": []
}
```

### Missing decision shapes

`harness/semantics.rs` sets `observed.decision` from exactly two sources:
`hookSpecificOutput.permissionDecision` and `PreToolUse` exit 2. The Claude Code hooks guide states
that "`PostToolUse` and `Stop` hooks use a top-level `decision: \"block\"` field, while
`PermissionRequest` uses `hookSpecificOutput.decision.behavior`", neither of which is read. The same
guide states that stdout is injected as context for `UserPromptSubmit`, `UserPromptExpansion`, and
`SessionStart`; `semantics.rs` gates that branch on `SessionStart` alone.

The four values `semantics.rs` maps for `permissionDecision` — `allow`, `deny`, `ask`, `defer` — were
verified correct and complete against the documentation, and are not a defect.

### No correlated regression

```
$ git log --oneline -12 -- crates/claudevs/src/harness/ crates/claudevs/src/wiring/ crates/claudevs/src/suite.rs crates/claudevs/src/types/hook_event.rs
d6fa4a6 fix(repo): stop the enforcement hook swallowing subagent tool calls (#48)
4c623e3 feat(claudevs): wiring checkers, the check gate, installed-layout simulation, and doctor (#47)
695a7a4 feat(claudevs): phase 1 verify core — deterministic plugin test harness and CLI (#46)
```

Every defect above dates to the originating feature commits. Nothing regressed.
