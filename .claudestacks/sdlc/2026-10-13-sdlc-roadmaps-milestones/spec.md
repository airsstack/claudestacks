---
status: approved
created: 2026-10-13
built-on: 9e19fea4e0d3
---

# Spec: artifact sync checks, roadmaps and milestones for claudestacks-sdlc

This spec delivers two things in the `claudestacks-sdlc` plugin. First, a mechanical check that
related chain artifacts still agree — a plan with the spec it was written against, a spec with
its intent — reported on the status board, used by every skill that reads or flips chain state,
and shown to the session's agent when a session starts. Second, optional roadmap and milestone
artifacts that sit above chains and whose progress is computed from the chains, never written
down. The second is built on the first: one script checks every relation and one board reports
every disagreement, at every level.

## 1. Design premises

**Paths.** A path beginning `scripts/`, `skills/`, `references/`, `agents/` or `hooks/` is
relative to `plugins/claudestacks-sdlc/`. Every other path is relative to the repository root.

Every premise here was proven on 2026-10-13. Probes were throwaway scripts run with the
installed `airsl` binary (`airsl --version` → `airsl 0.1.2`) against a byte-identical copy of
`scripts/lib/status.lua` (`cmp` reported no difference). They are deleted; their output is
recorded here.

**P1 — The board does not notice a plan whose spec is unapproved or missing.** A chain root
holding `2026-10-15-gap` (intent `approved`, `spec.md` `draft`, plan 01 `approved`) and
`2026-10-16-nospec` (intent `approved`, no `spec.md`, no `spec: skipped`, plan 01 `approved`)
rendered:

```
CHAIN                             STATE                         NEXT
2026-10-15-gap                    plan 01 approved              execute 01
2026-10-16-nospec                 plan 01 approved              execute 01
```

Once a chain has plans, `M.derive` returns from inside the `if #chain.plans > 0` block
(`scripts/lib/status.lua:210-263`) and the spec is read only after it (`:265-278`).

**P2 — A new top-level directory is read as a chain.** A chain root holding
`roadmaps/platform/roadmap.md`, a top-level `REVIEW.md`, and two chains rendered:

```
CHAIN                             STATE                         NEXT
2026-10-13-mfa                    intent approved               design
2026-10-14-typo                   intent draft                  approve or drop
roadmaps                          INVALID (intent.md missing)   fix roadmaps
```

Only `prds` and `rfcs` are skipped (`scripts/lib/status.lua:17`); a plain file produces no row
because the scan keeps directories only (`:130`).

**P3 — An unknown frontmatter key is parsed and otherwise ignored.** `2026-10-13-mfa` above
carried `milestone: platform/01` and still derived `intent approved → design`. The parser
returned `milestone=platform/01 type=string`.

**P4 — `airsl` hashes without any grant.** A script run as `airsl run --policy confined
<script>` printed:

```
hash module: hash_file:function, hex:function, sha1:function, sha256:function
sha256("abc\n") = edeaaff3f1774ad2888673770c6d64097e391bc362d7d6fb34982ddf0efd18cb
sha1("abc\n") = 03cfd743661f07975fa2f1220c5194cbaff48451
```

`printf 'abc\n' | shasum -a 256` printed the same 64 characters as the `sha256` line.

**P5 — A body fingerprint is computed identically by Lua and by a shell script.** The
fingerprint defined in §2 was computed over generated files, once by a Lua function using
`airsstack.hash.sha256`, and once by a shell script holding the pipeline of §2, run with each
of two hash tools. The Lua function printed the first six rows' values; the shell script
printed:

```
lf-final-newline.md        shasum=db42cc1eff57 exit=0  sha256sum=db42cc1eff57 exit=0
lf-no-final-newline.md     shasum=db42cc1eff57 exit=0  sha256sum=db42cc1eff57 exit=0
crlf.md                    shasum=db42cc1eff57 exit=0  sha256sum=db42cc1eff57 exit=0
status-flipped.md          shasum=db42cc1eff57 exit=0  sha256sum=db42cc1eff57 exit=0
body-edited.md             shasum=02746658f17b exit=0  sha256sum=02746658f17b exit=0
empty-body.md              shasum=e3b0c44298fc exit=0  sha256sum=e3b0c44298fc exit=0
no-frontmatter.md          shasum=             exit=2  sha256sum=             exit=2
unterminated.md            shasum=             exit=2  sha256sum=             exit=2
```

The first four files share one body and differ in line endings, the final newline, and the
frontmatter `status`; that body holds a `---` line of its own. The shell side ran on macOS
(Darwin 25.3.0) with `/usr/bin/awk`, `/usr/bin/shasum` and `/sbin/sha256sum`. **Not verified:
any of this on Linux.** A container run was attempted and failed with `Cannot connect to the
Docker daemon`. §11 makes the Linux result a gate rather than an assumption.

**P6 — A hook script receives the session's directory.** Fed a SessionStart payload on stdin,
`airsl run --policy confined <script>` printed `payload ok=true`, the payload's `cwd`,
`source=startup` and `hook_event_name=SessionStart` from `airsstack.hook.payload()`, while
`airsstack.path.absolute(".")` printed the directory the command was launched from — a
different directory. The sibling plugin already reads `payload.cwd`
(`plugins/claudestacks/hooks/enforce.lua:116`, `:128`) under `--allow-read /`
(`plugins/claudestacks/hooks/enforce.sh:36-39`).

**P7 — What the Claude Code hooks reference says.** Fetched with `curl -sS -L
'https://code.claude.com/docs/en/hooks.md'` to a local file of 268,811 bytes; line numbers are
that file's.

- `:810` — "The exceptions are `UserPromptSubmit`, `UserPromptExpansion`, `SessionStart`, and
  `PostModelSwitch`, where Claude Code adds plain-text stdout as context that Claude can see
  and act on."
