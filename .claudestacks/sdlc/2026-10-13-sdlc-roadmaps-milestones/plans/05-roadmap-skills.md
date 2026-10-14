---
status: approved
created: 2026-10-14
depends-on: [03, 04]
built-on: a5a235079e03
---

# Roadmap Skills Implementation Plan

**Goal:** A roadmap, its milestones, and each chain's membership of a milestone can be created, changed and closed through the plugin's skills.

**Architecture:** Two new dialogue skills own the two new artifacts: `roadmap` writes `roadmaps/<name>/roadmap.md` with its first milestone files, `milestone` owns everything about one milestone, including the `milestone` key on member intents. `intent` and `execute` gain only the edges that touch membership: the key at creation, and the roll-up after a drop or a chain walk-up. The roll-up procedure itself, the paths, the states and the board rows are defined once in `references/artifact-chain.md` by plan 04; every skill here cites that file rather than restating it.

**Tech Stack:** Markdown skill files under `plugins/claudestacks-sdlc/skills/`; the board (`scripts/status.sh`) as extended by plans 02 and 04; `cargo make plugins` as the gate.

**Content authority:** spec §8.1, §8.2, §8.3 (Creating, Dropping, Un-dropping), §8.5 (the roll-up after the walk-up), §6 ("When it runs"), the shared-check rows of §8 for `intent`, `milestone` and `roadmap`, and the roadmap scenarios of the §11 walkthrough. §4 and §5 supply the rules the two new skills enforce.

---

## File structure

```
plugins/claudestacks-sdlc/skills/roadmap/SKILL.md     — [create] creates a roadmap with its first milestones; approves, amends, drops, un-drops one
plugins/claudestacks-sdlc/skills/milestone/SKILL.md   — [create] add, approve, amend, drop, un-drop, park scope, adopt, release, roll up
plugins/claudestacks-sdlc/skills/intent/SKILL.md      — [modify] the optional `milestone` key; roll-up after a drop; key removed on un-drop under a closed milestone; the milestone's row in the sync check
plugins/claudestacks-sdlc/skills/execute/SKILL.md     — [modify] the roll-up after a chain walk-up
```

Claude Code discovers skills from the `skills/` directory; `plugins/claudestacks-sdlc/.claude-plugin/plugin.json` lists none, so the two new directories need no registration. The README, the plugin description and the version are plan 07's.

This plan touches no file under `references/` and no Lua. It assumes plan 03 has already added the `Sync check on re-invocation` section to `skills/intent/SKILL.md` and rewritten the `State walk-up` section of `skills/execute/SKILL.md`; Tasks 4 and 5 quote that text as plan 03 leaves it.

**How every task is verified.** Skill text has no unit test. Each task's red step shows a file or a phrase absent; its green step shows it present, with `grep -c` printing `1`. The behaviour is proven once, by the walkthrough in Task 6.

**Locating an edit.** Each edit task quotes the existing text it replaces, verbatim. Find it by that text; line numbers are not given for passages plan 03 moves.

**Paths in commands** are relative to the repository root.

**Decisions this plan makes where the spec is silent.** Each is reported to the author at the plan's approval gate:

- `intent`, asked to create a chain under a milestone that does not exist or is not `draft` or `approved`, writes no key, reports the path or status, and asks. (Spec §8.3 says only that it checks.)
- `roadmap` and `milestone` refuse to act on a row that reads `INVALID`, naming the file and reason. `milestone`'s `roll up` is still allowed: the spec says it is never refused.
- `roadmap` has no refusal table in spec §8.1. From the states of spec §4: approve only from `draft`; amend refused when `done`; drop refused when `done` or already `dropped`; un-drop only from `dropped`.
- For each first milestone, `roadmap` asks for a title, a goal and non-goals. (Spec §8.1 says "its first milestones" and no more.)
- `milestone`'s `add` takes the next number after the highest existing milestone file, never a freed one.
- `park scope`, when the chain directory it would create already exists, asks for a different topic.
- **The walkthrough records the board, not the skills in action**, for the reason given in plan 03's decisions list. Its last step writes by hand the state the `milestone` skill's refusal prevents, to show the board reports it; no refusal is observed being spoken by a skill. The author may want a live pass after reinstalling the plugin.

