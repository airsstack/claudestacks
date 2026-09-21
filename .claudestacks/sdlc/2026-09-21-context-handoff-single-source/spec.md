---
status: approved
created: 2026-09-21
---

# Spec: one authority for the handoff protocol, reachable at runtime and checked by a hook

The Context Handoff protocol is restated in thirteen files because the one file that holds it
cannot be opened from most of the places that must obey it. This spec moves the protocol into a
new `claudestacks:context-handoff` skill, gives every agent and driver a path to it that resolves
at runtime, cuts each of the seven writer agents down to a four-line stub carrying only the
contract that must hold if that path is never read, and adds a validator — one rule set, reachable
from the hooks that check every report and from a command a driver can run by hand. It absorbs
`2026-08-26-agent-report-shape`, whose `## Report` contract and frontmatter interpretation it
settles for all seven agents rather than two.

## 1. Design premises

Every premise below was verified in this task. Documentation was fetched to a local file and
grepped; no summarizing fetch tool was used. Doc citations are `<page>.md:<line>` against the raw
Markdown at `https://code.claude.com/docs/en/<page>.md`, fetched 2026-09-21.

**P1. `${CLAUDE_PLUGIN_ROOT}` substitutes inline in agent content, not only skill content.**
`plugins-reference.md:723-729` is the table of which plugin components resolve placeholders. Its
first row, at `:725`, reads `Skill and agent content` → `Anywhere the placeholder appears`. This is
the mechanism the three `claudestacks` agents use in §5.2.

**P2. The placeholder is unavailable only to Bash-tool commands; hooks get it both ways.**
`plugins-reference.md:721`: "All three are exported as environment variables to hook processes and
to MCP and LSP server subprocesses. They aren't present in the environment of commands Claude runs
through the Bash tool, in the main session or in a subagent." The component table's second row, at
`:726`, adds `Hook and monitor commands` → `Anywhere the placeholder appears`. So a hook command
may both spell the placeholder and read the environment variable, which is how the four commands
already in `plugins/claudestacks/hooks/hooks.json` find their scripts, and how §8's wrapper finds
the validator. What no mechanism can do is resolve it from a `Bash` tool call — which is why §6's
skill, and not a script, is what hands the path to a cross-plugin agent.

**P3. Substitution uses the owning plugin's root, not the caller's.** Observed twice in this task:
invoking `claudestacks-sdlc:intent` and then `claudestacks-sdlc:design` from the main thread of a
session whose working directory is `.claude/worktrees/claudestack-plugin-discuss` delivered skill
content in which `${CLAUDE_PLUGIN_ROOT}` had already been expanded to
`/Users/hiraq/Projects/airsstack/claudestacks/plugins/claudestacks-sdlc`. The caller was the main
thread, not the sdlc plugin; the expansion followed the file that contained the placeholder. A
skill owned by `claudestacks` therefore expands to `claudestacks`' root however it is invoked,
which is the property §6 depends on.

**P4. `${CLAUDE_PLUGIN_ROOT}` resolves to one of two places, and both defeat a hand-written
cross-plugin literal.** `plugins-reference.md:750` gives both cases in one line: "For a copied
plugin, `${CLAUDE_PLUGIN_ROOT}` changes when the plugin updates. The previous version's directory
remains on disk for a grace period after an update, but treat it as ephemeral and don't write
state there. For a plugin loaded in place from a local-directory marketplace, the variable points
at the stable source directory."

- **In place.** `~/.claude/plugins/known_marketplaces.json` records this marketplace as
  `"source": "directory"` over `/Users/hiraq/Projects/airsstack/claudestacks`. That is the case P3
  observed, and `plugins-reference.md:817` states its consequence: "your edits to the source
  directory take effect at the next session start or `/reload-plugins`. You don't need a version
  bump."
- **Copied.** A consumer installing this suite from a git marketplace gets
  `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>`. `installed_plugins.json` records
  such paths for this machine too, at five independent versions, with superseded versions still on
  disk:

  ```
  claudestacks                 0.1.5    (0.1.4 also present)
  claudestacks-sdlc            0.1.1    (0.1.0 also present)
  claudestacks-journal         0.1.1
  claudestacks-guideline-rust  0.1.4    (0.1.3 also present)
  claudestacks-cmux            0.1.1
  ```

