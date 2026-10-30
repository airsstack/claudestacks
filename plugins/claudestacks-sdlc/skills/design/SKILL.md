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

## Sync check

Before acting, render the board and read this chain's row:

    sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"

When that prints nothing, `airsl` is not installed: derive the row by hand, the way the
`status` skill's fallback does. Do the same again after every `status` flip this skill
makes, and tell the user what the row reads then.

The row's wording, and what each condition means, come from the sync rules in
`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`. These are this skill's to clear, or
to name to the user when another skill clears them:

| The row reads | Do |
|---|---|
| `spec stale (intent changed)` | Offer re-confirmation, below. |
| `INVALID (spec.md: missing built-on)` | Offer re-confirmation, below. |
| `spec disproven by plan NN` | Tell the user that executing plan `NN` disproved a claim of this spec, and that the redesign path (step 11) is what clears it. On their word, follow step 11. The condition ends when the new `spec.md`'s text differs from the text that was disproven — a replacement with the same body leaves it standing. |
| `plan NN <status>: blocked (spec not approved)` | Tell the user the spec is still `draft`, and take it through the user review gate (step 10). Approving it clears the condition. |
| `ADR NNNN disproven by plan NN`, or `ADR NNNN disproven by <chain>/NN` | Tell the user the ADR this spec cites is disproven, and that the `adr` skill supersedes or deprecates it. Nothing here clears it. |
| `spec stale (ADR NNNN superseded by MMMM)`, or `spec stale (ADR NNNN deprecated)` | Offer the ADR re-confirmation, below. |
| `spec blocked (ADR NNNN not approved)` | Tell the user the ADR this spec cites is not approved, and that the `adr` skill approves it. Nothing here clears it. |

Any other condition on the row is not this skill's to clear. Say what the row reads, in
the board's own words, and carry on under the state gate above.

**Re-confirmation.** An approved spec records, in its `built-on` frontmatter key, the
fingerprint of the intent it was written against. When the intent's text has changed
since, or the key is missing, ask the user one question: *does this spec still hold
against the intent as it now reads?* Show them what the intent says now; do not answer
for them.

- **An explicit yes** — compute the intent's current fingerprint,

      sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <chain>/intent.md

  write the 12 characters it prints as `built-on` in `spec.md`'s frontmatter, and change
  nothing else in the file. The spec stays `approved`. Then render the board again: an
  `INVALID` result replaces the whole row, so another condition may have been standing
  behind it.
- **A no** — offer the redesign path (step 11), and follow it only on the user's
  explicit word. A no is not that word; until they give it, the row stays as it reads.

Re-confirmation is never inferred from silence or from an answer to another question,
and never given on the user's behalf.

**ADR re-confirmation.** An approved spec lists the ADRs its design relies on in its
`adrs` frontmatter key. When one of them has since been superseded or deprecated, ask the
user one question: *does this spec still hold under the successor as it now reads* — or,
for a deprecated ADR, *without that decision*? Show them the successor as it reads, or for
a deprecated ADR the decision being withdrawn; do not answer for them.

- **An explicit yes** — in `spec.md`'s frontmatter, replace the ADR's number in `adrs`
  with its successor or successors, or remove it when the ADR was deprecated, and change
  nothing else in the file. `adrs` is frontmatter, so the spec's fingerprint does not move
  and its plans stay as they are. The spec stays `approved`. Then render the board again:
  another condition may have been standing behind this one.
- **A no** — offer the redesign path (step 11), and follow it only on the user's
  explicit word. A no is not that word; until they give it, the row stays as it reads.

This is never inferred from silence or from an answer to another question either.

## Hard gate

Do NOT invoke any implementation skill, write code, or scaffold anything until you have
presented a complete design AND received explicit user approval. This rule holds
regardless of how simple the work appears. A simple intent may produce a short spec, but
the spec must still be written, presented, and approved before moving forward.

## Zero assumptions — every claim is proven before it enters the spec

**A spec contains no assumptions, no predictions, and no recollections. Only claims you
proved in this task.** Plausibility is not evidence. "This is how it surely works" is not
evidence. A prior artifact in this chain asserting it is not evidence — inherited claims are
where errors concentrate, because nothing downstream re-checks them.

Before a claim reaches `spec.md`, classify it and produce the matching proof:

| Claim about | Proof required |
|---|---|
| This codebase's behaviour | A **temporary test or probe you ran**, with its real output. Not a reading of the source — run it. |
| This codebase's structure | `file:line` you opened in this task. |
| An external system's documented behaviour | The artifact fetched to a local file, cited `<file>:<line>`, quoted verbatim. |
| An external tool's actual behaviour | The command run and its real output, pasted. |
| A count, or an exhaustive list | The command that produced it (`grep -c`, the artifact's own enumeration), and its output. |
| A negative — "X does not exist", "there is no such flag" | The exact search run, plus a **control**: the same method finding a sibling you know is present. Without the control the search proves nothing. |

**Write throwaway tests to settle behavioural questions.** Does the harness actually drop
`args`? Write a probe plugin and run it. Does this assertion ever fail? Break it and watch.
Does the tool accept that flag? Run it with the flag. A temporary test that is run and
deleted is worth more than any amount of reasoning about the source, and it is the only way
to catch a behaviour that differs from what the code appears to say. Delete the probes
afterwards; keep their output in the spec as the evidence.

**A probe answers one question about what already exists — it never builds what the spec
describes.** A few lines, one run, one fact, using tools and code that already exist.
Implementing the feature to see whether the design works is a prototype, and a prototype
here means `execute` writes the same code again later: in the playbook the code is written
in Build, after the plan is accepted. This stage is where probes and throwaway tests belong:
`plan` runs nothing new and `execute` does not stop to ask, so a fact left unproven here is
never proven by anyone who can still change the design. A question only the new code could
answer is not a claim the spec may make — reshape it into a statement about what already
exists that a probe can settle, or cut it.

Record the evidence inline, next to the claim, at the precision someone else could re-run.
A spec section whose claims carry no citations is not finished, however confident it reads.

**The claim ledger.** The rule above covers every sentence of the spec that asserts
behaviour or an external fact, not only the design sections. That includes an error-handling
bullet ("a project below the baseline turns the gate red"), a risk note, a non-goal that
rests on a fact, and the label a probe is described with ("a virtual root" when the probe
ran a different shape). Each is a claim, and each needs the run or citation that proves it.
Step 8 builds the ledger and step 10 refuses to present the spec while a row is empty.

**A claim you cannot prove does not go in.** Prove it with a probe now, or leave it out and
say so in the dialogue; a "not verified" marker left in the spec is an unproven claim, and
the ledger refuses it. An unproven claim admitted here becomes a plan's constant, then a
test's expected value, and every gate between here and there compares documents to each other
rather than to the world — so it will not be caught until code meets reality.

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

   When `.claudestacks/sdlc/adrs/` exists, also read the title of every `approved` ADR
   in it, and the body of each one that bears on the intent. Reading is not asking: with
   no `adrs/` directory this step is unchanged.

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
   in the spec; cite it or leave it out. Counts, exhaustive lists, and
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
   derived and stated as an overridable assumption. This is the last stage that talks to
   the author: `plan` asks nothing and `execute` does not stop to ask, so every question
   about the design and its facts is asked and answered here.

6. **Propose 2–3 approaches.** Once you understand the intent well enough, present two
   or three distinct approaches along with their trade-offs. Lead with your
   recommendation and explain why you favor it. Invite the user to redirect before
   committing to any path.

   An `approved` ADR read in step 3 is a settled decision. An approach that contradicts
   one says so and names the ADR, and taking that approach means superseding the ADR
   through the `adr` skill, on the user's word.

   This skill never asks whether a choice should be an ADR. When the user asks for one to
   be recorded, hand off to the `adr` skill's *new* operation. The new ADR's number goes
   into `adrs` when step 8 writes the spec, or into the draft spec's `adrs` if it already
   exists.

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

   The frontmatter also carries `built-on`: the fingerprint of the chain's `intent.md`
   as it reads at this moment. Run

       sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <chain>/intent.md

   and write the 12 characters it prints. If it prints nothing, the intent has no
   fingerprint: stop and name the file rather than write a spec against it.

   It also carries `adrs`: the number of every approved ADR the design relies on,
   including one recorded through the step-6 hand-off. Omit the key when there are none.

   **Build the claim ledger before the review.** Walk the written spec sentence by sentence
   and list every one that asserts behaviour or an external fact, with the run or citation
   that proves it. Write each proof into the spec beside its claim, so the reviewer, the
   `plan` skill, and a later reader find it where the claim is. A claim with no proof is
   either probed now — existing tools and code only, never the feature — or removed. The
   spec leaves this step with no row empty.

9. **Review the spec — by an agent, not by yourself.** You wrote every line of this
   spec and held the dialogue that produced it, so you are the weakest available reader
   of it. Spawn `claudestacks-sdlc:artifact-reviewer` over the draft:

   ```
   kind: spec
   draft: <chain>/spec.md
   authority: <chain>/intent.md
   handoff: <TMPDIR>/claudestacks-sdlc-<chain>-spec-<NN>.md
   handoff-protocol: <the path /claudestacks:context-handoff gave you>
   ```

   Invoke `/claudestacks:context-handoff` for the tier rules and the protocol path. This flow
   spawns exactly one subagent, so it takes a literal temp path and mints no session. Expand
   `${TMPDIR:-/tmp}` yourself before the path enters the brief. The report is always `01`.

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

   **Every finding gets a disposition, and the author sees it.** Not only the blocking
   ones. Build a table as you work the report — one row per finding, at every tier:

   | # | Tier | Finding | Disposition |
   |---|---|---|---|
   | 1 | 🔴 | <one line> | applied |
   | 2 | 🟡 | <one line> | declined — <reason> |

   Carry that table to the approval gate in step 10. A finding you decided not to act on
   is the author's call to confirm, not yours to make silently: `artifact-review.md`
   assigns completeness to the reviewer and the decision to this skill *and the user*.
   Work the tiers in order but do not stop at the end of 🔴 — the risk tier is where a
   quietly-dropped finding hides, because nothing about the draft looks unfinished
   afterwards.

   The criteria it applies live in
   `${CLAUDE_PLUGIN_ROOT}/references/artifact-review.md` § *Reviewing a draft spec*. If
   the agent does not resolve, or returns nothing you can act on, apply that same file's
   criteria inline yourself and tell the user the review ran inline — never skip the
   review for want of the agent.

10. **User review gate.** Ask the user to read the spec file you just wrote and give
   explicit approval, and show them step 9's disposition table in the same message. An
   approval given without sight of the declined findings is not an approval of them.
   This is a mandatory stop, not a formality. If they request
   changes — small clarifications or significant redesigns — revise the spec and present
   it again. **Do not re-spawn the reviewer**; step 9 has already run and runs once per
   spec.

   Before you ask, walk the claim ledger again over the draft as it now reads — the
   review's fixes and the author's changes add sentences. Refuse to present the spec for
   approval while any claim lacks its recorded run or citation: probe it now or remove it.
   A spec presented with an unproven claim is not ready to ask about, and `plan` will send
   it back.

   Also before you ask, compute the intent's fingerprint again and compare it with the
   spec's `built-on`. If they differ, the intent changed while this spec was a draft:
   say so, and the approval question becomes whether the spec still holds against the
   intent as it now reads.

   Also before you ask, check every number in the spec's `adrs`. Refuse to take the spec
   to approval while any of them is unknown, ambiguous, invalid, disproven, or not
   `approved`: name the ADR and its status, and say that the `adr` skill is what moves it.
   A draft spec's citations raise no `ADR NNNN disproven by …`, `spec stale (ADR …)` or
   `spec blocked (ADR …)` part on the board, and a healthy `superseded` or `deprecated`
   ADR has no ADR row, so for each cited number read the ADR's row when it has one and
   its `status` from its file when it has none — the same rule the `adr` skill follows.

   Only on explicit approval, flip `spec.md`'s frontmatter `status: draft → approved`
   and write the intent's current fingerprint as `built-on`, in the same edit, as the
   last step of this interaction. Then render the board again (Sync check) and tell the
   user what the chain's row reads. Committing the spec is the user's call — do not
   auto-commit.

11. **Redesign path.** When the user asks to redesign a chain whose `spec.md` is
    already `approved`: rename the existing file to `spec-superseded-YYYY-MM-DD.md`
    (today's date), then flip that renamed file's frontmatter
    `status: approved → superseded` — `artifact-chain.md` §7.2 assigns this transition
    to `design`, and the archived file must not go on reading `approved` forever. Only
    then write a fresh `spec.md` with `status: draft`, starting again from step 1.
    `spec.md` — the unsuffixed name — is always the governing spec for the chain. The
    fresh spec's `adrs` is written afresh by step 8 from the new design; a number the
    archived spec cited is carried over only when the new design still relies on that ADR.

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
