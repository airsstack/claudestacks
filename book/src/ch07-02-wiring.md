# Wiring

By the end of this page you will know what the `wiring` stage looks at, which findings fail it, and
why a matcher `claudevs` cannot evaluate is a warning.

## What the stage checks

`wiring` reads your plugin's files and runs nothing. It has three checkers, and each reports
findings.

| Checker | Severity | It reports |
|---|---|---|
| `refs` | error | A `${CLAUDE_PLUGIN_ROOT}/…` reference to a file that does not exist, or one that climbs out of the plugin root. |
| `invocations` | warning | A script in the plugin that nothing else mentions. |
| `matchers` | error or warning | A `hooks.json` that is not JSON, or has no `hooks` object, is an error. An unknown event name, a matcher on an event that takes none, and a matcher `claudevs` cannot evaluate are warnings. |

Only an error fails the stage. A warning is printed and the stage still passes. The `refs` checker
reads the braced form `${CLAUDE_PLUGIN_ROOT}`. It does not read `$CLAUDE_PLUGIN_ROOT` without braces.

Here is `refs` failing on
[`07_wiring_broken`](https://github.com/airsstack/claudestacks/tree/main/crates/claudevs/examples/07_wiring_broken),
whose `PostToolUse` hook runs `format-on-write.sh` while the script in `hooks/` is `format.sh`:

```console
$ claudevs check --json crates/claudevs/examples/07_wiring_broken | jq -r '.stages[] | select(.name == "wiring") | .detail'
  error  refs  hooks/hooks.json:9  `${CLAUDE_PLUGIN_ROOT}/hooks/format-on-write.sh` does not exist

1 error, 0 warnings
```

Each finding is one line: severity, checker, file with a line number when there is one, then the
message. The last line counts errors and warnings.

## Why a matcher claudevs cannot evaluate is a warning

A `matcher` value in `hooks.json` is not a Rust regular expression, even where it looks like one. The
hooks reference defines two modes. A value made only of letters, digits, `_`, `-`, spaces, `,` and `|`
is an exact string, or a list of exact strings separated by `|` or `,`. Any other character makes the
whole value a regular expression, matched anywhere in the name. `claudevs` judges a matcher's shape
against those modes and does not compile every value with Rust's regex engine.

`FileChanged` and `StopFailure` use a narrower exact set: letters, digits, `_` and `|`. A hyphen,
space or comma in one of their matchers puts it in the regular-expression mode.

Once a value falls into the pattern mode, `claudevs` does compile it, because that is how it matches
the value when it runs your cases. Rust's regex engine and the one the runtime uses do not accept
exactly the same syntax. Rust has no look-around and no backreferences, so a pattern that works in
Claude Code can fail to compile here.

When that happens, `claudevs` cannot tell whether the runtime accepts the pattern. It reports a
warning that names the divergence, and never an error against the plugin. An error would punish the
plugin for a gap in `claudevs` and not for a defect in the plugin.

To see it, copy the `01_hook_decision` example to a scratch directory and change the matcher in the
copy's `hooks/hooks.json` from `Edit|Write` to `(?!Read)(Edit|Write)`:

```console
$ cp -R crates/claudevs/examples/01_hook_decision /tmp/lookahead-demo
$ claudevs check --json /tmp/lookahead-demo > report.json
$ jq -r '.stages[] | select(.name == "wiring") | .detail' report.json
  warn   matchers  hooks/hooks.json  claudevs cannot evaluate matcher `(?!Read)(Edit|Write)` (regex parse error:
    (?!Read)(Edit|Write)
    ^^^
error: look-around, including look-ahead and look-behind, is not supported), so it cannot tell whether the runtime accepts it

0 errors, 1 warning
```

`wiring` passes. The warning does not change what the matcher means in Claude Code, but it changes
what `claudevs` can do with it. A value it cannot evaluate matches nothing, so no case reaches that
hook, and `test` fails:

```console
$ jq -c '.stages[] | {name, status}' report.json
{"name":"validate","status":"passed"}
{"name":"wiring","status":"passed"}
{"name":"test","status":"failed"}
{"name":"test --installed","status":"skipped"}
```

`test --installed` is skipped because the copy in `/tmp` has no marketplace manifest above it to key
the installed layout by. The warning tells you the failing cases are about the matcher, not about your
hook script. To keep the hook under test, write the matcher so Rust can compile it.
