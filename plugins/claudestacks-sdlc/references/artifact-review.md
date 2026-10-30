# Artifact review criteria

What a review of a draft chain artifact checks, by hop, and what a review of a draft ADR
checks. Read by
`claudestacks-sdlc:artifact-reviewer`, and by the calling skill directly when that agent
is unavailable — this file is the single source, so the two can never drift.

The reviewer reports; it never edits the artifact, never flips a `status`, never commits.
The skill that spawned it fixes the draft and holds the user's approval gate.

## Severity

| Emoji | Tier | Use for |
|---|---|---|
| 🔴 | blocking | a placeholder, a requirement with no coverage, a forward reference, an unproven claim, or a contradiction that would produce wrong work |
| 🟡 | risk | an ambiguity with a likely-but-unconfirmed reading, or a section whose root in the authority is weak |
| 🔵 | nit | wording, ordering, or a body-shape deviation that changes nothing material |
| ❓ | question | needs the author's intent before it can be judged |

Report every finding at every tier, nits included. Completeness is the reviewer's job;
deciding what is worth acting on belongs to the skill and the user.

`.claudestacks/sdlc/REVIEW.md` does not govern here. That policy is for a code diff in the
consuming repository, not for a chain artifact in this plugin.

## What closes a round

A round closes when the **blocking set is empty** — every 🔴 applied, or declined in front
of the author. It does not close when the report is empty, because the report is never
empty: a thorough reviewer always has a nit, and each round of fixes writes fresh prose
that gives the next round fresh things to find. "Review until it comes back clean" has no
terminating state.

So every report states its own stopping condition. The verdict line names the blocking
set — its count, or `none` — and that is what the calling skill closes on. A report
carrying 🟡 and 🔵 under a blocking count of `none` is a passing review, not unfinished
work, and is not a reason to spawn another round.

This narrows nothing about what gets reported. Completeness is unchanged: every finding,
every tier, as stated above. The stopping condition governs what blocks, not what is
written down.

## A record of verification is itself a claim

A record stating that something was verified — a findings record, a probe log, a
disposition table — asserts that the stated result reproduces. Record the command and its
real output, from the run that actually happened, never a result reconstructed from memory
or from what the fix was expected to produce. A stated result that does not reproduce is a
false green of the same class as a test nobody has seen fail: it reads as evidence and is
not. Treat it as 🔴, the same as no verification at all.

## Reviewing a draft spec

Authority: the chain's `intent.md`. Body shape: `templates.md` § `spec.md`.

- **Placeholders** — no `TBD`, `TODO`, "to be determined", or vague deferral language.
  Either the gap is filled or the decision is made explicit.
- **Internal consistency** — component names, data shapes, and behavioral descriptions
  agree throughout. A component described one way in the architecture section must match
  its description in the error-handling section.
- **Scope** — focused enough to map to one coherent implementation cycle. Independent
  objectives woven together are a finding: they want decomposing before planning starts.
- **Ambiguity** — anywhere the spec reads two ways. Name both readings.
- **Intent tracing** — every section roots in the intent's problem or desired outcome. A
  section with no root is scope creep: it gets cut, or the intent itself has to grow.
- **Every claim carries its proof, and the proof is the right kind.** The spec's rule is
  zero assumptions: a behavioural claim about the codebase needs a probe that was run and
  its output, not a reading of the source; a structural claim needs `file:line`; a count or
  exhaustive list needs the command that produced it; a negative needs the search plus a
  control showing that search finds a sibling that does exist. A claim with no evidence is
  a finding even when it is probably true — "probably true" is exactly the state this rule
  exists to eliminate. Quoted material is the shape that decays first — error text and
  error codes, exit statuses, a command's rendered output, a version number, a count — and
  each one has to have been produced by a run in the same change that wrote it down, not
  predicted from what the code looks like it would do.

  **Re-run every recorded probe whose command you can run**, not a sample, and report any
  whose output differs from the one the spec quotes. Check that the probe exercised the shape
  the text names: a probe described as running against a virtual root that ran a different
  shape proves nothing about the shape it names. Walk the spec for claims no probe or citation
  covers — an error-handling bullet and a risk note assert behaviour as much as a design
  section does. **An unproven claim is 🔴 blocking**, however plausible it reads; the spec
  stage is the last one where it can be probed, so it cannot be left for `plan` or `execute`.
  Say which probes you could not run, and why, rather than counting them as passed.
