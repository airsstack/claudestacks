//! The `invocations` checker and the crate's one fenced-command parser.
//!
//! Responsibilities: [`FencedCommand`], [`parse_fenced`], [`check`].
//!
//! The grammar is the subset of fenced markdown that skill documents in this
//! repository actually use: a fence opens on a line whose first non-blank
//! characters are three or more backticks and closes on a line of backticks
//! alone; the opening line's indentation is stripped from the body, so a fence
//! nested in a numbered list parses the same as one at the margin; a body line
//! ending in `\` continues onto the next; a blank line or a `#` comment ends a
//! command. Every other body line is one command, in document order.
//!
//! Commands are kept as text, never split into argv: a referenced fenced
//! command must run *verbatim* — flags and grants included — because the
//! point of citing one is to prove the documented command is the command
//! that runs. The harness also already spawns command strings through
//! `sh -c`, so there is no argv to split into.
//!
//! [`check`]'s dead-file report exempts case files: [`crate::case::discover`]
//! finds `tests/**` entries by naming convention rather than by any other
//! file pointing at them, so they are entry points the harness runs, not
//! scripts that must be named to count as used.
//!
//! Fenced code blocks are read here and skipped by the `refs` checker, which
//! is not a contradiction. This checker asks "is this file referenced by
//! anything?", and a command inside a fence is evidence that it is. That one
//! asks "does this path exist?", and an example path inside a fence is not
//! claiming to. Two questions of the same text, two right answers.

use std::collections::HashSet;
use std::os::unix::fs::PermissionsExt as _;
use std::path::{Path, PathBuf};

use crate::case;
use crate::error::{Error, Result};
use crate::wiring::{Finding, Severity, refs};

/// One command parsed out of a fenced block.
#[derive(Debug, Clone, PartialEq, Eq)]
#[non_exhaustive]
pub struct FencedCommand {
    /// 1-based line where the command starts.
    pub line: usize,
    /// The fence's info string: `sh`, `bash`, or empty.
    pub language: String,
    /// The command text, with `\` continuations joined by single spaces.
    pub command: String,
}

/// Every command in every fenced block of `markdown`, in document order.
#[must_use]
pub fn parse_fenced(markdown: &str) -> Vec<FencedCommand> {
    let mut commands = Vec::new();
    let mut open: Option<(usize, usize, String)> = None;
    let mut pending: Option<(usize, String)> = None;

    for (index, line) in markdown.lines().enumerate() {
        let trimmed = line.trim_start();
        let indent = line.len() - trimmed.len();
        let ticks = trimmed.chars().take_while(|c| *c == '`').count();

        let Some((open_ticks, open_indent, language)) = open.clone() else {
            if ticks >= 3 {
                open = Some((ticks, indent, trimmed[ticks..].trim().to_owned()));
            }
            continue;
        };

        if ticks >= open_ticks && trimmed.trim_end_matches('`').is_empty() {
            flush(&mut commands, &mut pending, &language);
            open = None;
            continue;
        }

        let body = line
            .strip_prefix(" ".repeat(open_indent).as_str())
            .unwrap_or(trimmed)
            .trim_end();
        if body.trim().is_empty() || body.trim_start().starts_with('#') {
            flush(&mut commands, &mut pending, &language);
            continue;
        }

        let (text, continues) = body
            .strip_suffix('\\')
            .map_or((body, false), |head| (head.trim_end(), true));
        match &mut pending {
            Some((_, accumulated)) => {
                accumulated.push(' ');
                accumulated.push_str(text.trim_start());
            }
            None => pending = Some((index + 1, text.to_owned())),
        }
        if !continues {
            flush(&mut commands, &mut pending, &language);
        }
    }

    // An unclosed fence is a malformed document, not a reason to lose what it
    // held: the last command is reported rather than silently dropped.
    if let Some((_, _, language)) = open {
        flush(&mut commands, &mut pending, &language);
    }
    commands
}

/// Moves an accumulated command into the list.
fn flush(commands: &mut Vec<FencedCommand>, pending: &mut Option<(usize, String)>, language: &str) {
    if let Some((line, command)) = pending.take() {
        commands.push(FencedCommand {
            line,
            language: language.to_owned(),
            command,
        });
    }
}

/// File extensions the dead-file report covers.
const SCRIPT_EXTENSIONS: [&str; 4] = ["sh", "lua", "py", "js"];

