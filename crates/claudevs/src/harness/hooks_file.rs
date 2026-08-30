//! Reading a plugin's hooks/hooks.json and resolving a case's hook reference.
//!
//! The file shape is `hooks.json` as documented for Claude Code plugin hooks:
//! `{"hooks": {"<Event>": [{"matcher": "...", "hooks": [{"type": "command", "command": "..."}]}]}}`.
//! See [`crate::contract::handler`] for the two execution models a `type:
//! "command"` entry may declare.
//!
//! Resolution: groups are filtered by their `matcher` against the case's
//! payload first, the way the runtime routes; no `hook:` → the surviving
//! group(s)' single handler (error if several); `hook: <text>` → the unique
//! surviving handler whose display form contains `<text>` as a substring.

use std::path::Path;

use crate::contract::handler::{HookCommand, from_entry};
use crate::error::{Error, Result};
use crate::types::HookEvent;

/// The handler groups hooks.json declares for one event, each paired with its
/// `matcher` (absent when the group declares none), in declaration order.
///
/// Entries claudevs does not model are skipped, not rejected: a plugin that
/// mixes a prompt handler into a hook group still has its command handlers
/// run. See [`crate::contract::handler::from_entry`].
///
/// # Errors
///
/// [`Error::Io`] / [`Error::HookResolution`] when the file is missing or malformed.
fn groups_for(
    plugin_dir: &Path,
    event: HookEvent,
) -> Result<Vec<(Option<String>, Vec<HookCommand>)>> {
    let path = plugin_dir.join("hooks/hooks.json");
    let text = std::fs::read_to_string(&path).map_err(|source| Error::Io {
        operation: "read hooks.json",
        path: path.display().to_string(),
        source,
    })?;
    let value: serde_json::Value =
        serde_json::from_str(&text).map_err(|e| Error::HookResolution {
            reason: format!("{}: {e}", path.display()),
        })?;

    let mut groups = Vec::new();
    if let Some(raw_groups) = value
        .get("hooks")
        .and_then(|h| h.get(event.as_str()))
        .and_then(serde_json::Value::as_array)
    {
        for group in raw_groups {
            let matcher = group
                .get("matcher")
                .and_then(serde_json::Value::as_str)
                .map(str::to_owned);
            let mut handlers = Vec::new();
            if let Some(entries) = group.get("hooks").and_then(serde_json::Value::as_array) {
                for entry in entries {
                    if let Some(handler) = from_entry(entry) {
                        handlers.push(handler);
                    }
                }
            }
            groups.push((matcher, handlers));
        }
    }
    Ok(groups)
}

/// The handlers hooks.json declares for one event, in declaration order,
/// ignoring `matcher` entirely.
///
/// Defined in terms of the same group parsing [`resolve`] uses, so this and
/// `resolve`'s per-group matcher filter can never disagree about what a
/// group's handlers are.
///
/// # Errors
///
/// [`Error::Io`] / [`Error::HookResolution`] when the file is missing or malformed.
pub fn commands_for(plugin_dir: &Path, event: HookEvent) -> Result<Vec<HookCommand>> {
    Ok(groups_for(plugin_dir, event)?
        .into_iter()
        .flat_map(|(_, handlers)| handlers)
        .collect())
}

/// Whether `group_matcher` selects `payload` under `event`'s rules.
fn group_selects(
    event: HookEvent,
    group_matcher: Option<&str>,
    payload: &serde_json::Value,
) -> bool {
    use crate::contract::event::MatcherSupport;

    let Some(matcher) = group_matcher else {
        return true;
    };
    let Some(documented) = crate::contract::event::lookup(event.as_str()) else {
        return true;
    };
    let MatcherSupport::Field(key) = documented.matcher else {
        // Either the event takes no matcher — the runtime ignores one
        // written here — or the reference does not say what the matcher is
        // compared against. Both mean: do not filter.
        return true;
    };
    let Some(subject) = payload.get(key).and_then(serde_json::Value::as_str) else {
        return true;
    };
    crate::contract::matcher::parse(event.as_str(), matcher).matches(subject)
}

