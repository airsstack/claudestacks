---
status: approved
created: 2026-10-04
depends-on: [01, 03]
---

# Discuss Skill Implementation Plan

**Goal:** The author drives a topic-indexed discussion with `/claudestacks:discuss <argument>`.

**Architecture:** `skills/discuss/SKILL.md` maps each `$ARGUMENTS` form to one `scripts/discuss.lua` command (spec §6) and tells the main thread how to brief agents and handle their reports under the protocol plan 01 wrote. It sets `disable-model-invocation: true`, so only the author's typing runs it (spec P3b). Values the skill cannot know are filled by Claude Code's substitution — `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_SESSION_ID}`, `${user_config.archive_keep}` — with the last single-quoted, because unset it stays a literal that the shell must not expand (spec P3, P3a). A suite test pins those properties of the file so they cannot silently regress. `plugin.json` gains the `archive_keep` option.

**Tech Stack:** Claude Code skill frontmatter and substitutions, plugin `userConfig`, `airsl` Lua 5.4 for the pinning test.

---

## File structure

```
plugins/claudestacks/skills/discuss/SKILL.md          — [create] the /claudestacks:discuss skill
plugins/claudestacks/scripts/discuss_skill_test.lua    — [create] pins the skill's frontmatter and command lines
plugins/claudestacks/.claude-plugin/plugin.json        — [modify] add userConfig.archive_keep
```

Facts this plan encodes, each checked on 2026-10-04:

- Frontmatter fields `argument-hint` and `disable-model-invocation` exist (`skills.md:383`, `:385`); with the latter set, Claude does not invoke the skill itself (`skills.md:60`, `:315`).
- `$ARGUMENTS` and `${CLAUDE_SESSION_ID}` are substituted in skill text (spec P6, probe `cfgprobe`); `${CLAUDE_PLUGIN_ROOT}` is too — this session's loaded `context-handoff` skill shows an absolute path where its source at `plugins/claudestacks/skills/context-handoff/SKILL.md:12` has the placeholder.
- An unset `${user_config.archive_keep}` stays literal in skill text (spec P3); unquoted it is `bad substitution` in `sh`, single-quoted it passes through (spec P3a).
- A Bash call made by the model has no `CLAUDE_PLUGIN_*` variables (spec P7), so the skill's command lines must carry substituted values, not `$CLAUDE_PLUGIN_ROOT`.
- The worktree guard accepts `$HOME` but refuses other variables in an `airsl` command line; a plain command may use them (spec P14).
- `userConfig` fields `type`, `title`, `description`, `default` (`manifest-reference.md:431-435`).

### Task 1 — Pin the skill's contract in a test

**Files:**
- Test `plugins/claudestacks/scripts/discuss_skill_test.lua`

**Steps:**

1. Write the failing test in `plugins/claudestacks/scripts/discuss_skill_test.lua`:

   ```lua
   -- Pins the parts of skills/discuss/SKILL.md that a careless edit would break silently: who may
   -- invoke it, and how the command lines carry substituted values.
   --
   --   cargo make plugins-test   (paths are relative to the repository root)

   local fs = airsstack.fs

   local SKILL = "plugins/claudestacks/skills/discuss/SKILL.md"

   local function text()
     return fs.read(SKILL)
   end

   return {
     only_the_author_can_invoke_it = function()
       local frontmatter = text():match("^%-%-%-\n(.-)\n%-%-%-\n")
       assert(frontmatter, "no frontmatter")
       -- Wrapped in newlines so the key matches on any line, first and last included.
       assert(("\n" .. frontmatter .. "\n"):find("\ndisable%-model%-invocation: true\n"),
         "model invocation not disabled")
     end,

     every_user_config_placeholder_is_single_quoted = function()
       local body = text()
       local count = 0
       for before, after in body:gmatch("(.)%${user_config%.archive_keep}(.)") do
         count = count + 1
         assert(before == "'" and after == "'", "unquoted ${user_config.archive_keep}")
       end
       assert(count >= 1, "the start line does not pass --keep")
     end,

     command_lines_carry_the_session_and_the_plugin_root = function()
       local body = text()
       assert(body:find("--session ${CLAUDE_SESSION_ID}", 1, true))
       assert(body:find('"${CLAUDE_PLUGIN_ROOT}/scripts/discuss.lua"', 1, true))
       assert(not body:find("$CLAUDE_PLUGIN_ROOT/", 1, true), "an unsubstituted shell variable")
     end,

     every_command_is_named = function()
       local body = text()
       for _, command in ipairs({ " start", " add ", " list", "list --archive", " show ", " done",
         " report-path " }) do
         assert(body:find(command, 1, true), "missing command:" .. command)
       end
     end,
   }
   ```

