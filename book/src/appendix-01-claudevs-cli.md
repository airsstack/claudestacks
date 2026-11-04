# A. claudevs CLI Reference

This appendix lists every `claudevs` command, flag, exit code, case field and report shape. For a
walk through the same material, start at [Getting Started](ch05-00-claudevs-getting-started.md). For
the reasoning behind it, see [Under the Hood](ch09-00-claudevs-under-the-hood.md).

## Commands

```text
Command-line interface for claudevs, the Claude Code plugin lifecycle tool

Usage: claudevs <COMMAND>

Commands:
  test     Run a plugin's case suite plus its declared native suites
  migrate  Convert a YAML case to its data-Lua form
  check    Validate, check wiring, then run the suite in both layouts
  doctor   Report what this environment can and cannot do
  help     Print this message or the help of the given subcommand(s)

Options:
  -h, --help     Print help
  -V, --version  Print version
```

### test

Run a plugin's case suite plus its declared native suites.

```text
Run a plugin's case suite plus its declared native suites

Usage: claudevs test [OPTIONS] [PATH]

Arguments:
  [PATH]  The plugin directory [default: .]

Options:
      --case <CASE>  Only run cases whose name contains this substring
      --installed    Run against a throwaway copy in the installed cache layout
      --json         Emit the machine-readable report instead of the human one
  -h, --help         Print help
```

The human report ends with a summary line of the form `N passed, N failed (N cases, N native suites)`.
A declared native suite counts toward the passed and failed totals. `--case` with a substring that
matches no case runs no case, but every declared native suite still runs, so the exit code is 0 only if
they all pass.

### check

Validate, check wiring, then run the suite in both layouts.

```text
Validate, check wiring, then run the suite in both layouts

Usage: claudevs check [OPTIONS] [PATH]

Arguments:
  [PATH]  The plugin directory [default: .]

Options:
      --strict  Fail on the delegate's warnings as well as its errors
      --json    Emit the machine-readable report instead of the human one
  -h, --help    Print help
```

### doctor

Report what this environment can and cannot do.

```text
Report what this environment can and cannot do

Usage: claudevs doctor [OPTIONS] [PATH]

Arguments:
  [PATH]  The plugin directory [default: .]

Options:
      --json  Emit the machine-readable report instead of the human one
  -h, --help  Print help
```

### migrate

Convert a YAML case to its data-Lua form.

```text
Convert a YAML case to its data-Lua form

Usage: claudevs migrate [OPTIONS] <FILE>

Arguments:
  <FILE>  The YAML case file

Options:
      --write  Replace the .yaml file with the .lua file instead of printing
  -h, --help   Print help
```

Without `--write`, `migrate` prints the Lua to stdout. With `--write`, it writes `<stem>_test.lua`
beside the YAML file, removes the YAML file, and prints `<stem>.yaml -> <stem>_test.lua`.

## Exit codes

| Command | 0 | 1 | 2 |
|---|---|---|---|
| `test` | Every case passed and every declared native suite exited 0. | At least one case failed, or a native suite exited non-zero. A YAML case file that cannot be loaded counts here: it is reported as one failed case and the run goes on. | claudevs itself could not run: a usage error, a plugin path that does not resolve, no case files under `tests/`, a Lua case file that does not load, does not return a table or holds an invalid case name, a `hooks/hooks.json` that is missing or not valid JSON when a hook case needs it, a `claudevs.toml` entry with an unknown key, a declared native suite that could not be started, or a temporary project that could not be created. |
| `check` | No stage failed. A skipped stage does not count against it. | At least one stage failed. | The plugin path is not a directory, or some other error that a stage does not turn into a skip or a failure, such as a `hooks/hooks.json` that is not valid JSON while a hook case runs, or a temporary directory that cannot be created. |
| `doctor` | No probe reports a gap. | A probe reports a gap. A warning alone never produces this. | Only when `--json` cannot render the report, which the report types claudevs emits never cause in practice. |
| `migrate` | The case was printed, or written with `--write`. | None. | The file is not a loadable YAML case, or writing or removing a file failed. |

## Case discovery

