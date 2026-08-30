//! What an observed run *means*, per hook event.
//!
//! The one place the exit-code and envelope knowledge lives: cases
//! state meaning (`decision: deny`) and this module translates observation into
//! it. Grounded rules, each carried by a test:
//!
//! - A JSON envelope on stdout may carry a decision through any of three
//!   read shapes: `hookSpecificOutput.permissionDecision`,
//!   `hookSpecificOutput.decision.behavior`, or a top-level `decision`
//!   string. [`crate::contract::event::DecisionMechanism`] enumerates twelve
//!   documented mechanisms in total; these three shapes are the ones
//!   `observe` reads, the rest are not. The reference states no precedence
//!   between the JSON forms; claudevs reads them most-specific-first —
//!   `permissionDecision`, then `hookSpecificOutput.decision.behavior`, then
//!   the top-level `decision` field — as its own choice, not a documented
//!   rule. `hookSpecificOutput.additionalContext` carries injected context
//!   independently of any of these.
//! - Separately from any JSON envelope, `PreToolUse` treats exit code 2 as a
//!   denial.
//! - A hook's bare stdout (no envelope) is injected context on whichever
//!   events [`crate::contract::event`]'s catalogue marks `stdout_is_context`,
//!   read from there rather than listed again here.

use crate::case::Decision;
use crate::harness::Captured;
use crate::types::HookEvent;

/// The meaning extracted from one captured run.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
#[non_exhaustive]
pub struct Observed {
    /// Exit code.
    pub exit: i32,
    /// The decision, when one was communicated.
    pub decision: Option<Decision>,
    /// Injected context, when any was communicated.
    pub context: Option<String>,
    /// Whether the hook emitted any envelope or context at all.
    pub emitted: bool,
    /// Whether the child was killed by the case timeout.
    pub timed_out: bool,
    /// Raw stdout.
    pub stdout: String,
    /// Raw stderr.
    pub stderr: String,
}

/// `hookSpecificOutput.permissionDecision` (allow/deny/ask/defer) or
/// `hookSpecificOutput.decision.behavior` (allow/deny), per the reference's
/// per-field spellings. `"block"` is deliberately not accepted here: the
/// reference spells denial `"deny"` in both of these fields and reserves
/// `"block"` for the top-level `decision` field, read by
/// [`decision_from_top_level`]. A value neither the reference nor this
/// function recognises leaves the decision unset while still counting as an
/// emission — a hook that wrote an envelope did emit, whatever it put in it.
fn decision_from(value: &str) -> Option<Decision> {
    match value {
        "allow" => Some(Decision::Allow),
        "deny" => Some(Decision::Deny),
        "ask" => Some(Decision::Ask),
        "defer" => Some(Decision::Defer),
        _ => None,
    }
}

/// The top-level `decision` string, which the reference spells `"block"`
/// for denial rather than the `"deny"` [`decision_from`] reads from the
/// `hookSpecificOutput` fields.
fn decision_from_top_level(value: &str) -> Option<Decision> {
    match value {
        "block" => Some(Decision::Deny),
        _ => None,
    }
}

/// Interprets `captured` under `event`'s semantics.
#[must_use]
pub fn observe(event: HookEvent, captured: &Captured) -> Observed {
    let mut observed = Observed {
        exit: captured.exit,
        stdout: captured.stdout.clone(),
        stderr: captured.stderr.clone(),
        timed_out: captured.timed_out,
        ..Observed::default()
    };

    let envelope: Option<serde_json::Value> = serde_json::from_str(captured.stdout.trim()).ok();
    let specific = envelope.as_ref().and_then(|e| e.get("hookSpecificOutput"));
    // `as_str` is what separates the top-level `decision: "block"` string from
    // `hookSpecificOutput.decision`, which is an object. A top-level `decision`
    // that is not a string is not this mechanism.
    let top_level = envelope
        .as_ref()
        .and_then(|e| e.get("decision"))
        .and_then(serde_json::Value::as_str);

    if specific.is_some() || top_level.is_some() {
        observed.emitted = true;

        // Precedence runs most-specific-first: `permissionDecision`, then
        // `hookSpecificOutput.decision.behavior`, then the top-level `decision`
        // field. The reference states no precedence between them, so this is
        // claudevs' choice and not a documented rule.
        let permission = specific
            .and_then(|s| s.get("permissionDecision"))
            .and_then(serde_json::Value::as_str);
        let behavior = specific
            .and_then(|s| s.get("decision"))
            .and_then(|d| d.get("behavior"))
            .and_then(serde_json::Value::as_str);

        observed.decision = permission
            .and_then(decision_from)
            .or_else(|| behavior.and_then(decision_from))
            .or_else(|| top_level.and_then(decision_from_top_level));
        observed.context = specific
            .and_then(|s| s.get("additionalContext"))
            .and_then(serde_json::Value::as_str)
            .map(str::to_owned);
    } else if crate::contract::event::lookup(event.as_str())
        .is_some_and(|documented| documented.stdout_is_context)
        && !captured.stdout.trim().is_empty()
    {
        observed.emitted = true;
        observed.context = Some(captured.stdout.trim().to_owned());
    }

    if event == HookEvent::PreToolUse && captured.exit == 2 {
        observed.emitted = true;
        observed.decision = Some(Decision::Deny);
    }

    observed
}

