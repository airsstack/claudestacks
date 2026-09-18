# claudevs CLI reference

## Commands

```text
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
Usage: claudevs test [OPTIONS] [PATH]

Arguments:
  [PATH]  The plugin directory [default: .]

Options:
      --case <CASE>  Only run cases whose name contains this substring
      --installed    Run against a throwaway copy in the installed cache layout
      --json         Emit the machine-readable report instead of the human one
  -h, --help         Print help
```

### check

Validate, check wiring, then run the suite in both layouts.

```text
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
Usage: claudevs migrate [OPTIONS] <FILE>

Arguments:
  <FILE>  The YAML case file

Options:
      --write  Replace the .yaml file with the .lua file instead of printing
  -h, --help   Print help
```

## Exit codes

| Command | 0 | 1 | 2 |
|---|---|---|---|
| `test` | Every case passed and every declared native suite exited 0. | At least one case failed — including a case file that could not be loaded, which is reported as one failed case rather than aborting the run — or a native suite exited non-zero. | claudevs itself could not run: a usage error, a plugin path that does not resolve, no case files found under `tests/`, a Lua case file that does not load or does not return a table, a `hooks/hooks.json` that is not valid JSON, or a declared native suite that could not be started. |
| `check` | No stage failed; a skipped stage does not count against it. | At least one stage failed. | The plugin path is not a directory, or some other error a stage does not turn into a skip or a failure. |
| `doctor` | No probe reports a gap. | A probe reports a gap; a warning alone never produces this. | Only when `--json` cannot render the report — which the report types this crate emits never cause in practice. |
| `migrate` | The case printed, or was written with `--write`. | — | The file is not a loadable YAML case, or writing or removing a file failed. |

## Case discovery

Case files are found under `<plugin>/tests/`, walked recursively in sorted order. A `.yaml` or `.yml` file is one case, named by its file stem. A file named `*_test.lua` or `test_*.lua` returns a table of named cases. Anything under `tests/fixtures/` is fixture data, never a case. Finding no case files at all is an error, not a green suite.

A case name — the file stem for YAML, the table key for Lua — must be non-empty and use only `A-Z`, `a-z`, `0-9`, `.`, `_` and `-`.

## Case fields

**Common to every case:**

| Field | Meaning |
|---|---|
| `project` | The fixture to materialize as the temp project — a bare name or `fixture: <name>` — instead of the default project. |
| `expect` | Judged after the run for a hook or script case, or after the last step for a flow case. |

**Kind-specific fields** — a case is exactly one of hook, script or flow:

