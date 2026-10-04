---
status: done
created: 2026-09-21
---

# Protocol Relocation and Driver Skill Implementation Plan

**Goal:** The handoff protocol lives in one file under a new `claudestacks:context-handoff` skill that every driver and agent can reach at runtime.

**Architecture:** `plugins/claudestacks/skills/process-guidelines/references/context-handoff.md` moves to `plugins/claudestacks/skills/context-handoff/references/protocol.md` and is rewritten to carry the trimmed frontmatter schema and the three-tier table. A new `SKILL.md` beside it holds the driver half — which of `init`/`beat`/`end` to call and when, the tier decision, and the literal `${CLAUDE_PLUGIN_ROOT}` path drivers copy into each brief. Per spec §3 the `airsl` command line itself stays in `protocol.md` and the skill points at it, so there is exactly one copy. Four Lua comment sites and one skill index are re-pointed here; `orchestrate` and `execute` also cite the old path but plan `05` rewrites those sections wholesale and owns them.

**Tech Stack:** Markdown (skill and reference), Lua comments, `airsl` for the check pass.

---

### Task 1 — Move the protocol file to its new home

**Files:**
- Create `plugins/claudestacks/skills/context-handoff/references/protocol.md`
- Delete `plugins/claudestacks/skills/process-guidelines/references/context-handoff.md`

**Steps:**

1. Record the source file's length so step 3 can prove nothing was lost:

   ```
   $ wc -l plugins/claudestacks/skills/process-guidelines/references/context-handoff.md
        164 plugins/claudestacks/skills/process-guidelines/references/context-handoff.md
   ```

2. Create the destination directory and move the file with git so history follows it:

   ```
   $ mkdir -p plugins/claudestacks/skills/context-handoff/references
   $ git mv plugins/claudestacks/skills/process-guidelines/references/context-handoff.md \
       plugins/claudestacks/skills/context-handoff/references/protocol.md
   ```

3. Confirm the move:

   ```
   $ wc -l plugins/claudestacks/skills/context-handoff/references/protocol.md
        164 plugins/claudestacks/skills/context-handoff/references/protocol.md
   $ test -e plugins/claudestacks/skills/process-guidelines/references/context-handoff.md && echo STILL-THERE || echo MOVED
   MOVED
   ```

4. Commit `refactor(repo): move the handoff protocol under its own skill`.

---

### Task 2 — Replace the frontmatter schema with the trimmed one

**Files:**
- Modify `plugins/claudestacks/skills/context-handoff/references/protocol.md`

**Steps:**

1. Confirm the schema block. It sits inside a fenced example that opens at `:31`; the seven
   frontmatter lines themselves are `:32-38`:

   ```
   $ sed -n '31,39p' plugins/claudestacks/skills/context-handoff/references/protocol.md
   ```

   ```markdown
   ---
   agent: reviewer
   session: 20260621-153012-a1b2
   seq: 03
   task: <one-line task description>
   created: 2026-06-21 15:31:40
   ---
   ```

   surrounded by the ` ```markdown ` opener at `:31` and the tag lines from `:39`.

2. Replace lines `32-38` — the seven frontmatter lines, leaving the fence alone — with:

   ```markdown
   ---
   agent: reviewer
   task: <one line — what this report is of>
   session: 20260621-153012-a1b2   # session-tier files only
   seq: 03                         # session-tier files only
   ---
   ```

3. Find the gating sentence that closes the `## File schema` section, and insert after it:

   ```
   $ grep -n "is always written; \`<detail>\` is gated" plugins/claudestacks/skills/context-handoff/references/protocol.md
   48:`<summary>` is always written; `<detail>` is gated — omit it when the summary already
   ```

   Insert immediately after that sentence ends (it runs to `:49`):

   ```markdown
   `agent:` and `task:` are always present. `task:` is composed from the brief the agent already
   receives; no brief carries a field to supply it.

   `session:` and `seq:` are present exactly when the file sits under a minted session tree. The
   protocol has three tiers:

   | Tier | Path | `session:` / `seq:` |
   |---|---|---|
   | session tree | `<root>/.airsstack/cc/plugins/claudestacks/handoff/<sid>/` | present |
   | single-subagent exception (below) | a literal temp path | absent |
   | `init`-refused fallback (below) | `<session-scratch>/handoff/` | absent |

   The third tier keeps the `<NN>-<agent>-<slug>.md` naming but mints no session and writes no
   lease, so there is no session identifier to record. Classifying it with the exception rather
   than with the session tree is deliberate, and is what the validator's path test implements.

   There is no `created:` key. The file's own modification time carries it, and requiring one
   would oblige every writer agent to gain a clock for a value nothing consults.
   ```

