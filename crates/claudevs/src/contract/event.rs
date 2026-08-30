//! The hook events Claude Code documents.
//!
//! Everything in this module describes Claude Code's hooks reference, not
//! `claudevs`. Whether `claudevs` can run a test case against a given event is
//! answered by [`crate::types::HookEvent`], a separate, narrower set: some
//! documented events here have no simulation support there. Every row's
//! `matcher` and `decision` fields are transcribed from
//! <https://code.claude.com/docs/en/hooks>.
//!
//! The reference also documents an "Exit code 2 behavior per event" table,
//! independent of the [`DecisionMechanism`] each event states in its
//! "Decision control" table — an event can honor exit code 2 and also carry a
//! JSON decision pattern. That exit-code axis is not modeled here.

/// Whether an event accepts a `matcher`, and what the matcher is compared to.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[non_exhaustive]
pub enum MatcherSupport {
    /// The event takes no matcher; one written here is silently ignored by the
    /// runtime, so a plugin that writes one is not being served.
    None,
    /// The event takes a matcher, and the reference names the payload field it
    /// is compared against.
    Field(&'static str),
    /// The event takes a matcher, and the reference names the payload field
    /// the subject is derived from, but the matcher is compared against a
    /// value Claude Code computes from that field, not the field's raw
    /// value: the canonical model name derived from `to_model` for
    /// `PreModelSwitch`/`PostModelSwitch`, or the changed file's basename
    /// derived from `file_path` for `FileChanged`. A caller cannot recover
    /// the compared value by reading the named key directly, so it must
    /// treat such an event as unfiltered rather than comparing against that
    /// key's raw value.
    Unresolved,
}

/// How an event's hook output can decide the event's outcome.
///
/// Every documented event has a stated mechanism in the reference's
/// "Decision control" table, so there is deliberately no variant meaning "the
/// reference is silent" — every row below carries one of these.
#[non_exhaustive]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DecisionMechanism {
    /// Top-level `decision: "block"` plus `reason`.
    TopLevelDecision,
    /// Exit code 2, or `{"continue": false}`.
    ExitCodeOrContinueFalse,
    /// Exit code 2, or top-level `decision: "block"`.
    ExitCodeOrTopLevelDecision,
    /// `hookSpecificOutput.permissionDecision`.
    PermissionDecision,
    /// `hookSpecificOutput.permissionDecision`, or top-level `decision`.
    PermissionDecisionOrTopLevelDecision,
    /// `hookSpecificOutput.decision.behavior`.
    DecisionBehavior,
    /// `hookSpecificOutput.retry`.
    Retry,
    /// A path on stdout, or `hookSpecificOutput.worktreePath`.
    PathReturn,
    /// `hookSpecificOutput.action` with `content`.
    ElicitationAction,
    /// `hookSpecificOutput.displayContent`.
    DisplayContent,
    /// `hookSpecificOutput.additionalContext` only; no blocking.
    ContextOnly,
    /// The reference states this event has no decision control.
    NoDecisionControl,
}

/// One row of Claude Code's documented hook-event catalogue.
#[non_exhaustive]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DocumentedEvent {
    /// The event name as Claude Code names it, e.g. `"PreToolUse"`.
    pub name: &'static str,
    /// Whether the event accepts a `matcher`, and what it filters on.
    pub matcher: MatcherSupport,
    /// How the event's hook output can decide its outcome.
    pub decision: DecisionMechanism,
    /// Whether bare stdout from this event's hooks is injected as context
    /// Claude can see and act on, rather than only written to the debug log.
    pub stdout_is_context: bool,
}

