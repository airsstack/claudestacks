# Artifact review criteria

What a review of a draft chain artifact checks, by hop. Read by
`claudestacks-sdlc:artifact-reviewer`, and by the calling skill directly when that agent
is unavailable — this file is the single source, so the two can never drift.

The reviewer reports; it never edits the artifact, never flips a `status`, never commits.
The skill that spawned it fixes the draft and holds the user's approval gate.

## Severity

| Emoji | Tier | Use for |
|---|---|---|
| 🔴 | blocking | a placeholder, a requirement with no coverage, a forward reference, or a contradiction that would produce wrong work |
| 🟡 | risk | an ambiguity with a likely-but-unconfirmed reading, or a section whose root in the authority is weak |
| 🔵 | nit | wording, ordering, or a body-shape deviation that changes nothing material |
| ❓ | question | needs the author's intent before it can be judged |

Report every finding at every tier, nits included. Completeness is the reviewer's job;
deciding what is worth acting on belongs to the skill and the user.

`.claudestacks/sdlc/REVIEW.md` does not govern here. That policy is for a code diff in the
consuming repository, not for a chain artifact in this plugin.

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
- **Guideline conformance** — every code block scanned against the active stack
  guideline's architecture rules. If no guideline matches the stack, say so rather than
  skipping silently.
- **External claims inherited from the spec are re-checked, not assumed.** Where a task
  encodes a fact about an outside system — a constant, an exhaustive match, a documented
  field name, a count in a test assertion — verify it against the fetched artifact, not
  against the spec that supplied it. A plan that faithfully transcribes a wrong spec is
  still a plan that will produce wrong code, and this is the last gate before someone
  writes it.
- **No placeholders** — `TBD`, `TODO`, `implement later`; "add appropriate error handling
  / validation / edge cases" without naming them and showing the code; "write tests for
  the above" without the test code; a step saying *what* without showing *how*, with no
  code block, command, or expected output; a reference to a type, function, or constant
  defined neither earlier in the plan nor in the codebase.
