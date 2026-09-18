//! The example plugins under `crates/claudevs/examples/` do what their READMEs say.
//!
//! Each example is teaching material: its README shows a `claudevs check` run and quotes the
//! outcome. This test is what keeps that quote true. It runs the same pipeline the binary runs
//! and compares the typed stage outcomes against the expectation declared below, so a broken
//! example fails `cargo test` rather than being discovered by a reader.
//!
//! `validate` is excluded from every assertion: it delegates to the `claude` binary and skips
//! wherever that binary is absent, which is the documented degradation on CI. The three
//! deterministic stages — `wiring`, `test`, `test --installed` — must always have run, because
//! `claudevs check` turns three environment gaps into a skipped stage rather than a failure (no
//! case files, no marketplace above the plugin, no writable temp dir), and a skip is exactly how
//! an example stops exercising what its README documents while still exiting 0.

#![expect(
    clippy::panic,
    reason = "a failing example reports which stage diverged by panicking"
)]

use std::path::{Path, PathBuf};

use claudevs::check::{CheckReport, StageStatus};

/// What an example is supposed to do.
#[derive(Debug, Clone, Copy)]
enum Expectation {
    /// Every deterministic stage ran and passed.
    AllOk,
    /// Every deterministic stage ran, and this one failed.
    FailsAt(&'static str),
}

/// Every example, and the outcome its README documents.
///
/// A new example directory with no row here fails the completeness test below, so this list
/// cannot silently fall behind `examples/`.
const EXAMPLES: &[(&str, Expectation)] = &[
    ("01_hook_decision", Expectation::AllOk),
    ("02_hook_decision_broken", Expectation::FailsAt("test")),
    ("03_session_context", Expectation::AllOk),
    ("04_script_and_flow", Expectation::AllOk),
    ("05_lua_cases", Expectation::AllOk),
    ("06_native_suite", Expectation::AllOk),
    ("07_wiring_broken", Expectation::FailsAt("wiring")),
    (
        "08_installed_broken",
        Expectation::FailsAt("test --installed"),
    ),
    ("09_doctor_gaps", Expectation::AllOk),
];

/// The stages that run on every machine, whether or not `claude` is installed.
const DETERMINISTIC: [&str; 3] = ["wiring", "test", "test --installed"];

fn examples_dir() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("examples")
}

fn stage<'report>(report: &'report CheckReport, name: &str) -> &'report claudevs::check::Stage {
    report
        .stages
        .iter()
        .find(|stage| stage.name == name)
        .unwrap_or_else(|| {
            panic!(
                "stage `{name}` is missing from the report entirely; stages present: {:?}",
                report.stages.iter().map(|s| s.name).collect::<Vec<_>>()
            )
        })
}

fn check(dir: &Path) -> CheckReport {
    claudevs::check::run(dir, claudevs::Strictness::Lenient)
        .unwrap_or_else(|error| panic!("claudevs check {}: {error}", dir.display()))
}

#[test]
fn every_example_produces_the_outcome_its_readme_documents() {
    for (name, expectation) in EXAMPLES {
        let dir = examples_dir().join(name);
        assert!(dir.is_dir(), "{} is not a directory", dir.display());

        let report = check(&dir);

        for deterministic in DETERMINISTIC {
            let stage = stage(&report, deterministic);
            assert_ne!(
                stage.status,
                StageStatus::Skipped,
                "{name}: stage `{deterministic}` skipped, so the run its README quotes did not \
                 happen: {}",
                stage.detail
            );
        }

        match expectation {
            Expectation::AllOk => {
                for deterministic in DETERMINISTIC {
                    let stage = stage(&report, deterministic);
                    assert_eq!(
                        stage.status,
                        StageStatus::Passed,
                        "{name}: stage `{deterministic}` did not pass: {}",
                        stage.detail
                    );
                }
            }
            Expectation::FailsAt(expected) => {
                let stage = stage(&report, expected);
                assert_eq!(
                    stage.status,
                    StageStatus::Failed,
                    "{name}: this example is broken on purpose and `{expected}` is the stage that \
                     must report it, but it did not: {}",
                    stage.detail
                );
            }
        }
    }
}

#[test]
fn every_example_directory_is_covered_by_the_table() {
    let dir = examples_dir();
    let mut found: Vec<String> = std::fs::read_dir(&dir)
        .unwrap_or_else(|error| panic!("read {}: {error}", dir.display()))
        .filter_map(Result::ok)
        .filter(|entry| entry.path().is_dir())
        .map(|entry| entry.file_name().to_string_lossy().into_owned())
        // The shared marketplace manifest is not an example.
        .filter(|name| !name.starts_with('.'))
        // `08_installed_broken` reads a file from this directory; it is not an example either.
        .filter(|name| name != "shared")
        .collect();
    found.sort();

    let mut declared: Vec<String> = EXAMPLES
        .iter()
        .map(|(name, _)| (*name).to_owned())
        .collect();
    declared.sort();

    assert_eq!(
        found, declared,
        "every directory under examples/ needs a row in EXAMPLES, and every row needs a directory"
    );
}