/// Resolves the one handler a hook case targets, for `payload`.
///
/// Groups are filtered by their `matcher` against the payload first, the way
/// the runtime routes, and the optional `reference` substring is a secondary
/// filter over the handlers that survive — for a plugin wiring several
/// commands behind one matcher.
///
/// The filter mirrors the runtime, including where the runtime ignores the
/// matcher. For an event that takes no matcher, one written in hooks.json is
/// silently ignored, so every group matches; and where the catalogue does not
/// name what a matcher is compared against, the matcher is ignored on the same
/// principle — claudevs never guesses a routing rule the documentation does
/// not state.
///
/// # Errors
///
/// [`Error::HookResolution`] when zero or several handlers match, or the
/// underlying hooks.json is malformed; [`Error::Io`] when it is missing.
pub fn resolve(
    plugin_dir: &Path,
    event: HookEvent,
    reference: Option<&str>,
    payload: &serde_json::Value,
) -> Result<HookCommand> {
    let groups = groups_for(plugin_dir, event)?;
    let candidates: Vec<&HookCommand> = groups
        .iter()
        .filter(|(matcher, _)| group_selects(event, matcher.as_deref(), payload))
        .flat_map(|(_, handlers)| handlers)
        .filter(|handler| reference.is_none_or(|needle| handler.display().contains(needle)))
        .collect();

    match candidates.as_slice() {
        [one] => Ok((*one).clone()),
        [] => Err(Error::HookResolution {
            reason: format!(
                "no {} handler matches {:?} for this payload; the plugin wires: {}",
                event.as_str(),
                reference.unwrap_or("<any>"),
                describe_groups(&groups),
            ),
        }),
        several => Err(Error::HookResolution {
            reason: format!(
                "{} {} handlers match {:?}; add a `hook:` substring that matches exactly one",
                several.len(),
                event.as_str(),
                reference.unwrap_or("<any>")
            ),
        }),
    }
}

/// Every group an event declares, as `matcher -> handler` pairs.
///
/// Shown when nothing matches, so an author sees what the plugin wires rather
/// than only that their case reached none of it. Empty both when the event
/// declares no groups at all and when every group it declares holds no entry
/// [`crate::contract::handler::from_entry`] models (a `type: "prompt"` entry,
/// a `type`-less entry, an empty `hooks` array) — either way there is nothing
/// to list, so both collapse to the same message rather than an empty tail.
fn describe_groups(groups: &[(Option<String>, Vec<HookCommand>)]) -> String {
    let rendered: Vec<String> = groups
        .iter()
        .flat_map(|(matcher, handlers)| {
            let matcher = matcher.as_deref().unwrap_or("*");
            handlers
                .iter()
                .map(move |handler| format!("matcher={matcher} -> {}", handler.display()))
        })
        .collect();
    if rendered.is_empty() {
        String::from("nothing declared")
    } else {
        rendered.join(", ")
    }
}

#[cfg(test)]
mod tests {
    #![expect(clippy::unwrap_used, reason = "tests unwrap known-valid fixtures")]
    #![expect(clippy::panic, reason = "tests panic to reject an unexpected shape")]

    use super::resolve;
    use crate::contract::handler::HookCommand;
    use crate::types::HookEvent;

