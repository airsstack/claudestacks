//! Running a plugin's suite: discovery → per-case execution → report data.
//!
//! Responsibilities: [`run_suite`], [`run_case`], [`SuiteOptions`],
//! [`SuiteReport`], [`CaseOutcome`].

#![expect(
    clippy::redundant_pub_crate,
    reason = "explicit pub(crate) documents the crate-wide visibility intent at each item"
)]

use std::path::Path;

use crate::case::{Case, CaseFile, CaseKind, Expectations, Invocation, discover};
use crate::error::{Error, Result};
use crate::harness::{
    DEFAULT_TIMEOUT, Mismatch, Observed, Project, Verdict, base_env, default_payload, judge, merge,
    observe, overlay_into, resolve_hook, run, run_handler, substitute_project,
};
use crate::native::{NativeOutcome, run_declared};
use crate::types::HookEvent;

/// Knobs for one suite run.
#[derive(Debug, Clone, Default)]
#[non_exhaustive]
pub struct SuiteOptions {
    /// Only run cases whose name contains this substring.
    pub case_filter: Option<String>,
}

/// One case's reported outcome.
#[derive(Debug, Clone, serde::Serialize)]
#[non_exhaustive]
pub struct CaseOutcome {
    /// The case name.
    pub name: String,
    /// Pass or the mismatch list.
    pub verdict: Verdict,
    /// The payload the hook was given — present only for a hook case that
    /// failed, because a case that passed needs no diagnosis and a green run
    /// should stay readable.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub payload: Option<serde_json::Value>,
    /// The handler that ran, in its display form — for an exec handler this is
    /// the argv actually spawned, which a shell-only reading of `hooks.json`
    /// makes invisible. Present under the same condition as `payload`.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub handler: Option<String>,
}

/// Everything one run produced.
#[derive(Debug, Clone, serde::Serialize)]
#[non_exhaustive]
pub struct SuiteReport {
    /// Case outcomes, in discovery order.
    pub outcomes: Vec<CaseOutcome>,
    /// Declared native suites' outcomes.
    pub native: Vec<NativeOutcome>,
}

impl SuiteReport {
    /// Whether everything passed.
    #[must_use]
    pub fn all_green(&self) -> bool {
        self.outcomes
            .iter()
            .all(|o| matches!(o.verdict, Verdict::Pass))
            && self.native.iter().all(|n| n.exit == 0)
    }
}

/// Runs the whole suite of the plugin at `plugin_dir`.
///
/// # Errors
///
/// Errors are the *inability to run* (discovery failure, unloadable case
/// files, unresolvable hooks); failing cases are outcomes, not errors.
pub fn run_suite(plugin_dir: &Path, options: &SuiteOptions) -> Result<SuiteReport> {
    // Children run inside the temp project, so a relative plugin path (the
    // CLI's default `.`) would make `CLAUDE_PLUGIN_ROOT` resolve against the
    // wrong directory — absolutize once here for every downstream consumer.
    let plugin_dir = plugin_dir.canonicalize().map_err(|source| Error::Io {
        operation: "resolve plugin dir",
        path: plugin_dir.display().to_string(),
        source,
    })?;
    let plugin_dir = plugin_dir.as_path();
    let fixtures_root = plugin_dir.join("tests/fixtures");
    let mut outcomes = Vec::new();

    for file in discover(plugin_dir)? {
        match file {
            CaseFile::Yaml(path) => {
                // The case name a filter matches against is the file stem, because a
                // file that does not load has no name of its own — and selection must
                // happen before loading, or one unloadable file decides the fate of
                // every case the user actually asked for.
                let stem = path
                    .file_stem()
                    .map_or_else(String::new, |s| s.to_string_lossy().into_owned());
                if !selected(options, &stem) {
                    continue;
                }
                match crate::case::load_yaml_case(&path) {
                    Ok(case) => outcomes.push(run_case(plugin_dir, &fixtures_root, &case)?),
                    Err(error) => outcomes.push(CaseOutcome {
                        name: stem,
                        verdict: Verdict::Fail(vec![Mismatch::DidNotRun {
                            reason: format!(
                                "load: {} could not be loaded: {error}",
                                path.display()
                            ),
                        }]),
                        payload: None,
                        handler: None,
                    }),
                }
            }
            CaseFile::Lua(path) => {
                outcomes.extend(crate::case::run_lua_file(
                    plugin_dir,
                    &fixtures_root,
                    &path,
                    options,
                )?);
            }
        }
    }

    let native = run_declared(plugin_dir)?;
    Ok(SuiteReport { outcomes, native })
}