4. Confirm the retired key is gone:

   ```
   $ grep -c "^created:" plugins/claudestacks/skills/context-handoff/references/protocol.md
   0
   ```

5. Commit `docs(repo): trim the handoff frontmatter schema to four scoped keys`.

---

### Task 3 — Absorb the one rule that lives only in agent files

**Files:**
- Modify `plugins/claudestacks/skills/context-handoff/references/protocol.md`

**Steps:**

1. Two rules were candidates for absorption; only one is actually missing. Confirm the
   failed-write rule is already here, so it is **not** added again:

   ```
   $ grep -c "returns its full receipt inline" plugins/claudestacks/skills/context-handoff/references/protocol.md
   1
   ```

   That single hit is the `## Error handling` bullet at `:159`. Adding a second copy would be the
   duplication this chain removes.

2. Confirm the one-file rule's current wording, which states what an agent writes but not that the
   channel is closed to anything else:

   ```
   $ grep -n "never another agent's, never" plugins/claudestacks/skills/context-handoff/references/protocol.md
   85:Every spawn writes exactly one handoff file — its own, never another agent's, never
   ```

3. Append one paragraph to the end of that `## Report-write mechanism` section:

   ```markdown
   The report is not a channel for editing anything else. An agent writes its own handoff file and
   no other file through it. A `coder` additionally writes source within its task scope, but that
   is its implementation duty, stated in its own definition — not part of this protocol and not a
   licence any other agent inherits.
   ```

4. Confirm exactly one copy of each rule now:

   ```
   $ grep -c "not a channel for editing" plugins/claudestacks/skills/context-handoff/references/protocol.md
   1
   $ grep -c "returns its full receipt inline" plugins/claudestacks/skills/context-handoff/references/protocol.md
   1
   ```

5. Commit `docs(repo): state the one-file rule in the protocol itself`.

---

### Task 4 — Write the driver skill

**Files:**
- Create `plugins/claudestacks/skills/context-handoff/SKILL.md`

**Steps:**

