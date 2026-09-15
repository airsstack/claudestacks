---
status: approved
created: 2026-09-13
---

# claudevs Example Plugins Implementation Plan

**Goal:** Make `cargo make claudevs-check` assert the `claudevs check` outcome that each of eight example plugins under `crates/claudevs/examples/` documents in its README.

**Architecture:** Every example is a plugin root (`.claude-plugin/plugin.json`, `hooks/`, `tests/`, `README.md`) run through the `claudevs` binary, never a Cargo target. The examples share one marketplace manifest at `crates/claudevs/examples/.claude-plugin/marketplace.json`, without which `test --installed` skips. The existing `claudevs-check` cargo-make task takes full plugin paths so fixtures and examples share its `_run`, `expect_no_fail` and `expect_stage_fail` functions. The CI job keeps its id and gets a name that covers both.

**Tech Stack:** POSIX `sh` hook scripts, YAML and Lua case files, `claudevs.toml`, a cargo-make `@shell` script, GitHub Actions YAML.

**Content authority:** `spec.md` §3 (example plugins), §4.1 (example gate), §5 second bullet (root `CLAUDE.md`), §6 (wording rules for shipped text).

---

## File structure

```
Makefile.toml                                              — [modify] claudevs-check takes full plugin paths; eight example expectations
.github/workflows/ci.yml                                   — [modify] job `claudevs-check` renamed "claudevs fixtures and examples"
CLAUDE.md                                                  — [modify] lane description names the example plugins
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
```

Every command runs from the worktree root. Two commands recur:

- **The lane:** `cargo make claudevs-check`. It prints one `ok  <path> (…)` line per plugin and stops at the first plugin whose expectation fails, printing `claudevs check <path>: expected …` and the captured output to stderr (`Makefile.toml:231-234`, `:256-258`, `:268-270`, `:279-281`).
- **One example:** `cargo run -q -p claudevs-cli -- check crates/claudevs/examples/<name>; echo "exit=$?"`.

Expected outputs below come from runs of scratch copies of these files (identical except that 04's `tests/fixtures/notes-repo/README.md` and 08's reworded script comment were added afterwards; neither is read by any case) on a machine with `claude` 2.1.270 on `PATH`. The `validate` detail lines hold a machine-specific absolute path and are shown as `…`. Without `claude` on `PATH`, the first stage prints `  skip  validate` followed by ``cannot run `claude`: No such file or directory (os error 2)``, the summary counts one stage fewer and one skipped, and the exit code and every other stage line are unchanged. That was run for all eight examples with `env PATH=/usr/bin:/bin target/debug/claudevs check …`.

**Rules for every README and script comment in `crates/claudevs/examples/`** (spec §6): no `file:line` citations; none of the development vocabulary banned in `crates/clauders/CLAUDE.md:150-160`; quoted output is pasted from the run in the same task, with temp paths and the validate detail elided as `…`. Task 12 greps for both.

**Commits:** the `execute` skill reserves committing to the user. The final task gives a suggested message; no task runs `git commit`.

### Task 1 — Let the claudevs-check lane take full plugin paths

**Files:**
- Modify `Makefile.toml`

**Steps:**

1. Record the current lane as the baseline:

   ```
   $ cargo make claudevs-check
   ```

   Expected, among cargo-make's own log lines, and a zero exit:

   ```text
   ok  minimal-plugin (exit 0, no stage failed)
   ok  dead-script-plugin (exit 0, no stage failed)
   ok  escape-plugin (FAIL wiring)
   ok  bad-matcher-plugin (FAIL wiring)
   ok  hooks-array-plugin (FAIL wiring)
   ok  project-branch-plugin (exit 0, no stage failed)
   ok  exec-args-plugin (exit 0, no stage failed)
   ok  matcher-routing-plugin (FAIL test)
   ```

2. In `Makefile.toml`, replace the task description (`:167`):

   ```toml
   description = "claudevs check over the fixture plugin corpus, both directions"
   ```

   with:

   ```toml
   description = "claudevs check over the fixture plugin corpus and the example plugins, both directions"
   ```

3. Replace this block (`:203-212`):

   ```text
   # `root` is deliberately relative: `claudevs check` resolves `plugin_dir` to
   # an absolute path once, up front, and uses that single value for both the
   # spawned delegate's argv and its cwd (crates/claudevs/src/validate.rs), so a
   # relative path here is no longer doubled. Keeping it relative means that on
   # a machine that has `claude`, this lane also exercises the delegate's path
   # handling, so that defect cannot come back unnoticed.
   script_runner = "@shell"
   script = '''
   set -e
   root="crates/claudevs/tests/fixtures"
   ```

   with:

   ```text
   # Plugin paths are deliberately relative: `claudevs check` resolves `plugin_dir`
   # to an absolute path once, up front, and uses that single value for both the
   # spawned delegate's argv and its cwd (crates/claudevs/src/validate.rs), so a
   # relative path here is no longer doubled. Keeping them relative means that on
   # a machine that has `claude`, this lane also exercises the delegate's path
   # handling, so that defect cannot come back unnoticed.
   script_runner = "@shell"
   script = '''
   set -e
   ```

4. In the `_run` comment (`:220`), replace `never called from the fixture list below` with `never called from the plugin lists below`.

5. In the comment above `expect_no_fail` (`:248-251`), replace:

   ```text
   # Each fixture calls exactly one of the three functions below, and each one
   # runs `_run` itself before reading `$out`/`$got` — the two can no longer be
   # invoked separately, so there is no way to assert against a previous
   # fixture's stale output.
   ```

   with:

   ```text
   # Each plugin calls exactly one of the functions below, and each one
   # runs `_run` itself before reading `$out`/`$got` — the two can no longer be
   # invoked separately, so there is no way to assert against a previous
   # plugin's stale output.
   ```

   Then `grep -n "fixture's stale\|Each fixture" Makefile.toml` prints nothing, exit 1.

