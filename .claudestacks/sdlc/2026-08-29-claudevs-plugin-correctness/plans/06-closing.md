---
status: draft
created: 2026-08-29
depends-on: [01, 02, 03, 04, 05]
---

# Publication Surface and Corpus Check Plan

**Goal:** Nothing this chain changed can drift unnoticed after publication.

**Architecture:** Two closing pieces, both of which need every other plan landed first. The crate
exposes 44 public enums and structs and carries exactly one `#[non_exhaustive]`, on `Error`;
publication freezes the other 43, plus the seven types plans 01, 02 and 04 add. Each is enumerated
against a five-bullet rule and the bullet it lands on is recorded, so the audit is reviewable rather
than asserted. Then the 156-root third-party corpus becomes a standing check: an `#[ignore]`d
integration test reading `corpus.toml`, a per-root snapshot, and two cargo-make lanes — one that
fetches over the network, one that runs offline. Neither lane joins `cargo make dod` or CI.

**Tech Stack:** Rust 2024, `walkdir`, `serde`, `toml`, `git` on `PATH` for the fetch lane. **No new
dependencies** — `toml` is already a workspace dependency (`Cargo.toml:62`, `toml = "1.1"`) and
already a regular dependency of this crate (`crates/claudevs/Cargo.toml:25`), where it reads
`claudevs.toml` for declared native suites. The workspace is featureless; do not add a Cargo
`[feature]` to gate the corpus test — `#[ignore]` is the gate.

**Depends on:** every other plan. The audit must see the types plans 01, 02 and 04 add, and the
snapshot records post-recalibration behaviour, so plan 05 must have landed or every row is wrong.

---

## Guideline conformance

- **`strong-types`** — a corpus row is a struct with named fields, not a tuple or a formatted string.
- **`unit-test-mandate`** — `tests/corpus.rs` is an integration test, which is structural exemption
  territory: it has no colocated unit tests because it is not a `src/*.rs` file. Any helper logic
  complex enough to want a unit test belongs in `src/`, not in the integration test.
- **`workspace`** — no dependency is added. Read both `Cargo.toml` files before assuming otherwise;
  `toml` is already there at both levels.
- **`strict-quality`** — `clippy::expect_used` is `warn` workspace-wide (root `Cargo.toml`,
  `[workspace.lints.clippy]`) and the gate runs `-D warnings`, so `.expect(...)` fails the build
  unless the enclosing module carries an `#![expect(clippy::expect_used, reason = "…")]`.
  `unwrap_used` is `deny` and `panic` is `deny`, so a test module needs those attributes too — the
  existing integration tests show the pattern. An integration test file has no enclosing `mod`, so
  the attributes go at the top of the file.
- **`doc-comment-discipline`** — the snapshot file and the runner both explain themselves in prose a
  downstream engineer can act on; no plan numbers, no workflow vocabulary.

## File map

```
crates/claudevs/src/**                        — [modify] add #[non_exhaustive] per the audit table
crates/claudevs/tests/corpus.rs               — [create] the #[ignore]d corpus runner
crates/claudevs/tests/corpus/expected.snap    — [create] one row per plugin root
crates/claudevs/tests/corpus/corpus.toml      — [unchanged] already committed
Makefile.toml                                 — [modify] corpus-fetch and corpus-check lanes
.gitignore                                    — [modify] the fetched clones and the .snap.actual
CLAUDE.md                                     — [modify] document both lanes
.claudestacks/…/surface-audit.md              — [create] the reviewable audit table
```

| File | Tasks |
|---|---|
| `surface-audit.md` (chain dir) | 1 |
| `src/**` (the audit) | 2 |
| `src/types/mod.rs` | 3 |
| `.gitignore` | 4, 7 |
| `Makefile.toml` | 4, 8 |
| `tests/corpus.rs` | 5, 6, 7 |
| `tests/corpus/expected.snap` | 7 |
| `CLAUDE.md` | 8 |

---

## Task 1 — Enumerate all 44 against the rule

This task produces a **table you can be argued with about**, before any attribute is added.

**Files:**
- No source changes. Write the table to the chain directory as
  `.claudestacks/sdlc/2026-08-29-claudevs-plugin-correctness/surface-audit.md`.

**Steps:**

1. Regenerate the list rather than trusting the one below — plans 01, 02 and 04 added types since this
   plan was written:

   ```
   $ grep -rn '^pub struct \|^pub enum ' crates/claudevs/src/
   ```