### Task 1 — Write the roadmap skill

**Files:**
- Create `plugins/claudestacks-sdlc/skills/roadmap/SKILL.md`

**Steps:**

1. Confirm the skill does not exist:

   ```
   $ test -e plugins/claudestacks-sdlc/skills/roadmap/SKILL.md; echo $?
   1
   ```

2. Create `plugins/claudestacks-sdlc/skills/roadmap/SKILL.md` with exactly this content:

   `````markdown
   ---
   name: roadmap
   description: Use when work is larger than one chain and needs a named direction above it — creates a roadmap and its first milestones under .claudestacks/sdlc/roadmaps/, or revisits an existing roadmap to approve, amend, drop, or un-drop it. Optional; a single chain never needs a roadmap.
   ---

   # Roadmap

   Give a body of work a home above the chain. A roadmap is one file saying where the work
   is going; its milestones are the files beside it; the chains that belong to a milestone
   say so in their own intent. Nothing here is required: a repository can run every chain it
   ever has without a roadmap, and no other skill asks for one.

   A roadmap never records progress. No file holds a count, a percentage, a list of
   milestones, a list of chains, or a checklist of finished work. The status board counts
   all of that from the chains each time it runs, which is why every reader gets the same
   answer.

   ## Shared contract

   Resolve every path, key, state and transition from
   `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`, and write files in the body shapes
   `${CLAUDE_PLUGIN_ROOT}/references/templates.md` defines for a roadmap and a milestone.
   Lazy-create `.claudestacks/sdlc/roadmaps/` and the roadmap's own directory before the
   first write; `/claudestacks-sdlc:setup` does not create them. Never commit. Flip `status`
   only per the transitions in `artifact-chain.md`, only as the last step of the interaction
   that earns it, only on the user's explicit word. Nothing under `roadmaps/` is ever
   deleted or renamed.

   ## Layout

   ```
   .claudestacks/sdlc/roadmaps/
   └── <roadmap>/                 # one directory per roadmap; the user names it
       ├── roadmap.md
       ├── 01-<topic>.md          # one file per milestone; NN orders them
       └── 02-<topic>.md
   ```

   `<roadmap>` and `<topic>` are kebab-case. A repository may hold any number of roadmaps.
   Both kinds of file carry `status` and `created` in frontmatter, and no other key.

   ## Creating a roadmap

   Ask one question at a time, never a battery:

   1. **Its name.** Kebab-case. Refuse `plans`, and say why: `roadmaps/plans/NN-<topic>.md`
      would be read as a chain's plan by the `distill` skill. If
      `.claudestacks/sdlc/roadmaps/<name>/` already exists, this is a re-invocation (below),
      not a creation.
   2. **Its vision** — where this body of work is going and why.
   3. **Its non-goals** — what it deliberately leaves out.
   4. **Its first milestones**, in the order they should be numbered. For each one, ask its
      title, its goal — the state of the world when it is reached — and what it leaves out.
      "None yet" is a valid answer: milestones can be added later with the `milestone`
      skill.

   A milestone states a goal, never a date, a deadline or an estimate.

   Then write:

   - `roadmaps/<name>/roadmap.md`, with `status: draft`, a `# Roadmap: <title>` heading,
     and the `## Vision` and `## Non-goals` sections;
   - one `roadmaps/<name>/NN-<topic>.md` per milestone named, numbered `01` upward in the
     order given, each with `status: draft`, a `# Milestone: <title>` heading, and the
     `## Goal` and `## Non-goals` sections.

   Then ask the user directly whether to approve the roadmap now or leave it `draft`.
   `draft → approved` happens only on an explicit yes. Approving a roadmap does not approve
   its milestones: each is approved through the `milestone` skill.

   ## Re-invocation

   Before acting on an existing roadmap, render the board and read that roadmap's row:

       sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"

   When that prints nothing, `airsl` is not installed: derive the row by hand, the way the
   `status` skill's fallback does. Do the same again after every `status` flip this skill
   makes, and tell the user what the row reads then.

   When the row reads `INVALID (…)`, refuse: name the file and the reason exactly as the
   board words them. The user fixes the file; this skill does not repair it.

   | Operation | Does | Refused when |
   |---|---|---|
   | approve | `draft → approved`, then the roll-up (below) | the roadmap is not `draft` |
   | amend | rewrites `## Vision` or `## Non-goals`; the status stays as it was | the roadmap is `done` |
   | drop | `draft → dropped` or `approved → dropped` | the roadmap is `done` or already `dropped` |
   | un-drop | `dropped → draft`; the user approves it again | the roadmap is not `dropped` |

   Every refusal names the file and the status it found.

   **Dropping a roadmap does not change its milestones.** The board flags each one still
   `draft` or `approved` with `⤷ roadmap <roadmap> is dropped — drop this milestone`. After
   the drop, tell the user which milestones those are, and that the `milestone` skill is
   what drops them.

   **`done` is final.** A closed roadmap is not reopened, amended or dropped. Work that
   arrives after it closed belongs to a new roadmap, or needs none.

   ## Roll-up

   After approving a roadmap, run the roll-up for it as the last step of the interaction.
   The procedure is defined once, in `artifact-chain.md`: it closes each `approved`
   milestone whose chains are all finished, then the roadmap once its milestones are. It is
   idempotent — when nothing is ready it changes nothing — and it flips without a fresh
   approval question, because each flip is a consequence of state already earned on the
   chains. Tell the user each thing it closed.

   A roadmap the board shows as `approved, 0 of 0 milestones done` has NEXT `add milestone`:
   that is the `milestone` skill's `add` operation.
   `````

3. Confirm it is in place:

   ```
   $ grep -c '^name: roadmap$' plugins/claudestacks-sdlc/skills/roadmap/SKILL.md
   1
   $ grep -c 'Refuse `plans`, and say why' plugins/claudestacks-sdlc/skills/roadmap/SKILL.md
   1
   ```

4. Commit `feat(repo): add the sdlc roadmap skill`.

### Task 2 — Write the milestone skill

**Files:**
- Create `plugins/claudestacks-sdlc/skills/milestone/SKILL.md`

**Steps:**

1. Confirm the skill does not exist:

   ```
   $ test -e plugins/claudestacks-sdlc/skills/milestone/SKILL.md; echo $?
   1
   ```

2. Create `plugins/claudestacks-sdlc/skills/milestone/SKILL.md` with exactly this content:

   `````markdown
   ---
   name: milestone
   description: Use to work on one milestone of a roadmap — add it, approve, amend, drop or un-drop it, park its unstarted work as draft intents, adopt or release a chain, or roll finished milestones and their roadmap up to done. Invoke with a milestone reference such as platform/01, or with a roadmap name for add and roll up.
   ---

   # Milestone

   A milestone is a goal inside a roadmap, reached through chains. It is one file,
   `roadmaps/<roadmap>/NN-<topic>.md`, stating the goal. The chains working toward it say so
   in their own intent, with the frontmatter key `milestone: <roadmap>/<NN>`. This skill is
   the only place a milestone's status changes by hand and, with `intent`, the only place
   that key is written or removed.

   Milestones are optional. A chain with no `milestone` key is a simple chain and needs
   nothing from this skill.

   A milestone never records progress: its file holds no list of chains, no count and no
   checklist. The board counts `N of M done` from the member intents each time it runs.

   ## Shared contract

   Resolve every path, key, state and transition from
   `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`, and write files in the body shapes
   `${CLAUDE_PLUGIN_ROOT}/references/templates.md` defines. Never commit. Flip `status` only
   per the transitions in `artifact-chain.md`, only as the last step of the interaction that
   earns it, only on the user's explicit word — the roll-up below is the one exception.
   Nothing under `roadmaps/` is ever deleted or renamed, and no chain directory ever moves:
   joining, leaving or switching milestones changes one frontmatter key and nothing else.

   ## Input

   A milestone reference `<roadmap>/<NN>`, for example `platform/01`. It resolves to the one
   file matching `.claudestacks/sdlc/roadmaps/<roadmap>/<NN>-*.md`.

   - **No match** — report the pattern you looked for and ask for a correction. Never guess
     a neighbouring milestone.
   - **Two matches** — refuse. Two files share a number, the board reads
     `INVALID (<file>: duplicate number NN)` for each, and the user fixes the files.

   `add` and `roll up` take a roadmap name instead; `roll up` also accepts a milestone
   reference and uses its roadmap.

   ## Check before acting

   Render the board and read two rows — the milestone's, and its roadmap's:

       sh "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"

   When that prints nothing, `airsl` is not installed: derive the rows by hand, the way the
   `status` skill's fallback does. Do the same again after every `status` flip or
   membership change this skill makes, and tell the user what the rows read then.

   When either row reads `INVALID (…)`, refuse every operation except `roll up`: name the
   file and the reason exactly as the board words them. The user fixes the file. A line
   under the milestone's row reading `⤷ roadmap <roadmap> is dropped — drop this milestone`
   means its roadmap was dropped while it stayed open: say so, and offer `drop`.

   ## Operations

   | Operation | Does | Refused when |
   |---|---|---|
   | add | writes the next `NN-<topic>.md` in the roadmap, `status: draft` | the roadmap is `done` or `dropped` |
   | approve | `draft → approved`, then the roll-up | the milestone is not `draft` |
   | amend | rewrites `## Goal` or `## Non-goals`; the status stays as it was | the milestone is `done` |
   | drop | `→ dropped`, then the roll-up | the milestone is `done` |
   | un-drop | `dropped → draft`; the user approves it again | the roadmap is `done` |
   | park scope | writes one new chain per piece of work the user lists, each a `draft` intent carrying the `milestone` key | the milestone is `done` or `dropped` |
   | adopt | adds the `milestone` key to an existing chain's intent | the milestone is `done` or `dropped`; the chain already has a `milestone` key; the chain's intent is not `draft` or `approved` |
   | release | removes the `milestone` key from a member's intent, then the roll-up | the milestone is `done` |
   | roll up | runs the roll-up for the roadmap | never |

   Every refusal names the milestone's or the roadmap's file and the status it found.
   Moving a chain from one milestone to another is a `release` followed by an `adopt`.

   **add.** Ask, one question at a time, the milestone's title, its goal — the state of the
   world when it is reached — and what it leaves out. A milestone states a goal, never a
   date, a deadline or an estimate. The new file takes the next free number in the roadmap:
   one more than the highest `NN` any file there carries, whatever that file's status. A
   number is never reused.

   **approve, drop, un-drop.** Each needs the user's explicit word. A milestone's status
   does not gate chain work: a member chain moves through `design`, `plan` and `execute`
   whatever its milestone's status.

   ## Parking scope

   Work planned for a milestone and not yet begun is parked as a `draft` intent, so the
   board counts it from the moment it is named and the milestone cannot read as finished
   while it waits. Ask the user for the pieces of work, then for each one write a new chain
   directory, named `YYYY-MM-DD-<kebab-topic>` with today's date as `artifact-chain.md`
   prescribes, holding this `intent.md`:

   ````markdown
   ---
   status: draft
   created: <YYYY-MM-DD>
   milestone: <roadmap>/<NN>
   ---

   # Intent: <title>

   ## Problem

   [what the user said about this piece of work]

   ## Affected systems

   Not explored yet — parked by milestone <roadmap>/<NN>.

   ## Desired outcome

   Not explored yet — parked by milestone <roadmap>/<NN>.

   ## Constraints

   Not explored yet — parked by milestone <roadmap>/<NN>.

   ## Non-goals

   Not explored yet — parked by milestone <roadmap>/<NN>.
   ````

   The four parked sections hold that one sentence exactly, with the real reference in
   place of `<roadmap>/<NN>`. Do not explore the problem here and do not approve the
   intent: the user completes and approves it later through the `intent` skill's amend
   mode. If a chain directory of that name already exists, ask for a different topic rather
   than write into it.

   ## Membership

   - A chain belongs to at most one milestone. `adopt` refuses a chain that already has
     the key; release it first.
   - Membership is a recorded fact. Never adopt a chain because its topic or name looks
     related — only on the user naming the chain.
   - `adopt` and `release` edit frontmatter only. A fingerprint covers an artifact's body,
     so neither marks a spec or a plan stale.
   - A line under a chain's row reading
     `⤷ milestone <roadmap>/<NN> is dropped — release this chain` is cleared by `release`.

   ## Roll-up

   The roll-up closes milestones, and then their roadmap, when their work is finished. Its
   procedure is defined once, in `artifact-chain.md`; follow it there. It takes a roadmap,
   it is idempotent — when nothing is ready it changes nothing — and it flips without a
   fresh approval question, because each flip is a consequence of state already earned on
   the chains. Tell the user each thing it closed.

   Run it for the milestone's roadmap as the last step of `approve`, `drop` and `release`,
   and whenever the user asks or the board's NEXT reads `roll up`. A milestone the board
   shows as `milestone complete`, or a roadmap it shows as `roadmap complete`, is waiting
   for exactly this.

   ## Closed is final

   A `done` milestone is not reopened, amended, dropped or given new work: `amend`, `drop`,
   `park scope`, `adopt` and `release` all refuse it. Say so plainly, and name the way
   forward: work that arrives after a milestone closed becomes a simple chain, or belongs
   to a new milestone added with `add`.
   `````

3. Confirm it is in place:

   ```
   $ grep -c '^name: milestone$' plugins/claudestacks-sdlc/skills/milestone/SKILL.md
   1
   $ grep -c '^Not explored yet — parked by milestone <roadmap>/<NN>.$' plugins/claudestacks-sdlc/skills/milestone/SKILL.md
   4
   ```

4. Commit `feat(repo): add the sdlc milestone skill`.

### Task 3 — Teach intent the optional milestone key

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/intent/SKILL.md`

