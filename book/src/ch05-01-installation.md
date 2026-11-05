# Installation

You need one binary, `claudevs`. There are three ways to get it. Pick one.

## A prebuilt binary

This needs no Rust toolchain. It downloads the installer for the latest release and runs it:

```bash
curl -LsSf https://airsstack.github.io/claudestacks/install.sh | sh
```

## From crates.io

This builds the binary on your machine:

```bash
cargo install --locked claudevs-cli
```

## From a checkout

From the root of a clone of the repository, this builds the version in the clone:

```bash
cargo install --locked --path crates/claudevs-cli
```

These commands reach a service or replace the `claudevs` already installed on your machine, so the
page shows no output for them.

## Check it works

Run the binary and ask for its version:

```bash
claudevs --version
```

```text
claudevs 0.1.1
```

Your version may differ from the one printed here.

## What it needs at run time

Hooks run through `sh`, and cases need `git` on `PATH`. Hook commands in `hooks.json` start as
`sh -c <command>`. The default project a case runs in is a git repository that `claudevs` creates
with `git`, so that a hook which looks at project state cannot take a silent "not found" path. A
fixture is a git repository only when it carries a `.gitinit` file, as [Scripts and
Flows](ch06-02-scripts-and-flows.md) explains.

`claude` is optional. Only the `validate` stage inside `claudevs check` delegates to it. If it is
missing, that stage is skipped and the run does not fail. [Running the Gate](ch05-04-running-the-gate.md)
shows the check output both ways.

Next, [write a first plugin](ch05-02-first-plugin.md).