6. In `_run` (`:228`), replace:

   ```sh
       out="$(cargo run -q -p claudevs-cli -- check "$root/$plugin" 2>&1)"
   ```

   with:

   ```sh
       out="$(cargo run -q -p claudevs-cli -- check "$plugin" 2>&1)"
   ```

7. Replace each fixture call with its full path, keeping every expectation and the comments between them:

   | Line | Before | After |
   |---|---|---|
   | `:297` | `expect_no_fail minimal-plugin 0` | `expect_no_fail crates/claudevs/tests/fixtures/minimal-plugin 0` |
   | `:298` | `expect_no_fail dead-script-plugin 0` | `expect_no_fail crates/claudevs/tests/fixtures/dead-script-plugin 0` |
   | `:299` | `expect_stage_fail escape-plugin 1 wiring` | `expect_stage_fail crates/claudevs/tests/fixtures/escape-plugin 1 wiring` |
   | `:300` | `expect_stage_fail bad-matcher-plugin 1 wiring` | `expect_stage_fail crates/claudevs/tests/fixtures/bad-matcher-plugin 1 wiring` |
   | `:301` | `expect_stage_fail hooks-array-plugin 1 wiring` | `expect_stage_fail crates/claudevs/tests/fixtures/hooks-array-plugin 1 wiring` |
   | `:309` | `expect_no_fail project-branch-plugin 0` | `expect_no_fail crates/claudevs/tests/fixtures/project-branch-plugin 0` |
   | `:314` | `expect_no_fail exec-args-plugin 0` | `expect_no_fail crates/claudevs/tests/fixtures/exec-args-plugin 0` |
   | `:323` | `expect_stage_fail matcher-routing-plugin 1 test` | `expect_stage_fail crates/claudevs/tests/fixtures/matcher-routing-plugin 1 test` |

8. Confirm no `root` reference is left in the task:

   ```
   $ grep -n '\$root' Makefile.toml
   ```

   Expected: no output, exit 1.

9. Re-run the lane:

   ```
   $ cargo make claudevs-check
   ```

   Expected: a zero exit and the same eight verdicts as step 1, now naming full paths:

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

### Task 2 — Add 01_hook_decision and the examples marketplace manifest

**Files:**
- Modify `Makefile.toml`
- Create `crates/claudevs/examples/.claude-plugin/marketplace.json`
- Create `crates/claudevs/examples/01_hook_decision/.claude-plugin/plugin.json`
- Create `crates/claudevs/examples/01_hook_decision/hooks/hooks.json`
- Create `crates/claudevs/examples/01_hook_decision/hooks/protect-env.sh`
- Create `crates/claudevs/examples/01_hook_decision/tests/blocks-env-file.yaml`
- Create `crates/claudevs/examples/01_hook_decision/tests/asks-for-secrets.yaml`
- Create `crates/claudevs/examples/01_hook_decision/tests/allows-other-files.yaml`
- Create `crates/claudevs/examples/01_hook_decision/README.md`

**Steps:**

1. Write the expectation first. In `Makefile.toml`, directly after `expect_stage_fail crates/claudevs/tests/fixtures/matcher-routing-plugin 1 test` and before the closing `'''`, add:

   ```sh

   # The example plugins under crates/claudevs/examples/ are the ones the claudevs
   # docs teach from, and each example's README quotes the outcome asserted here.
   # The broken ones fail at a named stage on purpose, for the same reason the
   # must-fail fixtures above exist:
   #
   #   02_hook_decision_broken  test              its gate exits 1 where a PreToolUse deny needs 2
   #   07_wiring_broken         wiring            hooks.json names a script that does not exist
   #   08_installed_broken      test --installed  its hook reads a file above the plugin root
   expect_no_fail crates/claudevs/examples/01_hook_decision 0
   ```

2. Run the lane and confirm it fails on the missing example:

   ```
   $ cargo make claudevs-check
   ```

   Expected: the eight fixture lines from Task 1, then on stderr, and a non-zero exit:

   ```text
   claudevs check crates/claudevs/examples/01_hook_decision: expected exit 0, got 2
   claudevs: walk plugin `crates/claudevs/examples/01_hook_decision`: No such file or directory (os error 2)
   ```

3. Create `crates/claudevs/examples/.claude-plugin/marketplace.json`:

   ```json
   {
     "name": "claudevs-examples",
     "owner": { "name": "rstlix0x0" },
     "description": "Example plugins for the claudevs documentation; not a real marketplace.",
     "plugins": []
   }
   ```

4. Create `crates/claudevs/examples/01_hook_decision/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "hook-decision",
     "version": "0.1.0",
     "description": "claudevs example: a PreToolUse gate asserted with YAML hook cases",
     "author": { "name": "rstlix0x0" }
   }
   ```

5. Create `crates/claudevs/examples/01_hook_decision/hooks/hooks.json`:

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

6. Create `crates/claudevs/examples/01_hook_decision/hooks/protect-env.sh`:

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

7. Create `crates/claudevs/examples/01_hook_decision/tests/blocks-env-file.yaml`:

   ```yaml
   event: PreToolUse
   payload:
     tool_input:
       file_path: .env
   expect:
     decision: deny
     stderr_contains: refusing to edit a .env file
   ```

8. Create `crates/claudevs/examples/01_hook_decision/tests/asks-for-secrets.yaml`:

   ```yaml
   event: PreToolUse
   payload:
     tool_name: Write
     tool_input:
       file_path: secrets/api-key.txt
   expect:
     decision: ask
   ```

