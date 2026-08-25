---
name: statusline
description: >
  Install, inspect, or remove the claudestacks Lua status line for Claude Code — a two-line
  status line showing path, git branch, context meter, output tokens, model, and rate limits.
  Installs machine-wide into ~/.claude, or for one project only via .claude/settings.local.json.
  Gates on the airsl binary, refuses to overwrite a status line it does not own, and backs up
  settings. Deterministic, no subagent. Use when the user says "install the status line" /
  "/claudestacks:statusline", or asks to remove it.
disable-model-invocation: true
---

# statusline

Point Claude Code's `statusLine` setting at the Lua status line. `statusLine` is a settings key,
not a plugin component type, which is why this is an installer rather than something the plugin
loads on its own.

## Pick the scope first

Two scopes. They are independent — both can exist at once, and the project one wins where it
applies.

| | **global** (default) | **project** (`--project`) |
|---|---|---|
| Renders in | every project on this machine | one project |
| Writes to | `~/.claude/settings.json` | `<project>/.claude/settings.local.json` |
| Copies files | yes, into `~/.claude/statusline/` | **no** — points at the source in place |
| Re-apply after editing the source | required | never |
| Committed to the repo | n/a | no — `settings.local.json` is the personal settings file |

**Ask the user which one, with `AskUserQuestion`.** Do not guess, and do not default silently:
the two write to different files and leave different things behind, so a wrong guess installs
something the user then has to find and undo. Skip the question only when they already said
which scope they want.

Gather the context first, so the recommendation is grounded rather than assumed:

```sh
# Does the status line source live inside this project?
case "${CLAUDE_PLUGIN_ROOT}" in "$PWD"/*) echo "source in-tree" ;; *) echo "source out-of-tree" ;; esac
# What is already installed, if anything?
grep -l statusLine "$HOME/.claude/settings.json" 2>/dev/null && echo "global install present"
grep -l statusLine .claude/settings.local.json 2>/dev/null && echo "project install present"
```

Then ask, marking the recommendation from what you found:

- **source in-tree** (the user is working in the repository that contains
  `plugins/claudestacks/scripts/`) → recommend **project**. Nothing is copied, so there is no
  installed second copy to drift, and editing the source takes effect on the next render.
- **source out-of-tree** → recommend **global**. Project mode would point at a plugin directory
  outside the project, which works but buys nothing over installing once machine-wide.
- **something already installed** → say so in the question. Re-running the same scope converges;
  choosing the other scope adds a second, independent install rather than replacing the first.

Give the answer options as `Global` and `This project only`, each with a one-line description
naming the file it writes. Carry the answer through every later step as either the plain
invocations or the `--project` ones — never mix them within one run.

## Steps

1. Confirm the runtime is present:

   ```sh
   command -v airsl
   ```

   If it is absent, stop. Tell the user to run `cargo make install-airsl`, and install nothing.

2. Show what would change, without changing it. No write grant: the whole point of the
   read-only mode is that it *cannot* write, and granting write erases that guarantee. It does
   need to **read** the plugin root, because it compares the installed files against the source
   ones — pass the same base and source arguments `apply` takes, or the comparison is skipped.

   Global:

   ```sh
   airsl run --policy confined \
     --allow-env HOME --allow-exec airsl \
     --allow-read "$HOME/.claude" --allow-read "${CLAUDE_PLUGIN_ROOT}" \
     "${CLAUDE_PLUGIN_ROOT}/scripts/statusline-install.lua" dry-run \
     "$HOME/.claude" "${CLAUDE_PLUGIN_ROOT}/scripts"
   ```

   Project:

   ```sh
   airsl run --policy confined \
     --allow-env HOME --allow-exec airsl \
     --allow-read "$PWD" --allow-read "${CLAUDE_PLUGIN_ROOT}" \
     "${CLAUDE_PLUGIN_ROOT}/scripts/statusline-install.lua" dry-run --project \
     "$PWD/.claude" "${CLAUDE_PLUGIN_ROOT}/scripts"
   ```

   Relay its one-line receipt verbatim, then act on which one it is:

   | Receipt | What to do |
   |---|---|
   | `already installed at …` | Stop. Everything is current. |
   | `would re-copy the status line at … — the source changed` | Go to step 3; the source moved on from what is installed. Global mode only. |
   | `would install the status line at …` | Go to step 3; nothing is installed yet. |
   | `a statusLine is already set and is not ours: …` | Stop. See the refusal note below. |

