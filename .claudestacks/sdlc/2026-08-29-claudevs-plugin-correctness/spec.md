---
status: approved
created: 2026-08-29
amended: 2026-08-30
---

# Spec: claudevs answers to the plugin contract, not to this repository's plugins

`claudevs` currently encodes what a Claude Code plugin is by looking at the five plugins in this
repository. This spec makes it answer to the published plugin contract instead, so that a verdict it
returns about a plugin nobody here wrote can be trusted: no passing result that was not earned, no
reported finding that is not real, and no cosmetic obstacle between a plugin and a verdict. It also
settles, before publication freezes the answer, which parts of the public surface are allowed to grow.

Where this spec's findings contradict the intent's Evidence, §1 and §4.1 say so at the point of
contradiction. Two claims in that Evidence did not survive re-checking.

## Amendments — 2026-08-30

Four claims about the Claude Code hooks reference were wrong, and were corrected while plan 01 was
being executed. They originated in research done through a summarizing fetch tool, which truncates a
long page and invents plausible content past the cutoff; the corrections come from the raw markdown of
`code.claude.com/docs/en/hooks.md` (316,753 bytes) fetched with `curl` and grepped, so every one now
carries a line citation.

| § | Was | Is | Consequence |
|---|---|---|---|
| §1 | 31 documented events | **33** | catalogue length, and the test asserting it |
| §1, §3.5 | bare stdout is context for 3 events | **4** — adds `PostModelSwitch` | `hooks.md:786` |
| §1, §2.1 | the reference carries no per-event decision-control table | **it does**, `hooks.md:1011-1025`, covering all 33 | `DecisionMechanism` is twelve variants with no `Unspecified`, not four plus one |
| §2.2 | one exact-match character set for all events | `FileChanged` and `StopFailure` use a **narrower** one, `hooks.md:301` | matcher evaluation takes the event, not only the value |

The third is the one that changed a design rather than a number: §2.1's enum was shaped around a column
that would be almost entirely `Unspecified`, on a premise one fetch of the page disproves.

Anything in §3 through §7 not touched above was audited separately against the same artifact. Claims
about `claudevs`' own source and about the corpus sweep are internal and were not part of that audit.

## 1. Design premises

Four things were measured rather than assumed, and the design rests on them. The second and third trace
to the intent's Evidence. The first, and part of the fourth, are fresh measurements taken while writing
this spec; they are recorded here in full, since nothing upstream carries them. The fourth closes with a
correction to the intent.

**A `--strict` failure and a plain failure report the same findings.** Over a checkout of
`mukiwu/muki-ai-plugins/plugins/figma-visual-reviewer`, one of the 156 roots §6's manifest will pin:

```
$ claude plugin validate <plugin>            $ claude plugin validate --strict <plugin>
⚠ Found 1 warning:                           ⚠ Found 1 warning:
  ❯ root: CLAUDE.md at the plugin root is      ❯ root: CLAUDE.md at the plugin root is
    not loaded as project context. …             not loaded as project context. …
✔ Validation passed with warnings            ✘ Validation failed (--strict treats warnings as errors)
exit=0                                       exit=1
```

Identical finding text; only the verdict line and exit code differ. `--strict` is `-Werror` over the
same findings, nothing more. So claudevs needs one invocation of the delegate, and restoring strictness
means restoring the delegate's own flag rather than re-deriving severity from its text.

**Warnings do not fail a wiring stage.** `crates/claudevs/src/wiring/finding.rs:43-46` is
`self.findings.iter().all(|finding| finding.severity == Severity::Warning)` — equivalent to "no finding
of `Severity::Error`" only while `Severity` (`finding.rs:11-16`) has exactly two variants. The 77
dead-file warnings across the corpus therefore blocked nothing; the 37 errors (34 `refs`, 3 `matchers`)
are what failed those plugins. Demoting a finding is a real fix, not a cosmetic one — but only inside
the wiring stage, which is the only stage that produces `Finding`s at all.

**The false findings have rules, not exceptions.** Each class was probed against the corpus for a
mechanical rule, and the rules were required to explain the whole population rather than the examples.
Both populations account exactly, and both leave exactly one survivor: 77 dead-file warnings partition
40 / 26 / 5 / 5 with one residual, and 34 `refs` errors partition 29 / 3 / 1 with one residual. §4 gives
each class and what survives it.

**The documentation answers more than this spec first credited.** Corrected during execution against
the raw reference; every citation below is a line in `code.claude.com/docs/en/hooks.md` fetched as raw
markdown rather than through a summarizing tool.

The hooks reference names **33** events (summary table, 33 rows) — not 31, as this section originally
said. It states verbatim which ten take no matcher — `UserPromptSubmit`, `PostToolBatch`, `Stop`,
`TeammateIdle`, `TaskCreated`, `TaskCompleted`, `WorktreeCreate`, `WorktreeRemove`, `MessageDisplay`
(`hooks.md:327`), `CwdChanged` (`hooks.md:319`) — adding at `hooks.md:351` that "If you add a `matcher`
field to an event without matcher support, it is silently ignored."

