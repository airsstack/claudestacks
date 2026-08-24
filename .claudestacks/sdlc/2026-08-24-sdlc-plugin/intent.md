---
status: approved
created: 2026-08-24
---

# Intent: replace claudestacks-sdd with an AI-native SDLC plugin

## Problem

The `claudestacks-sdd` plugin is a linear feature pipeline (brainstorm → write-plan →
execute-plan) adapted from the superpowers plugin. It ends at the user commit gate:
review findings evaporate with the conversation, plans are deleted after shipping,
specs are parked in a HOME-global store outside the repo, and nothing feeds the next
cycle. Every piece of work starts from zero accumulated knowledge. For building
complex, long-lived systems this is the binding constraint — not code generation.

## Affected systems

- `plugins/claudestacks-sdd/` — retired entirely (hard replace).
- `.claude-plugin/marketplace.json` — sdd entry replaced by the new plugin's entry.
- Root `CLAUDE.md` — plugin table and workflow references.
- The `claudestacks` main plugin's reviewer agent — future consumer of the review
  policy artifact (explicitly out of scope for this chain).

## Desired outcome

A `claudestacks-sdlc` plugin implementing Anthropic's AI-native SDLC playbook at
single-author scale: a repo-committed artifact chain (intent → spec → plans → diff →
findings) that is resumable from any worktree and auditable in git history, plus the
two feedback loops the current plugin lacks — review findings distilled into agent
config, and failures triaged back into the pipeline as new intents.

## Constraints

- Single-author context: no multi-role approval ceremony; the user holds every gate.
- Zero mandatory model-token overhead beyond the pipeline itself (deterministic
  status board, deterministic gates; model-run evals stay out).
- Suite conventions hold: soft-coupling to the `claudestacks` main plugin, Lua
  tooling on `airsl`, Apache-2.0, no auto-commit anywhere.

## Non-goals

- Reviewer-agent integration with the review policy (scope 2, own chain).
- Headless triage from CI (scope 3, own chain).
- Migration tooling for the old HOME-global store (abandoned in place).
