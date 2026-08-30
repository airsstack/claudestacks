//! The `matchers` checker: hooks.json declares documented events, and the
//! matchers written against them are ones the event accepts and claudevs can
//! evaluate.
//!
//! An event name not in [`crate::contract::event`]'s catalogue is a warning
//! rather than an error — the catalogue can lag a Claude Code release, and
//! using a newer event is not a defect. A matcher written on an event that
//! takes none is a warning naming the runtime's silent-ignore behaviour. A
//! matcher's own well-formedness is judged by [`crate::contract::matcher`],
//! which knows the exact-match and pattern modes the reference defines; this
//! checker no longer compiles a matcher as a Rust regex on its own authority.

use std::path::Path;

use serde_json::Value;

use crate::wiring::{Finding, Severity};

/// The file this checker reads, relative to the plugin root.
const HOOKS_FILE: &str = "hooks/hooks.json";

/// Checks the plugin's hooks.json, if it has one.
///
/// # Errors
///
/// Never in practice: a missing file is "nothing to check" and a malformed one
/// is a finding, because a plugin with a broken hooks.json is exactly what this
/// checker exists to report. The signature keeps the shape of its two siblings.
pub fn check(plugin_dir: &Path) -> crate::error::Result<Vec<Finding>> {
    let Ok(text) = std::fs::read_to_string(plugin_dir.join(HOOKS_FILE)) else {
        return Ok(Vec::new());
    };
    let value: Value = match serde_json::from_str(&text) {
        Ok(value) => value,
        Err(error) => {
            return Ok(vec![finding(
                Severity::Error,
                format!("is not JSON: {error}"),
            )]);
        }
    };
    let Some(events) = value.get("hooks").and_then(Value::as_object) else {
        return Ok(vec![finding(
            Severity::Error,
            String::from("has no `hooks` object at the top level"),
        )]);
    };

    let mut findings = Vec::new();
    for (event, groups) in events {
        let documented = crate::contract::event::lookup(event);
        if documented.is_none() {
            findings.push(finding(
                Severity::Warning,
                format!(
                    "`{event}` is not an event this version of claudevs knows about; \
                     it may be newer than the catalogue"
                ),
            ));
        }
        for group in groups.as_array().into_iter().flatten() {
            let Some(matcher) = group.get("matcher").and_then(Value::as_str) else {
                continue;
            };
            if let Some(documented) = documented
                && documented.matcher == crate::contract::event::MatcherSupport::None
            {
                findings.push(finding(
                    Severity::Warning,
                    format!(
                        "`{event}` takes no matcher, so `{matcher}` is silently ignored by \
                         the runtime"
                    ),
                ));
            }
            if let crate::contract::matcher::MatcherRule::Unsupported { value, reason } =
                crate::contract::matcher::parse(event, matcher)
            {
                findings.push(finding(
                    Severity::Warning,
                    format!(
                        "claudevs cannot evaluate matcher `{value}` ({reason}), so it cannot \
                         tell whether the runtime accepts it"
                    ),
                ));
            }
        }
    }
    Ok(findings)
}

/// One finding against the hooks file.
fn finding(severity: Severity, message: String) -> Finding {
    Finding {
        severity,
        checker: "matchers",
        file: String::from(HOOKS_FILE),
        line: None,
        message,
    }
}

#[cfg(test)]
mod tests {
    #![expect(clippy::unwrap_used, reason = "tests unwrap known-valid fixtures")]

    use super::check;
    use crate::wiring::Severity;

