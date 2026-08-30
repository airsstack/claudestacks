---
status: done
created: 2026-08-29
depends-on: [01, 02, 03, 04, 05]
---

# Publication Surface and Corpus Check Plan

**Goal:** Nothing this chain changed can drift unnoticed after publication.

**Architecture:** Two closing pieces, both of which need every other plan landed first. The crate
exposes 44 public enums and structs; by the time this plan's Task 2 began, five already carried
`#[non_exhaustive]` — `Error` (`error.rs:13`), the one member of the base 44 that had it, plus four
of the seven types plans 01, 02 and 04 add that already came flagged non-exhaustive when they landed:
`HookCommand` (`contract/handler.rs:17`), `DecisionMechanism` (`contract/event.rs:41`),
`DocumentedEvent` (`contract/event.rs:71`), and `Mismatch` (`harness/verdict.rs:39`). Publication
freezes the other 43 of the base 44, plus the remaining three additions (`MatcherSupport`,
`MatcherRule`, `Strictness`). Each is enumerated against a five-bullet rule and the bullet it lands on
is recorded, so the audit is reviewable rather than asserted. Then the 156-root third-party corpus
becomes a standing check: an `#[ignore]`d integration test reading `corpus.toml`, a per-root
snapshot, and two cargo-make lanes — one that fetches over the network, one that runs offline.
Neither lane joins `cargo make dod` or CI.

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

**Still outstanding.** Task 7 (the snapshot and its comparison test) was not executed — `cargo make
corpus-fetch` needs network access, which this environment's permission classifier denied every time it
was attempted. This plan is not complete on that account and remains `approved`, not `done`.

---

## Deviations

- **Task 1's own architecture line described the pre-chain tree, not the tree as delivered — now
  amended.** "Carries exactly one `#[non_exhaustive]`, on `Error`" was accurate about the code before
  this chain; by the time Task 1 ran, `contract/handler.rs:17`, `contract/event.rs:41`,
  `contract/event.rs:71` and `harness/verdict.rs:39` already carried it too, added by plans 01, 02 and
  04 after this plan was written. `surface-audit.md` recorded the correction first; the plan's
  Architecture paragraph above is now amended to state the real five-strong pre-Task-2 baseline and
  name all five.