3. On user confirmation, apply. Both need a **read** grant on the plugin root — global copies the
   source files and compares them with `fs.same_content`, project points at them — and without it
   the run fails with `outside the granted read roots`.

   Global:

   ```sh
   airsl run --policy confined \
     --allow-env HOME --allow-exec airsl \
     --allow-read "$HOME/.claude" --allow-write "$HOME/.claude" \
     --allow-read "${CLAUDE_PLUGIN_ROOT}" \
     "${CLAUDE_PLUGIN_ROOT}/scripts/statusline-install.lua" apply \
     "$HOME/.claude" "${CLAUDE_PLUGIN_ROOT}/scripts"
   ```

   Project:

   ```sh
   airsl run --policy confined \
     --allow-env HOME --allow-exec airsl \
     --allow-read "$PWD" --allow-write "$PWD/.claude" \
     --allow-read "${CLAUDE_PLUGIN_ROOT}" \
     "${CLAUDE_PLUGIN_ROOT}/scripts/statusline-install.lua" apply --project \
     "$PWD/.claude" "${CLAUDE_PLUGIN_ROOT}/scripts"
   ```

   Relay the receipt. Tell the user the new status line appears on the next render — settings
   reload on their own, so no restart is needed.

   After a **global** apply, check whether the current project shadows it:

   ```sh
   test -f .claude/settings.json && grep -l statusLine .claude/settings.json
   test -f .claude/settings.local.json && grep -l statusLine .claude/settings.local.json
   ```

   If either matches, warn that the project's own `statusLine` takes precedence and the newly
   installed global one will not render here. Do not edit the project files.

4. To remove it. No `--allow-exec airsl` here: uninstall never resolves the `airsl` path, so it
   has no use for the grant.

   Global — removes the `statusLine` key and deletes `~/.claude/statusline/`:

   ```sh
   airsl run --policy confined \
     --allow-env HOME \
     --allow-read "$HOME/.claude" --allow-write "$HOME/.claude" \
     "${CLAUDE_PLUGIN_ROOT}/scripts/statusline-install.lua" uninstall
   ```

   Project — removes only the key. Nothing was copied, so nothing is deleted:

   ```sh
   airsl run --policy confined \
     --allow-env HOME \
     --allow-read "$PWD" --allow-write "$PWD/.claude" \
     "${CLAUDE_PLUGIN_ROOT}/scripts/statusline-install.lua" uninstall --project \
     "$PWD/.claude"
   ```

   Both back the settings file up first, so a foreign command they clear is recoverable from the
   matching `.bak`.

## Notes

- This skill writes nothing itself and spawns no subagent — it only invokes
  `statusline-install.lua`.
- `--allow-exec airsl` is not there to run anything. The installer calls `proc.which("airsl")`
  to resolve the absolute path it writes into the settings file, and `proc.which` answers to the
  same allowlist as `proc.run`. Only the two modes that write a command string — `dry-run` and
  `apply` — reach that call, which is why `uninstall` does without it.
- A refusal is a result, not a failure to work around. If the installer reports a foreign
  `statusLine`, show the user what is there and let them decide; never pass a flag to force it.
- Precedence, highest first: `.claude/settings.local.json`, then `.claude/settings.json`, then
  `~/.claude/settings.json`. So a project install always wins over a global one in that project.