It states that bare stdout is injected as context for **four** events, not three (`hooks.md:786`): "The
exceptions are `UserPromptSubmit`, `UserPromptExpansion`, `SessionStart`, and `PostModelSwitch`, where
Claude Code adds plain-text stdout as context that Claude can see and act on."

It **does** carry a per-event decision-control table, at `hooks.md:1011-1025`, under
`#### Decision control`. This section originally recorded the opposite — that the guide links a
reference section absent from the page — and that error shaped §2.1. The table assigns all 33 events to
one of twelve patterns, so there is no event whose decision mechanism the documentation leaves
unstated.

What remains true is the principle: where the documentation is silent, the contract table records that
and produces no finding from it. Inventing a rule to fill a gap would recreate the defect this chain
exists to remove, one layer down. It simply turns out that, for the decision column, there is no gap.

**This corrects the intent on `SessionEnd`.** The intent's Evidence describes a probe carrying "bogus
matchers on `UserPromptSubmit` and `SessionEnd` — both of which the runtime would ignore". Only the
first is true. The matcher table gives `SessionEnd` a matcher row — "why the session ended", values
`clear`, `resume`, `logout`, `prompt_input_exit`, `other` — and `SessionEnd` does not appear in the
matcher-less list quoted above. §4.3's new warning is therefore correct to fire on one of that probe's
two matchers, not both, and the regression test written from that probe must expect one finding. The
probe's underlying point stands: claudevs raised nothing for either.

## 2. The contract module

A new module owns what Claude Code specifies. Every other component reads from it and states no plugin
knowledge of its own.

```
crates/claudevs/src/contract/
  mod.rs        export-only (unit-test-mandate exemption #1)
  event.rs      the documented event catalogue
  matcher.rs    how a matcher value is evaluated against a payload
  handler.rs    the hooks.json handler-entry shape
  site.rs       what counts as a wiring reference site
```

### 2.1 `contract::event`

The catalogue is data keyed by event name, carrying three facts per event: its matcher support, which
decision mechanism its output may use, and whether bare stdout is injected as context.

Matcher support is not a boolean. For the ten events that take none it is absent; for every other event
it names **the path into the payload that the matcher is compared against** — the field, not a prose
description of it. The documentation gives that column as English ("tool name", "why the session ended",
"agent type"), and dispatch (§3.3) cannot act on English. Turning each row into a concrete payload path
is a translation step the plan performs once, per event, against the matcher-patterns table; where the
table's subject cannot be resolved to a payload field, the row records that and dispatch treats the
event as unfiltered rather than guessing.

The decision mechanism transcribes the reference's `#### Decision control` table (`hooks.md:1011-1025`)
into twelve variants — `TopLevelDecision`, `ExitCodeOrContinueFalse`, `ExitCodeOrTopLevelDecision`,
`PermissionDecision`, `PermissionDecisionOrTopLevelDecision`, `DecisionBehavior`, `Retry`, `PathReturn`,
`ElicitationAction`, `DisplayContent`, `ContextOnly`, `NoDecisionControl`.

This section originally specified a four-state value plus an explicit `Unspecified`, on §1's premise
that the reference carried no such table. It does, and it covers all 33 events, so there is deliberately
**no `Unspecified` variant**: a value meaning "the documentation is silent" would have no rows. Note the
distinction the enum has to keep — `NoDecisionControl` means the reference states this event has no
decision control, which is a documented fact a checker may act on, not an absence of information.

An event whose decision shape changes in a later Claude Code release becomes a one-line table edit. The
principle the original `Unspecified` protected still stands and is now enforced by the type: no checker
may emit a finding from an unstated fact, and there is no way to spell one.

The catalogue deliberately does **not** carry a "can claudevs simulate this?" fact. That would be the
same fact in two places, and §2.3 already answers it: an event is simulatable exactly when
`types::HookEvent` has a variant for it. The catalogue describes Claude Code; `HookEvent` describes
claudevs' own reach, and neither derives from the other.

### 2.2 `contract::matcher`

A matcher is not a regex, and claudevs currently believes it is. `matchers.rs:51` runs
`regex::Regex::new(matcher)` on every matcher value it meets. The documentation defines two modes,
chosen by the characters in the value:

| Matcher value | Evaluated as |
|---|---|
| only letters, digits, `_`, `-`, spaces, `,` and `\|` | exact string, or a list of exact strings separated by `\|` or `,`, surrounding whitespace optional |
| contains any other character | JavaScript regular expression, **unanchored** |
| `"*"`, `""`, or omitted | match all |

