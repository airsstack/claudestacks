# 09 — Doctor gaps

One `SessionStart` hook, one case, nothing wrong with the plugin. This example is not about a defect
in `doctor-gaps` itself — it is about what `claudevs doctor` looks at, and how that differs from what
`claudevs check` looks at.

`scripts/simulate.sh` reproduces the four runs below without any manual copying: `sh
scripts/simulate.sh healthy`, `no-claude`, `no-marketplace`, or `no-cases` runs one, `all` runs all
four in order, and each prints the exact command it runs before running it. Run it from anywhere; it
finds its own plugin directory and picks `$CLAUDEVS`, then a `target/debug/claudevs` build, then
`claudevs` on `PATH`, in that order.

## `doctor` versus `check`

`check` judges the plugin: it validates the manifest, checks `${CLAUDE_PLUGIN_ROOT}` references,
and runs the cases. `doctor` asks a narrower, prior question — whether the *environment around* the
plugin can even run those stages: is the `claude` binary on `PATH` for the validate stage, can the
plugin's own manifest be read, do any case files exist for the suite stages to run at all, can a
marketplace manifest be found above the plugin to key an install path by, and can the simulated
install layout be materialized. A probe never repairs anything and never guesses: it runs the same
code the stage it is asking about would run.

Failing probes come in two shades. A **gap** means the environment is missing something the plugin
cannot supply for itself — no `claude` binary, no marketplace above it, no simulated install layout,
or an unreadable plugin manifest (without it, the marketplace and install-layout probes cannot run
either). A **warning** is an observation about the plugin's own content that does not stop `check`
from gating — today that is only the cases probe: a plugin with no case files yet is incomplete, not
broken. `Diagnosis::all_clear` fails only when a gap is present; a warning alone leaves it clear.

## The healthy run

```console
$ cargo run -q -p claudevs-cli -- doctor crates/claudevs/examples/09_doctor_gaps
```

```text
  ok    claude binary: present; `check` delegates its validate stage
  ok    plugin manifest: doctor-gaps 0.1.0
  ok    cases: 1 case file(s) found
  ok    marketplace: claudevs-examples
  ok    install layout: simulated at …/cache/claudevs-examples/doctor-gaps/0.1.0

0 gaps, 0 warnings
```

The exit code is 0. Every probe answers `ok`, so `doctor` has nothing to add to a `check` run on the
same directory.

## Gap 1 — hide the `claude` binary

```console
$ env PATH=/usr/bin:/bin target/debug/claudevs doctor crates/claudevs/examples/09_doctor_gaps
```

```text
  gap   claude binary: cannot run `claude`: No such file or directory (os error 2); `check` skips its validate stage
  ok    plugin manifest: doctor-gaps 0.1.0
  ok    cases: 1 case file(s) found
  ok    marketplace: claudevs-examples
  ok    install layout: simulated at …/cache/claudevs-examples/doctor-gaps/0.1.0

1 gap, 0 warnings
```

The exit code is 1. `claudevs` itself has to stay reachable once `PATH` is cut down to `/usr/bin:/bin`,
so the command above runs the built binary by its path (`target/debug/claudevs`, from the repository
root, after `cargo build -p claudevs-cli`) rather than relying on it being found on `PATH` — a relative
path containing a slash bypasses the `PATH` search that stripped `claude` out.

## Gap 2 — no marketplace above the plugin

Copy the plugin somewhere with no `.claude-plugin/marketplace.json` in any ancestor directory, then
run `doctor` there. Copying it anywhere inside this repository will not do it: the marketplace lookup
walks ancestors, and it would still find the repository root's own marketplace manifest. A directory
made with `mktemp -d`, outside the repository, is not below one.

```console
$ dest=$(mktemp -d)
$ cp -R crates/claudevs/examples/09_doctor_gaps "$dest/doctor-gaps"
$ target/debug/claudevs doctor "$dest/doctor-gaps"
```

```text
  ok    claude binary: present; `check` delegates its validate stage
  ok    plugin manifest: doctor-gaps 0.1.0
  ok    cases: 1 case file(s) found
  gap   marketplace: marketplace `…/doctor-gaps/../.claude-plugin/marketplace.json`: no `.claude-plugin/marketplace.json` in any ancestor directory; the installed layout is keyed by the marketplace that hosts the plugin
  gap   install layout: marketplace `…/doctor-gaps/../.claude-plugin/marketplace.json`: no `.claude-plugin/marketplace.json` in any ancestor directory; the installed layout is keyed by the marketplace that hosts the plugin

2 gaps, 0 warnings
```

The exit code is 1. Both the marketplace probe and the install-layout probe report the gap: the
install layout is keyed by the marketplace name, so it cannot be materialized without one either.

## The warn shade — no case files

Copy the plugin under a directory that does have a marketplace manifest, then delete its `tests/`.

```console
$ dest=$(mktemp -d)
$ mkdir -p "$dest/.claude-plugin"
$ echo '{"name":"doctor-gaps-warn-fixtures"}' > "$dest/.claude-plugin/marketplace.json"
$ cp -R crates/claudevs/examples/09_doctor_gaps "$dest/doctor-gaps"
$ rm -rf "$dest/doctor-gaps/tests"
$ target/debug/claudevs doctor "$dest/doctor-gaps"
```

```text
  ok    claude binary: present; `check` delegates its validate stage
  ok    plugin manifest: doctor-gaps 0.1.0
  warn  cases: no case files found under `…/doctor-gaps/tests` (cases are `*.yaml`, `*_test.lua` or `test_*.lua` in tests/)
  ok    marketplace: doctor-gaps-warn-fixtures
  ok    install layout: simulated at …/cache/doctor-gaps-warn-fixtures/doctor-gaps/0.1.0

0 gaps, 1 warning
```

The exit code is 0. `Diagnosis::all_clear` only checks for a gap — a warning never appears in that
check — so a plugin with no cases yet still diagnoses clear; it is incomplete, not broken. A gap in
either of the two runs above would have made `all_clear` false and the exit code 1.

## What `doctor` will not tell you

`doctor` never runs a case and never checks a `${CLAUDE_PLUGIN_ROOT}` reference, so it calls a plugin
healthy that `check` fails for reasons inside the plugin itself. `07_wiring_broken` and
`08_installed_broken` are both examples of exactly that: `claudevs doctor` on either one reports
`0 gaps, 0 warnings`, while `claudevs check` on the same directory fails `wiring` or
`test --installed`. Run both to see the split:

```console
$ cargo run -q -p claudevs-cli -- doctor crates/claudevs/examples/07_wiring_broken
$ cargo run -q -p claudevs-cli -- check  crates/claudevs/examples/07_wiring_broken
```
