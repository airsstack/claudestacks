//! Hook payloads: built-in defaults, case overlay, `{project}` substitution.
//!
//! The defaults describe a project that exists on disk: [`crate::harness::project`]
//! builds it and this module points a payload's `tool_input.file_path` at it,
//! both reading the same [`crate::harness::project::TRACKED_FILE`] constant so
//! the payload and the project cannot drift apart. A case may still overlay its
//! own values over any of these defaults; the overlay mechanism does not care
//! where the base came from.

use crate::types::HookEvent;

/// The built-in default payload for `event`.
#[must_use]
pub fn default_payload(event: HookEvent) -> serde_json::Value {
    let base = serde_json::json!({
        "session_id": "claudevs-test",
        "cwd": "{project}",
        "hook_event_name": event.as_str(),
    });
    let mut value = base;
    let extra = match event {
        HookEvent::PreToolUse | HookEvent::PostToolUse => serde_json::json!({
            "tool_name": "Edit",
            "tool_input": {
                "file_path": format!("{{project}}/{}", crate::harness::project::TRACKED_FILE),
            },
        }),
        HookEvent::UserPromptSubmit => serde_json::json!({ "prompt": "hello" }),
        HookEvent::SessionStart => serde_json::json!({ "source": "startup" }),
        HookEvent::SessionEnd => serde_json::json!({ "reason": "exit" }),
    };
    merge(&mut value, &extra);
    value
}

/// Overlays `over` onto `base`: objects merge recursively, everything else replaces.
pub fn merge(base: &mut serde_json::Value, over: &serde_json::Value) {
    match (base, over) {
        (serde_json::Value::Object(b), serde_json::Value::Object(o)) => {
            for (key, value) in o {
                merge(
                    b.entry(key.clone()).or_insert(serde_json::Value::Null),
                    value,
                );
            }
        }
        (slot, other) => *slot = other.clone(),
    }
}

/// Replaces `{project}` in every string of `value` with `project`.
#[expect(
    clippy::literal_string_with_formatting_args,
    reason = "the `{project}` literal is a placeholder token replaced by str::replace, not a format string"
)]
pub fn substitute_project(value: &mut serde_json::Value, project: &str) {
    match value {
        serde_json::Value::String(s) => {
            if s.contains("{project}") {
                *s = s.replace("{project}", project);
            }
        }
        serde_json::Value::Array(items) => {
            for item in items {
                substitute_project(item, project);
            }
        }
        serde_json::Value::Object(map) => {
            for item in map.values_mut() {
                substitute_project(item, project);
            }
        }
        _ => {}
    }
}

#[cfg(test)]
mod tests {
    #![expect(clippy::unwrap_used, reason = "tests unwrap known-valid payloads")]

    use super::{default_payload, merge, substitute_project};
    use crate::types::HookEvent;

    #[test]
    fn an_overlaid_field_wins_and_siblings_survive() {
        let mut payload = default_payload(HookEvent::PreToolUse);
        merge(
            &mut payload,
            &serde_json::json!({ "tool_input": { "file_path": "Cargo.lock" } }),
        );
        assert_eq!(payload["tool_input"]["file_path"], "Cargo.lock");
        assert_eq!(payload["tool_name"], "Edit"); // sibling default kept
        assert_eq!(payload["hook_event_name"], "PreToolUse");
    }

    #[test]
    fn project_placeholders_resolve_everywhere_in_the_tree() {
        let mut payload = default_payload(HookEvent::PreToolUse);
        substitute_project(&mut payload, "/tmp/p1");
        assert_eq!(payload["cwd"], "/tmp/p1");
        assert_eq!(
            payload["tool_input"]["file_path"],
            format!("/tmp/p1/{}", crate::harness::project::TRACKED_FILE)
        );
    }

    #[test]
    fn the_default_tool_input_resolves_to_a_file_that_exists() {
        let project = crate::harness::Project::empty().unwrap();
        let mut payload = default_payload(HookEvent::PreToolUse);
        substitute_project(&mut payload, &project.path().display().to_string());
        let target = payload["tool_input"]["file_path"].as_str().unwrap();
        assert!(
            std::path::Path::new(target).is_file(),
            "a PreToolUse hook that stats its target must find one: {target}"
        );
    }

    #[test]
    fn every_event_has_a_default_payload_object() {
        for event in [
            HookEvent::PreToolUse,
            HookEvent::PostToolUse,
            HookEvent::UserPromptSubmit,
            HookEvent::SessionStart,
            HookEvent::SessionEnd,
        ] {
            assert!(default_payload(event).is_object(), "{event:?}");
        }
    }
}