/// Runs the whole suite against a throwaway copy of the plugin in the shape it
/// has once installed (`--installed`).
///
/// The cases are the same ones [`run_suite`] runs; only the context differs —
/// `CLAUDE_PLUGIN_ROOT` points at the cache copy, so a path that resolves only
/// in the source checkout comes apart here.
///
/// # Errors
///
/// [`Error::Manifest`] or [`Error::Layout`] when the copy cannot be built, and
/// then the same conditions as [`run_suite`].
pub fn run_suite_installed(plugin_dir: &Path, options: &SuiteOptions) -> Result<SuiteReport> {
    // The layout owns a temp dir; holding it until the run finishes is what
    // keeps the copy on disk for the children the harness spawns.
    let installed = crate::layout::Installed::materialize(plugin_dir)?;
    run_suite(installed.plugin_root(), options)
}

/// Whether `name` passes the filter.
pub(crate) fn selected(options: &SuiteOptions, name: &str) -> bool {
    options
        .case_filter
        .as_deref()
        .is_none_or(|needle| name.contains(needle))
}

/// Runs one data case.
///
/// # Errors
///
/// Same conditions as [`run_suite`].
pub fn run_case(plugin_dir: &Path, fixtures_root: &Path, case: &Case) -> Result<CaseOutcome> {
    let project = match &case.project {
        Some(fixture) => Project::from_fixture(fixtures_root, &fixture.0)?,
        None => Project::empty()?,
    };
    let project_str = project.path().display().to_string();
    let env = base_env(plugin_dir, project.path());

    // Resolved ahead of the kind match so an unresolvable hook becomes one
    // failed case rather than the end of the run.
    let resolved = match &case.kind {
        CaseKind::Hook {
            event,
            hook,
            payload,
            payload_raw,
        } => {
            let (stdin, value, reported) = stdin_for(
                *event,
                payload.as_ref(),
                payload_raw.as_deref(),
                &project_str,
            );
            match resolve_hook(plugin_dir, *event, hook.as_deref(), &value) {
                Ok(handler) => Some((handler, stdin, reported)),
                Err(Error::HookResolution { reason }) => {
                    // `hooks_file::resolve` also raises `Error::HookResolution`
                    // when hooks.json itself fails to parse as JSON — a
                    // plugin-file defect, not a case that resolved to zero or
                    // several handlers. Re-checking the file's syntax tells
                    // the two apart without hooks_file.rs carrying the
                    // distinction in its `Result` type: a malformed file
                    // aborts the run like a missing one does; a well-formed
                    // file that resolves to nothing is one failed case.
                    //
                    // The payload is reported here too: resolution routes on
                    // it, so "no handler matches this payload" is precisely
                    // the failure where the payload is the diagnostic.
                    if hooks_json_is_valid(plugin_dir) {
                        return Ok(CaseOutcome {
                            name: case.name.to_string(),
                            verdict: Verdict::Fail(vec![Mismatch::DidNotRun { reason }]),
                            payload: Some(reported),
                            handler: None,
                        });
                    }
                    return Err(Error::HookResolution { reason });
                }
                Err(other) => return Err(other),
            }
        }
        CaseKind::Script { .. } | CaseKind::Flow { .. } => None,
    };

    let (verdict, payload, handler) = match &case.kind {
        CaseKind::Hook { event, .. } => {
            // `resolved` is `Some` for exactly this arm, set above. `expect`
            // is avoided because the workspace lints `clippy::expect_used`
            // (root `Cargo.toml`, `[workspace.lints.clippy]`); `unreachable!`
            // is the idiom this file uses instead for invariants like this
            // one (see `run_flow`'s step-validation panic below).
            let (handler, stdin, reported) = resolved
                .unwrap_or_else(|| unreachable!("a hook case resolves above the kind match"));
            let captured = run_handler(
                &handler,
                project.path(),
                &env,
                Some(&stdin),
                DEFAULT_TIMEOUT,
            )?;
            let verdict = judge(&case.expect, &observe(*event, &captured), project.path());
            // Diagnostic material for a failing case only: a case that passed
            // needs no diagnosis, and a green run should stay readable.
            if matches!(verdict, Verdict::Fail(_)) {
                (verdict, Some(reported), Some(handler.display()))
            } else {
                (verdict, None, None)
            }
        }
        CaseKind::Script { invocation } => {
            let captured = run_invocation(invocation, project.path(), &env, &project_str)?;
            (
                judge(&case.expect, &script_observed(&captured), project.path()),
                None,
                None,
            )
        }
        CaseKind::Flow { steps } => (
            run_flow(
                steps,
                &case.expect,
                fixtures_root,
                project.path(),
                &env,
                &project_str,
            )?,
            None,
            None,
        ),
    };

    Ok(CaseOutcome {
        name: case.name.to_string(),
        verdict,
        payload,
        handler,
    })
}

