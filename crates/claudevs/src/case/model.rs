//! The canonical case model.
//!
//! One type means "a test case": both front-ends (YAML, Lua data tables)
//! deserialize a `serde_json::Value` into [`RawCase`] and convert with
//! [`Case::from_raw`]. Nothing else in the crate models a case.
//!
//! Responsibilities: [`Case`], [`CaseKind`], [`Expectations`], [`Decision`],
//! [`Invocation`], [`Step`], [`FixtureRef`], [`RawCase`].

use std::collections::BTreeMap;

use crate::types::{CaseName, HookEvent};

/// A named fixture directory under `tests/fixtures/`.
///
/// Not a validated newtype — the field is `pub` and unvalidated, so this is a
/// transparent wrapper a caller only ever reads back (from a loaded [`Case`]
/// or [`Step`]), never builds from a literal. `#[non_exhaustive]` documents
/// that read-only contract.
///
/// On a tuple struct the attribute also closes the constructor to other
/// crates, so downstream code can neither build one nor destructure it. Which
/// diagnostic that produces depends on how the type is named at the site.
/// With it imported, `let FixtureRef(name) = fixture;` is
/// `error[E0532]: cannot match against a tuple struct which contains private
/// fields` and `FixtureRef(s)` is `error[E0423]: cannot initialize a tuple
/// struct which contains private fields`; named through its path, the same
/// pattern is instead ``error[E0603]: tuple struct constructor `FixtureRef`
/// is private``. Reading the name through `.0` stays available in every form.
#[derive(Debug, Clone, PartialEq, Eq, serde::Deserialize, serde::Serialize)]
#[non_exhaustive]
pub struct FixtureRef(pub String);

/// A command to spawn: argv plus environment overrides.
#[derive(Debug, Clone, PartialEq, Eq, serde::Deserialize, serde::Serialize)]
#[serde(deny_unknown_fields)]
pub struct Invocation {
    /// Program and arguments.
    pub argv: Vec<String>,
    /// Extra environment for the child.
    #[serde(default)]
    pub env: BTreeMap<String, String>,
}

/// The decision a hook communicates about a tool call.
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Deserialize, serde::Serialize)]
#[serde(rename_all = "lowercase")]
#[non_exhaustive]
pub enum Decision {
    /// The call may proceed.
    Allow,
    /// The call is refused.
    Deny,
    /// The user must confirm.
    Ask,
    /// The hook defers to the permission system.
    Defer,
}

/// What a case asserts about an observed run — meaning, not mechanics: a case
/// says `decision: deny`, never an exit code, and the harness owns the
/// translation from an observed run into that meaning.
#[derive(Debug, Clone, Default, PartialEq, Eq, serde::Deserialize, serde::Serialize)]
#[serde(deny_unknown_fields)]
#[non_exhaustive]
pub struct Expectations {
    /// Exact exit code.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub exit: Option<i32>,
    /// The hook's decision.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub decision: Option<Decision>,
    /// `"none"`: the hook must emit no envelope and no context at all.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub output: Option<String>,
    /// Substring the injected context must contain.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub context_contains: Option<String>,
    /// Substring stdout must contain.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub stdout_contains: Option<String>,
    /// Substring stderr must contain.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub stderr_contains: Option<String>,
    /// Paths (relative to the temp project) that must exist afterwards.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub files_exist: Vec<String>,
}

impl Expectations {
    /// Whether this expects anything that requires an actual run to have
    /// happened — everything except `files_exist`, which only inspects the
    /// project tree and holds even when no command ever ran (a flow made of
    /// `apply_fixture` steps alone, say).
    #[must_use]
    pub const fn expects_a_run(&self) -> bool {
        self.exit.is_some()
            || self.decision.is_some()
            || self.output.is_some()
            || self.context_contains.is_some()
            || self.stdout_contains.is_some()
            || self.stderr_contains.is_some()
    }
}

/// One step of a flow.
#[derive(Debug, Clone, PartialEq, Eq, serde::Deserialize, serde::Serialize)]
#[serde(deny_unknown_fields)]
#[non_exhaustive]
pub struct Step {
    /// A command to run (absent for a pure fixture-overlay step).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub run: Option<Invocation>,
    /// Expectations gating this step (meaningful only with `run`).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub expect: Option<Expectations>,
    /// A fixture to overlay into the shared project.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub apply_fixture: Option<FixtureRef>,
}

/// What kind of case this is.
#[derive(Debug, Clone, PartialEq, Eq)]
#[non_exhaustive]
pub enum CaseKind {
    /// Spawn one hook with a payload on stdin.
    Hook {
        /// The event whose semantics judge the run.
        event: HookEvent,
        /// Optional disambiguator: substring of the hooks.json command.
        hook: Option<String>,
        /// Payload fields overlaid on the built-in default (`None` = default only).
        payload: Option<serde_json::Value>,
        /// Raw stdin override (hostile-input cases); excludes `payload`.
        payload_raw: Option<String>,
    },
    /// Spawn one command.
    Script {
        /// What to run.
        invocation: Invocation,
    },
    /// Run steps sequentially in one shared project.
    Flow {
        /// The steps, in order.
        steps: Vec<Step>,
    },
}

