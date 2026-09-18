---
status: done
created: 2026-09-13
---

# claudevs Example Plugins Implementation Plan

**Goal:** Build eight example plugins under `crates/claudevs/examples/`, each verified by
`crates/claudevs/tests/examples.rs` against the `claudevs check` outcome its README documents.

**Architecture:** Every example is a plugin root (`.claude-plugin/plugin.json`, `hooks/`, `tests/`, `README.md`) run through the `claudevs` binary, never a Cargo target. The examples share one marketplace manifest at `crates/claudevs/examples/.claude-plugin/marketplace.json`, which keys their installed path as `cache/claudevs-examples/<plugin>/<version>/`. It is what makes that path the examples' own rather than the repository's: removing it does not make `test --installed` skip here, because the lookup walks ancestors and finds the repo-root `.claude-plugin/marketplace.json` (`name: claudestacks`) instead — verified 2026-09-18 by moving the directory aside and re-running `claudevs check` on an example, which still resolved to the repo-root marketplace and `test --installed` still passed. A plugin with no marketplace in any ancestor does skip, which is the case `08_installed_broken`'s README describes. Each example's correctness is asserted from Rust, not from the fixture corpus's shell lane: `crates/claudevs/tests/examples.rs` (Task 10) walks `crates/claudevs/examples/*/`, runs `claudevs::check::run` on each, and compares the typed stage outcomes against the expectation its README documents. `Makefile.toml` and `cargo make claudevs-check` are untouched by this chain and keep testing `crates/claudevs/tests/fixtures/` alone (spec §4.1, §8 amendment of 2026-09-18).

**Tech Stack:** POSIX `sh` hook scripts, YAML and Lua case files, `claudevs.toml`, a Rust integration test.

**Content authority:** `spec.md` §3 (example plugins), §4.1 (example gate), §5 second bullet (root `CLAUDE.md`), §6 (wording rules for shipped text).

---

## File structure

```
crates/claudevs/examples/README.md                         — [create] index table, how to run, why the marketplace manifest and shared/ exist
crates/claudevs/examples/.claude-plugin/marketplace.json   — [create] marketplace manifest the installed layout is keyed by
crates/claudevs/examples/shared/policy-message.txt         — [create] file 08_installed_broken reaches outside its root for
crates/claudevs/examples/01_hook_decision/**               — [create] PreToolUse gate + YAML hook cases
crates/claudevs/examples/02_hook_decision_broken/**        — [create] same gate with a defect; FAIL test
crates/claudevs/examples/03_session_context/**             — [create] SessionStart/UserPromptSubmit context cases
crates/claudevs/examples/04_script_and_flow/**             — [create] script case + flow with fixtures
crates/claudevs/examples/05_lua_cases/**                   — [create] data and scripted Lua cases, migrate
crates/claudevs/examples/06_native_suite/**                — [create] claudevs.toml [[native]]
crates/claudevs/examples/07_wiring_broken/**               — [create] dangling ${CLAUDE_PLUGIN_ROOT} reference; FAIL wiring
crates/claudevs/examples/08_installed_broken/**            — [create] hook reads above the plugin root; FAIL test --installed
crates/claudevs/tests/examples.rs                          — [create] runs claudevs::check::run on every example, asserts its README's outcome
```

Every command runs from the worktree root. Two commands recur:

- **One example:** `cargo run -q -p claudevs-cli -- check crates/claudevs/examples/<name>; echo "exit=$?"`.
- **The example gate:** `cargo test -p claudevs --test examples --all-features`. It runs `claudevs::check::run` on all eight examples in one process and panics naming the example and stage that diverged from its README (`crates/claudevs/tests/examples.rs`, built in Task 10).

Expected outputs below come from runs of scratch copies of these files (identical except that 04's `tests/fixtures/notes-repo/README.md` and 08's reworded script comment were added afterwards; neither is read by any case) on a machine with `claude` 2.1.270 on `PATH`. The `validate` detail lines hold a machine-specific absolute path and are shown as `…`. Without `claude` on `PATH`, the first stage prints `  skip  validate` followed by ``cannot run `claude`: No such file or directory (os error 2)``, the summary counts one stage fewer and one skipped, and the exit code and every other stage line are unchanged. That was run for all eight examples with `env PATH=/usr/bin:/bin target/debug/claudevs check …`.

**Rules for every README and script comment in `crates/claudevs/examples/`** (spec §6): no `file:line` citations; none of the development vocabulary banned in `crates/clauders/CLAUDE.md:150-160`; quoted output is pasted from the run in the same task, with temp paths and the validate detail elided as `…`. Task 13 greps for both.

**Commits:** the `execute` skill reserves committing to the user. The final task gives a suggested message; no task runs `git commit`.

### Task 1 — Withdrawn: the claudevs-check lane does not take example plugin paths

This task set out to make `cargo make claudevs-check` take full plugin paths so the example plugins
could share the fixtures' `_run` function, asserted through a new `expect_example`. That merge was the
error, on the reading that the fixtures and the examples ask the same question. They do not: the
fixtures are test data for claudevs, four of the eight built to fail so the lane can prove the checkers
still report, while the examples are teaching material, and the only thing that has to stay true of one
is that the run its README shows still produces what the README says.

Putting both in `Makefile.toml` made the examples' correctness a shell assertion over grepped output.
Executing this plan showed the cost twice in one session: a skipped stage passed the lane silently, and
the assertion added to catch it grew two more shell functions.

`Makefile.toml` is not modified by this chain and keeps testing `crates/claudevs/tests/fixtures/`
alone, exactly as before this plan started. Task 10 verifies the examples from Rust instead, where a
stage outcome is a typed value rather than text to grep (spec §4.1, §8 amendment of 2026-09-18).

### Task 2 — Add 01_hook_decision and the examples marketplace manifest

**Files:**
- Create `crates/claudevs/examples/.claude-plugin/marketplace.json`
- Create `crates/claudevs/examples/01_hook_decision/.claude-plugin/plugin.json`
- Create `crates/claudevs/examples/01_hook_decision/hooks/hooks.json`
- Create `crates/claudevs/examples/01_hook_decision/hooks/protect-env.sh`
- Create `crates/claudevs/examples/01_hook_decision/tests/blocks-env-file.yaml`
- Create `crates/claudevs/examples/01_hook_decision/tests/asks-for-secrets.yaml`
- Create `crates/claudevs/examples/01_hook_decision/tests/allows-other-files.yaml`
- Create `crates/claudevs/examples/01_hook_decision/README.md`

**Steps:**

1. Create `crates/claudevs/examples/.claude-plugin/marketplace.json`:

   ```json
   {
     "name": "claudevs-examples",
     "owner": { "name": "rstlix0x0" },
     "description": "Example plugins for the claudevs documentation; not a real marketplace.",
     "plugins": []
   }
   ```

2. Create `crates/claudevs/examples/01_hook_decision/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "hook-decision",
     "version": "0.1.0",
     "description": "claudevs example: a PreToolUse gate asserted with YAML hook cases",
     "author": { "name": "rstlix0x0" }
   }
   ```