9. Create `crates/claudevs/examples/01_hook_decision/tests/allows-other-files.yaml`:

   ```yaml
   event: PreToolUse
   expect:
     exit: 0
     output: none
   ```

10. Run the example:

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

11. Create `crates/claudevs/examples/01_hook_decision/README.md`, pasting the output block from step 10's run (behaviour sources: exit 2 and `permissionDecision` both read as a decision, `semantics.rs:104-115,128-131`; a case's payload is laid over a per-event default, `payload.rs:14-34`, `suite.rs:310-316`):

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
    <paste step 10's output here, validate detail as …, without the exit= line>
    ```

    The exit code is 0.
    ````

    Replace the `<paste …>` line with the real output before saving; the finished file contains no angle-bracket placeholder.

12. Run the lane:

    ```
    $ cargo make claudevs-check
    ```

    Expected: a zero exit, the eight fixture lines from Task 1 step 8, then:

    ```text
    ok  crates/claudevs/examples/01_hook_decision (exit 0, no stage failed)
    ```

### Task 3 — Add 02_hook_decision_broken and prove its expectation can fail

**Files:**
- Modify `Makefile.toml`
- Create `crates/claudevs/examples/02_hook_decision_broken/.claude-plugin/plugin.json`
- Create `crates/claudevs/examples/02_hook_decision_broken/hooks/hooks.json`
- Create `crates/claudevs/examples/02_hook_decision_broken/hooks/protect-env.sh`
- Create `crates/claudevs/examples/02_hook_decision_broken/tests/blocks-env-file.yaml`
- Create `crates/claudevs/examples/02_hook_decision_broken/tests/asks-for-secrets.yaml`
- Create `crates/claudevs/examples/02_hook_decision_broken/tests/allows-other-files.yaml`
- Create `crates/claudevs/examples/02_hook_decision_broken/README.md`

**Steps:**

1. In `Makefile.toml`, after `expect_no_fail crates/claudevs/examples/01_hook_decision 0`, add:

   ```sh
   expect_stage_fail crates/claudevs/examples/02_hook_decision_broken 1 test
   ```

2. Run the lane:

   ```
   $ cargo make claudevs-check
   ```

   Expected: non-zero exit, with on stderr:

   ```text
   claudevs check crates/claudevs/examples/02_hook_decision_broken: expected exit 1, got 2
   claudevs: walk plugin `crates/claudevs/examples/02_hook_decision_broken`: No such file or directory (os error 2)
   ```

3. Create `crates/claudevs/examples/02_hook_decision_broken/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "hook-decision-broken",
     "version": "0.1.0",
     "description": "claudevs example: the hook-decision gate with a defect its cases catch",
     "author": { "name": "rstlix0x0" }
   }
   ```

4. Create `crates/claudevs/examples/02_hook_decision_broken/hooks/hooks.json`:

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

5. Create `crates/claudevs/examples/02_hook_decision_broken/hooks/protect-env.sh`. It is Task 2's script with `exit 2` changed to `exit 1` on the `.env` branch:

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

6. Create `crates/claudevs/examples/02_hook_decision_broken/tests/blocks-env-file.yaml`:

   ```yaml
   event: PreToolUse
   payload:
     tool_input:
       file_path: .env
   expect:
     decision: deny
     stderr_contains: refusing to edit a .env file
   ```

7. Create `crates/claudevs/examples/02_hook_decision_broken/tests/asks-for-secrets.yaml`:

   ```yaml
   event: PreToolUse
   payload:
     tool_name: Write
     tool_input:
       file_path: secrets/api-key.txt
   expect:
     decision: ask
   ```

8. Create `crates/claudevs/examples/02_hook_decision_broken/tests/allows-other-files.yaml`:

   ```yaml
   event: PreToolUse
   expect:
     exit: 0
     output: none
   ```

9. Run the example:

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

10. Run the lane and confirm green:

    ```
    $ cargo make claudevs-check
    ```

    Expected: zero exit; after the 01 line:

    ```text
    ok  crates/claudevs/examples/02_hook_decision_broken (FAIL test)
    ```

11. Prove the expectation can fail. In `crates/claudevs/examples/02_hook_decision_broken/hooks/protect-env.sh`, change `    exit 1` to `    exit 2`, then run the lane:

    ```
    $ cargo make claudevs-check
    ```

    Expected: non-zero exit, with on stderr the line below followed by a report ending `4 stages run, 0 failed, 0 skipped`:

    ```text
    claudevs check crates/claudevs/examples/02_hook_decision_broken: expected exit 1, got 0
    ```

    (With `exit 2` the script is Task 2's script, which step 10 of Task 2 shows ends at exit 0.)

12. Restore the defect: change `    exit 2` back to `    exit 1`, then confirm with `grep -n 'exit 1' crates/claudevs/examples/02_hook_decision_broken/hooks/protect-env.sh`. Expected: `8:    exit 1`. Re-run `cargo make claudevs-check`; expected zero exit with the `(FAIL test)` line from step 10.

13. Create `crates/claudevs/examples/02_hook_decision_broken/README.md`, pasting step 9's output (sources: `semantics.rs:104-115,128-131` for what reads as a decision; `suite.rs:38-47` for payload and handler printed only on a failing hook case; `check.rs:108-116` for both suite stages running the same cases):

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
    <paste step 9's output here, validate detail and cwd as …, without the exit= line>
    ```

    The exit code is 1. A failing hook case prints the payload the hook received and the handler that
    ran, which tells you which branch the hook took. Change `exit 1` to `exit 2` in the script and the
    run ends at 0.
    ````

    Replace the `<paste …>` line with the real output before saving.