The on-disk state here is genuinely mixed — the 0.1.5 cache directory exists and its
`context-handoff.md` differs from source (`diff -q` → exit 1) — so which copy a given session
reads is not settled by this spec and does not need to be. **Both cases defeat a literal.** In the
copied case the version segment is unknowable to a sibling plugin; in the in-place case the source
path is the user's checkout, equally unknowable. `journal-review/SKILL.md:70-74` recorded the
copied half of this reasoning; the listing above is the evidence, and the in-place half is new.

Consequence for §2: a version bump is required for a consumer on a copied install and is
unnecessary for in-place development (`:817`). §2 states it conditionally rather than as a blanket
rule.

**P5. Plugin hooks fire inside subagents, and `PostToolUse` receives the absolute path.**
`hooks.md:267`: "Hooks from settings files, managed policy settings, and plugins also run inside
subagents. When a subagent calls a tool, tool events such as `PreToolUse` and `PostToolUse` fire
the same configured hooks as in the main conversation, and the input carries the `agent_id` and
`agent_type`". `hooks.md:2004`: PostToolUse input carries `tool_input`, and "File-tool
`tool_input` paths arrive in the same format as for PreToolUse: always absolute".

**P6. `PostToolUse` cannot block; `PreToolUse` and `SubagentStop` can.** `hooks.md:893` —
`PostToolUse` · Can block? · No · "Shows stderr to Claude; the tool already ran". `hooks.md:2037` —
its `decision: "block"` "adds the `reason` next to the tool result", and "Claude still sees the
original output". Against that, `hooks.md:882` — `PreToolUse` · Yes · "Blocks the tool call" — and
`hooks.md:887` — `SubagentStop` · Yes · "Prevents the subagent from stopping".

**P7. A subagent's report does not arrive as `last_assistant_message` when `SubagentHandback` is
in play.** `hooks.md:2405`: "On Claude Code v2.1.271 or later, a subagent that runs with the
`SubagentHandback` tool delivers its report through that tool before it stops. The
`last_assistant_message` field then holds the subagent's closing text, if any, which is not the
delivered report. The report is that call's `message` input, which a `PreToolUse` or `PostToolUse`
hook matched on `SubagentHandback` receives as `tool_input.message`." `hooks.md:1779` adds that
Claude Code provides the tool **in auto mode**. `claude --version` on this machine returns
`2.1.278 (Claude Code)`, past the threshold, and the `artifact-reviewer` spawned to review this
spec's first draft returned through `SubagentHandback` — so the suite's agents meet this today.
`grep -rn "SubagentHandback" plugins/` returns nothing: no agent definition and no prior chain
artifact knows of it. Because availability is mode-dependent, §8 registers **both** paths.

**P8. `FileChanged` is not usable for this.** `hooks.md:2873`: its matcher "is split on `|` and
each segment is registered as a literal filename in the working directory". Handoff files have
computed names (`<NN>-<agent>-<slug>.md`) inside a nested tree, so no literal watch list can name
them. The `PostToolUse` gap this leaves is stated in §8.

**P9. A subagent matcher takes the anchored plugin-scoped identifier.** `hooks.md:314` and `:317`
give `SubagentStart`/`SubagentStop` matchers as agent type, "custom agent names, or plugin-scoped
names like `^my-plugin:reviewer$`"; `sub-agents.md:767` adds that a scoped name contains a colon
and "is evaluated as an unanchored regular expression", so it must be anchored with `^` and `$`.

**P10. A preloaded skill is silently skipped when missing.** `sub-agents.md:588`: "If a listed
skill is missing or disabled, for example by your organization's policy, Claude Code skips it and
logs a warning to the debug log." This is why §5.1's stub exists regardless of delivery mechanism:
no mechanism that can fail quietly may be the sole carrier of the return contract.

**P11. Not verified — whether `skills:` frontmatter accepts a plugin-namespaced value.**
`sub-agents.md:296` and `:584` establish that the `skills:` field preloads full skill content at
startup without the `Skill` tool, and `:576-578` shows the field taking bare names. Whether
`claudestacks:context-handoff` is accepted there is undetermined: the attempted probe failed
because project agents are scanned at session start, so a mid-session agent file does not resolve
(`Agent type 'handoff-probe-ns' not found`). **This spec's design does not depend on the answer.**
It is recorded so a later chain can settle it and simplify §5.2 if it comes back positive.