2. The five bullets, from the spec (§7):

   1. `#[non_exhaustive]` on every public **enum whose variant set is decided by Claude Code** rather
      than by us.
   2. `#[non_exhaustive]` on every public **struct callers only read** — reports, outcomes, findings,
      observations.
   3. `#[non_exhaustive]` on every public **enum we decide that callers only read**.
   4. `#[non_exhaustive]` on every **caller-constructed config struct that implements `Default`**.
   5. **Exempt**: newtypes with one validated field, and their error structs.

3. This is the classification as the code stood before this chain, with the bullet each type lands on.
   Check every row against the current source; a row you disagree with is a finding, not a typo.

   | Type | File:line | Bullet |
   |---|---|---|
   | `Error` | `error.rs:14` | 3 — already carries it |
   | `SuiteOptions` | `suite.rs:24` | 4 |
   | `CaseOutcome` | `suite.rs:31` | 2 |
   | `SuiteReport` | `suite.rs:40` | 2 |
   | `StageStatus` | `check.rs:25` | 3 |
   | `Stage` | `check.rs:36` | 2 |
   | `CheckReport` | `check.rs:47` | 2 |
   | `Validation` | `validate.rs:19` | 3 |
   | `ProbeStatus` | `doctor.rs:36` | 3 |
   | `Probe` | `doctor.rs:48` | 2 |
   | `Diagnosis` | `doctor.rs:59` | 2 |
   | `HookEvent` | `types/hook_event.rs:10` | 1 |
   | `InvalidHookEvent` | `types/hook_event.rs:28` | 5 |
   | `PluginVersion` | `types/plugin_version.rs:12` | 5 |
   | `InvalidPluginVersion` | `types/plugin_version.rs:17` | 5 |
   | `PluginName` | `types/plugin_name.rs:11` | 5 |
   | `InvalidPluginName` | `types/plugin_name.rs:16` | 5 |
   | `MarketplaceName` | `types/marketplace_name.rs:12` | 5 |
   | `InvalidMarketplaceName` | `types/marketplace_name.rs:17` | 5 |
   | `CaseName` | `types/case_name.rs:8` | 5 |
   | `InvalidCaseName` | `types/case_name.rs:13` | 5 |
   | `NativeOutcome` | `native/declared.rs:24` | 2 |
   | `PluginManifest` | `layout/manifest.rs:22` | 2 |
   | `Installed` | `layout/installed.rs:26` | 2 |
   | `Severity` | `wiring/finding.rs:11` | 3 |
   | `Finding` | `wiring/finding.rs:20` | 2 |
   | `WiringReport` | `wiring/finding.rs:35` | 2 |
   | `FencedCommand` | `wiring/invocations.rs:33` | 2 |
   | `Observed` | `harness/semantics.rs:19` | 2 |
   | `Captured` | `harness/spawn.rs:18` | 2 |
   | `Project` | `harness/project.rs:13` | 2 |
   | `Verdict` | `harness/verdict.rs:13` | 3 |
   | `TModule` | `harness/t_module.rs:58` | **unclassified — raise it** |
   | `LuaFile` | `case/lua.rs:19` | 2 |
   | `CaseFile` | `case/discover.rs:14` | 3 |
   | `FixtureRef` | `case/model.rs:16` | **unclassified — raise it** |
   | `Invocation` | `case/model.rs:21` | **unclassified — raise it** |
   | `Decision` | `case/model.rs:32` | 3 |
   | `Expectations` | `case/model.rs:48` | 4 |
   | `Step` | `case/model.rs:91` | 2 |
   | `CaseKind` | `case/model.rs:105` | 3 |
   | `Case` | `case/model.rs:131` | 2 |
   | `RawCase` | `case/model.rs:150` | 2 |
   | `ProjectField` | `case/model.rs:180` | 3 |

   Plus the types this chain adds — classify each the same way:

   | Type | Added by | Bullet | Action |
   |---|---|---|---|
   | `DocumentedEvent` | `contract/event.rs` | 2 | verify — plan 01 already added it |
   | `MatcherSupport` | `contract/event.rs` | 1 | **add** |
   | `DecisionMechanism` | `contract/event.rs` | 1 | verify — plan 01 already added it |
   | `MatcherRule` | `contract/matcher.rs` | 3 | **add** |
   | `HookCommand` | `contract/handler.rs` | 1 | verify — plan 01 already added it |
   | `Strictness` | `validate.rs` | 4 | **add** |
   | `Mismatch` | `harness/verdict.rs` | 3 | verify — plan 04 already added it |

   `Strictness` is bullet 4, not 3: `crates/claudevs-cli` constructs it
   (`claudevs::Strictness::Strict`), so it is not a type callers only read. It has a `Default`
   (`Lenient`), which is what bullet 4 requires — but a fieldless enum has nothing to add a field to,
   so if you conclude bullet 4 does not really cover it either, that is a fourth unclassified type and
   belongs in step 4's list.

