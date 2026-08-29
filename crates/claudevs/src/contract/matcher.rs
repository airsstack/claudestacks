//! How a `matcher` value in `hooks.json` is evaluated.
//!
//! A matcher is not a regular expression. The Claude Code hooks reference
//! defines two modes, chosen by the characters in the value: a value made only
//! of letters, digits, `_`, `-`, spaces, `,` and `|` is an exact string — or a
//! list of exact strings separated by `|` or `,` — and any other character
//! makes the whole value a regular expression, matched **unanchored**. `"*"`,
//! the empty string and an absent matcher all match everything, on every
//! event.
//!
//! `FileChanged` and `StopFailure` are the two exceptions: their exact-string
//! set is narrower — letters, digits, `_`, and `|` only — so a hyphen, space,
//! or comma in one of their matchers keeps it on the regex path, and only
//! `|` separates alternatives (not `,`). Every other event uses the wider
//! set above.
//!
//! The regex mode is JavaScript's, tested with `RegExp.prototype.test`. Rust's
//! `regex` crate is a narrower dialect: it has no lookaround and no
//! backreferences, so a pattern that is valid in Claude Code can fail to
//! compile here. That divergence is reported as a warning naming the engine,
//! never as an error, because the plugin is not the thing that is wrong.
//!
//! One module owns this so that dispatch and the static checker can never
//! disagree about what a matcher means.

/// A parsed matcher value.
#[derive(Debug, Clone)]
pub enum MatcherRule {
    /// Matches every payload.
    All,
    /// Matches when the subject equals any of these strings.
    Exact(Vec<String>),
    /// Matches when the pattern is found anywhere in the subject.
    Regex(Box<regex::Regex>),
    /// The value is regex-mode but Rust's `regex` crate rejects it. Carries
    /// the value and the compile error so a caller can report which engine
    /// refused it.
    Unsupported {
        /// The matcher value as written.
        value: String,
        /// What Rust's `regex` crate said.
        reason: String,
    },
}

impl PartialEq for MatcherRule {
    fn eq(&self, other: &Self) -> bool {
        match (self, other) {
            (Self::All, Self::All) => true,
            (Self::Exact(a), Self::Exact(b)) => a == b,
            (Self::Regex(a), Self::Regex(b)) => a.as_str() == b.as_str(),
            (Self::Unsupported { value: a, .. }, Self::Unsupported { value: b, .. }) => a == b,
            _ => false,
        }
    }
}

impl MatcherRule {
    /// Whether this rule matches `subject`.
    ///
    /// The exact path compares whole strings; the regex path searches, since
    /// the documented semantics are `RegExp.prototype.test` on an unanchored
    /// pattern — the reference's own example has `Edit.*` reaching
    /// `NotebookEdit`. An [`MatcherRule::Unsupported`] value matches nothing:
    /// claudevs cannot evaluate it, and pretending it matched would route a
    /// case to a handler the runtime might not have chosen.
    #[must_use]
    pub fn matches(&self, subject: &str) -> bool {
        match self {
            Self::All => true,
            Self::Exact(alternatives) => alternatives.iter().any(|a| a == subject),
            Self::Regex(pattern) => pattern.is_match(subject),
            Self::Unsupported { .. } => false,
        }
    }
}

/// The characters that keep a matcher on the exact-string path for every
/// event except [`NARROW_EXACT_SET_EVENTS`].
const fn is_exact_mode_char(c: char) -> bool {
    c.is_ascii_alphanumeric() || matches!(c, '_' | '-' | ' ' | ',' | '|')
}

/// The narrower exact-mode set `FileChanged` and `StopFailure` use: letters,
/// digits, `_`, and `|` only. A hyphen, space, or comma in a matcher for
/// those two events keeps it on the regular-expression path.
const fn is_narrow_exact_char(c: char) -> bool {
    c.is_ascii_alphanumeric() || c == '_' || c == '|'
}

/// Hook events whose matcher uses [`is_narrow_exact_char`] instead of
/// [`is_exact_mode_char`], and split alternatives on `|` only (not `,`).
const NARROW_EXACT_SET_EVENTS: [&str; 2] = ["FileChanged", "StopFailure"];

/// Parses a `matcher` value into the rule that evaluates it.
///
/// `event` is the hook event name the matcher belongs to (for example
/// `"PreToolUse"`). It is a plain `&str` rather than a dedicated event type:
/// this module owns only the matcher-parsing contract, and the narrow-set
/// rule needs nothing about an event beyond its name, so borrowing the
/// caller's string keeps this module free of a dependency on the event
/// catalog being written elsewhere in `contract/`.
#[must_use]
pub fn parse(event: &str, value: &str) -> MatcherRule {
    if value.is_empty() || value == "*" {
        return MatcherRule::All;
    }
    let narrow = NARROW_EXACT_SET_EVENTS.contains(&event);
    let is_exact_char: fn(char) -> bool = if narrow {
        is_narrow_exact_char
    } else {
        is_exact_mode_char
    };
    if value.chars().all(is_exact_char) {
        let separators: &[char] = if narrow { &['|'] } else { &['|', ','] };
        let alternatives: Vec<String> = value
            .split(separators)
            .map(|part| part.trim().to_owned())
            .filter(|part| !part.is_empty())
            .collect();
        return if alternatives.is_empty() {
            MatcherRule::All
        } else {
            MatcherRule::Exact(alternatives)
        };
    }
    match regex::Regex::new(value) {
        Ok(compiled) => MatcherRule::Regex(Box::new(compiled)),
        Err(error) => MatcherRule::Unsupported {
            value: value.to_owned(),
            reason: error.to_string(),
        },
    }
}