**P12. No installed guideline governs this chain's files.** The only `enforcement.json` in the
repository is `plugins/claudestacks-guideline-rust/enforcement.json`, whose `match` is
`["**/*.rs", "**/Cargo.toml"]`. This chain changes Markdown, JSON and Lua and no Rust, so no stack
guideline's architecture rules apply. The Lua added in §7 follows the conventions of its
neighbours in `plugins/claudestacks/scripts/` — a `lib/` module holding the logic, a thin driver,
and a sibling `_test.lua` run by `airsl test`.

## 2. Files this spec changes

| File | Change |
|---|---|
| `plugins/claudestacks/skills/context-handoff/SKILL.md` | **new** — the driver half (§6) |
| `plugins/claudestacks/skills/context-handoff/references/protocol.md` | **new location** — the protocol, moved from below and rewritten per §3–§4 |
| `plugins/claudestacks/skills/process-guidelines/references/context-handoff.md` | **deleted** — content moves to the line above |
| `plugins/claudestacks/skills/process-guidelines/SKILL.md` | its handoff bullet (`:27-29`) and reference-index row (`:41-42`) point at the new skill instead of a file it no longer owns |
| `plugins/claudestacks/scripts/lib/handoff_report.lua` | **new** — the validator (§7) |
| `plugins/claudestacks/scripts/handoff_report.lua` | **new** — its CLI driver |
| `plugins/claudestacks/scripts/handoff_report_test.lua` | **new** — fixture tests (§11) |
| `plugins/claudestacks/hooks/handoff-check.sh` | **new** — the hook launcher (§8) |
| `plugins/claudestacks/hooks/handoff-check.lua` | **new** — the hook entry: reads the payload, calls the validator (§8) |
| `plugins/claudestacks/hooks/hooks.json` | gains `PostToolUse`, `PreToolUse` on `SubagentHandback`, and `SubagentStop` entries (§8); it currently registers five hook groups, not four |
| `plugins/claudestacks/agents/coder.md` | `## Context handoff` (`:94-105`) → the §5.1 stub; the stray coder clause is at `:101` |
| `plugins/claudestacks/agents/explorer.md` | `## Context handoff` (`:65-76`) → the §5.1 stub; the stray coder clause is at `:72` |
| `plugins/claudestacks/agents/reviewer.md` | `## Context handoff` (`:106-117`) → the §5.1 stub; the stray coder clause is at `:113` |
| `plugins/claudestacks-sdlc/agents/task-briefer.md` | its inlined schema (`:99-120`) and the `handoff` row of its brief table (`:30`) → the §5.1 stub |
| `plugins/claudestacks-sdlc/agents/chain-reader.md` | `## Output` (`:41-58`) and `## Context handoff` (`:66-74`) → one `## Report` per §5.3; `report` → `handoff` in its brief |
| `plugins/claudestacks-sdlc/agents/artifact-reviewer.md` | `## Output` (`:51-75`, next heading `## Boundaries` at `:77`) and `## Context handoff` (`:83-91`) → one `## Report` per §5.3; `report` row (`:32`) → `handoff` |
| `plugins/claudestacks-journal/agents/journal-curator.md` | its inlined schema (`:76-87`) and `handoff_path` input (`:29`) → the §5.1 stub, field renamed `handoff` |
| `plugins/claudestacks/skills/orchestrate/SKILL.md` | `## Context handoff` (`:103-122`) → invoke the §6 skill |
| `plugins/claudestacks-sdlc/skills/execute/SKILL.md` | `## Context handoff` (`:94-116`) → invoke the §6 skill; `handoff:` lines in its briefs (`:69`, `:167`, `:177-178`) keep their name |
| `plugins/claudestacks-sdlc/skills/design/SKILL.md` | spawn brief `:161-166`, `report:` at `:165` → invoke the §6 skill; `report:` → `handoff:` |
| `plugins/claudestacks-sdlc/skills/plan/SKILL.md` | spawn brief `:221-226`, `report:` at `:225` → same |
| `plugins/claudestacks-sdlc/skills/distill/SKILL.md` | spawn brief `:49-53`, `report:` at `:52` → same |
| `plugins/claudestacks-journal/skills/journal-review/SKILL.md` | steps 4–5 (`:64-80`) → invoke the §6 skill; `handoff_path` → `handoff` |
| `plugins/claudestacks/hooks/lib/enforce.lua` | the cross-reference at `:83` re-points at the new path |
| `plugins/claudestacks/scripts/handoff.lua` | cross-reference in its header at `:4` re-pointed; **behaviour unchanged** |
| `plugins/claudestacks/scripts/lib/handoff.lua` | cross-references at `:4` (header) and `:31` (mid-file, in the root-resolution comment) re-pointed; **behaviour and all 29 tests unchanged** |
| `plugins/claudestacks-journal/scripts/lib/vault.lua` | the cross-reference at `:31` re-pointed |
| `.claudestacks/sdlc/2026-08-25-sdlc-agent-tier/plans/01-foundations.md` | re-anchor the tag-count assertion at `:564-565` to §7's both-ends form, carried over from the absorbed chain |
| `.claudestacks/sdlc/2026-08-25-sdlc-agent-tier/plans/03-distill-wiring.md` | re-point the verbatim diff at `:198-206`, carried over from the absorbed chain |