### Task 4 — Add 03_session_context

**Files:**
- Modify `Makefile.toml`
- Create `crates/claudevs/examples/03_session_context/.claude-plugin/plugin.json`
- Create `crates/claudevs/examples/03_session_context/hooks/hooks.json`
- Create `crates/claudevs/examples/03_session_context/hooks/session-banner.sh`
- Create `crates/claudevs/examples/03_session_context/hooks/deploy-reminder.sh`
- Create `crates/claudevs/examples/03_session_context/tests/session-start-injects-banner.yaml`
- Create `crates/claudevs/examples/03_session_context/tests/deploy-prompt-gets-reminder.yaml`
- Create `crates/claudevs/examples/03_session_context/tests/ordinary-prompt-stays-silent.yaml`
- Create `crates/claudevs/examples/03_session_context/README.md`

**Steps:**

1. In `Makefile.toml`, after `expect_stage_fail crates/claudevs/examples/02_hook_decision_broken 1 test`, add:

   ```sh
   expect_no_fail crates/claudevs/examples/03_session_context 0
   ```

2. Run `cargo make claudevs-check`. Expected: non-zero exit, with on stderr:

   ```text
   claudevs check crates/claudevs/examples/03_session_context: expected exit 0, got 2
   claudevs: walk plugin `crates/claudevs/examples/03_session_context`: No such file or directory (os error 2)
   ```

3. Create `crates/claudevs/examples/03_session_context/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "session-context",
     "version": "0.1.0",
     "description": "claudevs example: context injected at SessionStart and UserPromptSubmit",
     "author": { "name": "rstlix0x0" }
   }
   ```

4. Create `crates/claudevs/examples/03_session_context/hooks/hooks.json`:

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

5. Create `crates/claudevs/examples/03_session_context/hooks/session-banner.sh`:

   ```sh
   #!/bin/sh
   # Plain stdout from a SessionStart hook becomes context for the session.
   echo "session-banner: run the test suite before you commit"
   ```

6. Create `crates/claudevs/examples/03_session_context/hooks/deploy-reminder.sh`:

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

7. Create `crates/claudevs/examples/03_session_context/tests/session-start-injects-banner.yaml`:

   ```yaml
   event: SessionStart
   expect:
     context_contains: run the test suite
   ```

8. Create `crates/claudevs/examples/03_session_context/tests/deploy-prompt-gets-reminder.yaml`:

   ```yaml
   event: UserPromptSubmit
   payload:
     prompt: deploy the api to production
   expect:
     context_contains: change ticket
   ```

9. Create `crates/claudevs/examples/03_session_context/tests/ordinary-prompt-stays-silent.yaml`:

   ```yaml
   event: UserPromptSubmit
   expect:
     output: none
   ```

10. Run the example:

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

11. Run `cargo make claudevs-check`. Expected: zero exit; after the 02 line:

    ```text
    ok  crates/claudevs/examples/03_session_context (exit 0, no stage failed)
    ```

12. Create `crates/claudevs/examples/03_session_context/README.md`, pasting step 10's output (sources: bare stdout is context on events the catalogue marks `stdout_is_context`, `semantics.rs:120-126`, true for `SessionStart` and `UserPromptSubmit` at `contract/event.rs:94,106`; `additionalContext`, `semantics.rs:116-119`; `output: none` fails on any emission, `verdict.rs:141-145`, and is refused outside hook cases, `model.rs:258-267`; default prompt `hello`, `payload.rs:28`):

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
    <paste step 10's output here, validate detail as …, without the exit= line>
    ```

    The exit code is 0.
    ````

    Replace the `<paste …>` line with the real output before saving.

### Task 5 — Add 04_script_and_flow

**Files:**
- Modify `Makefile.toml`
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

1. In `Makefile.toml`, after `expect_no_fail crates/claudevs/examples/03_session_context 0`, add:

   ```sh
   expect_no_fail crates/claudevs/examples/04_script_and_flow 0
   ```

2. Run `cargo make claudevs-check`. Expected: non-zero exit, with on stderr:

   ```text
   claudevs check crates/claudevs/examples/04_script_and_flow: expected exit 0, got 2
   claudevs: walk plugin `crates/claudevs/examples/04_script_and_flow`: No such file or directory (os error 2)
   ```

3. Create `crates/claudevs/examples/04_script_and_flow/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "script-and-flow",
     "version": "0.1.0",
     "description": "claudevs example: script cases and multi-step flows over a fixture project",
     "author": { "name": "rstlix0x0" }
   }
   ```

4. Create `crates/claudevs/examples/04_script_and_flow/skills/notes/SKILL.md`. The fenced commands name both scripts, which is what keeps the `invocations` checker from reporting them as referenced by nothing (`wiring/invocations.rs:131-147`):

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

5. Create `crates/claudevs/examples/04_script_and_flow/scripts/greet.sh`:

   ```sh
   #!/bin/sh
   # Greets whoever GREETING_NAME names.
   printf 'hello, %s\n' "${GREETING_NAME:?GREETING_NAME is required}"
   ```

6. Create `crates/claudevs/examples/04_script_and_flow/scripts/new-note.sh`:

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

7. Create `crates/claudevs/examples/04_script_and_flow/tests/greets-by-name.yaml`:

   ```yaml
   invocation:
     argv: [sh, -c, 'sh "$CLAUDE_PLUGIN_ROOT/scripts/greet.sh"']
     env:
       GREETING_NAME: claudevs
   expect:
     exit: 0
     stdout_contains: hello, claudevs
   ```

8. Create `crates/claudevs/examples/04_script_and_flow/tests/new-note-flow.yaml`:

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

9. Create the empty marker `crates/claudevs/examples/04_script_and_flow/tests/fixtures/notes-repo/.gitinit`:

   ```
   $ touch crates/claudevs/examples/04_script_and_flow/tests/fixtures/notes-repo/.gitinit
   ```

10. Create `crates/claudevs/examples/04_script_and_flow/tests/fixtures/notes-repo/README.md`:

    ```markdown
    # Notes repository

    A fixture project. The `.gitinit` marker beside this file makes claudevs run `git init` in the copy.
    ```

11. Create `crates/claudevs/examples/04_script_and_flow/tests/fixtures/imported-notes/notes/imported.md`:

    ```markdown
    # Imported note
    ```

12. Run the example:

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

13. Run `cargo make claudevs-check`. Expected: zero exit; after the 03 line:

    ```text
    ok  crates/claudevs/examples/04_script_and_flow (exit 0, no stage failed)
    ```

14. Create `crates/claudevs/examples/04_script_and_flow/README.md`, pasting step 12's output (sources: argv spawned directly, `harness/spawn.rs:3-5`; cwd is the case's temp project, `suite.rs:165-168,243-244`; environment `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PROJECT_DIR`, `harness/environment.rs`, plus `invocation.env`, `suite.rs:335-338`; `.gitinit` runs `git init` and one empty commit and is not copied, `harness/project.rs:3-5,115-131`; a step's `expect` gates the flow, `suite.rs:376-390`; top-level `expect` judged against the last step that ran, `suite.rs:397-398`; `files_exist` relative to the project, `verdict.rs:174-175`; `tests/fixtures/` is never searched for cases, `case/discover.rs:39,56-62`):

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
    <paste step 12's output here, validate detail as …, without the exit= line>
    ```

    The exit code is 0.
    ````

    Replace the `<paste …>` line with the real output before saving.

