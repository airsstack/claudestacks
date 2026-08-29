//! How a `matcher` value in `hooks.json` is evaluated.
//!
//! A matcher is not a regular expression. The Claude Code hooks reference
//! defines two modes, chosen by the characters in the value: a value made only
//! of letters, digits, `_`, `-`, spaces, `,` and `|` is an exact string — or a
//! list of exact strings separated by `|` or `,` — and any other character
//! makes the whole value a regular expression, matched **unanchored**. `"*"`,
//! the empty string and an absent matcher all match everything.
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

/// The characters that keep a matcher on the exact-string path.
const fn is_exact_mode_char(c: char) -> bool {
    c.is_ascii_alphanumeric() || matches!(c, '_' | '-' | ' ' | ',' | '|')
}

/// Parses a `matcher` value into the rule that evaluates it.
#[must_use]
pub fn parse(value: &str) -> MatcherRule {
    if value.is_empty() || value == "*" {
        return MatcherRule::All;
    }
    if value.chars().all(is_exact_mode_char) {
        let alternatives: Vec<String> = value
            .split(['|', ','])
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
            parse("Edit"),
            MatcherRule::Exact(vec![String::from("Edit")])
        );
    }

    #[test]
    fn a_pipe_separated_value_is_a_list_of_exact_strings() {
        assert_eq!(
            parse("Edit|Write"),
            MatcherRule::Exact(vec![String::from("Edit"), String::from("Write")]),
        );
    }

    #[test]
    fn a_comma_separated_value_is_a_list_and_surrounding_space_is_trimmed() {
        assert_eq!(
            parse("Edit, Write"),
            MatcherRule::Exact(vec![String::from("Edit"), String::from("Write")]),
        );
    }

    #[test]
    fn a_value_carrying_any_other_character_is_a_regex() {
        assert!(matches!(parse("Edit.*"), MatcherRule::Regex(_)));
        assert!(matches!(parse("^Notebook"), MatcherRule::Regex(_)));
    }

    #[test]
    fn a_star_an_empty_string_and_nothing_all_match_everything() {
        assert_eq!(parse("*"), MatcherRule::All);
        assert_eq!(parse(""), MatcherRule::All);
    }

    #[test]
    fn an_exact_list_matches_only_a_whole_element() {
        let rule = parse("Edit|Write");
        assert!(rule.matches("Edit"));
        assert!(rule.matches("Write"));
        assert!(!rule.matches("NotebookEdit"));
        assert!(!rule.matches("Edit|Write"));
    }

    #[test]
    fn a_regex_is_unanchored_so_edit_star_reaches_notebookedit() {
        assert!(parse("Edit.*").matches("NotebookEdit"));
    }

    #[test]
    fn all_matches_anything_including_the_empty_subject() {
        assert!(parse("*").matches("Edit"));
        assert!(parse("*").matches(""));
    }

    #[test]
    fn an_unsupported_pattern_matches_nothing_and_says_which_engine_refused_it() {
        let rule = parse("(?<=Edit)Write");
        let MatcherRule::Unsupported { value, reason } = &rule else {
            panic!("a lookbehind is not supported by Rust's regex crate: {rule:?}");
        };
        assert_eq!(value, "(?<=Edit)Write");
        assert!(!reason.is_empty());
        assert!(!rule.matches("EditWrite"));
    }
}
