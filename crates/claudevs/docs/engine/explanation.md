# How the claudevs engine fits together

## One type means a test case

YAML files and Lua data tables both deserialize into `RawCase` and become a
`Case` through `Case::from_raw`; nothing else in the crate models a case. A
case is one of three kinds — hook, script or flow. Expectations state
meaning, such as `decision: deny`, and the harness owns translating a run
into that meaning; a case never asserts an exit code where a decision is
what it means.

## The harness spawns, observes, then judges

A hook command without `args` runs through `sh -c`; one with `args` is
spawned directly, and a script's argv is always spawned directly. Every
spawn carries a 30-second timeout, and a killed child is never a pass.
`observe` reads a run under its event's rules; `judge` compares that
observation with the case's expectations and lists every mismatch rather
than stopping at the first. Cases run in temporary projects, never against
the plugin's own checkout.

## A failing plugin is a verdict, not an error

`Error` means claudevs itself could not produce a verdict — a case file that
does not load, or a fixture a case names that is not there, are two
examples. The full set is in the rustdoc rather than repeated here.

## Wiring reads files and never runs them

The three wiring checkers answer static questions about a plugin's files —
whether a reference resolves, whether a script is named by anything, whether
a matcher is one claudevs can evaluate — without spawning anything the
plugin ships.

## validate and layout reach outside the plugin

`validate` hands the plugin to `claude plugin validate` rather than
reimplementing the manifest checks that command already makes, and reports
`Unavailable` when `claude` cannot run at all. `layout` builds the installed
copy that the second suite stage runs its cases against.

## check and doctor compose the rest

`check` runs the four stages a plugin's gate needs; `doctor` runs one probe
per thing those stages need, so a gap it reports is exactly what would make
a stage skip or fail.

## Reports are data first

Human text and JSON both come from the same report structs; the sealed
`Report` trait limits `render_json` to the crate's own report types rather
than any `Serialize` value. Do not count how many report types there are —
that is exactly the kind of fact an ordinary change can shift.

## Two lists of hook events

`types::HookEvent` lists the events a case can run against; `contract::event`
catalogues the events Claude Code documents, which the wiring checkers read.
The two are separate on purpose: a documented event claudevs cannot yet
simulate is still one a plugin may legitimately wire.

## What `#[non_exhaustive]` means for a caller

Every public type carries it except the validated newtypes in `types`
(`CaseName`, `MarketplaceName`, `PluginName`, `PluginVersion`) and their
error structs, `InvalidHookEvent`, `case::Invocation` and `harness::TModule`.
Name them; do not count them.

A caller cannot build such a struct with a literal, so code starts from
`Default` where one exists and sets fields from there:

```rust
let mut options = claudevs::SuiteOptions::default();
options.case_filter = Some(String::from("blocks"));
assert_eq!(options.case_filter.as_deref(), Some("blocks"));
```

A `match` on such an enum needs a wildcard arm, because a variant the crate
adds later must not become a compile error at every call site:

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
