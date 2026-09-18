# Run a plugin's suite from Rust

This tutorial is for a Rust program that depends on the `claudevs` crate. It
runs the cases of an example plugin, prints the report, reads the verdicts,
and turns the result into a process exit code.

## Before you start

The harness spawns hooks through `sh -c` and creates each case's temporary
project with `git`, so both need to be on `PATH`.

The snippets below use `examples/01_hook_decision` and
`examples/02_hook_decision_broken`, paths relative to the `claudevs` crate
directory; see `../../examples/README.md` for what each example plugin
demonstrates.

## Run the suite

`run_suite` finds the case files under the plugin's `tests/` directory, runs
every case and every native suite, and returns a `SuiteReport`. An `Err`
means claudevs itself could not run; a failing case is part of the report,
not an error.

```rust
use std::path::Path;

let plugin = Path::new("examples/01_hook_decision");
let report = claudevs::run_suite(plugin, &claudevs::SuiteOptions::default())?;

print!("{}", claudevs::render_human(&report));
assert!(report.all_green());
assert_eq!(claudevs::exit_code(&report), 0);
# Ok::<(), claudevs::Error>(())
```

## Read what it printed

`render_human` writes one line per case and a summary line. Running the
block above against the same plugin prints:

```text
  ok    allows-other-files
  ok    asks-for-secrets
  ok    blocks-env-file

3 passed, 0 failed (3 cases, 0 native suites)
```

## Look at each verdict

Each `CaseOutcome` carries a `name` and a `Verdict`, which is `Pass` or
`Fail` with the list of `Mismatch`es. `Verdict` is `#[non_exhaustive]`, so a
`match` over it needs a wildcard arm — see `explanation.md` for why.

```rust
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

## Turn it into an exit code

`exit_code` is 0 when every case passed and every native suite exited 0, and
1 otherwise. 2 is reserved for "claudevs could not run", and no report ever
produces it — a program maps an `Err` from `run_suite` to 2 itself, the way
the `claudevs` binary does.

## Where to go next

`how-to.md` covers the rest of the engine's surface; `explanation.md` covers
how its parts relate; `../architecture.md` maps the modules. The engine's
full API is in its rustdoc:

```console
$ cargo doc -p claudevs --no-deps --open
```
