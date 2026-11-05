# Your First Suite

This page runs the cases of an example plugin from a Rust program. You print the report, read each
verdict, and turn the result into a process exit code.

## Before you start

The harness starts hooks through `sh -c` and creates a case's default project with `git`. Both
must be on your `PATH`.

Add the crate to your project:

```toml
[dependencies]
claudevs = "0.1"
```

The snippets use two plugins from the repository, `examples/01_hook_decision` and
`examples/02_hook_decision_broken`. Their paths are relative to the `claudevs` crate directory, and
the snippets start there. The
[examples README](https://github.com/airsstack/claudestacks/blob/main/crates/claudevs/examples/README.md)
says what each example plugin shows.

## Run the suite

`run_suite` finds the case files under the plugin's `tests/` directory, runs every case and every
native suite, and returns a `SuiteReport`. An `Err` means claudevs itself could not run. A failing
case is part of the report, not an error.

```rust
# std::env::set_current_dir(concat!(env!("CARGO_MANIFEST_DIR"), "/../claudevs")).unwrap();
use std::path::Path;

let plugin = Path::new("examples/01_hook_decision");
let report = claudevs::run_suite(plugin, &claudevs::SuiteOptions::default())?;

print!("{}", claudevs::render_human(&report));
assert!(report.all_green());
assert_eq!(claudevs::exit_code(&report), 0);
# Ok::<(), claudevs::Error>(())
```

## Read what it printed

`render_human` writes one line per case and a summary line. Running the block above prints this:

```text
  ok    allows-other-files
  ok    asks-for-secrets
  ok    blocks-env-file

3 passed, 0 failed (3 cases, 0 native suites)
```

## Look at each verdict

Each `CaseOutcome` carries a `name` and a `Verdict`. A `Verdict` is `Pass`, or `Fail` with the list of
`Mismatch`es. `Verdict` is `#[non_exhaustive]`, so a `match` over it needs a wildcard arm. [How the
Engine Fits Together](ch09-02-engine.md) explains why.

This plugin has a defect, so its cases fail:

```rust
# std::env::set_current_dir(concat!(env!("CARGO_MANIFEST_DIR"), "/../claudevs")).unwrap();
use std::path::Path;

use claudevs::Verdict;

let plugin = Path::new("examples/02_hook_decision_broken");
let report = claudevs::run_suite(plugin, &claudevs::SuiteOptions::default())?;

for outcome in &report.outcomes {
    match &outcome.verdict {
        Verdict::Pass => println!("pass  {}", outcome.name),
        Verdict::Fail(mismatches) => {
            println!("fail  {} ({} mismatch)", outcome.name, mismatches.len());
        }
        _ => println!("?     {}", outcome.name),
    }
}
assert_eq!(claudevs::exit_code(&report), 1);
# Ok::<(), claudevs::Error>(())
```

It prints:

```text
pass  allows-other-files
pass  asks-for-secrets
fail  blocks-env-file (1 mismatch)
```

## Turn it into an exit code

`exit_code` returns 0 when every case passed and every native suite exited 0. Otherwise it returns 1.

The value 2 is reserved for "claudevs could not run". No report ever produces it. Your program maps
an `Err` from `run_suite` to 2 itself, the way the `claudevs` binary does.

The [next page](ch08-02-recipes.md) covers the rest of the engine's surface.
