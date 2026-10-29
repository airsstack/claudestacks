---
status: approved
created: 2026-10-29
built-on: 80fae45ab510
---

# Python Guideline Plugin and Gate Implementation Plan

**Goal:** `claudestacks-guideline-python` installs from the in-repo marketplace with a
`python-guidelines` skill whose Definition of Done is the gate the spec proved.

**Architecture:** A new plugin directory shaped like `plugins/claudestacks-guideline-rust/`:
manifest, `enforcement.json`, licence, README, and one skill whose `SKILL.md` holds the gate and
a reference index. This plan ships the index with one entry, `strict-quality.md`; plans 02, 03
and 04 each append the entries for the files they create. The learning document currently in
the directory is deleted first, so nothing it says can ship.

**Tech Stack:** Claude Code plugin manifest and marketplace JSON; `claudevs` 0.1.0 for plugin
validation; uv 0.13.6, ruff 0.17.3, mypy 2.4.1, pytest 9.2.0 for the gate proof (run through
`uvx --from uv@0.13.6 uv`, since the local `uv` is 0.9.16); `airsl` for the dispatcher proof.

**Content authority:** spec §1.1–§1.3, §2.1, §2.2, §3, §4, §7, §8 rows 1–3; the marketplace row of
§2.3.

---

## Files that change

```
plugins/claudestacks-guideline-python/skills/python-guidelines/modern-python.md
                                        — [delete] the learning document (spec §2.1)
plugins/claudestacks-guideline-python/.claude-plugin/plugin.json
                                        — [create] plugin manifest (spec §2.1)
plugins/claudestacks-guideline-python/LICENSE
                                        — [create] Apache-2.0, byte-identical to the Rust plugin's
plugins/claudestacks-guideline-python/enforcement.json
                                        — [create] dispatcher manifest, verbatim spec §2.2
plugins/claudestacks-guideline-python/skills/python-guidelines/SKILL.md
                                        — [create] the gate (spec §3) and the reference index
plugins/claudestacks-guideline-python/skills/python-guidelines/references/strict-quality.md
                                        — [create] the policy behind the gate (spec §4)
plugins/claudestacks-guideline-python/README.md
                                        — [create] plugin README in the Rust README's sections
.claude-plugin/marketplace.json         — [modify] add the plugin entry after the Rust one
```

No file under `crates/` or the root Cargo files changes, so the workspace Rust gate
(`cargo make dod`) is not affected by this plan.

## Order of work

### Task 1 — Replace the learning document with a valid plugin skeleton

**Files:**
- Delete `plugins/claudestacks-guideline-python/skills/python-guidelines/modern-python.md`
- Create `plugins/claudestacks-guideline-python/.claude-plugin/plugin.json`
- Create `plugins/claudestacks-guideline-python/LICENSE`
- Create `plugins/claudestacks-guideline-python/enforcement.json`

**Change:** the directory stops holding the tutorial and becomes a plugin. `plugin.json` copies
the keys of `plugins/claudestacks-guideline-rust/.claude-plugin/plugin.json:1-18` with name
`claudestacks-guideline-python`, version `0.1.0`, description "Python engineering guidelines
and Definition-of-Done, delivered as a lazily-loaded skill.", and keywords `python`,
`guidelines`, `definition-of-done`, `code-quality`. `LICENSE` is a copy of
`plugins/claudestacks-guideline-rust/LICENSE`. `enforcement.json` is spec §2.2 verbatim.

**Proof:** written first, seen failing, then passing —
- `claudevs_check_validates_the_plugin` — before this task,
  `claudevs check plugins/claudestacks-guideline-python` exits 1 with `No manifest found in
  directory` (spec §8 row 1); after it, the `validate` stage reads `ok`. The `test` stages may
  report `skip` (no case files), as they do for the Rust plugin.
- `manifests_are_valid_json` — `python3 -I -m json.tool <file>` exits 0 for `plugin.json` and
  `enforcement.json`.
- `license_matches_the_rust_plugin` — `cmp` of the two `LICENSE` files exits 0.
- `learning_doc_is_gone` — `test ! -e
  plugins/claudestacks-guideline-python/skills/python-guidelines/modern-python.md` exits 0.

**Done when:** all four checks pass. Commit `feat(repo): scaffold the claudestacks-guideline-python plugin`.

### Task 2 — Write `SKILL.md`: the gate and its rules

**Files:**
- Create `plugins/claudestacks-guideline-python/skills/python-guidelines/SKILL.md`