- `:996` — "A hook's `additionalContext`, `systemMessage`, and `initialUserMessage` strings,
  and its plain stdout, are capped at 10,000 characters".
- `:1184` — "SessionStart runs on every session, so keep these hooks fast."
- `:1190-1194` — the SessionStart matcher values `startup`, `resume`, `clear`, `compact`,
  `fork`.
- `:207` — "If you omit the matcher or use `"*"`, the group activates on every occurrence of
  the event."
- `:612-613` — in a worktree `${CLAUDE_PROJECT_DIR}` "still points at the project root where
  the session started", while "the `cwd` field in the hook's [input JSON](#common-input-fields)
  is the worktree root after Claude enters a worktree".

**P8 — What the plugins reference says.** Fetched the same way from
`https://code.claude.com/docs/en/plugins-reference.md`, 41,987 bytes.

- `:264` — "Claude Code merges whatever you declare with `hooks/hooks.json` when that file
  exists."
- `:262` — "A hooks file wraps the event map in a top-level `"hooks"` key … A file that
  contains only the event map, without that wrapper, fails to load."
- `:556` — `${CLAUDE_PLUGIN_ROOT}` is the "Absolute path of the plugin's installed version".
- `:577` — "The variables aren't present in the environment of commands Claude runs through
  the Bash tool … In skill, command, and agent content, write the `${...}` reference in the
  Markdown body instead, and Claude Code substitutes the path inline when it loads the
  content."

**P9 — The plugin ships no hooks today.** `find plugins/claudestacks-sdlc -type d` lists
`references`, `agents`, `scripts`, `scripts/lib`, `.claude-plugin`, `skills` and eight skill
directories, and no `hooks`. Control: `find plugins/claudestacks -maxdepth 2 -name 'hooks*'`
finds `plugins/claudestacks/hooks` and `plugins/claudestacks/hooks/hooks.json`.

**P10 — The test baseline.** `cargo make plugins-test` printed `399 passed, 0 failed (20
files)`. `grep -cE '^  [a-z_A-Z0-9]+ = function\(\)' plugins/claudestacks-sdlc/scripts/status_test.lua`
printed `31`. A test file returns a table of named functions (`scripts/status_test.lua:33-34`).
That task is a shell script (`Makefile.toml:143-151`), and the Lua workflow runs it on
`ubuntu-latest` (`.github/workflows/lua.yml:90`, `:115-116`).

**P11 — A missed chain walk-up is invisible on the board.** A chain root holding one chain —
intent `approved` with `spec: skipped`, its only plan `done` — printed:

```
derive: 2026-10-17-missed-walkup | chain complete | execute walk-up
render:
CHAIN                             STATE                         NEXT
DONE/DROPPED: 1 done, 0 dropped (not listed)
```

`M.derive` returns the pair (`scripts/lib/status.lua:246`) and `M.render` counts any state
matching `^chain complete` into the tail without printing a row (`:318-319`). The existing
test `all_plans_done_derives_chain_complete_and_collapses_to_the_tail` pins that
(`scripts/status_test.lua:225-237`), and `references/artifact-chain.md:188-190` specifies it.
So today nothing on the board tells anyone that an intent was never flipped to `done`.

## 2. Fingerprints and the relation keys

A **fingerprint** identifies the text of an artifact, so a later change to that text can be
detected without anyone having to remember to record it.

**Definition.** The fingerprint of an artifact is the first 12 hexadecimal characters of the
SHA-256 of its body. The body is every line after the line that closes the frontmatter (the
first line equal to `---` after line 1), with a trailing carriage return removed from each
line and each line terminated by exactly one `\n`. The frontmatter is excluded, so a `status`
flip never changes a fingerprint (P5, `status-flipped.md`); any edit to the text does (P5,
`body-edited.md`). A file whose first line is not `---`, or whose frontmatter is never closed,
has no fingerprint (P5, last two rows); the board already reports such a file as `INVALID`
(`scripts/lib/status.lua:27-29`, `:53`).

**Two implementations, one result.** `scripts/lib/fingerprint.lua` computes it for the board.
`scripts/fingerprint.sh <file>` computes it for the no-`airsl` fallback (§8.6): it prints the
12 characters and exits 0, or prints nothing and exits 2 when the file has no fingerprint. It
uses `shasum -a 256` when `shasum` is on the path and `sha256sum` otherwise. Its pipeline, as
probed in P5:

```
awk '{ sub(/\r$/, "") } f { print } !f && NR > 1 && $0 == "---" { f = 1 }' <file> \
  | shasum -a 256 | cut -c1-12
```

**Two keys are added to the frontmatter schema** (`references/artifact-chain.md` §6):

| Key | On | Value | Meaning |
|---|---|---|---|
| `built-on` | spec, plan | a fingerprint | the authority text this artifact was written against, or last re-confirmed against |
| `disproves` | plan | a fingerprint | the authority text this plan's execution showed to be wrong |

**Authority.** A plan's authority is the chain's `spec.md`; when the intent carries
`spec: skipped` and no `spec.md` exists, it is the chain's `intent.md` (the existing spec-skip
rule, `references/artifact-chain.md` §8). A spec's authority is the chain's `intent.md`.

**`built-on` is written in three places.**

1. **When the artifact is written.** `design` writes it on a new `spec.md`, and `plan` on each
   new plan, with the authority's fingerprint at that moment.
2. **At approval.** The skill flipping `draft → approved` — `design` for a spec, `plan` for a
   plan — first compares the artifact's `built-on` with the authority's current fingerprint.
   If they differ, it tells the author the authority changed while the artifact was a draft,
   and the approval question becomes whether the artifact still holds against the authority
   as it now reads. On approval it writes the current fingerprint in the same edit as the
   flip.
3. **At re-confirmation**, below.

