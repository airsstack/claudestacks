# Embedding

The `claudevs` command line is a thin shell over a Rust library. You can depend on that library and
run a plugin's cases from your own program. You get the same report, verdicts and exit codes the
binary produces, as typed values you can inspect.

Use it when you want to wrap the harness in your own tool, or assert on plugin behavior from a Rust
test. If you only want to run cases from a terminal or CI, the [`claudevs` binary](ch05-00-claudevs-getting-started.md)
is enough.

| Page | What you do |
|---|---|
| [Your First Suite](ch08-01-first-suite.md) | Run a plugin's suite, read the report and turn it into an exit code |
| [Recipes](ch08-02-recipes.md) | Produce JSON, filter cases, run `check` and `doctor`, drive one case at a time |

Every snippet in this chapter runs offline. None of them reaches a service or spends usage. The
engine's full API is in its rustdoc:

```bash
cargo doc -p claudevs --no-deps --open
```

To see how the engine's parts relate, read [How the Engine Fits Together](ch09-02-engine.md).
