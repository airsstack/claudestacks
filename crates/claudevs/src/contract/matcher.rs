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
}