`execute` may approve a `draft` plan by being asked to run it
(`references/artifact-chain.md:140`). It does so only when that plan's `built-on` equals its
authority's current fingerprint. Otherwise it refuses and names `plan`: nobody has read the
plan against the changed text.

**Re-confirmation** is how an approved artifact whose `built-on` is out of date or missing
(§3) becomes current again. The skill that owns the artifact — `design` for a spec, `plan` for
a plan — asks the author whether the artifact still holds against its authority as that
authority now reads. On an explicit yes it writes `built-on` with the current fingerprint and
changes nothing else. On a no, the artifact is superseded by the existing paths
(`references/artifact-chain.md` §4). Re-confirmation is never inferred and never performed by
`execute`.

**`disproves` records a debt.** `execute` already stops when a probe comes back against the
plan and asks "amend the plan and the spec now, or after this run?"
(`skills/execute/SKILL.md:267-268`). When what was disproven is a claim of the plan's
authority, `execute` writes `disproves` on the plan it is running, with the authority's current
fingerprint, before it continues — whichever answer the author gives. The key holds one
fingerprint; a later disproof by the same plan overwrites it. It is never removed. It stops
having any effect once the authority's text changes, because its value then matches no current
fingerprint (§3).

## 3. Sync rules on the board

These rules extend NEXT derivation (`references/artifact-chain.md` §9; `M.derive` in
`scripts/lib/status.lua`). They apply to a chain whose intent is `approved`. A chain whose
intent is `draft`, `dropped` or `done` is derived as today, apart from the membership check of
§7.

A **live plan** is a plan whose status is `approved` or `executing`. A **settled plan** is one
whose status is `done` or `superseded`.

### 3.1 Invalid results

An invalid result replaces the whole STATE cell, as it does today
(`scripts/lib/status.lua:191-193`), and its NEXT is `fix <chain>`. When several hold, the cell
shows the first in this order; within a rule, the lowest plan number first.

| # | Condition | STATE |
|---|---|---|
| I1 | any result the board already reports as invalid (`scripts/lib/status.lua:191`, `:206`, `:220`, `:277`) | unchanged |
| I2 | `spec.md` has a status other than `draft` or `approved` | `INVALID (spec.md: unknown status <status>)` |
| I3 | `spec.md` is `approved` and has no `built-on` | `INVALID (spec.md: missing built-on)` |
| I4 | a live plan exists, there is no `spec.md`, and the intent has no `spec: skipped` | `INVALID (plans/NN: no spec and no skip flag)` |
| I5 | a live plan has no `built-on` | `INVALID (plans/NN: missing built-on)` |

I2 exists today only for a chain with no plans (`scripts/lib/status.lua:277`); it now applies
whether or not the chain has plans. A superseded spec is renamed
(`references/artifact-chain.md` §4), so `spec.md` itself is never legitimately `superseded`.

### 3.2 Conditions

| # | Condition | STATE part |
|---|---|---|
| C1 | `spec.md` is `approved` and its `built-on` differs from the intent's fingerprint | `spec stale (intent changed)` |
| C2 | a plan that is not `superseded` carries `disproves` equal to the current fingerprint of its authority | `spec disproven by plan NN`; on the spec-skip path `intent disproven by plan NN` |
| C3 | a live plan's authority is `spec.md` and that spec is `draft` | `plan NN <status>: blocked (spec not approved)` |
| C4 | a live plan's `built-on` differs from its authority's fingerprint, and C3 does not hold for it | `plan NN <status>: stale (spec changed)`; on the spec-skip path `plan NN <status>: stale (intent changed)` |

`<status>` is the plan's own status, so the row still shows whether the plan is `approved` or
`executing`. C3 and C4 read live plans only. C2 reads every plan except `superseded` ones,
because a plan can finish its run with the debt still owed. When several plans satisfy C2, one
part names the lowest number.

### 3.3 STATE

When no invalid result holds, the cell is built in this order, comma-separated, with the
`(triage)` tag appended last as today (`scripts/lib/status.lua:262`):

1. the C1 part, if C1 holds;
2. the C2 part, if C2 holds;
3. for a chain with plans, one part per plan in number order: `plan NN <status>`
   (`scripts/lib/status.lua:223`), or the C3 or C4 form for a plan they hold for;
4. for a chain without plans, today's single state (`intent approved`,
   `intent approved (spec skipped)`, `spec draft`, `spec approved` —
   `scripts/lib/status.lua:265-275`), except that `spec approved` is omitted when C1 holds.

**A chain is complete** when every plan is settled, at least one is `done`, and neither C1 nor
C2 holds. Its cell is `chain complete` and its NEXT is `execute walk-up`, as `M.derive` returns
today (`scripts/lib/status.lua:246`). When C1 or C2 holds, the chain is not complete and its
cell is built by the list above.

### 3.4 NEXT

The first of these that applies:

1. an invalid result → `fix <chain>`
2. C1 → `design`
3. C2 → `design`; on the spec-skip path → `intent`
4. C3 → `approve spec`
5. C4 → `plan`
6. otherwise the existing derivation, unchanged.

Because rule 3 precedes rule 6, a chain with a standing C2 never offers `execute NN`.

### 3.5 What the rules do to P1 and to earlier chains

The two chains of P1, as probed, carry no `built-on`. They render
`INVALID (plans/01: missing built-on)` → `fix 2026-10-15-gap` (I5) and
`INVALID (plans/01: no spec and no skip flag)` → `fix 2026-10-16-nospec` (I4). With `built-on`
present on its plan, the first renders `plan 01 approved: blocked (spec not approved)` →
`approve spec` (C3).

A chain approved before this change carries no `built-on`, so its approved spec and live plans
report I3 and I5 until re-confirmed (§2, §8.4). That is intended: the author decided no
compatibility with earlier chains is required (intent, Constraints). A chain whose intent is
`done` or `dropped` is not checked.

## 4. Roadmap and milestone artifacts

