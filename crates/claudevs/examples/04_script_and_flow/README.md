# 04 — Script and flow

Cases that run commands rather than hooks: a script case, and a flow of several steps in one project.

The plugin has two scripts, and `skills/notes/SKILL.md` documents both:

- `scripts/greet.sh` prints `hello, <name>` using `GREETING_NAME`.
- `scripts/new-note.sh` creates `notes/<slug>.md` and refuses to run outside a git repository.

## Script case

`tests/greets-by-name.yaml` spawns `invocation.argv` directly, without a shell, from a fresh temporary
project directory. The child's environment carries `CLAUDE_PLUGIN_ROOT`, `CLAUDE_PROJECT_DIR` and every
`invocation.env` entry. Because no shell is involved, the case runs `sh -c` itself to expand
`$CLAUDE_PLUGIN_ROOT`.

## Flow

`tests/new-note-flow.yaml` runs its `steps` in order, in one shared project:

1. `project: notes-repo` seeds the project from `tests/fixtures/notes-repo/`. That fixture carries a
   `.gitinit` marker, so claudevs runs `git init` and makes one empty commit in the copy, and leaves the
   marker out.
2. The first step runs `new-note.sh`. Its own `expect` must hold for the flow to continue.
3. `apply_fixture: imported-notes` copies `tests/fixtures/imported-notes/` over the project.
4. The last step lists `notes/`.

The top-level `expect` is judged against the last step that ran, and `files_exist` paths are relative
to the project. Directories under `tests/fixtures/` hold data and are never read as cases.

## Run it

```console
$ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/04_script_and_flow
```

```text
  ok    validate
        …
  ok    wiring
        0 errors, 0 warnings
  ok    test
          ok    greets-by-name
          ok    new-note-flow
        2 passed, 0 failed (2 cases, 0 native suites)
  ok    test --installed
          ok    greets-by-name
          ok    new-note-flow
        2 passed, 0 failed (2 cases, 0 native suites)

4 stages run, 0 failed, 0 skipped
```

The exit code is 0.
