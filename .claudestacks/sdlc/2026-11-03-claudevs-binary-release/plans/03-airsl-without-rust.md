---
status: done
created: 2026-11-03
depends-on: [02]
built-on: 89f35fe63246
---

# `airsl` without Rust Implementation Plan

**Goal:** Give plugin users a working `airsl` with no Rust toolchain.

**Architecture:** One lookup line, identical across ten files, gains `~/.local/bin` first. `install-airsl.sh` tries
the prebuilt route and falls back to cargo. An offline shell test script with stubs covers every route, and one
live CI step runs the real installer. This plan follows plan 02 only because both edit `Makefile.toml`.

**Tech Stack:** POSIX shell, shellcheck, cargo-make, GitHub Actions, Claude Code plugin manifests.

**Content authority:** `spec.md` sections 5, 6, 7 (the plugin rows and version bumps) and 8 (`plugins-install`).

---

## Files that change

```
scripts/test-plugins-install.sh                     — create: the offline test lane, outside plugins/
Makefile.toml                                       — modify: add the plugins-install task
plugins/claudestacks/hooks/comm-check.sh            — modify: lookup line, comment at :12
plugins/claudestacks/hooks/enforce.sh               — modify: lookup line, comment at :17
plugins/claudestacks/hooks/handoff-check.sh         — modify: lookup line, comment at :13
plugins/claudestacks/hooks/preflight.sh             — modify: lookup line, fallback message at :47
plugins/claudestacks/hooks/rearm.sh                 — modify: lookup line, comment at :10
plugins/claudestacks/hooks/style.sh                 — modify: lookup line, comment at :13
plugins/claudestacks-sdlc/scripts/attention.sh      — modify: lookup line, comment at :4
plugins/claudestacks-sdlc/scripts/status.sh         — modify: lookup line, comment at :4
plugins/claudestacks-journal/scripts/session-start.sh — modify: lookup line, comment at :14
plugins/claudestacks/scripts/install-airsl.sh       — modify: lookup line and both install routes
plugins/claudestacks/scripts/statusline-install.lua — modify: comment at :71
.github/workflows/lua.yml                           — modify: plugins-install job, path filters
plugins/claudestacks/README.md                      — modify: install section at :71-77
plugins/claudestacks-journal/README.md              — modify: install line at :16
plugins/claudestacks/skills/statusline/SKILL.md     — modify: message at :69
plugins/claudestacks/.claude-plugin/plugin.json     — modify: 0.2.2 to 0.2.3
plugins/claudestacks-sdlc/.claude-plugin/plugin.json — modify: 0.4.0 to 0.4.1
plugins/claudestacks-journal/.claude-plugin/plugin.json — modify: 0.1.3 to 0.1.4
```

## Order of work

### Task 1 — Add `~/.local/bin` to the lookup, test first

**Files:**
- Create `scripts/test-plugins-install.sh` — POSIX shell. Each case runs under a temp `HOME` and a restricted `PATH`,
  with `CARGO_HOME` and `AIRSL_BIN` unset, and the script exits non-zero if any case fails, naming it.
- Modify `Makefile.toml` — add `plugins-install`, a `Plugin suite` task that runs the script.
- Modify the ten lookup files in the list above, replacing the candidate line with the exact line in spec section 5.
- Modify the comments at the lines listed above, and `plugins/claudestacks/scripts/statusline-install.lua:71` and
  `install-airsl.sh:46`, to name both directories.

**Change:** Each of the ten files resolves `airsl` from `AIRSL_BIN`, then `PATH`, then `~/.local/bin`, then the two
cargo locations.

**Proof:** written first, seen failing against the current line, then passing:
- `lookup_line_is_identical` — exactly the ten files of spec section 5 carry the exact new line, and no file under
  `plugins/` carries the old one.
- `preflight_finds_local_bin_off_path` — with `airsl` only in `~/.local/bin`, off `PATH`, no `STATUS:` line prints.
- `preflight_prefers_local_bin_over_cargo` — with both present, off `PATH`, the resolved path is the `~/.local/bin` one.
  `preflight.sh` neither runs nor prints what it resolved (`:23-37`), so this case runs a temp copy with one line added
  after the lookup block that prints `AIRSL`, as the spec section 5 probe did.

This case passes today, so it is seen failing by a deliberate break instead, temporarily removing the code it covers:
- `preflight_warns_with_neither` — with neither present, the `STATUS:` line prints and the exit is 0.