Both are optional. A repository that has no `.claudestacks/sdlc/roadmaps/` directory and no
intent carrying a `milestone` key has no roadmap or milestone behaviour of any kind.

**Layout.**

```
.claudestacks/sdlc/
├── roadmaps/                        # optional; created on first use by the roadmap skill
│   └── <roadmap>/                   # one directory per roadmap; the engineer names it
│       ├── roadmap.md
│       ├── 01-<topic>.md            # one file per milestone; NN orders them
│       └── 02-<topic>.md
└── 2026-10-13-<topic>/              # chains stay flat at the chain root
    └── intent.md
```

- `<roadmap>` and `<topic>` are kebab-case. A repository may hold any number of roadmaps.
- A roadmap may not be named `plans`: `roadmaps/plans/NN-<topic>.md` would match the glob
  `distill` reads plans through, `.claudestacks/sdlc/*/plans/*.md`
  (`skills/distill/SKILL.md:50`).
- A milestone is identified by the reference `<roadmap>/<NN>`, for example `platform/01`.
- A milestone number is never reused within a roadmap; a new milestone takes the next free
  `NN`, the rule plans already follow (`references/artifact-chain.md:54-56`).
- Nothing in `roadmaps/` is ever deleted or renamed; a milestone that is no longer wanted is
  `dropped`.
- `setup` does not create `roadmaps/`.
- Within a roadmap directory, any entry other than `roadmap.md` and files matching
  `NN-<topic>.md` is ignored.

**Frontmatter.** Both artifacts carry `status` and `created`, and no other key.

**Body shapes** (added to `references/templates.md`):

```markdown
# Roadmap: <title>

## Vision

[where this body of work is going and why]

## Non-goals

[what this roadmap deliberately leaves out]
```

```markdown
# Milestone: <title>

## Goal

[the state of the world when this milestone is reached]

## Non-goals

[what this milestone deliberately leaves out]
```

Neither body holds a list of milestones, a list of chains, a progress figure, or a checklist
of finished work. A roadmap's milestones are the files beside it; a milestone's chains are the
intents that name it (§5).

**How this meets "one mechanism for every relation".** The intent asks that every relation be
declared in frontmatter and checked by the script. Three relations are declared in frontmatter
(`built-on`, `disproves`, `milestone`). Two are declared by path instead: a plan belongs to the
chain whose `plans/` directory holds it, as today, and a milestone belongs to the roadmap whose
directory holds it. Path is the stated exception to "in frontmatter"; it is not an exception to
the rest — all five are read by the one script and reported on the one board.

**States** (added to `references/artifact-chain.md` §7.1):

| Artifact | States |
|---|---|
| roadmap | `draft → approved → done`; `dropped` from `draft` or `approved`; `dropped → draft` |
| milestone | `draft → approved → done`; `dropped` from `draft` or `approved`; `dropped → draft` |

**Transitions** (added to §7.2):

| Transition | When | Flipped by |
|---|---|---|
| roadmap `— → draft` | file written | `roadmap` |
| roadmap `draft → approved` | the author approves it | `roadmap` |
| roadmap `approved → done` | roll-up (§6) | the skill running the roll-up |
| roadmap `→ dropped` | the author's instruction | `roadmap` |
| roadmap `dropped → draft` | the author un-drops it | `roadmap` |
| milestone `— → draft` | file written | `roadmap` (first milestones) or `milestone` |
| milestone `draft → approved` | the author approves it | `milestone` |
| milestone `approved → done` | roll-up (§6) | the skill running the roll-up |
| milestone `→ dropped` | the author's instruction | `milestone` |
| milestone `dropped → draft` | the author un-drops it | `milestone` |

- **Amending** a roadmap's or milestone's body leaves its status as it was, as amending an
  intent does (`skills/intent/SKILL.md:38-39`).
- **Un-dropping** always returns the artifact to `draft`; the author approves it again.
- **`done` is final**: a closed milestone or roadmap is not reopened, amended or dropped. Work
  that arrives after one closed becomes a simple chain or belongs to a new milestone.
- The two roll-up transitions join the existing mechanical pair that fires without a fresh
  approval question (`references/artifact-chain.md:157-159`).

**Status does not gate chain work.** A member chain moves through `design`, `plan` and
`execute` whatever its milestone's status.

## 5. Membership and progress

**The only link is one optional key on the intent** (added to `references/artifact-chain.md`
§6):

| Key | On | Value | Meaning |
|---|---|---|---|
| `milestone` | intent | `<roadmap>/<NN>` | this chain belongs to that milestone |

A chain belongs to at most one milestone. A chain with no `milestone` key is a **simple
chain**. Nothing else records membership: the milestone file does not list its chains.

**How the key changes.** `intent` writes it only when the author names a milestone (§8.3);
`milestone` writes it when parking scope or adopting a chain, and removes it when releasing one
(§8.2). No skill infers membership from a topic or a name, and a chain created by `intent`
with no milestone mentioned gets no key and no question.

A chain's directory never moves. `distill` globs `.claudestacks/sdlc/*/plans/*.md`
(`skills/distill/SKILL.md:50`) and the board scans one level
(`scripts/lib/status.lua:128-133`); both keep working because chains stay at the root.

**A member is as checked as any chain, and its key is checked too.** A `milestone` value that
resolves to no milestone makes the chain invalid (§7.4), and `execute` refuses an invalid chain
(§8.5). That is deliberate: membership is a recorded fact, and a broken one is reported rather
than guessed around. It is the one way a member chain behaves differently from a simple chain.

**Progress is derived, never stored.** For a milestone, the **members** are every chain whose
intent names it. Its progress is `N of M done`: `M` is the members whose intent is not
`dropped`, `N` is the members whose intent is `done`. For a roadmap, progress is
`N of M milestones done`: `M` is its milestone files whose status is not `dropped`, `N` is
those whose status is `done`.

