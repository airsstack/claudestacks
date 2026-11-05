# claudevs (engine)

Engine library for `claudevs`, the Claude Code plugin lifecycle CLI. It holds the case model (YAML and
Lua front-ends), the deterministic test harness that spawns a plugin's hooks and scripts the way the
Claude Code runtime would, native-suite delegation, static wiring checks, install-layout simulation,
and report rendering. The [`claudevs-cli`](https://crates.io/crates/claudevs-cli) crate is the binary;
this crate is everything it calls.

Use the binary to test a plugin from a shell or CI. Use this crate when Rust code wants to run the
same suite itself.

## Install

```toml
[dependencies]
claudevs = "0.1"
```

The harness starts hooks through `sh -c` and creates each case's project with `git`, so both need to
be on `PATH`.

## Example

A complete program that runs a plugin's suite, prints the report, and exits 0 when every case passes
and 1 when one fails. It takes the plugin directory as its first argument.

```rust,no_run
use std::path::PathBuf;

fn main() -> Result<(), claudevs::Error> {
    let plugin: PathBuf = std::env::args().nth(1).unwrap_or_else(|| ".".into()).into();

    let report = claudevs::run_suite(&plugin, &claudevs::SuiteOptions::default())?;
    print!("{}", claudevs::render_human(&report));

    std::process::exit(claudevs::exit_code(&report));
}
```

An `Err` means claudevs itself could not run, and returning it from `main` exits 1. A failing case is
part of the report, not an error.

## Documentation

The book covers the binary and the crate.

- [Getting Started](https://airsstack.github.io/claudestacks/ch05-00-claudevs-getting-started.html)
  installs the binary and takes you to a passing `claudevs check`.
- [Writing Cases](https://airsstack.github.io/claudestacks/ch06-00-writing-cases.html) covers hook
  decisions, scripts and flows, Lua cases and native suites.
- [The check Gate](https://airsstack.github.io/claudestacks/ch07-00-check-gate.html) covers the four
  stages, the wiring checkers and running the gate in CI.
- [Embedding](https://airsstack.github.io/claudestacks/ch08-00-embedding.html) is the chapter for
  Rust callers of this crate.
- [Under the Hood](https://airsstack.github.io/claudestacks/ch09-00-claudevs-under-the-hood.html)
  explains the design and how the engine fits together.
- [claudevs CLI Reference](https://airsstack.github.io/claudestacks/appendix-01-claudevs-cli.html)
  lists every command, flag and exit code.

The API reference is the rustdoc.

The repository also holds nine small example plugins, each with its case files and the `claudevs
check` outcome it produces, in
[`examples/`](https://github.com/airsstack/claudestacks/blob/main/crates/claudevs/examples/README.md).

## License

Apache-2.0. See the `LICENSE` file.
