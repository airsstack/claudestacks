# Running the Gate

`claudevs test` runs your cases. `claudevs check` runs everything that should be true before you ship
the plugin, and the case suite is one part of it. This page runs the gate, breaks the hook so a case
fails, reads the failure, and fixes it.

## Run the gate

```bash
claudevs check my-marketplace/my-plugin
```

The command exits with status 0:

```text
  ok    validate
        Validating plugin manifest: /private/tmp/claudevs-demo/my-marketplace/my-plugin/.claude-plugin/plugin.json
        Plugin directory checks for /private/tmp/claudevs-demo/my-marketplace/my-plugin. The plugin directory is the catalog that plugins are submitted to; this is a subset of what it runs.
        ✘ Found 2 problems the plugin directory refuses a submission for:
          ❯ README.md: README missing (README_MISSING). This plugin has no README.md. People who install it and the directory's automated review read the README to learn what it does; the first line of a README in the plugin folder also stands in as the listing summary when plugin.json has no description.
            Fix: Add a README.md to the plugin folder describing what the plugin does, how to use it, and any setup it needs, in at least 40 words. A README at the repository root also counts for a plugin in a sub-folder.
          ❯ LICENSE: License missing (LICENSE_MISSING). This plugin has no LICENSE file and plugin.json has no `license`. The directory requires one of them.
            Fix: Add a LICENSE file to the plugin folder, or set `license` (an SPDX id) in plugin.json. A LICENSE at the repository root also counts for a plugin in a sub-folder.
        ⚠ Found 1 plugin directory warning:
          ❯ .claude-plugin/plugin.json icon: No icon (ICON_MISSING). No icon found in the plugin. The validator looked for `icon` in plugin.json and for a file at .claude-plugin/icon.png or .svg, assets/icon.png or .svg, or a similar path.
            Fix: Add a square PNG to the plugin folder at .claude-plugin/icon.png, or set `icon` in plugin.json to the path of a square PNG or JPEG in the plugin: 512 to 2048 px on each side, under 2 MB. SVG and WebP are not accepted. That file may become the listing icon only once: the first time the plugin is saved or submitted in the developer portal. Adding or changing it later does not change the icon.
        These plugin directory checks do not change the result below. To fail on problems the directory refuses a submission for, run this command with --profile directory.
        The directory also runs a safety scan and a policy review that this command does not.
        ✔ Validation passed
  ok    wiring
        0 errors, 0 warnings
  ok    test
          ok    blocks-env-file
        1 passed, 0 failed (1 cases, 0 native suites)
  ok    test --installed
          ok    blocks-env-file
        1 passed, 0 failed (1 cases, 0 native suites)

4 stages run, 0 failed, 0 skipped
```

`check` runs four stages in order:

1. `validate` hands the manifest to `claude plugin validate`. The lines under it are written by
   `claude`, so their wording changes with the version of `claude` you have. Here it also lists
   directory submission notes. They do not change the result, and the stage ends with
   `Validation passed`.
2. `wiring` checks the plugin's files against each other, for instance that a path in `hooks.json`
   points at a file that exists.
3. `test` runs the case suite, as `claudevs test` did on the last page.
4. `test --installed` runs the same cases again from the simulated install layout.

Without `claude` on `PATH`, the first stage is skipped and the run still ends with status 0:

```text
  skip  validate
        cannot run `claude`: No such file or directory (os error 2)
  ok    wiring
        0 errors, 0 warnings
  ok    test
          ok    blocks-env-file
        1 passed, 0 failed (1 cases, 0 native suites)
  ok    test --installed
          ok    blocks-env-file
        1 passed, 0 failed (1 cases, 0 native suites)

3 stages run, 0 failed, 1 skipped
```

## Break the hook

In `protect-env.sh`, change `exit 2` to `exit 1`. Then run the cases:

```bash
claudevs test my-marketplace/my-plugin
```

The command exits with status 1:

```text
  FAIL  blocks-env-file
        decision: expected Deny, got None
        payload: {"cwd":"/var/folders/8w/4ccj7cw90nx4d32s72tqf5nw0000gn/T/.tmpy8YU7n","hook_event_name":"PreToolUse","session_id":"claudevs-test","tool_input":{"file_path":".env"},"tool_name":"Edit"}
        handler: sh "${CLAUDE_PLUGIN_ROOT}/hooks/protect-env.sh"

0 passed, 1 failed (1 cases, 0 native suites)
```

There are three lines to read after the case name:

- The mismatch itself: the case expected a deny and the hook produced no decision.
- The payload the hook received, with the default fields filled in. The `cwd` is a temporary project
  directory, so yours will differ.
- The handler that ran.

Exit 1 is not a `PreToolUse` denial as far as `claudevs` is concerned. Only exit 2 counts, so the
case reports no decision at all. The example
[`02_hook_decision_broken`](https://github.com/airsstack/claudestacks/tree/main/crates/claudevs/examples/02_hook_decision_broken)
works through this failure in full.

## Fix it and test the installed copy

Change `exit 1` back to `exit 2`. Then run the cases against the installed copy:

```bash
claudevs test --installed my-marketplace/my-plugin
```

The command exits with status 0:

```text
  ok    blocks-env-file

1 passed, 0 failed (1 cases, 0 native suites)
```

`--installed` runs the same cases against a throwaway copy of the plugin, made at a path shaped like
`cache/<marketplace>/<plugin>/<version>/`. `CLAUDE_PLUGIN_ROOT` points at that copy instead of your
source directory. A hook that reads a file outside its own plugin passes `test` and fails only here.
The example
[`08_installed_broken`](https://github.com/airsstack/claudestacks/tree/main/crates/claudevs/examples/08_installed_broken)
is a plugin that does exactly that.

You now have a plugin, a case and a passing gate. [Writing Cases](ch06-00-writing-cases.md) covers
what else a case can assert, and [the check gate](ch07-00-check-gate.md) covers what each stage does
and how to run it in CI.