2. Run it and confirm failure:

   ```
   $ cargo make plugins-test
     FAIL  only_the_author_can_invoke_it
     FAIL  every_user_config_placeholder_is_single_quoted
     FAIL  command_lines_carry_the_session_and_the_plugin_root
     FAIL  every_command_is_named
   ```

   (each with `read failed on \`/…/plugins/claudestacks/skills/discuss/SKILL.md\`: No such file or directory (os error 2)`).

3. Commit nothing yet; Task 2 makes it green.

### Task 2 — Write the skill

**Files:**
- Create `plugins/claudestacks/skills/discuss/SKILL.md`

**Steps:**

1. Create `plugins/claudestacks/skills/discuss/SKILL.md` with exactly this content:

   ````markdown
   ---
   name: discuss
   description: Open, browse and close a topic-indexed discussion. Agents briefed under it hand back a short summary plus numbered topics, the detail stays on disk until a topic is opened, and a closed discussion is archived per project. Runs only when the author types /claudestacks:discuss.
   argument-hint: "[list | list archive | <id> | <sid8>/<id> | done]"
   disable-model-invocation: true
   ---

   # Discuss

   Argument: `$ARGUMENTS`

   The communication protocol is `${CLAUDE_PLUGIN_ROOT}/skills/discuss/references/protocol.md`.
   Read it before the first brief. It inherits the Context Handoff protocol, which
   `/claudestacks:context-handoff` hands you.

   ## The command line

   Resolve the storage root once, with a plain command:

   ```
   echo "${AIRSSTACK_HOME:-$HOME/.airsstack}"
   ```

   Call its output `<root>`. Every command below runs from the repository root as:

   ```
   airsl run --policy confined --allow-env HOME --allow-env AIRSSTACK_HOME \
     --allow-read / --allow-write <root> \
     "${CLAUDE_PLUGIN_ROOT}/scripts/discuss.lua" <command> [argument] --session ${CLAUDE_SESSION_ID}
   ```

   with `<root>` pasted as a literal. If `airsl` is not found, say that `airsl` is not installed,
   point at `${CLAUDE_PLUGIN_ROOT}/scripts/install-airsl.sh`, and stop.

   A command that fails prints one line on stdout and exits non-zero; `airsl` also writes a Lua
   traceback to stderr. Show the author the stdout line as it is, not the traceback.

   ## What each argument does

   | `$ARGUMENTS` | Run | Then |
   |---|---|---|
   | empty | ` start --keep '${user_config.archive_keep}'` | The discussion is open. Follow "While a discussion is open" below. |
   | `list` | ` list` | Show the output. |
   | `list archive` | ` list --archive` | Show the output. `<sid8>/<id>` opens one of these. |
   | a number, or `<sid8>/<number>` | ` show <it>` | Answer from that section only. Do not open other topics. |
   | `done` | ` done` | If you minted a Context Handoff session for this discussion, run its `end`. Report any `missing:` lines. |
   | anything else | nothing | Refuse: `unknown /claudestacks:discuss argument: <it>. Use: list, list archive, <id>, done.` |

   Never guess what an unrecognised argument meant.

   ## While a discussion is open

   - **Brief agents under the protocol.** Every brief carries `handoff:`, `handoff-protocol:` and
     `comm-protocol: ${CLAUDE_PLUGIN_ROOT}/skills/discuss/references/protocol.md`.
   - **After each report, add it.** Run ` add <report-path>`. It prints the new topics as
     `<id> <title>`. Show the author the agent's summary and those lines. Do not read the
     report's `<detail>` yourself.
   - **If `add` refuses a report,** show its violation lines, and re-brief the agent to fix that
     report rather than repairing it yourself.
   - **Your own long answers become reports too.** When an answer would run past about 15 lines,
     run ` report-path <kebab-slug>`, write the answer there as a protocol report with
     `agent: main`, run ` add` on that path, then reply with its summary and topics.
   - **End every reply with the topic list** — the output of ` list`.
   ````