**Version bumps are conditional, per P4.** For a consumer on a copied install, each changed
plugin's `.claude-plugin/plugin.json` must bump or the cache stays stale. For in-place development
from this local-directory marketplace, `plugins-reference.md:817` says no bump is needed and a
session restart or `/reload-plugins` suffices. The plan bumps them, because what ships must work
for the copied case.

## 3. The authority moves and becomes self-contained

`references/protocol.md` under the new skill is the sole normative text. It carries, unchanged in
substance from today's file: the path layout (`:13-27`), the tag semantics (`:39-46`) **and the
gating rule at `:48-49`** ("`<summary>` is always written; `<detail>` is gated"), the
single-subagent exception (`:51-66`), the return and routing contract (`:68-81`), the
report-write mechanism (`:83-89`), the session lifecycle and its `airsl` invocation (`:91-142`),
the fallback when `init` cannot run (`:144-149`), retention (`:151-155`), and error handling
(`:157-164`). It gains §4's schema in place of the current one, and a statement that the validator
in §7 is what enforces it.

**`protocol.md` owns the `airsl` invocation, and §6's skill points at it rather than reproducing
it.** Both files describing how to run a session would be the duplication this chain exists to
remove, and §11.4's check would then fail against the chain's own output. The cost is that a
driver takes two hops to reach the command line; the benefit is that there is exactly one copy of
it, which is the property being bought.

It loses nothing. The two rules that today live only in agent files — that a report is one file
and never a channel for editing other files, and that a failed write falls back to an inline
receipt — are stated here, because §5 reduces the agent copies to pointers at this text.

The file the drivers and agents cite is this one. `process-guidelines` keeps its other references
and its role as the process index; it stops owning a protocol it does not drive.

## 4. The frontmatter schema, trimmed

Today's schema (`context-handoff.md:31-38`) mandates five keys. No report has carried them:
`2026-08-26-agent-report-shape/spec.md:146-148` records that every report produced on 2026-08-26
began at line 1 with `<summary>`. That chain had to interpret three of the five to proceed. This
spec settles them by changing the schema rather than by reading it charitably:

```markdown
---
agent: reviewer
task: <one line — what this report is of>
session: 20260621-153012-a1b2   # session-tier files only
seq: 03                         # session-tier files only
---
```

- **`agent:` and `task:` are always present.** `task:` is composed from the brief the agent already
  receives — no brief gains a field to supply it.
- **`session:` and `seq:` are present exactly when the file sits under a minted session tree.**
  The protocol has three tiers, not two, and the rule is stated against all three:

  | Tier | Path | `session:` / `seq:` |
  |---|---|---|
  | session tree | `<root>/.airsstack/cc/plugins/claudestacks/handoff/<sid>/` | present |
  | single-subagent exception (`protocol.md` exception clause) | a literal temp path | absent |
  | `init`-refused fallback (`context-handoff.md:144-149`) | `<session-scratch>/handoff/` | absent |

  The third tier keeps the `<NN>-<agent>-<slug>.md` naming but mints no session and writes no
  lease, so there is no session identifier to record; classifying it with the exception rather
  than with the session tree is deliberate and is what §7's path test implements.
- **`created:` is removed.** The file's own modification time carries it, the validator reads it
  from the filesystem when it needs it, and keeping it would require every one of the seven agents
  to gain `date` in its allowed Bash for a value nothing consults. The absorbed chain widened two
  `## Boundaries` sections for exactly this; that widening is not carried over.

## 5. The agent side

### 5.1 The stub

Each of the seven writer agents carries this and nothing more about the *protocol*:

