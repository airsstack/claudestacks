# Getting Started

`claudevs` tests Claude Code plugins without a model in the loop. It runs a plugin's hooks and scripts
the way Claude Code would, checks that the plugin's files are wired together, and reports one pass or
fail answer. This chapter takes you from nothing to a passing `claudevs check`, then breaks a hook on
purpose and fixes it.

There are two ways to use `claudevs`. You can run the `claudevs` binary from a plugin's own
repository, or you can call the `claudevs` crate from Rust code that wants the same checks. This
chapter uses the binary. The crate is the subject of [Embedding](ch08-00-embedding.md).

| | Plugin author | Rust caller |
|---|---|---|
| What you use | the `claudevs` binary | the `claudevs` crate |
| Needs | `sh` and `git` on `PATH`; `claude` for the `validate` stage | `sh` and `git` on `PATH` |
| Start with | the pages below | [Embedding](ch08-00-embedding.md) |

`claude` is optional. Only the `validate` stage of `claudevs check` hands work to it. Without it, that
one stage is skipped and the run goes on.

## The pages

| Page | What you do |
|---|---|
| [Installation](ch05-01-installation.md) | Install the `claudevs` binary |
| [A First Plugin](ch05-02-first-plugin.md) | Write a small plugin with one hook, and ask `claudevs doctor` what it lacks |
| [A First Case](ch05-03-first-case.md) | Write a case for the hook and run it |
| [Running the Gate](ch05-04-running-the-gate.md) | Run `claudevs check`, break the hook, fix it, and test the installed copy |

The pages build on each other, so read them in order. Each one runs in the same scratch directory and
adds to the plugin the one before it left.

## Examples

The repository holds nine small plugins that `claudevs check` runs. Each has a `README.md` that says
what it shows and how its check ends. Two of them are worked through in
[Running the Gate](ch05-04-running-the-gate.md), and the others are linked from the chapters that use
them. The full set is in
[`crates/claudevs/examples/`](https://github.com/airsstack/claudestacks/tree/main/crates/claudevs/examples).