4. **Three types fit no bullet, and that is a signal the rule is short a bullet — not licence to decide
   them by hand.** Work out which it is and raise it:

   - **`FixtureRef` (`case/model.rs:16`)** is `pub struct FixtureRef(pub String)` — a newtype, which
     bullet 5 exempts, except that bullet 5 says "with one **validated** field" and this field is `pub`
     and unvalidated. So it is either a newtype that should validate (and then bullet 5 applies), or a
     transparent wrapper that is not a newtype at all (and then bullet 2 does).
   - **`Invocation` (`case/model.rs:21`)** is caller-constructed and deserialized. Bullet 4 covers
     caller-constructed config structs *that implement `Default`*; check whether this one does. If it
     does, bullet 4. If it does not, the spec's own note applies: "a config struct without one would be
     left open and given a builder instead" — which is a decision, not an attribute.
   - **`TModule` (`harness/t_module.rs:58`)** is the Lua-side test module. Read the file and work out
     whether a caller constructs it or only reads it, then classify.

   Report all three with your reading before Task 2. Do not silently pick.

5. Write the table to `surface-audit.md` with a one-line note per row where the bullet is not obvious.
   That file is the reviewable artefact; the attributes in Task 2 are its consequence.

6. Commit `docs(repo): enumerate the claudevs public surface against the publication rule`.

---

## Task 2 — Add the attribute where the audit says

**Files:**
- Modify every file the Task 1 table names.

**Steps:**

1. Understand what the attribute does before adding it, because two of its effects are behavioural:

   - On a **struct**, `#[non_exhaustive]` stops downstream crates constructing it with a literal or
     with functional-record-update. Inside this crate, literals still work — so
     `Expectations { exit: Some(0), ..Expectations::default() }` in a `#[cfg(test)]` module keeps
     compiling, and `crates/claudevs-cli` does **not**, because it is a separate crate.
   - On an **enum**, it forces downstream `match`es to carry a wildcard arm.

   `crates/claudevs-cli/src/cli.rs:84` writes `claudevs::SuiteOptions { case_filter: case }` as a
   literal. That stops compiling the moment `SuiteOptions` becomes non-exhaustive. Rewrite it as:

   ```rust
   let mut options = claudevs::SuiteOptions::default();
   options.case_filter = case;
   ```

   That is the whole point of bullet 4: routing construction through `Default` is what makes adding a
   field non-breaking later. Expect to find two or three such sites; find them all with:

   ```
   $ cargo build -p claudevs-cli 2>&1 | grep -A3 'cannot create non-exhaustive'
   ```

   **Check clippy before settling on that shape.** `clippy::field_reassign_with_default` lints exactly
   this pattern, and `cargo clippy … -D warnings` is step 2 of the Definition of Done while this plan's
   own `strict-quality` line forbids an `#[allow]` to silence it. The lint is documented as not firing
   on `#[non_exhaustive]` structs, since there is no alternative — verify that on the version in
   `rust-toolchain.toml` rather than trusting it. If it does fire, the fallback is a constructor on the
   type rather than a suppression:

   ```rust
   impl SuiteOptions {
       /// Options that run every case.
       #[must_use]
       pub fn new() -> Self {
           Self::default()
       }

       /// Only run cases whose name contains `filter`.
       #[must_use]
       pub fn with_case_filter(mut self, filter: Option<String>) -> Self {
           self.case_filter = filter;
           self
       }
   }
   ```

   which reads better at the call site anyway and keeps the type closed.

2. Add the attributes, one commit per bullet so the diff is readable:

   ```rust
   #[derive(Debug, Clone, serde::Serialize)]
   #[non_exhaustive]
   pub struct CheckReport {
   ```

   The attribute goes **below** the derives and above the item, matching `error.rs:13-14`.

