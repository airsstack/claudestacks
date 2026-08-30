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
//!
//! Know what this lane can execute before fetching it. `claudevs check` runs a
//! plugin's case suite whenever the plugin carries one, and a declared native
//! suite is not confined: `src/native/declared.rs:66` hands each `run` string
//! from the plugin's own `claudevs.toml` to `run_shell` (imported at `:20`),
//! which is a shell carrying this process's privileges. Lua cases are confined
//! — `Policy::confined()` at `src/case/lua.rs:91` and `:116` grants them no
//! filesystem, process or network capability.
//!
//! None of the pinned repositories ships a case file today, so no third-party
//! code actually runs. The snapshot's `Skipped` on both suite stages of all 156
//! roots is consistent with that but does not establish it: `src/check.rs:164`
//! maps `Error::Marketplace` and `Error::Layout` to `Skipped` alongside
//! `Error::NoCases`, so a `Skipped` column alone leaves three explanations
//! open. The claim comes from the checkouts instead — walking each root's
//! `tests/` tree and finding nothing `src/case/discover.rs:71` would classify
//! as a case, on trees that do hold files, three of them. Re-derive it the same
//! way after a repin rather than reading it off the column. That is a fact
//! about those thirteen upstreams, not a guarantee this lane offers, and the
//! next repin can change it. Fetch and sweep only what you are willing to run.

#![expect(
    clippy::expect_used,
    reason = "a test names what it required in the panic"
)]
#![expect(
    clippy::panic,
    reason = "a snapshot mismatch reports the divergence by panicking"
)]

use std::collections::BTreeSet;
use std::ffi::OsStr;
use std::fmt::Write as _;
use std::os::unix::fs::PermissionsExt as _;
use std::path::{Path, PathBuf};