#[cfg(test)]
mod tests {
    use super::observe;
    use crate::case::Decision;
    use crate::harness::Captured;
    use crate::types::HookEvent;

    fn captured(exit: i32, stdout: &str, stderr: &str) -> Captured {
        Captured {
            exit,
            stdout: stdout.to_owned(),
            stderr: stderr.to_owned(),
            timed_out: false,
        }
    }

    #[test]
    fn an_envelope_decision_and_context_are_extracted() {
        let json = r#"{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"defer","additionalContext":"read the guideline"}}"#;
        let observed = observe(HookEvent::PreToolUse, &captured(0, json, ""));
        assert_eq!(observed.decision, Some(Decision::Defer));
        assert_eq!(observed.context.as_deref(), Some("read the guideline"));
        assert!(observed.emitted);
    }

    #[test]
    fn an_envelope_decision_allow_is_extracted() {
        let json =
            r#"{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}"#;
        let observed = observe(HookEvent::PreToolUse, &captured(0, json, ""));
        assert_eq!(observed.decision, Some(Decision::Allow));
    }

    #[test]
    fn an_envelope_decision_deny_is_extracted() {
        let json =
            r#"{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny"}}"#;
        let observed = observe(HookEvent::PreToolUse, &captured(0, json, ""));
        assert_eq!(observed.decision, Some(Decision::Deny));
    }

    #[test]
    fn an_envelope_decision_ask_is_extracted() {
        let json =
            r#"{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask"}}"#;
        let observed = observe(HookEvent::PreToolUse, &captured(0, json, ""));
        assert_eq!(observed.decision, Some(Decision::Ask));
    }

    #[test]
    fn an_unrecognised_permission_decision_string_leaves_decision_none() {
        let json =
            r#"{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"maybe"}}"#;
        let observed = observe(HookEvent::PreToolUse, &captured(0, json, ""));
        assert_eq!(observed.decision, None);
        assert!(observed.emitted);
    }

    #[test]
    fn a_permission_decision_of_block_is_not_recognised() {
        // The reference documents `permissionDecision` as allow/deny/ask/defer
        // (hooks.md:1016, 1744); "block" is only the top-level `decision`
        // field's spelling (hooks.md:1013), not this field's.
        let json =
            r#"{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"block"}}"#;
        let observed = observe(HookEvent::PreToolUse, &captured(0, json, ""));
        assert_eq!(observed.decision, None);
        assert!(observed.emitted);
    }

    #[test]
    fn a_behavior_field_of_block_is_not_recognised() {
        // hooks.md:1018 documents `decision.behavior` as allow/deny only.
        let json = r#"{"hookSpecificOutput":{"decision":{"behavior":"block"}}}"#;
        let observed = observe(HookEvent::PreToolUse, &captured(0, json, ""));
        assert_eq!(observed.decision, None);
        assert!(observed.emitted);
    }

    #[test]
    fn an_envelope_with_context_and_no_decision_leaves_decision_none() {
        let json = r#"{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"rust-guidelines apply"}}"#;
        let observed = observe(HookEvent::PreToolUse, &captured(0, json, ""));
        assert_eq!(observed.decision, None);
        assert_eq!(observed.context.as_deref(), Some("rust-guidelines apply"));
        assert!(observed.emitted);
    }

    #[test]
    fn pretooluse_exit_two_means_deny_even_without_an_envelope() {
        let observed = observe(HookEvent::PreToolUse, &captured(2, "", "blocked"));
        assert_eq!(observed.decision, Some(Decision::Deny));
    }

    #[test]
    fn exit_two_means_nothing_special_on_other_events() {
        let observed = observe(HookEvent::SessionEnd, &captured(2, "", ""));
        assert_eq!(observed.decision, None);
        assert!(!observed.emitted);
    }

    #[test]
    fn sessionstart_bare_stdout_is_context() {
        let observed = observe(HookEvent::SessionStart, &captured(0, "remember X\n", ""));
        assert_eq!(observed.context.as_deref(), Some("remember X"));
    }