3. After each bullet's batch, run:

   ```
   $ cargo clippy --workspace --all-targets --all-features -- -D warnings
   ```

   and fix every construction site the compiler names. Do not add `#[allow]`; the whole point is that
   the compiler is telling you where a caller was relying on the surface being frozen.

4. Confirm the attribute actually bites. Write a throwaway file under
   `crates/claudevs-cli/src/` that constructs one of the newly-closed structs as a literal, build, and
   read the error:

   ```
   error[E0639]: cannot create non-exhaustive struct using functional update syntax
   ```

   Delete the throwaway. A `#[non_exhaustive]` that has never been observed rejecting anything is an
   attribute nobody has tested.

5. Run the full gate:

   ```
   $ cargo make dod
   ```

6. Commit in bullet-sized pieces:
   - `feat(claudevs): mark the Claude-Code-decided enums non-exhaustive`
   - `feat(claudevs): mark the read-only report structs non-exhaustive`
   - `feat(claudevs): mark the read-only enums non-exhaustive`
   - `feat(claudevs): route config-struct construction through Default`

---

## Task 3 — Record the exemptions in the source

**Files:**
- Modify `crates/claudevs/src/types/mod.rs`

**Steps:**

1. Ten of the 44 are bullet-5 exempt — the five validating newtypes and their five error structs, all
   in `types/`. The exemption is a decision, and a decision that lives only in a chain artefact is a
   decision the next reader has to re-derive.

