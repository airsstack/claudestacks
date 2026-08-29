//! What counts as a wiring reference site.
//!
//! Three questions, one place: is this a file Claude Code loads, is this
//! position inside it load-bearing or illustrative, and where does a
//! reference end. Answering them once is what keeps the reference checker
//! from re-deriving the plugin layout from the plugins in front of it.

use std::path::Path;

/// The trees Claude Code loads from a plugin root.
///
/// `hooks/**` rather than `hooks/hooks.json`: a hook script is executed by
/// Claude Code, so a path inside one is wiring. A plugin's README, changelog,
/// release notes and `docs/` tree are not — nothing loads them, and a path
/// mentioned there is prose about the plugin rather than part of it.
///
/// The plugin structure reference also names `.mcp.json`, `.lsp.json`,
/// `monitors/`, `bin/` and `settings.json` as plugin-root locations Claude
/// Code loads (<https://code.claude.com/docs/en/plugins>, "Plugin structure
/// overview" table). None of those five are modeled here: this table widens
/// exactly the set the corpus measurement behind it covers — `.claude-plugin`,
/// `hooks`, `skills`, `agents`, `commands` — and a reference inside one of the
/// other five is not yet checked by this module.
const LOADED_TREES: [&str; 4] = ["hooks", "skills", "agents", "commands"];

/// Whether `relative` — a path relative to the plugin root — is a file Claude
/// Code loads.
#[must_use]
pub fn is_loaded_file(relative: &Path) -> bool {
    let mut components = relative.components();
    let Some(first) = components.next() else {
        return false;
    };
    let first = first.as_os_str();
    if first == ".claude-plugin" {
        return relative.extension().is_some_and(|e| e == "json");
    }
    LOADED_TREES.iter().any(|tree| first == *tree)
}

/// The 1-indexed lines of `text` that sit inside a fenced code block.
///
/// A fenced block is illustrative: a schema document teaching hook authoring
/// cites a `${CLAUDE_PLUGIN_ROOT}` path inside a ```` ```json ```` block as an
/// example, and that path is not claiming to exist. The fence markers
/// themselves are counted as fenced, since an info string can carry a path
/// too. An unclosed fence takes the rest of the file: a document that opens a
/// block and never closes it is not making load-bearing claims below it.
#[must_use]
pub fn fenced_lines(text: &str) -> std::collections::BTreeSet<usize> {
    let mut inside = false;
    let mut fenced = std::collections::BTreeSet::new();
    for (index, line) in text.lines().enumerate() {
        let trimmed = line.trim_start();
        let is_marker = trimmed.starts_with("```") || trimmed.starts_with("~~~");
        if is_marker {
            fenced.insert(index + 1);
            inside = !inside;
            continue;
        }
        if inside {
            fenced.insert(index + 1);
        }
    }
    fenced
}

/// Characters that end a `${CLAUDE_PLUGIN_ROOT}` reference.
///
/// `:` is here because of Claude Code's tool-argument matcher: a permission
/// rule such as `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/x.sh:*)` uses the `:*`
/// suffix as a trailing-wildcard shorthand
/// (<https://code.claude.com/docs/en/permissions>, "the `:*` suffix is an
/// equivalent way to write a trailing wildcard"), and `:*` is not part of the
/// path. Swallowing it reports a script that exists as missing.
const REFERENCE_TERMINATORS: [char; 12] = [
    ' ', '\t', '"', '\'', '`', ')', ']', '}', ',', ';', ':', '\\',
];

/// The reference at the start of `text`, up to where it ends.
///
/// `text` begins at the `$` of a `${CLAUDE_PLUGIN_ROOT}` occurrence. The
/// leading `${…}` is stepped over before scanning for a terminator, so the
/// `}` closing the variable does not end the reference it opens.
#[must_use]
pub fn reference_extent(text: &str) -> &str {
    const VARIABLE: &str = "${CLAUDE_PLUGIN_ROOT}";
    let scan_from = if text.starts_with(VARIABLE) {
        VARIABLE.len()
    } else {
        0
    };
    let end = text[scan_from..]
        .find(REFERENCE_TERMINATORS)
        .map_or(text.len(), |offset| scan_from + offset);
    text[..end].trim_end_matches('.')
}

#[cfg(test)]
mod tests {
    use super::is_loaded_file;
    use std::path::Path;

    #[test]
    fn the_five_loaded_trees_are_in_scope() {
        for rel in [
            ".claude-plugin/plugin.json",
            "hooks/hooks.json",
            "hooks/guard.py",
            "skills/authoring/SKILL.md",
            "agents/reviewer.md",
            "commands/ship.md",
        ] {
            assert!(is_loaded_file(Path::new(rel)), "{rel} should be in scope");
        }
    }

    #[test]
    fn a_plugins_own_prose_is_not_wiring() {
        for rel in [
            "README.md",
            "CHANGELOG.md",
            "RELEASE-NOTES.md",
            "docs/design.md",
            "tests/fixtures/x/README.md",
        ] {
            assert!(
                !is_loaded_file(Path::new(rel)),
                "{rel} should be out of scope"
            );
        }
    }

    #[test]
    fn a_hook_script_is_in_scope_because_claude_code_executes_it() {
        assert!(is_loaded_file(Path::new("hooks/lib/paths.sh")));
    }

    #[test]
    fn a_line_inside_a_fence_is_illustrative() {
        let text = "prose\n```json\nfenced\n```\nmore prose\n";
        let fenced = super::fenced_lines(text);
        assert!(!fenced.contains(&1), "line 1 is prose");
        assert!(fenced.contains(&3), "line 3 is inside the fence");
        assert!(!fenced.contains(&5), "line 5 is prose again");
    }

    #[test]
    fn the_fence_markers_themselves_count_as_fenced() {
        let text = "```\nx\n```\n";
        let fenced = super::fenced_lines(text);
        assert!(fenced.contains(&1));
        assert!(fenced.contains(&2));
        assert!(fenced.contains(&3));
    }

    #[test]
    fn a_tilde_fence_is_a_fence_too() {
        let text = "prose\n~~~\nfenced\n~~~\n";
        assert!(super::fenced_lines(text).contains(&3));
    }

    #[test]
    fn an_unclosed_fence_swallows_the_rest_of_the_file() {
        let text = "prose\n```\nfenced\nstill fenced\n";
        let fenced = super::fenced_lines(text);
        assert!(!fenced.contains(&1));
        assert!(fenced.contains(&4));
    }

    #[test]
    fn a_plain_path_reference_ends_at_whitespace() {
        assert_eq!(
            super::reference_extent("${CLAUDE_PLUGIN_ROOT}/scripts/run.sh and then"),
            "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh",
        );
    }

    #[test]
    fn a_reference_ends_before_a_closing_quote_or_bracket() {
        assert_eq!(
            super::reference_extent("${CLAUDE_PLUGIN_ROOT}/scripts/run.sh\")"),
            "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh",
        );
    }

    #[test]
    fn a_tool_argument_matcher_is_not_part_of_the_path() {
        // anthropics/ralph-wiggum declares:
        //   allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)"]
        // The script exists; `:*` is Claude Code's tool-argument matcher.
        assert_eq!(
            super::reference_extent("${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)"),
            "${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh",
        );
    }
}