/// Files a language reaches by importing their directory rather than by name.
///
/// One per scanned language. `mod.rs` is deliberately absent: `.rs` is not in
/// [`SCRIPT_EXTENSIONS`], so a Rust file is never a candidate here and the
/// entry would be dead code. Only `__init__.py` is backed by the corpus that
/// motivated this exemption; `index.js` and `init.lua` are the same convention
/// in the other two scanned languages and are included on that basis rather
/// than on measurement.
const INDEX_FILES: [&str; 3] = ["__init__.py", "index.js", "init.lua"];

/// Reports scripts in the plugin that nothing else in it names.
///
/// A script counts as referenced when its file name appears in any other
/// UTF-8 file of the plugin — a hooks.json command, a fenced command in a
/// skill, a sibling script. Existence of a *referenced* path is the `refs`
/// checker's job, not this one.
///
/// A script escapes the report five ways, not one: a file `case::discover`
/// classifies as a case file is exempt even when nothing names it, because the
/// claudevs harness finds it by glob under `tests/**` and runs it directly, so
/// "referenced by nothing" is false for it — it just has no name to be
/// referenced by. The plugin's own `tests/**` tree is exempt outright, whatever
/// its files are called. A language index file (`__init__.py` and its peers)
/// is reached by its directory rather than by name. Sample material that does
/// not present as executable is not wiring at all. And a reference by bare
/// module stem — an import or a `require` that never spells the extension —
/// counts as a reference the same as a reference by filename.
///
/// # Errors
///
/// [`Error::Io`] when the plugin directory cannot be walked.
pub fn check(plugin_dir: &Path) -> Result<Vec<Finding>> {
    let files = readable_files(plugin_dir)?;
    let case_files = discovered_case_files(plugin_dir)?;
    let mut findings = Vec::new();

    for (path, relative, text) in &files {
        let is_script = path
            .extension()
            .and_then(|e| e.to_str())
            .is_some_and(|e| SCRIPT_EXTENSIONS.contains(&e));
        let Some(name) = path.file_name().and_then(|n| n.to_str()) else {
            continue;
        };
        if !is_script
            || case_files.contains(path)
            || is_in_tests_tree(relative)
            || INDEX_FILES.contains(&name)
            || !presents_as_executable(path, text, relative)
        {
            continue;
        }
        // Module systems import by stem: a Python `from … import config_loader` and
        // a Lua `require("lib.globs")` never spell the extension. Matching only the
        // filename reports such a file as dead when it is the most-used file in the
        // plugin.
        let stem = path.file_stem().and_then(|n| n.to_str()).unwrap_or(name);
        let referenced = files.iter().any(|(other, _, other_text)| {
            other != path
                && (other_text.contains(name)
                    || other_text.contains(stem)
                    || mentions(other_text, name)
                    || mentions(other_text, stem))
        });
        if !referenced {
            findings.push(Finding {
                severity: Severity::Warning,
                checker: "invocations",
                file: relative.clone(),
                line: None,
                message: format!("`{name}` is referenced by nothing in this plugin"),
            });
        }
    }
    Ok(findings)
}

/// Whether a file presents as something meant to be run.
///
/// A shebang or an executable bit. Sample material a skill ships for a reader
/// has neither, and reporting it as dead wiring is reporting the skill for
/// doing its job. Inside `hooks/`, everything is treated as executable
/// regardless: that tree is what Claude Code runs, so a stray file there is
/// worth a warning even without a bit set.
fn presents_as_executable(path: &Path, text: &str, relative: &str) -> bool {
    if relative.starts_with("hooks/") || relative.starts_with("hooks\\") {
        return true;
    }
    if text.starts_with("#!") {
        return true;
    }
    std::fs::metadata(path).is_ok_and(|meta| meta.permissions().mode() & 0o111 != 0)
}

/// Whether `relative` sits in the plugin's own test tree.
///
/// A plugin's tests are not wired into the plugin, and claudevs' case-file
/// naming is not the only convention — a plugin with a `tests/test_guard.py`
/// is testing itself, not shipping dead wiring.
fn is_in_tests_tree(relative: &str) -> bool {
    relative == "tests" || relative.starts_with("tests/") || relative.starts_with("tests\\")
}