2. Add to `crates/claudevs/src/types/mod.rs`'s module doc:

   ```rust
   //! Validating newtypes for claudevs domain values.
   //!
   //! None of these carries `#[non_exhaustive]`, deliberately. Each wraps one
   //! validated field and its invariant is the whole type: there is nothing to
   //! add to a `PluginName` that is not a different type. The same holds for
   //! their error structs, which carry the rejected value and nothing else. Every
   //! other public type in this crate is closed, so this file is where the
   //! exception is written down.
   ```

3. Run the doc gate:

   ```
   $ RUSTDOCFLAGS="-D warnings" cargo doc --workspace --all-features --no-deps
   ```

4. Commit `docs(claudevs): record why the validating newtypes stay open`.

---

## ◆ CHECKPOINT — stop here and report

The surface is frozen. Report before starting the corpus work:

- the three unclassified types and what you concluded about each
- every construction site the compiler rejected, and how you rewrote it
- the throwaway that proved the attribute bites, and its exact error text
- whether the regenerated list still came to 44 before this chain's additions

Wait for a go-ahead. Do not start Task 4.

---

## Task 4 — The fetch lane

**Files:**
- Modify `.gitignore`
- Modify `Makefile.toml`

**Steps:**

1. Read `crates/claudevs/tests/corpus/corpus.toml`. Thirteen `[[repo]]` tables, each with `name`,
   `url`, `sha`, `branch` and a `plugins` list of paths relative to the repository root. `"."` means
   the repository root is itself the plugin, which is true for three of the thirteen. Two repositories
   have an empty `plugins` list; the fetch must still clone them, and the runner must produce no rows
   for them.

2. Add the clone destination to `.gitignore`. Under `target/`, so nothing about it is committed and
   `cargo clean` disposes of it:

   ```
   # Third-party plugin corpus, fetched on demand by `cargo make corpus-fetch`.
   /target/corpus/
   ```

   Check whether `.gitignore` already ignores `/target` wholesale — if it does, this entry is
   redundant and you should say so rather than adding a second one.

3. Add the lane to `Makefile.toml`, following the shape of the existing `claudevs-check` lane at
   `:165`:

   ```toml
   [tasks.corpus-fetch]
   category = "Plugin suite"
   description = "Clone the pinned third-party plugin corpus into target/corpus"
   # The only step in this repository that touches the network. It is never a
   # dependency of `dod`, never runs in CI, and is run before a release rather
   # than on every commit — the corpus is pinned by commit SHA rather than
   # vendored, which keeps repository weight at zero (vendoring measured 19 MB
   # for all 156 roots) and keeps the published .crate clear of the crates.io
   # size ceiling. The cost of that choice is exactly this: a check nobody is
   # obliged to run guards by convention.
   #
   # A pinned SHA is re-fetchable while the commit stays reachable. A repository
   # that is deleted, made private, or force-pushed makes its row a record of
   # what was tested rather than something re-runnable. That is expected; report
   # such a row as unfetchable rather than repinning it silently.
   script_runner = "@shell"
   script = '''
   set -eu
   manifest="crates/claudevs/tests/corpus/corpus.toml"
   dest="target/corpus"
   mkdir -p "$dest"

   # There is no TOML parser in the shell, and the manifest does not need one:
   # every [[repo]] block carries name, url and sha on their own lines, in that
   # order, because the generator that wrote the file emits exactly that shape.
   # awk reduces it to `name<TAB>url<TAB>sha` and the loop below does the rest.
   awk -F'"' '
     /^name = "/ { name = $2 }
     /^url = "/  { url  = $2 }
     /^sha = "/  { print name "\t" url "\t" $2 }
   ' "$manifest" | while IFS="$(printf '\t')" read -r name url sha; do
     slug=$(printf '%s' "$name" | tr '/' '_')
     repo="$dest/$slug"

     if [ -d "$repo/.git" ] && [ "$(git -C "$repo" rev-parse HEAD 2>/dev/null)" = "$sha" ]; then
       printf 'ok    %s @ %s\n' "$name" "$sha"
       continue
     fi

     rm -rf "$repo"
     mkdir -p "$repo"
     git -C "$repo" init -q
     git -C "$repo" remote add origin "$url"
     # A pinned SHA is fetchable directly while the commit stays reachable. A
     # repository that was deleted, made private, or force-pushed fails here,
     # and that is the honest outcome: its row records what was tested rather
     # than something re-runnable. Report it; do not repin it.
     if git -C "$repo" fetch -q --depth 1 origin "$sha" 2>/dev/null; then
       git -C "$repo" checkout -q FETCH_HEAD
       printf 'fetched %s @ %s\n' "$name" "$sha"
     else
       printf 'UNFETCHABLE %s @ %s (deleted, private, or force-pushed)\n' "$name" "$sha" >&2
       rm -rf "$repo"
     fi
   done
   '''
   ```

   The lane is idempotent: a repository already at the right SHA is skipped rather than re-cloned. It
   does **not** exit non-zero on an unfetchable repository — the whole corpus should not become
   unusable because one upstream vanished — but it prints `UNFETCHABLE` to stderr, and Task 6's runner
   is what turns a missing clone into a visible gap in the sweep.

   Verify the awk stage on its own before running the whole lane:

   ```
   $ awk -F'"' '/^name = "/{n=$2} /^url = "/{u=$2} /^sha = "/{print n"\t"u"\t"$2}' \
       crates/claudevs/tests/corpus/corpus.toml | wc -l
   13
   ```

4. Run it and confirm all thirteen land:

   ```
   $ cargo make corpus-fetch
   $ ls target/corpus | wc -l
   13
   ```

5. Commit `build(repo): add the corpus fetch lane`.

---

## Task 5 — The runner reads the manifest

**Files:**
- Create `crates/claudevs/tests/corpus.rs`

**Steps:**

1. Confirm the dependency you need is already there, and add nothing:

   ```
   $ grep -n toml Cargo.toml crates/claudevs/Cargo.toml
   Cargo.toml:62:toml               = "1.1"
   crates/claudevs/Cargo.toml:25:toml          = { workspace = true }
   ```

   `toml` is a regular dependency of this crate already — it reads `claudevs.toml` for declared native
   suites — so an integration test reaches it without a `[dev-dependencies]` entry. Adding
   `toml = "0.8"` to `[workspace.dependencies]` would be a duplicate key, which Cargo refuses outright,
   and a downgrade besides.

   Only two lint attributes, not three. The finished file (Tasks 5, 6 and 7) uses `.expect(…)`,
   `unwrap_or_default()` and `.ok()`, but no bare `.unwrap()` — and neither `unwrap_or_default` nor
   `ok` fulfils `clippy::unwrap_used`, so an `#![expect(clippy::unwrap_used, …)]` here would be
   unfulfilled and fire `unfulfilled_lint_expectations`. Add it only if you end up writing a real
   `.unwrap()`.