    #[test]
    fn user_prompt_submit_bare_stdout_is_context_too() {
        let observed = observe(
            HookEvent::UserPromptSubmit,
            &captured(0, "remember X\n", ""),
        );
        assert_eq!(observed.context.as_deref(), Some("remember X"));
        assert!(observed.emitted);
    }

    #[test]
    fn bare_stdout_on_pretooluse_is_not_context() {
        let observed = observe(HookEvent::PreToolUse, &captured(0, "chatter\n", ""));
        assert_eq!(observed.context, None);
        assert!(!observed.emitted);
    }

    #[test]
    fn a_timeout_kill_is_propagated_to_the_observation() {
        let mut killed = captured(-2, "", "");
        killed.timed_out = true;
        assert!(observe(HookEvent::PreToolUse, &killed).timed_out);
    }

    #[test]
    fn silence_is_observed_as_no_emission() {
        let observed = observe(HookEvent::PreToolUse, &captured(0, "", ""));
        assert!(!observed.emitted);
    }

    #[test]
    fn a_top_level_block_decision_is_read() {
        let json = r#"{"decision":"block","reason":"not allowed"}"#;
        let observed = observe(HookEvent::PreToolUse, &captured(0, json, ""));
        assert_eq!(observed.decision, Some(Decision::Deny));
        assert!(observed.emitted);
    }

    #[test]
    fn a_hook_specific_behavior_field_is_read() {
        let json = r#"{"hookSpecificOutput":{"decision":{"behavior":"deny"}}}"#;
        let observed = observe(HookEvent::PreToolUse, &captured(0, json, ""));
        assert_eq!(observed.decision, Some(Decision::Deny));
        assert!(observed.emitted);
    }

    // The reference states no precedence between these three fields.
    // Most-specific-first — permission, then behavior, then top-level — is
    // claudevs' own choice, so it is pinned as a decision rather than an
    // accident of evaluation order. The full ordering has three adjacent
    // pairs; each test below pits exactly one pair against the other so that
    // reordering any single step in `permission.or(behavior).or(top_level)`
    // turns at least one of the three red.

    #[test]
    fn claudevs_prefers_permission_over_top_level_when_a_hook_writes_both() {
        let json = r#"{"decision":"block","hookSpecificOutput":{"permissionDecision":"allow"}}"#;
        let observed = observe(HookEvent::PreToolUse, &captured(0, json, ""));
        assert_eq!(observed.decision, Some(Decision::Allow));
    }

    #[test]
    fn claudevs_prefers_permission_over_behavior_when_a_hook_writes_both() {
        let json = r#"{"hookSpecificOutput":{"permissionDecision":"allow","decision":{"behavior":"deny"}}}"#;
        let observed = observe(HookEvent::PreToolUse, &captured(0, json, ""));
        assert_eq!(observed.decision, Some(Decision::Allow));
    }

    #[test]
    fn claudevs_prefers_behavior_over_top_level_when_a_hook_writes_both() {
        let json = r#"{"decision":"block","hookSpecificOutput":{"decision":{"behavior":"allow"}}}"#;
        let observed = observe(HookEvent::PreToolUse, &captured(0, json, ""));
        assert_eq!(observed.decision, Some(Decision::Allow));
    }

    #[test]
    fn json_stdout_with_no_envelope_claudevs_knows_is_still_injected_as_context() {
        let observed = observe(HookEvent::SessionStart, &captured(0, r#"{"foo":1}"#, ""));
        assert!(
            observed.emitted,
            "a SessionStart hook that printed did emit"
        );
        assert_eq!(observed.context.as_deref(), Some(r#"{"foo":1}"#));
    }

    #[test]
    fn bare_stdout_context_injection_agrees_with_the_catalogue_for_every_event() {
        // Pinned against `crate::contract::event::lookup` itself, not a
        // second, independently-maintained list of which events are
        // `stdout_is_context`. A hardcoded `matches!(event, SessionStart |
        // UserPromptSubmit)` in `observe` would stay green against today's
        // catalogue, but diverge the moment the catalogue's own
        // `stdout_is_context` flag changes for any event — which this test
        // would then catch and a hardcoded list would not.
        for event in [
            HookEvent::PreToolUse,
            HookEvent::PostToolUse,
            HookEvent::UserPromptSubmit,
            HookEvent::SessionStart,
            HookEvent::SessionEnd,
        ] {
            let catalogue_says_context = crate::contract::event::lookup(event.as_str())
                .is_some_and(|documented| documented.stdout_is_context);
            let observed = observe(event, &captured(0, "plain text, no envelope", ""));
            assert_eq!(
                observed.context.is_some(),
                catalogue_says_context,
                "{event:?}: observe's context injection disagrees with the catalogue's \
                 stdout_is_context"
            );
        }
    }
}