### Task 6 — Add 05_lua_cases

**Files:**
- Modify `Makefile.toml`
- Create `crates/claudevs/examples/05_lua_cases/.claude-plugin/plugin.json`
- Create `crates/claudevs/examples/05_lua_cases/hooks/hooks.json`
- Create `crates/claudevs/examples/05_lua_cases/hooks/block-force-push.sh`
- Create `crates/claudevs/examples/05_lua_cases/skills/release/SKILL.md`
- Create `crates/claudevs/examples/05_lua_cases/scripts/version.sh`
- Create `crates/claudevs/examples/05_lua_cases/tests/allows-plain-push.yaml`
- Create `crates/claudevs/examples/05_lua_cases/tests/force_push_test.lua`
- Create `crates/claudevs/examples/05_lua_cases/README.md`

**Steps:**

1. In `Makefile.toml`, after `expect_no_fail crates/claudevs/examples/04_script_and_flow 0`, add:

   ```sh
   expect_no_fail crates/claudevs/examples/05_lua_cases 0
   ```

2. Run `cargo make claudevs-check`. Expected: non-zero exit, with on stderr:

   ```text
   claudevs check crates/claudevs/examples/05_lua_cases: expected exit 0, got 2
   claudevs: walk plugin `crates/claudevs/examples/05_lua_cases`: No such file or directory (os error 2)
   ```

3. Create `crates/claudevs/examples/05_lua_cases/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "lua-cases",
     "version": "0.3.1",
     "description": "claudevs example: generated data cases and scripted cases in Lua",
     "author": { "name": "rstlix0x0" }
   }
   ```

4. Create `crates/claudevs/examples/05_lua_cases/hooks/hooks.json`:

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

5. Create `crates/claudevs/examples/05_lua_cases/hooks/block-force-push.sh`:

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

6. Create `crates/claudevs/examples/05_lua_cases/skills/release/SKILL.md`:

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

7. Create `crates/claudevs/examples/05_lua_cases/scripts/version.sh`:

   ```sh
   #!/bin/sh
   # Prints the version field of this plugin's manifest.
   sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json"
   ```

8. Create `crates/claudevs/examples/05_lua_cases/tests/allows-plain-push.yaml`:

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

9. Create `crates/claudevs/examples/05_lua_cases/tests/force_push_test.lua`:

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

10. Run the example:

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

11. Capture the `migrate` output the README quotes:

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

12. Run `cargo make claudevs-check`. Expected: zero exit; after the 04 line:

    ```text
    ok  crates/claudevs/examples/05_lua_cases (exit 0, no stage failed)
    ```