2. Write the runner's manifest half first, with a test that asserts the file parses to the numbers its
   own header claims. The file-level attributes come first: `clippy::unwrap_used` is `deny` and
   `panic` is `deny` workspace-wide, and an integration test has no enclosing module to hang them on:

   ```rust
   //! The third-party plugin corpus: 156 plugin roots across 13 repositories
   //! nobody in this repository wrote.
   //!
   //! `tests/fixtures/` holds plugins written here, by the same hand as the code
   //! they exercise, so they encode the same assumptions and cannot disconfirm
   //! them. This corpus answers the other question — whether that intent survives
   //! contact with plugins written by people who had never heard of claudevs.
   //!
   //! Ignored by default and absent by default: the clones live under
   //! `target/corpus`, fetched by `cargo make corpus-fetch`, which is the only
   //! step in this repository that touches the network. `cargo test` neither runs
   //! this nor fails when the corpus is missing; `cargo make corpus-check`
   //! reaches it with `--ignored`.

   #![expect(clippy::expect_used, reason = "a test names what it required in the panic")]
   #![expect(clippy::panic, reason = "tests panic to reject an unexpected shape")]

   use std::path::{Path, PathBuf};

   /// One pinned repository from the corpus manifest.
   #[derive(Debug, serde::Deserialize)]
   struct Repo {
       name: String,
       url: String,
       sha: String,
       branch: String,
       plugins: Vec<String>,
   }

   /// The manifest file.
   #[derive(Debug, serde::Deserialize)]
   struct Manifest {
       repo: Vec<Repo>,
   }

   /// The manifest, read from the committed file beside this test.
   fn load_manifest() -> Manifest {
       let text = std::fs::read_to_string(
           Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/corpus/corpus.toml"),
       )
       .expect("tests/corpus/corpus.toml");
       toml::from_str(&text).expect("corpus.toml is valid TOML")
   }

   #[test]
   fn the_manifest_describes_thirteen_repositories_and_one_hundred_fifty_six_roots() {
       let manifest = load_manifest();
       assert_eq!(manifest.repo.len(), 13);
       let roots: usize = manifest.repo.iter().map(|r| r.plugins.len()).sum();
       assert_eq!(roots, 156);
   }
   ```

   This test carries **no** `#[ignore]`, unlike every other test in the file. It reads only the
   committed manifest and needs no clone, so `cargo test` can catch a manifest edited into an
   inconsistent state. Note the exception in the commit body — a reader meeting one un-ignored test in
   a file of ignored ones will wonder why.

3. Run it without `--ignored`, since it is not ignored:

   ```
   $ cargo test -p claudevs --test corpus
   test the_manifest_describes_thirteen_repositories_and_one_hundred_fifty_six_roots ... ok

   test result: ok. 1 passed; 0 failed; 0 ignored
   ```

4. Commit `test(claudevs): read the corpus manifest`.

   Do not stage a `Cargo.toml` change; there is none.

---

## Task 6 — The runner sweeps every root

**Files:**
- Modify `crates/claudevs/tests/corpus.rs`

**Steps:**

1. The snapshot's line format, which the code below produces. One line per plugin root, with any
   findings on continuation lines indented two spaces, so a root that reports nothing occupies exactly
   one line and a diff reads as one line per changed root:

   ```
   anthropics/claude-code  plugins/hookify  validate=Skipped wiring=Passed test=Skipped test--installed=Skipped
   obra/superpowers  .  validate=Skipped wiring=Failed test=Skipped test--installed=Skipped
     Error refs skills/plugin-authoring/SKILL.md `${CLAUDE_PLUGIN_ROOT}/scripts/format.sh` does not exist
   ```

   Order is the manifest's, not sorted: the manifest is committed and stable, so its order is already
   deterministic, and re-sorting would only hide which repository a run stopped in.