Two consequences, and the current code gets both wrong. `Edit|Write` and `a, b` are *lists of exact
strings*, not patterns — treating the second as a regex matches the literal `a, b` and nothing else. And
the regex path is JavaScript's, tested with `RegExp.prototype.test`: a pattern using lookahead is valid
there and rejected by Rust's `regex` crate, so claudevs would report ``matcher `…` does not compile as a
regex`` against a plugin that is correct. No plugin in the 156 triggers that today — it is latent rather
than observed — but it is the rule dispatch has to be built on, so it is settled here rather than
discovered later.

One module owns evaluation, and both callers use it: dispatch (§3.3) to decide which group a payload
routes to, and the checker (§4.3) to decide whether a matcher is well-formed. A checker that validated
matchers by one rule while dispatch routed by another would be the same class of split-brain the
contract module exists to prevent.

Unanchored is preserved: `Edit.*` matches `NotebookEdit`, per the documentation's own example. claudevs
does not tighten it.

**The exact-match set is not the same for every event**, which this section originally missed.
`hooks.md:301`: "`FileChanged` and `StopFailure` use a narrower exact-match set of letters, digits, `_`,
and `|` only. A hyphen, space, or comma in a matcher for those two events keeps it on the
regular-expression path, and only `|` separates alternatives. Every other event uses the wider set." So
evaluation takes the event as well as the value — a `StopFailure` matcher of `code-reviewer` is an
unanchored regex that also fires for `senior-code-reviewer`, where the same value on any other event is
one exact string. The table above describes the wider set, which covers the other 31 events.

Two further facts the reference states and this module records but does not act on. Comma separators
and surrounding-whitespace tolerance require Claude Code v2.1.191 or later, and hyphens in the wider
exact set require v2.1.195 or later (`hooks.md:297`, `:299`); claudevs models current behaviour only.
And `FileChanged`'s matcher has a second role when building its watch list — split on `|`, each segment
a literal filename, regex not meaningful (`hooks.md:2791`) — which is a different mechanism from the
filtering matcher this module parses.

### 2.3 Two event types, deliberately

`types::HookEvent` and the `contract::event` catalogue model different things and both are kept, which
the modularity rule permits for look-alikes carrying different invariants — each documents the
distinction in its own doc comment.

- `types::HookEvent` is **the events claudevs can simulate**: those for which `harness/payload.rs` can
  synthesize a payload and `harness/semantics.rs` can interpret a result.
- The catalogue is **the events Claude Code documents**, all 31.

Collapsing these into one type is what produced the `Stop` false error. `Stop` is documented, so
`claudevs check` must not reject a plugin for using it; `Stop` is not simulatable, so `claudevs test`
genuinely cannot run a case against it. One type cannot hold both answers, and the intent's non-goal on
widening `HookEvent` for completeness stands: `HookEvent` is not widened, it simply stops being asked a
question it was never the right type to answer.

`HookEvent` gains `#[non_exhaustive]` under the §7 rule.

### 2.4 `contract::handler`

The `hooks.json` handler entry becomes `HookCommand`, a two-variant enum, rather than a command string:

- `Shell(String)` — `command` alone; run through `sh -c`, as today.
- `Exec { program, args }` — `args` present; `command` resolved as an executable and spawned directly
  with `args` as the argument vector, no shell.

