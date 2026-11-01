# Artifact review criteria

What a review of a draft chain artifact or draft ADR checks. Read by
`claudestacks-sdlc:artifact-reviewer`, and by the calling skill directly when that agent is
unavailable; this file is the single source.

The reviewer reports. It never edits the artifact, flips a `status`, or commits; the calling
skill fixes the draft and holds the approval gate.

Intent and spec are the only stages with discussion and verification. Plan asks nothing and
must cover every spec requirement across the set. Execute never asks or re-proves. So a gap
left in the spec reaches execute as a guess: **look for what the artifact does not say, not
only what it says.**

## Severity

| Emoji | Tier | Use for |
|---|---|---|
| 🔴 | blocking | a placeholder, a requirement with no coverage, a forward reference, an unproven claim, an unsettled edge case or error, or a contradiction that would produce wrong work |
| 🟡 | risk | an ambiguity with a likely-but-unconfirmed reading, or a section whose root in the authority is weak |
| 🔵 | nit | wording, ordering, or a body-shape deviation that changes nothing material |
| ❓ | question | needs the author's intent before it can be judged |

Report every finding at every tier, nits included. `.claudestacks/sdlc/REVIEW.md` does not
govern here; it is for code diffs.

## What closes a round

A round closes when the **blocking set is empty**: every 🔴 applied, or declined in front of
the author. It does not close on an empty report; reports are never empty.

The verdict line names the blocking set (count, or `none`); the calling skill closes on it.
🟡 and 🔵 under `none` blocking is a passing review, not a reason for another round.

## A record of verification is itself a claim

A findings record, probe log or disposition table asserts its stated result reproduces.
It must carry the command and its real output from the run that happened, never a result
reconstructed from memory or expectation. One that does not reproduce is 🔴, the same as no
verification.

## Reviewing a draft spec

Authority: the chain's `intent.md`. Body shape: `templates.md` § `spec.md`.

- **Placeholders** — no `TBD`, `TODO`, "to be determined", or vague deferral. Fill the gap or
  make the decision explicit.
- **Unsettled cases** — 🔴 for any edge case, error type, or bad/empty input the spec leaves
  open. Walk each interface and rule yourself: empty, missing, malformed, duplicate,
  out-of-range, concurrent, partial-failure input; each failure mode and what the caller
  sees. If the spec does not say what happens, it is blocking, even if it reads as complete.
- **Rules need checked examples** — 🔴 for any rule or behaviour with no concrete example
  that was actually run or checked (input, expected output, and the recorded run). A rule
  stated only in prose is unproven.
- **Internal consistency** — names, data shapes and behaviour agree across sections.
- **Scope** — fits one coherent implementation cycle. Independent objectives woven together
  are a finding; decompose before planning.
- **Ambiguity** — anywhere the spec reads two ways. Name both readings.
- **Intent tracing** — every section roots in the intent's problem or outcome. A rootless
  section is scope creep: cut it or grow the intent.
- **Every claim carries its proof, and the proof is the right kind.**
  - Behavioural claim about the codebase: a probe that was run, with its output, not a
    reading of source.
  - Structural claim: `file:line`.
  - Count or exhaustive list: the command that produced it.
  - Negative: the search plus a control showing it finds a sibling that exists.
  - Quoted material (error text and codes, exit statuses, rendered command output, versions,
    counts): produced by a run in the same change that wrote it down, not predicted.

  Re-run every recorded probe you can run, not a sample; report any whose output differs.
  Check the probe exercised the shape the text names. Walk the spec for claims no probe or
  citation covers; error-handling bullets and risk notes assert behaviour too. **An unproven
  claim is 🔴**, however plausible. Name the probes you could not run, and why; do not count
  them as passed.
- **External claims are cited, and the citations resolve.** Every assertion about a system
  outside this repository (documented API, CLI behaviour, file format, wire protocol) cites a
  fetched artifact (`<local file>:<line>`, byte offset, version). Open it and check it says
  what the spec says. Uncited or unresolving is a finding.

  This is the only criterion that looks outside the chain; every other check validates
  against an upstream document and would confirm a wrong root fact. Do not skip it because
  upstream asserts the same thing. Check counts, exhaustive lists and negative existence
  claims individually against the artifact.

  **Check exhaustive lists for completeness**, not only correctness: find the artifact's own
  enumeration and compare lengths. Same for "the five X" or "exactly three Y".

  If no artifact was fetched, say so and mark the review incomplete rather than passing it.

## Reviewing a draft plan set

Authority: the chain's `spec.md`, or `intent.md` on the spec-skip path. Body shape:
`templates.md` § `plans/NN-<topic>.md`. Review the **set**: a requirement satisfied in plan
`03` is covered though plan `01` is silent.

- **Spec coverage** — every in-scope spec requirement (on the spec-skip path, every intent
  requirement) maps to a task somewhere in the set, or is explicitly deferred with a
  justification. A requirement with no task is 🔴.
- **Type consistency** — every type, signature and constant in Task N+1 was defined earlier
  or already exists. A forward reference is a defect.
- **Guideline conformance** — file placement, module boundaries and named interfaces checked
  against the active stack guideline. If none matches, say so.
- **No implementation code** — a function body, test body or diff in a task is 🔴. A command
  line to run is not code.
- **Every fact a task encodes traces to a recorded spec proof.** For a fact about an outside
  system or code the task does not create (constant, exhaustive match, field name, count in
  an assertion, existing behaviour), find the probe or citation the spec records. None is
  🔴; the finding sends the spec back to `design`. Name the fact and the task.
- **Claims about what already exists trace to something opened.** A count, version, field
  name or statement about code the task does not create cites the spec's proof or a
  `file:line`. Uncited is a finding. A premise only running new code could settle has no
  place in a plan, `## Risks` included; it is an unproven spec claim and 🔴.
- **No placeholders** — `TBD`, `TODO`, `implement later`; "add appropriate error handling"
  without naming which; "write tests" without naming each test and its assertion; a task with
  no done-check command; a reference to a type, function or constant introduced neither
  earlier nor in the codebase.

## Reviewing a draft ADR

Authority: none for a new ADR; the ADR(s) in `supersedes` for a supersede. Body shape:
`templates.md` § `adrs/NNNN-<topic>.md`. Checks are internal to the draft, except the proof
check and, on a supersede, the replaced-ADR check.

- **No placeholders** — no `TBD`, `TODO`, vague deferral, or bracketed template prompt left
  in a section.
- **Options considered holds at least two real options, each with trade-offs.** A strawman
  or an option with no stated trade-off does not count. One option is 🔴.
- **The decision follows from the context.** The chosen option answers the forces the
  context names. Answering an unnamed force, or leaving a named one unanswered, is a finding.
- **Consequences name costs as well as benefits.** Benefits only is a finding.
- **Every claim carries its proof, by the spec rule.** Apply the spec section's **Every claim
  carries its proof** and **External claims are cited** bullets in full, including the
  exhaustive-list check and marking the review incomplete when an external claim cannot be
  checked. A claim with no evidence is a finding even when probably true.
- **On a supersede, the context states what in the replaced ADR no longer holds.** Read each
  ADR in `supersedes`; the context must name the specific part that stopped being true or
  worth its cost. "Outdated", or no mention of the replaced ADR, is 🔴.