2. Run it and confirm green:

   ```
   $ cargo make plugins-test
     ok    only_the_author_can_invoke_it
     ok    every_user_config_placeholder_is_single_quoted
     ok    command_lines_carry_the_session_and_the_plugin_root
     ok    every_command_is_named
   ```

   Break it: remove the quotes around `${user_config.archive_keep}`, rerun, confirm `FAIL  every_user_config_placeholder_is_single_quoted`. Restore.

3. Commit `feat(repo): add the /claudestacks:discuss skill`.

### Task 3 — Declare the archive option and run the real start line

**Files:**
- Modify `plugins/claudestacks/.claude-plugin/plugin.json`

**Steps:**

1. In `plugins/claudestacks/.claude-plugin/plugin.json`, add inside the existing `userConfig` object, after `style_reinject`:

   ```json
       "archive_keep": {
         "type": "number",
         "title": "Discussions kept per project",
         "description": "How many /claudestacks:discuss discussions to keep per project besides the current one. Older ones are removed when a new one starts.",
         "default": 20
       }
   ```

2. Validate:

   ```
   $ claude plugin validate plugins/claudestacks
   ✔ Validation passed
   ```

3. Run the `start` line exactly as the skill renders it with the option unset — `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SESSION_ID}` substituted, `${user_config.archive_keep}` left literal (spec P3) — through `sh`, the way the Bash tool runs it. Resolve the literals first:

   ```
   $ echo "$TMPDIR"
   /var/folders/…/T/
   $ pwd
   /…/comm-ops-plugins
   ```

   Write that line into a script file (the worktree guard refuses the placeholder inline), with the literals pasted:

   ```sh
   # /var/folders/…/T/plan04-start.sh
   # The root is created first: a write grant on a path that does not exist yet, under the
   # /var -> /private/var symlink, makes fs.mkdir fail "outside the granted write roots".
   mkdir -p /var/folders/…/T/plan04-home
   airsl run --policy confined --allow-env HOME --allow-env AIRSSTACK_HOME \
     --allow-read / --allow-write /var/folders/…/T/plan04-home \
     "/…/comm-ops-plugins/plugins/claudestacks/scripts/discuss.lua" start --keep '${user_config.archive_keep}' --session plan04-check
   ```

   ```
   $ AIRSSTACK_HOME=/var/folders/…/T/plan04-home sh /var/folders/…/T/plan04-start.sh; echo "exit=$?"
   started discussion plan04-c (0 topics)
   exit=0
   ```

   Then remove the quotes from the script's `--keep` value, rerun, and confirm `bad substitution` — the failure the quoting prevents. Delete the script and `/var/folders/…/T/plan04-home`.

4. Run the gate:

   ```
   $ cargo make plugins
   … 0 failed …
   ```

5. Commit `feat(repo): declare the discuss archive_keep option`.

## Verification summary (plan-level)

- `cargo make plugins` green, with the four `discuss_skill_test.lua` tests among the passes, each seen failing first.
- The rendered `start` line succeeds with the option unset, and fails unquoted.
- `claude plugin validate plugins/claudestacks` passes.
- The live acceptance session runs at the end of plan 05, after the version bump makes the change installable (spec P16). A `--plugin-dir` session alongside the installed `claudestacks` was not probed for which copy wins, so it is not used here.
- Checkpoint: stop here for the author's review before plan 05.