**Unstarted work counts.** Work planned for a milestone and not yet begun exists as a parked
`draft` intent, so it is in `M` from the moment the milestone's scope is parked.

## 6. Walk-up and roll-up

The **chain walk-up** exists today: when a chain's plans are all settled with at least one
`done`, `execute` flips the intent `approved → done` (`skills/execute/SKILL.md:325-332`). Two
things change. It fires only for a chain that is complete in the sense of §3.3, so a chain
with a standing C1 or C2 keeps its intent `approved` until the spec or intent text is brought
up to date. And a missed walk-up now has a row and an entry point: the board lists the chain
as `chain complete` → `execute walk-up` (§7.1, closing P11), and `execute`, given a bare chain
reference whose row reads `chain complete`, performs the walk-up and the roll-up and nothing
else. Today a bare chain reference only prompts for a plan
(`skills/execute/SKILL.md:21-23`).

The **roll-up** closes milestones, and then their roadmap, when their work is finished. It is
defined once, in a new section of `references/artifact-chain.md`. It takes a roadmap name, and
it is idempotent — running it when nothing is ready changes nothing.

1. For each milestone of the roadmap whose status is `approved`, in number order: if every
   member's intent is `done` or `dropped`, with at least one `done`, flip the milestone
   `approved → done` and tell the author it closed.
2. If the roadmap's status is `approved`, and every milestone's status is `done` or `dropped`,
   with at least one `done`, flip the roadmap `approved → done` and tell the author it closed.

**When it runs.** As the last step of any interaction that could have made either condition
true, for the roadmap concerned:

| Event | Skill |
|---|---|
| a member's intent flips to `done` (chain walk-up) | `execute` |
| a member's intent is dropped | `intent` |
| a chain is released; a milestone is approved or dropped | `milestone` |
| a roadmap is approved | `roadmap` |
| the author asks for it, or the board's NEXT reads `roll up` | `milestone`, operation `roll up`, given a roadmap name or a milestone reference |

**A missed roll-up is visible.** The board reports `milestone complete` and `roadmap complete`
with NEXT `roll up` (§7.2, §7.3).

## 7. Board rendering

### 7.1 Chains

**A complete chain is now a row.** `M.render` stops collapsing a `chain complete` state into
the tail. The chain is listed with STATE `chain complete` and NEXT `execute walk-up`, and the
tail counts only chains whose intent is `done` or `dropped`. This replaces the behaviour of
P11, the test that pins it, and `references/artifact-chain.md:188-190`.

**Without any roadmap directory** the board keeps today's layout
(`scripts/lib/status.lua:306-335`): header, one row per open chain, an optional `⤷ inputs:`
line, the tail count. An **open chain** is one whose intent is `draft` or `approved`.

**With at least one roadmap directory** the same three columns are kept and rows are grouped:

```
CHAIN                             STATE                         NEXT
ROADMAP platform                  approved, 1 of 2 milestones done
MILESTONE platform/01-auth        done, 4 of 4 done
MILESTONE platform/02-billing     approved, 1 of 3 done
  2026-10-13-invoices             plan 01 approved: stale (spec changed)  plan
  2026-10-14-refunds              intent draft                  approve or drop
UNASSIGNED
  2026-10-15-fix-typo             intent approved               design
DONE/DROPPED: 6 done, 2 dropped (not listed)
```

- **Labels.** A roadmap row's first column is `ROADMAP <roadmap>`; a milestone row's is
  `MILESTONE <roadmap>/<file name without .md>`.
- **Order.** Roadmaps in directory-listing order; their milestones in number order; each
  milestone's open member chains in directory-listing order, indented two spaces.
- **Which milestone rows print.** Under a `draft` or `approved` roadmap, every milestone. Under
  a `done` or `dropped` roadmap, a milestone prints only when it is `draft` or `approved`, or
  has an open member chain. So every open member chain has a milestone row above it.
- **Members that are not open** are counted in their milestone's progress and in the tail, and
  not listed.
- **`UNASSIGNED`** lists every open simple chain, and every chain made invalid by its
  `milestone` value (§7.4), indented two spaces. The line is omitted when there is none.
- **Annotations.** A chain's `⤷ inputs:` line comes first, then any `⤷ milestone …` line, both
  indented as the `⤷ inputs:` line is today relative to its row
  (`scripts/lib/status.lua:326`). A milestone's `⤷ roadmap …` line follows its row the same
  way.
- `roadmaps` joins `prds` and `rfcs` in the scan's skip list (`scripts/lib/status.lua:17`),
  which removes the row shown in P2.

### 7.2 Milestone rows

| Milestone status | Condition | STATE | NEXT |
|---|---|---|---|
| `draft` | — | `draft, N of M done` | `approve or drop` |
| `approved` | `M` is 0 | `approved, 0 of 0 done` | `park scope` |
| `approved` | every member `done` or `dropped`, at least one `done` | `milestone complete` | `roll up` |
| `approved` | otherwise | `approved, N of M done` | empty |
| `done` | every member `done` or `dropped` | `done, N of M done` | empty |
| `done` | any member neither `done` nor `dropped` | `INVALID (done with open chains)` | `fix <roadmap>/<NN>` |
| `dropped` | — | `dropped` | empty |
| file unparseable, or any other status | — | `INVALID (<file>: <reason>)` | `fix <roadmap>/<NN>` |
| two files in one roadmap share a number | each of them | `INVALID (<file>: duplicate number NN)` | `fix <roadmap>/<NN>` |

### 7.3 Roadmap rows

