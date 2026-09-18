# Why claudevs works the way it does

## What sits between validate and a live session

`claude plugin validate` validates "a plugin or marketplace manifest, or the skills, agents, and
commands in a directory" — that is the tool's own description, from `claude plugin validate --help`
on claude 2.1.276. It does not run a hook.

`claude plugin eval` sits further along, and nothing here says more about it than its name.

claudevs sits between the two. It spawns a plugin's hooks and scripts the way Claude Code would,
against fixed payloads in throwaway projects instead of a live session. Wanting the same case to give
the same verdict on every run is why the throwaway project exists at all: a live session's state
would make today's answer depend on what happened yesterday.

## Cases assert meaning, not mechanics

A case never says "exit 2" or "print `blocked` on stderr". It says `decision: deny`, and the harness
owns the translation from an observed run into that meaning. `Expectations` is where a case states
what it means, and `harness::semantics` is where an observed run is read back into the same
vocabulary.

The payoff shows up whenever a hook has more than one way to say the same thing. A `PreToolUse` hook
that exits 2 and a hook that instead prints a JSON envelope carrying `permissionDecision: "deny"` are
both denials, and a case written as `decision: deny` passes against either. The case does not choose
a mechanism; the hook does, and claudevs reads whichever one it picked.

## A skip is an environment gap

Three things about the machine a suite runs on can be missing entirely: no case files, no
marketplace above the plugin to key an install path by, no writable temporary directory. None of
those are the plugin's fault, so claudevs reports them as skipped, with the reason stated, rather than
failing the stage.

A malformed `plugin.json` is not treated the same way, on purpose. It would be easy to skip a stage
that cannot parse the manifest it needs, but a plugin that cannot be installed has a real defect, and
skipping it would let that plugin pass a run on any machine where the `claude` binary also happens to
be absent and the validation stage has already skipped for the same reason. An environment gap and a
plugin defect can look alike from the outside; claudevs keeps them apart by asking whether the cause
is the machine or the manifest.

## Every stage runs

A failed stage does not stop the ones after it. `check` always runs validation, wiring, the case
suite, and the case suite again from the installed layout, and reports every outcome in one pass.

The `07_wiring_broken` example shows why that matters: its `wiring` stage fails on a hook that points
at a script that does not exist, but no case exercises that hook, so `test` and `test --installed`
both still run and both still pass. Stopping at the first failure would have hidden that the rest of
the plugin is fine — or, just as easily, hidden a second, unrelated failure sitting in a later stage.

## What the installed layout catches

Claude Code installs a plugin at `cache/<marketplace>/<plugin>/<version>/`, a path with nothing beside
it but the plugin's own files. `test` runs a suite against the plugin where it already sits in a
checkout, which can have other things nearby; `test --installed` copies just the plugin into that
installed shape and runs the same suite again with `CLAUDE_PLUGIN_ROOT` pointed at the copy.

The two runs catch different defects because they start from different neighborhoods. A hook that
reaches for a file one directory above its own plugin root works from a checkout, where that
directory happens to exist, and breaks once only the plugin itself is copied into place — exactly the
gap in [`08_installed_broken`](../../examples/08_installed_broken/README.md).

## Why validation is handed to claude

claudevs delegates manifest validation to `claude plugin validate` instead of reimplementing it.
Anything the `claude` binary already checks is one less thing claudevs has to keep in sync with a
runtime it does not control, and delegation is also why the stage degrades gracefully: when `claude`
is not on the machine at all, this stage is skipped with a reason instead of failing, and `check`
still runs its own deterministic stages.

The delegate's strictness is a separate choice from whether it runs. By default it is lenient, so a
warning like a missing `author` field does not stop the deterministic stages that would catch a real
defect. Asking for strict treatment turns the same findings into failures, for callers who want
warnings to gate a release.

## Why cases cover fewer events than hooks.json may use

Two different lists answer two different questions about a hook event. One catalogues every event
Claude Code documents — the full set a plugin may legitimately wire in `hooks.json`. The other lists
only the events claudevs can synthesize a payload for and interpret a hook's response to, which is
narrower: an event a plugin may legitimately wire without claudevs being able to run a case against
it. The gap is not a defect in either list; it just means a documented event and a runnable one are not
always the same event, and a checker that reads `hooks.json` has to consult the wider catalogue while
a case has to work within the narrower one.

## Why a matcher claudevs cannot evaluate is a warning

A `matcher` value in `hooks.json` is not a Rust regular expression, even where it looks like one.
The hooks reference defines its own two modes — an exact-string mode for a narrow set of characters,
and a pattern mode for everything else — and claudevs judges a matcher's shape against those modes
rather than compiling it with Rust's regex engine.

Compiling still happens once a value falls into the pattern mode, because that is how the value gets
matched at run time, and Rust's regex engine and the one the runtime actually uses do not accept
exactly the same syntax. When Rust cannot compile a pattern that the reference's own rules would still
accept, claudevs cannot tell whether the runtime accepts it either — so that finding is reported as a
warning naming the divergence, never as an error against the plugin. Treating it as a failure would
punish a plugin for a gap in claudevs' own matcher engine rather than a defect in the plugin.
