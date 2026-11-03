---
status: done
created: 2026-11-03
built-on: 89f35fe63246
---

# Install URL Implementation Plan

**Goal:** Serve the `claudevs` installer from `https://airsstack.github.io/claudestacks/install.sh`.

**Architecture:** A small pointer script fetches the installer dist generated for one release and runs it, so the
short URL never goes stale. A Pages workflow publishes only that script. GitHub Pages is already enabled with
the Actions source (spec section 4), so no task enables it.

**Tech Stack:** POSIX shell, shellcheck, cargo-make, GitHub Actions, GitHub Pages.

**Content authority:** `spec.md` sections 4, 8 (`install-check`) and 9 (the install-URL rows).

---

## Files that change

```
Makefile.toml                 — modify: add the install-check task
install/install.sh            — create: the pointer script
.github/workflows/ci.yml      — modify: add the install-pointer job
.github/workflows/pages.yml   — create: publish install.sh to Pages
```

## Order of work

### Task 1 — Add the pointer script, test first

**Files:**
- Modify `Makefile.toml` — add `install-check`, a `script_runner = "@shell"` task with `category = "Install"`.
- Create `install/install.sh` — the pointer on the pattern of `buildl/install/install.sh:1-78`, using the names in
  spec section 4, with its `say` prefix, messages and header comments changed to match.

**Change:** `install-check` runs `shellcheck --shell=sh install/install.sh`, then runs the script with
`CLAUDEVS_VERSION` set to `1;2`, a single space, and `../x`, each as a path and on stdin. The script resolves
`latest` to `$repo/releases/latest/download/claudevs-cli-installer.sh` and any other value that passes the version
check to the `claudevs-cli-v$version` release. It strips a leading `v`, treats an empty value as latest, and prints
`could not download` then exits 1 on a failed download.

**Proof:**
- `install_check_refuses_bad_versions` — written first and seen failing while the script does not exist; passes
  when all six runs exit 1 and print `is not a version`.
- `install_check_fails_on_a_broken_refusal` — with the validation branch temporarily removed, the task fails; the
  branch is then restored.

**Done when:** `cargo make install-check` passes and `cargo make dod` is green. Commit
`feat(repo): add the claudevs install pointer script`.

### Task 2 — Run the check in CI

**Files:**
- Modify `.github/workflows/ci.yml` — add an `install-pointer` job.

**Change:** The job checks out the repository, installs `shellcheck` by apt as `buildl/.github/workflows/ci.yml:147-150`
does, installs `cargo-make` as the file's `claudevs-check` job does, and runs `cargo make install-check`.

**Proof:**
- `ci_job_runs_install_check` — `grep -n 'cargo make install-check' .github/workflows/ci.yml` finds the step inside
  the `install-pointer` job.

**Done when:** that check passes and `cargo make dod` is green. Commit
`ci(repo): check the install pointer in CI`.

### Task 3 — Publish the script to Pages

**Files:**
- Create `.github/workflows/pages.yml` — from `buildl/.github/workflows/pages.yml:1-71`, without the mdBook steps.

**Change:** The workflow triggers on `main` for `install/**` and `.github/workflows/pages.yml`, and on
`workflow_dispatch`. Its workflow-level `concurrency` block stays as in `buildl`'s. Its build job copies
`install/install.sh` into a directory holding nothing else and uploads that directory. Its deploy job is unchanged
from `buildl`'s, including the `pages: write` and `id-token: write` permissions held only by that job. The header
comment names the published URL.

**Proof:**
- `pages_publishes_only_the_pointer` — `grep -in mdbook .github/workflows/pages.yml` prints nothing, and `grep -n
  'path:' .github/workflows/pages.yml` shows the directory the copy step created.
- `pages_triggers_on_the_pointer` — `grep -n -A3 'paths:' .github/workflows/pages.yml` shows exactly `install/**` and
  `.github/workflows/pages.yml`.

**Done when:** those checks pass and `cargo make dod` is green. Commit
`ci(repo): publish the install pointer to GitHub Pages`.

---

## Risks

- The URL returns the pointer's `could not download` error until the first `claudevs-cli` release exists. Spec
  section 9 records this as expected.
- Pages deploys on `main` only, so nothing in this plan can be observed live before merge. A defect in `pages.yml`,
  including a YAML error, first shows after merge; `workflow_dispatch` lets it be re-run once fixed.
- Riskiest step: Task 1's refusal check, because a failed download exits 1 as well. That is why it asserts the
  error text and Task 1 has a deliberate-break check.

## Proof

- `cargo make install-check` passes.
- `cargo make dod` is green.

## Review findings

No 🔴 in either review, so no fix round ran. Every line below is open.

Task 1:
- `Makefile.toml:467` 🟡 `install-check` covers only the refusal branch. The `latest` URL, the `claudevs-cli-v$version` URL, the `v` strip and empty-as-latest have no check, so a wrong tag prefix would first show when a user pins a version. The plan's Proof does not require one.
- `Makefile.toml:470` 🔵 the comment gives the secondary reason `plugins` sits outside the gate as its reason.
- `install/install.sh:31` 🔵 "a machine that can run one can run the other" is false for snap curl, which dist's installer refuses. Inherited from buildl.
- `install/install.sh:38` 🔵 `wget` has no https-only setting where `curl` has `--proto '=https'`, so a redirect to plain http would be followed. `--https-only` might not exist on BusyBox wget (not checked).

Task 2:
- `.github/workflows/ci.yml:93-115` 🔵 the pinned-toolchain download lands inside `cargo make install-check`; the job comment says only that it compiles nothing. The reviewer saw the rustup shim install the pin locally on rustup 1.29.1; not observed on a runner.
- `.github/workflows/ci.yml:100` 🔵 checkout keeps the read-only token persisted, as the sibling jobs do.

Task 3:
- `.github/workflows/pages.yml:22-23` 🔵 the "half-replaced" claim is inherited from buildl and could not be verified.
- 🔵 Nothing would catch a revert of the site-only copy in `pages.yml` or of the `install-pointer` job.

Reviewer verdicts: batch 1 `blocking: none`, batch 2 `blocking: none`. No workflow has run on GitHub, and `pages.yml` cannot run before merge.

## Deviations

- 2026-11-03: `install_check_fails_on_a_broken_refusal`. With only the validation branch removed, the break run would have reached github.com, so the `curl` and `wget` lines were also stubbed to `false` for that run. All temporary edits were reverted from a pre-break copy, and the re-run passed.
- 2026-11-03: Task 2. The job sets `timeout-minutes: 10`, which the plan does not name, and has no `rustup show` or cache step, because it compiles nothing.
- 2026-11-03: All tasks. The instruction to execute did not say to commit, so the commits this plan names were not made; the work is in the working tree.
- 2026-11-03: The ledger agent was not spawned because the plan text was already in the main thread when the run started. TodoWrite was not available, so tasks were tracked in the batch order.