- **External claims are cited, and the citations resolve.** Every assertion about a system
  outside this repository — a documented API, a CLI's behaviour, a file format, a wire
  protocol — carries a citation to a fetched artifact (`<local file>:<line>`, a byte
  offset, a version). Open the cited artifact and check the claim says what the spec says
  it says. An uncited external claim is a finding regardless of how plausible it reads,
  and so is a citation that does not resolve.

  **This is the only criterion that looks outside the chain.** Every other check above
  validates the draft against an upstream chain document, so a wrong external fact at the
  root is *confirmed* by each of them rather than caught. Do not skip it because the
  upstream artifact already asserts the same thing — the upstream artifact is exactly where
  the error comes from. Counts ("31 events"), exhaustive lists ("the ten that take no
  matcher"), and negative existence claims ("the reference has no such table") are the
  highest-risk shapes: check each one individually against the artifact.

  **An exhaustive list is checked for completeness, not only correctness.** A list whose
  every entry is right but which omits three more is the hardest of these to see, because
  nothing in it is false — find the artifact's own enumeration and compare lengths. Same for
  any set described as "the five X" or "exactly three Y".

  If the spec's external claims cannot be checked because no artifact was fetched, say so
  and mark the review incomplete rather than passing it.

## Reviewing a draft plan set

Authority: the chain's `spec.md`, or its `intent.md` on the spec-skip path. Body shape:
`templates.md` § `plans/NN-<topic>.md`. Review the **set**, not each plan alone — spec
coverage is a property of the set: a requirement satisfied in plan `03` is covered even
though plan `01` says nothing about it.

- **Spec coverage** — every in-scope spec requirement (on the spec-skip path, every
  requirement stated in the intent) maps to a task somewhere across the set, or is
  explicitly deferred with a justification.
- **Type consistency** — every type, signature, and constant used in Task N+1 was defined
  in an earlier task or already exists. A forward reference is a defect: reorder, or add
  the definition.
- **Guideline conformance** — every file placement, module boundary, and named interface
  checked against the active stack guideline's architecture rules. If no guideline matches
  the stack, say so rather than skipping silently.
- **No implementation code** — a task holding a function body, a test body, or a diff is a
  🔴 finding. The plan names files, behaviour, and tests; `execute` writes the code. A
  command line the implementer runs is not code in this sense.
- **Every fact a task encodes traces to a recorded proof in the spec.** Where a task
  encodes a fact about an outside system or about code it does not create — a constant, an
  exhaustive match, a documented field name, a count in a test assertion, how existing code
  behaves — find the probe run or the citation the spec records for it. A fact with none is
  🔴 blocking: the plan does not verify anything itself, so a fact the spec never proved is
  one nobody proved, and the finding sends the spec back to `design` rather than asking the
  plan to patch it. Name the fact and the task that encodes it.
- **A claim the plan makes about what already exists traces to something opened, not to
  the draft it came from.** A count, a version, a field name, a statement about how code
  the task does not create behaves: each cites the spec's recorded proof or the `file:line`
  it came from, and each goes stale silently when the thing it quotes moves on. Where a
  claim cites nothing, that is a finding even if it reads as obviously true. A premise that
  only running new code could settle has no place in a plan at all, `## Risks` included:
  it is an unproven claim in the spec, and it is 🔴.

  This bullet and the one above it are the only two that look past comparing documents:
  they hold the plan to the proofs the spec recorded, so a fact that reached a task without
  one cannot pass as confirmed by the spec it was copied from. Rounds do not substitute for
  the recorded proof.
- **No placeholders** — `TBD`, `TODO`, `implement later`; "add appropriate error handling
  / validation / edge cases" without naming which; "write tests for the above" without
  naming each test and what it asserts; a task with no done-check command; a reference to
  a type, function, or constant introduced neither earlier in the plan nor in the codebase.

## Reviewing a draft ADR

Authority: none for a new ADR; the replaced ADR(s) — those the draft lists in `supersedes` —
for a supersede. Body shape: `templates.md` § `adrs/NNNN-<topic>.md`. An ADR sits outside
the chain, so there is no upstream document to trace to; the checks below are internal to
the draft, except the proof check and, on a supersede, the replaced-ADR check, which
reach outside it.

- **No placeholders** — no `TBD`, `TODO`, "to be determined", or vague deferral language,
  and no bracketed template prompt left in a section. Either the gap is filled or the
  decision is made explicit.
- **Options considered holds at least two real options, each with its trade-offs.** An
  option that exists only to be rejected — a strawman nobody would choose, or one with no
  trade-off stated — does not count. A section naming one option is a 🔴 finding.
- **The decision follows from the context.** The forces the context names are the ones the
  chosen option answers. A decision that answers a force the context never mentions, or
  leaves a named force unanswered, is a finding.
- **Consequences name costs as well as benefits.** A section listing only benefits is a
  finding: every decision has a price, and an ADR that does not state it gives the next
  reader nothing to weigh when the decision is reopened.
- **Every claim carries its proof, by the same rule as a spec.** The criteria are those of
  the spec section's **Every claim carries its proof, and the proof is the right kind**
  and **External claims are cited, and the citations resolve** bullets, with everything
  under the second — the paragraph on exhaustive lists and the closing paragraph that marks
  the review incomplete when an external claim cannot be checked. The proof is the right
  kind, external claims are cited and the citations resolve, an exhaustive list is checked
  for completeness, and a review that could not check an external claim is marked
  incomplete rather than passed — not restated here. A claim with no evidence is a finding
  even when it is probably true.
- **On a supersede, the context states what in the replaced ADR no longer holds.** Read each
  ADR the draft lists in `supersedes` and check that the context names the specific part
  that stopped being true or stopped being worth its cost. A context that only says the
  decision is "outdated", or that never mentions the replaced ADR, is a 🔴 finding: the
  replaced decision was approved, and the reason for reversing it is the content of this one.