13. Create `crates/claudevs/examples/05_lua_cases/README.md`, pasting steps 10 and 11 (sources: table entries are data cases through the same path as YAML and function entries are scripted, `case/lua.rs:1-5,61-72`; case-file naming, `case/discover.rs:73-78`; case-name characters, `types/case_name.rs:6,24-28`; a scripted case passes by returning, `case/lua.rs:124-125` and `case/runner.rs:37-46`; `t` functions, `harness/t_module.rs:4-14`; confined Lua with zero grants while `t` runs host-side and `t.script` spawns any argv, `harness/t_module.rs:16-24`; `migrate --write` writes `<stem>_test.lua` with `-` turned into `_` and removes the YAML, `claudevs-cli/src/cli.rs:134-153`):

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
    <paste step 11's output here, without the exit= line>
    ```

    `claudevs migrate --write` instead writes `allows_plain_push_test.lua` next to the YAML file and
    deletes the YAML file.

    ## Run it

    ```console
    $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/05_lua_cases
    ```

    ```text
    <paste step 10's output here, validate detail as …, without the exit= line>
    ```

    The exit code is 0.
    ````

    Replace both `<paste …>` lines with the real output before saving.

### Task 7 — Add 06_native_suite

**Files:**
- Modify `Makefile.toml`
- Create `crates/claudevs/examples/06_native_suite/.claude-plugin/plugin.json`
- Create `crates/claudevs/examples/06_native_suite/claudevs.toml`
- Create `crates/claudevs/examples/06_native_suite/hooks/hooks.json`
- Create `crates/claudevs/examples/06_native_suite/hooks/session-banner.sh`
- Create `crates/claudevs/examples/06_native_suite/tests/native/syntax-check.sh`
- Create `crates/claudevs/examples/06_native_suite/tests/session-banner.yaml`
- Create `crates/claudevs/examples/06_native_suite/README.md`

**Steps:**

1. In `Makefile.toml`, after `expect_no_fail crates/claudevs/examples/05_lua_cases 0`, add:

   ```sh
   expect_no_fail crates/claudevs/examples/06_native_suite 0
   ```

2. Run `cargo make claudevs-check`. Expected: non-zero exit, with on stderr:

   ```text
   claudevs check crates/claudevs/examples/06_native_suite: expected exit 0, got 2
   claudevs: walk plugin `crates/claudevs/examples/06_native_suite`: No such file or directory (os error 2)
   ```

3. Create `crates/claudevs/examples/06_native_suite/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "native-suite",
     "version": "0.1.0",
     "description": "claudevs example: a native test command declared in claudevs.toml",
     "author": { "name": "rstlix0x0" }
   }
   ```

4. Create `crates/claudevs/examples/06_native_suite/claudevs.toml`:

   ```toml
   [[native]]
   run = "sh tests/native/syntax-check.sh"
   ```

5. Create `crates/claudevs/examples/06_native_suite/hooks/hooks.json`:

   ```json
   {
     "hooks": {
       "SessionStart": [
         { "hooks": [ { "type": "command", "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/session-banner.sh\"" } ] }
       ]
     }
   }
   ```

6. Create `crates/claudevs/examples/06_native_suite/hooks/session-banner.sh`:

   ```sh
   #!/bin/sh
   echo "session-banner: native suite example"
   ```

7. Create `crates/claudevs/examples/06_native_suite/tests/native/syntax-check.sh`:

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

8. Create `crates/claudevs/examples/06_native_suite/tests/session-banner.yaml`:

   ```yaml
   event: SessionStart
   expect:
     context_contains: native suite example
   ```

9. Run the example:

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

10. Run `cargo make claudevs-check`. Expected: zero exit; after the 05 line:

    ```text
    ok  crates/claudevs/examples/06_native_suite (exit 0, no stage failed)
    ```

11. Create `crates/claudevs/examples/06_native_suite/README.md`, pasting step 9's output (sources: `claudevs.toml` at the plugin root, `run` spawned with `sh -c` in the plugin directory, only the exit code asserted, `native/declared.rs:1-10,55`; `run` is the only accepted key, `native/declared.rs:35-47`; output printed only under a non-zero exit, `report/render.rs:157-168`; case-file naming, `case/discover.rs:73-78`; cases are discovered before native suites run and none found is an error, `suite.rs:90,129` and `case/discover.rs:48-52`, which `claudevs test` turns into exit 2, `claudevs-cli/src/cli.rs:123-126`):

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
    <paste step 9's output here, validate detail as …, without the exit= line>
    ```

    The exit code is 0.
    ````

    Replace the `<paste …>` line with the real output before saving.

### Task 8 — Add 07_wiring_broken and prove its expectation can fail

**Files:**
- Modify `Makefile.toml`
- Create `crates/claudevs/examples/07_wiring_broken/.claude-plugin/plugin.json`
- Create `crates/claudevs/examples/07_wiring_broken/hooks/hooks.json`
- Create `crates/claudevs/examples/07_wiring_broken/hooks/session-banner.sh`
- Create `crates/claudevs/examples/07_wiring_broken/hooks/format.sh`
- Create `crates/claudevs/examples/07_wiring_broken/tests/session-banner.yaml`
- Create `crates/claudevs/examples/07_wiring_broken/README.md`

**Steps:**

1. In `Makefile.toml`, after `expect_no_fail crates/claudevs/examples/06_native_suite 0`, add:

   ```sh
   expect_stage_fail crates/claudevs/examples/07_wiring_broken 1 wiring
   ```

2. Run `cargo make claudevs-check`. Expected: non-zero exit, with on stderr:

   ```text
   claudevs check crates/claudevs/examples/07_wiring_broken: expected exit 1, got 2
   claudevs: walk plugin `crates/claudevs/examples/07_wiring_broken`: No such file or directory (os error 2)
   ```

3. Create `crates/claudevs/examples/07_wiring_broken/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "wiring-broken",
     "version": "0.1.0",
     "description": "claudevs example: a hooks.json reference to a script that does not exist",
     "author": { "name": "rstlix0x0" }
   }
   ```

4. Create `crates/claudevs/examples/07_wiring_broken/hooks/hooks.json`. The `format-on-write.sh` reference on line 9 is the defect:

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

5. Create `crates/claudevs/examples/07_wiring_broken/hooks/session-banner.sh`:

   ```sh
   #!/bin/sh
   echo "session-banner: wiring example"
   ```

6. Create `crates/claudevs/examples/07_wiring_broken/hooks/format.sh`:

   ```sh
   #!/bin/sh
   # Formats the file a Write just touched.
   exit 0
   ```

7. Create `crates/claudevs/examples/07_wiring_broken/tests/session-banner.yaml`:

   ```yaml
   event: SessionStart
   expect:
     context_contains: wiring example
   ```

8. Run the example:

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