/// Whether `plugin_dir`'s `hooks/hooks.json` parses as JSON at all.
///
/// Only answers the syntax question `hooks_file::resolve` already had to
/// answer to get as far as a resolution miss; it does not re-derive anything
/// about groups, matchers or handlers. A file that fails this check can never
/// have produced a genuine no-match or several-match outcome.
fn hooks_json_is_valid(plugin_dir: &Path) -> bool {
    let Ok(text) = std::fs::read_to_string(plugin_dir.join("hooks/hooks.json")) else {
        return false;
    };
    serde_json::from_str::<serde_json::Value>(&text).is_ok()
}

/// The stdin a hook case sends, together with two views of it: the value
/// [`resolve_hook`] routes on, and the value a failing case reports back.
///
/// For every case but `payload_raw` the two coincide: default payload ⊕
/// overlay. A `payload_raw` case deliberately sends text that may not be
/// JSON at all, so the two diverge on purpose: the routing value stays
/// [`serde_json::Value::Null`] — `group_selects` treats a payload with no
/// value at the matcher's field as unfiltered, so such a case routes as it
/// does today, a decision plan 03 left open rather than this one revisiting
/// it — while the reported value carries the raw text itself, since `Null`
/// is not what was actually sent and a failing case needs to show what was.
fn stdin_for(
    event: HookEvent,
    payload: Option<&serde_json::Value>,
    payload_raw: Option<&str>,
    project: &str,
) -> (String, serde_json::Value, serde_json::Value) {
    if let Some(raw) = payload_raw {
        return (
            raw.to_owned(),
            serde_json::Value::Null,
            serde_json::Value::String(raw.to_owned()),
        );
    }
    let mut value = default_payload(event);
    if let Some(overlay) = payload {
        merge(&mut value, overlay);
    }
    substitute_project(&mut value, project);
    let stdin = value.to_string();
    (stdin, value.clone(), value)
}

/// Runs one script invocation with `{project}` substituted in argv and env.
#[expect(
    clippy::literal_string_with_formatting_args,
    reason = "the `{project}` literal is a placeholder token replaced by str::replace, not a format string"
)]
fn run_invocation(
    invocation: &Invocation,
    cwd: &Path,
    env: &std::collections::BTreeMap<String, String>,
    project: &str,
) -> Result<crate::harness::Captured> {
    let argv: Vec<String> = invocation
        .argv
        .iter()
        .map(|a| a.replace("{project}", project))
        .collect();
    let mut child_env = env.clone();
    for (key, value) in &invocation.env {
        child_env.insert(key.clone(), value.replace("{project}", project));
    }
    run(&argv, cwd, &child_env, None, DEFAULT_TIMEOUT)
}

/// Scripts have no event semantics; the observation is the raw capture.
fn script_observed(captured: &crate::harness::Captured) -> Observed {
    Observed {
        exit: captured.exit,
        stdout: captured.stdout.clone(),
        stderr: captured.stderr.clone(),
        timed_out: captured.timed_out,
        ..Observed::default()
    }
}

