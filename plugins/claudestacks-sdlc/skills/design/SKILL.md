---
name: design
description: Use when a chain's intent is approved and the design is not yet settled — turns an approved intent into an approved spec through a one-question-at-a-time design dialogue, then hands off to the plan skill. Invoke once an intent exists and is approved, before writing an implementation plan or any code.
---

# Design

Transform an approved intent into a fully-formed, user-approved spec through structured
collaborative dialogue. The only goal of this skill is to produce a spec the user stands
behind — one that roots every decision in the intent's problem and desired outcome.

Paths, naming, frontmatter, and state transitions all come from
`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`; artifact body shapes come from
`${CLAUDE_PLUGIN_ROOT}/references/templates.md`. Lazy-create the chain directory before
first write — never assume `/claudestacks-sdlc:setup` ran.

## State gate

This skill requires a chain whose `intent.md` is `status: approved`. Before anything
else, read the intent and check its state:

- `draft` — refuse. Name the file, its current state (`draft`), and that the `intent`
  skill is what advances it (approval, or amendment, happens there).
- `dropped` — refuse. Name the file and state; the idea is dead unless the user
  un-drops it via the `intent` skill.
- `done` — refuse. Name the file and state; the chain already completed its plans. A
  new round of work is a new intent, not a redesign of a finished chain.
- `approved` — proceed.

## Hard gate

Do NOT invoke any implementation skill, write code, or scaffold anything until you have
presented a complete design AND received explicit user approval. This rule holds
regardless of how simple the work appears. A simple intent may produce a short spec, but
the spec must still be written, presented, and approved before moving forward.

## Checklist

Work through these steps in order. Create a `TodoWrite` item for each step so progress
is visible.

1. **Read the intent.** Load the chain's `intent.md` in full — problem, affected
   systems, desired outcome, constraints, non-goals. This is the required input and the
   root every later design decision traces back to.

2. **Load provenance and scan `rfcs/`.** Load every file the intent's
   `derived-from-prd` / `derived-from-rfc` frontmatter names. Then scan the chain root's
   `rfcs/` directory for additional relevant input: if it holds files, surface them and
   ask which (if any) are relevant before proceeding; if empty or absent, proceed with
   no prompt. If the user explicitly names an RFC or other file by path, load it as
   primary input; if that named file is missing, report the path and ask for a
   correction rather than guessing. `rfcs/` is read-only — never create, edit, move, or
   delete a file in it.

3. **Explore project context.** Read relevant files, docs, and recent commits to
   understand the codebase, its conventions, and what already exists. Do not design in
   a vacuum. **Detect the active stack** and load its guideline now — see below.

   Delegate the locating half. When the exploration is broad — mapping an unfamiliar
   directory, sweeping for every use of a symbol, finding which files own a behavior —
   spawn `claudestacks:explorer` and work from the `file:line` tables it returns instead
   of reading those files into this thread. Read directly only what you must actually
   judge: a guideline, a convention you are about to follow, a file whose contents decide
   the design. If `claudestacks:explorer` does not resolve — the `claudestacks` main
   plugin is not installed — do the locating inline here and tell the user the agent was
   unavailable. Never fail hard for want of the main plugin.

4. **Ground every external claim against the artifact, before writing any of them down.**
   A spec that describes an outside system — a documented API, a CLI's behaviour, a file
   format, a wire protocol — is asserting facts this repository does not own. Fetch the
   artifact and read it. For documentation, download the raw source to a local file and
   grep it:

   ```
   curl -sS -L '<doc-url>.md' -o "${TMPDIR:-/tmp}/<name>.md"
   ```

   **Do not use a summarizing fetch tool for this.** Such tools truncate long pages and
   hand the remainder to a small model, which emits plausible invented content instead of
   an error — repeated fetches of the same section can return contradictory schemas. Prefer
   the shipped artifact over documentation about it: type declarations, the sdist, the
   binary's `--help`.

   Every external claim that reaches `spec.md` carries a citation to what you actually read
   — `<local file>:<line>`, a byte offset, a version. A claim you cannot cite does not go
   in the spec; write "not verified" or leave it out. Counts, exhaustive lists, and
   negative existence claims ("the reference documents no such field") are the shapes that
   go wrong most often and cost most later — check each one individually.

   An inherited claim is not a verified one. If the intent already asserts an external
   fact, that is where the error is most likely to be: **verify it here rather than
   carrying it forward.** Every downstream gate compares documents to each other, so a
   wrong fact admitted at this step is confirmed by every later review and surfaces only
   when code meets reality.

5. **Ask clarifying questions one at a time.** Surface the questions that matter most
   for the design: purpose, constraints, success criteria, non-goals. Prefer
   multiple-choice questions where natural — they give the user concrete options and
   keep the dialogue moving. Never ask a battery of questions at once; ask one, get the
   answer, then ask the next. Ask only when the answer changes the spec about to be
   written; anything derivable from the intent, the repo, or a loaded guideline is
   derived and stated as an overridable assumption.

6. **Propose 2–3 approaches.** Once you understand the intent well enough, present two
   or three distinct approaches along with their trade-offs. Lead with your
   recommendation and explain why you favor it. Invite the user to redirect before
   committing to any path.

