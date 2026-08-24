---
status: approved
created: 2026-08-24
---

# Spec: claudestacks-sdlc plugin

Replacement for `claudestacks-sdd`, implementing Anthropic's AI-native SDLC playbook
(https://claude.com/blog/the-ai-native-sdlc-playbook) at single-author scale. Six
workflow skills, two commands, a repo-committed artifact chain, and a versioned
review-policy template. Hard replace: `claudestacks-sdd` is deleted in the same
change that lands this plugin.

## 1. Design premises

1. **The chain is committed.** Intents, specs, and plans live in the repo under
   `.claudestacks/sdlc/`. This is what makes the pipeline resumable from any
   worktree, reviewable in PRs, and an audit trail. It reverses sdd's HOME-global,
   never-committed store.
2. **Plans are never deleted.** Superseded, not removed. Plan-vs-diff is a review
   input and part of the trail. sdd's three-gate deletion lifecycle is retired.
3. **Feedback loops are first-class.** `distill` turns recurring review findings
   into agent-config edits; `triage` turns failures into new intents. Both are
   thin dialogue skills, present from v1 so the loops exist from day one.
4. **Deterministic where possible.** State lives in frontmatter; the status board
   is a Lua script; every gate is a state check. Model judgment is reserved for
   the stages that need it.
5. **Guided dialogue everywhere.** Every pipeline skill leads the user with the
   sdd-brainstorm discipline: one question at a time, never a battery,
   multiple-choice where natural, lead with a recommendation, flexible on
   redirect. Depth varies per skill (§4.1); the mode does not.

## 2. Artifact chain model

### 2.1 Layout

```
.claudestacks/sdlc/                        # committed; provisioned by the setup command
├── prds/                                  # optional product input docs (inbox)
│   └── .gitkeep
├── rfcs/                                  # optional technical input docs (inbox)
│   └── .gitkeep
├── REVIEW.md                              # review policy, from template
└── 2026-08-24-webhook-reliability/        # one chain = one intent
    ├── intent.md
    ├── spec.md                            # absent until design runs; may be skipped
    └── plans/
        ├── 01-retry-core.md               # NN- prefix orders plans within a chain
        └── 02-dlq.md
```

- Chain directories are named `YYYY-MM-DD-<topic>` (kebab-case topic). Two chains
  on one day differ by topic.
- A superseded spec is renamed `spec-superseded-YYYY-MM-DD.md` (date of
  supersession) so `spec.md` is always the governing spec. Plans keep their `NN-`
  names; a replacement plan takes the next free number.
- No `.gitignore` management anywhere: everything under `.claudestacks/` is meant
  for git. The repo's existing `.airsstack/` ignore line is untouched.

### 2.2 Input docs: `prds/` and `rfcs/`

- **PRD** = product input (what users need, why, success criteria) — natural seed
  for `intent`. **RFC** = technical input (approach, trade-offs, constraints) —
  natural seed for `design`.
- Both are optional always; empty or absent dirs prompt nothing.
- Both are **read-only to the plugin**: no skill creates, edits, moves, or deletes
  a file in them.
- Both are raw material with **no state machine**: no frontmatter requirements, no
  lifecycle, not rendered as rows on the status board (only as `⤷ inputs:`
  annotations under chains that cite them).
- Top-level inbox only. Per-intent grouping is logical, via provenance
  frontmatter, because input docs pre-date chains and one doc can seed many
  chains.
- Scanning: `intent` scans both dirs and surfaces findings; `design` scans `rfcs/`
  plus anything the intent's provenance names. A file the user names explicitly is
  loaded as primary input; if that named file is missing, the skill reports the
  path and asks for a correction — it never guesses.

### 2.3 Frontmatter

Every chain artifact opens with YAML frontmatter:

```yaml
---
status: draft                 # per-artifact state, §2.4
created: 2026-08-24
derived-from-prd:             # optional, list-valued, provenance only
  - prds/payment-v2.md
derived-from-rfc:             # optional, list-valued, provenance only
  - rfcs/webhooks-v2.md
  - rfcs/retry-budget-notes.md
source: triage                # optional; absent = human-originated
spec: skipped                 # optional, intent only; §2.5
depends-on: [01]              # optional, plan only; empty/absent = independent
---
```

Provenance fields are omitted entirely when nothing seeded the artifact.

### 2.4 States and transitions

| Artifact | States |
|---|---|
| intent | `draft → approved → done`; `dropped` from any state |
| spec | `draft → approved`; `approved → superseded` |
| plan | `draft → approved → executing → done`; `superseded` from draft/approved/executing |

A skill flips a state only as the last step of the interaction that earns it,
always after the user's explicit in-dialogue approval, always by editing the
frontmatter of the file it just worked on. Committing is the user's separate act.

| Transition | When | Flipped by |
|---|---|---|
| intent `— → draft` | file written | `intent` |
| intent `draft → approved` | user approves at the intent gate (in-session or on later re-invocation) | `intent` |
| intent `approved → done` | all the chain's plans are `done` or `superseded`, with at least one `done` | `execute` (walk-up) |
| intent `→ dropped` | user declares the idea dead | `intent` |
| spec `— → draft` | file written | `design` |
| spec `draft → approved` | user approves at the design review gate | `design` |
| spec `approved → superseded` | user requests a redesign; old file renamed per §2.1, new `spec.md` written | `design` |
| plan `— → draft` | file written | `plan` |
| plan `draft → approved` | user approves at the plan review gate | `plan` |
| plan `approved → executing` | execution starts task 1 | `execute` |
| plan `executing → done` | every task verified and the user accepts the completion report | `execute` |
| plan `→ superseded` | re-planning replaces it | `plan` |

`dropped` and `superseded` are terminal but reversible by re-invocation (the skill
flips the state back on the user's instruction); nothing is ever deleted, so git
history plus the state field is the full record. The only flips without a fresh
approval question are the mechanical pair: `approved → executing` and the
intent's `done` roll-up.

### 2.5 Spec skip

Small chains may go intent → plan directly. During the intent dialogue the user
may set `spec: skipped` (the skill records a one-line reason next to it in the
body). `plan` accepts an approved intent directly only when this flag is present;
it never sets the flag itself.

## 3. Plugin structure

```
plugins/claudestacks-sdlc/
├── .claude-plugin/plugin.json        # name claudestacks-sdlc, version 0.1.0,
│                                     # Apache-2.0, homepage/repository as sdd had
├── README.md                         # install, workflow, layout, provenance,
│                                     # uninstall-sdd note, attribution
├── LICENSE                           # Apache-2.0
├── skills/
│   ├── intent/SKILL.md               # the six workflow skills: model- and
│   ├── design/SKILL.md               # user-invocable, default invocation
│   ├── plan/SKILL.md
│   ├── execute/SKILL.md
│   ├── distill/SKILL.md
│   ├── triage/SKILL.md
│   ├── status/SKILL.md               # /claudestacks-sdlc:status — read-only,
│   │                                 # default invocation
│   └── setup/SKILL.md                # /claudestacks-sdlc:setup — writes to the
│                                     # repo, so disable-model-invocation: true
├── scripts/
│   ├── status.lua                    # deterministic board renderer (airsl)
│   └── status_test.lua               # unit tests, airsl test discovers them
└── references/
    ├── artifact-chain.md             # canonical paths, naming, frontmatter,
    │                                 # states, transitions — the prose authority
    ├── templates.md                  # body shapes for intent, spec, and plan
    └── review-policy.md              # REVIEW.md template + tuning guidance
```

No `hooks/` directory. sdd needed SessionStart provisioning because its tree was
per-worktree and HOME-global; this chain is committed, so
`/claudestacks-sdlc:setup` once plus lazy-create in the writing skills covers
every case.

No `commands/` directory either. Custom commands and skills are one mechanism —
a `commands/<name>.md` and a `skills/<name>/SKILL.md` both create `/<name>` and
behave identically — and `skills/` is the superset: it takes a directory for
supporting files and the two invocation-control fields. Everything the plugin
exposes therefore ships as a skill, and `status` and `setup` are ordinary skills
that happen to be operational rather than part of the workflow pipeline.

Invocation control is set per skill, not inherited from a directory. Both the
user and Claude can invoke any skill by default. `setup` sets
`disable-model-invocation: true` because it writes into the user's repository
and its timing is the user's to choose; note that this also drops its
description from context, so Claude will not know it exists — intended. Every
other skill keeps the default: the six workflow skills are meant to be reached
for by name or by relevance, and `status` is read-only.

## 4. Skills

### 4.1 Common contract

Every skill: resolves paths from `references/artifact-chain.md`; lazy-creates its
target directory before first write (never assumes setup ran); never auto-commits;
flips states only per §2.4; runs guided dialogue per premise 5. Depth per skill:

| Skill | Dialogue depth | Proactively asks about |
|---|---|---|
| `intent` | short, 3–5 questions | problem, affected systems, outcome, constraints, why-now; proposes chain splits |
| `design` | full brainstorm depth | clarifiers → 2–3 approaches with recommendation → section-by-section agreement |
| `plan` | targeted | every spec ambiguity (as questions, not assumptions); proposed plan fan-out and dependencies; checkpoint boundaries |
| `execute` | minimal, exception-driven | the one focused question that unblocks, only when blocked |
| `distill` | per-proposal | accept / edit / skip, one config edit at a time |
| `triage` | short, evidence-seeded | usually 1–2 questions to shape the outcome |

Two rules keep dialogue from becoming ceremony: a skill asks only when the answer
changes the artifact it is about to write (anything derivable from the repo, the
chain, or a loaded guideline is derived and stated as an overridable assumption);
and every gate is a real stop, presented as an explicit question with the artifact
in front of the user — never "proceeding unless you object."

### 4.2 `intent` — problem in, chain born

- **Input:** a rough idea in the user's words; or an existing file to convert
  ("turn this RFC into an intent"); or re-invocation on an existing intent (to
  approve, amend, drop, or un-drop it).
- Scans `prds/` and `rfcs/`, surfaces relevant docs, records what seeds the
  intent in the provenance lists.
- **Hard refusal: no solution content.** If the dialogue drifts into "how"
  (architecture, tech choices, file layouts), the skill records at most a
  one-line "candidate direction" note in the body and steers back to the problem.
- **Multi-scope check:** if the problem spans independent subsystems, the skill
  proposes splitting into sibling chains before writing anything.
- **Output:** `<date>-<topic>/intent.md` with problem, affected systems, desired
  outcome, constraints, non-goals; `status: draft`, or `approved` if the user
  approves in-session. Sets `spec: skipped` plus a one-line reason when the user
  chooses the skip path.

### 4.3 `design` — approved intent in, spec out

The sdd `brainstorm` discipline minus problem-capture, plus a required input.

- **Input:** a chain whose intent is `approved`. Refuses `draft` (names the file
  and the advancing command), `dropped`, and `done`.
- Explores project context; scans `rfcs/` and provenance-named docs; detects the
  active stack and loads the matching guideline skill (e.g.
  `claudestacks-guideline-rust:rust-guidelines`), letting its architecture rules
  shape the design; if no installed guideline matches, says so and proceeds on
  general principles.
- Dialogue: clarifying questions one at a time; 2–3 approaches with a
  recommendation; design presented section by section with agreement per section;
  design-for-isolation and YAGNI throughout.
- **Self-review** before the gate: no placeholders; internal consistency; scope
  focused enough for one coherent implementation cycle; ambiguity resolved; and
  **intent tracing** — every spec section roots in the intent's problem/outcome;
  anything without a root is surfaced as scope creep and either cut or taken back
  to the user.
- **Output:** `spec.md`, `draft → approved` at the user gate. Redesign of an
  approved spec follows §2.1 renaming. Hand-off names `plan` as the only next
  step.

### 4.4 `plan` — spec in, plans out

The sdd `write-plan` format carried over intact: TDD task structure (failing test
→ confirm red → minimal code → confirm green → commit), exact file paths,
complete code, runnable commands with expected output, no forward references, no
placeholders, guideline conformance checked per code block, one-objective scope
guard (a goal sentence needing "and" splits the plan), file-structure-first
mapping, 2–5 minute task granularity, standalone-plan property.

Changes from sdd:

1. **Fan-out is first-class.** A spec usually yields several plans:
   `plans/01-<topic>.md`, `02-…`. Each plan's frontmatter carries `depends-on:`
   (list of plan numbers; empty or absent = independent). Independent plans are
   thereby visibly parallelizable across worktrees. The skill proposes the
   fan-out and dependency shape in dialogue before writing.
2. **Spec-skip:** accepts an `approved` intent directly when the intent carries
   `spec: skipped`; never sets that flag itself.
3. **Lifecycle:** plans are superseded, never deleted. sdd's
   `artifact-lifecycle.md` reference is retired without replacement.

Per-plan approval gate as in sdd. The skill recommends committing approved plans
before execution starts, so a worktree picking up a plan reads it from git —
committing remains the user's act.

### 4.5 `execute` — approved plan in, verified diff out

The sdd `execute-plan` discipline carried over: load the plan fully and critique
it before starting (surface ambiguities now, not three tasks in); task ledger;
protected-branch guard (stop on `main`/`master` without explicit consent);
per-task loop through `claudestacks:orchestrate` (coder → reviewer with fix loop)
with graceful degradation to guided inline execution when the main plugin is
absent — never a hard failure; checkpoint boundaries as hard stops; completion
report with per-task evidence; user commit gate.

Changes from sdd:

1. **Input by chain/plan reference** (`2026-08-24-webhook-reliability/01`).
   State-checked: refuses a plan not `approved`; warns when `depends-on` names a
   plan not yet `done` and asks before proceeding.
2. **Verification is the stage-4 contract:** a task is complete only when its
   named verification ran and its output is shown; the completion report shows
   each verification's evidence.
3. **Findings durability:** at completion, before flipping the plan `done`, the
   skill appends a `## Review findings` section to the plan file — the reviewer's
   Important findings, one line each ("category — description — where"). On the
   inline-degraded path the section records `inline execution, no independent
   reviewer` plus anything the verification surfaced.
4. **Deviation record:** departures from the plan are written into the plan file
   as a dated `## Deviations` section before `done` — keeping plan-vs-diff review
   meaningful.
5. **State walk-up:** plan → `executing` at task 1, → `done` at user acceptance;
   then if all sibling plans are `done`/`superseded` (≥1 `done`), intent →
   `done`.

### 4.6 `distill` — review findings in, agent-config edit out

Loop 2. Reads the `## Review findings` sections across chains (durable per
§4.5.3), no session memory required.

1. Scans plans across chains for recurring findings — same category appearing in
   ≥2 chains ("same mistake twice").
2. Presents evidence one proposal at a time: the finding, where it recurred, and
   a concrete minimal edit (a line in the target repo's `CLAUDE.md`, or a change
   to a skill file). Accept / edit / skip per proposal.
3. On accept, applies the edit. The user commits. When the edit touches a plugin
   in this suite, the skill reminds the user to run the plugin gates
   (`cargo make claudevs-check`, `cargo make plugins`) before committing.

Never edits config without a per-proposal accept; never proposes an edit without
citing at least two occurrences.

### 4.7 `triage` — failure evidence in, intent out

Loop 3 entry. Manual invocation only in v1.

- **Input:** pasted log, a file path, or a description of what broke.
- Correlates deterministically checkable facts first (e.g. `git log` — did
  anything relevant change here?), then a short evidence-seeded dialogue (§4.1).
- **Output:** a normal chain with `intent.md`: `source: triage`,
  `status: draft`, and the evidence quoted verbatim in the body at full
  precision — exact error text, exact commands. Enters the same queue as every
  intent; no special downstream handling.

## 5. Operational skills

`status` and `setup` ship under `skills/` like everything else (§3); they are
grouped separately here only because they serve the chain rather than advance
it.

### 5.1 `/claudestacks-sdlc:status`

Deterministic board. Two tiers:

- **Primary:** run `scripts/status.lua` with the installed `airsl` binary. The
  script scans `.claudestacks/sdlc/`, parses frontmatter, derives chain state and
  a NEXT action, renders the board.
- **Fallback:** `airsl` absent → the command instructs the model to perform the
  same scan by the rules in `references/artifact-chain.md`. Same output shape,
  never a hard failure.

```
CHAIN                            STATE                        NEXT
2026-08-24-webhook-reliability   plan 01 executing, 02 apprv  execute 02 (parallel OK)
  ⤷ inputs: prds/payment-v2.md · rfcs/webhooks-v2.md
2026-08-25-rate-limiting         intent approved              design
2026-08-26-dark-mode             intent draft                 approve or drop
2026-08-27-airsl-breakage        intent draft (triage)        review evidence
```

NEXT derivation (states only, no judgment): intent draft → "approve or drop";
intent approved, no spec, no skip → "design"; intent approved with
`spec: skipped` and no plans → "plan"; spec draft → "approve spec"; spec
approved, no plans → "plan"; plan approved with `depends-on` all `done` →
"execute NN"; plan approved with any `depends-on` not yet `done` →
"wait (dependencies pending)"; plan executing → shown as such; all plans done
→ chain complete
(dropped/done chains are listed under a collapsed `DONE/DROPPED` tail section,
count only, unless a verbose flag in the command's dialogue asks for them).
Triage-sourced intents are tagged `(triage)`.

### 5.2 `/claudestacks-sdlc:setup`

Idempotent provisioning: creates `.claudestacks/sdlc/`, `prds/.gitkeep`,
`rfcs/.gitkeep`, and `REVIEW.md` from the template in
`references/review-policy.md` (skipped if present — never overwrites). No
`.gitignore` writes. Reports what it created vs found.

## 6. REVIEW.md template

Shipped in `references/review-policy.md`, provisioned by setup. Sections:

- **Passes**, in order: bugs/logic errors → security → compliance against
  spec and plan.
- **Severity:** Important (must address before commit) vs Nit (batch or ignore).
- **Exclusions:** generated paths; anything CI already enforces.
- **Tuning log:** dated entries when the user adjusts the policy.

The template header states plainly: reviewer-agent consumption is a separate
future chain (scope 2); until then the policy is versioned documentation the user
can point any reviewer at, including pasting into a review prompt by hand.

## 7. Error handling

- **Malformed frontmatter:** the status board renders the row as
  `INVALID (<file>: <reason>)` and continues; skills refuse to operate on a chain
  whose state will not parse, naming the file to fix. No state is ever guessed.
- **Missing directories:** lazy-create, always.
- **Missing `airsl`:** status falls back per §5.1; nothing else in the plugin
  depends on the binary.
- **State-gate refusals** (design on a draft intent, execute on an unapproved
  plan, plan on a chain without spec or skip flag): each refusal names the file,
  its current state, and the command that advances it.
- **Named-but-missing input doc:** report the path, ask for a correction, never
  guess (§2.2).

## 8. Testing

- **`scripts/status.lua`:** unit tests in `scripts/status_test.lua` (the sdd
  `layout_test.lua` pattern), run by `airsl test` via `cargo make plugins`; CI's
  `lua.yml` already filters `plugins/**`, so coverage needs no workflow change.
  Cases: state derivation for each artifact-state combination; NEXT derivation
  per §5.1 including depends-on gating; frontmatter parsing (missing status,
  list-valued provenance, malformed YAML → INVALID row); empty root; chain with
  spec-skip; done/dropped tail collapsing.
- **Plugin structure:** `claude plugin validate --strict` before commit.
- **Skill prose:** no deterministic test in v1; behavioral evals are deliberately
  deferred (see intent constraints).

## 9. Rollout

One change, three parts:

1. Add `plugins/claudestacks-sdlc/` at version 0.1.0.
2. Delete `plugins/claudestacks-sdd/` and its `marketplace.json` entry; add the
   `claudestacks-sdlc` entry ("Implements Anthropic's AI-native SDLC playbook:
   a committed intent → spec → plan → execute chain with distill and triage
   feedback loops and a deterministic status board.").
3. Sweep repo docs: root `CLAUDE.md` plugin table and workflow references;
   any sdd mention in other plugin READMEs.

Post-merge, per machine: `/plugin uninstall claudestacks-sdd@claudestacks`, then
`/plugin install claudestacks-sdlc@claudestacks`. The README carries this.

The old HOME-global sdd store (`~/.airsstack/cc/plugins/sdd/`) is abandoned in
place: not read, not migrated, not deleted.

## 10. Non-goals

- Reviewer-agent consumption of `REVIEW.md` (scope 2 — a change to the
  `claudestacks` main plugin, its own chain).
- Headless triage from CI cron / `claude -p` (scope 3).
- Model-run eval suites for skill behavior.
- Migration tooling for the old sdd store.
- Any `.gitignore` management.
- Maintain-stage metric monitoring or control-band detection.

## 11. Attribution

The README credits two lineages: the stage model and feedback loops implement
Anthropic's AI-native SDLC playbook; the design/plan/execute discipline (gated
design dialogue, TDD plan format, checkpointed execution) descends from
`claudestacks-sdd`, itself adapted from the superpowers plugin
(`superpowers@claude-plugins-official`). Apache-2.0 throughout.
