//! Judging an [`Observed`] run against a case's [`Expectations`].
//!
//! Every mismatch is a typed [`Mismatch`], not a rendered sentence; a verdict
//! lists all of them rather than stopping at the first, so one run shows the
//! full distance to green. Rendering a mismatch into text is
//! [`crate::report`]'s job, not this module's.

use std::path::Path;

use crate::case::Expectations;
use crate::harness::Observed;

/// The outcome of one case.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize)]
#[non_exhaustive]
pub enum Verdict {
    /// Every expectation held.
    Pass,
    /// At least one expectation failed; each mismatch described.
    Fail(Vec<Mismatch>),
}

/// One way a case failed.
///
/// Eleven variants in two groups. Eight are assertions — one per expectation
/// [`judge`] can test — and three are structural: a case that never ran
/// ([`Mismatch::DidNotRun`]), a scripted case that reported its own failure
/// ([`Mismatch::Reported`]), and a wrapper naming which flow step failed
/// ([`Mismatch::InStep`]). The three exist because a run's outcomes are one
/// list, and a caller reading that list should not need a second shape for the
/// entries that never reached an assertion.
///
/// Typed rather than a rendered sentence, so `--json` carries structure a
/// consumer can act on and the human text has one place it is derived. The
/// assertion group grows every time an assertion is added, which is why this
/// enum is `#[non_exhaustive]`: that is a change claudevs makes routinely, and
/// a downstream exhaustive `match` should not break on it.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
#[non_exhaustive]
pub enum Mismatch {
    // ── structural ──────────────────────────────────────────────────────
    /// Nothing ran: the case would not load, its hook resolved to nothing, or
    /// a flow declared no run step.
    DidNotRun {
        /// What stopped it.
        reason: String,
    },
    /// A scripted case reported its own failure.
    Reported {
        /// What it said. Opaque to claudevs — the script decides the wording.
        reason: String,
    },
    /// A flow step failed; which one, and how.
    InStep {
        /// 0-based index of the step, in declaration order.
        index: usize,
        /// The failure inside it.
        mismatch: Box<Self>,
    },

    // ── assertions ──────────────────────────────────────────────────────
    /// The child was killed before it finished.
    TimedOut,
    /// Exit code differed.
    Exit {
        /// What the case asked for.
        expected: i32,
        /// What the run produced.
        observed: i32,
    },
    /// The decision differed.
    Decision {
        /// What the case asked for.
        expected: crate::case::Decision,
        /// What the hook communicated, if anything.
        observed: Option<crate::case::Decision>,
    },
    /// `output: none` was asserted and the hook emitted.
    UnexpectedOutput {
        /// The context it injected, if any. `None` when the hook
        /// communicated only a decision or exit code, with no
        /// `additionalContext` — the only producer is `observed.context`,
        /// which never carries the raw envelope.
        observed: Option<String>,
    },
    /// Injected context did not contain the expected substring.
    ContextMissing {
        /// The substring asked for.
        expected: String,
        /// The context that was injected, if any.
        observed: Option<String>,
    },
    /// stdout did not contain the expected substring.
    StdoutMissing {
        /// The substring asked for.
        expected: String,
        /// Everything the run printed to stdout.
        observed: String,
    },
    /// stderr did not contain the expected substring.
    StderrMissing {
        /// The substring asked for.
        expected: String,
        /// Everything the run printed to stderr.
        observed: String,
    },
    /// A file the case expected is not in the project.
    FileMissing {
        /// The path, relative to the project root.
        expected: String,
    },
}

/// Judges `observed` (plus the project tree for file asserts) against `expect`.
#[must_use]
pub fn judge(expect: &Expectations, observed: &Observed, project: &Path) -> Verdict {
    let mut mismatches = Vec::new();

    // A killed child is never a pass: no expectation can vouch for a run that
    // did not finish on its own.
    if observed.timed_out {
        mismatches.push(Mismatch::TimedOut);
    }
    if let Some(exit) = expect.exit
        && observed.exit != exit
    {
        mismatches.push(Mismatch::Exit {
            expected: exit,
            observed: observed.exit,
        });
    }
    if let Some(decision) = expect.decision
        && observed.decision != Some(decision)
    {
        mismatches.push(Mismatch::Decision {
            expected: decision,
            observed: observed.decision,
        });
    }
    if expect.output.as_deref() == Some("none") && observed.emitted {
        mismatches.push(Mismatch::UnexpectedOutput {
            observed: observed.context.clone(),
        });
    }
    if let Some(needle) = &expect.context_contains
        && !observed
            .context
            .as_deref()
            .unwrap_or("")
            .contains(needle.as_str())
    {
        mismatches.push(Mismatch::ContextMissing {
            expected: needle.clone(),
            observed: observed.context.clone(),
        });
    }
    if let Some(needle) = &expect.stdout_contains
        && !observed.stdout.contains(needle.as_str())
    {
        mismatches.push(Mismatch::StdoutMissing {
            expected: needle.clone(),
            observed: observed.stdout.clone(),
        });
    }
    if let Some(needle) = &expect.stderr_contains
        && !observed.stderr.contains(needle.as_str())
    {
        mismatches.push(Mismatch::StderrMissing {
            expected: needle.clone(),
            observed: observed.stderr.clone(),
        });
    }
    for rel in &expect.files_exist {
        if !project.join(rel).exists() {
            mismatches.push(Mismatch::FileMissing {
                expected: rel.clone(),
            });
        }
    }

    if mismatches.is_empty() {
        Verdict::Pass
    } else {
        Verdict::Fail(mismatches)
    }
}