/// One pinned repository from the corpus manifest.
#[derive(Debug, serde::Deserialize)]
struct Repo {
    name: String,
    url: String,
    sha: String,
    /// The branch the pinned `sha` sat on when the corpus was measured.
    ///
    /// Nothing fetches by it: `corpus-fetch` reads only `name`, `url` and
    /// `sha` from this manifest and clones with
    /// `git fetch --depth 1 origin <sha>`. It is recorded so that a human
    /// repinning a repository knows which history the commit came from —
    /// twelve of the thirteen are `main` and one is `master`, so the answer is
    /// not guessable. The manifest assertion below only keeps it from being
    /// recorded empty.
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

#[test]
fn every_repository_names_where_and_at_what_commit_to_clone_it() {
    let manifest = load_manifest();
    for repo in &manifest.repo {
        assert!(!repo.url.is_empty(), "{} has no url", repo.name);
        assert!(!repo.sha.is_empty(), "{} has no pinned sha", repo.name);
        assert!(!repo.branch.is_empty(), "{} has no branch", repo.name);
    }
}

/// The fetched clones.
///
/// A `#[ignore]`d test that was explicitly asked for with `--ignored` and then
/// finds nothing must fail rather than pass quietly, so this stops the sweep
/// outright instead of rendering 156 `ABSENT` rows that would look like a
/// clean run at a glance.
fn corpus_root() -> PathBuf {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../target/corpus");
    assert!(
        root.is_dir(),
        "the corpus is not fetched; run `cargo make corpus-fetch` ({} is absent)",
        root.display()
    );
    root
}

/// The `claude` binary the `validate` stage delegates to.
///
/// That stage degrades to `Skipped` when the binary is absent rather than
/// failing the run, so a sweep on a machine without it records
/// `validate=Skipped` on every root while the committed snapshot records the
/// real `Passed`/`Failed` verdicts. All 156 rows would then diverge for an
/// environmental reason and read as a change in what claudevs reports, so the
/// precondition is stated up front instead. Resolving the path is enough; the
/// binary is not spawned here.
///
/// The decision itself lives in [`claude_resolves_in`], which takes the `PATH`
/// value rather than reading the environment, so it can be exercised against a
/// synthetic one.
fn require_claude_on_path() {
    assert!(
        claude_resolves_in(std::env::var_os("PATH").as_deref()),
        "`claude` is not on PATH; the sweep delegates its `validate` stage to that \
         binary and the committed snapshot records the verdicts it returned, so \
         without it every root would render `validate=Skipped` and the snapshot \
         comparison would fail for an environmental reason rather than a real one"
    );
}

/// Whether a spawnable `claude` resolves in the `PATH` value `path`.
///
/// Executability is part of the question, not a refinement of it. The
/// `validate` stage spawns the binary — `src/validate.rs:97` hands the argv to
/// the process harness — so a plain file named `claude` sitting on `PATH`
/// fails to exec and leaves the stage `Skipped` exactly as an absent one does.
/// A check that stopped at `is_file` would report the precondition satisfied on
/// a machine where the sweep is about to diverge on all 156 rows, which is the
/// one outcome this precondition exists to prevent.
///
/// Any execute bit counts, rather than resolving this process's uid and gid
/// against the file's owner and group: that is the approximation `PATH` lookups
/// conventionally make, and the exec itself remains the real authority.
fn claude_resolves_in(path: Option<&OsStr>) -> bool {
    path.is_some_and(|path| {
        std::env::split_paths(path).any(|dir| {
            std::fs::metadata(dir.join("claude"))
                .is_ok_and(|meta| meta.is_file() && meta.permissions().mode() & 0o111 != 0)
        })
    })
}

#[test]
fn claude_resolves_only_from_a_path_entry_holding_an_executable_file() {
    let temp = tempfile::tempdir().expect("a temp dir");
    let executable = temp.path().join("executable");
    let not_executable = temp.path().join("not-executable");
    let empty = temp.path().join("empty");
    for dir in [&executable, &not_executable, &empty] {
        std::fs::create_dir(dir).expect("a PATH entry");
    }
    for (dir, mode) in [(&executable, 0o755), (&not_executable, 0o644)] {
        let binary = dir.join("claude");
        std::fs::write(&binary, "#!/bin/sh\nexit 0\n").expect("a claude to find");
        std::fs::set_permissions(&binary, std::fs::Permissions::from_mode(mode))
            .expect("the mode under test");
    }

    let as_path = |dirs: &[&Path]| std::env::join_paths(dirs).expect("a PATH value");

    let found = as_path(&[&executable]);
    assert!(claude_resolves_in(Some(&found)));

    // The precondition is about a binary the `validate` stage can spawn, so a
    // file named `claude` that cannot be executed counts as absent.
    let present_but_not_runnable = as_path(&[&not_executable]);
    assert!(!claude_resolves_in(Some(&present_but_not_runnable)));

    let nothing_named_claude = as_path(&[&empty]);
    assert!(!claude_resolves_in(Some(&nothing_named_claude)));

    // A process with no PATH at all resolves nothing rather than falling back
    // to some default set of directories.
    assert!(!claude_resolves_in(None));

    // Order does not matter: one usable entry anywhere is enough.
    let mixed = as_path(&[&empty, &not_executable, &executable]);
    assert!(claude_resolves_in(Some(&mixed)));
}

/// The directory name a repository's clone lives under inside `target/corpus`.
///
/// Shared by [`sweep`] (to find a clone) and
/// [`the_sweep_covers_every_manifest_root_and_matches_the_committed_snapshot`]
/// (to check one is there), so the two agree on where a repository is supposed
/// to be.
fn checkout_slug(repo_name: &str) -> String {
    repo_name.replace('/', "_")
}

/// The repository slugs `corpus-fetch` recorded as unfetchable this run.
///
/// `corpus-fetch` writes one slug per line to `target/corpus/.unfetchable`
/// when a pinned commit was deleted, made private, or force-pushed and so
/// could not be re-cloned — the one case where an absent checkout is a fact
/// about upstream rather than a fact about this run. A missing file means
/// nothing was recorded, so every absence must be explained some other way.
fn unfetchable_slugs(corpus: &Path) -> BTreeSet<String> {
    std::fs::read_to_string(corpus.join(".unfetchable"))
        .map(|text| text.lines().map(str::to_owned).collect())
        .unwrap_or_default()
}

/// The committed record of what `claudevs check` reports for every root.
///
/// Regenerated deliberately, never edited by hand: a row corrected to look
/// right is a defect hidden rather than found, which is the whole reason this
/// corpus exists. Set `CLAUDEVS_CORPUS_BLESS=1` to rewrite it from a live
/// sweep, then read the diff before keeping it.
fn snapshot_path() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/corpus/expected.snap")
}

/// Plugin roots that render `ABSENT` even though their repository has a
/// checkout on disk.
///
/// An absent checkout is legitimate when [`unfetchable_slugs`] recorded it —
/// that names a repository this run could not reach at all. This function
/// covers the other case: the checkout directory exists, so the clone
/// happened, and a root under it is still missing. That can only mean the
/// checkout landed on the wrong commit or that a plugin path in
/// `corpus.toml` no longer matches the repository's layout, and either is a
/// defect in the corpus rather than a fact about upstream, so it is never an
/// acceptable `ABSENT`.
fn absent_despite_checkout(manifest: &Manifest, corpus: &Path) -> Vec<String> {
    let mut offending = Vec::new();
    for repo in &manifest.repo {
        let slug = checkout_slug(&repo.name);
        let checkout = corpus.join(&slug);
        if !checkout.is_dir() {
            // No checkout at all: the "corpus is short" check below decides
            // whether that absence is explained.
            continue;
        }
        for plugin in &repo.plugins {
            let root = if plugin == "." {
                checkout.clone()
            } else {
                checkout.join(plugin)
            };
            if !root.is_dir() {
                offending.push(format!("{}/{plugin}", repo.name));
            }
        }
    }
    offending
}