**Done when:** `cargo make plugins-install` and `cargo make plugins` pass and `cargo make dod` is green. Commit
`fix(repo): find airsl in ~/.local/bin from every plugin hook`.

### Task 2 — Make `install-airsl.sh` prebuilt-first, test first

**Files:**
- Modify `plugins/claudestacks/scripts/install-airsl.sh` — the flow in spec section 6.
- Modify `plugins/claudestacks/hooks/preflight.sh` — `:47` prints the `curl` line spec section 6 gives.
- Modify `scripts/test-plugins-install.sh` — add the cases below.

**Change:** The script picks `curl` if present, else `wget`, with the flags in spec section 6; a failing `curl` does
not try `wget`. It fetches `https://airsstack.github.io/airsl/install.sh` whole into a `mktemp -d` directory that is
removed on exit, then runs it with `sh`. A `mktemp` failure counts as a failed fetch. No downloader, a failed fetch
or a failed installer each go to the fallback. The fallback runs `cargo install airsl-cli --locked`, with `--force`
when given, if `cargo` exists; otherwise it prints the matching message and exits 1. Every message is the exact text
in the spec section 6 table. The off-`PATH` warning replaces `install-airsl.sh:62-64`. The shadowed warning compares
the resolved binary with the path just installed on either route, and is skipped when any of the four variables spec
section 6 names is set. The comments at `:4-8`, `:14-16`, `:68-72` and `:83-90` are rewritten to describe both routes.

**Proof:** written first, seen failing against the current script, then passing:
- `prebuilt_route_installs` — a stub `curl` serves a script that writes `~/.local/bin/airsl`; the `cargo` stub is not
  called; exit 0.
- `wget_is_used_without_curl` — the same through a `wget` stub, with no `curl` on `PATH`.
- `fetch_failure_falls_back_to_cargo` — the `cargo` stub receives `install airsl-cli --locked`, and the fallback line
  prints.
- `installer_failure_falls_back_to_cargo` — the served script exits 1, then the same.
- `no_downloader_falls_back_to_cargo` — no `curl` or `wget`, then the same with the reason A line.
- `no_downloader_no_cargo_exits_1` — exit 1 and the reason A text.
- `failed_install_no_cargo_exits_1` — exit 1, the reason B text, and no `Install one`.
- `unresolved_after_install_exits_1` — the served script writes nothing: exit 1 and the not-found text.
- `off_path_warning_names_skills` — `~/.local/bin` off `PATH`: the off-`PATH` text, and no `may still see nothing`.
- `shadowed_binary_warns` — a different `airsl` earlier on `PATH`: the warning names both paths.
- `preflight_fallback_names_the_pointer` — `preflight.sh` holds the `curl` line and no `cargo install airsl-cli` line.

These four pass against today's script, so each is seen failing by a deliberate break of the new code instead, then
restored:
- `failed_curl_does_not_try_wget` — with a failing `curl` stub and a `wget` stub, `wget` is not called. Break: let a
  failed `curl` try `wget`.
- `force_reaches_cargo` — `--force` on the fallback adds `--force` to the stub's arguments. Break: drop the flag.
- `cargo_failure_exits_1` — a failing `cargo` stub gives exit 1. Break: ignore cargo's status.
- `chosen_location_skips_shadow_warning` — `AIRSL_BIN` set: no shadowed warning. Break: remove the skip.

**Done when:** `cargo make plugins-install` passes, `shellcheck --shell=sh
plugins/claudestacks/scripts/install-airsl.sh scripts/test-plugins-install.sh` prints nothing, and `cargo make dod` is
green. Commit `feat(repo): install prebuilt airsl with a cargo fallback`.

### Task 3 — Run the lane in CI, with one live install

**Files:**
- Modify `.github/workflows/lua.yml` — add a `plugins-install` job; add `scripts/test-plugins-install.sh` to the
  `paths` lists under both `push` and `pull_request`.

**Change:** The job installs `shellcheck` by apt and `cargo-make` as the file's other jobs do, runs `shellcheck` over
`install-airsl.sh` and the test script, then runs `cargo make plugins-install`. A final live step sets `HOME` to a
temp directory, runs `sh plugins/claudestacks/scripts/install-airsl.sh`, then runs `"$HOME/.local/bin/airsl" --version`.
Its comment says the temp `HOME` keeps the runner's profiles untouched, and that this is the only test of the real
pointer and installer.

