---
name: orchestrate
description: Use when driving a scoped implementation task through the review pipeline — runs coder → reviewer (with explorer to locate code first) from the main thread and holds the user commit gate. Invoke when a change is substantial enough to warrant test-driven implementation plus an independent review before commit. Soft-coupled to the claudestacks agents; if they are not installed, fall back to doing the work inline and tell the user.
---

# Orchestrate

The driver for the `coder → reviewer` pipeline. Plugin agents are **leaves** — they have no `Agent` tool and cannot chain themselves. So the chaining lives HERE, on the main thread that runs this skill. You are the orchestrator: you spawn each agent, route every finding, and hold the commit gate.

## The three agents

| Agent | Model / effort | Role |
| --- | --- | --- |
| `explorer` | haiku · low | Read-only locator: finds and maps code as `file:line` tables. Run FIRST when the task needs code located. Refuses judgment. |
| `coder` | sonnet · high | Implements one scoped task with strict TDD, runs the active stack's DoD, leaves changes in the working tree. Never commits. |
| `reviewer` | opus · high | One combined report: re-runs the DoD + reviews the diff for style/correctness, AND reviews against the spec/plan intent. Report-only. |

Namespaced as `claudestacks:coder`, `claudestacks:reviewer`, etc. Spawn each via the `Agent` tool's `subagent_type`. Both dials are set in each agent's frontmatter — the spawn can override `model:`, but effort comes from the definition only.

## The flow

1. **Locate (optional).** If the task needs code found or a directory mapped first, spawn `explorer`. Use its `file:line` tables to scope the coder's brief. Skip when the target is already clear.
2. **Batch, prove, implement.** Cut the work into batches (below), settle what each task assumes before a coder builds on it, then spawn one `coder` per task within a batch — all in one message, so they run concurrently.
3. **Review — once, when every task is done.** Spawn `reviewer` over the whole diff. It returns the DoD result + code findings + the spec/plan compliance verdict in one report. Once for the run: not per task, not per batch.
4. **Fix round — one.** Route every reviewer finding back through YOU to a FRESH `coder` spawn. The reviewer never calls the coder; you do. Then re-run only the verification each fix touches. Do NOT re-spawn the reviewer over the fixed diff — what closes the work is the reviewer's `blocking:` line, not a report that came back empty. See the review budget.
5. **Commit gate.** Show the USER the diff + the reviewer's report and wait for explicit approval. No agent commits — you don't either until the user says so.

## Batch the tasks, then run each batch in parallel

Sequential-by-default wastes the work's own structure: four tasks over four disjoint files can all build at once.

You wrote the task list, so you scope each task's files yourself — name the exact paths a task may write before you batch it. A task whose file set you cannot name is its own batch.

A run of consecutive tasks belongs in one batch when **both** hold:

- their file sets are pairwise disjoint — no two tasks in the batch write the same path; and
- no task in the batch names a type, function, constant, or module that another task in the same batch creates.

Where the task list alone cannot settle the second test, spawn `claudestacks:explorer` once over the batch's symbols and let its `file:line` table say whether each already exists.

Anything failing either test starts a new batch. A batch of one is normal and fine — much work is genuinely sequential, because task N+1 uses what task N defined. Within a batch, one `coder` per task in a single message. **Never give two concurrent coders the same file.**

## Prove what a task assumes, before a coder builds on it

Every fact a task asserts about something it does not create is a place your task list can be wrong, and the list is not evidence for itself. Sort each such fact:

| Kind | What settles it |
|---|---|
| **The task creates it** | nothing to prove — it does not exist yet by design. |
| **Structural — a symbol, path, or signature said to already exist** | one `explorer` spawn over the whole batch's symbols, returning `file:line` or NOT FOUND. Cheap; batch them. |
| **Behavioural, or a fact about an outside system** | a **throwaway test you actually run**. Write the smallest probe that would come out differently if the claim were false, run it, keep the real output, delete the probe. |

Reading the source is not proof of behaviour. Neither is your own recollection, nor the review finding or bug report the task came from — those are precisely the paths that put a wrong fact there. Run it.

For a claim about a documented external system the artifact is the authority: fetch the raw source to a local file and grep it — `curl -sS -L '<doc-url>.md' -o "$TMPDIR/<name>.md"` — never through a summarizing fetch tool, which truncates a long page and hands the remainder to a small model that emits plausible invented content instead of an error.

Ad-hoc work has no plan supplying a red-green cycle, so the probe is yours to name — but **where the task's own failing test already discriminates the claim, that test IS the probe.** Write a separate one only for claims nothing in the task puts under a test. Probes are for the load-bearing and unproven, not for every literal in the diff.

## Every coder brief names the stack's guidelines

Detect the active stack from repo markers — a `Cargo.toml` means Rust, so the brief names `claudestacks-guideline-rust:rust-guidelines`; `package.json`, `pyproject.toml`, or `go.mod` point at whichever installed `*-guidelines` skill covers that stack. Name that skill in **every** coder brief, and say that its **architecture** rules bind, not only its Definition of Done: a change that passes the gate while violating the stack's structural rules is not done.

If no installed guideline matches the stack, settle it in the brief rather than leaving the coder to ask — say that none matched, that it proceeds on general engineering principles, and that its receipt must say so. Tell the reviewer the same, and tell the user.

## Verification budget — do not over-verify

Run each verification once, at the point it is meaningful, and then trust it. The stack's Definition of Done runs **once for the batch**, not once per task — a green gate is not re-run to confirm it is still green. A file you just wrote through `Edit` or `Write` is not read back; the tool would have failed. The reviewer's own DoD run is the one deliberate duplication in this flow, and it replaces any auditing pass of yours over the coder's receipt — there is no third run. A verification that cannot change what you do next is not a verification.