3. Create `crates/claudevs/examples/01_hook_decision/hooks/hooks.json`:

   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Edit|Write",
           "hooks": [
             { "type": "command", "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/protect-env.sh\"" }
           ]
         }
       ]
     }
   }
   ```

4. Create `crates/claudevs/examples/01_hook_decision/hooks/protect-env.sh`:

   ```sh
   #!/bin/sh
   # Refuses edits to .env files and asks before touching anything under secrets/.
   # Every other path passes silently.
   payload=$(cat)
   case "$payload" in
     *'"file_path":"'*'.env"'*)
       echo "protect-env: refusing to edit a .env file" >&2
       exit 2
       ;;
     *'"file_path":"secrets/'*|*'/secrets/'*)
       printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"protect-env: files under secrets/ need confirmation"}}'
       ;;
   esac
   exit 0
   ```

5. Create `crates/claudevs/examples/01_hook_decision/tests/blocks-env-file.yaml`:

   ```yaml
   event: PreToolUse
   payload:
     tool_input:
       file_path: .env
   expect:
     decision: deny
     stderr_contains: refusing to edit a .env file
   ```

6. Create `crates/claudevs/examples/01_hook_decision/tests/asks-for-secrets.yaml`:

   ```yaml
   event: PreToolUse
   payload:
     tool_name: Write
     tool_input:
       file_path: secrets/api-key.txt
   expect:
     decision: ask
   ```

7. Create `crates/claudevs/examples/01_hook_decision/tests/allows-other-files.yaml`:

   ```yaml
   event: PreToolUse
   expect:
     exit: 0
     output: none
   ```

8. Run the example:

   ```
   $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/01_hook_decision; echo "exit=$?"
   ```

   Expected:

   ```text
     ok    validate
           …
     ok    wiring
           0 errors, 0 warnings
     ok    test
             ok    allows-other-files
             ok    asks-for-secrets
             ok    blocks-env-file
           3 passed, 0 failed (3 cases, 0 native suites)
     ok    test --installed
             ok    allows-other-files
             ok    asks-for-secrets
             ok    blocks-env-file
           3 passed, 0 failed (3 cases, 0 native suites)

   4 stages run, 0 failed, 0 skipped
   exit=0
   ```

9. Create `crates/claudevs/examples/01_hook_decision/README.md`, pasting the output block from step 8's run (behaviour sources: exit 2 and `permissionDecision` both read as a decision, `semantics.rs:104-115,128-131`; a case's payload is laid over a per-event default, `payload.rs:14-34`, `suite.rs:310-316`):

    ````markdown
    # 01 — Hook decision

    A `PreToolUse` hook that guards `.env` files, tested with YAML hook cases.

    `hooks/protect-env.sh` reads the tool call as JSON on stdin. It refuses an edit to a `.env` file by
    exiting 2 with a message on stderr, asks for confirmation before anything under `secrets/` is touched
    by printing a `permissionDecision` of `ask`, and stays silent otherwise.

    | Case | Payload | Asserts |
    |---|---|---|
    | `tests/blocks-env-file.yaml` | `tool_input.file_path` set to `.env` | `decision: deny`, `stderr_contains` |
    | `tests/asks-for-secrets.yaml` | `tool_name` and `tool_input.file_path` set | `decision: ask` |
    | `tests/allows-other-files.yaml` | the default `PreToolUse` payload | `exit: 0`, `output: none` |

    A case asserts what the hook means rather than how it says it. On `PreToolUse`, exit code 2 and a
    JSON `permissionDecision` both read as a decision. The `payload` a case gives is laid over a default
    payload for its event, so a case names only the fields it cares about.

    ## Run it

    From the repository root:

    ```console
    $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/01_hook_decision
    ```

    ```text
    <paste step 8's output here, validate detail as …, without the exit= line>
    ```

    The exit code is 0.
    ````

    Replace the `<paste …>` line with the real output before saving; the finished file contains no angle-bracket placeholder.

### Task 3 — Add 02_hook_decision_broken and prove its expectation can fail

**Files:**
- Create `crates/claudevs/examples/02_hook_decision_broken/.claude-plugin/plugin.json`
- Create `crates/claudevs/examples/02_hook_decision_broken/hooks/hooks.json`
- Create `crates/claudevs/examples/02_hook_decision_broken/hooks/protect-env.sh`
- Create `crates/claudevs/examples/02_hook_decision_broken/tests/blocks-env-file.yaml`
- Create `crates/claudevs/examples/02_hook_decision_broken/tests/asks-for-secrets.yaml`
- Create `crates/claudevs/examples/02_hook_decision_broken/tests/allows-other-files.yaml`
- Create `crates/claudevs/examples/02_hook_decision_broken/README.md`

**Steps:**

1. Create `crates/claudevs/examples/02_hook_decision_broken/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "hook-decision-broken",
     "version": "0.1.0",
     "description": "claudevs example: the hook-decision gate with a defect its cases catch",
     "author": { "name": "rstlix0x0" }
   }
   ```

2. Create `crates/claudevs/examples/02_hook_decision_broken/hooks/hooks.json`:

   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Edit|Write",
           "hooks": [
             { "type": "command", "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/protect-env.sh\"" }
           ]
         }
       ]
     }
   }
   ```

3. Create `crates/claudevs/examples/02_hook_decision_broken/hooks/protect-env.sh`. It is Task 2's script with `exit 2` changed to `exit 1` on the `.env` branch:

   ```sh
   #!/bin/sh
   # Refuses edits to .env files and asks before touching anything under secrets/.
   # Every other path passes silently.
   payload=$(cat)
   case "$payload" in
     *'"file_path":"'*'.env"'*)
       echo "protect-env: refusing to edit a .env file" >&2
       exit 1
       ;;
     *'"file_path":"secrets/'*|*'/secrets/'*)
       printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"protect-env: files under secrets/ need confirmation"}}'
       ;;
   esac
   exit 0
   ```

4. Create `crates/claudevs/examples/02_hook_decision_broken/tests/blocks-env-file.yaml`:

   ```yaml
   event: PreToolUse
   payload:
     tool_input:
       file_path: .env
   expect:
     decision: deny
     stderr_contains: refusing to edit a .env file
   ```

5. Create `crates/claudevs/examples/02_hook_decision_broken/tests/asks-for-secrets.yaml`:

   ```yaml
   event: PreToolUse
   payload:
     tool_name: Write
     tool_input:
       file_path: secrets/api-key.txt
   expect:
     decision: ask
   ```

6. Create `crates/claudevs/examples/02_hook_decision_broken/tests/allows-other-files.yaml`:

   ```yaml
   event: PreToolUse
   expect:
     exit: 0
     output: none
   ```

7. Run the example:

   ```
   $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/02_hook_decision_broken; echo "exit=$?"
   ```

   Expected (temp directory in `cwd` shown as `…`):

   ```text
     ok    validate
           …
     ok    wiring
           0 errors, 0 warnings
     FAIL  test
             ok    allows-other-files
             ok    asks-for-secrets
             FAIL  blocks-env-file
                   decision: expected Deny, got None
                   payload: {"cwd":"…","hook_event_name":"PreToolUse","session_id":"claudevs-test","tool_input":{"file_path":".env"},"tool_name":"Edit"}
                   handler: sh "${CLAUDE_PLUGIN_ROOT}/hooks/protect-env.sh"
           2 passed, 1 failed (3 cases, 0 native suites)
     FAIL  test --installed
             ok    allows-other-files
             ok    asks-for-secrets
             FAIL  blocks-env-file
                   decision: expected Deny, got None
                   payload: {"cwd":"…","hook_event_name":"PreToolUse","session_id":"claudevs-test","tool_input":{"file_path":".env"},"tool_name":"Edit"}
                   handler: sh "${CLAUDE_PLUGIN_ROOT}/hooks/protect-env.sh"
           2 passed, 1 failed (3 cases, 0 native suites)

   4 stages run, 2 failed, 0 skipped
   exit=1
   ```

8. Create `crates/claudevs/examples/02_hook_decision_broken/README.md`, pasting step 7's output (sources: `semantics.rs:104-115,128-131` for what reads as a decision; `suite.rs:38-47` for payload and handler printed only on a failing hook case; `check.rs:108-116` for both suite stages running the same cases):

    ````markdown
    # 02 — Hook decision, broken

    The plugin from [`01_hook_decision`](../01_hook_decision/README.md) with one defect, to show what a
    failing case reports.

    ## What is wrong

    `hooks/protect-env.sh` exits 1 on the `.env` branch instead of 2. claudevs reads a `PreToolUse`
    denial from exit code 2 or from a JSON decision on stdout. Exit code 1 is neither, so the hook still
    prints its message but communicates no decision, and `tests/blocks-env-file.yaml`, which asserts
    `decision: deny`, fails.

    The `test` stage reports it, and so does `test --installed`, because both stages run the same cases.

    ## Run it

    ```console
    $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/02_hook_decision_broken
    ```

    ```text
    <paste step 7's output here, validate detail and cwd as …, without the exit= line>
    ```

    The exit code is 1. A failing hook case prints the payload the hook received and the handler that
    ran, which tells you which branch the hook took. Change `exit 1` to `exit 2` in the script and the
    run ends at 0.
    ````

    Replace the `<paste …>` line with the real output before saving.

### Task 4 — Add 03_session_context

**Files:**
- Create `crates/claudevs/examples/03_session_context/.claude-plugin/plugin.json`
- Create `crates/claudevs/examples/03_session_context/hooks/hooks.json`
- Create `crates/claudevs/examples/03_session_context/hooks/session-banner.sh`
- Create `crates/claudevs/examples/03_session_context/hooks/deploy-reminder.sh`
- Create `crates/claudevs/examples/03_session_context/tests/session-start-injects-banner.yaml`
- Create `crates/claudevs/examples/03_session_context/tests/deploy-prompt-gets-reminder.yaml`
- Create `crates/claudevs/examples/03_session_context/tests/ordinary-prompt-stays-silent.yaml`
- Create `crates/claudevs/examples/03_session_context/README.md`

**Steps:**

1. Create `crates/claudevs/examples/03_session_context/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "session-context",
     "version": "0.1.0",
     "description": "claudevs example: context injected at SessionStart and UserPromptSubmit",
     "author": { "name": "rstlix0x0" }
   }
   ```

