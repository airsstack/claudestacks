//! The two guards in `scripts/corpus-fetch.sh`: the malformed-record check
//! inside the clone loop, and the accounting check after it.
//!
//! That script destroys directories: for each manifest record it computes
//! `<destination>/<slug>` and `rm -rf`s it before cloning. A record whose
//! fields came out empty — a hand-edited `[[repo]]` table with a reordered or
//! blank key, which the script's awk pass cannot tell from a well-formed one —
//! collapses that path to the destination root, and the removal takes every
//! clone instead of one. The guard rejects such a record first.
//!
//! Nothing else pins it. `cargo make corpus-fetch` is in neither the
//! Definition-of-Done gate nor CI, because the corpus is pinned by commit SHA
//! rather than vendored and the fetch is the one step here that touches the
//! network. So the guard's only other exercise is a lane that runs by
//! convention before a release, and deleting the guard would leave every such
//! run green. These tests run under plain `cargo test`, drive the script
//! against manifests and destinations they own under a temporary directory,
//! and never reach the network: every record that gets as far as `git fetch`
//! points at a `file://` origin that does not exist.
//!
//! The accounting check answers a different question. The clone loop is the
//! right-hand side of a pipeline and so runs in a subshell, where a counter
//! cannot survive; the script therefore compares the lines it appended to
//! `<destination>/.fetch-log` against the repository count it hardcodes. What
//! that catches is a manifest format drift leaving the awk extraction matching
//! fewer tables than the file declares, so records go missing without anything
//! failing — the malformed-record guard never sees them, because the
//! extraction never emitted them.

#![expect(clippy::unwrap_used, reason = "tests unwrap known-valid fixtures")]

use std::path::{Path, PathBuf};
use std::process::{Command, Output};

/// The script under test, resolved from this crate rather than the cwd.
fn script() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../scripts/corpus-fetch.sh")
}

/// Runs the script against a manifest and destination the caller owns.
///
/// Invoking the file directly rather than through `sh` keeps the executable bit
/// load-bearing, which is how `cargo make corpus-fetch` reaches it too.
fn fetch(manifest: &Path, destination: &Path) -> Output {
    Command::new(script())
        .arg(manifest)
        .arg(destination)
        .output()
        .unwrap()
}

#[test]
fn a_record_with_empty_fields_is_rejected_before_the_destination_is_removed() {
    let scratch = tempfile::tempdir().unwrap();

    // A blank `sha` sitting ahead of `name` and `url` is the shape that made
    // this guard necessary: the awk pass emits its record the moment it sees a
    // `sha` line, so this one carries three empty fields and an empty slug.
    let manifest = scratch.path().join("corpus.toml");
    std::fs::write(
        &manifest,
        concat!(
            "[[repo]]\n",
            "sha = \"\"\n",
            "name = \"owner/repo\"\n",
            "url = \"https://example.invalid/owner/repo\"\n",
        ),
    )
    .unwrap();

    // A stand-in for the clones a real destination already holds. The guard is
    // worth nothing if the run still empties the directory on its way out.
    let destination = scratch.path().join("corpus");
    std::fs::create_dir_all(&destination).unwrap();
    let bystander = destination.join("owner_other-repo");
    std::fs::write(&bystander, "a previous run's clone").unwrap();

    let output = fetch(&manifest, &destination);
    let stderr = String::from_utf8_lossy(&output.stderr);

    // Asserted first because it is the consequence the guard exists to
    // prevent: without it, `rm -rf` resolves to the destination root and this
    // file is gone before the run ends.
    assert!(
        bystander.exists(),
        "the destination was emptied by a record that should have been rejected:\n{stderr}"
    );
    assert!(
        !output.status.success(),
        "a malformed record must fail the run, got {:?}\n{stderr}",
        output.status
    );
    assert!(
        stderr.contains("malformed manifest record"),
        "expected the guard to name what it rejected, got:\n{stderr}"
    );
}

#[test]
fn a_well_formed_record_reaches_the_fetch() {
    let scratch = tempfile::tempdir().unwrap();

    // A `file://` origin that does not exist. `git fetch` fails against it
    // locally, so this record proves it passed the guard without the test
    // needing a network or a real upstream.
    let origin = scratch.path().join("no-such-origin.git");
    let manifest = scratch.path().join("corpus.toml");
    std::fs::write(
        &manifest,
        format!(
            "[[repo]]\nname = \"owner/repo\"\nurl = \"file://{}\"\nsha = \"{}\"\n",
            origin.display(),
            "0".repeat(40),
        ),
    )
    .unwrap();

    let destination = scratch.path().join("corpus");
    let output = fetch(&manifest, &destination);
    let stderr = String::from_utf8_lossy(&output.stderr);

    assert!(
        !stderr.contains("malformed manifest record"),
        "the guard rejected a record carrying a name, url and sha:\n{stderr}"
    );
    // The absence above cannot tell "accepted" from "the loop never saw the
    // record at all", so pin where the record actually got to. Reaching the
    // unfetchable branch means the guard passed it through and the clone was
    // attempted.
    assert!(
        stderr.contains("UNFETCHABLE owner/repo"),
        "expected the record to reach the fetch and be reported unfetchable, got:\n{stderr}"
    );
}