| Kind | Field | Meaning |
|---|---|---|
| Hook | `event` | One of `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `SessionStart`, `SessionEnd`. |
| Hook | `hook` | An optional substring that disambiguates which `hooks.json` handler this case targets, when more than one survives matcher filtering. |
| Hook | `payload` | An object overlaid on the event's built-in default payload — objects merge recursively field by field, any other value replaces its counterpart outright. |
| Hook | `payload_raw` | Raw stdin text sent verbatim instead of a JSON payload, for hostile-input cases; mutually exclusive with `payload`. |
| Script | `invocation.argv` | The program and arguments to spawn. |
| Script | `invocation.env` | Extra environment variables for the child. |
| Flow | `steps` | A sequence of steps run in one shared project. |

A flow step is exactly one of `run` (an invocation) or `apply_fixture` (a fixture name to overlay into the shared project), plus an optional `expect` that only applies to a `run` step. A step whose expectation fails stops the flow right there. The case's top-level `expect` is judged against the last `run` step's observation; a flow made of `apply_fixture` steps alone has nothing to judge but `files_exist`, and any other expectation on such a flow fails rather than passing vacuously.

`{project}` in `invocation.argv` and `invocation.env` is substituted with the temp project's path at run time.

**`expect` fields:**

| Field | Meaning |
|---|---|
| `exit` | The exact exit code expected. |
| `decision` | One of `allow`, `deny`, `ask`, `defer`. |
| `output` | Only accepts `"none"`: the hook must emit no envelope and no context at all. This is a hook-only assertion — asserting it on a script or flow case is rejected at load time, since only a hook observation records whether anything was emitted. |
| `context_contains` | A substring the injected context must contain. |
| `stdout_contains` | A substring stdout must contain. |
| `stderr_contains` | A substring stderr must contain. |
| `files_exist` | Paths, relative to the temp project, that must exist once the run finishes. |

Every expectation present on a case is checked, and a failing case lists every mismatch rather than stopping at the first. Unknown fields are rejected — in cases, invocations, flow steps and `expect` blocks alike — rather than silently ignored.

## Case load errors

The following messages are reported verbatim when a case fails to load:

```text
a case is exactly one of hook (`event:`), script (`invocation:`) or flow (`steps:`); found N
`payload` and `payload_raw` are mutually exclusive
flow step N: exactly one of `run` or `apply_fixture`
`expect.output` only accepts "none", got `VALUE`
`expect.output` is a hook assertion: only a hook observation records whether anything was emitted, so this expectation could never fail here
unknown hook event `NAME` (known: PreToolUse, PostToolUse, UserPromptSubmit, SessionStart, SessionEnd)
invalid case name `NAME`: names are non-empty [A-Za-z0-9._-]
```

An unrecognized field name reports the exact field alongside every field the case shape does accept, for example: ``unknown field `expct`, expected one of `event`, `hook`, `payload`, `payload_raw`, `invocation`, `steps`, `project`, `expect` ``.

## Default payloads

The built-in default payload for `PreToolUse` (and `PostToolUse`, which shares the same shape):

```json
{
  "session_id": "claudevs-test",
  "cwd": "{project}",
  "hook_event_name": "PreToolUse",
  "tool_name": "Edit",
  "tool_input": { "file_path": "{project}/file.txt" }
}
```

`UserPromptSubmit` adds `"prompt": "hello"`; `SessionStart` adds `"source": "startup"`; `SessionEnd` adds `"reason": "exit"`. A case's `payload` overlay merges onto this default (objects merge recursively, other values replace), and `{project}` in any string — default or overlay alike — is replaced with the temp project's actual path before the payload is sent.

## How a hook run is read

A hook's stdout may carry a JSON envelope communicating a decision through any of three shapes, read most-specific-first (the reference states no precedence between them; this order is claudevs' own choice): `hookSpecificOutput.permissionDecision` (`allow`/`deny`/`ask`/`defer`), then `hookSpecificOutput.decision.behavior` (`allow`/`deny`), then a top-level `decision` string, which spells denial `"block"` rather than `"deny"`. Whichever of these is present, the hook counts as having emitted something, whether or not its value is one this reads as a decision.

Separately from any envelope, a `PreToolUse` hook that exits `2` is read as a denial.

`hookSpecificOutput.additionalContext` carries injected context, read independently of which decision shape (if any) accompanied it. When no envelope is present at all, bare stdout is read as injected context only for the events whose bare output Claude Code actually surfaces — of the five events claudevs can simulate, that is `SessionStart` and `UserPromptSubmit`; a `PreToolUse` or `PostToolUse` hook's bare stdout is not context, and neither is a `SessionEnd` hook's.

## What a spawned command gets

The child's working directory is the case's temp project. Its environment is the process's own environment plus `CLAUDE_PLUGIN_ROOT` (the plugin directory) and `CLAUDE_PROJECT_DIR` (the temp project), with a script invocation's own `env` entries layered on top.

A `hooks.json` handler is one of two execution models. A `command` alone is a shell handler, run through `sh -c`, so its string may use pipelines, redirection and expansion. A `command` paired with `args` is an exec handler, spawned directly with no shell at all — each `args` element is one argument exactly as written, with no tokenization on any platform.

Every spawned child is subject to a 30-second timeout; a child still running past it is killed and the case fails with `timeout: the child timed out and was killed before completing`.

## Projects and fixtures

Without a `project:` field, a case runs against the default project: a git repository carrying a minimal `Cargo.toml` manifest and one tracked, committed file (`file.txt`) — the same file the default `PreToolUse`/`PostToolUse` payload points its `tool_input.file_path` at.

`project: <name>` (or `project: { fixture: <name> }`) copies `tests/fixtures/<name>/` into a fresh temp directory instead. A `.gitinit` file inside that fixture triggers a `git init` plus one commit (empty unless the fixture also carries tracked content) once copied, and the marker file itself is never copied into the project. A flow's `apply_fixture` step (and the Lua `t.apply_fixture`) copies a fixture over an already-materialized project rather than starting a fresh one.

## Lua cases

A `*_test.lua` file returns a table whose entries are either data cases (tables, parsed the same way a YAML case is) or scripted cases (functions). A scripted case runs by calling its function with the harness handle `t`; it passes by returning without raising.

`t`'s functions:

| Function | Returns |
|---|---|
| `t.fixture(name)` | The path of a fresh temp project seeded from the named fixture. |
| `t.project()` | The path of a fresh, empty temp project (the same default project a caseless `project:` would build). |
| `t.apply_fixture(name, dir)` | Overlays the named fixture into `dir`. |
| `t.hook(ref, payload?)` | Runs a hook and returns `{exit, stdout, stderr, decision?, context?, emitted}`. `ref` is either an event name or a substring of a handler's command that is unique across every event's wiring. |
| `t.script(argv, opts?)` | Runs `argv` directly and returns `{exit, stdout, stderr}`. `opts.env` adds environment, `opts.cwd` sets the working directory (defaulting to the plugin directory), `opts.stdin` feeds stdin. |
| `t.skill_command(skill, n)` | The text of the `n`-th fenced command (1-based, in document order) in `skills/<skill>/SKILL.md`. |
| `t.json(path)` | The decoded contents of a JSON file. |

`t.json`'s path and `t.script`'s `cwd` must resolve inside the plugin directory or a temp project the case itself created; `t.apply_fixture`'s `dir` must resolve inside a temp project only, never the plugin directory; `t.skill_command`'s resolved path must stay inside the plugin directory. Only the Lua itself runs confined with no grants — it cannot reach the sandboxed filesystem or process modules directly. The `t` handle is not part of that sandbox: every function on it runs host-side, and `t.script` can spawn any program with the ambient environment. A `*_test.lua` file is trusted code, on the same footing as a shell script the author runs locally.

## claudevs.toml

A plugin may declare native suites claudevs delegates to, rather than run itself:

```toml
[[native]]
run = "airsl test --policy confined ."
```

Each `run` is spawned as `sh -c` in the plugin directory. Only the exit code is asserted; the combined stdout and stderr are captured and shown only when the exit code is non-zero. No `claudevs.toml` file means no native suites at all. An entry carrying any key other than `run` is an error.

## check stages

`check` runs four stages in order, and a failure in one does not stop the ones that follow:

| Stage | What it runs | Skipped when | Fails when |
|---|---|---|---|
| `validate` | `claude plugin validate [--strict] <path>`, delegated to the installed `claude` binary. | The `claude` binary cannot run. | The delegate exits non-zero. |
| `wiring` | The three wiring checkers below. | Never. | Any checker reports an error-severity finding. |
| `test` | The case suite, in the source checkout. | No case files exist, no marketplace manifest is found above the plugin, or the environment cannot build a temp project. | A case or declared native suite fails, or the plugin manifest cannot be read. |
| `test --installed` | The case suite again, against a throwaway copy in the simulated installed layout. | Same conditions as `test`. | Same conditions as `test`. |

Each stage is marked `ok`, `FAIL`, or `skip` in the human output, followed by a summary line of the form `N stages run, N failed, N skipped`, where a skipped stage does not count toward the number run.

## Wiring checkers

Three static checkers, run in this order, each producing findings rather than running anything:

| Checker | Severity | Reports | Message |
|---|---|---|---|
| `refs` | error | Every `${CLAUDE_PLUGIN_ROOT}/…` reference in `.claude-plugin/*.json` and under `hooks/`, `skills/`, `agents/` and `commands/` (outside fenced code blocks) that either does not resolve to a file in the plugin, or escapes the plugin root via a `..` segment. The unbraced form `$CLAUDE_PLUGIN_ROOT` (no braces) is not scanned. | ``` `${CLAUDE_PLUGIN_ROOT}/PATH` does not exist ``` or ``` `${CLAUDE_PLUGIN_ROOT}/PATH` escapes the plugin root ``` |
| `invocations` | warning | A `.sh`, `.lua`, `.py` or `.js` file that presents as executable (a shebang, an executable bit, or anything under `hooks/`) but is named by nothing else in the plugin — by filename, by module stem, or from inside a fenced command. Case files, anything under `tests/`, and language index files (`__init__.py`, `index.js`, `init.lua`) are exempt. | ``` `NAME` is referenced by nothing in this plugin ``` |
| `matchers` | error/warning | `hooks/hooks.json` that is not JSON, or has no top-level `hooks` object, is an error. An event name the catalogue does not document, a matcher written on an event that takes none, or a matcher claudevs cannot evaluate as a regular expression are each a warning. | Varies per finding; see the source messages. |

The human rendering is one line per finding — `  error  CHECKER  FILE[:LINE]  MESSAGE` or `  warn   CHECKER  FILE[:LINE]  MESSAGE` — followed by a summary line of the form `N error(s), N warning(s)`.

## doctor probes

`doctor` runs five probes, in order, each reusing the same code the corresponding `check` stage would run rather than guessing at the environment:

| Probe | Checks | Status it can take |
|---|---|---|
| `claude binary` | Whether the `claude` binary can be delegated to for the `validate` stage. | `ok` when reachable; `gap` when absent. |
| `plugin manifest` | Whether `<plugin>/.claude-plugin/plugin.json` can be read and names a usable `name` and `version`. | `ok` or `gap`. |
| `cases` | Whether any case files can be discovered under `tests/`. | `ok` when at least one is found; `warning` when none are — a plugin with no cases yet is incomplete, not broken. |
| `marketplace` | Whether a `.claude-plugin/marketplace.json` can be found by walking up from the plugin. | `ok` or `gap`. |
| `install layout` | Whether the simulated installed-cache layout can be materialized. | `ok` or `gap`. |

Each probe is marked `ok`, `warn`, or `gap` in the human output, followed by a summary line of the form `N gaps, N warnings`. A `gap` fails the overall diagnosis; a `warning` alone never does.

A clean diagnosis is not a verdict on the plugin. Every probe answers whether a stage can run at all, so a plugin whose `hooks.json` points at a file that does not exist, or whose hook breaks only once installed, reports `0 gaps, 0 warnings` and exit 0 here while `check` fails it. `examples/09_doctor_gaps` walks through both shades of failure and names the two examples that show the difference.

## JSON reports

Every `--json` report shares two conventions: a case's verdict serializes as the plain string `"Pass"` or as `{"Fail": [mismatch, …]}`, and each mismatch is an object tagged by a `kind` field in snake_case (for example `"decision"`, `"stdout_missing"`, `"file_missing"`).

`claudevs test --json` reports `outcomes[]` of `{name, verdict}`, with `payload` and `handler` present only on a failing hook case, plus `native[]` of `{command, exit, output}` for declared native suites:

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
        "cwd": "…",
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

`claudevs check --json` reports `stages[]` of `{name, status, detail}`, `detail` carrying the same text the human renderer would have shown for that stage:

```json
{
  "stages": [
    {
      "name": "validate",
      "status": "passed",
      "detail": "Validating plugin manifest: …/07_wiring_broken/.claude-plugin/plugin.json\n\n✔ Validation passed\n"
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

`claudevs doctor --json` reports `probes[]` of `{name, status, detail}`:

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
      "detail": "simulated at …/cache/claudevs-examples/hook-decision/0.1.0"
    }
  ]
}
```