Case files are found under `<plugin>/tests/`, walked recursively in sorted order. A `.yaml` or `.yml`
file is one case, named by its file stem. A file named `*_test.lua` or `test_*.lua` returns a table of
named cases. Anything under `tests/fixtures/` is fixture data, never a case. Finding no case files at
all is an error, not a green suite.

A case name is the file stem for YAML and the table key for Lua. It must be non-empty and use only
`A-Z`, `a-z`, `0-9`, `.`, `_` and `-`.

## Case fields

**Common to every case:**

| Field | Meaning |
|---|---|
| `project` | The fixture to materialize as the temporary project, instead of the default project. Write a bare name or `fixture: <name>`. |
| `expect` | Judged after the run for a hook or script case, or after the last step for a flow case. |

**Kind-specific fields.** A case is exactly one of hook, script or flow:

| Kind | Field | Meaning |
|---|---|---|
| Hook | `event` | One of `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `SessionStart`, `SessionEnd`. |
| Hook | `hook` | An optional substring that picks which `hooks.json` handler this case targets, when more than one survives matcher filtering. |
| Hook | `payload` | An object overlaid on the event's built-in default payload. Objects merge recursively field by field. Any other value replaces its counterpart outright. |
| Hook | `payload_raw` | Raw stdin text sent verbatim instead of a JSON payload, for hostile-input cases. It excludes `payload`. |
| Script | `invocation.argv` | The program and arguments to spawn. |
| Script | `invocation.env` | Extra environment variables for the child. |
| Flow | `steps` | A sequence of steps run in one shared project. |

A flow step is exactly one of `run` (an invocation) or `apply_fixture` (a fixture name to overlay into
the shared project). It may also carry an `expect`, which applies only to a `run` step. A step whose
expectation fails stops the flow right there.

The case's top-level `expect` is judged against the last `run` step's observation. A flow made only of
`apply_fixture` steps has nothing to judge but `files_exist`. Any other expectation on such a flow
fails rather than passing without checking anything.

`{project}` in `invocation.argv` and `invocation.env` is replaced with the temporary project's path at
run time.

**`expect` fields:**

| Field | Meaning |
|---|---|
| `exit` | The exact exit code expected. |
| `decision` | One of `allow`, `deny`, `ask`, `defer`. |
| `output` | Accepts only `"none"`: the hook must return no decision and no context, as [How a hook run is read](#how-a-hook-run-is-read) defines them. Any other output, such as text on stderr or a `systemMessage` envelope on `PreToolUse`, does not count. It is a hook-only assertion. Asserting it on a script or flow case is rejected when the case loads, because only a hook observation records whether anything was emitted. |
| `context_contains` | A substring the injected context must contain. |
| `stdout_contains` | A substring stdout must contain. |
| `stderr_contains` | A substring stderr must contain. |
| `files_exist` | Paths, relative to the temporary project, that must exist once the run finishes. |

Every expectation on a case is checked, and a failing case lists every mismatch rather than stopping
at the first. Unknown fields are rejected, in cases, invocations, flow steps and `expect` blocks alike.

## Case load errors

A YAML case that fails to load is reported as a failed case with one of these messages. A Lua case
file that fails to load stops the run with exit 2 and the same message. Flow step numbers start at 0.

```text
a case is exactly one of hook (`event:`), script (`invocation:`) or flow (`steps:`); found N
`payload` and `payload_raw` are mutually exclusive
flow step N: exactly one of `run` or `apply_fixture`
`expect.output` only accepts "none", got `VALUE`
`expect.output` is a hook assertion: only a hook observation records whether anything was emitted, so this expectation could never fail here
unknown hook event `NAME` (known: PreToolUse, PostToolUse, UserPromptSubmit, SessionStart, SessionEnd)
invalid case name `NAME`: names are non-empty [A-Za-z0-9._-]
```

An unrecognized field name reports the field together with every field the case shape accepts. For
example, a misspelled `expect` gives ``unknown field `expct`, expected one of `event`, `hook`,
`payload`, `payload_raw`, `invocation`, `steps`, `project`, `expect` ``.

## Default payloads

The built-in default payload for `PreToolUse`, and for `PostToolUse` with its own event name, has this
shape:

```text
{
  "session_id": "claudevs-test",
  "cwd": "{project}",
  "hook_event_name": "PreToolUse",
  "tool_name": "Edit",
  "tool_input": { "file_path": "{project}/file.txt" }
}
```

`UserPromptSubmit` adds `"prompt": "hello"`. `SessionStart` adds `"source": "startup"`. `SessionEnd`
adds `"reason": "exit"`. The last three carry no `tool_name` or `tool_input`.

A case's `payload` overlay merges onto this default. Objects merge recursively and other values
replace. Before the payload is sent, `{project}` in any string, default or overlay alike, is replaced
with the temporary project's actual path.

## How a hook run is read

A hook's stdout may carry a JSON envelope that communicates a decision in one of three shapes. They
are read most-specific first. The hooks reference states no precedence between them, so this order is
claudevs' own choice.

1. `hookSpecificOutput.permissionDecision`, which is `allow`, `deny`, `ask` or `defer`.
2. `hookSpecificOutput.decision.behavior`, which is `allow` or `deny`.
3. A top-level `decision` string. It spells denial `"block"` rather than `"deny"`, and claudevs reads
   `"block"` as a denial.

Whichever of these is present, the hook counts as having emitted something, whether or not its value
is one claudevs reads as a decision.

Separately from any envelope, a `PreToolUse` hook that exits `2` is read as a denial.

`hookSpecificOutput.additionalContext` carries injected context. It is read independently of which
decision shape, if any, came with it.

When there is no envelope at all, bare stdout is read as injected context only for the events whose
bare output Claude Code actually surfaces. Of the five events claudevs can simulate, those are
`SessionStart` and `UserPromptSubmit`. The bare stdout of a `PreToolUse`, `PostToolUse` or
`SessionEnd` hook is not context.

## What a spawned command gets

The child's working directory is the case's temporary project. Its environment is the process's own
environment plus `CLAUDE_PLUGIN_ROOT` (the plugin directory) and `CLAUDE_PROJECT_DIR` (the temporary
project). A script invocation's own `env` entries are layered on top.

A `hooks.json` handler uses one of two execution models. A `command` alone is a shell handler, run
through `sh -c`, so its string may use pipelines, redirection and expansion. A `command` paired with
`args` is an exec handler, spawned directly with no shell at all. Each `args` element is one argument
exactly as written, with no tokenization on any platform.

Every spawned child has a 30-second timeout. A child still running past it is killed, and the case
fails with this message:

```text
timeout: the child timed out and was killed before completing
```

## Projects and fixtures

Without a `project:` field, a case runs against the default project. It is a git repository with a
minimal `Cargo.toml`, one tracked and committed file named `file.txt`, and one commit. The default
`PreToolUse` and `PostToolUse` payload points its `tool_input.file_path` at that file.

`project: <name>`, or `project: { fixture: <name> }`, copies `tests/fixtures/<name>/` into a fresh
temporary directory instead. A `.gitinit` file inside the fixture triggers a `git init` plus one
commit once the copy is made. The commit is always empty: the fixture's files are copied in but never
added, so they stay untracked. The marker file is never copied into the project.

A flow's `apply_fixture` step, and the Lua `t.apply_fixture`, copies a fixture over a project that
already exists instead of starting a fresh one.

## Lua cases

A `*_test.lua` file returns a table. Each entry is either a data case or a scripted case. A data case
is a table, parsed the same way a YAML case is. A scripted case is a function. It runs when claudevs
calls it with the harness handle `t`, and it passes by returning without raising an error.

`t` offers these functions:

| Function | Returns |
|---|---|
| `t.fixture(name)` | The path of a fresh temporary project seeded from the named fixture alone, without the default project's files. |
| `t.project()` | The path of a fresh temporary copy of the default project. |
| `t.apply_fixture(name, dir)` | Overlays the named fixture into `dir`. |
| `t.hook(ref, payload?)` | Runs a hook and returns `{exit, stdout, stderr, decision?, context?, emitted}`. `ref` is either an event name or a substring of a handler's command that is unique across every event's wiring. |
| `t.script(argv, opts?)` | Runs `argv` directly and returns `{exit, stdout, stderr}`. `opts.env` adds environment, `opts.cwd` sets the working directory (the plugin directory by default), and `opts.stdin` feeds stdin. |
| `t.skill_command(skill, n)` | The text of the `n`-th fenced command in `skills/<skill>/SKILL.md`. `n` starts at 1 and follows document order. |
| `t.json(path)` | The decoded contents of a JSON file. |

A relative path given to `t.json` is read from the directory you started `claudevs` in, not from the
plugin directory. To read a file inside the plugin, build an absolute path from `CLAUDE_PLUGIN_ROOT`.

`t.json`'s path and `t.script`'s `cwd` must resolve inside the plugin directory or a temporary project
the case itself created. `t.apply_fixture`'s `dir` must resolve inside a temporary project only, never
the plugin directory. `t.skill_command`'s resolved path must stay inside the plugin directory.

Only the Lua itself runs confined with no grants. It cannot reach the sandboxed filesystem or process
modules directly. The `t` handle is not part of that sandbox. Every function on it runs on the host,
and `t.script` can spawn any program with the ambient environment. A `*_test.lua` file is trusted code,
on the same footing as a shell script you run locally.

## claudevs.toml

A plugin may declare native suites that claudevs delegates to instead of running itself:

```toml
[[native]]
run = "airsl test --policy confined ."
```

Each `run` is spawned as `sh -c` in the plugin directory. Only the exit code is asserted. The combined
stdout and stderr are captured. The human report shows them only when the exit code is non-zero. The
`--json` report carries them for every suite. With no `claudevs.toml` there are no native suites at
all. An entry with any key other than `run` is an error, and the run exits 2.

## check stages

`check` runs four stages in order. A failure in one does not stop the ones that follow.

| Stage | What it runs | Skipped when | Fails when |
|---|---|---|---|
| `validate` | `claude plugin validate [--strict] <path>`, delegated to the installed `claude` binary. | The `claude` binary cannot run. | The delegate exits non-zero. |
| `wiring` | The three wiring checkers below. | Never. | Any checker reports an error-severity finding. |
| `test` | The case suite, in the source checkout. | No case files exist. | A case or declared native suite fails. |
| `test --installed` | The case suite again, against a throwaway copy in the simulated installed layout. | No case files exist, no marketplace manifest is found above the plugin, or the simulated installed layout cannot be created. | A case or declared native suite fails, or the plugin manifest cannot be read. |

Each stage is marked `ok`, `FAIL` or `skip` in the human output. A summary line follows, in the form
`N stages run, N failed, N skipped`. A skipped stage does not count toward the number run.

## Wiring checkers

Three static checkers run in this order. Each produces findings and runs nothing.

| Checker | Severity | Reports | Message |
|---|---|---|---|
| `refs` | error | Every `${CLAUDE_PLUGIN_ROOT}/…` reference in `.claude-plugin/*.json` and under `hooks/`, `skills/`, `agents/` and `commands/` (outside fenced code blocks) that does not resolve to a file in the plugin, or that escapes the plugin root through a `..` segment. The unbraced form `$CLAUDE_PLUGIN_ROOT` is not scanned. | ``` `${CLAUDE_PLUGIN_ROOT}/PATH` does not exist ``` or ``` `${CLAUDE_PLUGIN_ROOT}/PATH` escapes the plugin root ``` |
| `invocations` | warning | A `.sh`, `.lua`, `.py` or `.js` file that presents as executable (a shebang, an executable bit, or anything under `hooks/`) but is named by nothing else in the plugin, by filename, by module stem, or from inside a fenced command. Case files, anything under `tests/`, and language index files (`__init__.py`, `index.js`, `init.lua`) are exempt. | ``` `NAME` is referenced by nothing in this plugin ``` |
| `matchers` | error or warning | See the findings below. | See the findings below. |

The `matchers` checker reports these findings:

| Finding | Severity | Message |
|---|---|---|
| `hooks/hooks.json` is not JSON | error | ``is not JSON: REASON`` |
| `hooks/hooks.json` has no top-level `hooks` object | error | ``has no `hooks` object at the top level`` |
| An event name the catalogue does not document | warning | ``` `EVENT` is not an event this version of claudevs knows about; it may be newer than the catalogue ``` |
| A matcher on an event that takes none | warning | ``` `EVENT` takes no matcher, so `MATCHER` is silently ignored by the runtime ``` |
| A matcher claudevs cannot evaluate as a regular expression | warning | ``` claudevs cannot evaluate matcher `MATCHER` (REASON), so it cannot tell whether the runtime accepts it ``` |

The human rendering is one line per finding, followed by a summary line. A line reads
`  error  CHECKER  FILE[:LINE]  MESSAGE` or `  warn   CHECKER  FILE[:LINE]  MESSAGE`. The summary line
reads `N errors, N warnings`, with `1 error` and `1 warning` in the singular.

## doctor probes

`doctor` runs five probes in order. Each one reuses the code of the `check` stage it stands for, so it
reports what the stage would find and does not guess at the environment.

| Probe | Checks | Status it can take |
|---|---|---|
| `claude binary` | Whether the `claude` binary can be delegated to for the `validate` stage. | `ok` when reachable, `gap` when absent. |
| `plugin manifest` | Whether `<plugin>/.claude-plugin/plugin.json` can be read and names a usable `name` and `version`. | `ok` or `gap`. |
| `cases` | Whether any case files can be discovered under `tests/`. | `ok` when at least one is found. `warning` when none are, because a plugin with no cases yet is incomplete, not broken. |
| `marketplace` | Whether a `.claude-plugin/marketplace.json` can be found by walking up from the plugin. | `ok` or `gap`. |
| `install layout` | Whether the simulated installed-cache layout can be created. | `ok` or `gap`. |

Each probe is marked `ok`, `warn` or `gap` in the human output. A summary line follows, in the form
`N gaps, N warnings`, with `1 gap` and `1 warning` in the singular. A `gap` fails the overall
diagnosis. A warning alone never does. The JSON report spells the middle status `warning`.

This is a clean diagnosis, from `claudevs doctor` on the `01_hook_decision` example:

```text
  ok    claude binary: present; `check` delegates its validate stage
  ok    plugin manifest: hook-decision 0.1.0
  ok    cases: 3 case file(s) found
  ok    marketplace: claudevs-examples
  ok    install layout: simulated at /var/folders/8w/4ccj7cw90nx4d32s72tqf5nw0000gn/T/.tmpysjv4P/cache/claudevs-examples/hook-decision/0.1.0

0 gaps, 0 warnings
```

A clean diagnosis is not a verdict on the plugin. Every probe answers whether a stage can run at all.
A plugin whose `hooks.json` points at a file that does not exist reports `0 gaps, 0 warnings` and exits
0 here, and so does a plugin whose hook breaks only once installed. `check` fails both. The
[`09_doctor_gaps`](https://github.com/airsstack/claudestacks/tree/main/crates/claudevs/examples/09_doctor_gaps)
example walks through both shades of failure and names the two examples that show the difference.

## JSON reports

Every `--json` report shares two conventions. A case's verdict is the plain string `"Pass"` or the
object `{"Fail": [mismatch, …]}`. Each mismatch is an object tagged by a `kind` field in snake_case,
for example `"decision"`, `"stdout_missing"` or `"file_missing"`.

`claudevs test --json` reports `outcomes[]` of `{name, verdict}`. The `payload` and `handler` fields
appear only on a failing hook case. It also reports `native[]` of `{command, exit, output}` for
declared native suites. This is the report for the `02_hook_decision_broken` example:

```json
{
  "outcomes": [
    {
      "name": "allows-other-files",
      "verdict": "Pass"
    },
    {
      "name": "asks-for-secrets",
      "verdict": "Pass"
    },
    {
      "name": "blocks-env-file",
      "verdict": {
        "Fail": [
          {
            "kind": "decision",
            "expected": "deny",
            "observed": null
          }
        ]
      },
      "payload": {
        "cwd": "/var/folders/8w/4ccj7cw90nx4d32s72tqf5nw0000gn/T/.tmpGomqj2",
        "hook_event_name": "PreToolUse",
        "session_id": "claudevs-test",
        "tool_input": {
          "file_path": ".env"
        },
        "tool_name": "Edit"
      },
      "handler": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/protect-env.sh\""
    }
  ],
  "native": []
}
```

`claudevs check --json` reports `stages[]` of `{name, status, detail}`. Each `status` is `passed`,
`failed` or `skipped`. The `detail` carries the same text the human renderer shows for that stage. For
`validate` that text is whatever `claude plugin validate` printed, so it changes with the installed
`claude`. This is the report for the `07_wiring_broken` example:

```json
{
  "stages": [
    {
      "name": "validate",
      "status": "passed",
      "detail": "Validating plugin manifest: /private/tmp/claudevs-ref/examples/07_wiring_broken/.claude-plugin/plugin.json\n\nPlugin directory checks for /private/tmp/claudevs-ref/examples/07_wiring_broken. The plugin directory is the catalog that plugins are submitted to; this is a subset of what it runs.\n\n✘ Found 1 problem the plugin directory refuses a submission for:\n\n  ❯ LICENSE: License missing (LICENSE_MISSING). This plugin has no LICENSE file and plugin.json has no `license`. The directory requires one of them.\n    Fix: Add a LICENSE file to the plugin folder, or set `license` (an SPDX id) in plugin.json. A LICENSE at the repository root also counts for a plugin in a sub-folder.\n\n⚠ Found 1 plugin directory warning:\n\n  ❯ .claude-plugin/plugin.json icon: No icon (ICON_MISSING). No icon found in the plugin. The validator looked for `icon` in plugin.json and for a file at .claude-plugin/icon.png or .svg, assets/icon.png or .svg, or a similar path.\n    Fix: Add a square PNG to the plugin folder at .claude-plugin/icon.png, or set `icon` in plugin.json to the path of a square PNG or JPEG in the plugin: 512 to 2048 px on each side, under 2 MB. SVG and WebP are not accepted. That file may become the listing icon only once: the first time the plugin is saved or submitted in the developer portal. Adding or changing it later does not change the icon.\n\nThese plugin directory checks do not change the result below. To fail on problems the directory refuses a submission for, run this command with --profile directory.\n\nThe directory also runs a safety scan and a policy review that this command does not.\n\nℹ Advice (does not change the verdict):\n\n  ❯ /private/tmp/claudevs-ref/examples/07_wiring_broken/README.md: This README has no line that installs \"wiring-broken\" from a marketplace. Add the install line, which works in one step on Claude Code 2.1.275 or later. Validate the folder that holds its marketplace.json to have <owner>/<repo> filled in, and the name its marketplace lists it under.\n      /plugin install wiring-broken --marketplace <owner>/<repo>\n\n✔ Validation passed\n"
    },
    {
      "name": "wiring",
      "status": "failed",
      "detail": "  error  refs  hooks/hooks.json:9  `${CLAUDE_PLUGIN_ROOT}/hooks/format-on-write.sh` does not exist\n\n1 error, 0 warnings\n"
    },
    {
      "name": "test",
      "status": "passed",
      "detail": "  ok    session-banner\n\n1 passed, 0 failed (1 cases, 0 native suites)\n"
    },
    {
      "name": "test --installed",
      "status": "passed",
      "detail": "  ok    session-banner\n\n1 passed, 0 failed (1 cases, 0 native suites)\n"
    }
  ]
}
```

`claudevs doctor --json` reports `probes[]` of `{name, status, detail}`. Each `status` is `ok`,
`warning` or `gap`:

```json
{
  "probes": [
    {
      "name": "claude binary",
      "status": "ok",
      "detail": "present; `check` delegates its validate stage"
    },
    {
      "name": "plugin manifest",
      "status": "ok",
      "detail": "hook-decision 0.1.0"
    },
    {
      "name": "cases",
      "status": "ok",
      "detail": "3 case file(s) found"
    },
    {
      "name": "marketplace",
      "status": "ok",
      "detail": "claudevs-examples"
    },
    {
      "name": "install layout",
      "status": "ok",
      "detail": "simulated at /var/folders/8w/4ccj7cw90nx4d32s72tqf5nw0000gn/T/.tmp7lzeOL/cache/claudevs-examples/hook-decision/0.1.0"
    }
  ]
}
```
