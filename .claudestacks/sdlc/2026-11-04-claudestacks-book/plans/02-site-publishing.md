---
status: done
created: 2026-11-04
depends-on: [01]
built-on: bdf14ebffb48
---

# Site publishing Implementation Plan

**Goal:** Publish the book beside `install.sh`, with every pull request building it first.

**Architecture:** `pages.yml` keeps its two jobs and its Actions artifact. The build job now builds the book and copies `install/install.sh` into the output, the way `../airsl/.github/workflows/pages.yml` does for its own installers. Pages already deploys from Actions (`gh api repos/airsstack/claudestacks/pages --jq .build_type` → `workflow`, spec section 1), so no repository setting changes.

**Tech Stack:** GitHub Actions, mdBook 0.4.52, mdbook-mermaid 0.16.2.

**Content authority:** `spec.md` section 2.

---

## Files that change

```
.github/workflows/pages.yml  — modify: build and publish the book with install.sh
.github/workflows/ci.yml     — modify: add a book job
```

## Order of work

### Task 1 — Publish the book with install.sh

**Files:**
- Modify `.github/workflows/pages.yml` — the path filter becomes `book/**`, `install/**`, `.github/workflows/pages.yml`. In the build job, replace the `Add the install pointer` step at `:38-41` with these steps: install `mdbook@0.4.52,mdbook-mermaid@0.16.2` through `taiki-e/install-action@v2`, run `mdbook build book`, run `cp install/install.sh book/book/`. Upload path becomes `book/book`. Rewrite the header comment, which today says `install.sh` is the only file served. The deploy job and its `needs: build` (`:49`) do not change.

**Change:** A push to `main` touching the book or the installer publishes the book at `/claudestacks/` with `install.sh` still at `/claudestacks/install.sh`. A failed book build stops before deploy.

**Proof:** the workflow runs only on `main`, so the proof here is its build steps run by hand.
- `mdbook build book` exits 0.
- `cp install/install.sh book/book/` exits 0, and `test -f book/book/install.sh` and `test -f book/book/index.html` both pass.
- `grep -n 'site/' .github/workflows/pages.yml` prints nothing.

**Done when:** those commands pass and the Definition of Done is green (`cargo make dod`). Commit `ci(repo): publish the book beside install.sh`.

### Task 2 — Build the book on pull requests

**Files:**
- Modify `.github/workflows/ci.yml` — add a `book` job after `deny`, shaped like `../buildl/.github/workflows/ci.yml:187-205`: `ubuntu-latest`, 10-minute timeout, checkout, install `mdbook@0.4.52,mdbook-mermaid@0.16.2`, run `mdbook build book`. Its comment says the versions stay in step with `pages.yml` and the book tasks in `Makefile.toml`.

**Change:** A pull request that breaks the book fails CI before it reaches `main`.

**Proof:**
- `grep -n 'mdbook build book' .github/workflows/ci.yml .github/workflows/pages.yml` prints one line for each file.
- `grep -c 'mdbook@0.4.52,mdbook-mermaid@0.16.2' .github/workflows/ci.yml` prints 1, and the same for `pages.yml`.

**Done when:** those commands pass and the Definition of Done is green (`cargo make dod`). Commit `ci(repo): build the book on pull requests`.

---

## Risks

- A token without the `workflow` scope cannot push these two files; the root `CLAUDE.md` describes the silent rejection. An SSH remote sidesteps it, and `git remote -v` prints `git@github.com:airsstack/claudestacks.git`.
- Neither workflow can run from this branch. Their first real run is after merge, which is why plan 13 names the two `curl` checks for the author.

## Proof

- `cargo make book-build` exits 0.
- `cargo make dod` exits 0.

## Review findings

Reviewed together with plan 01: no blocking findings. `cargo make dod` exit 0, `cargo make book-build` exit 0.

- Open, risk: `.github/workflows/pages.yml:51`, nothing fails if the `cp install/install.sh book/book/` step is removed, because the CI `book` job does not run it. The first sign is the installer URL returning 404 after a merge.
- Open, nit: `.github/workflows/pages.yml:42`, the step "Install mdBook" installs two tools and has no comment keeping its versions in step with `ci.yml` and `Makefile.toml`.

## Deviations

- 2026-11-04: The Commit lines were not run during execution, which the instruction did not ask for. The author asked for the commits afterwards, with these messages: `ci(repo): publish the book beside install.sh` and `ci(repo): build the book on pull requests`.