| Roadmap status | Condition | STATE | NEXT |
|---|---|---|---|
| `draft` | — | `draft, N of M milestones done` | `approve or drop` |
| `approved` | `M` is 0 (no milestone file, or all `dropped`) | `approved, 0 of 0 milestones done` | `add milestone` |
| `approved` | every milestone `done` or `dropped`, at least one `done` | `roadmap complete` | `roll up` |
| `approved` | otherwise | `approved, N of M milestones done` | empty |
| `done` | every milestone `done` or `dropped` | `done, N of M milestones done` | empty |
| `done` | any milestone neither `done` nor `dropped` | `INVALID (done with open milestones)` | `fix <roadmap>` |
| `dropped` | — | `dropped` | empty |
| `roadmap.md` missing or unparseable, or any other status | — | `INVALID (roadmap.md: <reason>)` | `fix <roadmap>` |
| the directory is named `plans` | — | `INVALID (reserved name)` | `fix plans` |

### 7.4 Membership problems

These apply to every chain whose intent is `draft` or `approved`, in either layout.

| Condition | Reported as |
|---|---|
| the `milestone` value is not of the form `<roadmap>/<NN>`, or no milestone file has that roadmap and number | the chain renders `INVALID (intent.md: unknown milestone <value>)` → `fix <chain>` |
| the value matches two milestone files (duplicate number) | the chain renders `INVALID (intent.md: ambiguous milestone <value>)` → `fix <chain>` |
| the chain names a `dropped` milestone | under the chain's row: `⤷ milestone <roadmap>/<NN> is dropped — release this chain` |
| a `draft` or `approved` milestone sits under a `dropped` roadmap | under the milestone's row: `⤷ roadmap <roadmap> is dropped — drop this milestone` |

The two invalid results rank after I1 and before I2 in §3.1. In a repository with no roadmap
directory, a chain carrying a `milestone` key therefore renders the first row of this table in
the flat layout.

## 8. Skills

Every skill below resolves paths, keys and states from `references/artifact-chain.md`, flips
state only per its flip rule (`references/artifact-chain.md:147-150`), and never commits.

**The shared check.** Before acting, and again after flipping a state, a skill renders the
board — `sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"`, a reference Claude Code substitutes
when it loads the skill (P8, `:577`), or by hand per §8.6 when that prints nothing — and reads
the row it concerns. A refusal names the file, the condition as the board words it, and the
skill that clears it.

| Skill | Row it reads |
|---|---|
| `design`, `plan`, `execute` | the chain they were given |
| `intent`, on re-invocation for an existing chain | that chain; and its milestone's row when the intent carries `milestone` |
| `milestone` | the milestone it was given, and that milestone's roadmap |
| `roadmap`, on re-invocation | the roadmap it was given |

### 8.1 `roadmap` (new)

Creates a roadmap through a one-question-at-a-time dialogue: its name, its vision, its
non-goals, and its first milestones. It refuses the name `plans`. It writes
`roadmaps/<name>/roadmap.md` with `status: draft` and one `draft` milestone file per milestone
named, then asks whether to approve the roadmap. On re-invocation it approves, amends, drops
or un-drops an existing roadmap, per §4. Dropping a roadmap does not change its milestones;
the board flags the ones still open (§7.4). After approving a roadmap it runs the roll-up (§6).

### 8.2 `milestone` (new)

Works on one milestone, named by reference, or on one roadmap for `add` and `roll up`.

| Operation | Behaviour | Refused when |
|---|---|---|
| add | writes the next `NN-<topic>.md` in the roadmap, `status: draft` | the roadmap is `done` or `dropped` |
| approve | `draft → approved`, then the roll-up | the milestone is not `draft` |
| amend | rewrites body sections; status unchanged | the milestone is `done` |
| drop | `→ dropped`, then the roll-up | the milestone is `done` |
| un-drop | `dropped → draft` | the roadmap is `done` |
| park scope | for each piece of work the author lists, writes one new chain directory, named per `references/artifact-chain.md` §2, holding an `intent.md` with `status: draft` and the `milestone` key | the milestone is `done` or `dropped` |
| adopt | adds the `milestone` key to an existing chain's intent | the milestone is `done` or `dropped`; the chain already has a `milestone` key; the chain's intent is not `draft` or `approved` |
| release | removes the key from a member's intent, then the roll-up | the milestone is `done` |
| roll up | runs the roll-up (§6) for the roadmap | never |

Every refusal names the milestone's or roadmap's status. Moving a chain from one milestone to
another is a release followed by an adopt.

A **parked intent** uses the standard `intent.md` shape (`references/templates.md`). `Problem`
holds what the author said about that piece of work. `Affected systems`, `Desired outcome`,
`Constraints` and `Non-goals` each hold the one sentence
`Not explored yet — parked by milestone <roadmap>/<NN>.` The author completes it later through
`intent`'s existing amend mode (`skills/intent/SKILL.md:35-41`).

### 8.3 `intent` (changed)

- **Creating.** Writes `milestone` only when the author names a milestone, after checking it
  exists and is `draft` or `approved`. It asks no question about milestones otherwise.
- **Dropping.** After dropping an intent that carries `milestone`, it runs the roll-up (§6).
- **Un-dropping.** When the intent's milestone is `done`, it removes the `milestone` key as
  part of the un-drop and tells the author the revived chain is a simple chain, because a
  closed milestone takes no new work (§4).
- **Amending.** Before amending the body of an intent whose chain has an `approved` spec, or
  live plans on the spec-skip path, it tells the author the amendment will mark them stale. It
  then proceeds on the author's word.
- **Clearing `intent disproven by plan NN`.** On the spec-skip path this condition ends when
  the intent's body is amended to correct what was disproven; that is this skill's amend mode.
  The plans then report C4 and go to `plan`.

### 8.4 `design` and `plan` (changed)