**Steps:**

1. Confirm the section is absent:

   ```
   $ grep -c '^## Milestones$' plugins/claudestacks-sdlc/skills/intent/SKILL.md
   0
   ```

2. Replace these lines (the end of the `Spec-skip` section and the heading after it; `skills/intent/SKILL.md:82-84` at commit `55df7cf`):

   ````text
   approach, or anything the multi-scope check flagged is not offered the skip.

   ## Output
   ````

   with:

   ````text
   approach, or anything the multi-scope check flagged is not offered the skip.

   ## Milestones

   A chain may belong to one milestone, recorded as `milestone: <roadmap>/<NN>` in the
   intent's frontmatter — for example `milestone: platform/01`. Roadmaps and milestones are
   optional (`${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`), and most chains have
   none: a chain with no `milestone` key is a simple chain.

   - **Never ask.** Write the key only when the user names a milestone for this chain. When
     they name none, write no key and ask no question about milestones — not even in a
     repository that has roadmaps. Never infer membership from a topic or a name.
   - **Check it before writing it.** When the user names one, find the milestone file
     `.claudestacks/sdlc/roadmaps/<roadmap>/<NN>-<topic>.md` and read its `status`. Write
     the key only when the file exists and its status is `draft` or `approved`. Otherwise
     write no key: report the path you looked for, or the status you found, and ask the
     user how to proceed. A `done` milestone takes no new work.
   - **Dropping a member.** After dropping an intent that carries `milestone`, run the
     roll-up for that milestone's roadmap as the last step. The procedure is defined in
     `artifact-chain.md`; dropping a milestone's last open chain can close the milestone.
   - **Un-dropping a member of a closed milestone.** When the intent being un-dropped names
     a milestone whose status is `done`, remove the `milestone` key in the same edit and
     tell the user the revived chain is now a simple chain: a closed milestone takes no new
     work.

   Adopting an existing chain into a milestone, releasing one, and parking a milestone's
   unstarted work are the `milestone` skill's.

   ## Output
   ````