/// The 33 hook events Claude Code documents, in the reference's summary-table
/// order ("When it fires"). The per-event `### <EventName>` sections in the
/// same reference use a different order; this catalogue does not follow it.
static CATALOGUE: &[DocumentedEvent] = &[
    DocumentedEvent {
        name: "SessionStart",
        matcher: MatcherSupport::Field("source"),
        decision: DecisionMechanism::ContextOnly,
        stdout_is_context: true,
    },
    DocumentedEvent {
        name: "Setup",
        matcher: MatcherSupport::Field("trigger"),
        decision: DecisionMechanism::NoDecisionControl,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "UserPromptSubmit",
        matcher: MatcherSupport::None,
        decision: DecisionMechanism::TopLevelDecision,
        stdout_is_context: true,
    },
    DocumentedEvent {
        name: "UserPromptExpansion",
        matcher: MatcherSupport::Field("command_name"),
        decision: DecisionMechanism::TopLevelDecision,
        stdout_is_context: true,
    },
    DocumentedEvent {
        name: "PreToolUse",
        matcher: MatcherSupport::Field("tool_name"),
        decision: DecisionMechanism::PermissionDecision,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "PermissionRequest",
        matcher: MatcherSupport::Field("tool_name"),
        decision: DecisionMechanism::DecisionBehavior,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "PermissionDenied",
        matcher: MatcherSupport::Field("tool_name"),
        decision: DecisionMechanism::Retry,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "PostToolUse",
        matcher: MatcherSupport::Field("tool_name"),
        decision: DecisionMechanism::TopLevelDecision,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "PostToolUseFailure",
        matcher: MatcherSupport::Field("tool_name"),
        decision: DecisionMechanism::TopLevelDecision,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "PostToolBatch",
        matcher: MatcherSupport::None,
        decision: DecisionMechanism::TopLevelDecision,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "Notification",
        matcher: MatcherSupport::Field("notification_type"),
        decision: DecisionMechanism::NoDecisionControl,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "MessageDisplay",
        matcher: MatcherSupport::None,
        decision: DecisionMechanism::DisplayContent,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "SubagentStart",
        matcher: MatcherSupport::Field("agent_type"),
        decision: DecisionMechanism::ContextOnly,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "SubagentStop",
        matcher: MatcherSupport::Field("agent_type"),
        decision: DecisionMechanism::TopLevelDecision,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "TaskCreated",
        matcher: MatcherSupport::None,
        decision: DecisionMechanism::ExitCodeOrTopLevelDecision,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "TaskCompleted",
        matcher: MatcherSupport::None,
        decision: DecisionMechanism::ExitCodeOrContinueFalse,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "Stop",
        matcher: MatcherSupport::None,
        decision: DecisionMechanism::TopLevelDecision,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "StopFailure",
        matcher: MatcherSupport::Field("error"),
        decision: DecisionMechanism::NoDecisionControl,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "TeammateIdle",
        matcher: MatcherSupport::None,
        decision: DecisionMechanism::ExitCodeOrContinueFalse,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "InstructionsLoaded",
        matcher: MatcherSupport::Field("load_reason"),
        decision: DecisionMechanism::NoDecisionControl,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "ConfigChange",
        matcher: MatcherSupport::Field("source"),
        decision: DecisionMechanism::TopLevelDecision,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "CwdChanged",
        matcher: MatcherSupport::None,
        decision: DecisionMechanism::NoDecisionControl,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "DirectoryAdded",
        matcher: MatcherSupport::Field("source"),
        decision: DecisionMechanism::NoDecisionControl,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "FileChanged",
        // The matcher filters against the changed file's basename, a value
        // derived from `file_path` rather than the raw field itself, so the
        // reference does not resolve it to a named payload field. Parallel to
        // PreModelSwitch/PostModelSwitch below.
        matcher: MatcherSupport::Unresolved,
        decision: DecisionMechanism::NoDecisionControl,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "WorktreeCreate",
        matcher: MatcherSupport::None,
        decision: DecisionMechanism::PathReturn,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "WorktreeRemove",
        matcher: MatcherSupport::None,
        decision: DecisionMechanism::NoDecisionControl,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "PreCompact",
        matcher: MatcherSupport::Field("trigger"),
        decision: DecisionMechanism::TopLevelDecision,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "PostCompact",
        matcher: MatcherSupport::Field("trigger"),
        decision: DecisionMechanism::NoDecisionControl,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "PreModelSwitch",
        // The matcher is compared against the canonical model name Claude Code
        // derives from `to_model`, not the raw field value, so the reference
        // does not resolve it to a named payload field.
        matcher: MatcherSupport::Unresolved,
        decision: DecisionMechanism::PermissionDecisionOrTopLevelDecision,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "PostModelSwitch",
        // Same derivation rule as PreModelSwitch: compared against a derived
        // canonical model name, not a raw field value.
        matcher: MatcherSupport::Unresolved,
        decision: DecisionMechanism::ContextOnly,
        stdout_is_context: true,
    },
    DocumentedEvent {
        name: "Elicitation",
        matcher: MatcherSupport::Field("mcp_server_name"),
        decision: DecisionMechanism::ElicitationAction,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "ElicitationResult",
        matcher: MatcherSupport::Field("mcp_server_name"),
        decision: DecisionMechanism::ElicitationAction,
        stdout_is_context: false,
    },
    DocumentedEvent {
        name: "SessionEnd",
        matcher: MatcherSupport::Field("reason"),
        decision: DecisionMechanism::NoDecisionControl,
        stdout_is_context: false,
    },
];