The documentation is explicit that these are different execution models ("There is no shell, so each
`args` element is one argument exactly as written … No shell tokenization happens on any platform"), so
they are different variants, not a flag on one shape.

`HookCommand` carries a display form used wherever a handler has to be shown or matched as text — the
`hook:` substring filter (§3.3) and failure messages (§3.6). For `Shell` it is the command string; for
`Exec` it is `program` joined with `args` by single spaces. One method, one definition, so the filter
and the report can never disagree about what a handler is called.

**A handler claudevs does not model is skipped, never a parse error.** `hooks_file.rs:40` reads
`entry.get("command")` with no `type` check at all today, so a `type: "prompt"` entry is passed over by
accident. Once the entry is parsed into an enum that behaviour has to be chosen, and it is chosen the
same way: an entry whose `type` is not `command` is skipped silently, and an entry claudevs cannot parse
is skipped rather than failing the file. §8 makes the other handler types a non-goal, and a non-goal
that turns into a hard error would be a new false failure on exactly the third-party plugins this chain
is about.

### 2.5 `contract::site`

One place answers "is this a wiring reference site?", consumed by `wiring::refs` (§4.1). It decides
three things: whether a file is one Claude Code loads (§4.1 item 2), whether a position within that file
is load-bearing or illustrative (item 1), and where a reference ends (item 3). It does not attempt item
4, which §4.1 and §8 both put out of reach of a rule.

## 3. The run path — earning the verdict

### 3.1 `output: none` becomes falsifiable or is refused

`Observed.emitted` is set only by `harness/semantics.rs`, which runs for hook observations.
`suite.rs:224-232` builds a script/flow `Observed` from `..Observed::default()`, so `emitted` is always
`false` and `verdict.rs:45` can never fire. The assertion reads as real and passes unconditionally:

```
  FAIL  a-output-none                 hook case, emitting hook       → correct
  ok    c-script-output-none          script case, `echo` output     → vacuous
```

The fix is at case load, not at judgement time: `expect.output` is refused for any case kind whose
observation cannot populate `emitted`, with a named load error. This follows parse-don't-validate — an
assertion that cannot fail should not be constructible, rather than being silently skipped later.

Asserting that a *script* produced no output is a legitimate thing to want. It is not added here: the
adoption chain owns negative assertions and the case-authoring vocabulary, and adding a second spelling
of the same idea in two chains at once is how a duplicate type gets born.

### 3.2 `args` is honoured

`harness/hooks_file.rs:40` reads `command` and nothing else; `harness/spawn.rs:120` unconditionally
builds `vec!["sh", "-c", command]`. A hook declaring
`{"type": "command", "command": "sh", "args": ["-c", "echo …"]}` therefore runs `sh -c sh`, silently.

`hooks_file` parses into `contract::handler::HookCommand`, and `spawn` dispatches on the variant. The
existing shell wrap becomes one arm rather than the only path. Nothing about `Shell` behaviour changes.

### 3.3 Dispatch respects matchers

`resolve` in `harness/hooks_file.rs` flattens every group's commands and never reads `matcher`;
disambiguation is a substring match on the command string. A case can therefore pair an event with a
payload the runtime would route elsewhere, and be told it passed.

`resolve` filters groups by matcher against the payload before flattening. It reads the payload path
from the catalogue (§2.1) and compares with `contract::matcher` (§2.2) — the same evaluator the checker
uses, so a matcher claudevs calls well-formed and a matcher claudevs routes by can never diverge. The
`hook:` substring stays as a secondary filter, applied to `HookCommand`'s display form (§2.4), for a
plugin wiring several commands behind one matcher.

**The filter mirrors the runtime, including where the runtime ignores the matcher.** For an event in
the matcher-less ten, the documentation is explicit that a matcher "is silently ignored", so `resolve`
ignores it too and every group for that event matches. `UserPromptSubmit` is both in that ten and one of
the five simulatable events, so this is a live path, not a hypothetical — and §4.3 exists precisely
because plugins do write matchers there. Filtering on a matcher the runtime discards would invent a
mismatch that cannot happen in production, which is the same class of untruth as the false pass it
replaces. Where the catalogue does not name what a matcher is matched against, `resolve` ignores it on
the same principle: claudevs never guesses a routing rule the documentation does not state.

Both no-match paths converge on the same outcome. Today they differ: a case whose event resolves to
nothing already returns an `Error` from `resolve` (`hooks_file.rs:64-71`, test
`zero_matches_is_an_error_naming_the_event`), which `crates/claudevs-cli/src/cli.rs:95-107` turns into
exit 2 for the whole run, while a case whose *matcher* does not match passes. Both become one failed
case, naming the event and matcher and listing what the plugin does wire for that event — consistent
with §5's treatment of an unloadable case, and for the same reason: one bad case should not be able to
decide the fate of the others.

### 3.4 The default payload describes a real project

`harness/payload.rs` `default_payload` sets `cwd` and `tool_input.file_path` to a bare temp directory.
The intent names three absences, not two — no git repository, no `Cargo.toml`, no registry record bound
to it — and its worked example turns on the third: the case "would pass identically … if the registry
were empty". Hooks that branch on project state take their silent branch, so a case passes exactly as
well when the hook is broken or its runtime is missing.

Two of the three are closed. The synthesized project becomes git-initialised with a tracked file and
carries a manifest, and `tool_input.file_path` points at a path that exists inside it. Only the git half
is existing machinery — `harness/project.rs:48-51` already runs `git init` plus one commit behind the
`.gitinit` fixture marker; the manifest is new and cheap.

**The registry record is deliberately not bound, and this spec does not change that.** A synthetic
`installed_plugins.json` already exists: `layout/installed.rs:63-80` writes a `version: 2` record keyed
`<plugin>@<marketplace>` with an `installPath`, covered by `installed.rs:162`
(`the_synthetic_registry_keys_the_record_the_way_the_real_one_does`). What does not exist is any way for
a child process to find it, and that too is a recorded decision — `installed.rs:11-14`:

```
//! The registry is written for shape fidelity alone — nothing in the engine
//! reads it back, and no environment variable is invented here to point a child
//! at it.
```

Binding it means pointing a hook at a registry other than the developer's real one, and Claude Code
offers no variable whose documented purpose is that. `CLAUDE_CONFIG_DIR` relocates the whole
configuration tree, which is a far broader lever than this needs; it is also the mechanism the
plugin-cache-hygiene chain is built on, and that chain is a non-goal here (§8). Reaching for it from
this chain would be borrowing a sibling chain's design decision without owning it.

So the intent's third absence stays open, named rather than quietly dropped: a hook that consults the
plugin registry is still exercised against whatever registry the developer's machine has. §3.6 is what
makes that survivable — a failure that shows the payload the hook was given, and the stdout and stderr
it produced, is one an author can diagnose. §3.4 narrows the hazard; it does not eliminate it, and a
case can still assert too little.

### 3.5 The missing decision shapes

`harness/semantics.rs` sets `observed.decision` from exactly two sources — `permissionDecision` and
`PreToolUse` exit 2 — and gates bare-stdout context injection on `SessionStart` alone. Both are
corrected against the catalogue: the top-level `decision: "block"` field (`hooks.md:1013`) and
`hookSpecificOutput.decision.behavior` (`hooks.md:1018`) are read, and stdout-as-context is keyed off
the catalogue's flag, which the documentation sets for **four** events — `UserPromptSubmit`,
`UserPromptExpansion`, `SessionStart` and `PostModelSwitch` (`hooks.md:786`). This section originally
named only the first three; the mechanism is unaffected, since it reads the catalogue rather than a list
written here, but a reader working from the old sentence would have expected three.

Reading the decision from the catalogue now means reading one of twelve mechanisms rather than the four
this spec first assumed — see §2.1. The mechanisms `TopLevelDecision`, `PermissionDecision`,
`DecisionBehavior` and the exit-code pair are the ones this section's correction depends on; the rest
exist because the reference states them.

The four `permissionDecision` values `allow` / `deny` / `ask` / `defer` were verified correct and
complete against `hooks.md:1016`. They are not touched.

### 3.6 Failures carry their evidence

`verdict.rs` interpolates `observed.context` and `observed.decision` into mismatch messages but never
`observed.stdout` or `observed.stderr`, so a `stdout:` failure cannot distinguish "printed something
different" from "printed nothing" from "never ran". `--json` carries no more than the rendered text,
because `Verdict::Fail` is a `Vec<String>`.

`Verdict::Fail` carries a `Vec<Mismatch>`, a typed enum with one variant per assertion, each holding
what was expected and what was observed. Rendering derives the human sentence from it, and `--json`
gains structure a consumer can act on rather than prose it must parse. This is a public API and report
shape change, which is free before publication and expensive after.

A failing case also reports **what the hook was given and what was run**: the synthesized payload, and
the handler resolved for it in `HookCommand`'s display form (§2.4) — which for an `Exec` handler is the
argv actually spawned, the thing §3.2's defect made invisible. §3.4 depends on this. A default payload
that is more realistic still cannot tell an author *which* branch their hook took; the payload and the
argv, printed beside the mismatch, can.

## 4. The static checkers — every finding real

### 4.1 `wiring::refs`

`refs.rs:60` walks the plugin and reads every UTF-8 file, skipping only files that are not UTF-8
(`refs.rs:72-73`). The 34 `refs` errors across the corpus partition into four classes, and three of them
are distinct defects:

1. **Position — 29 of 34.** The cited line sits inside a fenced code block. A schema document that
   teaches hook authoring cites `${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh` inside a ` ```json ` block
   as an example; that is the document doing its job. Fenced blocks are illustrative, not load-bearing.
2. **Scope — 3 of 34.** The file is not one Claude Code loads. Only `.claude-plugin/*.json`, `hooks/**`,
   `skills/**`, `agents/**` and `commands/**` are scanned; a plugin's `README`, `RELEASE-NOTES`,
   `CHANGELOG` and `docs/` tree are not wiring. All three are `obra/superpowers`, and one of them is a
   changelog entry announcing the very removal it is being blamed for.

   The scanned set is `hooks/**`, not `hooks/hooks.json`. A hook script is executed by Claude Code, so a
   `${CLAUDE_PLUGIN_ROOT}` path inside one is as load-bearing as a reference gets. This class is empty
   in the corpus — every occurrence inside a hook script across the 156 is a comment or an
   `os.environ.get('CLAUDE_PLUGIN_ROOT')`-style env read, not a path — so widening costs no measured
   finding. It is widened anyway, because this rule is the thinnest-evidenced in §4 (three findings,
   one repository) and the narrow version would stop checking a category nothing measured.
3. **Extraction — 1 of 34.** `anthropics/ralph-wiggum` declares
   `allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)"]` in command
   frontmatter, and claudevs reports `…/setup-ralph-loop.sh:*` does not exist. The script exists and is
   executable; the `:*` is Claude Code's tool-argument matcher and claudevs swallowed it into the path.
   Reference extraction has to know where a reference ends — this is a wiring site claudevs is right to
   check and wrong about, which neither of the cuts above would fix. **This corrects the intent**, whose
   Evidence reads "All 34 `refs` errors point into Markdown files, none at a wiring site": command
   frontmatter is a wiring site, and this one is in it.
4. **Accepted residual — 1 of 34.** A "Red Flags" list in `skills/plugin-authoring/SKILL.md` writes
   "**USE** `${CLAUDE_PLUGIN_ROOT}/scripts/format.sh`" as prose advice: an in-scope file, outside a
   fence, illustrative anyway. Separating this from a real reference needs authorial intent, not a rule.
   It stays reported, and the spec claims one false positive across 156 plugins rather than zero.

References in scanned files outside fences stay errors. That class is real: a skill body pointing at a
script that does not exist is broken wiring, and it is how the skills in this repository refer to their
own files — in prose, not in fences. That is also why the residual is accepted rather than ruled out by
demoting prose references: doing so would demote the true-positive class along with it.

Fenced blocks are skipped *here* and read elsewhere, which is not a contradiction. `refs` asks "does
this path exist?", and an example path in a fence is not claiming to. `invocations` asks "is this file
referenced by anything?", and a command inside a fence is evidence that it is — `invocations.rs:183-190`
already reads fenced commands for exactly that. The two checkers ask different questions of the same
text and are right to treat it differently; each says so in its module doc.

### 4.2 `wiring::invocations`

`invocations.rs:138` exempts only files matching claudevs' own case-file naming. Four exemptions
replace it, each explaining a measured share of the 77 dead-file warnings:

1. **The plugin's own `tests/` directory**, whatever the file is named. A plugin's tests are not wired
   into the plugin, and claudevs' convention is not the only one. (40 of 77.)
2. **Files whose bare stem is referenced** even when the filename is not. Module systems import by
   stem: `from hookify.core.config_loader import load_rules` never spells `config_loader.py`, and Lua's
   `require("lib.globs")` never spells `globs.lua`. All three matching paths compare against the
   filename *with* its extension — the two inside `mentions` (`invocations.rs:183-190`) and the direct
   `other_text.contains(name)` beside it in `check` (`invocations.rs:144-145`) — so none can see a stem
   reference today, and the fix has to reach all three. (26 of 77.)
3. **Language index files**, referenced by importing their directory rather than by name. Only
   `__init__.py`, `index.js` and `init.lua` — one per scanned language. `mod.rs` is not in the list:
   `invocations.rs:111` is `const SCRIPT_EXTENSIONS: [&str; 4] = ["sh", "lua", "py", "js"]`, so a `.rs`
   file is never a candidate and the entry would be dead. Only `__init__.py` is backed by the corpus
   (all 5 occurrences); `index.js` and `init.lua` are the same convention in the other two scanned
   languages and are included on that basis, not on measurement. (5 of 77.)
4. **Files that do not present as executable** — no shebang and no executable bit — outside `hooks/`.
   Sample material a skill ships for reading is not dead wiring. (5 of the 6 residual.)

The check stays a warning. After calibration it emits one finding across 156 real plugins — a shebanged
`optimize-prompt.py` under `scripts/` that nothing references — which is the thing the check was for.

### 4.3 `wiring::matchers`

`matchers.rs` knows five event names and checks only that the name parses and the matcher compiles as a
regex. It reads the catalogue and `contract::matcher` instead:

- A documented event produces no finding. `Stop` stops being an error.
- An undocumented event name produces a **warning**, not an error. claudevs' catalogue can lag a Claude
  Code release; a plugin using a newer event than claudevs knows about is not thereby broken.
- A `matcher` on one of the ten events that take none produces a new warning. The documentation states
  such a matcher "is silently ignored", so the author's intent is not being served — a finding claudevs
  cannot make today at all.
- Well-formedness is judged by `contract::matcher` (§2.2), not by `regex::Regex::new`. A value on the
  exact-string path is never compiled, so `a, b` stops being read as a pattern. A value on the regex
  path is JavaScript-flavoured, so the check cannot simply be "does Rust's `regex` crate accept it" — a
  pattern Rust rejects and JavaScript accepts is a plugin claudevs must not fail. Where the two
  dialects diverge the finding is a warning naming the divergence, not an error.

## 5. The gates — nothing blocks a verdict for a cosmetic reason

**`validate.rs:72` drops `--strict` from the delegate argv.** That is the whole change. `claude plugin
validate` runs plain, once; on a plugin whose only defect is a missing `author` field it exits 0, so
`Validation::Passed` and `StageStatus::Passed` follow with no further work. This alone is what rejected
35 of 156 plugins, none of which had a defect that would stop them working.

Nothing parses the delegate's human output into `Finding`s. `Validation` (`validate.rs:19-35`) carries
an opaque `output: String` and `validation_stage` (`check.rs:122-140`) maps it straight to a
`StageStatus` with that text as `detail`; the wiring stage's severity machinery
(`finding.rs:43-46`) does not reach it and is not extended to. Re-deriving severity from prose the
delegate is free to reword would be exactly the kind of unearned inference this chain removes.

**`claudevs check --strict` restores the delegate's flag.** It is a passthrough: it puts `--strict` back
into the argv and changes nothing else. It therefore promotes the validate stage's warnings only, and
never the wiring warnings §4 just decided not to fail on — the two are different mechanisms and the flag
touches one of them. The flag surfaces in `crates/claudevs-cli/src/cli.rs`, where `Check` takes only
`--json` and a path today; this is the one place the intent scopes that crate to.

**`check.rs:87,101,110` lose their early returns.** All four stages run and the report aggregates.

The manifest classification does **not** change. `check.rs:145-149` already reasons about this case in
writing — a malformed `plugin.json` "is deliberately not among" the environment gaps, "that is a plugin
defect, and skipping it would let a plugin that cannot be installed pass the gate on any machine where
the `claude` delegate is absent and the validation stage already skipped" — and `check.rs:172-175` maps
`Error::Manifest` to `StageStatus::Failed` accordingly. That reasoning is sound and describes the same
false-green class this chain exists to close, so it stands. Removing the early returns means later
stages *run* after an earlier failure; it does not mean a plugin defect is reclassified as a skip.

**`suite.rs:80-81` filters before loading.** Case selection currently loads every case file and then
tests whether it was wanted, so one unloadable file aborts the whole suite with exit 2 — including cases
the user asked for by name. Selection happens first, and a load failure becomes one failed case named
for its file rather than the death of the run.

This last item is the one change in §5 with no measurement behind it, and the spec says so rather than
implying otherwise. The corpus sweep could not have surfaced it: it needs a plugin that ships case
files, and neither this repository nor any of the 156 does. It is a generalisation of the intent's
"nothing stops `claudevs` reaching a verdict for a cosmetic reason" from the validate gate, where that
sentence was measured, to the case loader, where the same shape of obstacle exists — and it was observed
directly while probing §3.1, where one deliberately invalid case file took its valid sibling down with
it. §3.3 depends on this decision, so if it is dropped, §3.3's convergence goes with it.

## 6. Testing

**Every fix is watched fail first.** Four of these defects are silent false greens, and a test that has
only ever been green is the instrument that missed them. Nothing here is complete on a passing test
alone.

**The four false-green fixes get paired-control tests.** Each pairs a case that was already honest with
the case that was vacuous, in one suite, so the test asserts the *difference* rather than an absolute. A
single-sided test would go green against the unfixed code, which is how these survived 201 tests.

| Fix | Control (already fails) | Formerly vacuous (must now fail) |
|---|---|---|
| §3.1 `output: none` | hook case against an emitting hook | script case against `echo` |
| §3.2 `args` | `Shell` handler asserting its own output | `Exec` handler whose `args` carry the only output that satisfies the assertion |
| §3.3 matchers | case whose matcher routes to the asserted hook | case whose matcher routes elsewhere |
| §3.4 payload realism | hook reaching its real branch on a realistic project | same case with the hook's runtime made unavailable |

The §3.4 pair is the one that differs in kind: it is not two cases but one case run twice, and it is the
only test here that asserts the *payload* did its job. If that case still passes with the runtime gone,
the payload is still driving the hook down its silent branch and the fix did not land.

**Unit tests are colocated** per the unit-test mandate. Every new logic-bearing file under `contract/`
ships `#[cfg(test)] mod tests`; `contract/mod.rs` is export-only and carries the exemption-#1 header.

**The third-party corpus is a standing check, outside the gate.**

```
crates/claudevs/tests/
  corpus.rs             #[ignore]d runner; `cargo make corpus-check` passes --ignored
  corpus/
    corpus.toml         13 repos × pinned sha, 156 plugin roots — written, committed
    expected.snap       one row per plugin root: stage outcomes + findings
```

**`expected.snap` is one row per plugin root, not a list of findings.** After §4 the whole corpus emits
roughly two findings, and a two-line snapshot cannot tell *correctly quiet* from *the checker panicked
and reported nothing* — which is the same blind spot as a test that has only ever been green, rebuilt
inside the mechanism meant to catch it. Each of the 156 rows carries the outcome of every stage
(`validate`, `wiring`, `test`, `test --installed`) plus any findings, so a checker going silent moves
156 rows and is impossible to miss.

`corpus.toml` already exists — 13 repositories pinned by commit, 156 plugin roots, written from the
2026-08-29 sweep before its clones were lost. Three of the roots are the repository itself rather than a
subdirectory, recorded as `"."`. The header carries the provenance those numbers depend on.

The runner is a normal integration test marked `#[ignore]` beside the existing `installed.rs`,
`verify_core.rs` and `wiring.rs`, so `cargo test` neither runs it nor fails when the corpus is absent,
and `cargo make corpus-check` reaches it with `--ignored`. `cargo make corpus-fetch` clones the pinned
SHAs into a gitignored directory under `target/`; it is the only step that touches the network and it
never runs in CI or in `cargo make dod`. The snapshot is what makes the corpus a check rather than an
exercise: a recalibration that silently reintroduces a false-positive class shows as a diff.

Pinning by SHA rather than vendoring keeps repository weight at zero (the alternative measured 7.3 MB
for the 14 finding-producing plugins, 19 MB for all 156), avoids relicensing thirteen upstream
repositories, and keeps the published `.crate` clear of the crates.io size ceiling. The cost is
accepted deliberately: a check nobody is obliged to run guards by convention, and the intent's own
constraint — no network access at test time, no live `git clone` in CI — is what forces that shape.
It is run before a release, not on every commit.

This is a second corpus, not a replacement for the first. `cargo make claudevs-check` runs the
hand-authored fixtures in `crates/claudevs/tests/fixtures/` in both directions and stays exactly as it
is: those fixtures pin the behaviour claudevs intends, and they are cheap and unskippable. The
third-party corpus answers the different question — whether that intent survives contact with plugins
nobody here wrote. Task naming follows the existing `<thing>` / `<thing>-<verb>` convention in
`Makefile.toml`.

## 7. The public type surface

The crate exposes 44 public enums and structs and carries exactly one `#[non_exhaustive]`, on `Error`
(`error.rs:13`). Publication freezes the rest. The rule, which the plan enumerates against:

- **`#[non_exhaustive]` on every public enum whose variant set is decided by Claude Code rather than by
  us.** `HookEvent` and the contract's decision-shape enum are the clear cases: Claude Code adds hook
  events, and a downstream `match` that breaks on a new one is a breakage we chose.
- **`#[non_exhaustive]` on every public struct callers only read** — reports, outcomes, findings,
  observations. Adding a field to a report should not be a major version.
- **`#[non_exhaustive]` on every public enum *we* decide that callers only read.** `Verdict`,
  `Validation`, `StageStatus`, `Severity`, and the `Mismatch` enum §3.6 introduces. `Mismatch` is the
  sharpest case and the reason this bullet exists: "one variant per assertion" means the variant set
  grows every time an assertion is added, so a downstream exhaustive `match` breaks on a change we make
  routinely. That the variants are ours rather than Claude Code's changes who adds them, not whether
  adding one is breaking.
- **`#[non_exhaustive]` on every caller-*constructed* config struct that implements `Default`.**
  `SuiteOptions` (`suite.rs:22-27`) is the one in the crate today: one public field, `Default` derived.
  This is the bullet that looks backwards and is not. Leaving it open lets callers write
  `SuiteOptions { case_filter }` as a literal, and then the next field this chain or the adoption chain
  adds is a breaking change. Closing it routes construction through `Default::default()` plus field
  assignment, after which adding a field is not. The requirement is `Default`; a config struct without
  one would be left open and given a builder instead.
- **Exempt: newtypes with one validated field, and their error structs.** The invariant is the whole
  type; there is nothing to add.

The plan enumerates all 44 against these five and records the bullet each lands on, so the audit is
reviewable rather than asserted. A type fitting none of them is a signal the rule is short a bullet —
raise it rather than deciding that type by hand.

## 8. Non-goals

- The adoption path for an existing plugin: the adoption skill, the case-format documentation, and the
  case-model fields (`env` on hook cases, setup/teardown, negative assertions). Separate chain,
  sequenced after this one. In particular, an assertion that a *script* produced no output belongs
  there, not in §3.1.
- Plugin cache staleness and dead registry entries. Separate chain, and §3.4 stays out of it: the
  synthetic registry keeps the shape-fidelity-only role `installed.rs:11-14` gives it, and no mechanism
  is invented here to point a hook at it.
- Widening `types::HookEvent` toward all 33 events. §2.3 makes that unnecessary rather than deferring
  it.
- Simulating events claudevs cannot synthesize a payload for. Recognising `Stop` in `check` is in
  scope; running a `Stop` case is not.
- Inferring a decision mechanism the reference does not state. This was written as a non-goal on the
  premise that the reference had no per-event decision-control table; it has one, at
  `hooks.md:1011-1025`, covering all 33 events, so nothing is inferred and the catalogue has no
  `Unspecified` variant to spell. The non-goal survives as a rule for the next release that adds an
  event: transcribe what the table says, or leave the row out — do not reason from what a similar event
  does.
- Reaching zero `refs` false positives. §4.1's fourth class needs authorial intent to resolve; one in
  156 is the target, not none.
- Prompt-based, agent-based, `http` and `mcp_tool` hook handler types. `contract::handler` models
  `type: command` only.
- Anything in `crates/clauders`.