3. Confirm the section is present:

   ```
   $ grep -c '^## Milestones$' plugins/claudestacks-sdlc/skills/intent/SKILL.md
   1
   ```

4. Commit `feat(repo): let an sdlc intent name its milestone`.

### Task 4 — List the key in intent's output and read the milestone's row

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/intent/SKILL.md`

**Steps:**

1. Confirm both new passages are absent:

   ```
   $ grep -c 'optional `milestone` (Milestones, above)' plugins/claudestacks-sdlc/skills/intent/SKILL.md
   0
   $ grep -c 'read that milestone' plugins/claudestacks-sdlc/skills/intent/SKILL.md
   0
   ```

2. In the `Output` section, replace these two lines (`skills/intent/SKILL.md:87-88` at commit `55df7cf`):

   ````text
   is created) in the frontmatter and body shape from `templates.md`: `status`, `created`, the optional
   provenance lists, optional `source`, optional `spec: skipped`, and body sections Problem, Affected
   ````

   with:

   ````text
   is created) in the frontmatter and body shape from `templates.md`: `status`, `created`, the optional
   provenance lists, optional `source`, optional `spec: skipped`, optional `milestone` (Milestones, above),
   and body sections Problem, Affected
   ````

3. In the `Sync check on re-invocation` section plan 03 added, replace its closing paragraph:

   ````text
   Any other condition on the row is not this skill's to clear. Say what the row reads and
   carry on with what the user asked.
   ````

   with:

   ````text
   Any other condition on the row is not this skill's to clear. Say what the row reads and
   carry on with what the user asked.

   When the intent carries `milestone`, read that milestone's row as well. A line under the
   chain's row reading `⤷ milestone <roadmap>/<NN> is dropped — release this chain` means
   the chain still names a dropped milestone: say so, and name the `milestone` skill's
   `release` as what clears it. A row reading
   `INVALID (intent.md: unknown milestone <value>)` or
   `INVALID (intent.md: ambiguous milestone <value>)` means the key resolves to no single
   milestone: name the file and the value, and leave the correction to the user.
   ````

4. Confirm both passages are present:

   ```
   $ grep -c 'optional `milestone` (Milestones, above)' plugins/claudestacks-sdlc/skills/intent/SKILL.md
   1
   $ grep -c 'read that milestone' plugins/claudestacks-sdlc/skills/intent/SKILL.md
   1
   ```

5. Commit `feat(repo): show an sdlc intent its milestone's row`.