#[cfg(test)]
mod tests {
    #![expect(clippy::panic, reason = "tests panic to reject an unexpected shape")]

    use super::{MatcherRule, parse};

    #[test]
    fn a_bare_word_is_an_exact_string_not_a_pattern() {
        assert_eq!(
            parse("PreToolUse", "Edit"),
            MatcherRule::Exact(vec![String::from("Edit")])
        );
    }

    #[test]
    fn a_pipe_separated_value_is_a_list_of_exact_strings() {
        assert_eq!(
            parse("PreToolUse", "Edit|Write"),
            MatcherRule::Exact(vec![String::from("Edit"), String::from("Write")]),
        );
    }

    #[test]
    fn a_comma_separated_value_is_a_list_and_surrounding_space_is_trimmed() {
        assert_eq!(
            parse("PreToolUse", "Edit, Write"),
            MatcherRule::Exact(vec![String::from("Edit"), String::from("Write")]),
        );
    }

    #[test]
    fn a_value_carrying_any_other_character_is_a_regex() {
        assert!(matches!(
            parse("PreToolUse", "Edit.*"),
            MatcherRule::Regex(_)
        ));
        assert!(matches!(
            parse("PreToolUse", "^Notebook"),
            MatcherRule::Regex(_)
        ));
    }

    #[test]
    fn a_star_an_empty_string_and_nothing_all_match_everything() {
        assert_eq!(parse("PreToolUse", "*"), MatcherRule::All);
        assert_eq!(parse("PreToolUse", ""), MatcherRule::All);
    }

    #[test]
    fn an_exact_list_matches_only_a_whole_element() {
        let rule = parse("PreToolUse", "Edit|Write");
        assert!(rule.matches("Edit"));
        assert!(rule.matches("Write"));
        assert!(!rule.matches("NotebookEdit"));
        assert!(!rule.matches("Edit|Write"));
    }

    #[test]
    fn a_regex_is_unanchored_so_edit_star_reaches_notebookedit() {
        assert!(parse("PreToolUse", "Edit.*").matches("NotebookEdit"));
    }

    #[test]
    fn all_matches_anything_including_the_empty_subject() {
        assert!(parse("PreToolUse", "*").matches("Edit"));
        assert!(parse("PreToolUse", "*").matches(""));
    }

    #[test]
    fn an_unsupported_pattern_matches_nothing_and_says_which_engine_refused_it() {
        let rule = parse("PreToolUse", "(?<=Edit)Write");
        let MatcherRule::Unsupported { value, reason } = &rule else {
            panic!("a lookbehind is not supported by Rust's regex crate: {rule:?}");
        };
        assert_eq!(value, "(?<=Edit)Write");
        assert!(!reason.is_empty());
        assert!(!rule.matches("EditWrite"));
    }

    #[test]
    fn a_hyphen_keeps_a_stopfailure_matcher_on_the_regex_path() {
        assert!(matches!(
            parse("StopFailure", "code-reviewer"),
            MatcherRule::Regex(_)
        ));
    }

    #[test]
    fn a_comma_does_not_split_alternatives_for_filechanged() {
        assert!(matches!(parse("FileChanged", "a,b"), MatcherRule::Regex(_)));
    }

    #[test]
    fn underscore_and_pipe_still_produce_exact_on_the_narrow_path() {
        assert_eq!(
            parse("StopFailure", "rate_limit|overloaded"),
            MatcherRule::Exact(vec![String::from("rate_limit"), String::from("overloaded")]),
        );
        assert_eq!(
            parse("FileChanged", "a_b|c"),
            MatcherRule::Exact(vec![String::from("a_b"), String::from("c")]),
        );
    }

    #[test]
    fn the_same_value_differs_between_the_narrow_and_wide_paths() {
        assert_eq!(
            parse("PreToolUse", "code-reviewer"),
            MatcherRule::Exact(vec![String::from("code-reviewer")]),
        );
        assert!(matches!(
            parse("StopFailure", "code-reviewer"),
            MatcherRule::Regex(_)
        ));

        assert_eq!(
            parse("PreToolUse", "a,b"),
            MatcherRule::Exact(vec![String::from("a"), String::from("b")]),
        );
        assert!(matches!(parse("FileChanged", "a,b"), MatcherRule::Regex(_)));
    }

    #[test]
    fn a_star_and_empty_string_match_everything_on_the_narrow_path_too() {
        assert_eq!(parse("StopFailure", "*"), MatcherRule::All);
        assert_eq!(parse("FileChanged", ""), MatcherRule::All);
    }
}
