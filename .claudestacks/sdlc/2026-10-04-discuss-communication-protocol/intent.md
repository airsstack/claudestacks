---
status: approved
created: 2026-10-04
---

# Intent: replies and agent reports reach the author too long, and `concise` cannot be trusted to fix it

## Problem

**The only verbosity control in the suite misfires.** `claudestacks:concise` is driven by a
`UserPromptSubmit` hook that classifies every prompt with natural-language regexes
(`plugins/claudestacks/hooks/lib/concise.lua:21-26` to deactivate, `:32-33` and `:76` to
activate). Ten ordinary prompts run through `classify` on 2026-10-04 gave the wrong answer
nine times — "stop the server and write a concise summary" and "how do I get out of vim
normal mode" both turn the mode **off**; "the doc comment should be concise" turns it **on**.
The 18 tests in `hooks/concise_test.lua` cover only prompts meant to match, so the suite is
green over this.

**Its state is machine-wide, and more than the author's typing writes it.** The level lives
in one file with no session or project key (`lib/concise.lua:89-91`,
`~/.airsstack/cc/concise.json`), so a switch in one session flips every session and worktree
on the machine. The hook also runs on background-subagent hand-backs, scheduled `/loop`
firings, cross-session messages and expanded pastes (`hooks.md:1325-1329`, `:1339`), any of
which can flip it.

**Even when it works, it only shortens prose.** Subagent output is the larger source of
length. `context-handoff` already keeps an agent's `<detail>` on disk and returns only the
`<summary>` (`skills/context-handoff/references/protocol.md:86-92`), but nothing governs what
the main thread then tells the author: there is no rule for the reply's shape, no way to see
what else a report holds, and no way to come back to it. The detail that does exist is
short-lived — rooted at the worktree (`protocol.md:15-27`) and pruned past ten sessions
(`:174-178`).

**Why now.** The `concise` defects above were found and reproduced on 2026-10-04. The author
already works this way on another machine with three personal skills (`response-to-me`,
`simplify-answers`, `discuss`) built on four rules, and wants that way of working in this
suite instead of `concise`.

## Affected systems

- `plugins/claudestacks/` — the only plugin that changes:
  - `skills/concise/`, `hooks/concise-tracker.{sh,lua}`, `hooks/lib/concise.lua`,
    `hooks/concise_test.lua`, the `UserPromptSubmit` entry in `hooks/hooks.json` — replaced.
  - `skills/context-handoff/` and `scripts/lib/handoff_report.lua` — **read, built on, not
    modified**.
  - Text that names `concise`: `hooks/preflight.sh:41`, a comment at
    `hooks/enforce_test.lua:125`, `skills/snapshot-save/SKILL.md:45`, `README.md` (skill
    table, hooks list, runtime section, Attribution), `.claude-plugin/plugin.json`
    description.
- Repository text that names `concise`: `CLAUDE.md:103` (tells every session to load it),
  `CLAUDE.md:228`, root `README.md:43` and `:61`, `.claude-plugin/marketplace.json:12`.

Not affected (assumed, overridable): `claudestacks-sdlc` and `claudestacks-journal`. Their
agents use `context-handoff`, and a report that carries extra structure still passes the
existing validator unchanged — checked on 2026-10-04 with `scripts/handoff_report.lua`
(superset report → exit 0; same report without `<summary>` → `summary-missing`). The
`M-CONCISE-NAMES` references in `claudestacks-guideline-rust` are an unrelated naming rule.

## Desired outcome

Four rules govern every reply the main thread gives the author, discussion or not:

1. Reduce agent verbosity output.
2. Do not over-explain everything; only explain what matters.
3. Use ASCII visualizations to replace long narratives or text.
4. Be concise but precise; only tell what matters and is important.

Those rules are a **communication protocol** layered on `context-handoff`, and `/discuss` is
the skill that uses it. When an agent works under a `/discuss` brief, the author gets a short
summary and a numbered list of topics; the rest stays out of the conversation until the
author asks for a topic by name. A finished discussion is kept, not discarded, so its topics
can be reopened later from any worktree of the repository.

The chain is finished when `concise` and every reference to it are gone, nothing reads or
writes the machine-wide flag, and the author can start, list, open and close a discussion
without anything guessing at intent from the text of a prompt.

## Constraints

- **`context-handoff` is not changed.** The new protocol inherits it — same paths, tiers,
  session lifecycle, `<summary>`/`<detail>` schema and validator — and adds to it. Nothing in
  `skills/context-handoff/` or `scripts/lib/handoff_report.lua` is edited.
- **Opt-in for agents.** Only reports written under a `/discuss` brief follow the protocol.
  `coder`, `explorer`, `reviewer`, and every `sdlc` and `journal` agent keep their current
  reports.
- **Explicit control only.** Mode and discussion state change on a command's argument, never
  on a classification of free prompt text.
- **Discussion state is per session**, never one value shared by every session on the
  machine.
- **The archive outlives the worktree** and `context-handoff` pruning.
- **Lives in the `claudestacks` plugin**; no new plugin.
- **No mods.** Skills, settings hooks and `airsl` Lua only.
- **The `airsl` confinement holds.** Any hook or script reading a new environment variable
  gets an explicit `--allow-env` grant, as the existing launchers do.
- Candidate directions, one line each, for `design` to settle: commands
  `/discuss`, `list`, `list archive`, `<id>`, `done` with numeric topic ids; a per-session
  topic index on disk; a Lua script that extracts one topic's section; plugin `userConfig`
  options (style re-injection on/off, archive retention); a validator for the protocol's own
  additions, run only on reports that declare it.

## Non-goals

- **`/gh-pr-submit`.** Agreed as a separate intent.
- **Separate `comm` / `ops` plugins**, and the wider `gh-*` set (`gh-pr-reviewer`,
  `gh-issue-analyzer`).
- **Mods**, and **claudevs support for mods** — a later refactor of claudevs.
- **Moving existing agents onto the protocol.** `claudestacks`, `sdlc` and `journal` agents
  adopt it later, one at a time, in their own chains.
- **The `SessionEnd` snapshot reminder**, whose `echo` goes only to the debug log
  (`hooks.md:786`). It is a real defect in the same plugin, but a separate fix.
- **Keeping `concise`'s natural-language triggers** ("be terse", "concise mode").