```markdown
## Context handoff

When your brief gives you a handoff write-path, write ONE file there: `<summary>…</summary>`
wrapping what the orchestrator routes on, `<detail>…</detail>` wrapping the heavy material,
omitted when there is none. Return ONLY the `<summary>` plus that path, never the `<detail>`.
Write no file but that one through this channel. If no path is given, or the write fails (say
so), return your full receipt inline. Full protocol: <pointer, per §5.2>.
```

The stub states exactly the contract that must survive the pointer never being read — P10 shows a
delivery mechanism can fail silently, and `protocol.md`'s error-handling clause already guarantees
an agent run with no handoff path behaves as it did before the protocol existed. Everything
conditional — path layout, `<NN>-<agent>-<slug>` naming the orchestrator assigns anyway, the
lease, retention, the tiers, the frontmatter keys, the error table — is reached through the
pointer.

The stub is identical across all seven files **except** the pointer line. Nothing agent-specific
appears in it, which is what makes `explorer.md:72`'s stray *"(and, for the coder, source within
task scope)"* impossible to reproduce: the per-agent text no longer restates a rule that differs
by agent.

### 5.2 How each agent reaches the protocol

Each uses the strongest mechanism available to it. The asymmetry is deliberate: the three
in-plugin agents get a pointer that works with no brief at all, which the other four cannot have
(P4).

| Agent | Pointer |
|---|---|
| `claudestacks`: `coder`, `explorer`, `reviewer` | the literal `${CLAUDE_PLUGIN_ROOT}/skills/context-handoff/references/protocol.md`, resolved at load time by P1 and correct even when the agent is run standalone |
| `claudestacks-sdlc`: `task-briefer`, `chain-reader`, `artifact-reviewer` | the `handoff-protocol:` value in the brief, emitted by §6's skill |
| `claudestacks-journal`: `journal-curator` | the same |

For the four cross-plugin agents the stub's last line reads: *"Full protocol: the
`handoff-protocol:` path in your brief. If the brief carries none, follow this section and note
that you had no protocol path."* P4 forbids writing their pointer as a literal, and P2 forbids
computing it in a `Bash` call.

### 5.3 `chain-reader` and `artifact-reviewer` keep a `## Report` section

These two are the pair the absorbed chain fixed, and its finding stands: each specified its file
shape twice, in `## Output` and in `## Context handoff`, and the two disagreed.

**These two agents carry `## Report` *instead of* §5.1's stub, not in addition to it.** The stub
describes file shape, and a second section describing file shape is the defect being removed. Their
`## Report` opens with the stub's four sentences verbatim, so the contract that must survive an
unread pointer is present in all seven definitions, and then continues with the two templates.
§11.3 checks the stub text in all seven on that basis — five as a standalone `## Context handoff`
section, two as the opening of `## Report`.

`## Report` holds, in order: the stub contract; a pointer for everything else (never a
restatement); the `<summary>` shape for that agent as a literal template; the `<detail>` shape as
a literal template. A definition may not describe its file shape outside this section.

**`## Output` is replaced, not deleted.** The absorbed chain's guarantee at
`2026-08-26-agent-report-shape/spec.md:52-54` — "no rule currently in either file is dropped by
this chain" — is carried forward, and so are the per-rule destinations that made it true. The
layout rules become the templates. The behavioural rules in `artifact-reviewer.md:67-75` are not
layout and have no home in a template, so each is routed by name:

| Rule at | Destination |
|---|---|
| `:67-69` the verdict line states the blocking set exactly, its count or `none` | `## Report`, as a sentence governing the `<summary>` template |
| `:69-71` 🟡 and 🔵 under `none` blocking is a normal, passing review | the agent's existing `## What you HARD-REFUSE` neighbourhood, as a reporting rule |
| `:73-75` clean draft → say so in one line; never invent findings; never inflate a nit | the same |

`chain-reader`'s surviving behavioural rules are routed the same way; its `<detail>` template must
preserve extracted text byte-for-byte including interior blank lines, and the current two-space
indent in its `## Output` block does not, so that indent is dropped rather than carried over.

**The templates themselves are carried over, not reinvented.** They are written out in
`2026-08-26-agent-report-shape/spec.md` §4 (`:77-110`) for `chain-reader` and §5 (`:111-143`) for
`artifact-reviewer`. A plan implementing this section takes them from there, adjusted only for
§4's frontmatter.