**Proof:**
- `lua_job_runs_the_lane` — `grep` finds `cargo make plugins-install` inside the new job.
- `lua_paths_cover_the_script` — `scripts/test-plugins-install.sh` appears in both `paths` lists.
- `lua_live_step_uses_a_temp_home` — the live step sets `HOME` before it runs the script.

**Done when:** those checks pass and `cargo make dod` is green. Commit
`ci(repo): run the airsl install lane and a live install`.

### Task 4 — Update the plugin docs, then bump plugin versions

**Files:**
- Modify `plugins/claudestacks/README.md` — `:71-77` describes the prebuilt route, the cargo fallback, and that
  re-running installs the latest.
- Modify `plugins/claudestacks-journal/README.md` — `:16` names the prebuilt route.
- Modify `plugins/claudestacks/skills/statusline/SKILL.md` — `:69` points at `install-airsl.sh`, not
  `cargo make install-airsl`.
- Modify each of the three `plugin.json` files at `:3` — the versions in the file list above.

**Change:** Plugin docs describe what the script now does, and each changed plugin carries a new version so installed
copies receive it.

**Proof:**
- `plugin_docs_name_the_prebuilt_route` — `grep -n 'install.sh\|install-airsl.sh\|cargo install airsl-cli'` on each
  README shows a prebuilt line numbered ahead of any `cargo install airsl-cli` line.
- `statusline_skill_names_the_script` — `grep 'cargo make install-airsl'` on that skill prints nothing, and
  `grep 'install-airsl.sh'` on it finds the new line.
- `plugin_versions_bumped` — `grep -n '"version"'` on the three manifests prints 0.2.3, 0.4.1 and 0.1.4.

**Done when:** those checks and `cargo make plugins` pass and `cargo make dod` is green. Commit
`docs(repo): describe the prebuilt airsl route and bump plugin versions`.

---

## Risks

- Riskiest step: Task 1 edits a line in every hook, and an error there silently disables hooks, because they are
  guarded to exit quietly. `lookup_line_is_identical` and the preflight cases are the protection.
- The stubs cannot show the real pointer and installer working. Only Task 3's live step can, and it runs in CI, so it
  depends on the network and the latest `airsl` release, like the install steps already in `lua.yml`.
- A contributor with an older `~/.local/bin/airsl` and the cargo directory off `PATH` runs that older copy after
  `cargo make install-airsl`, with no warning. Spec section 6 accepts this.
- Run the test lane through `cargo make`. The script sets `HOME`, and this worktree's session guard refused a hand-typed
  command that did so during design. That the `cargo make` form passes the guard was not tested here.
- A YAML error in `lua.yml` first shows on the pull request. No workflow parser was confirmed on this machine, and the
  spec requires none.

## Proof

- `cargo make plugins-install` passes.
- `cargo make plugins` passes.
- `cargo make dod` is green.

## Review findings

Two lines are fixed. Every other line is open. Line numbers are as each review saw them.

Task 1 (reviewer: non-compliant on one requirement; blocking `scripts/test-plugins-install.sh:58`):
- `scripts/test-plugins-install.sh:58` 🟡 fixed: `lookup_line_is_identical` matched a substring, so a commented-out, re-indented or CRLF line stayed green. Now `grep -rlxF -- "  $NEW_LINE" plugins`. With `rearm.sh`'s line commented out, `cargo make plugins-install` printed `ok   lookup_line_is_identical` before the change and `FAIL lookup_line_is_identical` / `plugins-install: FAILED` after it; restored, it printed `plugins-install: all cases passed`. Only the commented-out variant was run.
- `Makefile.toml:147` 🟡 the comment says the worktree guard refuses running the script by hand and calls it this repository's guard. The reviewer ran `sh scripts/test-plugins-install.sh` by hand and it passed, and `protocol.md:140` calls it Claude Code's guard.
- `scripts/test-plugins-install.sh:79` 🟡 the Task 1 found-path cases ignore `$rc`: `preflight_finds_local_bin_off_path` passes with `preflight.sh` deleted, because the absence of `STATUS:` proves nothing if the script never ran.
- `Makefile.toml:149` 🔵 "every case runs against stubs under a temporary HOME" overclaims.
- `scripts/test-plugins-install.sh:1` 🔵 shebang on a 0644 file; sibling `scripts/corpus-fetch.sh` is 0755.
- `scripts/test-plugins-install.sh:6` 🔵 "Every case runs under its own temporary HOME" is false for `lookup_line_is_identical`. The plan's Files bullet says the same; see Deviations.
- `scripts/test-plugins-install.sh:58` 🔵 `grep -r` and `mktemp` are outside POSIX 2024 (weak evidence for `mktemp`); ran under sh, dash and ksh.
- `scripts/test-plugins-install.sh:69` 🔵 "a candidate loop of any other shape" overclaims; an eleventh file with a one-entry loop passes.
- `scripts/test-plugins-install.sh:123` 🔵 no trap, so a signal mid-case leaks the temp dir.

