# claudevs architecture

## Two crates

`claudevs-cli` builds the `claudevs` binary. It is the only crate in the pair that depends on `clap`
— its command-line grammar and dispatch live in one file, and nothing else in the pair parses
arguments. `claudevs` is the engine that crate calls: everything the binary does, from running a
suite to rendering a report, is a call into a public function this crate exports.

## Module map

Every module `claudevs` declares from its crate root, public or private, with one line from its own
module doc:

| Module | Visibility | What it is |
|---|---|---|
| `case` | public | The case model and its front-ends. |
| `check` | public | `claudevs check`: the one gate a plugin passes or fails. |
| `contract` | public | What Claude Code specifies about plugin hooks. |
| `doctor` | public | `claudevs doctor`: what this environment can and cannot do. |
| `harness` | public | The execution harness: spawning hooks and scripts the way the Claude Code runtime would, and judging what they produced. |
| `layout` | public | Simulating the shape a plugin has once installed. |
| `types` | public | Validating newtypes for claudevs domain values. |
| `validate` | public | Delegating manifest validation to the `claude` binary. |
| `wiring` | public | Static wiring checks: no execution, one finding list. |
| `error` | private | The crate's error type. |
| `native` | private | Native suites a plugin declares outside the case model, in `claudevs.toml`. |
| `report` | private | Rendering a suite report, a check report, or a doctor diagnosis for people and for machines, and their exit codes. |
| `suite` | private | Running a plugin's suite: discovery, per-case execution, report data. |

The four private modules are reached only through the crate root's own re-exports, never through
their own path. That root re-exports `CheckReport`, `Stage` and `StageStatus` from `check`;
`Diagnosis`, `Probe` and `ProbeStatus` from `doctor`; `Error` and `Result` from `error`; `Mismatch`
and `Verdict` from `harness`; `NativeOutcome` from `native`; `Report`, `check_exit_code`,
`doctor_exit_code`, `exit_code`, `render_check_human`, `render_doctor_human`, `render_human`,
`render_json` and `render_wiring_human` from `report`; `CaseOutcome`, `SuiteOptions`, `SuiteReport`,
`run_case`, `run_suite` and `run_suite_installed` from `suite`; `Strictness` and `Validation` from
`validate`; and `Finding`, `Severity` and `WiringReport` from `wiring`.

## From a plugin directory to a report

The engine's own flow, from a plugin directory to a report:

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

The binary wraps every entry point in that flow behind one subcommand each:

```text
claudevs test [--installed] ─► run_suite / run_suite_installed ─► render_human | render_json ─► exit_code
claudevs check              ─► check::run                        ─► render_check_human | render_json ─► check_exit_code
claudevs doctor             ─► doctor::run                       ─► render_doctor_human | render_json ─► doctor_exit_code
claudevs migrate            ─► case::migrate_to_lua              ─► stdout, or <stem>_test.lua
```

## Where to read next

- [`cli/explanation.md`](cli/explanation.md) — why the harness behaves as it does from a plugin
  author's side of the binary.
- [`engine/explanation.md`](engine/explanation.md) — how the same parts relate from a Rust caller's
  side of the library.