## 6. The `claudestacks:context-handoff` skill

One skill owns the driver half for all six drivers. It is invoked by name, so a driver in any
plugin reaches it; by P3 its `${CLAUDE_PLUGIN_ROOT}` expands to `claudestacks`' root whoever
invokes it, which is what lets it hand out a path the invoker could not write down.

`SKILL.md` carries:

1. **The resolved protocol path**, as the literal
   `${CLAUDE_PLUGIN_ROOT}/skills/context-handoff/references/protocol.md`, stated as the value a
   driver copies into each brief's `handoff-protocol:` field.
2. **Which tier applies** — the three of §4: the session tree when more than one subagent is in
   flight at once or spawns interleave, a literal temp path for a single-subagent flow, and the
   `<session-scratch>/handoff/` fallback when `init` is refused.
3. **When to run `init` / `beat` / `end`**, and a pointer to `references/protocol.md` for the
   exact `airsl` command line and the worktree-guard workaround it carries. The skill says which
   of the three calls a driver makes and when; the protocol says how to spell them. Per §3 the
   command line itself appears in `protocol.md` and nowhere else, so what is written once here
   instead of six times is the *decision*, not the command.
4. **The fallback** when `init` is refused, and the instruction to record the deviation.
5. **The validator command** from §7, for a driver that wants to check a report by hand.

Each driver's `## Context handoff` section collapses to an invocation of this skill plus whatever
is genuinely local to it — which spawns it makes and in what order. The four exception-path
drivers stop spelling their own temp-path rationale; they state their path and cite the skill.

`disable-model-invocation` is not set, so the skill stays invocable and a future chain can settle
P11 and preload it.

## 7. The report validator

`scripts/lib/handoff_report.lua` holds the rules and nothing else; `scripts/handoff_report.lua` is
its CLI driver, matching the split already used by `handoff.lua` and `lib/handoff.lua` and for the
same reason — the logic is exercised against fixtures without going through a process.

Given a file path it returns a list of violations, each a stable identifier plus a human line:

| Check | Violation when |
|---|---|
| `unreadable` | the file could not be read for any reason but a confinement refusal |
| `read-denied` | the read was refused by the confinement policy |
| `frontmatter-missing` | the file does not open with a `---` block |
| `frontmatter-unterminated` | the file opens with `---` but never closes the block |
| `agent-missing` / `task-missing` | either required key is absent or empty |
| `session-unexpected` / `seq-unexpected` | either key is present in a non-session-tier file |
| `session-missing` / `seq-missing` | either key is absent in a session-tier file |
| `summary-missing` / `summary-repeated` | no `<summary>` pair, or more than one |
| `summary-unclosed` / `detail-unclosed` | an open tag with no matching close |
| `detail-repeated` | more than one `<detail>` pair |
| `summary-empty` | the pair encloses only whitespace |

The two read failures are separate identifiers because they send whoever reads them to different
places: `read-denied` means the caller's grant does not cover the path, so the fix is the grant.
It says nothing about whether the file exists — confinement is checked before the filesystem is
touched, so a path outside the grant is refused whether or not anything is there (probed against
`airsl` 0.1.2, 2026-09-21, including a path whose parent directory does not exist). `unreadable`
is everything the runtime attempted and could not hand back — the file is absent, or is a
directory, or the OS denied it, or its bytes are not UTF-8 — so the fix is the report. Collapsing them tells an agent with a misconfigured grant that its report is malformed.
`unreadable` is deliberately the fallback: only a real confinement refusal is classified away from
it, so a read failure nobody anticipated lands on the wider identifier rather than a false one. The runtime distinguishes them in the error text it returns —
an absent file gives `No such file or directory (os error 2)`, a refusal gives
`fs.read_lines denied: ... is outside the granted read roots` (probed against `airsl` 0.1.2,
2026-09-21). `frontmatter-unterminated` is separate for the same reason: `frontmatter-missing`'s
line is false of a file that does open with `---`, and that line is the reason text the hook hands
back.

**Tag detection anchors at both ends of the line** — a tag line is exactly `<summary>`,
`</summary>`, `<detail>` or `</detail>` with no other content. This is the absorbed chain's rule
(`2026-08-26-agent-report-shape/spec.md:227`, `:237-238`), and it is stricter than anchoring only
at the start: a line reading `<summary>text on the same line` is a violation, not a tag. It is
what makes a report that *discusses* `<summary>` in prose validate clean — the failure recorded at
`2026-08-26-agent-report-shape/intent.md:62-63`, where an unanchored `grep -c` returned `3`
instead of `2` against the assertion at
`2026-08-25-sdlc-agent-tier/plans/01-foundations.md:564-565`.

