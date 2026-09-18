# claudevs documentation

`claudevs` tests Claude Code plugins deterministically: a canonical case model, a harness that spawns
a plugin's hooks and scripts the way the Claude Code runtime would, and a report over the verdicts.
There are two ways to use it — the `claudevs` binary from a plugin's own repository, or the `claudevs`
crate from Rust code that wants the same checks programmatically.

These docs follow [Diátaxis](https://diataxis.fr/): four modes, kept separate on purpose. A tutorial
that stops to explain becomes a bad tutorial *and* a bad explanation, so each document commits to one
job.

## Start here

| | Plugin author | Rust caller |
|---|---|---|
| What you use | the `claudevs` binary | the `claudevs` crate |
| Needs | `sh` and `git` on `PATH`; `claude` for the `validate` stage | `sh` and `git` on `PATH` |
| Learn it | [tutorial](cli/tutorial.md) | [tutorial](engine/tutorial.md) |
| Do a specific thing | [how-to](cli/how-to.md) | [how-to](engine/how-to.md) |
| Look something up | [reference](cli/reference.md) | the rustdoc |
| Understand the design | [explanation](cli/explanation.md) | [explanation](engine/explanation.md) |

## Cross-cutting

Read this when the question spans the binary and the crate, or before your first edit to the engine.

- **[Architecture](architecture.md)** — how the case model, harness, native-suite delegation, wiring
  checks and report rendering fit together, and the crate-wide conventions worth knowing before you
  change anything.

## The four modes, and which file is which

| Mode | Question it answers | Where it lives |
|---|---|---|
| Tutorial | "I am new — get me something working." | `*/tutorial.md` |
| How-to | "I know the basics. How do I do *this*?" | `*/how-to.md`, plus [`../examples/`](../examples/README.md) |
| Reference | "What exactly does this do?" | `cli/reference.md`, plus the rustdoc |
| Explanation | "Why is it built this way?" | `*/explanation.md`, `architecture.md` |

The rustdoc is generated from the source, gated by `RUSTDOCFLAGS="-D warnings"`, and cannot drift from
the code:

```console
$ cargo doc -p claudevs --no-deps --open
```

## Examples

[`../examples/README.md`](../examples/README.md) indexes the runnable example plugins. Each one is a
plugin run through `claudevs check`, and `cargo make claudevs-check` asserts the outcome it produces.
