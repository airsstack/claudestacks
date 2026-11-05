# Scripts and Flows

Not everything a plugin does is a hook. A skill often tells Claude to run a script, and a script runs
in a project with files, a git repository and an environment. Two kinds of case cover that. A script
case runs one command. A flow case runs several commands in order, in one shared project.

The recipes use a plugin called `notes` with two scripts:

```text
notes/
├── .claude-plugin/plugin.json
├── scripts/
│   ├── greet.sh
│   └── new-note.sh
└── tests/
```

`scripts/greet.sh` prints a greeting for whoever `GREETING_NAME` names, and stops with a message when
the variable is missing:

```sh
#!/bin/sh
# Greets whoever GREETING_NAME names.
printf 'hello, %s\n' "${GREETING_NAME:?GREETING_NAME is required}"
```

`scripts/new-note.sh` creates `notes/<slug>.md` in the current git repository, and refuses to run
anywhere else:

```sh
#!/bin/sh
# Creates notes/<slug>.md in the current git repository.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "new-note: not inside a git repository" >&2
  exit 1
}
title="$1"
slug=$(printf '%s' "$title" | tr ' ' '-')
mkdir -p notes
printf '# %s\n' "$title" > "notes/$slug.md"
echo "created notes/$slug.md"
```

The scripts need `git` on your `PATH`, because `new-note.sh` calls it and the flow below starts a git
repository.

## Test a script with its environment

A script case has an `invocation` instead of an `event`. `tests/greets-by-name.yaml` runs `greet.sh`
with one environment variable set:

```yaml
invocation:
  argv: [sh, -c, 'sh "$CLAUDE_PLUGIN_ROOT/scripts/greet.sh"']
  env:
    GREETING_NAME: claudevs
expect:
  exit: 0
  stdout_contains: hello, claudevs
```

```console
$ claudevs test
```

```text
  ok    greets-by-name

1 passed, 0 failed (1 cases, 0 native suites)
```

`argv` is the program and its arguments. It is spawned directly, with no shell, so `$CLAUDE_PLUGIN_ROOT`
in a bare argument stays as typed. This case starts `sh -c` itself so that the variable is expanded. The
child runs in the case's temporary project, and its environment holds your own environment plus
`CLAUDE_PLUGIN_ROOT` (the plugin directory), `CLAUDE_PROJECT_DIR` (the temporary project) and every
`env` entry the case sets.

`{project}` in any `argv` or `env` value is replaced with the path of the temporary project before the
child starts. Use it when a script takes the project as an argument.

A script case can assert `exit`, `stdout_contains`, `stderr_contains` and `files_exist`. It cannot
assert `output: none`. That check is for hooks, and a script or flow case that sets it fails to load.
The message says the expectation is a hook assertion.

The [example](https://github.com/airsstack/claudestacks/tree/main/crates/claudevs/examples/04_script_and_flow)
adds a skill that documents both scripts.

## Test a multi-step flow in a project

A flow case has `steps`. `tests/new-note-flow.yaml` creates a note, then adds a second one from a
fixture, then lists the result:

```yaml
project: notes-repo
steps:
  - run:
      argv: [sh, -c, 'sh "$CLAUDE_PLUGIN_ROOT/scripts/new-note.sh" "first note"']
    expect:
      exit: 0
      stdout_contains: created notes/first-note.md
  - apply_fixture: imported-notes
  - run:
      argv: [ls, notes]
expect:
  exit: 0
  stdout_contains: imported.md
  files_exist:
    - notes/first-note.md
    - notes/imported.md
```

The case needs two fixture directories under `tests/fixtures/`. A fixture is a directory that is copied
into the project:

```text
tests/fixtures/
├── notes-repo/
│   ├── .gitinit
│   └── README.md
└── imported-notes/
    └── notes/
        └── imported.md
```

`.gitinit` is an empty marker file. It makes claudevs run `git init` in the copy and make one commit,
and the marker itself is not copied. `README.md` contains `# Notes repository`, and `imported.md`
contains `# Imported note`. Anything under `tests/fixtures/` is data and is never read as a case.

```console
$ claudevs test
```

```text
  ok    greets-by-name
  ok    new-note-flow

2 passed, 0 failed (2 cases, 0 native suites)
```

`project: notes-repo` seeds one project, and every step shares it. A `run` step can carry its own
`expect`, and that expectation must hold for the flow to continue. When one fails, the flow stops there
and later steps do not run. `apply_fixture` copies another fixture directory over the same project
without running anything. The top-level `expect` is judged against the last `run` step, and its
`files_exist` paths are relative to the project.

Without a `project:` field, a case runs in a default project: a git repository with a minimal
`Cargo.toml` and one committed file, `file.txt`.