**Tier is decided from the path**: a path containing the `HANDOFF_REL` segment that
`lib/handoff.lua:17` defines is session tier; anything else is not, which covers both the
exception tier and the `init`-refused tier per §4. The validator requires that constant from that
module rather than repeating the string.

Exit code 0 with no output when clean; non-zero with one line per violation otherwise.

## 8. Hook wiring

Two files, matching the split `enforce.sh`/`enforce.lua` already uses: `hooks/handoff-check.sh` is
a launcher that resolves `airsl` and its own directory, and `hooks/handoff-check.lua` reads the
payload with `airsstack.hook.payload()` and calls the validator. JSON parsing belongs in Lua
because that is where the payload helper lives.

**The report path must be recognised for every tier, not only the session tree.** An
exception-tier report is named by its driver and carries no `<NN>-<agent>-<slug>` prefix and no
`handoff/` segment — `journal-review`'s is `${TMPDIR}/journal-curator-review.md`. A matcher keyed
on either shape would leave the gate silently off for all four single-subagent drivers while
reporting nothing wrong, which is the exact failure this chain exists to remove. The entry
therefore takes the last `.md` path appearing in the agent's report text, and treats "no `.md`
path at all" — not "no path of a recognised shape" — as the standalone case that must not be held.

Three registrations in `hooks.json`, which already holds five hook groups across four event keys:

- **`PostToolUse`, matcher `Write`** — the early signal. It takes `tool_input.file_path`
  (absolute, P5), returns immediately when the path is not a handoff report, and otherwise emits
  `{"decision": "block", "reason": "<violations>"}`. By P6 this blocks nothing; it puts the
  violations next to the write result so the agent sees them at the moment it wrote the file and
  can rewrite before returning. It fires inside the subagent by P5.
- **`PreToolUse`, matcher `SubagentHandback`** — the gate, for sessions where that tool is in use
  (auto mode, P7). It reads `tool_input.message`, which is the report text the agent is about to
  deliver, extracts the handoff path the return contract requires it to state, validates the file,
  and exits 2 on a violation — which blocks the tool call (P6) and sends the agent back to fix it
  before its report can reach the orchestrator.
- **`SubagentStop`, matcher**
  `^claudestacks:(coder|explorer|reviewer)$|^claudestacks-sdlc:(task-briefer|chain-reader|artifact-reviewer)$|^claudestacks-journal:journal-curator$`
  (anchored plugin-scoped form, P9) — the same gate for sessions where `SubagentHandback` is not
  in play, reading the path from `last_assistant_message` and exiting 2 on a violation (P6).

The two gate legs are mutually exclusive in effect, not redundant: P7 makes
`last_assistant_message` carry the report only when the hand-back tool was not used. Each leg
exits 0 when it finds no path, because an agent legitimately without one — the standalone case —
must not be held, and an agent that omitted a path it owed has already broken the return contract
where the orchestrator can see it.

**Known gap.** `hooks.md:2000`: Claude Code does not run a `PostToolUse` hook matching
`Edit|Write` when a `Bash` command rewrites the file. A report written through `Bash` therefore
escapes the early signal. It does not escape either gate leg, which read the file from disk
however it got there. P8 rules out `FileChanged` as an alternative.

## 9. One brief field

`handoff:` is the field name in every brief in all three plugins — it is what `protocol.md` calls
the thing, and the two session drivers already use it. `report:` (design, plan, distill) and
`handoff_path:` (journal-review) are retired. `need:` keeps its name and meaning.
`handoff-protocol:` is new, per §5.2, and carries the resolved path.

## 10. What does not change

- The `<summary>`/`<detail>` split, the routing contract, and the orchestrator's role as sole
  router.
- The flat/leaf topology, every user approval gate, and the rule that no agent commits.
- `handoff.lua` and `lib/handoff.lua` behaviour: session minting, the `.active` lease, the grace
  window, retention, root resolution. All 29 tests in `handoff_test.lua` pass unchanged, and a
  test that needed editing would mean this spec changed behaviour it said it would not.
