---
status: approved
created: 2026-11-03
depends-on: [01, 02, 03]
built-on: 89f35fe63246
---

# Repository docs Implementation Plan

**Goal:** Document the prebuilt pipeline across the repository's own guides.

**Architecture:** Documentation only. User-facing files lead with the prebuilt command, keep cargo second and state the
`git` requirement. Maintainer files describe the release workflow, its recovery, and the new check lanes.

**Tech Stack:** Markdown.

**Content authority:** `spec.md` sections 7 and 9 (the recovery rows). Spec sections 10 and 11 are the author's steps
after this chain's plans finish, and have no task here.

---

## Files that change

```
README.md                             — modify: :101 and :161-162 install routes
crates/claudevs-cli/README.md         — modify: :12 install route
crates/claudevs/docs/cli/tutorial.md  — modify: :11 and :17 install routes
RELEASING.md                          — modify: binary release, what a release leaves, recovery
.claude/skills/release/SKILL.md       — modify: section 9 report for claudevs-cli
CLAUDE.md                             — modify: :207-208, :214-215 and the Commands section
```

## Order of work

### Task 1 — Update the user-facing install docs

**Files:**
- Modify `README.md` — at `:101`, `curl -LsSf https://airsstack.github.io/claudestacks/install.sh | sh` first, cargo
  second, and a line stating `git` is required. At `:161-162`, the prebuilt `airsl` route first, and "needs a Rust
  toolchain" removed.
- Modify `crates/claudevs-cli/README.md` — at `:12`, the same as `README.md:101`.
- Modify `crates/claudevs/docs/cli/tutorial.md` — at `:11` and `:17`, the prebuilt route ahead of the two cargo routes.
  Its `:22` already says cases need `git` on `PATH`, and stays.

**Change:** Users see the Rust-free route first and learn `claudevs` needs `git`. These files state current facts in
the present tense, with no release history.

**Proof:**
- `install_docs_lead_with_prebuilt` — `grep -n 'install.sh\|cargo install'` on each of the three files shows the
  `install.sh` line numbered ahead of the first `cargo install` line for `claudevs-cli`.
- `install_docs_state_git` — `grep -n '`git`'` on `README.md` and `crates/claudevs-cli/README.md` finds the new line, and
  on the tutorial still finds `:22`.
- `root_readme_drops_rust_note` — `grep 'needs a Rust toolchain' README.md` prints nothing, and `grep -n
  'airsl/install.sh\|cargo install airsl-cli' README.md` shows the prebuilt `airsl` line numbered first.

**Done when:** those checks pass and `cargo make dod` is green. Commit
`docs(repo): lead the claudevs install docs with the prebuilt route`.

### Task 2 — Update the release process docs

**Files:**
- Modify `RELEASING.md` — state that the `claudevs-cli` tag starts the binary release, add the GitHub Release to "What a
  release leaves behind", and add the recovery from spec section 9: `gh run rerun <run-id> --failed` first, then fix
  forward with a new patch version, because crates.io cannot replace a version.
- Modify `.claude/skills/release/SKILL.md` — in section 9, for `claudevs-cli`, the report names the
  `claudevs-cli-release.yml` run to watch. The skill stays check-only and gains no new step.

**Change:** Whoever releases `claudevs-cli` knows the tag starts a build, where to watch it and what to do if it fails.

**Proof:**
- `releasing_names_the_workflow` — `RELEASING.md` names `claudevs-cli-release.yml` and `gh run rerun`.
- `release_skill_names_the_workflow` — section 9 of the skill names `claudevs-cli-release.yml`.

**Done when:** those checks pass and `cargo make dod` is green. Commit
`docs(repo): describe the claudevs binary release and its recovery`.

### Task 3 — Update `CLAUDE.md`

**Files:**
- Modify `CLAUDE.md` — at `:214-215`, record two install routes: `install-airsl.sh` prebuilt, `cargo make install-airsl`
  cargo. At `:207-208`, name `lua.yml`'s third job and its filter beyond `plugins/**`. In Commands, name the release,
  smoke and pages workflows, the `dist generate` rule, the `macos-15` departure from `airsl` and `buildl`, and
  `cargo make install-check` and `cargo make plugins-install`.

**Change:** Future sessions find the pipeline's rules, and know not to hand-edit the generated workflow or restore
`macos-14`.

**Proof:**
- `claude_md_names_the_rules` — `CLAUDE.md` names `dist generate`, `macos-15`, `install-check` and `plugins-install`.
- `claude_md_no_single_route` — `grep -n 'install the crate' CLAUDE.md` no longer finds the sentence saying both routes
  install with `cargo install`, and `grep -n 'test-plugins-install' CLAUDE.md` finds the `lua.yml` filter.

**Done when:** those checks pass and `cargo make dod` is green. Commit
`docs(repo): record the binary release rules in CLAUDE.md`.

---

## Risks

- `README.md` and `crates/claudevs-cli/README.md` will name a URL that errors until the first release. Spec section 9
  records that state, and spec section 11 puts the release right after merge.
- `crates/claudevs-cli/README.md` reaches crates.io only with 0.1.1. `crates/claudevs/docs/cli/tutorial.md` reaches it only
  with a later `claudevs` version, since spec section 12 holds that crate at 0.1.0.
- Riskiest step: Task 1's edit to `crates/claudevs/docs/cli/tutorial.md`, because the `Recorded from the checkout` line
  at its `:20` must stay attached to the checkout route.

## Proof

- `cargo make dod` is green.
- `grep -rl 'cargo install' README.md RELEASING.md CLAUDE.md crates plugins .claude/skills --include='*.md'` returns only
  files that also name the prebuilt route or describe contributors' tooling.