/// The paths `case::discover` classifies as case files under `plugin_dir`.
///
/// A plugin with no cases at all is normal for a plugin this checker is
/// asked about, so [`Error::NoCases`] collapses to an empty set rather than
/// propagating — a caseless plugin must still get its dead-file report.
fn discovered_case_files(plugin_dir: &Path) -> Result<HashSet<PathBuf>> {
    match case::discover(plugin_dir) {
        Ok(files) => Ok(files
            .into_iter()
            .map(|file| match file {
                case::CaseFile::Yaml(path) | case::CaseFile::Lua(path) => path,
            })
            .collect()),
        Err(Error::NoCases { .. }) => Ok(HashSet::new()),
        Err(other) => Err(other),
    }
}

/// Whether any fenced command or plugin-root reference in `text` names `name`.
///
/// Plain text containment already catches most references; this adds the two
/// structured readings so a name that only ever appears inside a fence or a
/// `${CLAUDE_PLUGIN_ROOT}` tail is still seen.
fn mentions(text: &str, name: &str) -> bool {
    parse_fenced(text)
        .iter()
        .any(|command| command.command.contains(name))
        || refs::occurrences(text)
            .iter()
            .any(|occurrence| occurrence.target.ends_with(name))
}

/// Every UTF-8 file under `plugin_dir`: absolute path, plugin-relative path, text.
fn readable_files(plugin_dir: &Path) -> Result<Vec<(PathBuf, String, String)>> {
    let mut files = Vec::new();
    for entry in walkdir::WalkDir::new(plugin_dir).sort_by_file_name() {
        let entry = entry.map_err(|source| Error::Io {
            operation: "walk plugin",
            path: plugin_dir.display().to_string(),
            source: source.into(),
        })?;
        if !entry.file_type().is_file() {
            continue;
        }
        let Ok(text) = std::fs::read_to_string(entry.path()) else {
            continue;
        };
        let relative = entry
            .path()
            .strip_prefix(plugin_dir)
            .unwrap_or_else(|_| entry.path())
            .display()
            .to_string();
        files.push((entry.path().to_path_buf(), relative, text));
    }
    Ok(files)
}

#[cfg(test)]
mod tests {
    #![expect(clippy::unwrap_used, reason = "tests unwrap known-valid fixtures")]

    use std::os::unix::fs::PermissionsExt;

    use super::{check, parse_fenced};

    const SKILL: &str = "\
## Steps

1. Resolve the bundle root:

   ```sh
   airsl run --policy confined --allow-read . \\
     \"${CLAUDE_PLUGIN_ROOT}/scripts/okf-root.lua\" [explicit-path]
   ```

   Exit 2 -> relay stderr and STOP.

2. Then two more:

```bash
# a comment line is not a command
echo one
echo two
```
";

    #[test]
    fn a_continuation_joins_into_one_command() {
        let commands = parse_fenced(SKILL);
        assert_eq!(
            commands[0].command,
            "airsl run --policy confined --allow-read . \"${CLAUDE_PLUGIN_ROOT}/scripts/okf-root.lua\" [explicit-path]"
        );
        assert_eq!(commands[0].language, "sh");
        assert_eq!(commands[0].line, 6);
    }

    #[test]
    fn each_command_line_of_a_block_is_its_own_invocation_and_comments_are_not() {
        let commands = parse_fenced(SKILL);
        assert_eq!(commands.len(), 3, "{commands:?}");
        assert_eq!(commands[1].command, "echo one");
        assert_eq!(commands[2].command, "echo two");
        assert_eq!(commands[1].language, "bash");
    }

    #[test]
    fn prose_outside_a_fence_is_never_a_command() {
        let commands = parse_fenced("just prose, `echo inline` included\n");
        assert!(commands.is_empty(), "{commands:?}");
    }

    #[test]
    fn an_unclosed_fence_still_yields_what_it_opened() {
        let commands = parse_fenced("```sh\necho only\n");
        assert_eq!(commands.len(), 1);
        assert_eq!(commands[0].command, "echo only");
    }

