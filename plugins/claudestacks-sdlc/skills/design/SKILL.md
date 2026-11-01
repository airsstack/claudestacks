---
name: design
description: Use when a chain's intent is approved and the design is not yet settled — settles every question, edge case and fact with the author one question at a time, proves each claim with a run or citation, and writes an approved spec for the plan skill.
---

# Design

## The rule

This is the last stage that talks to the author. `plan` asks nothing and runs nothing; `execute`
never asks and never re-proves. What is not settled and proven here is never settled or proven.

- **Settle everything with the author** — every question, concern, edge case and error case.
- **Prove every claim.** No assumption, prediction or recollection enters the spec.
- **Hunt for what the spec does not say**, not only prove what it does.
- **No code** — no implementation skill, code or scaffolding before explicit approval, however
  simple the work. Probes are not code.

Paths, frontmatter, states: `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`. Body shapes:
`${CLAUDE_PLUGIN_ROOT}/references/templates.md`. Lazy-create the chain directory.

## Gates

**State.** Read `intent.md` and refuse, naming file and state: `draft` (the `intent` skill
approves or amends it), `dropped` (only `intent` un-drops it), `done` (new work is a new intent).
`approved`: proceed.

**Board.** `sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"`, read the chain's row; empty output
means no `airsl` — derive the row as the `status` skill's fallback does. Repeat after every
`status` flip and tell the author the row.

| The row reads | Do |
|---|---|
| `spec stale (intent changed)`, `INVALID (spec.md: missing built-on)` | Re-confirm. |
| `spec disproven by plan NN` | Say plan `NN` disproved a claim; redesign on the author's word. Clears only when the new `spec.md` text differs from the disproven text. |
| `plan NN <status>: blocked (spec not approved)` | Take the draft through the approval gate. |
| `ADR NNNN disproven by plan NN`, `… by <chain>/NN` | Say so; the `adr` skill supersedes or deprecates it. |
| `spec stale (ADR NNNN superseded by MMMM)`, `spec stale (ADR NNNN deprecated)` | ADR re-confirm. |
| `spec blocked (ADR NNNN not approved)` | Say so; the `adr` skill approves it. |

Anything else: state it in the board's words and carry on under the state gate.

- **Re-confirm.** Show the intent as it reads now; ask *does this spec still hold against it?*
  Yes → write the 12 characters of `sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh"
  <chain>/intent.md` as `built-on`, nothing else; spec stays `approved`.
- **ADR re-confirm.** Show the successor (or withdrawn decision); ask *does this spec still hold
  under it / without it?* Yes → in `adrs`, swap in the successor(s) or remove the deprecated
  number, nothing else (the fingerprint does not move).
- After a yes, re-render (an `INVALID` hides other conditions). A no → offer redesign, follow
  only on explicit word. Never infer an answer from silence or from another answer.

## Proof — recorded beside each claim in the spec

| Claim about | Proof |
|---|---|
| This codebase's behaviour | A throwaway probe you ran, with real output — not a source reading. |
| This codebase's structure | `file:line` opened in this task. |
| External documented behaviour | Artifact fetched to a local file, `<file>:<line>`, quoted. |
| External tool behaviour / a count or list | The command and its real output. |
| A negative ("X does not exist") | The search plus a control finding a known sibling the same way. |

- A probe answers one question about what already exists: few lines, one run, existing tools
  only, never the feature. Delete it; keep its output. A question only new code could answer is
  not a claim — restate it about what exists, or cut it.
- Docs: `curl -sS -L '<doc-url>.md' -o "${TMPDIR:-/tmp}/<name>.md"`, then grep. Never a
  summarizing fetch tool. Prefer the shipped artifact (type declarations, sdist, `--help`).
- Re-prove inherited claims (intent, RFC). Remove what cannot be proven; "not verified" is unproven.

## Edge cases — what the spec does not say

For every input, rule and boundary, settle with the author and write into the spec:
- **Bad and empty input:** empty, whitespace-only, malformed, out-of-range, duplicate, and data
  from an older or newer schema version.
- **Errors:** each error type, where it arises, what the caller sees, what is retried or logged.
- **A checked example for every rule**, run against real values including one that could break
  it — a `"City, ST"` rule was approved wrong and parsed `"San Francisco, CA"` as Canada.

