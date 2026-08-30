//! Delegating manifest validation to the `claude` binary.
//!
//! Anything `claude plugin` already ships is delegated, never rebuilt. The
//! binary is not a requirement — CI runs no real binary at all — so its absence
//! degrades this stage to skipped-with-reason and `check` continues on its
//! deterministic stages. Whether the delegate is run strictly is the caller's
//! choice; see [`Strictness`].
//!
//! Responsibilities: [`Validation`], [`Strictness`], [`run`].

use std::collections::BTreeMap;
use std::path::Path;

use crate::error::Error;
use crate::harness::{DEFAULT_TIMEOUT, run as spawn};

/// The delegate's verdict.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize)]
#[serde(tag = "status", rename_all = "lowercase")]
#[non_exhaustive]
pub enum Validation {
    /// The delegate exited 0.
    Passed {
        /// What it printed.
        output: String,
    },
    /// The delegate exited non-zero.
    Failed {
        /// What it printed.
        output: String,
    },
    /// The delegate could not be run at all.
    Unavailable {
        /// Why — the message `doctor` repeats.
        reason: String,
    },
}

/// The binary the validation stage delegates to.
const PROGRAM: &str = "claude";

/// Whether the delegate treats its own warnings as failures.
///
/// `claude plugin validate --strict` is `-Werror` over the same findings: a
/// strict run and a plain run report identical text, and differ only in the
/// verdict line and the exit code. So this is not "check more"; it is "fail on
/// what was already reported". Default is [`Strictness::Lenient`], because a
/// plugin whose only defect is a missing `author` field works, and a gate that
/// stops it never reaches the deterministic stages that would find a real one.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
#[non_exhaustive]
pub enum Strictness {
    /// Warnings stay warnings; the delegate exits 0.
    #[default]
    Lenient,
    /// Warnings fail. Passes `--strict` to the delegate.
    Strict,
}

/// Runs `claude plugin validate [--strict] <plugin_dir>`.
#[must_use]
pub fn run(plugin_dir: &Path, strictness: Strictness) -> Validation {
    run_program(PROGRAM, plugin_dir, strictness)
}

/// Runs `<program> plugin validate [--strict] <plugin_dir>`.
///
/// Taking the program as a parameter is what lets the tests drive all three
/// outcomes without depending on a `claude` binary being installed.
fn run_program(program: &str, plugin_dir: &Path, strictness: Strictness) -> Validation {
    // The delegate is spawned with `plugin_dir` as its working directory AND
    // handed `plugin_dir` as an argument. If that argument is relative, the
    // delegate re-resolves it against the already-changed cwd, doubling the
    // path (e.g. `a/b` inside a cwd of `a/b` becomes `a/b/a/b`). Resolving
    // once up front and using that single value for both the argv element
    // and the spawn cwd keeps the two from drifting apart.
    //
    // `absolute` never touches the filesystem, so this is not an existence
    // check: a missing directory still resolves, and the spawn below is what
    // turns it into the existing `Unavailable` outcome. std documents the
    // empty path as a rejection case, not the only one, so any error here
    // falls back to the path as given for the same reason — a hard error
    // would defeat this stage's contract of degrading rather than failing
    // the run. It also does not normalise `..` on Unix, so `check
    // ../plugin` reaches the delegate as `<cwd>/../plugin`; that is still
    // absolute, which is all the doubling fix needs.
    let resolved = std::path::absolute(plugin_dir).unwrap_or_else(|_| plugin_dir.to_path_buf());
    let mut argv = vec![
        String::from(program),
        String::from("plugin"),
        String::from("validate"),
    ];
    if strictness == Strictness::Strict {
        argv.push(String::from("--strict"));
    }
    argv.push(resolved.display().to_string());
    match spawn(&argv, &resolved, &BTreeMap::new(), None, DEFAULT_TIMEOUT) {
        Ok(captured) => {
            let output = format!("{}{}", captured.stdout, captured.stderr);
            if captured.exit == 0 {
                Validation::Passed { output }
            } else {
                Validation::Failed { output }
            }
        }
        Err(Error::Io { source, .. }) => Validation::Unavailable {
            reason: format!("cannot run `{program}`: {source}"),
        },
        Err(other) => Validation::Unavailable {
            reason: other.to_string(),
        },
    }
}

