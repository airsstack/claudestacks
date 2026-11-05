# Under the Hood

The earlier chapters show how to use claudevs. This one explains why it behaves the way it does. You
do not need any of it to write a case or to run the gate. It helps when a verdict surprises you, when
you wonder why a hook event is missing from the list a case accepts, or when you embed the engine in
your own Rust program and want to know how the parts fit.

| Page | What it explains |
|---|---|
| [Why It Works This Way](ch09-01-design.md) | Where claudevs sits next to `claude plugin validate`, why a case states a meaning instead of an exit code, and why cases cover fewer events than `hooks.json` may use |
| [How the Engine Fits Together](ch09-02-engine.md) | The two crates, every module the engine exports, the path from a plugin directory to a report, and the rules a Rust caller should know |

The pages describe the design. For the exact flags, exit codes and report shapes, see
[Appendix A](appendix-01-claudevs-cli.md). To call the engine from your own program, start at
[Embedding](ch08-00-embedding.md).