### Task 5 — Run the roll-up after a chain walk-up

**Files:**
- Modify `plugins/claudestacks-sdlc/skills/execute/SKILL.md`

**Steps:**

1. Confirm the new text is absent:

   ```
   $ grep -c 'Then the roll-up' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   0
   ```

2. In the `State walk-up` section as plan 03 rewrote it, replace its last bullet:

   ````text
   - **Other plans remain `draft`, `approved`, or `executing`.** Leave the intent as is and
     say what is still open.
   ````

   with:

   ````text
   - **Other plans remain `draft`, `approved`, or `executing`.** Leave the intent as is and
     say what is still open.

   **Then the roll-up.** When the walk-up flipped the intent to `done` and that intent
   carries a `milestone` key, run the roll-up for the milestone's roadmap as the last step.
   Its procedure is defined once, in `${CLAUDE_PLUGIN_ROOT}/references/artifact-chain.md`:
   it closes each `approved` milestone whose chains are all finished, then the roadmap once
   its milestones are. It is idempotent, and it flips without a fresh approval question —
   a consequence of state already earned on the chains. Tell the user each thing it closed.
   An intent with no `milestone` key is a simple chain: there is nothing to roll up.
   ````

3. Confirm the new text is present:

   ```
   $ grep -c 'Then the roll-up' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   1
   ```

