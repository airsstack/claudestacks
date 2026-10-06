---
status: approved
created: 2026-10-04
---

# Spec: `/discuss` and a communication protocol on top of context-handoff

Replaces `claudestacks:concise` with two things in the `claudestacks` plugin: a
**communication protocol** — four reply rules plus additions to a handoff report — that
inherits `context-handoff` without modifying it, and a **`/discuss` skill** that uses it to
hand the author a short summary and a numbered topic list, keep the detail on disk, open one
topic on request, and archive the discussion when it closes. The four rules govern every
reply, discussion or not. Authority: `intent.md` in this chain.

## 1. Premises — verified 2026-10-04

Every fact the design rests on, with its proof. Docs were fetched raw with
`curl -sS -L 'https://code.claude.com/docs/en/<page>.md'` and grepped; line numbers refer
to those files as fetched that day.

| # | Premise | Proof |
|---|---|---|
| P1 | The existing validator accepts a report carrying extra frontmatter keys and an extra `<topics>` block, and still catches a real defect. | Probe: a report with `protocol: discuss/1` and `<topics>` → `airsl run --policy confined --allow-read / plugins/claudestacks/scripts/handoff_report.lua <report>` exit 0, no output. Same file minus its `<summary>` line → `summary-missing: no \`<summary>\` line of its own`, exit 1. Rules read at `scripts/lib/handoff_report.lua:252-285` (checks only `agent`/`task`/`session`/`seq`, one non-empty `<summary>`, at most one `<detail>`). |
| P2 | `airsl` resolves `require` only under the running script's own directory; there is no `package` table and no `..` form. | Probe from `req/scripts/main.lua`: `print(type(package))` → `nil`; `require("lib.shared")` with the module under a sibling `hooks/lib/` → `module \`lib.shared\` not found under \`…/req/scripts\``; `require("..hooks.lib.shared")` → `invalid require target … must not begin or end with a dot`. `airsl run --help` documents no module-path flag. |
| P3 | For a plugin loaded with `--plugin-dir`, a `userConfig` option the user never set reaches neither a hook's environment nor skill text, even with a `default`. A marketplace-installed plugin was not probed. | Probe plugin `cfgprobe` (boolean `style_reinject` default `true`, number `retention` default `30`), run `claude -p '/cfgprobe:show hello world' --plugin-dir ./cfgprobe --model haiku` on Claude Code `2.1.289`: the `UserPromptSubmit` hook's `env \| grep '^CLAUDE_PLUGIN_OPTION'` found nothing; the skill rendered `STYLE=${user_config.style_reinject} RET=${user_config.retention}` literally. Docs say `default` is the "Value used when the user provides nothing" (`manifest-reference.md:435`). The design applies defaults in its own code, so it is correct under either behaviour. |
| P3a | An unset placeholder is not valid shell. Unquoted it fails; single-quoted it passes through as text. | `sh` running `echo --keep ${user_config.archive_keep}` → `${user_config.archive_keep}: bad substitution`, exit 1; `echo --keep '${user_config.archive_keep}'` → `--keep ${user_config.archive_keep}`, exit 0. The worktree guard also refused the unquoted form inline ("runs sh with shell text it cannot parse"). |
| P3b | A skill with `disable-model-invocation: true` runs only when the user types it. | `skills.md:60`, `:315`. |
| P4 | A *set* option arrives as `CLAUDE_PLUGIN_OPTION_<KEY>` in hook processes and as `${user_config.KEY}` substitution in skill content. | Docs only: `manifest-reference.md:495-496`. **Not verified by probe** — setting a value writes the author's user settings. The exact text a boolean arrives as is therefore unknown; §8 accepts `true`/`1` and `false`/`0`. |
| P5 | Saved option values are user-scope: one value for every project. | `settings-reference.md:4758` — `pluginConfigs` scope "User or managed". |
| P6 | Skill content substitutes `$ARGUMENTS` and `${CLAUDE_SESSION_ID}`, and that id equals the hooks' `session_id`. | Same `cfgprobe` run: skill rendered `SID=44b72213-256f-49e3-9ffd-00e131373e77 ARGS=hello world`; hook payload `"session_id":"44b72213-256f-49e3-9ffd-00e131373e77"`. Docs: `skills.md:448`, `:452`. |
| P7 | A Bash tool call made by the model has no `CLAUDE_PLUGIN_*` variables. | In this session: `echo "[${CLAUDE_PLUGIN_ROOT:-}]"` → `[]`; `env \| grep -c '^CLAUDE_PLUGIN'` → `0`. |
| P8 | `SessionStart` and `UserPromptSubmit` command-hook stdout is added to the model's context. | `hooks.md:786`. |
| P9 | `SessionStart` fires with source `startup`, `resume`, `clear`, `compact`, `fork`. | `hooks.md:308`. |
| P10 | `UserPromptSubmit` also fires on background-subagent hand-backs, scheduled tasks and cross-session messages. | `hooks.md:1325-1329`. |
| P11 | Exit 2 blocks the call on `PreToolUse` and keeps the subagent running on `SubagentStop`. | `hooks.md` exit-code table (`PreToolUse` "Blocks the tool call"; `SubagentStop` "Prevents the subagent from stopping"). |
| P12 | A subagent using `SubagentHandback` delivers its report as that call's `tool_input.message`; the Agent result then carries only a note. | `hooks.md:1764`, `:1772`. |
| P13 | The existing validator ignores a report cited at a path outside a handoff root. | `skills/context-handoff/references/protocol.md:198-201`; `scripts/handoff_check_hook.lua:39-50`. |
| P14 | A worktree-isolated session refuses runtime-computed variables in an `airsl` command line, except `$HOME`; a plain command may use variables freely, so a skill resolves a value with a plain `echo` first and pastes the literal. | `skills/context-handoff/references/protocol.md:145-154`. `${CLAUDE_PLUGIN_ROOT}` needs no such step inside skill text — it is already substituted there (this session's loaded skills show absolute paths) — and `echo "$CLAUDE_PLUGIN_ROOT"` would print nothing (P7). |
| P15 | The per-repository key is already derived in three places and documented as "ported elsewhere — keep them in sync". | `skills/snapshot-save/SKILL.md:72-77`; Lua copy `hooks/lib/enforce.lua:156-174`. |
| P16 | A plugin change reaches copied installs only with a version bump. | PR #11 body (`gh pr view 11`): "a consumer on a copied install keeps the cached 0.1.6 tree and never receives the fix". |
| P17 | The plugin test gate grants no environment variables. | `Makefile.toml:158-162`: `airsl test --policy confined --allow-read / --allow-write "${TMPDIR:-/tmp}" --allow-exec git plugins`. |

**Not verified:** whether `${CLAUDE_SESSION_ID}` survives `/clear`, `resume` or `fork`. A
grep of `hooks.md`, `skills.md` and `settings-reference.md` found nothing either way. §5.2
is written to hold under both answers.

## 2. Architecture

Three layers; the bottom one is not edited.

```
┌─ /discuss skill ──────────── commands · runs discuss.lua · writes main-thread reports ─┐
├─ communication protocol ──── 4 reply rules · report additions · its own validator ─────┤
└─ context-handoff (as-is) ─── paths · tiers · sessions · summary/detail · base validator ┘
```

File layout, all under `plugins/claudestacks/`:

```
skills/discuss/SKILL.md                    the /discuss commands (§6)
skills/discuss/references/protocol.md      the communication protocol (§3) — single source of the rules
scripts/discuss.lua                        CLI entry (§5)
scripts/lib/discuss.lua                    index model, topic parse, section extract, project key, prune
scripts/lib/comm_report.lua                protocol-addition rules (§4)
scripts/comm_check_hook.lua                hook entry for those rules
scripts/style.lua                          prints the reply rules from protocol.md (§7)
scripts/discuss_test.lua · comm_report_test.lua · style_test.lua
hooks/comm-check.sh · hooks/style.sh       thin launchers (§7)
```

All new Lua sits in `scripts/` because of P2: `comm_check_hook.lua` must reuse
`lib.handoff_report.file_from_payload` (`scripts/lib/handoff_report.lua:362`), and
`discuss.lua` must share the topic parser with it. The cost is that `project_key` cannot be
required from `hooks/lib/enforce.lua`; it is ported (§5.4).

Every `.sh` is a launcher only: resolve `airsl` without relying on `PATH`, pass explicit
grants, map the exit code, never `exec` — the shape of `hooks/concise-tracker.sh:11-38` and
`hooks/handoff-check.sh:9-44`. `discuss.lua` has no launcher; the skill runs `airsl`
directly, as `enforce-doctor` does.

## 3. The communication protocol (`skills/discuss/references/protocol.md`)

Opens by stating that every rule of `skills/context-handoff/references/protocol.md` applies
unchanged — paths, tiers, session lifecycle, file schema, return contract, error handling —
and that this file only adds.

### 3.1 Reply rules

A section headed exactly `## Reply rules`, which `style.lua` prints (§7). Its body:

1. Reduce agent verbosity output.
2. Do not over-explain everything; only explain what matters.
3. Use ASCII visualizations to replace long narratives or text.
4. Be concise but precise; only tell what matters and is important.

Applied as: the outcome comes first; anything that would run past a short paragraph becomes
an ASCII diagram, table or tree; while a discussion is open, a reply ends with its topic list.
These three lines sit inside the `## Reply rules` section with the four rules, so `style.lua`
prints all of it (amended 2026-10-04 during planning).

### 3.2 Brief

A `/discuss` brief carries the two `context-handoff` fields plus one:

```
handoff: <write-path>
handoff-protocol: <context-handoff protocol path>
comm-protocol: <this file's path>
```

### 3.3 Report additions

```
---
agent: reviewer
task: …
protocol: discuss/1            ← required on a protocol report
---
<summary>
at most 6 non-empty lines, outcome first
</summary>
<topics>
1. <title>
2. <title>
</topics>
<detail>
## 1. <title>                  ← one heading per topic, same number and title
…
## 2. <title>
…
</detail>
```

A report with no `<detail>` (a thin report) carries no `<topics>` (§4 `topics-without-detail`).

### 3.4 Return contract

The agent returns its `<summary>`, its `<topics>` lines verbatim, and the report path. It
does not return `<detail>`.

### 3.5 Main-thread reports

During an open discussion, a main-thread answer that would exceed about 15 lines — guidance
to the model, not a checked rule — is written
as a protocol report with `agent: main` to
`<discussion-dir>/reports/NN-main-<slug>.md`, then added with `discuss.lua add`. That path is
outside every handoff root, so per P13 only `add` validates it.

## 4. Validator for the additions (`scripts/lib/comm_report.lua`)

Runs only on a report whose frontmatter has a `protocol:` key; any other report returns no
violations, so `claudestacks-sdlc` and `claudestacks-journal` reports are never touched. The
base schema stays with `lib.handoff_report`.

| id | fails when |
|---|---|
| `protocol-unknown` | `protocol:` is not `discuss/1` |
| `summary-too-long` | more than 6 non-empty lines inside `<summary>` |
| `topics-missing` | `<detail>` present and no `<topics>` pair |
| `topics-malformed` | a non-blank line inside `<topics>` is not `N. <title>` |
| `topics-numbering` | topic numbers are not `1..n` in order |
| `topic-heading-missing` | no line `## N. <title>` inside `<detail>` for topic `N` |
| `topics-without-detail` | `<topics>` present and no `<detail>` pair |
| `protocol-missing` | no `protocol:` key — raised only when `discuss.lua add` asks for it (§5.2), never by the hook |

Tag lines are matched the way `lib.handoff_report` matches them — the tag alone on its line
(`scripts/lib/handoff_report.lua:206-209`).

## 5. `discuss.lua` and storage

### 5.1 Storage

```
${AIRSSTACK_HOME:-$HOME/.airsstack}/discussions/<project-key>/<claude-session-id>/
├── index.json    { "state": "open"|"closed", "opened": <ts>, "closed": <ts>|null, "touched": <ts>,
│                   "topics": [ { "id", "title", "report", "heading", "read" } ] }
└── reports/      report copies, filled at `done` (and main-thread reports, §3.5)
```

JSON because only the script reads it; `airsstack.json` already serves that role elsewhere
in the suite (`plugins/claudestacks-journal/scripts/lib/health.lua:112`).

### 5.2 Commands

Every command takes `--session <id>` (from `${CLAUDE_SESSION_ID}`, P6) and runs from the
repository's working directory.

| command | does | non-zero exit when |
|---|---|---|
| `start [--keep <n>]` | create or resume `<sid>/` as `open`; prune (§5.3) | — |
| `add <report>` | run `lib.handoff_report.check` and `lib.comm_report` on it, with `protocol:` required (`protocol-missing`); append its topics with the next ids; print `<id> <title>` per topic | any violation (printed one per line) |
| `list` | this session's topics: id, title, read mark | no discussion for this session — the message points at `list --archive` |
| `list --archive` | other discussions of this project, open or closed: `<sid8>/<n>`, title, state | — |
| `show <id>` \| `show <sid8>/<n>` | print that topic's `## N.` section only; mark read | unknown id; `report gone: <path>` if the file vanished |
| `done` | copy every cited report into `reports/`, repoint the index, set `closed` | no open discussion |
| `report-path <slug>` | print the next free `<discussion-dir>/reports/NN-main-<slug>.md` for a main-thread report (§3.5); `NN` is two digits, one past the highest in `reports/` (added 2026-10-04 during planning) | no open discussion; slug not `[a-z0-9-]+` |

If the session id changes under an open discussion (unverified, §1), that discussion is
not lost: it shows in `list --archive` as `open`, its topics stay readable as `<sid8>/<n>`,
and it ages out under §5.3.

### 5.3 Retention

`start` keeps the project's newest `n` discussions other than the current one, ordered by
the index's own `touched` field (epoch seconds, rewritten on every save), and removes the
rest. A field rather than the file's mtime because `fs` cannot set an mtime
(`scripts/lib/handoff.lua:199-200`), so tests could not order fixtures written in the same
second (amended 2026-10-04 during planning). Counting open ones too means a session
that crashed before `done` still ages out. `n` comes from `--keep`; anything that is not a
positive integer — including the literal `${user_config.archive_keep}` an unset option leaves
in skill text (P3), which the skill passes single-quoted so the shell hands it over untouched
(P3a) — means `20`.

### 5.4 Project key

`lib/discuss.lua` ports the reference derivation of `skills/snapshot-save/SKILL.md` —
`<sanitized basename of the common-dir's parent>-<first 8 hex of sha1(absolute common-dir)>`,
falling back to `cwd` outside a repository — read from `.git` without running `git`, as
`hooks/lib/enforce.lua:85-174` does. It is the fourth copy (P15); the snapshot-save sync note
gains a line naming it.

### 5.5 Grants

`airsl run --policy confined --allow-env HOME --allow-env AIRSSTACK_HOME --allow-read /
--allow-write <root>`. `--allow-read /` because reports may sit in `TMPDIR` or any handoff
root, the same reason `hooks/handoff-check.sh:29-33` gives. `<root>` is a literal the skill
obtains first with the plain command `echo "${AIRSSTACK_HOME:-$HOME/.airsstack}"` (P14).

### 5.6 Testability

The test gate grants no environment variables (P17), so every value a test varies — the
storage root, the session id, `--keep` — reaches `lib/discuss.lua` as an argument, never read
from the environment inside the library. `scripts/discuss.lua` is the only place that reads
`HOME`/`AIRSSTACK_HOME`.

## 6. The `/discuss` skill (`skills/discuss/SKILL.md`)

| invocation | main thread does |
|---|---|
| `/discuss` | `start`; briefs agents with `comm-protocol:` (§3.2); after each report, `add` it and show summary + new topics |
| `/discuss list` | `list` |
| `/discuss list archive` | `list --archive` |
| `/discuss <id>` | `show <id>`; answer from that section only |
| `/discuss done` | `done`; then `handoff.lua end` if a handoff session was minted |

The frontmatter sets `disable-model-invocation: true` (P3b), so only the author starts,
opens or closes anything — the intent's "explicit control only". The skill's real name is
`/claudestacks:discuss`; this spec writes `/discuss` for short.

The argument arrives as `$ARGUMENTS` (P6). Any other argument is refused by name, never
guessed. The skill states each command line with variables already resolved (P14), passes
`--session ${CLAUDE_SESSION_ID}`, and passes `--keep '${user_config.archive_keep}'` —
single-quoted (P3a) — on `start`.
If `airsl` is missing the skill says so and stops; `hooks/preflight.sh` already reports the
fix.

## 7. Hooks and reply-rule delivery

| event | after this change |
|---|---|
| `SessionStart`, no matcher (all of P9) | `style.sh` — prints the reply rules, always |
| `UserPromptSubmit` | `style.sh --turn` — prints them unless `style_reinject` is off (§8); replaces `concise-tracker.sh` |
| `PostToolUse` `Write` | `handoff-check.sh` + `comm-check.sh` |
| `PreToolUse` `^SubagentHandback$` | `handoff-check.sh` + `comm-check.sh` |
| `SubagentStop`, no matcher | `comm-check.sh` (a `/discuss` brief may go to any agent; it acts only on `protocol:`); `handoff-check.sh` keeps its named matcher |

Every other entry in `hooks/hooks.json` stays as it is: `preflight.sh` on `SessionStart`
`startup|resume|clear`, `rearm.sh` on `compact`, the `SessionEnd` echo, and `enforce.sh` on
`PreToolUse` `Read|Edit|Write`.

`style.lua` reads the `## Reply rules` section out of `protocol.md` at run time, so the rules
exist once. Because `SessionStart` covers `clear` and `compact` (P9) and its stdout is context
(P8), the rules survive even with the per-turn re-send off. P10 means the per-turn print also
runs on hand-backs and scheduled turns; it prints the same fixed text, so that is harmless.
`style.sh` always exits 0.

`comm_check_hook.lua` locates the report with `lib.handoff_report.file_from_payload` and
mirrors `scripts/handoff_check_hook.lua:52-63`: on `PostToolUse` it emits
`{decision:"block", reason}`; on the gate events it prints the violations and
`comm-check.sh` exits 2 (P11). Any other failure exits 0, as `hooks/handoff-check.sh:4-7`
requires.

## 8. Options (`plugin.json` `userConfig`)

| key | type | default (applied in our code, P3) | read by |
|---|---|---|---|
| `style_reinject` | boolean | on | `style.lua` via `CLAUDE_PLUGIN_OPTION_STYLE_REINJECT`; `false` or `0` turns it off, anything else or absent is on |
| `archive_keep` | number | 20 | the skill, substituted into `--keep` (P7 rules out the environment) |

`style.sh` adds `--allow-env CLAUDE_PLUGIN_OPTION_STYLE_REINJECT`. Values are per user, not
per project (P5).

## 9. Removing `concise`

- Delete `skills/concise/`, `hooks/concise-tracker.sh`, `hooks/concise-tracker.lua`,
  `hooks/lib/concise.lua`, `hooks/concise_test.lua` (18 tests).
- Reword every other mention: `hooks/preflight.sh:12` and `:41`, the comments at
  `hooks/enforce_test.lua:65` and `:125`, `skills/snapshot-save/SKILL.md:45`, the plugin `README.md`,
  `.claude-plugin/plugin.json` description, `.claude-plugin/marketplace.json:12`, root
  `README.md:43` and `:61`, `CLAUDE.md:103` (now: the plugin's hooks deliver the reply rules;
  nothing to load), `CLAUDE.md:228`, and the test count at `CLAUDE.md:200` ("266 assertions
  across 16 files" — already stale; the gate on 2026-10-04 reported `346 passed, 0 failed
  (17 files)`), rewritten to whatever the gate reports after this change.
- Bump `claudestacks` `0.1.7 → 0.2.0` (P16; a skill is removed).
- `~/.airsstack/cc/concise.json` is left on disk; nothing reads it, and the README says it may
  be deleted.

## 10. Error handling

| failure | behaviour |
|---|---|
| `airsl` missing | launchers exit 0; `preflight.sh` reports it; the skill says so and stops |
| `style.lua` cannot read `protocol.md` | prints nothing, exits 0 |
| report violates the additions | blocked at the agent's gate (P11); at `add`, refused with violations |
| report vanished before `done` | `show` prints `report gone: <path>`; `done` records it as missing and still closes |
| unknown `/discuss` argument | refused by name, nothing run |

## 11. Testing

`airsl test` files; every test is seen failing before it passes (break the code, watch it go
red). Gate: `cargo make plugins` (`airsl check` + `airsl test`).

- `comm_report_test.lua` — each violation id; a valid protocol report passes; a report
  without `protocol:` returns nothing from the hook path and `protocol-missing` from the
  `add` path; `comm_check_hook`'s event split — `PostToolUse` emits `decision:"block"`,
  the gate events write violations to stdout (§7).
- `discuss_test.lua` — every command and its exit cases; ids continue across two `add`s;
  `show` returns one section only; `done` copies reports and survives a missing one; pruning
  keeps `n` and spares the current session; `--keep` given `${user_config.archive_keep}`
  means 20; the project key of a linked worktree equals its main worktree's, and for a
  fixture path equals a hard-coded value captured once from the `skills/snapshot-save`
  reference shell block — so a port that skips the physical-path step fails.
- `style_test.lua` — extracts exactly the `## Reply rules` section; option parsing for
  `true`, `1`, `false`, `0`, absent — values passed as arguments (§5.6).

Launcher check, outside the gate: run `sh hooks/style.sh` and `sh hooks/comm-check.sh` with
a fixture payload on stdin and assert stdout and exit code, as `.claudestacks/sdlc/
2026-09-21-context-handoff-single-source/plans/06-hook-wiring.md:458-472` did for
`handoff-check.sh`. Also run the real `start` line from §6 with the option unset, so the
single-quoting is tested on the path that broke, not only in the library.

Closing check: `git grep -n -i -E 'claudestacks:concise|concise-tracker|concise tracker|concise hook|concise (output|response) mode|lib/concise|concise_test|skills/concise|`concise`' -- . ':!crates' ':!.claudestacks'` returns nothing. It targets references to the removed skill, not
the English word, which legitimately stays in rule 4 of §3.1 ("Be concise but precise"), its test,
the §9 README note about `concise.json`, `skills/snapshot-load/SKILL.md:64`, and the
`M-CONCISE-NAMES` rule in `claudestacks-guideline-rust` (amended 2026-10-04 during planning: the
earlier word-level grep contradicted §3.1 and §9). Run on 2026-10-04 before the change, the same
command finds every mention §9 lists, so it is known to find what it should.

Acceptance, by hand: one live session — `/claudestacks:discuss`, one subagent under the
protocol, `list`, `<id>`, `done`, `list archive` from a second worktree.

## 12. Non-goals

- Changing anything in `skills/context-handoff/` or `scripts/lib/handoff_report.lua`.
- Moving `coder`, `explorer`, `reviewer`, or any `sdlc`/`journal` agent onto the protocol.
- `/gh-pr-submit`; separate `comm`/`ops` plugins; mods; claudevs support for mods.
- The `SessionEnd` reminder whose `echo` reaches only the debug log (`hooks.md:786`).
- Natural-language triggers of any kind.
- Proving P4 by probe; the parsing in §8 tolerates either form instead.