Task 2 (reviewer: `blocking: none`, 0🔴 10🟡 10🔵, 3🔵 against the plan):
- `plugins/claudestacks/scripts/install-airsl.sh:81` 🟡 the shadowed check compares path strings, so one binary spelled two ways warns "Remove <the binary just installed>". Reproduced with a symlinked `PATH` entry and a `CARGO_HOME` trailing slash.
- `plugins/claudestacks/scripts/install-airsl.sh:114` 🟡 `wget -q` printed nothing on a 404, so "see the error above" points at nothing on a wget-only machine. Flags and text are the plan's.
- `plugins/claudestacks/scripts/install-airsl.sh:126` 🟡 an installer that exits 0 and writes nothing, with an older `airsl` on `PATH`, gives exit 0 and a warning naming a file that does not exist; following "Remove <older>" leaves no `airsl`. Whether the real installer can do this was not checked.
- `scripts/test-plugins-install.sh:20` 🟡 only `CARGO_HOME` and `AIRSL_BIN` are unset; with `AIRSL_CLI_INSTALL_DIR` exported, `shadowed_binary_warns` goes red. Fails closed.
- 🟡 Six behaviours no case guards, each shown by a mutation that left the lane green: `install-airsl.sh:105` (`mktemp` failure), `:106` (both traps), `:114` (wget failure), `:116` (arguments to the installer; `--force` reaching the real installer would send every install to cargo), `:129` (`installed` on the cargo route), `:157` (`--force` cargo failure).
- `plugins/claudestacks/scripts/install-airsl.sh:18` 🔵 "resolves to the latest release" holds only without `AIRSL_VERSION`.
- `plugins/claudestacks/scripts/install-airsl.sh:106` 🔵 a signal between `mktemp` and the traps would leave an empty directory (by reading).
- `plugins/claudestacks/scripts/install-airsl.sh:116` 🔵 the installer inherits stdin; `sh < install-airsl.sh` with an installer that drains stdin ends at exit 0 with no report. `</dev/null` would fix it.
- `plugins/claudestacks/scripts/install-airsl.sh:116` 🔵 a rejected `AIRSL_VERSION` fails the pointer, then the fallback builds the latest release and exits 0 (by reading).
- `plugins/claudestacks/scripts/install-airsl.sh:127` 🔵 `HOME` unset aborts after a successful install; the old script aborted on `HOME` too.
- `plugins/claudestacks/scripts/install-airsl.sh:129` 🔵 assumes cargo's root is `CARGO_HOME`; `CARGO_INSTALL_ROOT` and `install.root` take precedence per `cargo help install`. Effect not run.
- `scripts/test-plugins-install.sh:6` 🔵 "with CARGO_HOME and AIRSL_BIN unset" is false for `chosen_location_skips_shadow_warning`.
- `scripts/test-plugins-install.sh:45` 🔵 says `install-airsl.sh` calls these tools; it does not call `mkdir`, `chmod` or `cat`.
- `scripts/test-plugins-install.sh:215` 🔵 the script's temp directory lands in the system temp, not `$h`, so a lost trap would leak there unseen.
- `scripts/test-plugins-install.sh:394` 🔵 `preflight_fallback_names_the_pointer` is a static grep; no case executes `preflight.sh:47`. The plan says "holds", so it conforms.
- Task 2 Change 🔵 the comment at old `:83-90` was re-wrapped, not rewritten; it is accurate.