9. Run `cargo make claudevs-check`. Expected: zero exit; after the 06 line:

   ```text
   ok  crates/claudevs/examples/07_wiring_broken (FAIL wiring)
   ```

10. Prove the expectation can fail. In `crates/claudevs/examples/07_wiring_broken/hooks/hooks.json`, change `hooks/format-on-write.sh` to `hooks/format.sh`, then run `cargo make claudevs-check`. Expected: non-zero exit, with on stderr the line below followed by a report ending `4 stages run, 0 failed, 0 skipped`:

    ```text
    claudevs check crates/claudevs/examples/07_wiring_broken: expected exit 1, got 0
    ```

11. Restore the defect: change `hooks/format.sh` back to `hooks/format-on-write.sh` in `hooks.json`. Confirm with `grep -n 'format-on-write' crates/claudevs/examples/07_wiring_broken/hooks/hooks.json`; expected one match on line 9. Re-run `cargo make claudevs-check`; expected zero exit with the `(FAIL wiring)` line from step 9.

12. Create `crates/claudevs/examples/07_wiring_broken/README.md`, pasting step 8's output (sources: `refs` resolves `${CLAUDE_PLUGIN_ROOT}/…` references in the files Claude Code loads, `wiring/refs.rs:1-3,84-86` and `contract/site.rs:24-39`; a missing target is `Severity::Error` with this message, `wiring/refs.rs:99,121`; wiring runs nothing, `wiring/mod.rs:1`; a failed stage does not stop later stages, `check.rs:28`):

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
    <paste step 8's output here, validate detail as …, without the exit= line>
    ```

    The exit code is 1. Point the command at `hooks/format.sh` and the run ends at 0.
    ````

    Replace the `<paste …>` line with the real output before saving.

### Task 9 — Add 08_installed_broken and prove its expectation can fail

**Files:**
- Modify `Makefile.toml`
- Create `crates/claudevs/examples/shared/policy-message.txt`
- Create `crates/claudevs/examples/08_installed_broken/.claude-plugin/plugin.json`
- Create `crates/claudevs/examples/08_installed_broken/hooks/hooks.json`
- Create `crates/claudevs/examples/08_installed_broken/hooks/block-rm-rf.sh`
- Create `crates/claudevs/examples/08_installed_broken/tests/blocks-rm-rf.yaml`
- Create `crates/claudevs/examples/08_installed_broken/README.md`

**Steps:**

1. In `Makefile.toml`, after `expect_stage_fail crates/claudevs/examples/07_wiring_broken 1 wiring`, add:

   ```sh
   expect_stage_fail crates/claudevs/examples/08_installed_broken 1 "test --installed"
   ```

2. Run `cargo make claudevs-check`. Expected: non-zero exit, with on stderr:

   ```text
   claudevs check crates/claudevs/examples/08_installed_broken: expected exit 1, got 2
   claudevs: walk plugin `crates/claudevs/examples/08_installed_broken`: No such file or directory (os error 2)
   ```

3. Create `crates/claudevs/examples/shared/policy-message.txt`:

   ```text
   blocked-by-policy: recursive deletes are not allowed
   ```

4. Create `crates/claudevs/examples/08_installed_broken/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "installed-broken",
     "version": "0.1.0",
     "description": "claudevs example: a hook that reads a file outside its plugin root",
     "author": { "name": "rstlix0x0" }
   }
   ```

5. Create `crates/claudevs/examples/08_installed_broken/hooks/hooks.json`:

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

6. Create `crates/claudevs/examples/08_installed_broken/hooks/block-rm-rf.sh`. The unbraced `$CLAUDE_PLUGIN_ROOT/../shared/…` on line 5 is the defect:

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

7. Create `crates/claudevs/examples/08_installed_broken/tests/blocks-rm-rf.yaml`:

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

8. Run the example:

   ```
   $ cargo run -q -p claudevs-cli -- check crates/claudevs/examples/08_installed_broken; echo "exit=$?"
   ```

   Expected (temp directories shown as `…`; on Linux the `cat:` wording comes from GNU coreutils and may differ, which the lane does not read):

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

9. Run `cargo make claudevs-check`. Expected: zero exit; after the 07 line:

   ```text
   ok  crates/claudevs/examples/08_installed_broken (FAIL test --installed)
   ```

10. Prove the expectation can fail. Move the message inside the plugin:

    ```
    $ cp crates/claudevs/examples/shared/policy-message.txt crates/claudevs/examples/08_installed_broken/policy-message.txt
    ```

    and in `hooks/block-rm-rf.sh` change `"$CLAUDE_PLUGIN_ROOT/../shared/policy-message.txt"` to `"$CLAUDE_PLUGIN_ROOT/policy-message.txt"`. Run `cargo make claudevs-check`. Expected: non-zero exit, with on stderr the line below followed by a report ending `4 stages run, 0 failed, 0 skipped`:

    ```text
    claudevs check crates/claudevs/examples/08_installed_broken: expected exit 1, got 0
    ```

11. Restore the defect:

    ```
    $ rm crates/claudevs/examples/08_installed_broken/policy-message.txt
    ```

    and change `"$CLAUDE_PLUGIN_ROOT/policy-message.txt"` back to `"$CLAUDE_PLUGIN_ROOT/../shared/policy-message.txt"`. Confirm with `grep -n 'shared/policy-message' crates/claudevs/examples/08_installed_broken/hooks/block-rm-rf.sh`; expected one match on line 5. Re-run `cargo make claudevs-check`; expected zero exit with the `(FAIL test --installed)` line from step 9.

12. Create `crates/claudevs/examples/08_installed_broken/README.md`, pasting step 8's output (sources: the installed copy at `cache/<marketplace>/<plugin>/<version>/` with `CLAUDE_PLUGIN_ROOT` pointed at it, `layout/installed.rs:3-9,51-56` and `suite.rs:136-148`; only the plugin directory is copied, `layout/installed.rs:43-60`; `refs` matches only the braced form, `wiring/refs.rs:29-30`; exit 2 on `PreToolUse` reads as deny, `semantics.rs:128-131`):

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
    <paste step 8's output here, validate detail and temp paths as …, without the exit= line>
    ```

    The exit code is 1.
    ````

    Replace the `<paste …>` line with the real output before saving.