    fn plugin(hooks_json: &str) -> tempfile::TempDir {
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("hooks")).unwrap();
        std::fs::write(dir.path().join("hooks/hooks.json"), hooks_json).unwrap();
        dir
    }

    #[test]
    fn a_well_formed_hooks_file_produces_no_findings() {
        let dir = plugin(
            r#"{"hooks":{"PreToolUse":[{"matcher":"Edit|Write","hooks":[{"type":"command","command":"true"}]}]}}"#,
        );
        assert!(check(dir.path()).unwrap().is_empty());
    }

    #[test]
    fn an_unknown_event_name_is_a_warning_naming_the_offending_event() {
        let dir = plugin(r#"{"hooks":{"PreToolUseX":[{"hooks":[]}]}}"#);
        let findings = check(dir.path()).unwrap();
        assert_eq!(findings.len(), 1, "{findings:?}");
        assert_eq!(findings[0].severity, Severity::Warning);
        assert!(findings[0].message.contains("PreToolUseX"), "{findings:?}");
    }

    #[test]
    fn a_documented_event_claudevs_cannot_simulate_is_not_a_finding() {
        let dir = plugin(r#"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"true"}]}]}}"#);
        assert!(check(dir.path()).unwrap().is_empty());
    }

    #[test]
    fn a_matcher_on_an_event_that_takes_none_is_a_warning() {
        let dir = plugin(
            r#"{"hooks":{
                 "UserPromptSubmit":[{"matcher":"Edit","hooks":[{"type":"command","command":"true"}]}],
                 "SessionEnd":[{"matcher":"clear","hooks":[{"type":"command","command":"true"}]}]
               }}"#,
        );
        let findings = check(dir.path()).unwrap();
        assert_eq!(
            findings.len(),
            1,
            "SessionEnd does take a matcher; only UserPromptSubmit's is ignored: {findings:?}"
        );
        assert_eq!(findings[0].severity, Severity::Warning);
        assert!(
            findings[0].message.contains("UserPromptSubmit"),
            "{findings:?}"
        );
        assert!(findings[0].message.contains("ignored"), "{findings:?}");
    }

    #[test]
    fn a_matcher_rust_cannot_compile_is_a_warning_not_proof_the_plugin_is_broken() {
        // `Edit(` contains `(`, so it is regex-mode, and Rust's `regex` crate
        // rejects the unclosed group. An unclosed group is invalid in
        // JavaScript too, so this particular value probably *is* broken —
        // but claudevs has no JavaScript engine to confirm that, only Rust's
        // narrower one, so it reports what it can prove (a divergence it
        // cannot resolve) rather than asserting the plugin is wrong outright.
        let dir = plugin(
            r#"{"hooks":{"PreToolUse":[{"matcher":"Edit(","hooks":[{"type":"command","command":"true"}]}]}}"#,
        );
        let findings = check(dir.path()).unwrap();
        assert_eq!(findings.len(), 1, "{findings:?}");
        assert_eq!(findings[0].severity, Severity::Warning);
        assert!(findings[0].message.contains("Edit("), "{findings:?}");
    }

    #[test]
    fn a_comma_list_yields_no_finding() {
        // This does not distinguish list-mode from regex-mode: every
        // character `crate::contract::matcher::is_exact_mode_char` admits
        // also compiles as a Rust regex, so `"Edit, Write"` produced no
        // finding under the old `regex::Regex::new` path too. The list
        // semantics themselves — that it splits into two exact alternatives
        // rather than matching the literal substring `"Edit, Write"` — are
        // pinned in `crate::contract::matcher`'s
        // `a_comma_separated_value_is_a_list_and_surrounding_space_is_trimmed`.
        let dir = plugin(
            r#"{"hooks":{"PreToolUse":[{"matcher":"Edit, Write","hooks":[{"type":"command","command":"true"}]}]}}"#,
        );
        assert!(check(dir.path()).unwrap().is_empty());
    }

    #[test]
    fn a_pattern_rust_rejects_and_javascript_accepts_is_a_warning_naming_the_engine() {
        let dir = plugin(
            r#"{"hooks":{"PreToolUse":[{"matcher":"(?<=Edit)Write","hooks":[{"type":"command","command":"true"}]}]}}"#,
        );
        let findings = check(dir.path()).unwrap();
        assert_eq!(findings.len(), 1, "{findings:?}");
        assert_eq!(
            findings[0].severity,
            Severity::Warning,
            "a plugin whose pattern the runtime accepts must not be failed: {findings:?}"
        );
    }

    #[test]
    fn a_plugin_with_no_hooks_file_is_not_a_finding() {
        let dir = tempfile::tempdir().unwrap();
        assert!(check(dir.path()).unwrap().is_empty());
    }

    #[test]
    fn a_hooks_file_that_is_not_json_is_one_error_not_a_crate_error() {
        let dir = plugin("{not json");
        let findings = check(dir.path()).unwrap();
        assert_eq!(findings.len(), 1);
        assert_eq!(findings[0].severity, Severity::Error);
    }
}