2. Add the four functions that produce it. Task 7's comparison test calls `sweep()` and
   `snapshot_path()`, so both are defined here:

   ```rust
   /// Where the snapshot lives.
   fn snapshot_path() -> PathBuf {
       Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/corpus/expected.snap")
   }

   /// The fetched clones.
   ///
   /// A `#[ignore]`d test that was explicitly asked for with `--ignored` and
   /// then finds nothing must fail rather than pass quietly — the caller asked
   /// for the corpus check, and a silent pass is the shape of false green this
   /// whole corpus exists to catch.
   fn corpus_root() -> PathBuf {
       let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../target/corpus");
       assert!(
           root.is_dir(),
           "the corpus is not fetched; run `cargo make corpus-fetch` ({} is absent)",
           root.display()
       );
       root
   }

   /// Sweeps every plugin root the manifest names, rendered as the snapshot.
   ///
   /// Deterministic: repositories in manifest order, plugin roots in the order
   /// the manifest lists them, so a diff against the snapshot shows only what
   /// changed in behaviour.
   fn sweep() -> String {
       let manifest = load_manifest();
       let corpus = corpus_root();
       let mut rows = Vec::new();

       for repo in &manifest.repo {
           let slug = repo.name.replace('/', "_");
           let checkout = corpus.join(&slug);
           for plugin in &repo.plugins {
               let root = if plugin == "." {
                   checkout.clone()
               } else {
                   checkout.join(plugin)
               };
               rows.push(render_row(&repo.name, plugin, &root));
           }
       }
       rows.join("")
   }

   /// One plugin root's row, plus an indented line per finding.
   ///
   /// A row per root rather than a list of findings. After recalibration the
   /// whole corpus emits roughly two findings, and a two-line snapshot cannot
   /// tell "correctly quiet" from "the checker panicked and reported nothing" —
   /// which is the same blind spot as a test that has only ever been green,
   /// rebuilt inside the mechanism meant to catch it. Every root carries the
   /// outcome of every stage, so a checker going silent moves 156 rows.
   fn render_row(repo: &str, plugin: &str, root: &Path) -> String {
       if !root.is_dir() {
           return format!("{repo}  {plugin}  ABSENT\n");
       }
       // Lenient, matching what `claudevs check` does by default. A strict run
       // would record the delegate's style opinions, which are not what this
       // corpus is watching.
       let report = match claudevs::check::run(root, claudevs::Strictness::Lenient) {
           Ok(report) => report,
           Err(error) => return format!("{repo}  {plugin}  ERROR {error}\n"),
       };
       let stages: Vec<String> = report
           .stages
           .iter()
           .map(|stage| format!("{}={:?}", stage.name.replace(' ', ""), stage.status))
           .collect();
       let mut row = format!("{repo}  {plugin}  {}\n", stages.join(" "));

       let wiring = claudevs::wiring::run(root).unwrap_or_default();
       for finding in &wiring.findings {
           row.push_str(&format!(
               "  {:?} {} {} {}\n",
               finding.severity, finding.checker, finding.file, finding.message
           ));
       }
       row
   }
   ```

   Two things to check against the code before running this. `claudevs::wiring::run` returns
   `Result<WiringReport>`; `unwrap_or_default()` needs `WiringReport: Default`, which
   `crates/claudevs/src/wiring/finding.rs:35` may or may not derive — read it and use an explicit
   `match` if it does not. And `Stage::status` is a `StageStatus`, formatted here with `{:?}`; if plan
   06 Task 2 made that enum `#[non_exhaustive]` it still derives `Debug`, so this keeps working.

   Calling `wiring::run` a second time repeats work `check::run` already did. That is deliberate:
   `CheckReport` carries the wiring stage's *rendered* text as an opaque `detail` string
   (`crates/claudevs/src/check.rs:99`), not the `Finding` list, and a snapshot built from rendered
   prose would move every time the renderer's wording changed. Say so in a comment.

3. Run the sweep and capture its output. It runs `claudevs check` 156 times, each spawning the `claude`
   delegate; on a machine where `claude` is absent the validate stage skips and it is fast, and on a
   machine where it is present this is minutes rather than seconds. Say so in the lane's description
   (Task 8) so nobody runs it expecting `cargo test` speed.

4. Commit `test(claudevs): sweep every corpus plugin root`.

---

## Task 7 — The snapshot

**Files:**
- Create `crates/claudevs/tests/corpus/expected.snap`
- Modify `crates/claudevs/tests/corpus.rs`

**Steps:**

1. Generate the snapshot from a sweep, review it by hand, then commit it. Reviewing it is not optional:
   this is the artefact that decides what "correct" means for 156 plugins, and generating it from a run
   you have not read is how a recalibration bug becomes the baseline.

2. What to look for in the review, from the spec's expected end state:

   - `refs` errors across the whole corpus: **1** — the "Red Flags" prose advice in
     `skills/plugin-authoring/SKILL.md`, which is the accepted residual.
   - `invocations` warnings: **1** — the shebanged `optimize-prompt.py` under `scripts/` that nothing
     references, which is the genuine finding the check exists for.
   - `matchers` errors: **0**. Some warnings are expected — an unknown event name from a plugin using a
     newer event than the catalogue, or a matcher on an event that takes none.

   If the sweep produces materially different numbers, **stop and report** rather than committing the
   snapshot. A snapshot that encodes a wrong baseline is worse than no snapshot: every future diff is
   then measured against it.