2. Create `crates/claudevs/examples/03_session_context/hooks/hooks.json`:

   ```json
   {
     "hooks": {
       "SessionStart": [
         { "hooks": [ { "type": "command", "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/session-banner.sh\"" } ] }
       ],
       "UserPromptSubmit": [
         { "hooks": [ { "type": "command", "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/deploy-reminder.sh\"" } ] }
       ]
     }
   }
   ```

3. Create `crates/claudevs/examples/03_session_context/hooks/session-banner.sh`:

   ```sh
   #!/bin/sh
   # Plain stdout from a SessionStart hook becomes context for the session.
   echo "session-banner: run the test suite before you commit"
   ```

4. Create `crates/claudevs/examples/03_session_context/hooks/deploy-reminder.sh`:

   ```sh
   #!/bin/sh
   # Adds a reminder when the prompt mentions a deploy; says nothing otherwise.
   payload=$(cat)
   case "$payload" in
     *deploy*)
       printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"deploy-reminder: production deploys need a change ticket"}}'
       ;;
   esac
   exit 0
   ```

5. Create `crates/claudevs/examples/03_session_context/tests/session-start-injects-banner.yaml`:

   ```yaml
   event: SessionStart
   expect:
     context_contains: run the test suite
   ```

6. Create `crates/claudevs/examples/03_session_context/tests/deploy-prompt-gets-reminder.yaml`:

   ```yaml
   event: UserPromptSubmit
   payload:
     prompt: deploy the api to production
   expect:
     context_contains: change ticket
   ```

7. Create `crates/claudevs/examples/03_session_context/tests/ordinary-prompt-stays-silent.yaml`:

   ```yaml
   event: UserPromptSubmit
   expect:
     output: none
   ```

8. Run the example:

   ```
   $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/03_session_context; echo "exit=$?"
   ```

   Expected:

   ```text
     ok    validate
           …
     ok    wiring
           0 errors, 0 warnings
     ok    test
             ok    deploy-prompt-gets-reminder
             ok    ordinary-prompt-stays-silent
             ok    session-start-injects-banner
           3 passed, 0 failed (3 cases, 0 native suites)
     ok    test --installed
             ok    deploy-prompt-gets-reminder
             ok    ordinary-prompt-stays-silent
             ok    session-start-injects-banner
           3 passed, 0 failed (3 cases, 0 native suites)

   4 stages run, 0 failed, 0 skipped
   exit=0
   ```

9. Create `crates/claudevs/examples/03_session_context/README.md`, pasting step 8's output (sources: bare stdout is context on events the catalogue marks `stdout_is_context`, `semantics.rs:120-126`, true for `SessionStart` and `UserPromptSubmit` at `contract/event.rs:94,106`; `additionalContext`, `semantics.rs:116-119`; `output: none` fails on any emission, `verdict.rs:141-145`, and is refused outside hook cases, `model.rs:258-267`; default prompt `hello`, `payload.rs:28`):

    ````markdown
    # 03 — Session context

    Two hooks that add context to the conversation, and cases that assert the context arrived.

    - `hooks/session-banner.sh` runs at `SessionStart` and prints one line. On `SessionStart` and
      `UserPromptSubmit`, plain stdout from a hook is context, so it needs no JSON.
    - `hooks/deploy-reminder.sh` runs at `UserPromptSubmit`. When the prompt mentions a deploy it prints a
      JSON object whose `hookSpecificOutput.additionalContext` carries a reminder, and otherwise it prints
      nothing.

    | Case | Asserts |
    |---|---|
    | `tests/session-start-injects-banner.yaml` | `context_contains` against plain stdout |
    | `tests/deploy-prompt-gets-reminder.yaml` | `context_contains` against `additionalContext`, with `prompt` set in the payload |
    | `tests/ordinary-prompt-stays-silent.yaml` | `output: none` against the default payload, whose prompt is `hello` |

    `output: none` fails when a hook emits any JSON envelope or any context. Only hook cases accept it.

    ## Run it

    ```console
    $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/03_session_context
    ```

    ```text
    <paste step 8's output here, validate detail as …, without the exit= line>
    ```

    The exit code is 0.
    ````

    Replace the `<paste …>` line with the real output before saving.

### Task 5 — Add 04_script_and_flow

**Files:**
- Create `crates/claudevs/examples/04_script_and_flow/.claude-plugin/plugin.json`
- Create `crates/claudevs/examples/04_script_and_flow/skills/notes/SKILL.md`
- Create `crates/claudevs/examples/04_script_and_flow/scripts/greet.sh`
- Create `crates/claudevs/examples/04_script_and_flow/scripts/new-note.sh`
- Create `crates/claudevs/examples/04_script_and_flow/tests/greets-by-name.yaml`
- Create `crates/claudevs/examples/04_script_and_flow/tests/new-note-flow.yaml`
- Create `crates/claudevs/examples/04_script_and_flow/tests/fixtures/notes-repo/.gitinit`
- Create `crates/claudevs/examples/04_script_and_flow/tests/fixtures/notes-repo/README.md`
- Create `crates/claudevs/examples/04_script_and_flow/tests/fixtures/imported-notes/notes/imported.md`
- Create `crates/claudevs/examples/04_script_and_flow/README.md`

**Steps:**

1. Create `crates/claudevs/examples/04_script_and_flow/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "script-and-flow",
     "version": "0.1.0",
     "description": "claudevs example: script cases and multi-step flows over a fixture project",
     "author": { "name": "rstlix0x0" }
   }
   ```

2. Create `crates/claudevs/examples/04_script_and_flow/skills/notes/SKILL.md`. The fenced commands name both scripts, which is what keeps the `invocations` checker from reporting them as referenced by nothing (`wiring/invocations.rs:131-147`):

   ````markdown
   ---
   name: notes
   description: Greet the user and keep short notes in the current repository.
   ---

   # Notes

   1. Greet the user by name. The script reads the name from `GREETING_NAME`:

      ```sh
      sh "${CLAUDE_PLUGIN_ROOT}/scripts/greet.sh"
      ```

   2. Create a note in the current git repository:

      ```sh
      sh "${CLAUDE_PLUGIN_ROOT}/scripts/new-note.sh" "note title"
      ```
   ````

3. Create `crates/claudevs/examples/04_script_and_flow/scripts/greet.sh`:

   ```sh
   #!/bin/sh
   # Greets whoever GREETING_NAME names.
   printf 'hello, %s\n' "${GREETING_NAME:?GREETING_NAME is required}"
   ```

4. Create `crates/claudevs/examples/04_script_and_flow/scripts/new-note.sh`:

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

5. Create `crates/claudevs/examples/04_script_and_flow/tests/greets-by-name.yaml`:

   ```yaml
   invocation:
     argv: [sh, -c, 'sh "$CLAUDE_PLUGIN_ROOT/scripts/greet.sh"']
     env:
       GREETING_NAME: claudevs
   expect:
     exit: 0
     stdout_contains: hello, claudevs
   ```

6. Create `crates/claudevs/examples/04_script_and_flow/tests/new-note-flow.yaml`:

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

7. Create the empty marker `crates/claudevs/examples/04_script_and_flow/tests/fixtures/notes-repo/.gitinit`:

   ```
   $ touch crates/claudevs/examples/04_script_and_flow/tests/fixtures/notes-repo/.gitinit
   ```

8. Create `crates/claudevs/examples/04_script_and_flow/tests/fixtures/notes-repo/README.md`:

    ```markdown
    # Notes repository

    A fixture project. The `.gitinit` marker beside this file makes claudevs run `git init` in the copy.
    ```

9. Create `crates/claudevs/examples/04_script_and_flow/tests/fixtures/imported-notes/notes/imported.md`:

    ```markdown
    # Imported note
    ```

10. Run the example:

    ```
    $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/04_script_and_flow; echo "exit=$?"
    ```

    Expected:

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
    exit=0
    ```

11. Create `crates/claudevs/examples/04_script_and_flow/README.md`, pasting step 10's output (sources: argv spawned directly, `harness/spawn.rs:3-5`; cwd is the case's temp project, `suite.rs:165-168,243-244`; environment `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PROJECT_DIR`, `harness/environment.rs`, plus `invocation.env`, `suite.rs:335-338`; `.gitinit` runs `git init` and one empty commit and is not copied, `harness/project.rs:3-5,115-131`; a step's `expect` gates the flow, `suite.rs:376-390`; top-level `expect` judged against the last step that ran, `suite.rs:397-398`; `files_exist` relative to the project, `verdict.rs:174-175`; `tests/fixtures/` is never searched for cases, `case/discover.rs:39,56-62`):

    ````markdown
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
    <paste step 10's output here, validate detail as …, without the exit= line>
    ```

    The exit code is 0.
    ````

    Replace the `<paste …>` line with the real output before saving.

### Task 6 — Add 05_lua_cases