### Task 10 — Write the examples index

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

   `cargo make claudevs-check` runs `claudevs check` over every example and asserts the exit code and
   the stage in the last column, so an example that stops matching its README fails the build.

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

### Task 11 — Name the examples in the CI job and in CLAUDE.md

**Files:**
- Modify `.github/workflows/ci.yml`
- Modify `CLAUDE.md`

**Steps:**

1. In `.github/workflows/ci.yml` (`:65`), replace:

   ```yaml
       name: claudevs fixture corpus
   ```

   with:

   ```yaml
       name: claudevs fixtures and examples
   ```

   The job id `claudevs-check` (`:64`) stays, because the `dod` job's cache comment names it (`:44`).

2. In `CLAUDE.md`, replace these lines (`:182-185`):

   ```text
   That same workflow carries two jobs the gate deliberately excludes. `cargo make claudevs-check` runs
   `claudevs check` over the fixture plugin corpus in `crates/claudevs/tests/fixtures/` in both
   directions — fixtures that must pass and fixtures that must fail at a named stage — because a corpus
   of only-passing fixtures would go green the day the checkers stopped reporting. `cargo make deny`
   ```

   with:

   ```text
   That same workflow carries two jobs the gate deliberately excludes. `cargo make claudevs-check` runs
   `claudevs check` over the fixture plugin corpus in `crates/claudevs/tests/fixtures/` and the example
   plugins in `crates/claudevs/examples/`, in both directions — plugins that must pass and plugins that
   must fail at a named stage — because a corpus of only-passing plugins would go green the day the
   checkers stopped reporting. `cargo make deny`
   ```

3. Verify:

   ```
   $ grep -n 'claudevs fixtures and examples' .github/workflows/ci.yml
   $ grep -n 'example$' CLAUDE.md
   $ grep -n 'plugins in `crates/claudevs/examples/`' CLAUDE.md
   ```

   Expected: `65:    name: claudevs fixtures and examples`; `183:` ending in `and the example`; one match on line 184.

### Task 12 — Verify the whole plan and hand off for commit

**Steps:**

1. Run the lane (it rebuilds the binary through `cargo run` as needed):

   ```
   $ cargo make claudevs-check
   ```

   Expected: zero exit, and these sixteen lines in this order:

   ```text
   ok  crates/claudevs/tests/fixtures/minimal-plugin (exit 0, no stage failed)
   ok  crates/claudevs/tests/fixtures/dead-script-plugin (exit 0, no stage failed)
   ok  crates/claudevs/tests/fixtures/escape-plugin (FAIL wiring)
   ok  crates/claudevs/tests/fixtures/bad-matcher-plugin (FAIL wiring)
   ok  crates/claudevs/tests/fixtures/hooks-array-plugin (FAIL wiring)
   ok  crates/claudevs/tests/fixtures/project-branch-plugin (exit 0, no stage failed)
   ok  crates/claudevs/tests/fixtures/exec-args-plugin (exit 0, no stage failed)
   ok  crates/claudevs/tests/fixtures/matcher-routing-plugin (FAIL test)
   ok  crates/claudevs/examples/01_hook_decision (exit 0, no stage failed)
   ok  crates/claudevs/examples/02_hook_decision_broken (FAIL test)
   ok  crates/claudevs/examples/03_session_context (exit 0, no stage failed)
   ok  crates/claudevs/examples/04_script_and_flow (exit 0, no stage failed)
   ok  crates/claudevs/examples/05_lua_cases (exit 0, no stage failed)
   ok  crates/claudevs/examples/06_native_suite (exit 0, no stage failed)
   ok  crates/claudevs/examples/07_wiring_broken (FAIL wiring)
   ok  crates/claudevs/examples/08_installed_broken (FAIL test --installed)
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

5. Confirm the change set:

   ```
   $ git status --short
   ```

   Expected, besides the chain directory `.claudestacks/sdlc/2026-09-13-claudevs-docs/` if it is still uncommitted:

   ```text
    M .github/workflows/ci.yml
    M CLAUDE.md
    M Makefile.toml
   ?? crates/claudevs/examples/
   ```

6. Hand the change to the user. Suggested message, if they commit it:

   ```text
   feat(claudevs): add example plugins asserted by claudevs-check

   Eight example plugins under crates/claudevs/examples/, three broken on
   purpose, each run by `cargo make claudevs-check` with its exit code and
   stage asserted. The lane takes full plugin paths so fixtures and examples
   share one set of assertions, and the CI job is renamed to match.
   ```

---

## Verification summary (plan-level)

- `cargo make claudevs-check` exits 0 with sixteen `ok  …` lines, and each broken example's expectation was seen failing with its defect removed (Tasks 3, 8, 9).
- The same stage outcomes hold with `claude` absent from `PATH` (Task 12 step 2), which is the CI runner's environment (`ci.yml:88-89`).
- No example is a Cargo target, and no Rust source or rustdoc changed, so the Definition of Done is unaffected.
- Shipped READMEs and scripts carry no `file:line`, no banned vocabulary, and no unfilled paste markers.
