# A First Plugin

This page builds a small plugin with one hook, then asks `claudevs doctor` what the plugin and its
surroundings lack. Make an empty directory and work inside it. Every command in this chapter runs from
that directory, which is the one that holds `my-marketplace`.

## The plugin

The plugin guards `.env` files. It refuses any edit to one, and asks before touching anything under
`secrets/`. Every other path passes without a word. It has a manifest, a hook declaration and a hook
script:

```text
my-marketplace/
└── my-plugin/
    ├── .claude-plugin/plugin.json
    └── hooks/
        ├── hooks.json
        └── protect-env.sh
```

`my-marketplace/my-plugin/.claude-plugin/plugin.json`:

```json
{
  "name": "my-plugin",
  "version": "0.1.0",
  "description": "Guards .env files from edits",
  "author": { "name": "You" }
}
```

`my-marketplace/my-plugin/hooks/hooks.json` runs the script before the `Edit` and `Write` tools:

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

`my-marketplace/my-plugin/hooks/protect-env.sh`:

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

Claude Code sends the hook a JSON payload on standard input. The script reads it and looks for the
`file_path` field. Exit code 2 is how a `PreToolUse` hook says no.

## Ask what is missing

`claudevs doctor` reports what the plugin and its environment lack:

```bash
claudevs doctor my-marketplace/my-plugin
```

The command exits with status 1. This is what it prints:

```text
  ok    claude binary: present; `check` delegates its validate stage
  ok    plugin manifest: my-plugin 0.1.0
  warn  cases: no case files found under `my-marketplace/my-plugin/tests` (cases are `*.yaml`, `*_test.lua` or `test_*.lua` in tests/)
  gap   marketplace: marketplace `my-marketplace/my-plugin/../.claude-plugin/marketplace.json`: no `.claude-plugin/marketplace.json` in any ancestor directory; the installed layout is keyed by the marketplace that hosts the plugin
  gap   install layout: marketplace `my-marketplace/my-plugin/../.claude-plugin/marketplace.json`: no `.claude-plugin/marketplace.json` in any ancestor directory; the installed layout is keyed by the marketplace that hosts the plugin

2 gaps, 1 warning
```

A `gap` is something the environment around the plugin lacks. Here there is no marketplace above the
plugin, so there is no simulated install layout either. A gap makes the exit status 1. A `warn` is an
observation about the plugin's own content. Here it says no case files exist yet. A warning does not
change the exit status. Without `claude` on `PATH`, the first line is a gap too, and it names the
stage that gets skipped.

## Put the plugin in a marketplace

Claude Code installs a plugin from a marketplace, and `claudevs` simulates that install. Give the
plugin one by adding `my-marketplace/.claude-plugin/marketplace.json`:

```json
{
  "name": "my-marketplace",
  "owner": { "name": "You" },
  "plugins": []
}
```

The installed layout is keyed by the name of the nearest marketplace manifest, found by walking up
from the plugin. Ask again:

```bash
claudevs doctor my-marketplace/my-plugin
```

The command now exits with status 0:

```text
  ok    claude binary: present; `check` delegates its validate stage
  ok    plugin manifest: my-plugin 0.1.0
  warn  cases: no case files found under `my-marketplace/my-plugin/tests` (cases are `*.yaml`, `*_test.lua` or `test_*.lua` in tests/)
  ok    marketplace: my-marketplace
  ok    install layout: simulated at /var/folders/8w/4ccj7cw90nx4d32s72tqf5nw0000gn/T/.tmpPPmD7A/cache/my-marketplace/my-plugin/0.1.0

0 gaps, 1 warning
```

Both gaps are gone. The simulated install path is a temporary directory, so yours will differ. The
warning stays until you write a case, which is the next page.

Next, [write a first case](ch05-03-first-case.md).