1. Write the file. `${CLAUDE_PLUGIN_ROOT}` is literal — Claude Code substitutes it when it loads
   skill content (`plugins-reference.md:725`), so it must not be expanded here. Note what this
   file deliberately does **not** carry: the `airsl` command line. Per spec §3 that lives in
   `protocol.md` and only there:

   ````markdown
   ---
   name: context-handoff
   description: Use when driving subagents that report through the filesystem — deciding where reports land, running a handoff session, and handing each agent the resolved path to the protocol. Invoke once at the top of any pipeline that spawns reporting agents, before the first spawn.
   ---

   # Context Handoff

   Subagent detail stays on disk; only summaries reach the thread that spawned them. This skill is
   the driver half: it decides where reports land, says which session calls to make, and hands
   every agent a path to the protocol that it can actually open.

   **The protocol is `${CLAUDE_PLUGIN_ROOT}/skills/context-handoff/references/protocol.md`.** It
   is the authority for the file schema, the tiers, the return contract, error handling, retention,
   and the exact `airsl` command line for the session calls below. Read it before your first
   `init`.

   ## Pass two fields in every brief

   ```
   handoff: <the full write-path you assign this spawn>
   handoff-protocol: <the protocol path above, exactly as it appears>
   ```

   By the time you read this file the placeholder is already an absolute path — copy it. An agent
   cannot compute it: the variable is absent from the environment of a `Bash` tool call
   (`plugins-reference.md:721`), and an agent in another plugin resolves it to its own plugin's
   root rather than this one's.

   `coder`, `explorer` and `reviewer` live in this plugin and cite the path in their own
   definitions, so they do not need the second field. Passing it anyway is harmless.

   ## Choose the tier

   | Situation | Where reports land | Session? |
   |---|---|---|
   | more than one subagent in flight at once, or interleaved spawns whose reports refer to each other | the session tree | yes |
   | exactly one subagent, or sequential rounds of one | a literal temp path, e.g. `${TMPDIR:-/tmp}/<skill>-<round>.md` | no |
   | `init` refused or failed | `<session-scratch>/handoff/`, same `<NN>-<agent>-<slug>.md` naming | no |

   Expand `${TMPDIR:-/tmp}` yourself before a path enters a brief. An agent receives its brief as
   literal text and runs no shell over it, so an unexpanded variable reaches it as a filename.

   A single-subagent flow calls none of the session commands and mints no session directory. There
   is nothing for a lease to arbitrate, so paying for a session buys nothing. The file schema and
   the return contract still apply unchanged — only the path differs.

   ## Run a session

   Only for the first row of that table. The command line for each call, its grants, and the
   worktree-guard workaround are in the protocol's session-lifecycle section — run them exactly as
   written there.

   1. **Once, at the top of the pipeline.** `init` mints the session, writes its lease, prunes
      stale prior sessions, and prints the session directory and id. Keep both.
   2. **Per spawn.** Assign `<NN>-<agent>-<slug>.md` under the session directory and pass it as
      `handoff:`. Call `beat <session-dir>` so a long run is never pruned by a concurrent session.
   3. **At close.** `end <session-dir>` drops the lease. Optional — the grace window self-heals a
      crash.

   If `init` is refused or fails, do not improvise a layout: take the third tier, and record the
   deviation in the run's execution record.

   ## Route off the summary

   The agent returns its `<summary>` plus the path — never the `<detail>`. Route off the summary.
   Open a `<detail>` yourself only when you personally must judge it. When a downstream agent needs
   upstream detail, pass the upstream `handoff:` path plus a targeted `need:` pointer; it reads its
   own slice and the detail never transits you.

   ## Check a report by hand

   Reports are validated automatically by this plugin's hooks. To check one yourself:

   ```
   airsl run --policy confined --allow-read / \
     "${CLAUDE_PLUGIN_ROOT}/scripts/handoff_report.lua" <path-to-report>
   ```

   Silence and exit 0 mean the report conforms. Otherwise it prints one line per violation.
   ````

2. Confirm the frontmatter is well formed:

   ```
   $ head -2 plugins/claudestacks/skills/context-handoff/SKILL.md
   ---
   name: context-handoff
   ```

3. Confirm the placeholder survived unexpanded, and that it appears on exactly the three lines the
   block above puts it on — the protocol path twice (the authority sentence and the validator
   command) and nowhere else:

   ```
   $ grep -c 'CLAUDE_PLUGIN_ROOT' plugins/claudestacks/skills/context-handoff/SKILL.md
   2
   ```

   If this is higher, the `airsl` session command line was copied in against spec §3 and must be
   removed.

4. Confirm the invocation is **not** here — this is the check that keeps the duplication out:

   ```
   $ grep -c "AIRSSTACK_HANDOFF_KEEP" plugins/claudestacks/skills/context-handoff/SKILL.md
   0
   $ grep -c "AIRSSTACK_HANDOFF_KEEP" plugins/claudestacks/skills/context-handoff/references/protocol.md
   2
   ```

   `grep -c` counts matching lines, and the protocol carries the name on two: the `--allow-env`
   grant inside the session invocation (`:109`) and the retention paragraph (`:151`).

5. Commit `feat(repo): add the context-handoff driver skill`.

---

### Task 5 — Re-point the cross-references this plan owns

**Files:**
- Modify `plugins/claudestacks/skills/process-guidelines/SKILL.md`
- Modify `plugins/claudestacks/hooks/lib/enforce.lua`
- Modify `plugins/claudestacks/scripts/handoff.lua`
- Modify `plugins/claudestacks/scripts/lib/handoff.lua`
- Modify `plugins/claudestacks-journal/scripts/lib/vault.lua`

**Steps:**