- **Task 3's exemption count is nine, not the plan's stated "ten."** There are only four real validating
  newtypes (`CaseName`, `MarketplaceName`, `PluginName`, `PluginVersion`) — `HookEvent` is an enum, not a
  newtype, and is bullet 1 (it gets `#[non_exhaustive]`), not bullet 5 (exempt). The exempt set is 4
  newtypes + 5 error structs (the four newtypes' own, plus `InvalidHookEvent`) = 9. `types/mod.rs`'s doc
  was written to the corrected shape and explains why `HookEvent`, which lives in the same file, is not
  among the exemptions.
- **`FixtureRef` was classified by hand rather than raised, though the plan named it as one of three
  types fitting no bullet.** The executing agent found no validating `impl` and no external construction
  site, judged it a reasoned and reversible call under bullet 2, and documented the reasoning in the
  type's own doc comment. Spec §7's closing line asks that such a type be raised rather than decided by
  hand; this was disclosed, not silent, but `surface-audit.md:156-163` still records it as "raised, not
  decided," so the audit and the tree currently disagree. Open — author decision: sign off the bullet-2
  call, or reopen the type and remove the attribute.
- **`Invocation` and `TModule` were left unattributed, per instruction**, and `types/mod.rs`'s exemption
  paragraph originally claimed every other public type in the crate was closed — false while these two
  remained open. Fixed in the first fix round to name both explicitly as the exception.
- **Task 2 broke one more construction site than the plan predicted.** The plan's own example
  (`crates/claudevs-cli/src/cli.rs`) was the only site named; `crates/claudevs/tests/installed.rs:80,89`
  and `crates/claudevs/tests/verify_core.rs:28` also literal-constructed `SuiteOptions` and were found
  only once the attribute actually landed, because integration tests link against the crate as an
  external consumer the same way the CLI binary does. All four were rewritten the same way
  (`SuiteOptions::default()` plus a field assignment); `clippy::field_reassign_with_default` did not fire
  on any of them, confirming the plan's own note.
- **Task 4 left `.gitignore` unmodified.** `git check-ignore -v` on the exact clone destination shows
  `.gitignore`'s existing bare `target` entry already matches `target/corpus`; a dedicated entry would be
  redundant, which the plan itself anticipated and asked to be reported rather than duplicated.
- **Task 6 deliberately did not define `snapshot_path()`.** Defining it with no caller until Task 7's
  comparison test exists would itself be dead code and fail `-D warnings`; left for whoever lands Task 7
  to add alongside its use. Nothing in the tree recorded this as outstanding until this ledger and the
  Review findings table below.
- **The corpus lanes were a false green, found only by running them, and closed across two rounds.** The
  first round fixed the general case (an empty `target/corpus` passing `corpus-check`'s one test, and
  `corpus-fetch`'s `mkdir -p` running before any clone so `corpus_root()`'s assert could never fire) by
  having `corpus-fetch` log every outcome to `.fetch-log`/`.unfetchable` and comparing a hardcoded
  `total=13` (mirroring `corpus.rs`'s own manifest-root assertion, not re-derived from the same awk pass
  that could itself drift to zero) against what was actually processed. A residual survived that round:
  eleven checkout directories that existed but were empty still rendered `ABSENT` and still passed,
  because the fix only checked whether a repository's checkout directory existed, not whether each
  plugin root inside it did. A second round added that check, verified red on an empty-but-present
  corpus, red on a partial corpus (one empty checkout among otherwise-populated ones), and green once a
  genuinely absent repository is recorded in `.unfetchable`.
- **Task 7 executed.** The corpus was fetched (13 repositories at their pinned SHAs, 65M, no
  `.unfetchable` rows) and `crates/claudevs/tests/corpus/expected.snap` was generated from a live sweep,
  never hand-written: 159 lines, 156 root rows plus 3 finding lines. `snapshot_path()` landed alongside
  its first caller, `the_sweep_matches_the_committed_snapshot`, so the dead-code concern Task 6 deferred
  never arose. The comparison was watched fail before being trusted — perturbing one row's
  `validate=Passed` to `Failed` produced a failure naming the snapshot and writing
  `expected.snap.actual` beside it; the row was restored afterward. `expected.snap.actual` is ignored at
  `.gitignore:41`, since the existing `target` rule does not reach it. Re-blessing is deliberate and
  explicit (`CLAUDEVS_CORPUS_BLESS=1`), so a diff cannot be absorbed by accident.
- **Finding 10 in the table below is closed by that work.** The comparison test panics on a mismatch, so
  the file needed `#![expect(clippy::panic, reason = "a snapshot mismatch reports the divergence by
  panicking")]`; `cargo clippy --all-targets -- -D warnings` failed with ``error: `panic` should not be
  present in production code`` at `crates/claudevs/tests/corpus.rs:281` until it was added.
- **The scratch dump test was removed.** It existed to inspect the sweep by hand and had no place in a
  committed suite once the snapshot replaced it.

## Review findings

One reviewer pass over the completed diff, re-running `cargo make dod` itself (exit 0, zero warnings,
neither corpus lane wired into it). Initial verdict: spec **non-compliant**. The corpus lanes were a
false green — `corpus-check`'s one test counts rows against the manifest's own root count, so a corpus
with zero repositories cloned renders 156 `ABSENT` rows and passes, and `corpus-fetch`'s unconditional
`mkdir -p` meant `corpus_root()`'s assert, named in the lane's own comment as its whole safety net, could
never fire after a fetch ran (`wshobson/agents` alone carries 91 of the 156 roots; losing it changed
nothing). `CLAUDE.md` documented a snapshot-comparison mechanism that does not exist in the tree. A
second defect sat in shipped rustdoc: `types/mod.rs:20` claimed every public type outside its named
exceptions is closed, while `Invocation` and `TModule` are public and open, satisfying neither. Reviewer's
own totals: code 3🔴 5🟡 6🔵, spec 1🔴 4🟡 1🔵. Two fix rounds followed; all four 🔴 are now closed, the
second round closing a residual the first round's own fix left open.

| # | Sev | Finding | Disposition |
|---|---|---|---|
| 1 | 🔴 | `CLAUDE.md:185-194` — claims `corpus-check` "compares the result against a committed per-root snapshot"; no snapshot exists and no comparison test was written | fixed — rewritten to describe the `.unfetchable` record instead of a snapshot that isn't there |
| 2 | 🔴 | `Makefile.toml:333` — `mkdir -p "$dest"` runs before the clone loop, so `corpus_root()`'s directory assert can never fire post-fetch even when every clone failed | fixed — `mkdir -p` moved inside the loop; every outcome logged to `.fetch-log`/`.unfetchable`; the lane exits 1 if the logged count disagrees with the manifest's known repository total |
| 3 | 🔴 | `crates/claudevs/tests/corpus.rs:151-157` — the only test `corpus-check` runs counts rows, and `render_row` emits exactly one row per manifest root regardless of whether the clone exists, so a short corpus cannot be detected | fixed — a checkout-vs-root-presence assertion added; a residual survived the first round (empty-but-present checkouts still passed) and was closed in a second round, both directions verified locally |
| 4 | 🔴 | `crates/claudevs/src/types/mod.rs:20` — "Every public type elsewhere in this crate is closed" is false; `Invocation` and `TModule` are public and open and named nowhere | fixed — doc now names both explicitly as open, unattributed, per the author's instruction |
| 5 | 🟡 | `Makefile.toml:352` — an empty `slug` (e.g. a `[[repo]]` table reaching `sha` before `name`) makes `rm -rf "$repo"` resolve to `rm -rf target/corpus/`, widening to the whole corpus | fixed — `corpus-fetch` now validates each awk-extracted record before `repo` is computed, rejecting an empty `name`/`url`/`sha`/`slug` and a `slug` still holding `/`, `.` or `..`. The rejection reaches the lane through `set -e` on the pipeline plus a `.malformed` marker checked after the loop, because the `while read` body is a subshell. **The finding's stated trigger was wrong:** a `[[repo]]` table whose `sha` line precedes `name` does not yield an empty `slug` — the tab is IFS whitespace, so `read` collapses the leading empty fields and `name` absorbs the sha (measured: `slug=b819fe74…`, exit 0). The widening needs the values themselves empty — a blank `sha` ahead of `name`/`url`, which pre-fix gave `slug=`, `repo="$dest/"`, `rm -rf` of the whole destination, and exit 0. Both malformations now exit 1 |
| 6 | 🟡 | `crates/claudevs/tests/corpus.rs:126,130-134` — the row bakes in whether `claude` is on `PATH`, so the snapshot (once Task 7 lands) will move across machines even with no code change | fixed — `require_claude_on_path()` asserts the binary resolves on `PATH` before the sweep runs, naming why (the snapshot records real `validate` verdicts, so without it all 156 rows would read `validate=Skipped`). Watched fail under a stripped `PATH`, green under the real one. The path is resolved, not spawned |
| 7 | 🟡 | `Makefile.toml:384-386` — the comment guards against a name-filter typo, which cargo already errors on; it misdiagnoses the real hole (finding 2) | fixed — the claim was false and is now checked: a mistyped `-p` or `--test` name is a hard cargo failure at exit 101 (`error: package ID specification claudevs-nonexistent did not match any packages` / `error: no test target named nonexistent in claudevs package`), not a silent pass. The comment now names the real exit-0-having-run-nothing path (an unmatched name filter), states that the genuine silent-pass risk is an absent or short corpus, and describes the three guards in `tests/corpus.rs` without naming test functions |
| 8 | 🟡 | `crates/claudevs/tests/corpus/corpus.toml:31` — "This file is data, not a test. Nothing reads it yet." is stale; `corpus.rs` now reads it and three tests assert against it | fixed — replaced with what actually reads the file and what those assertions cover |
| 9 | 🟡 | security — `corpus-check` executes code from 13 third-party repositories via `native/declared.rs:67`'s `run_shell` (unmitigated) and `case/lua.rs:46` (Lua, confined by `Policy::confined()` at `:89`/`:117`); nothing in the plan, the lane comment or `CLAUDE.md` says so | fixed — disclosed in three places: `tests/corpus.rs`'s module doc, the `corpus-check` lane comment, and `CLAUDE.md`. Stated as the capability it is rather than as something happening: `native/declared.rs:66` hands each `run` string to `run_shell` (imported at `:20`) unconfined, Lua is confined by `Policy::confined()` at `case/lua.rs:91`/`:116`, and nothing executes today only because no pinned repository ships a case file — verified by searching the checkouts directly for `claudevs.toml`, `tests/*.yaml`/`.yml` and `_test.lua`/`test_*.lua` rather than inferred from the `Skipped` column, since `check.rs:164`'s arm also covers `Error::Marketplace` and `Error::Layout` |
| 10 | 🔵 | `crates/claudevs/tests/corpus.rs:15-18` — no `#![expect(clippy::panic, …)]` yet; Task 7's comparison test will need one | closed — the attribute landed with Task 7 |
| 11 | 🔵 | `crates/claudevs/tests/corpus.rs:154` — once Task 7 lands, `corpus-check` will run a full 156-root sweep twice (once per `#[ignore]`d test) | fixed — the two `#[ignore]`d tests merged into `the_sweep_covers_every_manifest_root_and_matches_the_committed_snapshot`, which sweeps once and makes every assertion in order: arity, corpus-not-short, no `ABSENT`-despite-checkout, then the snapshot. Shortness is checked before the snapshot so a short corpus reports what is missing rather than a 156-line diff. `corpus-check` now runs one sweep, 41s |
| 12 | 🔵 | `crates/claudevs/tests/corpus.rs:139-144` — `Finding.line` is dropped from the rendered row, so two findings differing only by line number render identically | fixed — the row renders `{file}:{line}`, with `-` where a checker knows no line. Re-blessed; the diff moved exactly the three indented finding lines (`SKILL.md:69`, `hooks.json:-`, `optimize-prompt.py:-`) and no root row |
| 13 | 🔵 | `crates/claudevs/tests/corpus.rs:29` — `Repo::branch` is deserialized and asserted non-empty but used by no code path (the fetch is by SHA) | fixed — the field now carries a doc comment saying what it records (the branch the pinned `sha` sat on, for a human repinning: twelve `main`, one `master`) and that `corpus-fetch` reads only `name`, `url` and `sha`. Field and assertion both kept |
| 14 | 🔵 | `crates/claudevs/src/case/model.rs:16-19` — `FixtureRef`'s doc comment for the bullet-2 call doesn't mention that downstream can no longer pattern-match `let FixtureRef(name) = …`, only `.0` | fixed — the doc now states the consequence and its error text. **A first attempt at this row was wrong and is corrected here:** it quoted ``error[E0603]: tuple struct constructor `FixtureRef` is private`` as *the* diagnostic. That text is real but reaches only a caller who names the type through its path; the reproduction behind the claim had been run in that form alone, on rustc 1.91.1 from the ambient `PATH` rather than the 1.94.1 pinned by `rust-toolchain.toml`. Re-measured on 1.94.1: imported, `let FixtureRef(name) = …` is ``error[E0532]: cannot match against a tuple struct which contains private fields`` and `FixtureRef(s)` is ``error[E0423]: cannot initialize a tuple struct which contains private fields``; path-qualified, the pattern is the E0603 above. `.0` compiles in every form. The doc now gives all three, keyed to how the type is named |
| 15 | 🔴 | plan 06 "Done when" #3 — "there is no third category"; `Invocation` and `TModule` are one | decided, not a gap — both stay unattributed permanently, not pending: `TModule` is already closed to external construction by field privacy, so `#[non_exhaustive]` would add nothing; `Invocation` fails the audit's bullet 4 only because it does not derive `Default`, a technicality of the rule's wording rather than a reason to close the type. `types/mod.rs`'s module doc already names both as open exceptions (see finding 4), so the published rustdoc is accurate as written and "Done when" #3 is satisfied by that documented exception, not violated by it |
| 16 | 🟡 | spec §7 closing line — "raise it rather than deciding that type by hand"; `FixtureRef` was decided by hand | fixed — `surface-audit.md` gains a §7 recording where each of the three raised types was decided and why, and the three table rows now read `raised in §4, decided in §7`. Spec §7 is not amended: its rule was followed — all three were raised rather than quietly assigned a bullet — and the decisions are on the record. `types/mod.rs`'s module doc, which described the two open types as "pending a decision by the crate's maintainers", now states the decision |
| 17 | 🟡 | spec §6 — "every fix is watched fail first"; the sweep's arity-only test had never been red and structurally could not be for the failure it was deployed against | fixed — see finding 3 |
| 18 | 🟡 | plan 06 Task 6 — `snapshot_path()`'s absence is a disclosed, reasoned deviation, but nothing in the tree recorded that Task 7 is still outstanding | acknowledged — recorded in this ledger and in the Deviations section above |
| 19 | 🟡 | plan 06 Task 5 — two tests not named by the plan were added; the manifest-integrity test is justified (gives dead fields a reader), the arity-only sweep test is finding 3/17 | acknowledged — no further action beyond finding 3/17 |
| 20 | 🔵 | plan 06 architecture line — "exactly one `#[non_exhaustive]`, on `Error`" describes the pre-chain tree; five were present before Task 2 | fixed — the Architecture paragraph now names the five that carried `#[non_exhaustive]` before Task 2 ran (`Error`, `HookCommand`, `DecisionMechanism`, `DocumentedEvent`, `Mismatch`); `surface-audit.md` already recorded the correction |
| 21 | 🔵 | plan 06 Task 4 step 1 — "two repositories have an empty `plugins` list" | no finding — verified correct |

Findings 4 and 15 are the same defect, cited under both a source line and the plan's own "Done when."
Findings 3, 17 and 19 are the same test, cited from three angles.

### Follow-up round — closing the rows left open

The rows above that read `open — author decision` were carried, then closed in a later pass, together
with the equivalent rows in `05-wiring-checkers.md`. Two independent reviews ran over that work.

The first returned one blocking finding and it was the record's own: row 14 above had stated a
verification whose result did not reproduce. A doc comment quoted
``error[E0603]: tuple struct constructor `FixtureRef` is private`` as the diagnostic for a pattern
match, and the reproduction behind it had been run on rustc 1.91.1 from the ambient `PATH` rather than
the 1.94.1 that `rust-toolchain.toml` pins, and only in the path-qualified form. Re-measured on 1.94.1:
imported, the pattern gives ``error[E0532]: cannot match against a tuple struct which contains private
fields`` and construction gives ``error[E0423]: cannot initialize a tuple struct which contains private
fields``; path-qualified, the pattern gives the E0603 above. `.0` compiles in every form. Row 14 now
records all three. That a wrong claim survived being written, reviewed and recorded as verified is the
finding worth keeping: a record of verification is a claim like any other.

The same review found the round's own highest-severity fix — a guard stopping `corpus-fetch` from
resolving `rm -rf "$repo"` to the destination root — pinned by nothing at all. Not in the gate, not in
CI, no test referencing it. The shell body was moved to `scripts/corpus-fetch.sh` so it could be driven
by ordinary tests, and `crates/claudevs/tests/corpus_fetch.rs` now pins both of the script's guards.
Each was confirmed by deleting it and watching the suite fail:

```
$ cargo test -p claudevs --test corpus_fetch      # malformed-record guard removed
the destination was emptied by a record that should have been rejected:
.../corpus/.fetch-log: No such file or directory
test result: FAILED. 1 passed; 1 failed

$ cargo test -p claudevs --test corpus_fetch      # accounting check removed
failures:
    a_declared_table_the_extraction_misses_fails_the_accounting_check
test result: FAILED. 3 passed; 1 failed

$ cargo test -p claudevs --test corpus_fetch      # both restored
test result: ok. 4 passed; 0 failed
```

The second review returned **no blocking findings** and verified all nine claimed closures against the
pinned toolchain, including a recursive search of the thirteen checkouts — with a control proving the
search could have found a case file — behind the claim that none ships one. Its two risk-level findings
were acted on: a comment in `wiring/run.rs` still named a test the same change had deleted, and the
accounting check above was the second unpinned guard. Its remaining risk and observation rows were
recorded and left, per a stopping rule set at the start of that pass: blocking findings only, no third
round.

Both reviews are counted, not summarised from memory: across the two ledgers here and in
`05-wiring-checkers.md` there are 41 finding rows, of which 19 concern the accuracy of something written
— a comment, a doc string, a stale count, a claim in this record — against 9 concerning code that
nothing would catch if it were removed. That distribution is why the guideline and agent definitions
were amended afterwards rather than only the code.