/// A fully-validated test case.
#[derive(Debug, Clone, PartialEq, Eq)]
#[non_exhaustive]
pub struct Case {
    /// Reporting identity.
    pub name: CaseName,
    /// What to do.
    pub kind: CaseKind,
    /// Fixture to materialize as the temp project.
    pub project: Option<FixtureRef>,
    /// Judged after the run (Hook/Script) or after the last step (Flow).
    pub expect: Expectations,
}

/// The permissive serde shape both front-ends produce.
///
/// Unknown fields are rejected here (`deny_unknown_fields`), which is the typo
/// guard the spec requires of the YAML tier; kind validation happens in
/// [`Case::from_raw`] because "exactly one of event/argv/steps" is not a serde
/// concept.
#[derive(Debug, Clone, serde::Deserialize)]
#[serde(deny_unknown_fields)]
#[non_exhaustive]
pub struct RawCase {
    /// Hook kind: the event name.
    #[serde(default)]
    pub event: Option<String>,
    /// Hook kind: command disambiguator.
    #[serde(default)]
    pub hook: Option<String>,
    /// Hook kind: payload overlay.
    #[serde(default)]
    pub payload: Option<serde_json::Value>,
    /// Hook kind: raw stdin override.
    #[serde(default)]
    pub payload_raw: Option<String>,
    /// Script kind: the invocation.
    #[serde(default)]
    pub invocation: Option<Invocation>,
    /// Flow kind: the steps.
    #[serde(default)]
    pub steps: Option<Vec<Step>>,
    /// Fixture to materialize.
    #[serde(default)]
    pub project: Option<ProjectField>,
    /// The expectations.
    #[serde(default)]
    pub expect: Expectations,
}

/// `project:` accepts `fixture: name` (mapping) or a bare fixture name.
#[derive(Debug, Clone, serde::Deserialize)]
#[serde(untagged)]
#[non_exhaustive]
pub enum ProjectField {
    /// `project: { fixture: rust-repo }`
    Tagged {
        /// The fixture name.
        fixture: FixtureRef,
    },
    /// `project: rust-repo`
    Bare(FixtureRef),
}

/// Why `expect.output` cannot be asserted outside a hook case.
const OUTPUT_IS_A_HOOK_ASSERTION: &str = "`expect.output` is a hook assertion: only a hook observation records whether \
     anything was emitted, so this expectation could never fail here";

impl Case {
    /// Validates a [`RawCase`] into a [`Case`].
    ///
    /// # Errors
    ///
    /// Returns a human-readable reason when the raw shape names no kind, more
    /// than one kind, an unknown event, or both `payload` and `payload_raw`.
    pub fn from_raw(name: CaseName, raw: RawCase) -> Result<Self, String> {
        let kinds = usize::from(raw.event.is_some())
            + usize::from(raw.invocation.is_some())
            + usize::from(raw.steps.is_some());
        if kinds != 1 {
            return Err(format!(
                "a case is exactly one of hook (`event:`), script (`invocation:`) or flow (`steps:`); found {kinds}"
            ));
        }

        let kind = if let Some(event) = raw.event {
            if raw.payload.is_some() && raw.payload_raw.is_some() {
                return Err("`payload` and `payload_raw` are mutually exclusive".into());
            }
            CaseKind::Hook {
                event: event.parse().map_err(|e| format!("{e}"))?,
                hook: raw.hook,
                payload: raw.payload,
                payload_raw: raw.payload_raw,
            }
        } else if let Some(invocation) = raw.invocation {
            CaseKind::Script { invocation }
        } else {
            let steps = raw.steps.unwrap_or_default();
            for (index, step) in steps.iter().enumerate() {
                if step.run.is_some() == step.apply_fixture.is_some() {
                    return Err(format!(
                        "flow step {index}: exactly one of `run` or `apply_fixture`"
                    ));
                }
            }
            CaseKind::Flow { steps }
        };

        if let Some(output) = &raw.expect.output {
            if output != "none" {
                return Err(format!(
                    "`expect.output` only accepts \"none\", got `{output}`"
                ));
            }
            if !matches!(kind, CaseKind::Hook { .. }) {
                return Err(String::from(OUTPUT_IS_A_HOOK_ASSERTION));
            }
        }
        if let CaseKind::Flow { steps } = &kind {
            for (index, step) in steps.iter().enumerate() {
                let Some(expect) = &step.expect else {
                    continue;
                };
                match expect.output.as_deref() {
                    None => {}
                    Some("none") => {
                        return Err(format!("flow step {index}: {OUTPUT_IS_A_HOOK_ASSERTION}"));
                    }
                    Some(other) => {
                        return Err(format!(
                            "flow step {index}: `expect.output` only accepts \"none\", got `{other}`"
                        ));
                    }
                }
            }
        }

        Ok(Self {
            name,
            kind,
            project: raw.project.map(|p| match p {
                ProjectField::Tagged { fixture } | ProjectField::Bare(fixture) => fixture,
            }),
            expect: raw.expect,
        })
    }
}