**Files:**
- Create `crates/claudevs/examples/05_lua_cases/.claude-plugin/plugin.json`
- Create `crates/claudevs/examples/05_lua_cases/hooks/hooks.json`
- Create `crates/claudevs/examples/05_lua_cases/hooks/block-force-push.sh`
- Create `crates/claudevs/examples/05_lua_cases/skills/release/SKILL.md`
- Create `crates/claudevs/examples/05_lua_cases/scripts/version.sh`
- Create `crates/claudevs/examples/05_lua_cases/tests/allows-plain-push.yaml`
- Create `crates/claudevs/examples/05_lua_cases/tests/force_push_test.lua`
- Create `crates/claudevs/examples/05_lua_cases/README.md`

**Steps:**

1. Create `crates/claudevs/examples/05_lua_cases/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "lua-cases",
     "version": "0.3.1",
     "description": "claudevs example: generated data cases and scripted cases in Lua",
     "author": { "name": "rstlix0x0" }
   }
   ```

2. Create `crates/claudevs/examples/05_lua_cases/hooks/hooks.json`:

   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Bash",
           "hooks": [
             { "type": "command", "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/block-force-push.sh\"" }
           ]
         }
       ]
     }
   }
   ```

3. Create `crates/claudevs/examples/05_lua_cases/hooks/block-force-push.sh`:

   ```sh
   #!/bin/sh
   # Blocks force pushes; every other Bash command passes silently.
   payload=$(cat)
   case "$payload" in
     *'git push'*'--force'*|*'git push'*' -f'*)
       echo "block-force-push: force pushes are not allowed" >&2
       exit 2
       ;;
   esac
   exit 0
   ```

4. Create `crates/claudevs/examples/05_lua_cases/skills/release/SKILL.md`:

   ````markdown
   ---
   name: release
   description: Print the plugin version before tagging a release.
   ---

   # Release

   1. Print the version the manifest declares:

      ```sh
      sh "${CLAUDE_PLUGIN_ROOT}/scripts/version.sh"
      ```
   ````

5. Create `crates/claudevs/examples/05_lua_cases/scripts/version.sh`:

   ```sh
   #!/bin/sh
   # Prints the version field of this plugin's manifest.
   sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json"
   ```

6. Create `crates/claudevs/examples/05_lua_cases/tests/allows-plain-push.yaml`:

   ```yaml
   event: PreToolUse
   payload:
     tool_name: Bash
     tool_input:
       command: git push origin main
   expect:
     exit: 0
     output: none
   ```

7. Create `crates/claudevs/examples/05_lua_cases/tests/force_push_test.lua`:

   ```lua
   -- Data cases generated from a table, then scripted cases that drive the
   -- harness through `t`.
   local cases = {}

   for name, command in pairs({
     long_flag = "git push --force origin main",
     short_flag = "git push -f origin main",
   }) do
     cases["blocks_force_push_" .. name] = {
       event = "PreToolUse",
       payload = { tool_name = "Bash", tool_input = { command = command } },
       expect = { decision = "deny", stderr_contains = "force pushes are not allowed" },
     }
   end

   cases.plain_push_emits_nothing = function(t)
     local reply = t.hook("PreToolUse", {
       tool_name = "Bash",
       tool_input = { command = "git push origin main" },
     })
     assert(reply.exit == 0, "expected exit 0, got " .. tostring(reply.exit))
     assert(not reply.emitted, "a plain push should emit nothing")
   end

   cases.release_skill_prints_the_manifest_version = function(t)
     local command = t.skill_command("release", 1)
     local run = t.script({ "sh", "-c", command })
     assert(run.exit == 0, "release command failed: " .. run.stderr)

     local root = t.script({ "sh", "-c", 'printf %s "$CLAUDE_PLUGIN_ROOT"' }).stdout
     local manifest = t.json(root .. "/.claude-plugin/plugin.json")
     local printed = run.stdout:gsub("%s+$", "")
     assert(printed == manifest.version, "printed " .. printed .. ", manifest says " .. manifest.version)
   end

   return cases
   ```

8. Run the example:

   ```
   $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/05_lua_cases; echo "exit=$?"
   ```

   Expected:

   ```text
     ok    validate
           …
     ok    wiring
           0 errors, 0 warnings
     ok    test
             ok    allows-plain-push
             ok    blocks_force_push_long_flag
             ok    blocks_force_push_short_flag
             ok    plain_push_emits_nothing
             ok    release_skill_prints_the_manifest_version
           5 passed, 0 failed (5 cases, 0 native suites)
     ok    test --installed
             ok    allows-plain-push
             ok    blocks_force_push_long_flag
             ok    blocks_force_push_short_flag
             ok    plain_push_emits_nothing
             ok    release_skill_prints_the_manifest_version
           5 passed, 0 failed (5 cases, 0 native suites)

   4 stages run, 0 failed, 0 skipped
   exit=0
   ```

9. Capture the `migrate` output the README quotes:

   ```
   $ cargo run -q -p claudevs-cli -- migrate crates/claudevs/examples/05_lua_cases/tests/allows-plain-push.yaml; echo "exit=$?"
   ```

   Expected:

   ```text
   return {
     ["allows-plain-push"] = {
       event = "PreToolUse",
       expect = {
         exit = 0,
         output = "none",
       },
       payload = {
         tool_input = {
           command = "git push origin main",
         },
         tool_name = "Bash",
       },
     },
   }
   exit=0
   ```

10. Create `crates/claudevs/examples/05_lua_cases/README.md`, pasting steps 8 and 9 (sources: table entries are data cases through the same path as YAML and function entries are scripted, `case/lua.rs:1-5,61-72`; case-file naming, `case/discover.rs:73-78`; case-name characters, `types/case_name.rs:6,24-28`; a scripted case passes by returning, `case/lua.rs:124-125` and `case/runner.rs:37-46`; `t` functions, `harness/t_module.rs:4-14`; confined Lua with zero grants while `t` runs host-side and `t.script` spawns any argv, `harness/t_module.rs:16-24`; `migrate --write` writes `<stem>_test.lua` with `-` turned into `_` and removes the YAML, `claudevs-cli/src/cli.rs:134-153`):

    ````markdown
    # 05 — Lua cases

    Cases written in Lua: data cases generated in a loop, and scripted cases that drive the harness
    through the `t` handle.

    The plugin blocks force pushes with a `PreToolUse` hook on `Bash`, and has a `release` skill whose
    one fenced command prints the manifest version.

    ## Data cases

    `tests/force_push_test.lua` returns a table. An entry whose value is a table is a data case, with the
    same fields a YAML case has. The file builds two of them in a loop, one per force-push spelling.

    A Lua file is a case file when its name ends in `_test.lua` or starts with `test_`. Each entry's key
    is its case name, and a case name uses only `A-Z`, `a-z`, `0-9`, `.`, `_` and `-`.

    ## Scripted cases

    An entry whose value is a function is a scripted case. It receives `t`, and it passes by returning;
    an error, such as a failed `assert`, fails it.

    - `plain_push_emits_nothing` calls `t.hook("PreToolUse", payload)` and reads `exit` and `emitted`
      from the result.
    - `release_skill_prints_the_manifest_version` takes the skill's first fenced command with
      `t.skill_command("release", 1)`, runs it with `t.script`, and compares what it printed with the
      version `t.json` reads from `.claude-plugin/plugin.json`.

    The Lua runs under a confined policy with no grants. The `t` functions run on the host, though, and
    `t.script` can start any program, so treat a case file as code you run.

    ## From YAML to Lua

    `tests/allows-plain-push.yaml` is an ordinary YAML case. `claudevs migrate` prints its data-Lua form:

    ```console
    $ cargo run -q -p claudevs-cli -- migrate crates/claudevs/examples/05_lua_cases/tests/allows-plain-push.yaml
    <paste step 9's output here, without the exit= line>
    ```

    `claudevs migrate --write` instead writes `allows_plain_push_test.lua` next to the YAML file and
    deletes the YAML file.

    ## Run it

    ```console
    $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/05_lua_cases
    ```

    ```text
    <paste step 8's output here, validate detail as …, without the exit= line>
    ```

    The exit code is 0.
    ````

    Replace both `<paste …>` lines with the real output before saving.

### Task 7 — Add 06_native_suite

**Files:**
- Create `crates/claudevs/examples/06_native_suite/.claude-plugin/plugin.json`
- Create `crates/claudevs/examples/06_native_suite/claudevs.toml`
- Create `crates/claudevs/examples/06_native_suite/hooks/hooks.json`
- Create `crates/claudevs/examples/06_native_suite/hooks/session-banner.sh`
- Create `crates/claudevs/examples/06_native_suite/tests/native/syntax-check.sh`
- Create `crates/claudevs/examples/06_native_suite/tests/session-banner.yaml`
- Create `crates/claudevs/examples/06_native_suite/README.md`

**Steps:**

1. Create `crates/claudevs/examples/06_native_suite/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "native-suite",
     "version": "0.1.0",
     "description": "claudevs example: a native test command declared in claudevs.toml",
     "author": { "name": "rstlix0x0" }
   }
   ```

2. Create `crates/claudevs/examples/06_native_suite/claudevs.toml`:

   ```toml
   [[native]]
   run = "sh tests/native/syntax-check.sh"
   ```

3. Create `crates/claudevs/examples/06_native_suite/hooks/hooks.json`:

   ```json
   {
     "hooks": {
       "SessionStart": [
         { "hooks": [ { "type": "command", "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/session-banner.sh\"" } ] }
       ]
     }
   }
   ```

4. Create `crates/claudevs/examples/06_native_suite/hooks/session-banner.sh`:

   ```sh
   #!/bin/sh
   echo "session-banner: native suite example"
   ```

5. Create `crates/claudevs/examples/06_native_suite/tests/native/syntax-check.sh`:

   ```sh
   #!/bin/sh
   # Parses every hook script without running it.
   status=0
   for script in hooks/*.sh; do
     if sh -n "$script"; then
       echo "ok    $script"
     else
       status=1
     fi
   done
   exit $status
   ```

6. Create `crates/claudevs/examples/06_native_suite/tests/session-banner.yaml`:

   ```yaml
   event: SessionStart
   expect:
     context_contains: native suite example
   ```

7. Run the example:

   ```
   $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/06_native_suite; echo "exit=$?"
   ```

   Expected:

   ```text
     ok    validate
           …
     ok    wiring
           0 errors, 0 warnings
     ok    test
             ok    session-banner
             ok    native: sh tests/native/syntax-check.sh (exit 0)
           1 passed, 0 failed (1 cases, 1 native suites)
     ok    test --installed
             ok    session-banner
             ok    native: sh tests/native/syntax-check.sh (exit 0)
           1 passed, 0 failed (1 cases, 1 native suites)

   4 stages run, 0 failed, 0 skipped
   exit=0
   ```

8. Create `crates/claudevs/examples/06_native_suite/README.md`, pasting step 7's output (sources: `claudevs.toml` at the plugin root, `run` spawned with `sh -c` in the plugin directory, only the exit code asserted, `native/declared.rs:1-10,55`; `run` is the only accepted key, `native/declared.rs:35-47`; output printed only under a non-zero exit, `report/render.rs:157-168`; case-file naming, `case/discover.rs:73-78`; cases are discovered before native suites run and none found is an error, `suite.rs:90,129` and `case/discover.rs:48-52`, which `claudevs test` turns into exit 2, `claudevs-cli/src/cli.rs:123-126`):

    ````markdown
    # 06 — Native suite

    A plugin that keeps its own test command and has claudevs run it next to the cases.

    `claudevs.toml` at the plugin root declares the command:

    ```toml
    [[native]]
    run = "sh tests/native/syntax-check.sh"
    ```

    claudevs spawns each `[[native]]` entry's `run` string with `sh -c` from the plugin directory. It
    asserts only the exit code, and prints the command's combined output only when that code is not 0.
    `run` is the only key an entry accepts.

    `tests/native/syntax-check.sh` parses every hook script with `sh -n`. It sits under `tests/` without
    being a case file, because only `*.yaml`, `*.yml`, `*_test.lua` and `test_*.lua` files are.

    A plugin with a native suite still needs at least one case file. `claudevs test` looks for cases
    first and exits 2 when it finds none, so this plugin also has `tests/session-banner.yaml`.

    ## Run it

    ```console
    $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/06_native_suite
    ```

    ```text
    <paste step 7's output here, validate detail as …, without the exit= line>
    ```

    The exit code is 0.
    ````

    Replace the `<paste …>` line with the real output before saving.

### Task 8 — Add 07_wiring_broken and prove its expectation can fail

**Files:**
- Create `crates/claudevs/examples/07_wiring_broken/.claude-plugin/plugin.json`
- Create `crates/claudevs/examples/07_wiring_broken/hooks/hooks.json`
- Create `crates/claudevs/examples/07_wiring_broken/hooks/session-banner.sh`
- Create `crates/claudevs/examples/07_wiring_broken/hooks/format.sh`
- Create `crates/claudevs/examples/07_wiring_broken/tests/session-banner.yaml`
- Create `crates/claudevs/examples/07_wiring_broken/README.md`

**Steps:**

1. Create `crates/claudevs/examples/07_wiring_broken/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "wiring-broken",
     "version": "0.1.0",
     "description": "claudevs example: a hooks.json reference to a script that does not exist",
     "author": { "name": "rstlix0x0" }
   }
   ```

2. Create `crates/claudevs/examples/07_wiring_broken/hooks/hooks.json`. The `format-on-write.sh` reference on line 9 is the defect:

   ```json
   {
     "hooks": {
       "SessionStart": [
         { "hooks": [ { "type": "command", "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/session-banner.sh\"" } ] }
       ],
       "PostToolUse": [
         {
           "matcher": "Write",
           "hooks": [ { "type": "command", "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/format-on-write.sh\"" } ]
         }
       ]
     }
   }
   ```

3. Create `crates/claudevs/examples/07_wiring_broken/hooks/session-banner.sh`:

   ```sh
   #!/bin/sh
   echo "session-banner: wiring example"
   ```

4. Create `crates/claudevs/examples/07_wiring_broken/hooks/format.sh`:

   ```sh
   #!/bin/sh
   # Formats the file a Write just touched.
   exit 0
   ```

5. Create `crates/claudevs/examples/07_wiring_broken/tests/session-banner.yaml`:

   ```yaml
   event: SessionStart
   expect:
     context_contains: wiring example
   ```

6. Run the example:

   ```
   $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/07_wiring_broken; echo "exit=$?"
   ```

   Expected:

   ```text
     ok    validate
           …
     FAIL  wiring
             error  refs  hooks/hooks.json:9  `${CLAUDE_PLUGIN_ROOT}/hooks/format-on-write.sh` does not exist
           1 error, 0 warnings
     ok    test
             ok    session-banner
           1 passed, 0 failed (1 cases, 0 native suites)
     ok    test --installed
             ok    session-banner
           1 passed, 0 failed (1 cases, 0 native suites)

   4 stages run, 1 failed, 0 skipped
   exit=1
   ```

7. Create `crates/claudevs/examples/07_wiring_broken/README.md`, pasting step 6's output (sources: `refs` resolves `${CLAUDE_PLUGIN_ROOT}/…` references in the files Claude Code loads, `wiring/refs.rs:1-3,84-86` and `contract/site.rs:24-39`; a missing target is `Severity::Error` with this message, `wiring/refs.rs:99,121`; wiring runs nothing, `wiring/mod.rs:1`; a failed stage does not stop later stages, `check.rs:28`):

    ````markdown
    # 07 — Wiring, broken

    A plugin whose `hooks/hooks.json` points at a script that is not there.

    ## What is wrong

    The `PostToolUse` hook runs `${CLAUDE_PLUGIN_ROOT}/hooks/format-on-write.sh`, but the script in
    `hooks/` is `format.sh`. The `refs` wiring checker resolves every `${CLAUDE_PLUGIN_ROOT}/…` reference
    in the files Claude Code loads from a plugin. A reference to a file that does not exist is an error,
    so the `wiring` stage fails.

    No case exercises `PostToolUse`, so `test` and `test --installed` still pass. `wiring` finds the
    defect without running anything, and a failing stage does not stop the stages after it.

    ## Run it

    ```console
    $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/07_wiring_broken
    ```

    ```text
    <paste step 6's output here, validate detail as …, without the exit= line>
    ```

    The exit code is 1. Point the command at `hooks/format.sh` and the run ends at 0.
    ````

    Replace the `<paste …>` line with the real output before saving.

### Task 9 — Add 08_installed_broken and prove its expectation can fail

**Files:**
- Create `crates/claudevs/examples/shared/policy-message.txt`
- Create `crates/claudevs/examples/08_installed_broken/.claude-plugin/plugin.json`
- Create `crates/claudevs/examples/08_installed_broken/hooks/hooks.json`
- Create `crates/claudevs/examples/08_installed_broken/hooks/block-rm-rf.sh`
- Create `crates/claudevs/examples/08_installed_broken/tests/blocks-rm-rf.yaml`
- Create `crates/claudevs/examples/08_installed_broken/README.md`

**Steps:**

1. Create `crates/claudevs/examples/shared/policy-message.txt`:

   ```text
   blocked-by-policy: recursive deletes are not allowed
   ```

2. Create `crates/claudevs/examples/08_installed_broken/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "installed-broken",
     "version": "0.1.0",
     "description": "claudevs example: a hook that reads a file outside its plugin root",
     "author": { "name": "rstlix0x0" }
   }
   ```

3. Create `crates/claudevs/examples/08_installed_broken/hooks/hooks.json`:

   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Bash",
           "hooks": [ { "type": "command", "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/block-rm-rf.sh\"" } ]
         }
       ]
     }
   }
   ```

4. Create `crates/claudevs/examples/08_installed_broken/hooks/block-rm-rf.sh`. The unbraced `$CLAUDE_PLUGIN_ROOT/../shared/…` on line 5 is the defect:

   ```sh
   #!/bin/sh
   # Blocks recursive deletes. Its message is read from one directory above the
   # plugin root, which exists in this checkout and not in an installed copy.
   payload=$(cat)
   message=$(cat "$CLAUDE_PLUGIN_ROOT/../shared/policy-message.txt")
   case "$payload" in
     *'rm -rf'*)
       echo "$message" >&2
       exit 2
       ;;
   esac
   exit 0
   ```

5. Create `crates/claudevs/examples/08_installed_broken/tests/blocks-rm-rf.yaml`:

   ```yaml
   event: PreToolUse
   payload:
     tool_name: Bash
     tool_input:
       command: rm -rf build
   expect:
     decision: deny
     stderr_contains: blocked-by-policy
   ```

6. Run the example:

   ```
   $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/08_installed_broken; echo "exit=$?"
   ```

   Expected (temp directories shown as `…`; on Linux the `cat:` wording comes from GNU coreutils and may differ, which nothing here asserts):

   ```text
     ok    validate
           …
     ok    wiring
           0 errors, 0 warnings
     ok    test
             ok    blocks-rm-rf
           1 passed, 0 failed (1 cases, 0 native suites)
     FAIL  test --installed
             FAIL  blocks-rm-rf
                   stderr: expected to contain `blocked-by-policy`, got "cat: …/cache/claudevs-examples/installed-broken/0.1.0/../shared/policy-message.txt: No such file or directory\n\n"
                   payload: {"cwd":"…","hook_event_name":"PreToolUse","session_id":"claudevs-test","tool_input":{"command":"rm -rf build","file_path":"…/file.txt"},"tool_name":"Bash"}
                   handler: sh "${CLAUDE_PLUGIN_ROOT}/hooks/block-rm-rf.sh"
           0 passed, 1 failed (1 cases, 0 native suites)

   4 stages run, 1 failed, 0 skipped
   exit=1
   ```

7. Create `crates/claudevs/examples/08_installed_broken/README.md`, pasting step 6's output (sources: the installed copy at `cache/<marketplace>/<plugin>/<version>/` with `CLAUDE_PLUGIN_ROOT` pointed at it, `layout/installed.rs:3-9,51-56` and `suite.rs:136-148`; only the plugin directory is copied, `layout/installed.rs:43-60`; `refs` matches only the braced form, `wiring/refs.rs:29-30`; exit 2 on `PreToolUse` reads as deny, `semantics.rs:128-131`):

    ````markdown
    # 08 — Installed layout, broken

    A hook that works while the plugin runs from this checkout and breaks once the plugin is installed.

    ## What is wrong

    `hooks/block-rm-rf.sh` reads its message from `$CLAUDE_PLUGIN_ROOT/../shared/policy-message.txt`, a
    file one directory above the plugin root. From this checkout that path lands in
    `crates/claudevs/examples/shared/`, so `test` passes.

    `test --installed` runs the same cases against a copy of the plugin at
    `cache/<marketplace>/<plugin>/<version>/`, the layout Claude Code installs a plugin into, with
    `CLAUDE_PLUGIN_ROOT` pointing at the copy. Only the plugin directory is copied, so there is no
    `../shared/` next to it. The hook still exits 2, which keeps `decision: deny` passing, but its message
    is gone and `stderr_contains` fails.

    `wiring` does not catch this. The `refs` checker reads references written as
    `${CLAUDE_PLUGIN_ROOT}/…`, with braces, and this script writes the variable without them.

    The fix is to keep the file inside the plugin.

    ## Run it

    ```console
    $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/08_installed_broken
    ```

    ```text
    <paste step 6's output here, validate detail and temp paths as …, without the exit= line>
    ```

    The exit code is 1.
    ````

    Replace the `<paste …>` line with the real output before saving.

### Task 10 — Build the example gate: crates/claudevs/tests/examples.rs

**Files:**
- Create `crates/claudevs/tests/examples.rs`

**Steps:**

1. Create `crates/claudevs/tests/examples.rs`:

   ````rust
   //! The example plugins under `crates/claudevs/examples/` do what their READMEs say.
   //!
   //! Each example is teaching material: its README shows a `claudevs check` run and quotes the
   //! outcome. This test is what keeps that quote true. It runs the same pipeline the binary runs
   //! and compares the typed stage outcomes against the expectation declared below, so a broken
   //! example fails `cargo test` rather than being discovered by a reader.
   //!
   //! `validate` is excluded from every assertion: it delegates to the `claude` binary and skips
   //! wherever that binary is absent, which is the documented degradation on CI. The three
   //! deterministic stages — `wiring`, `test`, `test --installed` — must always have run, because
   //! `claudevs check` turns three environment gaps into a skipped stage rather than a failure (no
   //! case files, no marketplace above the plugin, no writable temp dir), and a skip is exactly how
   //! an example stops exercising what its README documents while still exiting 0.

   #![expect(
       clippy::panic,
       reason = "a failing example reports which stage diverged by panicking"
   )]

   use std::path::{Path, PathBuf};

   use claudevs::check::{CheckReport, StageStatus};

   /// What an example is supposed to do.
   #[derive(Debug, Clone, Copy)]
   enum Expectation {
       /// Every deterministic stage ran and passed.
       AllOk,
       /// Every deterministic stage ran, and this one failed.
       FailsAt(&'static str),
   }

   /// Every example, and the outcome its README documents.
   ///
   /// A new example directory with no row here fails the completeness test below, so this list
   /// cannot silently fall behind `examples/`.
   const EXAMPLES: &[(&str, Expectation)] = &[
       ("01_hook_decision", Expectation::AllOk),
       ("02_hook_decision_broken", Expectation::FailsAt("test")),
       ("03_session_context", Expectation::AllOk),
       ("04_script_and_flow", Expectation::AllOk),
       ("05_lua_cases", Expectation::AllOk),
       ("06_native_suite", Expectation::AllOk),
       ("07_wiring_broken", Expectation::FailsAt("wiring")),
       (
           "08_installed_broken",
           Expectation::FailsAt("test --installed"),
       ),
   ];

   /// The stages that run on every machine, whether or not `claude` is installed.
   const DETERMINISTIC: [&str; 3] = ["wiring", "test", "test --installed"];

   fn examples_dir() -> PathBuf {
       Path::new(env!("CARGO_MANIFEST_DIR")).join("examples")
   }

   fn stage<'report>(report: &'report CheckReport, name: &str) -> &'report claudevs::check::Stage {
       report
           .stages
           .iter()
           .find(|stage| stage.name == name)
           .unwrap_or_else(|| {
               panic!(
                   "stage `{name}` is missing from the report entirely; stages present: {:?}",
                   report.stages.iter().map(|s| s.name).collect::<Vec<_>>()
               )
           })
   }

   fn check(dir: &Path) -> CheckReport {
       claudevs::check::run(dir, claudevs::Strictness::Lenient)
           .unwrap_or_else(|error| panic!("claudevs check {}: {error}", dir.display()))
   }

   #[test]
   fn every_example_produces_the_outcome_its_readme_documents() {
       for (name, expectation) in EXAMPLES {
           let dir = examples_dir().join(name);
           assert!(dir.is_dir(), "{} is not a directory", dir.display());

           let report = check(&dir);

           for deterministic in DETERMINISTIC {
               let stage = stage(&report, deterministic);
               assert_ne!(
                   stage.status,
                   StageStatus::Skipped,
                   "{name}: stage `{deterministic}` skipped, so the run its README quotes did not \
                    happen: {}",
                   stage.detail
               );
           }

           match expectation {
               Expectation::AllOk => {
                   for deterministic in DETERMINISTIC {
                       let stage = stage(&report, deterministic);
                       assert_eq!(
                           stage.status,
                           StageStatus::Passed,
                           "{name}: stage `{deterministic}` did not pass: {}",
                           stage.detail
                       );
                   }
               }
               Expectation::FailsAt(expected) => {
                   let stage = stage(&report, expected);
                   assert_eq!(
                       stage.status,
                       StageStatus::Failed,
                       "{name}: this example is broken on purpose and `{expected}` is the stage that \
                        must report it, but it did not: {}",
                       stage.detail
                   );
               }
           }
       }
   }

   #[test]
   fn every_example_directory_is_covered_by_the_table() {
       let dir = examples_dir();
       let mut found: Vec<String> = std::fs::read_dir(&dir)
           .unwrap_or_else(|error| panic!("read {}: {error}", dir.display()))
           .filter_map(Result::ok)
           .filter(|entry| entry.path().is_dir())
           .map(|entry| entry.file_name().to_string_lossy().into_owned())
           // The shared marketplace manifest is not an example.
           .filter(|name| !name.starts_with('.'))
           // `08_installed_broken` reads a file from this directory; it is not an example either.
           .filter(|name| name != "shared")
           .collect();
       found.sort();

       let mut declared: Vec<String> = EXAMPLES
           .iter()
           .map(|(name, _)| (*name).to_owned())
           .collect();
       declared.sort();

       assert_eq!(
           found, declared,
           "every directory under examples/ needs a row in EXAMPLES, and every row needs a directory"
       );
   }
   ````

2. Prove it red. Move `crates/claudevs/examples/03_session_context/tests` aside (`$ mv crates/claudevs/examples/03_session_context/tests /tmp/aside`), then run:

   ```
   $ cargo test -p claudevs --test examples --all-features
   ```

   Expected: `every_example_directory_is_covered_by_the_table` passes, `every_example_produces_the_outcome_its_readme_documents` panics and fails:

   ```text
   thread 'every_example_produces_the_outcome_its_readme_documents' panicked at crates/claudevs/tests/examples.rs:86:13:
   assertion `left != right` failed: 03_session_context: stage `test` skipped, so the run its README quotes did not happen: no case files found under `…/crates/claudevs/examples/03_session_context/tests` (cases are `*.yaml`, `*_test.lua` or `test_*.lua` in tests/)
     left: Skipped
    right: Skipped

   test result: FAILED. 1 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out
   ```

   Restore `tests/` (`$ mv /tmp/aside crates/claudevs/examples/03_session_context/tests`).

3. Run it green:

   ```
   $ cargo test -p claudevs --test examples --all-features
   ```

   Expected:

   ```text
   running 2 tests
   test every_example_directory_is_covered_by_the_table ... ok
   test every_example_produces_the_outcome_its_readme_documents ... ok

   test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out
   ```

### Task 11 — Write the examples index

**Files:**
- Create `crates/claudevs/examples/README.md`

**Steps:**

1. Create `crates/claudevs/examples/README.md` (sources: stage order and later stages still running, `check.rs:3-5,28,92-116`; `validate` delegates and skips without `claude`, the no-`claude` runs recorded at the top of this plan; the installed layout and marketplace lookup, `layout/installed.rs:3-9,51-56` and `layout/manifest.rs:90-120`; a missing marketplace skips the stage, `check.rs:164`):

   ````markdown
   # claudevs examples

   Each directory below is a small Claude Code plugin whose `tests/` directory holds claudevs cases. Run
   one from the repository root:

   ```console
   $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/01_hook_decision
   ```

   `check` runs four stages in order: `validate`, `wiring`, `test` and `test --installed`. Every stage
   runs even when an earlier one fails. `claudevs test <dir>` runs the cases and native suites alone,
   without `validate` or `wiring`.

   | Example | Shows | `claudevs check` ends with |
   |---|---|---|
   | [`01_hook_decision`](01_hook_decision/README.md) | a `PreToolUse` gate tested with YAML hook cases: `decision`, `stderr_contains`, `output: none`, payload overlays | exit 0 |
   | [`02_hook_decision_broken`](02_hook_decision_broken/README.md) | the same gate with a defect, and the failure its case reports | exit 1, `FAIL  test` |
   | [`03_session_context`](03_session_context/README.md) | context added at `SessionStart` and `UserPromptSubmit`, asserted with `context_contains` and `output: none` | exit 0 |
   | [`04_script_and_flow`](04_script_and_flow/README.md) | a script case with `invocation.env`, and a flow over a fixture project with `.gitinit`, `apply_fixture` and `files_exist` | exit 0 |
   | [`05_lua_cases`](05_lua_cases/README.md) | generated data cases and scripted cases in Lua using `t.hook`, `t.script`, `t.skill_command` and `t.json`, and `claudevs migrate` | exit 0 |
   | [`06_native_suite`](06_native_suite/README.md) | a native test command declared in `claudevs.toml` | exit 0 |
   | [`07_wiring_broken`](07_wiring_broken/README.md) | a `${CLAUDE_PLUGIN_ROOT}` reference to a file that does not exist | exit 1, `FAIL  wiring` |
   | [`08_installed_broken`](08_installed_broken/README.md) | a hook that works in this checkout and breaks once installed | exit 1, `FAIL  test --installed` |

   `crates/claudevs/tests/examples.rs` runs `claudevs check` over every example and asserts the stage
   in the last column, so an example that stops matching its README fails `cargo test`.

   ## Without a `claude` binary

   The `validate` stage hands the manifest to `claude plugin validate`. When `claude` is not on `PATH`,
   that stage reports `skip  validate` with the reason, and the other three stages still decide the
   result. Every outcome in the table holds either way.

   ## Why a marketplace manifest sits here

   `.claude-plugin/marketplace.json` makes this directory a marketplace for the plugins inside it.
   `test --installed` copies a plugin to `cache/<marketplace>/<plugin>/<version>/`, the layout Claude Code
   installs a plugin into, and takes `<marketplace>` from the nearest `.claude-plugin/marketplace.json`
   above the plugin. Without one, that stage skips. This manifest lists no plugins.

   ## Why `shared/` sits here

   `shared/policy-message.txt` belongs to `08_installed_broken`. That example's hook reads the file
   through a path that climbs out of the plugin root: it is found while the plugin runs from this
   checkout, and missing from the installed copy. That gap is what the example shows.
   ````

2. Check that every README the table links to exists:

   ```
   $ ls crates/claudevs/examples/*/README.md
   ```

   Expected: exactly these eight paths, exit 0 — one per row of the table, and no README under `shared/`:

   ```text
   crates/claudevs/examples/01_hook_decision/README.md
   crates/claudevs/examples/02_hook_decision_broken/README.md
   crates/claudevs/examples/03_session_context/README.md
   crates/claudevs/examples/04_script_and_flow/README.md
   crates/claudevs/examples/05_lua_cases/README.md
   crates/claudevs/examples/06_native_suite/README.md
   crates/claudevs/examples/07_wiring_broken/README.md
   crates/claudevs/examples/08_installed_broken/README.md
   ```

### Task 12 — Withdrawn: no CI job or CLAUDE.md change

This task set out to rename the `claudevs-check` CI job to cover the examples and to have root
`CLAUDE.md` describe the lane as testing both the fixture corpus and the example plugins. Both
followed from Task 1's premise that the examples ride `cargo make claudevs-check`, which is withdrawn.

`.github/workflows/ci.yml`'s `claudevs-check` job keeps its existing name; it still runs only the
fixture corpus, unchanged by this chain. Root `CLAUDE.md` is not modified either — spec §5 already
says so: "the lane still covers the fixture corpus and nothing else." The example gate
(`crates/claudevs/tests/examples.rs`, Task 10) runs under the existing `cargo test --workspace
--all-targets --all-features` Definition-of-Done step, which needs no new CI job to name it.

### Task 13 — Verify the whole plan and hand off for commit

**Steps:**

1. Run the fixture lane, untouched by this plan, and confirm it still passes on its own:

   ```
   $ cargo make claudevs-check
   ```

   Expected: zero exit, and these eight lines, naming only the fixtures:

   ```text
   ok  crates/claudevs/tests/fixtures/minimal-plugin (exit 0, no stage failed)
   ok  crates/claudevs/tests/fixtures/dead-script-plugin (exit 0, no stage failed)
   ok  crates/claudevs/tests/fixtures/escape-plugin (FAIL wiring)
   ok  crates/claudevs/tests/fixtures/bad-matcher-plugin (FAIL wiring)
   ok  crates/claudevs/tests/fixtures/hooks-array-plugin (FAIL wiring)
   ok  crates/claudevs/tests/fixtures/project-branch-plugin (exit 0, no stage failed)
   ok  crates/claudevs/tests/fixtures/exec-args-plugin (exit 0, no stage failed)
   ok  crates/claudevs/tests/fixtures/matcher-routing-plugin (FAIL test)
   ```

   Then run the example gate:

   ```
   $ cargo test -p claudevs --test examples --all-features
   ```

   Expected: zero exit, two tests passed:

   ```text
   running 2 tests
   test every_example_directory_is_covered_by_the_table ... ok
   test every_example_produces_the_outcome_its_readme_documents ... ok

   test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out
   ```

2. Confirm the outcomes hold without `claude`, as on the CI runner. Run each of these separately:

   ```
   $ env PATH=/usr/bin:/bin target/debug/claudevs check crates/claudevs/examples/01_hook_decision | grep -E '^  (ok|FAIL|skip)  |stages run'
   $ env PATH=/usr/bin:/bin target/debug/claudevs check crates/claudevs/examples/02_hook_decision_broken | grep -E '^  (ok|FAIL|skip)  |stages run'
   $ env PATH=/usr/bin:/bin target/debug/claudevs check crates/claudevs/examples/03_session_context | grep -E '^  (ok|FAIL|skip)  |stages run'
   $ env PATH=/usr/bin:/bin target/debug/claudevs check crates/claudevs/examples/04_script_and_flow | grep -E '^  (ok|FAIL|skip)  |stages run'
   $ env PATH=/usr/bin:/bin target/debug/claudevs check crates/claudevs/examples/05_lua_cases | grep -E '^  (ok|FAIL|skip)  |stages run'
   $ env PATH=/usr/bin:/bin target/debug/claudevs check crates/claudevs/examples/06_native_suite | grep -E '^  (ok|FAIL|skip)  |stages run'
   $ env PATH=/usr/bin:/bin target/debug/claudevs check crates/claudevs/examples/07_wiring_broken | grep -E '^  (ok|FAIL|skip)  |stages run'
   $ env PATH=/usr/bin:/bin target/debug/claudevs check crates/claudevs/examples/08_installed_broken | grep -E '^  (ok|FAIL|skip)  |stages run'
   ```

   Expected, where `claude` is not in `/usr/bin` or `/bin`. Examples 01, 03, 04, 05 and 06:

   ```text
     skip  validate
     ok    wiring
     ok    test
     ok    test --installed
   3 stages run, 0 failed, 1 skipped
   ```

   02: `skip  validate`, `ok    wiring`, `FAIL  test`, `FAIL  test --installed`, `3 stages run, 2 failed, 1 skipped`.
   07: `skip  validate`, `FAIL  wiring`, `ok    test`, `ok    test --installed`, `3 stages run, 1 failed, 1 skipped`.
   08: `skip  validate`, `ok    wiring`, `ok    test`, `FAIL  test --installed`, `3 stages run, 1 failed, 1 skipped`.

3. Confirm no example became a Cargo target (spec P4):

   ```
   $ cargo metadata --no-deps --format-version 1 | jq -r '.packages[] | select(.name == "claudevs") | .targets[] | select(.kind[] == "example") | .name'
   ```

   Expected: no output.

4. Check the shipped text against spec §6:

   ```
   $ grep -rnE '\.rs:[0-9]' crates/claudevs/examples
   $ grep -rnwiE 'phases?|workstreams?|epics?|milestones?|sprints?|tasks?|backlog|todo|plans?|specs?|rfcs?|roadmaps?|delivered|landed|shipped|closed|planned' crates/claudevs/examples
   $ grep -rniE 'now supports|no longer|used to|as of|was wrong|coming soon|not yet|future work|prior revision|this revision' crates/claudevs/examples
   $ grep -rn '<paste' crates/claudevs/examples
   ```

   Expected: no output from any of the four, each exiting 1.

5. Confirm the change set. This plan touches nothing outside `crates/claudevs/examples/` and
   `crates/claudevs/tests/examples.rs`; `Makefile.toml`, `.github/workflows/ci.yml` and root
   `CLAUDE.md` are untouched:

   ```
   $ git status --short crates/claudevs/examples crates/claudevs/tests/examples.rs Makefile.toml .github/workflows/ci.yml CLAUDE.md
   ```

   Expected — the last three print nothing, so only these two lines appear (other chains may leave
   further uncommitted work elsewhere in the tree; this step does not check that):

   ```text
   ?? crates/claudevs/examples/
   ?? crates/claudevs/tests/examples.rs
   ```

6. Hand the change to the user. Suggested message, if they commit it:

   ```text
   feat(claudevs): add example plugins with a Rust test asserting their outcomes

   Eight example plugins under crates/claudevs/examples/, three broken on
   purpose, each with a README whose `claudevs check` output is asserted by
   crates/claudevs/tests/examples.rs against the typed stage outcomes rather
   than by grepping rendered text. The fixture corpus lane in Makefile.toml
   is untouched.
   ```

---

## Verification summary (plan-level)

- `cargo make claudevs-check` exits 0 with the eight fixture `ok  …` lines, unchanged by this plan.
- `cargo test -p claudevs --test examples --all-features` exits 0 with both tests passing, and was
  proven red first by moving `03_session_context/tests` aside (Task 10).
- The same per-example stage outcomes hold with `claude` absent from `PATH` (Task 13 step 2), which is
  the CI runner's environment (`ci.yml:88-89`).
- No example is a Cargo target; `crates/claudevs/tests/examples.rs` is new Rust source, so the
  Definition of Done's `clippy`, `doc` and `test` steps all cover it.
- Shipped READMEs and scripts carry no `file:line`, no banned vocabulary, and no unfilled paste markers.

## Review findings

- premise — the examples were merged into `cargo make claudevs-check`, the fixture corpus's pass/fail
  lane; the two answer different questions, and the merge put the examples' correctness in shell —
  `Makefile.toml`, withdrawn Task 1. Raised by the author. Fixed: the lane is byte-identical to its
  committed state and the examples are verified from Rust.
- blind spot — `expect_no_fail` could not distinguish a passing stage from a skipped one, so an
  example could stop exercising the stage its README quotes while the lane stayed green.
  Superseded by the finding above; `tests/examples.rs` now asserts it.
- accuracy — `crates/claudevs/README.md` carried four claims the source contradicts, not the one the
  intent named: matchers compiling via the `regex` crate, references resolving "anywhere in the
  plugin", the dead-file exemption list, and `doctor` "never exits 2". All four corrected.
- gap — no example covered `claudevs doctor`, so running it on a deliberately broken plugin reported
  `0 gaps, 0 warnings` with no explanation anywhere. Fixed by `09_doctor_gaps` and a paragraph in
  `docs/cli/reference.md`.

## Probe results

- Claim: the example gate can see a stage that stops running. Command:
  `mv crates/claudevs/examples/03_session_context/tests ...-held` then
  `cargo test -p claudevs --test examples`. Output:
  "03_session_context: stage `test` skipped, so the run its README quotes did not happen".
  Restored, 2 passed. The gate is proven red before green.
- Claim (AGAINST the plan): `examples/.claude-plugin/marketplace.json` is what keeps `test --installed`
  from skipping. Command: moved that directory aside and re-ran the lane. Output: it stayed green —
  the lookup walks ancestors and finds the repo-root manifest (`claudestacks`) instead. What the
  example manifest actually does is key the installed path as
  `cache/claudevs-examples/<plugin>/<version>/`. Plan text corrected.
- Claim: a skipped stage passes `expect_no_fail`. Command: same `tests/` move, then
  `cargo make claudevs-check`. Output: `skip  test`, `skip  test --installed`,
  `2 stages run, 0 failed, 2 skipped`, exit 0 — a pass. This is what withdrew Task 1.
- Claim: hiding the `claude` binary produces a doctor gap. Command:
  `env PATH=/usr/bin:/bin claudevs doctor crates/claudevs/examples/03_session_context`. Output:
  "gap   claude binary: cannot run `claude`: No such file or directory (os error 2)",
  `1 gap, 0 warnings`, exit 1. This is `09_doctor_gaps`'s `no-claude` scenario.

## Deviations

- 2026-09-18 — Task 1 and the CI/CLAUDE.md task withdrawn, `Makefile.toml` left untouched, and the
  example gate moved to `crates/claudevs/tests/examples.rs`. Authorized by the author, who identified
  the fixtures/examples merge as the error. Spec 4.1 rewritten and recorded in spec 8.
- 2026-09-18 — a ninth example, `09_doctor_gaps`, added at the author's request after `doctor` reported
  `0 gaps, 0 warnings` on `07_wiring_broken` and `08_installed_broken`. It carries
  `scripts/simulate.sh`, a scenario runner the other examples have no equivalent of. Recorded in spec 8.
- 2026-09-18 — Tasks 3, 8 and 9 keep the title "and prove its expectation can fail" but no longer carry
  a per-example red-green step, because that step ran through the withdrawn lane. `tests/examples.rs`
  proves the mechanism generically; per-example regression proof is not replaced and remains open.
- 2026-09-18 — Tasks 3 through 13 ran as parallel agents against a fixed plan rather than in the plan's
  batch order, to meet a same-day deadline. One combined review pass over Tasks 1 and 2 instead of one
  per batch, since both edited `Makefile.toml`.