- What any agent extracts, implements or judges, beyond §5.3's routing of rules between sections.
- No agent gains a tool. The `date` widening the absorbed chain proposed is dropped with
  `created:` (§4).

## 11. Verification

1. **The validator's own tests.** `scripts/handoff_report_test.lua` carries one fixture per
   violation identifier in §7 plus one clean report per tier in §4's table — session, exception,
   `init`-refused — and asserts the exact identifier list. `read-denied` is the one exception and
   cannot have a fixture: the gate runs `airsl test` with `--allow-read /`, under which no path is
   refused, so the suite exercises its classifier against the runtime's literal refusal text
   instead of provoking a live denial. `cargo make plugins-test` runs it. Each
   fixture is written to fail first; a test whose red state was never seen proves nothing.
2. **Anchoring is tested directly.** A fixture whose `<summary>` body discusses the strings
   `<summary>` and `<detail>` in prose must validate clean, and a fixture with
   `<summary>text on the same line` must produce `summary-missing`.
3. **The stub text appears in all seven agents.** A check extracts the stub's four sentences from
   each definition — from `## Context handoff` in five, from the opening of `## Report` in
   `chain-reader` and `artifact-reviewer` (§5.3) — strips the pointer line, and asserts all seven
   are byte-identical.
4. **No file restates the protocol.** A grep asserts that `protocol.md` is the only file under
   `plugins/` containing the frontmatter key list, the retention numbers, or the handoff `airsl`
   invocation — exactly one hit each, in that file. Two exclusions are named rather than
   discovered: `scripts/lib/handoff.lua:18` and `:21` hold `DEFAULT_KEEP = 10` and
   `DEFAULT_GRACE_MINUTES = 120` as code, which §10 forbids changing, and
   `journal-review/SKILL.md:56-61` carries an unrelated `airsl run` invocation for
   `graph-health.lua`. The pattern keys on `AIRSSTACK_HANDOFF_KEEP`, which the handoff invocation
   carries and no other `airsl run` in the tree does.
5. **Every pointer resolves.** For the three in-plugin agents and for the skill, the cited path
   exists relative to `plugins/claudestacks/`. A pointer that does not resolve is the defect this
   chain exists to fix and must fail the check.
6. **`cargo make plugins`** — `airsl check` over every Lua file including the new ones, then
   `airsl test`. This is the gate `.github/workflows/lua.yml` runs on `plugins/**`.
7. **End-to-end, once, by hand.** Run one real orchestrated spawn, confirm the report carries §4's
   frontmatter, and confirm a deliberately malformed report produces the `PostToolUse` reason and
   then the gate refusal. Because P7 makes the active gate leg mode-dependent, this runs twice —
   once in a session using `SubagentHandback` and once without — or, if only one mode is
   reachable, the untested leg is recorded as unverified rather than assumed.

## 12. Rollout

The protocol, the skill, the validator and the hook wrapper script land before any agent or driver
is edited, so there is a target to point at. Agents and drivers follow. Ordering within the agent
set does not matter — the stub is self-sufficient by construction, so a half-converted suite has
no agent worse off than it is today.

The `hooks.json` **registration** is last, separately from the wrapper script landing. Until every
agent emits §4's frontmatter, the gate legs would refuse hand-backs and stops for reports that are
correct under the old schema.

## 13. Non-goals

- **A machine-readable report format.** The validator checks conformance; the tags and the prose
  inside them stay human-first, and nothing parses a report for its meaning.
- **Settling P11.** Whether `skills:` preloading accepts a namespaced plugin skill is left
  undetermined and recorded. If a later chain settles it positively, §5.2's four-agent brief field
  can be replaced by a preload; nothing here forecloses that.
- **Adopting `SubagentHandback` anywhere but the hook.** P7's tool changes how a report reaches
  the orchestrator, and nothing in `plugins/` mentions it. §8 reads it; whether agent definitions
  and the routing contract should be rewritten around it is a larger question and its own chain.
- **Retrofitting reports already written.** Handoff files are ephemeral — pruned at `init`, or in
  `TMPDIR` under the exception.
- **Changing `handoff.lua`'s session behaviour.** The chain's intent permits it; this design does
  not need it. The `init` fragility is contained in §6's skill rather than fixed in the Lua,
  because the guard that causes it belongs to Claude Code and not to this repository.
- **The snapshot store and the journal vault.**
- **`journal-capture`, `journal-note`, `journal-recall`.** None takes a handoff path or mentions
  the protocol.