4. Commit `feat(repo): roll a milestone up when sdlc execute completes its last chain`.

---

**Checkpoint A — pause here.** Run the gate once and show its output:

```
$ cargo make plugins
```

Expected: `airsl check plugins` reports no error, and the `airsl test` summary line ends `0 failed`, with the same passed count it had before Task 1 (this plan changes no Lua). Present the two new skill files and the two edited ones, and wait for "continue" before the walkthrough: it is the only verification this skill text gets.

---

### Task 6 — Record the roadmap walkthrough

This task changes no repository file. It builds a throwaway chain root under the system temp directory, makes each state change the skills prescribe, and records what the board prints.

**Steps:**

1. Write this script to a temp path outside the repository, e.g. `${TMPDIR:-/tmp}/sdlc-roadmap-walk.sh`:

   ```sh
   #!/bin/sh
   # Roadmap walkthrough for plan 05 of 2026-10-13-sdlc-roadmaps-milestones.
   #   sh sdlc-roadmap-walk.sh <absolute path of the repository root>
   # Builds one throwaway chain root, makes the state changes the roadmap,
   # milestone, intent and execute skills prescribe, and prints the board
   # after each one.
   set -eu
   REPO=$1
   P="$REPO/plugins/claudestacks-sdlc"

   WT=$(mktemp -d)
   R="$WT/.claudestacks/sdlc"
   mkdir -p "$R"

   # art <file> <body> <frontmatter line>... — writes one artifact, replacing it.
   art() {
     f=$1; body=$2; shift 2
     mkdir -p "$(dirname "$f")"
     {
       echo '---'
       for line in "$@"; do echo "$line"; done
       echo '---'
       printf '%s\n' "$body"
     } > "$f"
   }

   board() {
     printf '\n-- %s\n' "$1"
     ( cd "$WT" && sh "$P/scripts/status.sh" )
   }

   # member <chain dir> <title> <status> [milestone line] — one chain's intent.
   # The board reads frontmatter only, so the body is a single heading.
   member() {
     dir=$1; title=$2; status=$3; shift 3
     art "$dir/intent.md" "# Intent: $title" "status: $status" "created: 2026-10-14" "$@"
   }

   M="$R/roadmaps/platform"
   A="$R/2026-10-14-login"
   B="$R/2026-10-14-logout"
   L="$R/2026-10-15-late"

   printf '\n######## R1 a milestone parked, worked and closed by roll-up ########\n'
   art "$R/2026-10-13-fix-typo/intent.md" "# Intent: fix typo" \
     "status: approved" "created: 2026-10-13"
   art "$M/roadmap.md" "# Roadmap: Platform" "status: approved" "created: 2026-10-14"
   art "$M/01-auth.md" "# Milestone: Auth" "status: draft" "created: 2026-10-14"
   board "R1.1 roadmap wrote and approved the roadmap; its first milestone is a draft"
   art "$M/01-auth.md" "# Milestone: Auth" "status: approved" "created: 2026-10-14"
   board "R1.2 milestone approved it; nothing is parked yet"
   member "$A" "login" "draft" "milestone: platform/01"
   member "$B" "logout" "draft" "milestone: platform/01"
   board "R1.3 milestone parked two pieces of work as draft intents"
   member "$A" "login" "approved" "milestone: platform/01"
   board "R1.4 intent approved one member; its chain is now worked like any other"
   member "$A" "login" "done" "milestone: platform/01"
   member "$B" "logout" "dropped" "milestone: platform/01"
   board "R1.5 one member done by walk-up, the other dropped: the roll-up is owed"
   art "$M/01-auth.md" "# Milestone: Auth" "status: done" "created: 2026-10-14"
   board "R1.6 the roll-up closed the milestone (its first step)"
   art "$M/roadmap.md" "# Roadmap: Platform" "status: done" "created: 2026-10-14"
   board "R1.7 the same roll-up then closed the roadmap (its second step)"

   printf '\n######## R2 a closed milestone takes no new work ########\n'
   member "$B" "logout" "draft"
   board "R2.1 intent un-dropped a member of the closed milestone and removed its key"
   member "$L" "late" "draft" "milestone: platform/01"
   board "R2.2 the state the milestone skill's refusal prevents, written by hand"
   ```