    fn plugin(hooks_json: &str) -> tempfile::TempDir {
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("hooks")).unwrap();
        std::fs::write(dir.path().join("hooks/hooks.json"), hooks_json).unwrap();
        dir
    }

    const TWO_HOOKS: &str = r#"{"hooks":{"PreToolUse":[
        {"matcher":"Edit|Write","hooks":[{"type":"command","command":"sh gate.sh"}]},
        {"matcher":"Read","hooks":[{"type":"command","command":"sh audit.sh"}]}
    ]}}"#;

    /// A payload naming no field any matcher in these tests filters on, so
    /// resolution behaves exactly as it did before matcher filtering existed.
    fn no_payload() -> serde_json::Value {
        serde_json::json!({})
    }

    #[test]
    fn a_single_event_hook_resolves_without_a_reference() {
        let dir = plugin(
            r#"{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"echo hi"}]}]}}"#,
        );
        assert_eq!(
            resolve(dir.path(), HookEvent::SessionStart, None, &no_payload()).unwrap(),
            HookCommand::Shell(String::from("echo hi")),
        );
    }

    #[test]
    fn several_hooks_need_a_disambiguating_substring() {
        let dir = plugin(TWO_HOOKS);
        assert!(resolve(dir.path(), HookEvent::PreToolUse, None, &no_payload()).is_err());
        assert_eq!(
            resolve(
                dir.path(),
                HookEvent::PreToolUse,
                Some("audit"),
                &no_payload()
            )
            .unwrap(),
            HookCommand::Shell(String::from("sh audit.sh")),
        );
    }

    #[test]
    fn zero_matches_is_an_error_naming_the_event() {
        let dir = plugin(TWO_HOOKS);
        let error = resolve(dir.path(), HookEvent::SessionEnd, None, &no_payload())
            .unwrap_err()
            .to_string();
        assert!(error.contains("SessionEnd"), "{error}");
    }

    #[test]
    fn a_group_whose_matcher_does_not_match_the_payload_is_not_a_candidate() {
        let dir = plugin(
            r#"{"hooks":{"PreToolUse":[
                {"matcher":"Edit","hooks":[{"type":"command","command":"echo edit"}]},
                {"matcher":"Bash","hooks":[{"type":"command","command":"echo bash"}]}
              ]}}"#,
        );
        let payload = serde_json::json!({"tool_name": "Bash"});
        let handler = super::resolve(dir.path(), HookEvent::PreToolUse, None, &payload).unwrap();
        assert_eq!(handler, HookCommand::Shell(String::from("echo bash")));
    }

    #[test]
    fn an_unanchored_regex_matcher_reaches_a_longer_tool_name() {
        let dir = plugin(
            r#"{"hooks":{"PreToolUse":[
                {"matcher":"Edit.*","hooks":[{"type":"command","command":"echo edit"}]}
              ]}}"#,
        );
        let reached = serde_json::json!({"tool_name": "NotebookEdit"});
        let handler = super::resolve(dir.path(), HookEvent::PreToolUse, None, &reached).unwrap();
        assert_eq!(handler, HookCommand::Shell(String::from("echo edit")));

        // The matcher was actually consulted, not merely absent: a tool name
        // the pattern cannot reach still fails to resolve.
        let not_reached = serde_json::json!({"tool_name": "Bash"});
        assert!(super::resolve(dir.path(), HookEvent::PreToolUse, None, &not_reached).is_err());
    }

    #[test]
    fn a_matcher_on_an_event_that_takes_none_is_ignored_the_way_the_runtime_ignores_it() {
        let dir = plugin(
            r#"{"hooks":{"UserPromptSubmit":[
                {"matcher":"NeverMatchesAnything","hooks":[{"type":"command","command":"echo ran"}]}
              ]}}"#,
        );
        let payload = serde_json::json!({"prompt": "hello"});
        let handler =
            super::resolve(dir.path(), HookEvent::UserPromptSubmit, None, &payload).unwrap();
        assert_eq!(handler, HookCommand::Shell(String::from("echo ran")));
    }

    #[test]
    fn an_args_entry_is_read_as_an_exec_handler_keeping_every_argument() {
        let dir = plugin(
            r#"{"hooks":{"SessionStart":[{"hooks":[
                 {"type":"command","command":"sh","args":["-c","echo hi"]}
               ]}]}}"#,
        );
        let handlers = super::commands_for(dir.path(), HookEvent::SessionStart).unwrap();
        assert_eq!(
            handlers,
            vec![HookCommand::Exec {
                program: String::from("sh"),
                args: vec![String::from("-c"), String::from("echo hi")],
            }],
        );
    }

    #[test]
    fn a_handler_type_claudevs_does_not_model_is_skipped_not_collected() {
        // The prompt entry carries a `command` key on purpose. Without it the
        // entry is skipped for want of a command rather than for its type, so
        // an extractor that never reads `type` at all passes this test too.
        let dir = plugin(
            r#"{"hooks":{"SessionStart":[{"hooks":[
                 {"type":"prompt","prompt":"summarise","command":"leaked"},
                 {"type":"command","command":"true"}
               ]}]}}"#,
        );
        let handlers = super::commands_for(dir.path(), HookEvent::SessionStart).unwrap();
        assert_eq!(handlers, vec![HookCommand::Shell(String::from("true"))]);
    }

    #[test]
    fn a_group_with_no_modeled_handlers_still_names_what_the_plugin_wires() {
        let dir = plugin(r#"{"hooks":{"SessionEnd":[{"hooks":[]}]}}"#);
        let payload = serde_json::json!({});
        let outcome = super::resolve(dir.path(), HookEvent::SessionEnd, None, &payload);
        let Err(error) = outcome else {
            panic!("nothing is wired for SessionEnd");
        };
        let message = error.to_string();
        assert!(message.contains("SessionEnd"), "{message}");
        assert!(
            message.contains("wires: nothing declared"),
            "the failure must list what the plugin does wire, not end mid-sentence: {message}"
        );
    }
}
