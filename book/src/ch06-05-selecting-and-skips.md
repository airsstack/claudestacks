# Selecting Cases and Reading Skips

Two small things finish the chapter. You can run part of a suite while you work on one case, and you
can read a `skip` line in a report, which is not a failure and is not a pass either.

## Run only some cases

`--case` keeps a case only when its name contains the given text. In the `guard` plugin from [Hook
Decisions](ch06-01-hook-decisions.md), which has four cases:

```console
$ claudevs test --case blocks
```

```text
  ok    blocks-env-file

1 passed, 0 failed (1 cases, 0 native suites)
```

The match is a plain substring, not a pattern, and it applies to the case name: the file stem for a
YAML case, the table key for a Lua case. Text that matches nothing is not an error:

```console
$ claudevs test --case nothing-has-this-name
```

```text
0 passed, 0 failed (0 cases, 0 native suites)
```

The exit code is 0, so a misspelt filter looks like a green run. Read the count before you trust it.

`--case` filters cases and leaves [native suites](ch06-04-native-suites.md) alone. In the `banner`
plugin, a filter that matches no case still runs the suite:

```console
$ claudevs test --case nothing-has-this-name
```

```text
  ok    native: sh tests/native/syntax-check.sh (exit 0)

0 passed, 0 failed (0 cases, 1 native suites)
```

The [first example](https://github.com/airsstack/claudestacks/tree/main/crates/claudevs/examples/01_hook_decision)
has three cases to try the filter on.

## Read a skip

`claudevs check` runs four stages, and a stage reports `ok`, `FAIL` or `skip`. A skip means the stage
could not run on this machine, and the reason follows on the next line. Here is a plugin called `bare`
that has a manifest and nothing else, checked on a machine where `claude` is not on the `PATH`. The
command puts only `/usr/bin` and `/bin` on the `PATH` for this one run:

```console
$ PATH=/usr/bin:/bin "$(command -v claudevs)" check
```

```text
  skip  validate
        cannot run `claude`: No such file or directory (os error 2)
  ok    wiring
        0 errors, 0 warnings
  skip  test
        no case files found under `/private/tmp/claudevs-cases/bare/tests` (cases are `*.yaml`, `*_test.lua` or `test_*.lua` in tests/)
  skip  test --installed
        marketplace `./../.claude-plugin/marketplace.json`: no `.claude-plugin/marketplace.json` in any ancestor directory; the installed layout is keyed by the marketplace that hosts the plugin

1 stage run, 0 failed, 3 skipped
```

The exit code is 0. A skip never fails `check`. Each of the three skips names something the machine
lacks, and each has one fix:

| Skip | What is missing | The fix |
|---|---|---|
| `validate` says `cannot run claude` | the `claude` binary on `PATH` | put `claude` on `PATH` |
| `test` says `no case files found` | a case under `tests/` | write a case, as in [A First Case](ch05-03-first-case.md) |
| `test --installed` says `no .claude-plugin/marketplace.json in any ancestor directory` | a marketplace above the plugin | put the plugin in a marketplace, as in [A First Plugin](ch05-02-first-plugin.md) |

With a case, a marketplace above the plugin and `claude` installed, the same plugin runs all four
stages. A skip says nothing about whether your plugin works. A stage that skipped checked nothing, so a
run that ends in `0 failed, 3 skipped` has tested far less than one that ends in `0 failed, 0 skipped`.

Only `check` turns these gaps into skips. `claudevs test` with no case files ends with exit code 2, and
so does `claudevs test --installed` with no marketplace above the plugin. Running one stage by hand
means you asked for it, so a missing piece is an error.

The [examples README](https://github.com/airsstack/claudestacks/tree/main/crates/claudevs/examples#without-a-claude-binary)
shows which results hold with and without `claude`.

## A skip is an environment gap

claudevs reports a skip when the cause is the machine and not the plugin: no case files yet, no
marketplace above the plugin to key an install path by, no `claude` to validate with. None of those is a
fault in the plugin, so none of them fails the stage.

A malformed `plugin.json` is treated differently, on purpose. It would be easy to skip a stage that
cannot read the manifest it needs. But a plugin whose manifest cannot be read has a real defect, and
skipping it would let that plugin pass on any machine where `claude` is also missing and `validate` has
already skipped. So a plugin inside a marketplace, with a `plugin.json` that is not valid JSON, fails
`test --installed` even when `claude` is missing and `validate` has skipped.

An environment gap and a plugin defect can look alike from the outside. claudevs tells them apart by
asking whether the cause is the machine or the manifest.

A temporary directory that claudevs cannot create is a problem with the machine too, but `check` does
not turn it into a skip. When a case needs a project, the run ends with exit code 2 and a message that
names the directory.

A failed stage does not stop the ones after it, so a `FAIL` and a `skip` can sit in the same report.
[Stages](ch07-01-stages.md) covers the errors that do stop the run.