#[cfg(test)]
mod tests {
    #![expect(clippy::unwrap_used, reason = "tests unwrap known-valid fixtures")]

    use super::{Case, CaseKind, RawCase};
    use crate::types::CaseName;

    fn case(json: serde_json::Value) -> Result<Case, String> {
        let raw: RawCase = serde_json::from_value(json).map_err(|e| e.to_string())?;
        Case::from_raw(CaseName::new("t").unwrap(), raw)
    }

    #[test]
    fn a_hook_case_parses_with_event_payload_and_expect() {
        let parsed = case(serde_json::json!({
            "event": "PreToolUse",
            "payload": { "tool_input": { "file_path": "Cargo.lock" } },
            "expect": { "decision": "deny", "stderr_contains": "lockfile" }
        }))
        .unwrap();
        assert!(matches!(parsed.kind, CaseKind::Hook { .. }));
        assert_eq!(parsed.expect.stderr_contains.as_deref(), Some("lockfile"));
    }

    #[test]
    fn an_unknown_field_is_rejected_not_ignored() {
        let error = case(serde_json::json!({
            "event": "PreToolUse",
            "expct": {}
        }))
        .unwrap_err();
        assert!(error.contains("expct"), "{error}");
    }

    #[test]
    fn zero_or_two_kinds_are_rejected() {
        assert!(case(serde_json::json!({ "expect": {} })).is_err());
        assert!(
            case(serde_json::json!({
                "event": "PreToolUse",
                "invocation": { "argv": ["true"] }
            }))
            .is_err()
        );
    }

    #[test]
    fn payload_and_payload_raw_are_mutually_exclusive() {
        assert!(
            case(serde_json::json!({
                "event": "PreToolUse",
                "payload": {},
                "payload_raw": "{not json"
            }))
            .is_err()
        );
    }

    #[test]
    fn a_flow_step_is_exactly_run_or_apply_fixture() {
        assert!(
            case(serde_json::json!({
                "steps": [ { "expect": {} } ]
            }))
            .is_err()
        );
        assert!(
            case(serde_json::json!({
                "steps": [ { "run": { "argv": ["true"] } }, { "apply_fixture": "edits" } ]
            }))
            .is_ok()
        );
    }

    #[test]
    fn expect_output_accepts_only_none() {
        assert!(
            case(serde_json::json!({
                "event": "SessionStart", "expect": { "output": "none" }
            }))
            .is_ok()
        );
        assert!(
            case(serde_json::json!({
                "event": "SessionStart", "expect": { "output": "verbose" }
            }))
            .is_err()
        );
    }

    #[test]
    fn output_none_is_accepted_on_a_hook_case() {
        let parsed = case(serde_json::json!({
            "event": "PreToolUse",
            "expect": { "output": "none" }
        }));
        assert!(parsed.is_ok(), "{parsed:?}");
    }

    #[test]
    fn output_none_is_refused_on_a_script_case_because_it_could_never_fail() {
        let error = case(serde_json::json!({
            "invocation": { "argv": ["true"] },
            "expect": { "output": "none" }
        }))
        .unwrap_err();
        assert!(error.contains("output"), "{error}");
        assert!(error.contains("hook"), "{error}");
    }

    #[test]
    fn output_none_is_refused_on_a_flow_case_for_the_same_reason() {
        let error = case(serde_json::json!({
            "steps": [{ "run": { "argv": ["true"] } }],
            "expect": { "output": "none" }
        }))
        .unwrap_err();
        assert!(error.contains("output"), "{error}");
    }

    #[test]
    fn output_none_is_refused_inside_a_flow_step_too() {
        let error = case(serde_json::json!({
            "steps": [{
                "run": { "argv": ["true"] },
                "expect": { "output": "none" }
            }]
        }))
        .unwrap_err();
        assert!(error.contains("output"), "{error}");
    }

    #[test]
    fn the_refusal_names_the_offending_steps_own_index() {
        let error = case(serde_json::json!({
            "steps": [
                { "run": { "argv": ["true"] } },
                {
                    "run": { "argv": ["true"] },
                    "expect": { "output": "none" }
                }
            ]
        }))
        .unwrap_err();
        assert!(
            error.contains("flow step 1"),
            "the offender is the second step (index 1): {error}"
        );
    }
}