**Change:** frontmatter `name: python-guidelines` and a `description` in the form of
`plugins/claudestacks-guideline-rust/skills/rust-guidelines/SKILL.md:3`, written complete now
because it decides when the skill loads and no later plan revisits it: "Use when writing or
editing Python code or pyproject.toml — supplies the Python Definition-of-Done (the exact uv,
ruff, mypy and pytest command gate every change must pass) and an index of engineering rules
(strict quality, modern typing, strong types, protocols and composition, `__init__.py`
hygiene, modularity, docstring discipline, the test mandate, errors, idioms, project layout, uv
workspaces, and the Google Python Style Guide). Read the matching reference before applying a
rule." Body sections mirror the Rust skill
(`rust-guidelines/SKILL.md:6-73`, sections at `:11` and `:48`): an opening line naming `SKILL.md` as gate and map; a
"Definition of Done (the gate)" section holding the five commands of spec §3 in one fenced
block, with `--all-packages` noted for workspaces; the rules of the gate as spec §3 lists them
(every step exits 0, `--locked`, `--no-fix`, `--strict` on the command line, `--all-packages`,
no `uv lock --check` step, no coverage threshold, the gate runs on `.python-version`); a line
naming `uv` as the one prerequisite and the `dev` group as the source of every gate tool (spec
§7); and a "Reference index" section, empty in this task — Task 3 adds its first entry together
with the file it names, so no commit indexes a file that does not exist.

**Proof:** written first, seen failing, then passing —
- `skill_frontmatter_names_the_skill` — `grep -n '^name: python-guidelines$'` on `SKILL.md`
  finds one line; absent before the file exists.