2. Run it with the repository root's absolute path:

   ```
   $ sh "${TMPDIR:-/tmp}/sdlc-roadmap-walk.sh" "$(git rev-parse --show-toplevel)"
   ```

   Every board must show the rows below. Each row is what the spec section cited requires, and each was printed, exactly as written here, when this script was run on 2026-10-14 against a prototype of the code plans 01, 02 and 04 specify. The run in this task is against the real code; record its output, and treat any difference as a finding. The first column is the row's label; rows not listed for a step are unchanged from the step before.

   | Step | Row | STATE | NEXT | Spec |
   |---|---|---|---|---|
   | R1.1 | `ROADMAP platform` | `approved, 0 of 1 milestones done` | empty | §7.3 |
   | R1.1 | `MILESTONE platform/01-auth` | `draft, 0 of 0 done` | `approve or drop` | §7.2 |
   | R1.1 | `UNASSIGNED`, then `2026-10-13-fix-typo` indented two spaces | `intent approved` | `design` | §7.1 |
   | R1.2 | `MILESTONE platform/01-auth` | `approved, 0 of 0 done` | `park scope` | §7.2 |
   | R1.3 | `MILESTONE platform/01-auth` | `approved, 0 of 2 done` | empty | §7.2, §5 |
   | R1.3 | `2026-10-14-login`, indented under the milestone | `intent draft` | `approve or drop` | §7.1 |
   | R1.3 | `2026-10-14-logout`, indented under the milestone | `intent draft` | `approve or drop` | §7.1 |
   | R1.4 | `2026-10-14-login`, indented under the milestone | `intent approved` | `design` | §4 (status does not gate chain work) |
   | R1.5 | `MILESTONE platform/01-auth` | `milestone complete` | `roll up` | §7.2 |
   | R1.5 | `ROADMAP platform` | `approved, 0 of 1 milestones done` | empty | §7.3 |
   | R1.5 | no row for `2026-10-14-login` or `2026-10-14-logout`; the tail reads `DONE/DROPPED: 1 done, 1 dropped (not listed)` | — | — | §7.1 |
   | R1.6 | `MILESTONE platform/01-auth` | `done, 1 of 1 done` | empty | §7.2 |
   | R1.6 | `ROADMAP platform` | `roadmap complete` | `roll up` | §7.3 |
   | R1.7 | `ROADMAP platform` | `done, 1 of 1 milestones done` | empty | §7.3 |
   | R1.7 | no `MILESTONE platform/01-auth` row: a `done` milestone with no open member is not printed under a `done` roadmap | — | — | §7.1 |
   | R2.1 | `2026-10-14-logout`, indented under `UNASSIGNED` | `intent draft` | `approve or drop` | §8.3, §7.1 |
   | R2.1 | `ROADMAP platform` | `done, 1 of 1 milestones done` | empty | §7.3 |
   | R2.1 | the tail reads `DONE/DROPPED: 1 done, 0 dropped (not listed)` | — | — | §7.1 |
   | R2.2 | `MILESTONE platform/01-auth` | `INVALID (done with open chains)` | `fix platform/01` | §7.2 |
   | R2.2 | `2026-10-15-late`, indented under the milestone | `intent draft` | `approve or drop` | §7.1 |