| Skill | Row for its chain | Behaviour |
|---|---|---|
| `design` | C1 `spec stale (intent changed)`, or I3 `spec.md: missing built-on` | offers re-confirmation (§2); on a no, the existing redesign path (`skills/design/SKILL.md:221-224`) |
| `design` | C2 `spec disproven by plan NN` | the existing redesign path; the new spec's text ends the condition |
| `design` | writing or approving a spec | writes `built-on` per §2 |
| `plan` | C1, C2, C3, or any invalid result other than I5 | refuses; names `design` for C1, C3 and `spec disproven`, `intent` for `intent disproven`, and the file for an invalid result |
| `plan` | C4 `plan NN …: stale (…)`, or I5 `plans/NN: missing built-on` | for each such plan, offers re-confirmation (§2) or supersession |
| `plan` | writing or approving a plan | writes `built-on` per §2 |

### 8.5 `execute` (changed)

- **Refuses to start or resume a plan** when its chain's row is an invalid result or reports
  C1, or when C3 or C4 holds for that plan. This is stricter than its existing warning for an
  unmet `depends-on` (`skills/execute/SKILL.md:49-51`), which is unchanged.
- **While C2 stands** — either wording — it refuses to start or resume every plan of the chain
  except the plan whose `disproves` raised it, which may finish its run. That includes a
  `draft` plan it is asked to run.
- **Approving a `draft` plan** by being asked to run it follows §2.
- It writes `disproves` per §2.
- **Walk-up.** It flips the intent to `done` only for a complete chain (§3.3), then runs the
  roll-up (§6). Given a bare chain reference whose row reads `chain complete`, it does exactly
  that.

### 8.6 `status` (changed)

Unchanged in shape: it prints the script's board, or derives the same board by hand when
`airsl` is absent (`skills/status/SKILL.md:12-23`). Its fallback instructions gain the rules
of §3 and §7 by reference to `references/artifact-chain.md`, and compute each fingerprint by
running `sh "${CLAUDE_PLUGIN_ROOT}/scripts/fingerprint.sh" <file>` (§2).

### 8.7 Unchanged

`setup`, `distill`, `triage`, and the three agents. A triage-sourced intent is a simple chain
until `milestone` adopts it.

## 9. Session-start hook

The plugin gains its first hook (P9): `hooks/hooks.json`, wrapped in the top-level `"hooks"`
key (P8), declaring one `SessionStart` group with no matcher, so it fires for every way a
session starts (P7, `:207`, `:1190-1194`):

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command",
          "command": "sh \"${CLAUDE_PLUGIN_ROOT}/scripts/attention.sh\"" } ] }
    ]
  }
}
```

`scripts/attention.sh` resolves `airsl` the way `scripts/status.sh` does
(`scripts/status.sh:11-24`) and runs `scripts/attention.lua` under
`--fail-open --policy confined --allow-read /`, the grant the sibling plugin's hook uses (P6).
It always exits 0 and prints nothing when `airsl` is not found.

`scripts/attention.lua` takes the chain root from the payload's `cwd` (P6; P7 `:612-613`),
falling back to the process directory when the payload is absent, and prints plain text, which
Claude Code adds to the session's context (P7, `:810`). **Whether that text also reaches
subagents is not verified, and nothing here depends on it:** subagents are spawned by skills,
and the skills run the shared check (§8).

```
claudestacks-sdlc: 3 open, 1 need attention — full board: /claudestacks-sdlc:status
  2026-10-13-invoices             plan 01 approved: stale (spec changed)  plan