## Review budget — do not over-review

**One `reviewer` spawn for the whole run, after every task is complete. One fix round. Then you are done.**

- Route the reviewer's findings to a **fresh** `coder` spawn — the reviewer never edits and never calls the coder.
- After that fix round, re-run only the specific verification the fix touches. **Do not re-spawn the reviewer over the fixed diff.**
- If the fix round leaves something genuinely unresolved, that is an escalation to the user, not a second review. Say what is unresolved and ask.

What closes the work is the **blocking set** being empty — every finding named on the reviewer's required `blocking:` line either fixed or put to the user — not the report being empty. The report is not expected to come back empty, and a reviewer that keeps reporting nits after the blocking findings are gone is doing its job, not signalling that work remains. Read that line, not the report's length.

Rounds beyond the first return progressively smaller findings about code the compiler has already accepted, while the defects that actually matter are wrong premises — which no review round can catch, because a reviewer checks the diff against the stated intent, and wrong intent is exactly what it will confirm. The probe step above is what replaces the extra rounds.

## Report in plain words, not in the reviewer's

The reviewer reports everything at every tier because completeness is its job. Translating that
for the user is yours, and it is not optional — relaying its list verbatim hands someone a
tidy-up list that reads as a defect count.

- **Lead with the blocking set.** When it is empty, the first thing you say is that the work is
  ready. Do not open with a total, a tier breakdown, or the longest finding.
- **Then one line for what remains**, naming how much and what kind — "four small cleanups, mostly
  stale wording". Not each item. The user asks for the list if they want it, and usually does not.
- **Say what a thing does, not what tier it sits in.** "This makes the tool report a wrong answer"
  is a defect. "This sentence no longer matches the code" is cleanup. Never carry severity symbols
  into user-facing text: they flatten a ragged line-wrap and a data-loss bug into the same shape,
  and the reader cannot tell which they are looking at.
- **Reserve the word for things that misbehave.** A stale comment, a missing test on a branch that
  already has end-to-end coverage, a duplicated paragraph — those are cleanup. Calling them
  problems, or issues, or bugs, is inaccurate in the direction that costs the most trust.

Work that passes every gate with an empty blocking set is finished work. Presenting it beside a
list of nits describes finished work as though it were broken, and the user has no way to tell
you are doing that.

## Context handoff

Subagents report through the filesystem so the main thread holds summaries, not full detail. Drive it:

1. **Session start.** Run `handoff.lua init` (full invocation in `references/context-handoff.md`) once at the top of the
   pipeline. It prints the session dir and id; keep them. It also prunes stale prior sessions and writes
   the `.active` lease.
2. **Per spawn.** Assign the spawn a file `<NN>-<agent>-<slug>.md` under the session dir and pass that
   **full write-path** in the agent's brief. Call `handoff.lua beat
   <session-dir>` as a heartbeat so a long run is never pruned by a concurrent session.
3. **On return.** The agent returns its `<summary>` + the relative handoff path — NOT the detail. Route
   off the summary. Pull `<detail>` (read the file yourself) only when YOU must judge it.
4. **Downstream needs detail.** Pass the upstream `handoff:` path plus a targeted `need:` pointer in the
   next agent's brief; it reads the slice into its own context. Detail never transits you unless you must
   reason over it.
5. **Session end.** `handoff.lua end <session-dir>` drops the lease
   (optional; the grace window self-heals a crash).

The full protocol — file schema, contract, retention — is `process-guidelines/references/context-handoff.md`.

## Invariants (keep these — they are the point of the flow)

- **Flat / leaf.** No agent spawns another agent. Every result passes through you, so the user gate is never bypassed. If you find yourself wanting an agent to "just call the coder," that's the violation — you make the call.
- **Findings route through the orchestrator.** A reviewer reports; you decide and re-spawn. Reviewers never edit.
- **The reviewer is the independent check.** A coder's "DoD green" is a claim, not proof — which is why the reviewer re-runs the DoD itself rather than reading the receipt. That run is the pipeline's ground truth; there is no second auditing pass over the receipts.
- **User is the commit gate.** No agent runs `git commit`. You present; the user approves.

## Selective delegation

Delegation trades total token spend for main-context longevity — each spawn re-pays a fixed overhead. So:

- Delegate genuinely heavy work: multi-file implementation, full-diff review, broad locating.
- Keep trivia inline on the main thread (a one-line edit costs more delegated than done directly).
- Don't blanket-delegate to "keep context clean" — it raises total cost for no gain.

## Soft coupling / fallback

This skill assumes the `claudestacks` agents are installed. If they are not (the agents don't resolve), degrade gracefully: do the implementation + verification inline on the main thread, follow the same discipline (TDD, DoD from the guidelines skill, user commit gate), and tell the user the agent pipeline was unavailable. Never fail hard for want of the agents.

## Anti-patterns

- An agent spawning another agent (recursion hides steps, bypasses the gate). Agents have no `Agent` tool — keep it that way.
- A coder diff going straight to commit without a reviewer pass.
- A reviewer that edits files instead of reporting.
- Any agent running `git commit`.
- Reaching the commit gate on the coder's word alone — the reviewer's own DoD run is what makes the result real.
- Blanket-delegating trivia to "keep main context clean" — raises total token spend for no real gain.
- Re-spawning the reviewer over the fixed diff, chasing an empty report. The `blocking:` line closes the work.
- Spawning coders one at a time over tasks whose file sets are disjoint.
- Handing a coder a premise nobody probed, then shipping it because the review came back clean.