#[cfg(test)]
mod tests {
    #![expect(clippy::unwrap_used, reason = "tests unwrap known-valid fixtures")]
    #![expect(
        clippy::panic,
        reason = "let-else diagnostics in tests panic by design"
    )]

    use super::{Strictness, Validation, run_program};

    #[test]
    fn a_missing_binary_is_unavailable_with_a_reason_not_a_failure() {
        let dir = tempfile::tempdir().unwrap();
        let outcome = run_program(
            "claude-that-is-not-installed",
            dir.path(),
            Strictness::Lenient,
        );
        let Validation::Unavailable { reason } = outcome else {
            panic!("expected Unavailable, got {outcome:?}");
        };
        assert!(reason.contains("claude-that-is-not-installed"), "{reason}");
    }

    #[test]
    fn a_zero_exit_from_the_delegate_passes_the_stage() {
        let dir = tempfile::tempdir().unwrap();
        assert!(matches!(
            run_program("true", dir.path(), Strictness::Lenient),
            Validation::Passed { .. }
        ));
    }

    #[test]
    fn a_non_zero_exit_from_the_delegate_fails_the_stage() {
        let dir = tempfile::tempdir().unwrap();
        assert!(matches!(
            run_program("false", dir.path(), Strictness::Lenient),
            Validation::Failed { .. }
        ));
    }

    #[test]
    fn a_relative_plugin_dir_reaches_the_delegate_as_an_absolute_path() {
        // The delegate is spawned with `plugin_dir` as its working directory AND
        // handed `plugin_dir` as an argument. A relative argument is re-resolved
        // against that already-changed cwd, doubling the path, so the argument has
        // to be absolute before it leaves.
        let outcome = run_program(
            "echo",
            std::path::Path::new("tests/fixtures/minimal-plugin"),
            Strictness::Lenient,
        );
        let Validation::Passed { output } = outcome else {
            panic!("expected Passed, got {outcome:?}");
        };
        assert!(
            output.contains(&format!(
                "{}/tests/fixtures/minimal-plugin",
                env!("CARGO_MANIFEST_DIR")
            )),
            "the delegate must receive an absolute plugin path: {output}"
        );
    }

    #[test]
    fn the_default_delegate_invocation_carries_no_strict_flag() {
        let dir = tempfile::tempdir().unwrap();
        let log = dir.path().join("argv.txt");
        let recorder = dir.path().join("recorder.sh");
        std::fs::write(
            &recorder,
            format!("#!/bin/sh\nprintf '%s\\n' \"$@\" > {}\n", log.display()),
        )
        .unwrap();
        std::fs::set_permissions(
            &recorder,
            std::os::unix::fs::PermissionsExt::from_mode(0o755),
        )
        .unwrap();

        let _ = super::run_program(
            recorder.to_str().unwrap(),
            dir.path(),
            super::Strictness::Lenient,
        );

        let logged = std::fs::read_to_string(&log).unwrap();
        assert!(
            !logged.contains("--strict"),
            "the default invocation must not be strict: {logged}"
        );
        assert!(logged.contains("validate"), "{logged}");
    }

    #[test]
    fn strict_puts_the_flag_back() {
        let dir = tempfile::tempdir().unwrap();
        let log = dir.path().join("argv.txt");
        let recorder = dir.path().join("recorder.sh");
        std::fs::write(
            &recorder,
            format!("#!/bin/sh\nprintf '%s\\n' \"$@\" > {}\n", log.display()),
        )
        .unwrap();
        std::fs::set_permissions(
            &recorder,
            std::os::unix::fs::PermissionsExt::from_mode(0o755),
        )
        .unwrap();

        let _ = super::run_program(
            recorder.to_str().unwrap(),
            dir.path(),
            super::Strictness::Strict,
        );

        assert!(std::fs::read_to_string(&log).unwrap().contains("--strict"));
    }
}