1. List every live reference to the old path. There are ten:

   ```
   $ grep -rn "references/context-handoff.md" plugins/ | grep -v "/agents/"
   plugins/claudestacks/hooks/lib/enforce.lua:83
   plugins/claudestacks/scripts/handoff.lua:4
   plugins/claudestacks/scripts/lib/handoff.lua:4
   plugins/claudestacks/scripts/lib/handoff.lua:31
   plugins/claudestacks/skills/process-guidelines/SKILL.md:29
   plugins/claudestacks/skills/process-guidelines/SKILL.md:41
   plugins/claudestacks/skills/orchestrate/SKILL.md:107
   plugins/claudestacks/skills/orchestrate/SKILL.md:122
   plugins/claudestacks-sdlc/skills/execute/SKILL.md:98
   plugins/claudestacks-journal/scripts/lib/vault.lua:31
   ```

   **Seven of those are this plan's.** The three in `orchestrate/SKILL.md` and
   `execute/SKILL.md` sit inside sections plan `05` replaces wholesale; editing them here would
   be work plan `05` discards, and the assertion in step 4 accounts for that.

2. Rewrite the four Lua comment sites. All four are comments; none is code:

   ```
   $ sed -i '' 's|skills/process-guidelines/references/context-handoff.md|skills/context-handoff/references/protocol.md|g' \
       plugins/claudestacks/hooks/lib/enforce.lua \
       plugins/claudestacks/scripts/handoff.lua \
       plugins/claudestacks/scripts/lib/handoff.lua \
       plugins/claudestacks-journal/scripts/lib/vault.lua
   ```

3. In `process-guidelines/SKILL.md`, replace the handoff bullet at `:27-29` with:

   ```markdown
   - **Context handoff**: subagents report through the filesystem — a cheap `<summary>` returns to the
     main thread, heavy `<detail>` stays on disk and is pulled by path only when needed. Owned by the
     `context-handoff` skill, which drivers invoke. → `/claudestacks:context-handoff`
   ```

   and the reference-index row at `:41-42` with:

   ```markdown
   - The handoff protocol is no longer a reference here. Invoke `/claudestacks:context-handoff`; its
     `references/protocol.md` is the authority.
   ```

4. Confirm exactly three references to the old path remain, all of them in the two files plan `05`
   owns:

   ```
   $ grep -rn "references/context-handoff.md" plugins/ | grep -v "/agents/"
   plugins/claudestacks/skills/orchestrate/SKILL.md:107
   plugins/claudestacks/skills/orchestrate/SKILL.md:122
   plugins/claudestacks-sdlc/skills/execute/SKILL.md:98
   ```

   Any other line here is a site this task missed.

5. Confirm the Lua still compiles — the edits were comments, and this proves they did not break a
   string or a block comment:

   ```
   $ cargo make plugins-check
   ```

   Ends in `[cargo-make] INFO - Build Done`.

6. Commit `refactor(repo): re-point handoff protocol cross-references at the new skill`.

---

### Task 6 — Bump the plugin versions this plan changed

**Files:**
- Modify `plugins/claudestacks/.claude-plugin/plugin.json`
- Modify `plugins/claudestacks-journal/.claude-plugin/plugin.json`

**Steps:**

1. Read the current versions:

   ```
   $ grep '"version"' plugins/claudestacks/.claude-plugin/plugin.json plugins/claudestacks-journal/.claude-plugin/plugin.json
   plugins/claudestacks/.claude-plugin/plugin.json:  "version": "0.1.5",
   plugins/claudestacks-journal/.claude-plugin/plugin.json:  "version": "0.1.1",
   ```

2. Set `claudestacks` to `0.1.6` and `claudestacks-journal` to `0.1.2`. A consumer on a copied
   install reads the cache keyed by version; without a bump the cache stays stale (spec P4).
   In-place development does not need it, but what ships must work for the copied case.

3. Confirm:

   ```
   $ grep '"version"' plugins/claudestacks/.claude-plugin/plugin.json plugins/claudestacks-journal/.claude-plugin/plugin.json
   plugins/claudestacks/.claude-plugin/plugin.json:  "version": "0.1.6",
   plugins/claudestacks-journal/.claude-plugin/plugin.json:  "version": "0.1.2",
   ```

4. Commit `chore(repo): bump claudestacks and claudestacks-journal for the protocol move`.