    #[test]
    fn a_script_no_other_file_names_is_a_warning_not_an_error() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("hooks")).unwrap();
        std::fs::write(dir.path().join("hooks/used.sh"), "exit 0\n").unwrap();
        std::fs::write(dir.path().join("hooks/orphan.sh"), "exit 0\n").unwrap();
        std::fs::write(
            dir.path().join("hooks/hooks.json"),
            r#"{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"sh \"${CLAUDE_PLUGIN_ROOT}/hooks/used.sh\""}]}]}}"#,
        )
        .unwrap();

        let findings = check(dir.path()).unwrap();
        assert_eq!(findings.len(), 1, "{findings:?}");
        assert_eq!(findings[0].severity, crate::wiring::Severity::Warning);
        assert_eq!(findings[0].file, "hooks/orphan.sh");
        assert!(findings[0].message.contains("referenced"), "{findings:?}");
    }

    #[test]
    fn a_script_naming_itself_in_its_own_body_is_still_unreferenced() {
        // Scripts routinely carry their own name — a usage line, a banner, a
        // self-referential comment. Without the `other != path` guard such a
        // file vouches for itself and can never be reported dead, so this is
        // the case that makes the guard load-bearing.
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("hooks")).unwrap();
        std::fs::write(
            dir.path().join("hooks/orphan.sh"),
            "# usage: sh hooks/orphan.sh\nexit 0\n",
        )
        .unwrap();

        let findings = check(dir.path()).unwrap();
        assert_eq!(findings.len(), 1, "{findings:?}");
        assert_eq!(findings[0].file, "hooks/orphan.sh");
    }

    #[test]
    fn a_script_named_only_by_a_fenced_command_counts_as_referenced() {
        // A skill that documents `sh hooks/helper.sh` with no ${CLAUDE_PLUGIN_ROOT}
        // prefix still references it; the dead-file report must not claim otherwise.
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("hooks")).unwrap();
        std::fs::create_dir_all(dir.path().join("skills/demo")).unwrap();
        std::fs::write(dir.path().join("hooks/helper.sh"), "exit 0\n").unwrap();
        std::fs::write(
            dir.path().join("skills/demo/SKILL.md"),
            "Run it:\n\n```sh\nsh hooks/helper.sh\n```\n",
        )
        .unwrap();
        assert!(check(dir.path()).unwrap().is_empty());
    }

    #[test]
    fn a_discovered_case_file_is_not_reported_dead() {
        // `tests/foo_test.lua` matches the case-file naming convention that
        // `case::discover` implements — it is an entry point the harness finds
        // by glob and runs, not a script some other file must name for it to
        // count as referenced.
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("tests")).unwrap();
        std::fs::write(dir.path().join("tests/foo_test.lua"), "return {}\n").unwrap();

        let findings = check(dir.path()).unwrap();
        assert!(findings.is_empty(), "{findings:?}");
    }

    #[test]
    fn a_python_module_imported_by_stem_is_referenced() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("hookify/core")).unwrap();
        std::fs::write(
            dir.path().join("hookify/core/config_loader.py"),
            "RULES = []\n",
        )
        .unwrap();
        // The executable bit is set so this fixture survives
        // `presents_as_executable`: without it the file would be exempted as
        // sample material before the stem check ever runs, and the assertion
        // below would pass whether or not the stem widening exists.
        std::fs::set_permissions(
            dir.path().join("hookify/core/config_loader.py"),
            std::fs::Permissions::from_mode(0o755),
        )
        .unwrap();
        std::fs::write(
            dir.path().join("hookify/core/main.py"),
            "from hookify.core.config_loader import load_rules\n",
        )
        .unwrap();
        let findings = check(dir.path()).unwrap();
        assert!(
            findings
                .iter()
                .all(|f| !f.message.contains("config_loader")),
            "{findings:?}"
        );
    }

    #[test]
    fn a_lua_module_required_by_stem_is_referenced() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("lib")).unwrap();
        std::fs::write(dir.path().join("lib/globs.lua"), "return {}\n").unwrap();
        // See the matching comment in `a_python_module_imported_by_stem_is_referenced`:
        // the bit is what keeps this fixture from being exempted before the
        // stem check runs.
        std::fs::set_permissions(
            dir.path().join("lib/globs.lua"),
            std::fs::Permissions::from_mode(0o755),
        )
        .unwrap();
        std::fs::write(
            dir.path().join("init.lua"),
            "local g = require(\"lib.globs\")\n",
        )
        .unwrap();
        let findings = check(dir.path()).unwrap();
        assert!(
            findings.iter().all(|f| !f.message.contains("globs")),
            "{findings:?}"
        );
    }

    #[test]
    fn a_stem_that_appears_nowhere_is_still_reported() {
        // The executable bit is set deliberately: the non-executable exemption
        // in `presents_as_executable` exempts a non-executable file outside
        // `hooks/` as sample material, which is an axis orthogonal to what
        // this test pins — a stem that appears nowhere. Without the bit, this
        // file would be skipped before the stem check ever runs, and the test
        // would pass for the wrong reason.
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("lib")).unwrap();
        std::fs::write(dir.path().join("lib/orphan.lua"), "return {}\n").unwrap();
        std::fs::set_permissions(
            dir.path().join("lib/orphan.lua"),
            std::fs::Permissions::from_mode(0o755),
        )
        .unwrap();
        std::fs::write(
            dir.path().join("driver.lua"),
            "local g = require(\"lib.other\")\n",
        )
        .unwrap();
        let findings = check(dir.path()).unwrap();
        assert!(
            findings.iter().any(|f| f.message.contains("orphan.lua")),
            "{findings:?}"
        );
    }

    #[test]
    fn a_language_index_file_is_exempt_because_its_directory_is_the_reference() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("pkg")).unwrap();
        std::fs::write(dir.path().join("pkg/__init__.py"), "").unwrap();
        // The executable bit is set so this fixture survives
        // `presents_as_executable`: without it the file would already be
        // exempted as sample material, and the assertion below would pass
        // whether or not the index-file exemption exists.
        std::fs::set_permissions(
            dir.path().join("pkg/__init__.py"),
            std::fs::Permissions::from_mode(0o755),
        )
        .unwrap();
        assert!(check(dir.path()).unwrap().is_empty());
    }

    #[test]
    fn a_plugins_own_tests_directory_is_exempt_whatever_the_files_are_called() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("tests")).unwrap();
        std::fs::write(
            dir.path().join("tests/test_guard.py"),
            "# nothing names me\n",
        )
        .unwrap();
        std::fs::write(dir.path().join("tests/helpers.sh"), "# nor me\n").unwrap();
        // Both bits are set so these fixtures survive `presents_as_executable`:
        // without them the files would already be exempted as sample
        // material, and the assertion below would pass whether or not the
        // tests-tree exemption exists.
        std::fs::set_permissions(
            dir.path().join("tests/test_guard.py"),
            std::fs::Permissions::from_mode(0o755),
        )
        .unwrap();
        std::fs::set_permissions(
            dir.path().join("tests/helpers.sh"),
            std::fs::Permissions::from_mode(0o755),
        )
        .unwrap();
        assert!(check(dir.path()).unwrap().is_empty());
    }

    #[test]
    fn a_non_executable_unshebanged_script_outside_hooks_and_skills_is_exempt() {
        // Pins the actual reach of `presents_as_executable` today: the
        // exemption is not scoped to `skills/`, so a dead, non-executable,
        // unshebanged script directly under `scripts/` escapes the report
        // the same way sample material under `skills/` does. Whether the
        // exemption should be narrowed to `skills/` is a scoping question
        // for the checker's design, not this test.
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("scripts")).unwrap();
        std::fs::write(dir.path().join("scripts/dead.py"), "print('unused')\n").unwrap();
        std::fs::write(dir.path().join("scripts/dead.sh"), "echo unused\n").unwrap();
        std::fs::write(dir.path().join("scripts/dead.lua"), "return {}\n").unwrap();
        assert!(check(dir.path()).unwrap().is_empty());
    }

    #[test]
    fn a_script_outside_tests_that_nothing_names_is_still_reported() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("scripts")).unwrap();
        std::fs::write(dir.path().join("scripts/orphan.sh"), "#!/bin/sh\n").unwrap();
        let findings = check(dir.path()).unwrap();
        assert_eq!(findings.len(), 1, "{findings:?}");
    }

    #[test]
    fn a_non_executable_sample_outside_hooks_is_not_dead_wiring() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("skills/x")).unwrap();
        std::fs::write(dir.path().join("skills/x/example.sh"), "echo sample\n").unwrap();
        assert!(check(dir.path()).unwrap().is_empty());
    }

    #[test]
    fn a_shebanged_script_outside_hooks_that_nothing_names_is_still_reported() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("scripts")).unwrap();
        std::fs::write(
            dir.path().join("scripts/optimize-prompt.py"),
            "#!/usr/bin/env python3\nprint('hi')\n",
        )
        .unwrap();
        let findings = check(dir.path()).unwrap();
        assert_eq!(findings.len(), 1, "{findings:?}");
    }

    #[test]
    fn a_non_executable_file_inside_hooks_is_still_reported() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dir.path().join("hooks")).unwrap();
        std::fs::write(dir.path().join("hooks/helper.sh"), "echo helper\n").unwrap();
        let findings = check(dir.path()).unwrap();
        assert_eq!(findings.len(), 1, "{findings:?}");
    }
}
