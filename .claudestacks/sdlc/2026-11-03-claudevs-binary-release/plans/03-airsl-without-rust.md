---
status: approved
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