3. Tie each step to the sentence that governs it. Run these and keep the output; each must print exactly one line:

   ```
   $ grep -n '| park scope |' plugins/claudestacks-sdlc/skills/milestone/SKILL.md
   $ grep -n '| adopt |' plugins/claudestacks-sdlc/skills/milestone/SKILL.md
   $ grep -n '^## Closed is final$' plugins/claudestacks-sdlc/skills/milestone/SKILL.md
   $ grep -n 'Run it for the milestone' plugins/claudestacks-sdlc/skills/milestone/SKILL.md
   $ grep -n 'Un-dropping a member of a closed milestone' plugins/claudestacks-sdlc/skills/intent/SKILL.md
   $ grep -n 'Dropping a member' plugins/claudestacks-sdlc/skills/intent/SKILL.md
   $ grep -n 'Then the roll-up' plugins/claudestacks-sdlc/skills/execute/SKILL.md
   $ grep -n '| approve | `draft → approved`, then the roll-up (below) |' plugins/claudestacks-sdlc/skills/roadmap/SKILL.md
   ```

4. Record in this plan's `## Probe results` section, under a `### Walkthrough` heading, at full precision: the command of step 2, the script's complete real output, and the eight `grep -n` lines of step 3. Where a real row differs from the table in step 2, do not edit the table to match: stop and report the difference — it means the board (plan 04) and the spec disagree.

---

**Checkpoint B — end of plan.** Present the walkthrough record and the completion report, and wait for the author before flipping this plan to `done`.

---

## Verification summary (plan-level)

- `cargo make plugins` ends `0 failed` with the passed count unchanged from before Task 1 (Checkpoint A).
- Each of Tasks 1–5 showed its file or phrase absent before the change and present after.
- The walkthrough's real output matches every row of Task 6's table: the milestone reads `approved, 0 of 0 done` → `park scope` before anything is parked, counts parked `draft` intents in its total, reads `milestone complete` → `roll up` once its members are finished, and a chain naming a closed milestone makes that milestone `INVALID (done with open chains)`.
- `git diff --stat` for this plan lists the four files of the file structure and this plan file itself (its appended record sections), and nothing under `references/` or `scripts/`.
