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

#![expect(
    clippy::expect_used,
    reason = "a test names what it required in the panic"
)]
#![expect(
    clippy::panic,
    reason = "a snapshot mismatch reports the divergence by panicking"
)]

use std::collections::BTreeSet;
use std::fmt::Write as _;
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

/// The directory name a repository's clone lives under inside `target/corpus`.
///
/// Shared by [`sweep`] (to find a clone) and
/// [`the_sweep_renders_one_row_per_manifest_root`] (to check one is there),
/// so the two agree on where a repository is supposed to be.
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
        writeln!(
            row,
            "  {:?} {} {} {}",
            finding.severity, finding.checker, finding.file, finding.message
        )
        .expect("writing to a String never fails");
    }
    row
}

#[test]
#[ignore = "needs the corpus fetched by `cargo make corpus-fetch`"]
fn the_sweep_renders_one_row_per_manifest_root() {
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
}

#[test]
#[ignore = "needs the corpus fetched by `cargo make corpus-fetch`"]
fn the_sweep_matches_the_committed_snapshot() {
    let actual = sweep();
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