An unsettled edge case makes the spec unapprovable.

## Steps

1. **Read `intent.md`** in full — the root of every decision.
2. **Provenance.** Load `derived-from-prd` / `derived-from-rfc` files. If `rfcs/` has files, list
   them and ask which apply (none or absent: no prompt). A named file missing: give the path,
   ask. Never write to `rfcs/`.
3. **Explore.** `claudestacks:explorer` for broad locating (unresolved: inline, say so); read
   directly only what you must judge. Load the stack guideline. If `.claudestacks/sdlc/adrs/`
   exists, read every `approved` ADR title and the body of each bearing on the intent.
4. **Ground** every external claim (Proof) before writing any down.
5. **Ask one question at a time**, multiple-choice where natural, only when the answer changes
   the spec; state derivable answers as overridable assumptions. Cover purpose, constraints,
   success criteria, non-goals, and every edge case.
6. **Propose 2–3 approaches**, recommendation first. One contradicting an `approved` ADR names
   it and means superseding it via the `adr` skill on the author's word. Never ask whether
   something should be an ADR; if asked to record one, hand off to `adr` *new*, number → `adrs`.
7. **Present section by section** — architecture, components, data flow, error handling, edge
   cases, testing — per the guideline's architecture rules; confirm each non-trivial section.
8. **Write `spec.md`**: `status: draft`, templates.md shape, provenance keys, standalone.
   `built-on` = 12 characters of `fingerprint.sh <chain>/intent.md` (empty: stop, name the file).
   `adrs` = every approved ADR relied on (omit if none). **Claim ledger:** every sentence that
   asserts behaviour or a fact — error bullets, risks, non-goals, probe labels included — gets
   its proof beside it; probe or remove. Unsettled edge cases go back to step 5.
9. **One agent review.** `/claudestacks:context-handoff` for the protocol path (one subagent:
   literal temp path, no session, expand `${TMPDIR:-/tmp}` yourself). Spawn
   `claudestacks-sdlc:artifact-reviewer` with `kind: spec`, `draft: <chain>/spec.md`,
   `authority: <chain>/intent.md`, `handoff: <TMPDIR>/claudestacks-sdlc-<chain>-spec-01.md`,
   `handoff-protocol: <path>`. One round, never a second. Route off the summary; read `<detail>`
   only to act; you fix, the agent never edits, flips or commits. Criteria:
   `${CLAUDE_PLUGIN_ROOT}/references/artifact-review.md` § *Reviewing a draft spec* — inline if
   the agent fails, and say so. Every finding at every tier gets a row:
   `| # | Tier | Finding | Disposition (applied / declined — reason) |`.
10. **Approval gate.** Refuse to present while: a claim lacks proof (re-walk the ledger over the
    current draft); an edge case, error case or rule example is unsettled; or an `adrs` number
    is unknown, ambiguous, invalid, disproven or not `approved` (its board row, else its file's
    `status`; name it and the `adr` skill). Recompute the intent fingerprint; if it differs from
    `built-on`, ask whether the spec holds against the intent as it now reads. Ask the author to
    read `spec.md` and approve, with the whole disposition table. Changes: revise, re-present,
    no new review. Explicit approval: in one edit flip `draft → approved` and write the current
    fingerprint as `built-on`; re-render, report the row. Do not commit.
11. **Redesign** (on request, spec `approved`): rename `spec.md` to `spec-superseded-YYYY-MM-DD.md`
    (today), flip it `approved → superseded` (`artifact-chain.md` §7.2), write a fresh draft
    `spec.md` from step 1. Rebuild `adrs`; keep a number only if the new design relies on it.
12. **Hand off** to the `plan` skill. Write no code.

## Principles

- **Stack guideline:** detect via each guideline plugin's `enforcement.json` `detect` markers
  (`Cargo.toml` → Rust), invoke its skill (e.g. `claudestacks-guideline-rust:rust-guidelines`),
  apply its architecture rules, not only its Definition of Done. None installed: say so.
- **Isolation:** small units, one purpose, clear interfaces, testable alone.
- **YAGNI:** every component traces to the intent. **Flexible:** follow redirects, don't defend.
