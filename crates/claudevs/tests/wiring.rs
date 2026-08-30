//! Whole-checker integration over the committed negative fixture plugins.
//!
//! Most fixtures carry exactly one defect; `bad-matcher-plugin` carries three
//! (two warnings the catalogue and matcher checks report, one error the
//! `refs` check reports) because a plugin author who gets one thing wrong
//! rarely gets only one thing wrong, and the fixture doubles as the case that
//! wiring still fails a plugin for a real reason once the other two stopped
//! being errors. A checker that stopped reporting its defect would leave the
//! matching assertion below red.

#![expect(clippy::unwrap_used, reason = "tests unwrap known-valid fixtures")]

use std::path::PathBuf;

use claudevs::{Severity, wiring};

fn fixture(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures")
        .join(name)
}

#[test]
fn the_exemplar_plugin_has_clean_wiring() {
    let report = wiring::run(&fixture("minimal-plugin")).unwrap();
    assert!(report.findings.is_empty(), "{report:?}");
}

#[test]
fn the_escape_fixture_is_reported_by_refs() {
    // The fixture's only true defect is the `../gate.sh` escape in
    // hooks.json. It stays a *single* finding only because that escaping
    // reference happens to contain the literal substring `gate.sh` — the
    // name of the one script the fixture ships — so `invocations`' dead-file
    // scan (`refs::occurrences(..).any(|o| o.target.ends_with(name))`, see
    // `wiring/invocations.rs::mentions`) reads `hooks/gate.sh` as referenced
    // and stays silent. Respell the escape as e.g. `../tools.sh` and
    // `gate.sh` would no longer be named anywhere, adding an unrelated
    // "referenced by nothing" warning here — this test would then need to
    // filter it out or fail on `report.findings.len()`.
    let report = wiring::run(&fixture("escape-plugin")).unwrap();
    let escapes: Vec<_> = report
        .findings
        .iter()
        .filter(|f| f.checker == "refs" && f.message.contains("escapes"))
        .collect();
    assert_eq!(escapes.len(), 1, "{report:?}");
    assert_eq!(escapes[0].severity, Severity::Error);
    assert!(!report.all_clear());
}

#[test]
fn the_dead_script_fixture_is_a_warning_that_does_not_fail_the_stage() {
    let report = wiring::run(&fixture("dead-script-plugin")).unwrap();
    let dead: Vec<_> = report
        .findings
        .iter()
        .filter(|f| f.checker == "invocations")
        .collect();
    assert_eq!(dead.len(), 1, "{report:?}");
    assert_eq!(dead[0].file, "hooks/orphan.sh");
    assert!(
        report.all_clear(),
        "a dead file is a warning, not a stage failure: {report:?}"
    );
}

#[test]
fn the_bad_matcher_fixture_is_reported_twice_by_matchers_as_warnings() {
    // An unknown hook event and a matcher Rust cannot compile are both
    // warnings now, not errors: the catalogue can lag a Claude Code release,
    // and claudevs cannot prove the JavaScript engine would also reject a
    // pattern its narrower `regex` crate rejects. Neither fails the stage on
    // its own (`wiring/finding.rs`); see `the_bad_matcher_fixture_is_reported_
    // by_refs_and_fails_the_stage` for what still does.
    let report = wiring::run(&fixture("bad-matcher-plugin")).unwrap();
    let matchers: Vec<_> = report
        .findings
        .iter()
        .filter(|f| f.checker == "matchers")
        .collect();
    assert_eq!(matchers.len(), 2, "{report:?}");
    assert!(
        matchers.iter().all(|f| f.severity == Severity::Warning),
        "{report:?}"
    );
    assert!(
        matchers.iter().any(|f| f
            .message
            .contains("is not an event this version of claudevs knows about")),
        "{report:?}"
    );
    assert!(
        matchers
            .iter()
            .any(|f| f.message.contains("cannot evaluate matcher")),
        "{report:?}"
    );
}

#[test]
fn the_bad_matcher_fixture_is_reported_by_refs_and_fails_the_stage() {
    // The fixture's `hooks.json` command references
    // `${CLAUDE_PLUGIN_ROOT}/scripts/absent.sh`, a script that does not
    // exist — the one finding in this fixture that is still an error, so
    // wiring still fails for a genuine reason (Makefile.toml's
    // `claudevs-check` lane relies on this).
    let report = wiring::run(&fixture("bad-matcher-plugin")).unwrap();
    let refs: Vec<_> = report
        .findings
        .iter()
        .filter(|f| f.checker == "refs")
        .collect();
    assert_eq!(refs.len(), 1, "{report:?}");
    assert_eq!(refs[0].severity, Severity::Error);
    assert!(refs[0].message.contains("absent.sh"), "{report:?}");
    assert!(!report.all_clear(), "{report:?}");
}