- `gate_block_matches_spec` — the fenced gate block, extracted with `sed`, is line-for-line the
  five commands of spec §3 (compare with `diff` against the spec's block).
- `claudevs_check_still_passes` — `claudevs check plugins/claudestacks-guideline-python` exits 0.

**Done when:** the three checks pass. Commit `feat(repo): add the python-guidelines Definition of Done`.

### Task 3 — Write `references/strict-quality.md`

**Files:**
- Create `plugins/claudestacks-guideline-python/skills/python-guidelines/references/strict-quality.md`
- Modify `SKILL.md` — add the first "Reference index" entry, for this file, in the form of
  `rust-guidelines/SKILL.md:52-53`

**Change:** the policy behind the gate, in the section order of
`plugins/claudestacks-guideline-rust/skills/rust-guidelines/references/strict-quality.md`
(zero-failure scope, how enforcement is split between command flags and project config,
suppressions, tests green including doctests, a pointer to `SKILL.md` for the commands, a
reviewer checklist). Its content is spec §4: the required baseline of §4.1 verbatim with the
pinned versions named (ruff 0.17.3, mypy 2.4.1, pytest 9.2.0 as the versions proven on
2026-10-29), the rule that a project may add but not remove, the rule for changing the list,
and every §4.2 policy line. Each tool-behaviour claim cites the spec §1.2 or §4.2 evidence
row it rests on.

`uv audit` and the `exclude-newer` cooldown enter this file only after the implementer has run
them (spec §9), as the last two probes below. If either cannot be run as described, leave it out
of the file and report it — the spec's decision (advisory audit, SHOULD cooldown) stands, but
an unrun command does not ship.

**Proof:** written first, seen failing, then passing — the spec §8 row 3 probe, rebuilt from the
shipped files:
- `clean_probe_is_green` — a throwaway project from `uvx --from uv@0.13.6 uv init --lib --python
  3.12 probe`, dev group pinned to the three versions above, the `[tool.*]` tables copied from
  the shipped `strict-quality.md`, one Google-docstring module with a doctest and one test: all
  five gate commands copied from the shipped `SKILL.md` exit 0.
- `each_defect_fails_its_step` — each spec §1.2 defect row, applied alone to a fresh copy, makes
  the step that row names exit non-zero with the rule code or message that row records (stale
  lock, unformatted line, `fix = true` plus unused import, `FBT001`, `D417`, `T201`, `RUF100`,
  `PGH003` together with mypy `unused-ignore`, `B904`, mypy `arg-type`, `explicit-override`, a
  `DeprecationWarning` in a test, a broken doctest).
- `config_warning_does_not_fail` — adding `"COM"` to `extend-select` prints the `COM812`
  conflict warning on stderr while `ruff format --check` exits 0 (spec §4.2), which is why the
  reviewer checklist carries the warning rule.
- `uv_audit_runs` — `uvx --from uv@0.13.6 uv audit` run in the clean probe project; record the
  exit code and output, and the exact invocation the reference then names.
- `cooldown_excludes_a_newer_release` — in a copy of the probe project, set
  `[tool.uv] exclude-newer` to a date before the upload of one pinned dev tool (ruff 0.17.3 was
  uploaded 2026-10-27, per PyPI JSON); `uv lock` must then refuse that pin, and with the pin
  relaxed to `ruff>=0.17` it must resolve an older ruff — both outputs recorded, and the
  reference's syntax copied from the run.

The probe project is rebuilt, not kept: plans 02 and 03 recreate it from the shipped
`strict-quality.md` by this same recipe.

**Done when:** the three probes hold, and every behavioural sentence in the file cites a spec
evidence row or a command run in this task. Commit `feat(repo): add the python strict-quality reference`.

### Task 4 — Prove the dispatcher surfaces the skill inside a git repository

**Files:**
- none in the repository (a throwaway git repository and registry under the session temp
  directory)

**Change:** none to the code; this task proves spec §8 row 2 against the shipped
`enforcement.json`.

**Proof:**
The dispatcher computes the repository-relative match path from the process's working
directory, not from the file: `explain` sets `cwd = path.absolute(".")`
(`plugins/claudestacks/hooks/enforce.lua:49`) and `path_for_matching` finds the toplevel from
that cwd, falling back to the basename for a file outside it (`hooks/lib/enforce.lua:181-196`).
So each probe runs **with its working directory at the throwaway repository's root** and names
`enforce.lua` by its absolute path. In a worktree-isolated session the guard refuses variables in
an `airsl` command line; write each command into a script file under the temp directory that
first `cd`s to the throwaway repository, and run it with `sh`.

- `py_file_in_a_pyproject_repo_emits` — a throwaway git repository holding `pyproject.toml` and
  `src/pkg/m.py`; a registry JSON whose single record is
  `claudestacks-guideline-python@claudestacks` with `installPath` set to the absolute path of
  `plugins/claudestacks-guideline-python`; from the throwaway repository's root,
  `AIRSSTACK_ENFORCE_REGISTRY=<that file> TMPDIR=<fresh dir A> airsl run --policy confined
  --allow-env HOME --allow-env TMPDIR --allow-env AIRSSTACK_HOME --allow-env
  AIRSSTACK_ENFORCE_REGISTRY --allow-read / --allow-write <temp root> <absolute path to
  plugins/claudestacks/hooks/enforce.lua> --explain <repo>/src/pkg/m.py` prints `match path:
  src/pkg/m.py` (not the basename) and `EMIT claudestacks-guideline-python:python-guidelines`.
- `script_without_pyproject_is_silent` — the same command with a **new** `TMPDIR` (fresh dir B),
  on a `.py` file in a directory with no `pyproject.toml` above it, prints `GATE 2 no detect
  marker` and `outcome: 0 pointer(s)`. A reused `TMPDIR` would stop at `already claimed`
  instead, because the first probe's `EMIT` claims the sentinel for this stack and phase
  (`hooks/lib/enforce.lua:386-392`, `:549-561`).

**Done when:** both traces read as above. No commit (nothing in the repository changed); record
the two traces in the next commit's body.

### Task 5 — Write the plugin README and list the plugin in the marketplace

**Files:**
- Create `plugins/claudestacks-guideline-python/README.md`
- Modify `.claude-plugin/marketplace.json` — new entry after `:20-22`

**Change:** the README follows `plugins/claudestacks-guideline-rust/README.md:1-40` section for
section (headings at `:10`, `:23`, `:32`, `:38`) (title and one-paragraph summary naming the skill, Install, the enforcement paragraph,
What it provides, How it pairs with `claudestacks`, License), with Python content: the gate of
spec §3 summarised, a reference list holding only `strict-quality.md` (plans 02, 03 and 04 each
append their own files — see Risks), and the out-of-scope note for standalone PEP 723 scripts (spec §2.2). The
marketplace entry is `{"name": "claudestacks-guideline-python", "source":
"./plugins/claudestacks-guideline-python", "description": "Python engineering guidelines and
Definition-of-Done, delivered as a lazily-loaded skill."}`.

**Proof:** written first, seen failing, then passing —
- `marketplace_lists_the_plugin` — `python3 -I -c` loading `.claude-plugin/marketplace.json`
  and listing plugin names prints `claudestacks-guideline-python` (absent before).
- `marketplace_is_valid_json` — `python3 -I -m json.tool .claude-plugin/marketplace.json` exits 0.
- `claudevs_check_passes` — `claudevs check plugins/claudestacks-guideline-python` exits 0.
- `readme_has_the_rust_sections` — `grep -c` for the headings `## Install`, `## What it
  provides`, `## How it pairs with \`claudestacks\``, `## License` in the new README gives 4 (0
  before the file exists).

**Done when:** the four checks pass. Commit `feat(repo): list claudestacks-guideline-python in the marketplace`.

## Risks

- **Index and README grow across plans.** Plans 02, 03 and 04 append index entries to `SKILL.md`
  and the README's reference list. Run in parallel worktrees they edit neighbouring lines;
  expect a textual merge conflict and resolve it by keeping every entry, in spec §5 table order.
- **The gate probe depends on PyPI and python.org downloads.** `uvx --from uv@0.13.6` and
  `uv python install 3.12` fetch from the network; an offline run cannot prove Task 3.
- **Most risky step:** Task 3 — it is where a spec premise (the `uv audit` and cooldown syntax)
  is run for the first time.
- **Not done here:** the other twelve references (plans 02–04), the agent wording (plan 05), and
  the rest of the repository text (plan 06).

## Proof

- `claudevs check plugins/claudestacks-guideline-python` exits 0.
- The Task 3 probe set passes from the shipped `SKILL.md` and `strict-quality.md`.
- The Task 4 traces show the skill surfaced for a `.py` file in a `pyproject.toml` repository and
  silent for a standalone script.
- `test ! -e plugins/claudestacks-guideline-python/skills/python-guidelines/modern-python.md`
  exits 0.
