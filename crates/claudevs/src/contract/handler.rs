//! The `hooks.json` handler entry.
//!
//! The reference specifies two execution models for a `type: "command"`
//! handler, and they are genuinely different rather than a flag on one shape:
//! a `command` alone is run through a shell, while a `command` with `args` is
//! resolved as an executable and spawned directly — "There is no shell, so
//! each `args` element is one argument exactly as written … No shell
//! tokenization happens on any platform."
//!
//! Handler types claudevs does not model — prompt, agent, `http`, `mcp_tool`
//! — are skipped rather than rejected. claudevs not modelling a handler is a
//! limit of claudevs, and turning it into a parse failure would fail a plugin
//! that is correct.

/// One `type: "command"` handler from `hooks.json`.
#[derive(Debug, Clone, PartialEq, Eq)]
#[non_exhaustive]
pub enum HookCommand {
    /// `command` alone: run through `sh -c`.
    Shell(String),
    /// `command` plus `args`: spawned directly, no shell.
    Exec {
        /// The executable.
        program: String,
        /// The argument vector, each element passed exactly as written.
        args: Vec<String>,
    },
}

/// The handler an entry declares, or `None` when claudevs does not model it.
///
/// `None` is not an error. An entry whose `type` is not `command`, an entry
/// with no `type`, and an entry claudevs cannot parse are all skipped, so a
/// plugin mixing a prompt handler into a hook group still runs its command
/// handlers.
#[must_use]
pub fn from_entry(entry: &serde_json::Value) -> Option<HookCommand> {
    if entry.get("type").and_then(serde_json::Value::as_str) != Some("command") {
        return None;
    }
    let command = entry.get("command").and_then(serde_json::Value::as_str)?;
    let Some(args) = entry.get("args").and_then(serde_json::Value::as_array) else {
        return Some(HookCommand::Shell(command.to_owned()));
    };
    let args: Vec<String> = args
        .iter()
        .filter_map(|a| a.as_str().map(str::to_owned))
        .collect();
    Some(HookCommand::Exec {
        program: command.to_owned(),
        args,
    })
}

impl HookCommand {
    /// The handler as text, for substring matching and for reporting.
    ///
    /// One definition so the `hook:` disambiguator and a failure message can
    /// never disagree about what a handler is called. For an exec handler
    /// this is the argv actually spawned, joined by single spaces — the thing
    /// a shell-only reading of `hooks.json` makes invisible.
    #[must_use]
    pub fn display(&self) -> String {
        match self {
            Self::Shell(command) => command.clone(),
            Self::Exec { program, args } if args.is_empty() => program.clone(),
            Self::Exec { program, args } => format!("{program} {}", args.join(" ")),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{HookCommand, from_entry};

    #[test]
    fn an_entry_with_only_a_command_is_a_shell_handler() {
        let entry = serde_json::json!({"type": "command", "command": "echo hi"});
        assert_eq!(
            from_entry(&entry),
            Some(HookCommand::Shell(String::from("echo hi"))),
        );
    }

    #[test]
    fn an_entry_with_args_is_an_exec_handler_and_keeps_every_element() {
        let entry = serde_json::json!({
            "type": "command",
            "command": "sh",
            "args": ["-c", "echo hi"]
        });
        assert_eq!(
            from_entry(&entry),
            Some(HookCommand::Exec {
                program: String::from("sh"),
                args: vec![String::from("-c"), String::from("echo hi")],
            }),
        );
    }

    #[test]
    fn a_handler_type_claudevs_does_not_model_is_skipped_not_an_error() {
        let entry = serde_json::json!({"type": "prompt", "prompt": "summarise"});
        assert_eq!(from_entry(&entry), None);
    }

    #[test]
    fn an_entry_with_no_type_at_all_is_skipped() {
        let entry = serde_json::json!({"command": "echo hi"});
        assert_eq!(from_entry(&entry), None);
    }

    #[test]
    fn an_entry_that_cannot_be_parsed_is_skipped_not_an_error() {
        assert_eq!(from_entry(&serde_json::json!(42)), None);
        assert_eq!(from_entry(&serde_json::json!({"type": "command"})), None);
    }

    #[test]
    fn a_shell_handler_displays_as_its_command_string() {
        assert_eq!(
            HookCommand::Shell(String::from("echo hi")).display(),
            "echo hi",
        );
    }

    #[test]
    fn an_exec_handler_displays_as_the_argv_it_spawns() {
        let handler = HookCommand::Exec {
            program: String::from("sh"),
            args: vec![String::from("-c"), String::from("echo hi")],
        };
        assert_eq!(handler.display(), "sh -c echo hi");
    }

    #[test]
    fn an_exec_handler_with_no_args_displays_as_its_program_alone() {
        let handler = HookCommand::Exec {
            program: String::from("true"),
            args: Vec::new(),
        };
        assert_eq!(handler.display(), "true");
    }
}