3. Add the comparison test:

   ```rust
   #[test]
   #[ignore = "needs the corpus fetched by `cargo make corpus-fetch`"]
   fn the_corpus_reports_exactly_what_the_snapshot_records() {
       let actual = sweep();
       let expected = std::fs::read_to_string(snapshot_path()).expect("expected.snap");
       if actual != expected {
           // Write the actual to a sibling file so the diff is one command away,
           // rather than making the reader reconstruct it from assertion output
           // 156 rows long.
           std::fs::write(snapshot_path().with_extension("snap.actual"), &actual).ok();
           panic!(
               "the corpus no longer reports what the snapshot records.\n\
                diff {} {}",
               snapshot_path().display(),
               snapshot_path().with_extension("snap.actual").display(),
           );
       }
   }
   ```

   Add the scratch file to `.gitignore`, beside the corpus entry from Task 4:

   ```
   # Written by the corpus check when the sweep and the snapshot disagree.
   /crates/claudevs/tests/corpus/expected.snap.actual
   ```

4. **See it fail.** Edit one row of `expected.snap` — change a `passed` to `failed` — re-run, and
   confirm the test goes red and writes the `.actual` file. Restore the row. A snapshot test that has
   only ever been green is exactly the instrument this chain exists to distrust.

5. Commit `test(claudevs): pin the corpus sweep with a per-root snapshot`.

---

## Task 8 — The check lane, and the docs that describe it

**Files:**
- Modify `Makefile.toml`
- Modify `CLAUDE.md`

**Steps:**

1. Add the offline lane:

   ```toml
   [tasks.corpus-check]
   category = "Plugin suite"
   description = "Sweep the fetched third-party corpus and compare against the snapshot (slow; needs corpus-fetch)"
   # Not a dependency of `dod` and not in CI, for the reason the corpus is
   # pinned rather than vendored: the clones are not in the repository, so this
   # lane cannot run on a checkout alone. It is run before a release.
   #
   # This is the second corpus, not a replacement for the first.
   # `cargo make claudevs-check` runs the hand-authored fixtures in
   # crates/claudevs/tests/fixtures/ in both directions and stays exactly as it
   # is: those fixtures pin the behaviour claudevs intends, and they are cheap
   # and unskippable. This one answers the different question — whether that
   # intent survives contact with plugins nobody here wrote.
   command = "cargo"
   args = ["test", "-p", "claudevs", "--test", "corpus", "--", "--ignored", "--nocapture"]
   ```

   Name it to match the existing `<thing>` / `<thing>-<verb>` convention in `Makefile.toml`. Read the
   file's existing task names before settling on `corpus-fetch` / `corpus-check`; if the convention
   there is verb-first, follow that instead.

2. Verify the lane is genuinely outside the gate:

   ```
   $ cargo make dod
   ```

   Confirm from the output that neither corpus lane ran. If `cargo make dod` picks them up, the lanes
   have a `dependencies` entry they should not.

3. Add the corpus to `CLAUDE.md`'s Commands section, beside the paragraph describing
   `cargo make claudevs-check`. It should say what the corpus is, that `corpus-fetch` is the only
   network step in the repository, that neither lane is in `dod` or CI, and that it is run before a
   release. Keep it to a short paragraph; that file is already long.

4. Confirm the published package is unaffected:

   ```
   $ cargo package -p claudevs --list --allow-dirty | grep corpus
   tests/corpus/corpus.toml
   tests/corpus/expected.snap
   ```

   The paths are package-relative, not workspace-relative.

   Both are small text files. If `cargo package` reports anything under `target/corpus`, the
   `.gitignore` entry from Task 4 did not take.

5. Commit `build(repo): add the corpus check lane and document both`.

---

## Done when

- `cargo make dod` is green with zero warnings, and neither corpus lane runs as part of it.
- `cargo make corpus-fetch` then `cargo make corpus-check` is green from a clean `target/`.
- Every public enum and struct either carries `#[non_exhaustive]` or is named in
  `types/mod.rs`'s exemption paragraph. There is no third category.
- `surface-audit.md` records the bullet for all 44 plus this chain's additions, and the three
  unclassified types were raised rather than decided.
- The snapshot was reviewed by hand before it was committed, and was watched go red when a row was
  edited.
- `cargo package -p claudevs --list` shows only `tests/corpus/corpus.toml` and
  `tests/corpus/expected.snap`.