7. **Present the design section by section.** Walk through the design in sections
   scaled to their complexity. At minimum, cover architecture, key components and their
   responsibilities, data flow, error handling, and testing strategy. Each section must
   conform to the active stack's guideline architecture rules loaded in step 3 — call
   out where a design choice is driven by a guideline rule. After each non-trivial
   section, confirm the user's understanding and agreement before moving to the next.
   This incremental gate catches disagreements early, before the full spec is written.

8. **Write the spec.** Once the design is agreed upon, write `spec.md` in the chain
   directory, in the body shape from `${CLAUDE_PLUGIN_ROOT}/references/templates.md`,
   with `status: draft` frontmatter. Carry forward any provenance frontmatter
   (`derived-from-prd` / `derived-from-rfc`) the intent or this dialogue names. The spec
   is the durable record — write it to stand on its own without reference to this
   conversation.

9. **Review the spec — by an agent, not by yourself.** You wrote every line of this
   spec and held the dialogue that produced it, so you are the weakest available reader
   of it. Spawn `claudestacks-sdlc:artifact-reviewer` over the draft:

   ```
   kind: spec
   draft: <chain>/spec.md
   authority: <chain>/intent.md
   report: <TMPDIR>/claudestacks-sdlc-<chain>-spec-<NN>.md
   ```

   Expand `${TMPDIR:-/tmp}` yourself before the path enters the brief — an agent
   receives its brief as literal text and runs no shell over it, so an unexpanded
   variable would reach it as a filename. The report is always `01`.

   **Exactly one review round. Never a second.** Fix the findings and go to the author.
   Do not re-spawn the reviewer over the revised draft, and do not spawn it again after
   the author asks for changes — revise and present.

   A second round is not worth what it costs. Rounds beyond the first return
   progressively smaller findings on the reasoning, while the errors that actually reach
   code are wrong external facts, which no round can find because every criterion but one
   compares documents to each other. Grounding those facts against the artifact — the step
   above — is what replaces the extra rounds, and the compiler catches the rest in seconds
   rather than twenty minutes. If a draft needs more than one round, it needs rewriting,
   not re-reviewing.

   The agent returns a verdict summary plus that path. Route off the summary; read the
   `<detail>` only when you must act on a finding. Fix the draft yourself — the agent
   never edits it, never flips a `status`, and never commits.

   The criteria it applies live in
   `${CLAUDE_PLUGIN_ROOT}/references/artifact-review.md` § *Reviewing a draft spec*. If
   the agent does not resolve, or returns nothing you can act on, apply that same file's
   criteria inline yourself and tell the user the review ran inline — never skip the
   review for want of the agent.

10. **User review gate.** Ask the user to read the spec file you just wrote and give
   explicit approval. This is a mandatory stop, not a formality. If they request
   changes — small clarifications or significant redesigns — revise the spec and present
   it again. **Do not re-spawn the reviewer**; step 9 has already run and runs once per
   spec. Only on explicit
   approval, flip `spec.md`'s frontmatter
   `status: draft → approved` as the last step of this interaction. Committing the spec
   is the user's call — do not auto-commit.

11. **Redesign path.** When the user asks to redesign a chain whose `spec.md` is
    already `approved`: rename the existing file to `spec-superseded-YYYY-MM-DD.md`
    (today's date), then flip that renamed file's frontmatter
    `status: approved → superseded` — `artifact-chain.md` §7.2 assigns this transition
    to `design`, and the archived file must not go on reading `approved` forever. Only
    then write a fresh `spec.md` with `status: draft`, starting again from step 1.
    `spec.md` — the unsuffixed name — is always the governing spec for the chain.

12. **Hand off.** The `plan` skill is the only next step from an approved spec — do not
    write code or scaffold files yourself; the approved spec is the handoff artifact.

## Design for isolation

When structuring the design, break the system into small units each with one clear
purpose and well-defined interfaces. Each unit should be understandable and testable on
its own, without needing to hold the rest of the system in your head. Highly coupled
designs are harder to test, harder to change, and harder to reason about in review.
Reach for loose coupling and obvious interfaces over clever integration.

## Honor the active stack's guidelines

Before proposing architecture, detect the project's active stack(s) and load the
matching guideline. A guideline plugin advertises itself with an `enforcement.json` at
its root (read by the `claudestacks` plugin's enforcement dispatcher); its `detect`
markers — e.g. `Cargo.toml` for Rust — tell you which stack a repo is. For every active
stack whose guideline skill is installed (e.g.
`claudestacks-guideline-rust:rust-guidelines`), invoke that skill and let its
**architecture** rules — not merely its Definition of Done — shape the design: type
modeling, module layout, dispatch choices, doc and test mandates. A spec that ignores
the guideline's architecture rules produces a plan that bakes those violations in
before a single line of code is written. If no installed guideline matches the active
stack, say so and proceed on general principles.

## Key principles

The checklist carries the dialogue rules (one question at a time, multiple-choice where
natural, 2–3 alternatives, agreement section by section). Two more bind throughout:

- **YAGNI ruthlessly.** No designing for imagined future requirements. Every component
  in the spec has a concrete, immediate reason to exist, traceable to the intent.
- **Be flexible.** If the user redirects mid-dialogue, update your understanding and
  carry forward without defending the prior path.