/// Looks up a documented event by its exact Claude Code name.
///
/// Returns [`None`] for a name the reference does not document — not every
/// string a plugin author might write names a real event.
#[must_use]
pub fn lookup(name: &str) -> Option<&'static DocumentedEvent> {
    CATALOGUE.iter().find(|row| row.name == name)
}

/// The full documented-event catalogue, for a caller that needs to walk
/// every row rather than look one up by name.
///
/// For example, checking whether a `matcher` was written on an event that
/// takes none, or warning on an event name the reference does not document
/// at all.
#[must_use]
pub const fn catalogue() -> &'static [DocumentedEvent] {
    CATALOGUE
}

#[cfg(test)]
mod tests {
    #![expect(
        clippy::panic,
        reason = "a missing fixture row means the test itself is broken, not the code under test"
    )]

    use super::{DecisionMechanism, DocumentedEvent, MatcherSupport, catalogue, lookup};

    /// Looks up a row that a test expects the catalogue to contain, panicking
    /// with the missing name if it doesn't — a broken fixture, not a normal
    /// assertion failure.
    fn must_lookup(name: &str) -> &'static DocumentedEvent {
        lookup(name).unwrap_or_else(|| panic!("{name} should be documented but was not found"))
    }

    #[test]
    fn the_catalogue_holds_every_documented_event() {
        // hooks.md:37-69 — the summary table's "Event" column, in order.
        assert_eq!(
            super::CATALOGUE
                .iter()
                .map(|row| row.name)
                .collect::<Vec<_>>(),
            [
                "SessionStart",
                "Setup",
                "UserPromptSubmit",
                "UserPromptExpansion",
                "PreToolUse",
                "PermissionRequest",
                "PermissionDenied",
                "PostToolUse",
                "PostToolUseFailure",
                "PostToolBatch",
                "Notification",
                "MessageDisplay",
                "SubagentStart",
                "SubagentStop",
                "TaskCreated",
                "TaskCompleted",
                "Stop",
                "StopFailure",
                "TeammateIdle",
                "InstructionsLoaded",
                "ConfigChange",
                "CwdChanged",
                "DirectoryAdded",
                "FileChanged",
                "WorktreeCreate",
                "WorktreeRemove",
                "PreCompact",
                "PostCompact",
                "PreModelSwitch",
                "PostModelSwitch",
                "Elicitation",
                "ElicitationResult",
                "SessionEnd",
            ]
        );
    }

    #[test]
    fn every_catalogue_name_is_unique() {
        use std::collections::HashSet;

        let names: Vec<&str> = super::CATALOGUE.iter().map(|row| row.name).collect();
        let unique: HashSet<&str> = names.iter().copied().collect();
        assert_eq!(unique.len(), names.len(), "duplicate name in {names:?}");
    }

    #[test]
    fn the_catalogue_function_returns_the_same_rows_as_lookup_sees() {
        assert_eq!(catalogue().len(), super::CATALOGUE.len());
        assert!(catalogue().iter().any(|row| row.name == "Stop"));
    }

    #[test]
    fn exactly_ten_documented_events_take_no_matcher() {
        let matcherless: Vec<&str> = super::CATALOGUE
            .iter()
            .filter(|row| matches!(row.matcher, MatcherSupport::None))
            .map(|row| row.name)
            .collect();
        assert_eq!(matcherless.len(), 10, "{matcherless:?}");
        for name in [
            "UserPromptSubmit",
            "PostToolBatch",
            "Stop",
            "TeammateIdle",
            "TaskCreated",
            "TaskCompleted",
            "WorktreeCreate",
            "WorktreeRemove",
            "MessageDisplay",
            "CwdChanged",
        ] {
            assert!(matcherless.contains(&name), "{name} should take no matcher");
        }
    }

    #[test]
    fn an_undocumented_event_name_is_not_in_the_catalogue() {
        assert!(lookup("Frobnicate").is_none());
    }

    #[test]
    fn stop_is_documented_even_though_claudevs_cannot_simulate_it() {
        assert!(lookup("Stop").is_some());
    }

    #[test]
    fn exactly_four_events_inject_bare_stdout_as_context() {
        let injecting: Vec<&str> = super::CATALOGUE
            .iter()
            .filter(|row| row.stdout_is_context)
            .map(|row| row.name)
            .collect();
        assert_eq!(
            injecting,
            [
                "SessionStart",
                "UserPromptSubmit",
                "UserPromptExpansion",
                "PostModelSwitch"
            ],
        );
    }

    /// Collects the names of every catalogue row carrying `mechanism`, sorted
    /// so the comparison is order-independent.
    fn names_with_decision(mechanism: DecisionMechanism) -> Vec<&'static str> {
        let mut names: Vec<&'static str> = super::CATALOGUE
            .iter()
            .filter(|row| row.decision == mechanism)
            .map(|row| row.name)
            .collect();
        names.sort_unstable();
        names
    }

    fn sorted(mut names: Vec<&'static str>) -> Vec<&'static str> {
        names.sort_unstable();
        names
    }

    #[test]
    fn the_top_level_decision_group_matches_the_reference_exactly() {
        // hooks.md:1013 — "UserPromptSubmit, UserPromptExpansion,
        // PostToolUse, PostToolUseFailure, PostToolBatch, Stop, SubagentStop,
        // ConfigChange, PreCompact".
        assert_eq!(
            names_with_decision(DecisionMechanism::TopLevelDecision),
            sorted(vec![
                "UserPromptSubmit",
                "UserPromptExpansion",
                "PostToolUse",
                "PostToolUseFailure",
                "PostToolBatch",
                "Stop",
                "SubagentStop",
                "ConfigChange",
                "PreCompact",
            ])
        );
    }

    #[test]
    fn the_exit_code_or_continue_false_group_matches_the_reference_exactly() {
        // hooks.md:1014 — "TeammateIdle, TaskCompleted".
        assert_eq!(
            names_with_decision(DecisionMechanism::ExitCodeOrContinueFalse),
            sorted(vec!["TeammateIdle", "TaskCompleted"])
        );
    }

    #[test]
    fn the_context_only_group_matches_the_reference_exactly() {
        // hooks.md:1024 — "SessionStart, SubagentStart, PostModelSwitch".
        assert_eq!(
            names_with_decision(DecisionMechanism::ContextOnly),
            sorted(vec!["SessionStart", "SubagentStart", "PostModelSwitch"])
        );
    }

    #[test]
    fn the_no_decision_control_group_matches_the_reference_exactly() {
        // hooks.md:1025 — "Setup, WorktreeRemove, Notification, SessionEnd,
        // PostCompact, InstructionsLoaded, StopFailure, CwdChanged,
        // DirectoryAdded, FileChanged".
        assert_eq!(
            names_with_decision(DecisionMechanism::NoDecisionControl),
            sorted(vec![
                "Setup",
                "WorktreeRemove",
                "Notification",
                "SessionEnd",
                "PostCompact",
                "InstructionsLoaded",
                "StopFailure",
                "CwdChanged",
                "DirectoryAdded",
                "FileChanged",
            ])
        );
    }

    #[test]
    fn each_single_event_decision_mechanism_pins_its_one_event() {
        // hooks.md:1011-1025 — the "Decision control" table rows that name
        // exactly one event each.
        assert_eq!(
            must_lookup("PreToolUse").decision,
            DecisionMechanism::PermissionDecision,
            "hooks.md:1016"
        );
        assert_eq!(
            must_lookup("PermissionRequest").decision,
            DecisionMechanism::DecisionBehavior,
            "hooks.md:1018"
        );
        assert_eq!(
            must_lookup("PermissionDenied").decision,
            DecisionMechanism::Retry,
            "hooks.md:1019"
        );
        assert_eq!(
            must_lookup("WorktreeCreate").decision,
            DecisionMechanism::PathReturn,
            "hooks.md:1020"
        );
        assert_eq!(
            must_lookup("MessageDisplay").decision,
            DecisionMechanism::DisplayContent,
            "hooks.md:1023"
        );
        assert_eq!(
            must_lookup("TaskCreated").decision,
            DecisionMechanism::ExitCodeOrTopLevelDecision,
            "hooks.md:1015"
        );
        assert_eq!(
            must_lookup("PreModelSwitch").decision,
            DecisionMechanism::PermissionDecisionOrTopLevelDecision,
            "hooks.md:1017"
        );
    }

    #[test]
    fn the_tool_events_resolve_their_matcher_to_the_tool_name_field() {
        use super::MatcherSupport::Field;
        for name in [
            "PreToolUse",
            "PostToolUse",
            "PostToolUseFailure",
            "PermissionRequest",
            "PermissionDenied",
        ] {
            let row = must_lookup(name);
            assert_eq!(row.matcher, Field("tool_name"), "{name}");
        }
    }
}
