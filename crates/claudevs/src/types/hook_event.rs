//! The hook events claudevs can run a case against.
//!
//! A variant here means the harness can synthesize a payload for the event and
//! interpret what a hook returns from it. That is a narrower set than the
//! events Claude Code documents, which live in [`crate::contract::event`]: a
//! documented event claudevs cannot simulate is still one a plugin may
//! legitimately wire, so a checker reads the catalogue while a case reads this
//! type. Neither derives from the other, and merging them would make one
//! answer serve two questions.
//!
//! Responsibilities: [`HookEvent`] and [`InvalidHookEvent`].

/// A hook event name from hooks.json.
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum HookEvent {
    /// Before a tool call runs. Exit 2 blocks the call.
    PreToolUse,
    /// After a tool call ran.
    PostToolUse,
    /// When the user submits a prompt.
    UserPromptSubmit,
    /// At session start/resume/clear/compact.
    SessionStart,
    /// At session end.
    SessionEnd,
}

/// Why a string is not a known hook event.
#[derive(Debug, thiserror::Error, PartialEq, Eq)]
#[error(
    "unknown hook event `{0}` (known: PreToolUse, PostToolUse, UserPromptSubmit, SessionStart, SessionEnd)"
)]
pub struct InvalidHookEvent(String);

impl core::str::FromStr for HookEvent {
    type Err = InvalidHookEvent;

    fn from_str(raw: &str) -> Result<Self, Self::Err> {
        match raw {
            "PreToolUse" => Ok(Self::PreToolUse),
            "PostToolUse" => Ok(Self::PostToolUse),
            "UserPromptSubmit" => Ok(Self::UserPromptSubmit),
            "SessionStart" => Ok(Self::SessionStart),
            "SessionEnd" => Ok(Self::SessionEnd),
            other => Err(InvalidHookEvent(other.to_owned())),
        }
    }
}

impl HookEvent {
    /// The event name as it appears in hooks.json.
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::PreToolUse => "PreToolUse",
            Self::PostToolUse => "PostToolUse",
            Self::UserPromptSubmit => "UserPromptSubmit",
            Self::SessionStart => "SessionStart",
            Self::SessionEnd => "SessionEnd",
        }
    }
}

#[cfg(test)]
mod tests {
    #![expect(clippy::unwrap_used, reason = "tests unwrap known-valid fixtures")]

    use super::HookEvent;

    #[test]
    fn every_variant_round_trips_through_its_name() {
        for event in [
            HookEvent::PreToolUse,
            HookEvent::PostToolUse,
            HookEvent::UserPromptSubmit,
            HookEvent::SessionStart,
            HookEvent::SessionEnd,
        ] {
            assert_eq!(event.as_str().parse::<HookEvent>(), Ok(event));
        }
    }

    #[test]
    fn an_unknown_event_is_an_error_naming_the_known_set() {
        let error = "Frobnicate".parse::<HookEvent>().unwrap_err();
        assert!(error.to_string().contains("PreToolUse"));
    }
}