#[cfg(test)]
mod tests {
    #![expect(clippy::unwrap_used, reason = "tests unwrap known-valid fixtures")]
    #![expect(clippy::panic, reason = "tests panic to reject an unexpected shape")]

    use super::{Mismatch, Verdict, judge};
    use crate::case::{Decision, Expectations};
    use crate::harness::Observed;

    fn observed() -> Observed {
        Observed {
            exit: 0,
            decision: Some(Decision::Deny),
            context: Some(String::from("read the rust guideline")),
            emitted: true,
            timed_out: false,
            stdout: String::new(),
            stderr: String::from("blocked: lockfile"),
        }
    }

    #[test]
    fn all_matching_expectations_pass() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::write(dir.path().join("audit.log"), "x").unwrap();
        let expect = Expectations {
            exit: Some(0),
            decision: Some(Decision::Deny),
            context_contains: Some(String::from("guideline")),
            stderr_contains: Some(String::from("lockfile")),
            files_exist: vec![String::from("audit.log")],
            ..Expectations::default()
        };
        assert_eq!(judge(&expect, &observed(), dir.path()), Verdict::Pass);
    }

    #[test]
    fn every_mismatch_is_reported_not_only_the_first() {
        let dir = tempfile::tempdir().unwrap();
        let expect = Expectations {
            exit: Some(1),
            decision: Some(Decision::Allow),
            ..Expectations::default()
        };
        let Verdict::Fail(mismatches) = judge(&expect, &observed(), dir.path()) else {
            panic!("expected a failing verdict");
        };
        assert_eq!(mismatches.len(), 2);
    }

    #[test]
    fn output_none_fails_when_the_hook_emitted() {
        let dir = tempfile::tempdir().unwrap();
        let expect = Expectations {
            output: Some(String::from("none")),
            ..Expectations::default()
        };
        assert!(matches!(
            judge(&expect, &observed(), dir.path()),
            Verdict::Fail(_)
        ));
    }

    #[test]
    fn a_timed_out_run_never_passes() {
        let dir = tempfile::tempdir().unwrap();
        let mut timed_out = observed();
        timed_out.timed_out = true;
        let Verdict::Fail(mismatches) = judge(&Expectations::default(), &timed_out, dir.path())
        else {
            panic!("a killed run must not pass");
        };
        assert_eq!(mismatches[0], Mismatch::TimedOut);
    }

    #[test]
    fn a_stdout_mismatch_carries_what_was_actually_printed() {
        let dir = tempfile::tempdir().unwrap();
        let mut run = observed();
        run.stdout = String::from("something else entirely");
        let expect = Expectations {
            stdout_contains: Some(String::from("expected-token")),
            ..Expectations::default()
        };
        let Verdict::Fail(mismatches) = judge(&expect, &run, dir.path()) else {
            panic!("expected a failing verdict");
        };
        assert_eq!(
            mismatches[0],
            Mismatch::StdoutMissing {
                expected: String::from("expected-token"),
                observed: String::from("something else entirely"),
            },
        );
    }

    #[test]
    fn a_stdout_mismatch_on_silence_is_distinguishable_from_a_wrong_value() {
        let dir = tempfile::tempdir().unwrap();
        let mut run = observed();
        run.stdout = String::new();
        let expect = Expectations {
            stdout_contains: Some(String::from("expected-token")),
            ..Expectations::default()
        };
        let Verdict::Fail(mismatches) = judge(&expect, &run, dir.path()) else {
            panic!("expected a failing verdict");
        };
        let Mismatch::StdoutMissing { observed, .. } = &mismatches[0] else {
            panic!("{mismatches:?}");
        };
        assert!(observed.is_empty(), "silence must be visible as silence");
    }

    #[test]
    fn empty_expectations_pass_vacuously() {
        let dir = tempfile::tempdir().unwrap();
        assert_eq!(
            judge(&Expectations::default(), &observed(), dir.path()),
            Verdict::Pass
        );
    }
}