Tasks 3 and 4 (reviewer: spec compliant; 5🟡 5🔵 1❓; blocking `plugins/claudestacks-journal/README.md:16`):
- `plugins/claudestacks-journal/README.md:16` 🟡 fixed: the first step was a repo-relative script with no clone in the section. Now the `curl` command from `preflight.sh:47`, with cargo as the source alternative. `grep -n 'install.sh\|install-airsl.sh\|cargo install airsl-cli' plugins/claudestacks-journal/README.md` prints `16:` the `curl` line then `17:` the cargo line; `grep -n 'install.sh' plugins/claudestacks/hooks/preflight.sh` prints the same command at `47:`.
- `.github/workflows/lua.yml:126` 🟡 no toolchain step, so `cargo make` relies on rustup downloading the 1.94.1 pin implicitly, uncached. Not observed on a runner; fails loudly if auto-install is off.
- `.github/workflows/lua.yml:153` 🟡 a failed prebuilt install can end in a pass: a served script that writes the binary then exits 1, with cargo succeeding, passes the step (reproduced with stubs). Whether the real installer can fail after writing its binary was not checked.
- `plugins/claudestacks/README.md:71` 🟡 only repo-relative commands remain, though this README's own install section uses the marketplace. The in-session `FIX:` line gives an absolute path.
- `plugins/claudestacks/README.md:76` 🟡 "Re-running the script installs the latest" omits that an older `airsl` on `PATH` keeps winning; the script warns, the README does not. This is the upgrade path for current cargo users.
- `.github/workflows/lua.yml:142` 🔵 the comment understates the lane, which also covers the installer's routes.
- `.github/workflows/lua.yml:153` 🔵 a broken pointer spends the cargo fallback's build before the step fails.
- `plugins/claudestacks/README.md:75` 🔵 the fallback sentence omits that it needs cargo.
- `plugins/claudestacks/README.md:77` 🔵 `--force` is mentioned but never explained.
- `plugins/claudestacks/skills/statusline/SKILL.md:69` 🔵 122-column line.
- 🔵 No committed check guards the `lua.yml` job, its path filters, the docs or the version bumps.
- `plugins/claudestacks/skills/statusline/SKILL.md:69` ❓ not verified whether `${CLAUDE_PLUGIN_ROOT}` reaches the user as a literal path.

The live install step has never run; no workflow has run on GitHub.

## Deviations

- 2026-11-03: Task 2, plan stage. The Proof says four cases pass against today's script. `force_reaches_cargo` and `cargo_failure_exits_1` did. `failed_curl_does_not_try_wget` failed because it also asserts `curl` was called, which the old script never does, and `chosen_location_skips_shadow_warning` failed because it asserts exit 0 and the old script exits 1 on the stub-only `PATH`. Each was shown able to go red for its named reason with a deliberate break, then restored. The cases keep the stronger assertions. The plan's claim, not the spec's, so no `disproves` marker.
- 2026-11-03: Task 2. `cargo_failure_exits_1`: the first break (`|| exit 1` to `|| true`) stayed green, because the failing stub left no binary and the script still exited 1 as not resolvable. A `stub_cargo 1 installs` stub, which fails but leaves a binary, went red with `exit status 0, expected 1`. `chosen_location_skips_shadow_warning` loops over four variables and stops at the first failure, so the break showed only `AIRSL_BIN` taking effect.
- 2026-11-03: Task 2. Decided where the spec is silent: the two cannot-install messages and the not-resolvable message go to stderr, the fallback line and the warnings to stdout. The shadowed warning's skip tests the four variables as non-empty. The fetch writes through a stdout redirect, as the published pointer script does. The coder also fetched that script to check this, which the run's no-re-proving rule does not call for.
- 2026-11-03: Task 1. The plan's Files bullet says each case runs under a temp `HOME` and restricted `PATH`. `lookup_line_is_identical` does neither, because it only reads repository files.
- 2026-11-03: Task 1. The plan's fallback-message wording at `preflight.sh:47` was left to Task 2, which rewrites that line.
- 2026-11-03: Task 3. The coder did not run the live install on this machine, on the brief's instruction, because it reaches the network and the task's proof is the `grep`. The job has no `rustup show` or cache step and sets `timeout-minutes: 15`, which the plan does not name.
- 2026-11-03: Task 4. The statusline skill points at `sh "${CLAUDE_PLUGIN_ROOT}/scripts/install-airsl.sh"`, the form that skill already uses at `:82`.
- 2026-11-03: All tasks. The instruction to execute did not say to commit, so the commits this plan names were not made; the work is in the working tree.
- 2026-11-03: Reports `06`, `11`, `12` and `14` were returned to the main thread and not written to the session directory, so the reviewer of Tasks 3 and 4 worked without `11` and `12`. TodoWrite was not available, so tasks were tracked in batch order. A task 3-4 reviewer issued one command that would have run the real installer; the permission classifier denied it and nothing ran.