/// Runs flow steps in one shared project; top-level expect judged after the last.
fn run_flow(
    steps: &[crate::case::Step],
    expect: &Expectations,
    fixtures_root: &Path,
    project_path: &Path,
    env: &std::collections::BTreeMap<String, String>,
    project_str: &str,
) -> Result<Verdict> {
    // The shared project was already materialized by the caller; steps mutate it.
    let mut last_observed: Option<Observed> = None;
    for (index, step) in steps.iter().enumerate() {
        if let Some(fixture) = &step.apply_fixture {
            overlay_into(fixtures_root, &fixture.0, project_path)?;
            continue;
        }
        let invocation = step
            .run
            .as_ref()
            .unwrap_or_else(|| unreachable!("validated in Case::from_raw"));
        let captured = run_invocation(invocation, project_path, env, project_str)?;
        let observed = script_observed(&captured);
        let default_expect = Expectations::default();
        if let Verdict::Fail(mismatches) = judge(
            step.expect.as_ref().unwrap_or(&default_expect),
            &observed,
            project_path,
        ) {
            return Ok(Verdict::Fail(
                mismatches
                    .into_iter()
                    .map(|mismatch| Mismatch::InStep {
                        index,
                        mismatch: Box::new(mismatch),
                    })
                    .collect(),
            ));
        }
        last_observed = Some(observed);
    }
    // A flow with no run steps at all (fixture overlays only) has nothing to
    // observe. `files_exist` still holds — it only inspects the project tree
    // — but any expectation that needs an actual run cannot pass vacuously
    // against a fabricated `Observed::default()`.
    match last_observed {
        Some(observed) => Ok(judge(expect, &observed, project_path)),
        None if expect.expects_a_run() => Ok(Verdict::Fail(vec![Mismatch::DidNotRun {
            reason: String::from(
                "flow: no run step executed (only `apply_fixture` steps ran); \
                 `expect` fields other than `files_exist` cannot be judged",
            ),
        }])),
        None => Ok(judge(expect, &Observed::default(), project_path)),
    }
}