/// Sweeps every plugin root the manifest names, rendered as one line per root
/// plus an indented line per finding.
///
/// Deterministic order: repositories as the manifest lists them, plugin roots
/// as each repository lists them, so a diff against a prior run shows only
/// what changed in behaviour rather than what changed in ordering.
fn sweep() -> String {
    let manifest = load_manifest();
    let corpus = corpus_root();
    let mut rows = Vec::new();

    for repo in &manifest.repo {
        let slug = checkout_slug(&repo.name);
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
/// A row per root rather than a flat list of findings: every root carries the
/// outcome of every stage, so a checker that stops reporting moves every row
/// it used to touch rather than shrinking a list silently.
///
/// Runs the wiring check a second time even though `claudevs::check::run`
/// already ran it as one of its stages, because the stage's report carries
/// wiring's *rendered* text, not the structured findings — and a row built
/// from rendered prose would change every time the renderer's wording did,
/// not only when the plugin's wiring did.
fn render_row(repo: &str, plugin: &str, root: &Path) -> String {
    if !root.is_dir() {
        return format!("{repo}  {plugin}  ABSENT\n");
    }
    // Lenient, matching what `claudevs check` does by default. A strict run
    // would record the delegate's style opinions, which this sweep is not
    // watching for.
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
        // The line is part of the identity of a finding: without it two
        // findings differing only in where they sit render identically, and
        // one can replace the other in the snapshot unnoticed. A checker that
        // knows no line renders `-` rather than dropping the field, so the
        // column stays in the same place on every line.
        let line = finding
            .line
            .map_or_else(|| String::from("-"), |line| line.to_string());
        writeln!(
            row,
            "  {:?} {} {}:{line} {}",
            finding.severity, finding.checker, finding.file, finding.message
        )
        .expect("writing to a String never fails");
    }
    row
}

#[test]
#[ignore = "needs the corpus fetched by `cargo make corpus-fetch`"]
fn the_sweep_covers_every_manifest_root_and_matches_the_committed_snapshot() {
    // Environment first, before a single root is swept: without the delegate
    // every row renders `validate=Skipped` and the snapshot comparison at the
    // end would fail for that reason rather than for a real one.
    require_claude_on_path();

    // One sweep for every assertion below: sweeping 156 roots twice costs the
    // wall clock twice and answers nothing the first pass already did.
    let manifest = load_manifest();
    let expected_roots: usize = manifest.repo.iter().map(|r| r.plugins.len()).sum();
    let actual = sweep();
    let root_rows = actual.lines().filter(|line| !line.starts_with(' ')).count();
    assert_eq!(root_rows, expected_roots, "{actual}");

    // `render_row` emits exactly one line per root whether its clone is
    // present or absent, so the count above holds even for a corpus with
    // nothing cloned at all. Catch that here: every repository that carries
    // at least one plugin root must have a checkout on disk, unless
    // `corpus-fetch` recorded it as unfetchable. An absent-and-unrecorded
    // repository means this run's corpus is short, not that the repository
    // is gone.
    let corpus = corpus_root();
    let unfetchable = unfetchable_slugs(&corpus);
    let unexplained: Vec<&str> = manifest
        .repo
        .iter()
        .filter(|repo| !repo.plugins.is_empty())
        .filter(|repo| {
            let slug = checkout_slug(&repo.name);
            !corpus.join(&slug).is_dir() && !unfetchable.contains(&slug)
        })
        .map(|repo| repo.name.as_str())
        .collect();
    assert!(
        unexplained.is_empty(),
        "corpus is short: {unexplained:?} have no checkout under {} and are not \
         recorded in .unfetchable; run `cargo make corpus-fetch`",
        corpus.display()
    );

    // A checkout being present does not mean every root under it is: an
    // `ABSENT` row whose repository *is* on disk means the pinned commit or
    // a plugin path is wrong, not that upstream is unreachable, so it must
    // fail rather than blend in with a legitimately unfetchable repository.
    let offending = absent_despite_checkout(&manifest, &corpus);
    assert!(
        offending.is_empty(),
        "these roots render ABSENT even though their repository has a checkout under \
         {}: {offending:?}; re-run `cargo make corpus-fetch` to fix a stale checkout, \
         or fix the plugin path in tests/corpus/corpus.toml if it moved",
        corpus.display()
    );

    // The snapshot comes last, so a short or mis-fetched corpus reports what
    // is missing rather than a 156-line diff caused by that same absence.
    let path = snapshot_path();
    if std::env::var_os("CLAUDEVS_CORPUS_BLESS").is_some() {
        std::fs::write(&path, &actual).expect("write snapshot");
        return;
    }

    let expected = std::fs::read_to_string(&path).unwrap_or_default();
    if expected != actual {
        let actual_path = path.with_extension("snap.actual");
        std::fs::write(&actual_path, &actual).expect("write actual");
        panic!(
            "the sweep no longer matches {}; wrote {} for comparison. \
             Review the diff: a changed row means claudevs reports something \
             different for a plugin that has not changed. Re-bless with \
             CLAUDEVS_CORPUS_BLESS=1 only once the change is understood.",
            path.display(),
            actual_path.display()
        );
    }
}