```

- **No chain root** — it prints nothing.
- **First line** — always printed when a chain root exists, in exactly that form: the number
  of open chains (§7.1), then the number of rows needing attention.
- **A row needs attention** when its STATE holds `INVALID`, `stale`, `blocked`, `disproven` or
  `complete`, when it names a plan as `executing`, or when it carries a `⤷ milestone …` or
  `⤷ roadmap …` line. That covers chain, milestone and roadmap rows.
- **Rows** are printed exactly as the board renders them, each followed by its `⤷ milestone …`
  or `⤷ roadmap …` line.
- **Size** — output is held under 9,000 characters, below the 10,000-character cap (P7,
  `:996`): rows are printed until the next would cross the limit, then one line states how
  many were left out.
- **Speed** (P7, `:1184`) — the script reads each chain's frontmatter once and hashes at most
  two bodies per chain whose intent is `approved`: the intent's and the spec's. Chains whose
  intent is `done` or `dropped` cost one frontmatter read. Its wall time on this repository's
  chain root is recorded in the walkthrough (§11) and must be under one second.

Without `airsl` there is no session-start line; the `status` skill's fallback is unaffected.

Listing every `executing` plan at every session start answers one of the gaps the author
reported (intent, Why now): a status that was never flipped after the work ended. Nothing
recorded on disk distinguishes that from a plan still in progress, so it is kept in view
rather than detected.

## 10. Error handling

- **The board never guesses.** An unreadable or unparseable roadmap or milestone file, an
  unknown status, or an unresolvable `milestone` value is rendered `INVALID` with the file and
  reason, as chains are today (`scripts/lib/status.lua:74-75`). One bad roadmap does not hide
  the others.
- **Nothing is repaired automatically.** A reported condition is cleared only by the owning
  skill on the author's word (§2, §8), or by the author fixing the file.
- **A refusal names its exit.** Every refusal in §8 states the file, the condition as the
  board words it, and the skill that clears it. Every condition of §3 and §7 has one: I3 and
  C1 → `design`; I5 and C4 → `plan`; C2 → `design`, or `intent` on the spec-skip path; C3 →
  `design`; `milestone complete` and `roadmap complete` → `milestone`; `chain complete` →
  `execute`; every other invalid result → the named file.
- **The hook cannot break a session.** Every path of `attention.sh` exits 0, and the script
  runs fail-open, as `status.sh` does (`scripts/status.sh:5-7`, `:26-30`).

## 11. Testing

Lua behaviour is tested under `airsl test`, in files that return a table of named functions
(P10), run by `cargo make plugins-test`; `cargo make plugins-check` compiles every Lua file
including `scripts/attention.lua`. Each test is seen failing before the code that satisfies it
is written.

The library is split so each part is testable alone:

| File | Responsibility | Tests |
|---|---|---|
| `scripts/lib/fingerprint.lua` (new) | body extraction and hashing | `scripts/fingerprint_test.lua` (new) |
| `scripts/lib/roadmap.lua` (new) | scanning `roadmaps/`, membership, progress, milestone and roadmap rows | `scripts/roadmap_test.lua` (new) |
| `scripts/lib/status.lua` | chain derivation including §3, board and attention rendering | `scripts/status_test.lua` |
| `scripts/attention.lua` (new) | hook entry point | compiled by `plugins-check`; behaviour tested through the library |
| `scripts/fingerprint.sh`, `scripts/attention.sh` (new) | shell entry points | the fingerprint gate below; the walkthrough |

What the tests must pin:

- **Fingerprint.** The first six cases of P5, asserting the literal values recorded there;
  plus missing and unterminated frontmatter yielding no fingerprint.
- **The fingerprint gate.** The `plugins-test` task (`Makefile.toml:143-151`) also runs
  `scripts/fingerprint.sh` over the eight cases of P5, generated by the task, and fails unless
  each prints the value and exit status recorded in P5. Because the Lua workflow runs that
  task on `ubuntu-latest` (P10), this is what proves, or disproves, the Linux half of P5. The
  chain is not finished until that job has been seen green.
- **Sync rules.** One test per row I2–I5 and C1–C4; the order among invalid results; C3 taking
  the plan over C4; every step of the NEXT order, including that a standing C2 never yields
  `execute NN`; a `disproves` value that no longer matches (no condition); C2 read from a
  `done` plan; `draft` and settled plans ignored by I4, I5, C3 and C4; a chain whose intent is
  not `approved` unchecked; STATE composition with and without plans, with C1 and C2 together,
  and with the `(triage)` tag; a chain with every plan settled and a standing C2 not being
  `chain complete`.
- **Roadmaps and milestones.** Every row of §7.2, §7.3 and §7.4; progress counting with
  dropped and parked members; which milestone rows print under each roadmap status; ordering;
  labels and annotation order; a root with no roadmap directory rendering in today's layout;
  `roadmaps` no longer rendering as a chain (P2).
- **Attention.** No chain root; nothing needing attention; each trigger, including both
  annotation lines; the first line's form; the size limit.
- **Existing tests.** The 31 tests in `scripts/status_test.lua` keep passing with two kinds of
  change. Fixtures holding an `approved` spec or a live plan gain `built-on`, set to the
  fingerprint of the fixture authority's body (the helper writes `# body\n`,
  `scripts/status_test.lua:23`). And the test named in P11 is rewritten to assert the new
  behaviour of §7.1: the complete chain is a row, and the tail does not count it.

Skill behaviour is prose and has no unit test. It is verified by a recorded walkthrough on a
throwaway chain root, with the real board output pasted into the executing plan: the two
chains of P1 rendering as §3.5 states; an intent edited after its spec was approved; a spec
superseded under an approved plan; a draft plan whose spec changed before approval; a
`disproves` marker holding back a sibling plan and the chain's walk-up, and clearing when the
spec changes; a missed walk-up shown and then performed; a milestone parked, worked and closed
by roll-up; a closed milestone refusing new work; and the hook's output and wall time for that
root and for this repository's.

## 12. Delivery

- **Order.** The sync mechanism (§2, §3, the chain walk-up of §6, the skill changes of
  §8.3–8.6) is built before roadmaps and milestones (§4, §5, the roll-up of §6, §7.2–7.4,
  §8.1–8.2), which report through it (intent, Constraints). The hook (§9) comes after both.
- **References.** `references/artifact-chain.md` gains the three keys, the two artifacts'
  paths, states and transitions, the roll-up procedure, and the board rules of §3 and §7,
  replacing the collapse rule at `:188-190`; `references/templates.md` gains the two body
  shapes and the parked-intent sentence. They stay the single authority the skills and the
  fallback read.
- **Documentation.** `plugins/claudestacks-sdlc/README.md`; the plugin description in
  `plugins/claudestacks-sdlc/.claude-plugin/plugin.json` and at
  `.claude-plugin/marketplace.json:17`; the plugin table at `CLAUDE.md:229`; `README.md:44`;
  and the Lua test count at `CLAUDE.md:200`.
- **Version.** `plugins/claudestacks-sdlc/.claude-plugin/plugin.json` moves from `0.1.2` to
  `0.2.0`.
- **This chain's own artifacts.** This spec and the plans written from it carry `built-on`,
  computed with the pipeline of §2, so that this chain does not report I3 or I5 when the check
  it builds first runs against it.

## 13. Non-goals

- Nesting chains inside a roadmap or milestone directory, or moving a chain's directory.
- Making a roadmap or milestone a required stage before `intent`.
- Dates, deadlines, estimates and velocity.
- Syncing with GitHub milestones, issues or projects.
- Migrating existing material: no chain or outside document is converted, and no `built-on`
  is back-filled into chains other than this one.
- Cross-chain dependencies; `depends-on` stays a plan-only, within-chain key.
- Judging whether two artifacts agree in meaning. The check compares fingerprints, states and
  declared relations; prose against prose stays with `artifact-reviewer`.
- Repairing a disagreement automatically.
- Detecting work that was abandoned with nothing recorded on disk (§9).
- Reopening a `done` milestone or roadmap.
- Checking `draft` artifacts on the board; a draft's `built-on` is compared only at approval
  (§2).
- Provenance keys (`derived-from-prd`, `derived-from-rfc`) on roadmaps and milestones.
- A hook on any event other than `SessionStart`, including one that would carry the board to
  subagents, and any hook that blocks.
- Splitting this work into two chains. The author chose to carry both objectives in one
  (intent, opening note).
