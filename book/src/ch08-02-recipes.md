# Recipes

These recipes are for a caller who has worked through [Your First Suite](ch08-01-first-suite.md).
Every path below is relative to the `claudevs` crate directory and names a plugin under `examples/`.
Each snippet starts in that directory.

## Produce a JSON report

`render_json` accepts a `SuiteReport`, a `CheckReport`, a `WiringReport` or a `Diagnosis`, and
nothing else. It produces the same JSON the `claudevs` binary prints with `--json`. The shape is in
the [CLI reference](appendix-01-claudevs-cli.md).

```rust
# std::env::set_current_dir(concat!(env!("CARGO_MANIFEST_DIR"), "/../claudevs")).unwrap();
use std::path::Path;

let report = claudevs::run_suite(
    Path::new("examples/01_hook_decision"),
    &claudevs::SuiteOptions::default(),
)?;
let json = claudevs::render_json(&report)?;
assert!(json.contains("\"outcomes\""));
# Ok::<(), claudevs::Error>(())
```

## Run only some cases

`SuiteOptions` is `#[non_exhaustive]`, so build it with `default()` and set `case_filter`. A case
runs when its name contains the filter. A YAML file is matched by its file stem before it is loaded,
and a Lua file's cases are matched by their entry name.

```rust
# std::env::set_current_dir(concat!(env!("CARGO_MANIFEST_DIR"), "/../claudevs")).unwrap();
use std::path::Path;

let mut options = claudevs::SuiteOptions::default();
options.case_filter = Some(String::from("blocks"));
let report = claudevs::run_suite(Path::new("examples/01_hook_decision"), &options)?;
assert_eq!(report.outcomes.len(), 1);
# Ok::<(), claudevs::Error>(())
```

## Run against the installed layout

`run_suite_installed` copies the plugin to `cache/<marketplace>/<plugin>/<version>/` in a temporary
directory. It runs the same cases with `CLAUDE_PLUGIN_ROOT` pointing there. It returns
`Error::Marketplace` when no ancestor directory holds a `.claude-plugin/marketplace.json`.

The
[`08_installed_broken` example](https://github.com/airsstack/claudestacks/tree/main/crates/claudevs/examples/08_installed_broken)
is a plugin that passes one call and fails the other.

```rust
# std::env::set_current_dir(concat!(env!("CARGO_MANIFEST_DIR"), "/../claudevs")).unwrap();
use std::path::Path;

let plugin = Path::new("examples/08_installed_broken");
let options = claudevs::SuiteOptions::default();
assert!(claudevs::run_suite(plugin, &options)?.all_green());
assert!(!claudevs::run_suite_installed(plugin, &options)?.all_green());
# Ok::<(), claudevs::Error>(())
```

## Run check from code

`claudevs::check::run(plugin_dir, strictness)` runs `validate`, `wiring`, `test` and
`test --installed`, in that order, and always reports all four. `Err` comes back only when claudevs
itself cannot run. A failing plugin is still `Ok`.

A suite stage is `Skipped` when there are no case files, no marketplace, or an installed layout that
cannot be built. It is `Failed` for an unreadable `plugin.json`. `Strictness::Strict` fails
`validate` on the delegate's warnings as well as its errors.

Each `Stage`'s `detail` is the human-rendered text of that stage. `render_check_human` and
`check_exit_code` turn the whole report into the same text and exit code the binary uses.

```rust
# std::env::set_current_dir(concat!(env!("CARGO_MANIFEST_DIR"), "/../claudevs")).unwrap();
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

## Diagnose the environment

`claudevs::doctor::run` returns a `Diagnosis` directly, not a `Result`. Its probes run in this
order: `claude binary`, `plugin manifest`, `cases`, `marketplace`, `install layout`.

A probe is `Ok`, `Warning` or `Gap`. Only `cases` can be a `Warning`. `all_clear` is false only when
a probe is a `Gap`. A missing `claude` binary is itself a `Gap`, so code that runs where `claude`
may be absent should not require `all_clear` to diagnose anything useful.

```rust
# std::env::set_current_dir(concat!(env!("CARGO_MANIFEST_DIR"), "/../claudevs")).unwrap();
use std::path::Path;

use claudevs::ProbeStatus;

let diagnosis = claudevs::doctor::run(Path::new("examples/01_hook_decision"));
print!("{}", claudevs::render_doctor_human(&diagnosis));
let marketplace = diagnosis.probes.iter().find(|probe| probe.name == "marketplace");
assert_eq!(marketplace.map(|probe| probe.status), Some(ProbeStatus::Ok));
```

## Run the wiring checkers alone

`claudevs::wiring::run` runs `refs`, `invocations` and `matchers`, in that order. It returns
`Error::Io` when the path is not a directory.

Each checker is also public on its own: `wiring::refs::check`, `wiring::invocations::check` and
`wiring::matchers::check`. Each returns `Result<Vec<Finding>>`. A `Finding` carries `severity`,
`checker`, `file`, `line` and `message`. `counts()` returns `(errors, warnings)`, and `all_clear()`
is false only when at least one finding is an error.

```rust
# std::env::set_current_dir(concat!(env!("CARGO_MANIFEST_DIR"), "/../claudevs")).unwrap();
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

## Load and run one YAML case

`case::discover` returns the plugin's case files, sorted, as `CaseFile::Yaml` or `CaseFile::Lua`.
`case::load_yaml_case` names the case after the file stem. `run_case(plugin_dir, fixtures_root, case)`
runs exactly one case.

Pass an absolute plugin directory. `run_suite` canonicalizes its path before the children it spawns
run inside their temporary project, and `run_case` uses whatever path it is given for
`CLAUDE_PLUGIN_ROOT`.

```rust
# std::env::set_current_dir(concat!(env!("CARGO_MANIFEST_DIR"), "/../claudevs")).unwrap();
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

## Run one Lua case file

`case::run_lua_file` runs a Lua file's data cases and its scripted cases together.
`case::load_lua_file` with `case::plain_engine()` also loads data cases. But the engine
`plain_engine` builds has no `t` handle. Only `run_lua_file` installs one, for callers that need
scripted cases too.

```rust
# std::env::set_current_dir(concat!(env!("CARGO_MANIFEST_DIR"), "/../claudevs")).unwrap();
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

## Convert a YAML case to Lua

`case::migrate_to_lua` loads the YAML case first and returns `Error::CaseLoad` for one that does not
load. It then produces a `return { [<stem>] = { … } }` literal.

```rust
# std::env::set_current_dir(concat!(env!("CARGO_MANIFEST_DIR"), "/../claudevs")).unwrap();
use std::path::Path;

let lua = claudevs::case::migrate_to_lua(Path::new(
    "examples/05_lua_cases/tests/allows-plain-push.yaml",
))?;
assert!(lua.starts_with("return {"));
assert!(lua.contains("[\"allows-plain-push\"]"));
# Ok::<(), claudevs::Error>(())
```