/// The repository count `scripts/corpus-fetch.sh` hardcodes as `total`, and the
/// same count `corpus.rs` asserts the real manifest carries. A corpus that
/// grows bumps all three together.
const MANIFEST_TOTAL: usize = 13;

/// A well-formed `[[repo]]` table the script's awk pass extracts.
///
/// The origin is a `file://` URL under the caller's scratch directory that was
/// never created, so the clone fails locally and the record still reaches the
/// log through the unfetchable branch — accounted for without a network.
fn record(scratch: &Path, index: usize) -> String {
    format!(
        "[[repo]]\nname = \"owner/repo-{index}\"\nurl = \"file://{}/no-such-origin-{index}.git\"\nsha = \"{}\"\n",
        scratch.display(),
        "0".repeat(40),
    )
}

/// The same table with its keys indented, which is the drift being modelled.
///
/// TOML permits the leading whitespace, so the manifest still declares the
/// repository, but the script's awk patterns are anchored at the start of the
/// line and match none of the three keys. The extraction emits no record at
/// all, which is why this reaches the accounting check rather than the
/// malformed-record guard: the loop never runs a body for this table.
fn record_the_extraction_misses(scratch: &Path, index: usize) -> String {
    let mut table = String::from("[[repo]]\n");
    for key in record(scratch, index).lines().skip(1) {
        table.push_str("  ");
        table.push_str(key);
        table.push('\n');
    }
    table
}

/// How many repositories a run accounted for, read back from the log the script
/// uses to carry that count out of the subshell.
fn accounted(destination: &Path) -> usize {
    std::fs::read_to_string(destination.join(".fetch-log"))
        .unwrap()
        .lines()
        .count()
}

/// Writes `body` as a manifest and runs the script against a fresh destination.
fn run(scratch: &Path, body: &str) -> (Output, PathBuf) {
    let manifest = scratch.join("corpus.toml");
    std::fs::write(&manifest, body).unwrap();
    let destination = scratch.join("corpus");
    (fetch(&manifest, &destination), destination)
}

#[test]
fn a_manifest_whose_every_table_is_extracted_satisfies_the_accounting_check() {
    let scratch = tempfile::tempdir().unwrap();
    let body: String = (0..MANIFEST_TOTAL)
        .map(|index| record(scratch.path(), index))
        .collect();

    let (output, destination) = run(scratch.path(), &body);
    let stderr = String::from_utf8_lossy(&output.stderr);

    // The control for the test below: a manifest carrying exactly the count the
    // script expects accounts for all of it and exits 0. Without this, a short
    // manifest failing would not distinguish the accounting check from a
    // scratch run that could never have succeeded anyway.
    assert_eq!(
        accounted(&destination),
        MANIFEST_TOTAL,
        "every table should have reached the log:\n{stderr}"
    );
    assert!(
        output.status.success(),
        "a fully accounted-for run must exit 0, got {:?}\n{stderr}",
        output.status
    );
}

#[test]
fn a_declared_table_the_extraction_misses_fails_the_accounting_check() {
    let scratch = tempfile::tempdir().unwrap();
    let last = MANIFEST_TOTAL - 1;
    let mut body: String = (0..last)
        .map(|index| record(scratch.path(), index))
        .collect();
    body.push_str(&record_the_extraction_misses(scratch.path(), last));

    let (output, destination) = run(scratch.path(), &body);
    let stderr = String::from_utf8_lossy(&output.stderr);

    // The premise: the manifest declares the full count and the extraction
    // emitted one fewer. Asserted before the outcome so a failure below cannot
    // be read as the drift never having taken hold.
    assert_eq!(
        accounted(&destination),
        last,
        "the indented table should have been missed, not logged:\n{stderr}"
    );
    assert!(
        !stderr.contains("malformed manifest record"),
        "a table the extraction never emitted cannot reach the loop's guard, so \
         this run has to be failed by the accounting check instead:\n{stderr}"
    );
    assert!(
        !output.status.success(),
        "a short run must fail, got {:?}\n{stderr}",
        output.status
    );
    assert!(
        stderr.contains(&format!(
            "manifest names {MANIFEST_TOTAL} repositories, accounted for {last}"
        )),
        "expected the accounting check to name both counts, got:\n{stderr}"
    );
}