#[cfg(test)]
mod tests {
    #![expect(clippy::unwrap_used, reason = "tests unwrap known-valid fixtures")]
    #![expect(
        clippy::panic,
        reason = "let-else diagnostics in tests panic by design"
    )]

    use super::{SuiteOptions, run_suite};

    /// A throwaway plugin: one `PreToolUse` gate hook + cases.
    fn plugin() -> tempfile::TempDir {
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("hooks")).unwrap();
        std::fs::create_dir_all(dir.path().join("tests/fixtures/edits")).unwrap();
        std::fs::write(dir.path().join("tests/fixtures/edits/new.md"), "x").unwrap();
        // The matcher covers both tools the harness's default `PreToolUse`
        // payload might carry (`harness::default_payload` uses `"Edit"`), so
        // these cases exercise routing the same way a real `Edit` or `Write`
        // call would.
        std::fs::write(
            dir.path().join("hooks/hooks.json"),
            r#"{"hooks":{"PreToolUse":[{"matcher":"Edit|Write","hooks":[{"type":"command","command":"sh \"${CLAUDE_PLUGIN_ROOT}/hooks/gate.sh\""}]}]}}"#,
        )
        .unwrap();
        // Deny writes that mention a lockfile; stay silent otherwise.
        std::fs::write(
            dir.path().join("hooks/gate.sh"),
            "payload=$(cat)\ncase \"$payload\" in\n  *Cargo.lock*) echo 'blocked: lockfile' >&2; exit 2 ;;\n  *) exit 0 ;;\nesac\n",
        )
        .unwrap();
        std::fs::write(
            dir.path().join("tests/blocks-lockfile.yaml"),
            "event: PreToolUse\npayload:\n  tool_input:\n    file_path: Cargo.lock\nexpect:\n  decision: deny\n  stderr_contains: lockfile\n",
        )
        .unwrap();
        std::fs::write(
            dir.path().join("tests/allows-clean.yaml"),
            "event: PreToolUse\nexpect:\n  output: none\n  exit: 0\n",
        )
        .unwrap();
        std::fs::write(
            dir.path().join("tests/flow-writes.yaml"),
            "steps:\n  - run:\n      argv: [sh, -c, \"echo made > out.txt\"]\n    expect:\n      exit: 0\n  - apply_fixture: edits\nexpect:\n  files_exist: [out.txt, new.md]\n",
        )
        .unwrap();
        dir
    }

    #[test]
    fn the_three_case_kinds_run_green_against_the_gate_plugin() {
        let dir = plugin();
        let report = run_suite(dir.path(), &SuiteOptions::default()).unwrap();
        assert_eq!(report.outcomes.len(), 3, "{report:?}");
        assert!(report.all_green(), "{report:?}");
    }

    #[test]
    fn a_wrong_expectation_fails_that_case_and_only_that_case() {
        let dir = plugin();
        std::fs::write(
            dir.path().join("tests/wrong.yaml"),
            "event: PreToolUse\npayload:\n  tool_input:\n    file_path: Cargo.lock\nexpect:\n  decision: allow\n",
        )
        .unwrap();
        let report = run_suite(dir.path(), &SuiteOptions::default()).unwrap();
        assert!(!report.all_green());
        let failed: Vec<_> = report
            .outcomes
            .iter()
            .filter(|o| !matches!(o.verdict, crate::harness::Verdict::Pass))
            .collect();
        assert_eq!(failed.len(), 1);
        assert_eq!(failed[0].name, "wrong");
    }

    #[test]
    fn a_flows_top_level_expect_is_judged_against_the_last_steps_observation() {
        // The top-level `expect` must see what the last step actually did,
        // not a fabricated `Observed::default()` (exit 0, empty stdout).
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("tests")).unwrap();
        std::fs::write(
            dir.path().join("tests/flow-lies.yaml"),
            "steps:\n  - run:\n      argv: [sh, -c, \"echo hi; exit 7\"]\nexpect:\n  exit: 0\n  stdout_contains: hi\n",
        )
        .unwrap();
        let report = run_suite(dir.path(), &SuiteOptions::default()).unwrap();
        assert_eq!(report.outcomes.len(), 1);
        let crate::harness::Verdict::Fail(mismatches) = &report.outcomes[0].verdict else {
            panic!("exit: expected 0, got 7 must fail this case, {report:?}");
        };
        assert!(
            mismatches
                .iter()
                .any(|m| matches!(m, crate::harness::Mismatch::Exit { .. })),
            "{mismatches:?}"
        );
        assert!(
            !mismatches
                .iter()
                .any(|m| matches!(m, crate::harness::Mismatch::StdoutMissing { .. })),
            "stdout_contains `hi` should pass against a step that printed it: {mismatches:?}"
        );
    }

    #[test]
    fn a_flow_with_no_run_step_fails_a_non_files_exist_expectation_instead_of_passing_vacuously() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("tests/fixtures/edits")).unwrap();
        std::fs::write(dir.path().join("tests/fixtures/edits/new.md"), "x").unwrap();
        std::fs::write(
            dir.path().join("tests/flow-no-run.yaml"),
            "steps:\n  - apply_fixture: edits\nexpect:\n  exit: 0\n",
        )
        .unwrap();
        let report = run_suite(dir.path(), &SuiteOptions::default()).unwrap();
        assert_eq!(report.outcomes.len(), 1);
        let crate::harness::Verdict::Fail(mismatches) = &report.outcomes[0].verdict else {
            panic!("a flow with no run step must not pass `exit: 0` vacuously, {report:?}");
        };
        assert!(!mismatches.is_empty());
    }

    #[test]
    fn a_flow_with_no_run_step_still_judges_files_exist() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("tests/fixtures/edits")).unwrap();
        std::fs::write(dir.path().join("tests/fixtures/edits/new.md"), "x").unwrap();
        std::fs::write(
            dir.path().join("tests/flow-no-run-files.yaml"),
            "steps:\n  - apply_fixture: edits\nexpect:\n  files_exist: [new.md]\n",
        )
        .unwrap();
        let report = run_suite(dir.path(), &SuiteOptions::default()).unwrap();
        assert_eq!(report.outcomes.len(), 1);
        assert!(report.all_green(), "{report:?}");
    }

    #[test]
    fn the_case_filter_narrows_the_run() {
        let dir = plugin();
        let report = run_suite(
            dir.path(),
            &SuiteOptions {
                case_filter: Some(String::from("blocks")),
            },
        )
        .unwrap();
        assert_eq!(report.outcomes.len(), 1);
    }

    #[test]
    fn an_unselected_unloadable_case_file_is_never_loaded_and_the_run_still_succeeds() {
        // The filter excludes this file's stem, so a correct run must never
        // attempt to load it — the file's YAML is broken on purpose, and if
        // loading were attempted the run would abort instead of succeeding.
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("tests")).unwrap();
        std::fs::write(
            dir.path().join("tests/broken.yaml"),
            "event: PreToolUse\nexpct: {}\n",
        )
        .unwrap();

        let report = run_suite(
            dir.path(),
            &SuiteOptions {
                case_filter: Some(String::from("keeper")),
            },
        )
        .unwrap();
        assert!(report.outcomes.is_empty(), "{report:?}");
        assert!(report.all_green(), "{report:?}");
    }

    #[test]
    fn one_unloadable_case_file_does_not_take_its_valid_sibling_down() {
        let dir = tempfile::tempdir().unwrap();
        let plugin = dir.path();
        std::fs::create_dir_all(plugin.join(".claude-plugin")).unwrap();
        std::fs::write(
            plugin.join(".claude-plugin/plugin.json"),
            r#"{"name":"p","version":"0.1.0"}"#,
        )
        .unwrap();
        std::fs::create_dir_all(plugin.join("hooks")).unwrap();
        std::fs::write(
            plugin.join("hooks/hooks.json"),
            r#"{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"true"}]}]}}"#,
        )
        .unwrap();
        std::fs::create_dir_all(plugin.join("tests/cases")).unwrap();
        std::fs::write(
            plugin.join("tests/cases/a-valid.yaml"),
            "event: SessionStart\nexpect:\n  exit: 0\n",
        )
        .unwrap();
        std::fs::write(
            plugin.join("tests/cases/b-broken.yaml"),
            "event: SessionStart\nexpect:\n  output: banana\n",
        )
        .unwrap();

        let report = super::run_suite(plugin, &super::SuiteOptions::default()).unwrap();
        let names: Vec<&str> = report.outcomes.iter().map(|o| o.name.as_str()).collect();
        assert_eq!(names.len(), 2, "{names:?}");
        assert!(names.contains(&"a-valid"));
        assert!(
            matches!(
                report
                    .outcomes
                    .iter()
                    .find(|o| o.name == "b-broken")
                    .map(|o| &o.verdict),
                Some(crate::harness::Verdict::Fail(_)),
            ),
            "the unloadable case is one failed case, not the death of the run"
        );
    }

    #[test]
    fn a_case_that_resolves_to_nothing_does_not_take_the_suite_down() {
        let dir = tempfile::tempdir().unwrap();
        let plugin = dir.path();
        std::fs::create_dir_all(plugin.join(".claude-plugin")).unwrap();
        std::fs::write(
            plugin.join(".claude-plugin/plugin.json"),
            r#"{"name":"p","version":"0.1.0"}"#,
        )
        .unwrap();
        std::fs::create_dir_all(plugin.join("hooks")).unwrap();
        // SessionStart is wired; SessionEnd is not.
        std::fs::write(
            plugin.join("hooks/hooks.json"),
            r#"{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"true"}]}]}}"#,
        )
        .unwrap();
        std::fs::create_dir_all(plugin.join("tests/cases")).unwrap();
        std::fs::write(
            plugin.join("tests/cases/a-resolves.yaml"),
            "event: SessionStart\nexpect:\n  exit: 0\n",
        )
        .unwrap();
        std::fs::write(
            plugin.join("tests/cases/b-wires-nothing.yaml"),
            "event: SessionEnd\nexpect:\n  exit: 0\n",
        )
        .unwrap();

        let report = super::run_suite(plugin, &super::SuiteOptions::default()).unwrap();
        let names: Vec<&str> = report.outcomes.iter().map(|o| o.name.as_str()).collect();
        assert_eq!(names.len(), 2, "{names:?}");
        assert!(names.contains(&"a-resolves"));
        let Some(unresolved) = report.outcomes.iter().find(|o| o.name == "b-wires-nothing") else {
            panic!("the unresolvable case is still an outcome: {names:?}");
        };
        assert!(
            matches!(unresolved.verdict, crate::harness::Verdict::Fail(_)),
            "an unwired event is one failed case, not the death of the run: {:?}",
            unresolved.verdict
        );
        // The payload was already built before resolution missed — it is the
        // one piece of diagnostic material that explains *why* nothing
        // matched, so a resolution miss must not throw it away.
        let Some(payload) = unresolved.payload.as_ref() else {
            panic!("a resolution miss reports the payload it would have routed on: {unresolved:?}");
        };
        assert_eq!(payload["hook_event_name"], "SessionEnd");
        assert!(
            unresolved.handler.is_none(),
            "nothing resolved, so there is no handler to name: {unresolved:?}"
        );
    }

    #[test]
    fn a_failing_raw_payload_case_reports_the_text_it_actually_sent() {
        // `payload_raw` deliberately sends text that is not JSON, so the
        // value `resolve_hook` routes on is `Value::Null` (plan 03's finding
        // 15, left as a routing decision). What the report echoes back on
        // failure is a different question: the raw text is exactly what an
        // author needs to see, and `Null` is not it.
        let dir = tempfile::tempdir().unwrap();
        let plugin = dir.path();
        std::fs::create_dir_all(plugin.join(".claude-plugin")).unwrap();
        std::fs::write(
            plugin.join(".claude-plugin/plugin.json"),
            r#"{"name":"p","version":"0.1.0"}"#,
        )
        .unwrap();
        std::fs::create_dir_all(plugin.join("hooks")).unwrap();
        std::fs::write(
            plugin.join("hooks/hooks.json"),
            r#"{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"true"}]}]}}"#,
        )
        .unwrap();
        std::fs::create_dir_all(plugin.join("tests/cases")).unwrap();
        std::fs::write(
            plugin.join("tests/cases/a-raw.yaml"),
            "event: SessionStart\npayload_raw: \"not json at all\"\nexpect:\n  stdout_contains: never-printed\n",
        )
        .unwrap();

        let report = super::run_suite(plugin, &super::SuiteOptions::default()).unwrap();
        let outcome = &report.outcomes[0];
        assert!(matches!(outcome.verdict, crate::harness::Verdict::Fail(_)));
        assert_eq!(
            outcome.payload,
            Some(serde_json::Value::String(String::from("not json at all"))),
            "{outcome:?}"
        );
    }

    #[test]
    fn a_failing_hook_case_reports_the_payload_it_sent_and_the_handler_it_ran() {
        let dir = tempfile::tempdir().unwrap();
        let plugin = dir.path();
        std::fs::create_dir_all(plugin.join(".claude-plugin")).unwrap();
        std::fs::write(
            plugin.join(".claude-plugin/plugin.json"),
            r#"{"name":"p","version":"0.1.0"}"#,
        )
        .unwrap();
        std::fs::create_dir_all(plugin.join("hooks")).unwrap();
        // A hook that prints nothing, against a case that asserts it printed.
        std::fs::write(
            plugin.join("hooks/hooks.json"),
            r#"{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"true"}]}]}}"#,
        )
        .unwrap();
        std::fs::create_dir_all(plugin.join("tests/cases")).unwrap();
        std::fs::write(
            plugin.join("tests/cases/a-silent-hook.yaml"),
            "event: SessionStart\nexpect:\n  stdout_contains: never-printed\n",
        )
        .unwrap();

        let report = super::run_suite(plugin, &super::SuiteOptions::default()).unwrap();
        let outcome = &report.outcomes[0];
        assert!(matches!(outcome.verdict, crate::harness::Verdict::Fail(_)));

        let Some(payload) = outcome.payload.as_ref() else {
            panic!("a failing hook case reports the payload it sent");
        };
        // `hook_event_name` and the handler string are stable, deterministic
        // fields; the rest of a real payload (e.g. `cwd`) carries the
        // temp-project's absolute path, so this test does not assert on the
        // payload as a whole.
        assert_eq!(payload["hook_event_name"], "SessionStart");
        assert_eq!(outcome.handler.as_deref(), Some("true"));

        // `--json` is where this material actually reaches a consumer today:
        // `CaseOutcome` derives `Serialize` directly, so `render_json` carries
        // the two new fields with no change to the renderer. Rendering them
        // into `render_human`'s text is a separate, concurrently-owned change
        // to `report/render.rs` and is not exercised here.
        let json = crate::report::render_json(&report).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();
        assert_eq!(
            parsed["outcomes"][0]["payload"]["hook_event_name"], "SessionStart",
            "{json}"
        );
        assert_eq!(parsed["outcomes"][0]["handler"], "true", "{json}");
    }

    #[test]
    fn a_passing_hook_case_does_not_echo_its_payload() {
        // A green run stays readable. The payload is diagnostic material, and
        // a case that passed needs no diagnosis.
        let dir = tempfile::tempdir().unwrap();
        let plugin = dir.path();
        std::fs::create_dir_all(plugin.join(".claude-plugin")).unwrap();
        std::fs::write(
            plugin.join(".claude-plugin/plugin.json"),
            r#"{"name":"p","version":"0.1.0"}"#,
        )
        .unwrap();
        std::fs::create_dir_all(plugin.join("hooks")).unwrap();
        std::fs::write(
            plugin.join("hooks/hooks.json"),
            r#"{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"true"}]}]}}"#,
        )
        .unwrap();
        std::fs::create_dir_all(plugin.join("tests/cases")).unwrap();
        std::fs::write(
            plugin.join("tests/cases/a-quiet-hook.yaml"),
            "event: SessionStart\nexpect:\n  exit: 0\n",
        )
        .unwrap();

        let report = super::run_suite(plugin, &super::SuiteOptions::default()).unwrap();
        assert!(matches!(
            report.outcomes[0].verdict,
            crate::harness::Verdict::Pass
        ));
        assert!(report.outcomes[0].payload.is_none());
        assert!(report.outcomes[0].handler.is_none());

        let json = crate::report::render_json(&report).unwrap();
        assert!(
            !json.contains("\"payload\""),
            "a passing case must not carry a `payload` key at all: {json}"
        );
        assert!(
            !json.contains("\"handler\""),
            "a passing case must not carry a `handler` key at all: {json}"
        );
    }

    #[test]
    fn an_exec_handlers_argv_is_what_the_report_names_not_the_shell_command() {
        // The spec's motivating gap: a shell-only reading of hooks.json cannot
        // see what an exec handler actually spawned. `args` makes the entry
        // an exec handler (see `contract::handler::from_entry`), and its
        // display form is the argv joined by spaces.
        let dir = tempfile::tempdir().unwrap();
        let plugin = dir.path();
        std::fs::create_dir_all(plugin.join(".claude-plugin")).unwrap();
        std::fs::write(
            plugin.join(".claude-plugin/plugin.json"),
            r#"{"name":"p","version":"0.1.0"}"#,
        )
        .unwrap();
        std::fs::create_dir_all(plugin.join("hooks")).unwrap();
        std::fs::write(
            plugin.join("hooks/hooks.json"),
            r#"{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"true","args":["ignored"]}]}]}}"#,
        )
        .unwrap();
        std::fs::create_dir_all(plugin.join("tests/cases")).unwrap();
        std::fs::write(
            plugin.join("tests/cases/a-silent-exec-hook.yaml"),
            "event: SessionStart\nexpect:\n  stdout_contains: never-printed\n",
        )
        .unwrap();

        let report = super::run_suite(plugin, &super::SuiteOptions::default()).unwrap();
        let outcome = &report.outcomes[0];
        assert!(matches!(outcome.verdict, crate::harness::Verdict::Fail(_)));
        assert_eq!(
            outcome.handler.as_deref(),
            Some("true ignored"),
            "{outcome:?}"
        );
    }

    #[test]
    fn a_malformed_hooks_json_aborts_the_run_instead_of_becoming_a_failed_case() {
        let dir = tempfile::tempdir().unwrap();
        let plugin = dir.path();
        std::fs::create_dir_all(plugin.join(".claude-plugin")).unwrap();
        std::fs::write(
            plugin.join(".claude-plugin/plugin.json"),
            r#"{"name":"p","version":"0.1.0"}"#,
        )
        .unwrap();
        std::fs::create_dir_all(plugin.join("hooks")).unwrap();
        // Truncated JSON: a plugin-file defect, not a case that resolved to
        // zero or several handlers.
        std::fs::write(plugin.join("hooks/hooks.json"), r#"{"hooks":"#).unwrap();
        std::fs::create_dir_all(plugin.join("tests/cases")).unwrap();
        std::fs::write(
            plugin.join("tests/cases/a.yaml"),
            "event: SessionStart\nexpect:\n  exit: 0\n",
        )
        .unwrap();

        let outcome = super::run_suite(plugin, &super::SuiteOptions::default());
        let Err(error) = &outcome else {
            panic!(
                "a malformed hooks.json must abort the run, not become a failed case: {outcome:?}"
            );
        };
        let message = error.to_string();
        assert!(
            message.contains("hooks.json"),
            "the run-level error should name the broken file: {message}"
        );
    }
}
