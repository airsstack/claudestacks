-- Tests for lib/handoff_report — schema conformance of a written handoff report.
--
--   airsl test --allow-read "$TMPDIR" --allow-write "$TMPDIR" --allow-read . plugins/claudestacks/scripts

local report = require("lib.handoff_report")
local fs = airsstack.fs
local path = airsstack.path

-- Writes `body` to a fresh temp file and returns its path. The name matters only where a test
-- is about the path, so every test that is not names it plainly.
local function written(body, name)
  local file = path.join(fs.tempdir(), name or "report.md")
  fs.write(file, body)
  return file
end

-- The violation identifiers from `report.check`, sorted, as one comparable string.
local function ids(file)
  local found = {}
  for _, violation in ipairs(report.check(file)) do
    found[#found + 1] = violation.id
  end
  table.sort(found)
  return table.concat(found, ",")
end

return {
  a_report_without_frontmatter_is_a_violation = function()
    local file = written("<summary>\nfine\n</summary>\n")
    assert(ids(file):find("frontmatter%-missing"), ids(file))
  end,

  an_absent_agent_key_is_a_violation = function()
    local file = written("---\ntask: something\n---\n<summary>\nx\n</summary>\n")
    assert(ids(file):find("agent%-missing"), ids(file))
  end,

  an_empty_task_value_is_a_violation = function()
    local file = written("---\nagent: coder\ntask:\n---\n<summary>\nx\n</summary>\n")
    assert(ids(file):find("task%-missing"), ids(file))
  end,

  both_required_keys_present_is_clean_of_those_two = function()
    local file = written("---\nagent: coder\ntask: build the thing\n---\n<summary>\nx\n</summary>\n")
    local found = ids(file)
    assert(not found:find("agent%-missing"), found)
    assert(not found:find("task%-missing"), found)
  end,

  a_session_tier_report_needs_session_and_seq = function()
    local handoff = require("lib.handoff")
    local dir = path.join(fs.tempdir(), handoff.HANDOFF_REL, "20260101-000000-ab")
    fs.mkdir(dir)
    local file = path.join(dir, "01-coder-thing.md")
    fs.write(file, "---\nagent: coder\ntask: t\n---\n<summary>\nx\n</summary>\n")
    local found = ids(file)
    assert(found:find("session%-missing"), found)
    assert(found:find("seq%-missing"), found)
  end,

  a_temp_path_report_must_not_carry_session_or_seq = function()
    local file = written(
      "---\nagent: chain-reader\ntask: t\nsession: 20260101-000000-ab\nseq: 01\n---\n<summary>\nx\n</summary>\n"
    )
    local found = ids(file)
    assert(found:find("session%-unexpected"), found)
    assert(found:find("seq%-unexpected"), found)
  end,

  an_init_refused_report_is_classified_with_the_exception = function()
    -- `<session-scratch>/handoff/` keeps the naming but mints no session, so neither key belongs.
    local dir = path.join(fs.tempdir(), "handoff")
    fs.mkdir(dir)
    local file = path.join(dir, "01-coder-thing.md")
    fs.write(file, "---\nagent: coder\ntask: t\n---\n<summary>\nx\n</summary>\n")
    local found = ids(file)
    assert(not found:find("session%-missing"), found)
    assert(not found:find("seq%-missing"), found)
  end,

  a_report_with_no_summary_pair_is_a_violation = function()
    local file = written("---\nagent: coder\ntask: t\n---\nbody with no tags\n")
    assert(ids(file):find("summary%-missing"), ids(file))
  end,

  two_summary_pairs_are_a_violation = function()
    local file = written(
      "---\nagent: coder\ntask: t\n---\n<summary>\na\n</summary>\n<summary>\nb\n</summary>\n"
    )
    assert(ids(file):find("summary%-repeated"), ids(file))
  end,

  an_unclosed_summary_is_a_violation = function()
    local file = written("---\nagent: coder\ntask: t\n---\n<summary>\na\n")
    assert(ids(file):find("summary%-unclosed"), ids(file))
  end,

  prose_discussing_the_tags_is_not_a_tag = function()
    -- The failure this rule exists for: an unanchored count returned 3 where 2 was expected,
    -- because a finding discussed the `<summary>`/`<detail>` schema in prose.
    local file = written(
      "---\nagent: artifact-reviewer\ntask: t\n---\n"
        .. "<summary>\nthe file wraps its halves in <summary> and <detail> tags\n</summary>\n"
    )
    assert(ids(file) == "", ids(file))
  end,

  a_tag_with_trailing_text_is_not_a_tag = function()
    local file = written("---\nagent: coder\ntask: t\n---\n<summary>text on the same line\n</summary>\n")
    assert(ids(file):find("summary%-missing"), ids(file))
  end,

  an_empty_summary_is_a_violation = function()
    local file = written("---\nagent: coder\ntask: t\n---\n<summary>\n\n  \n</summary>\n")
    assert(ids(file):find("summary%-empty"), ids(file))
  end,

  an_absent_detail_is_legal = function()
    local file = written("---\nagent: coder\ntask: t\n---\n<summary>\nx\n</summary>\n")
    assert(ids(file) == "", ids(file))
  end,

  two_detail_pairs_are_a_violation = function()
    local file = written(
      "---\nagent: coder\ntask: t\n---\n<summary>\nx\n</summary>\n"
        .. "<detail>\na\n</detail>\n<detail>\nb\n</detail>\n"
    )
    assert(ids(file):find("detail%-repeated"), ids(file))
  end,

  an_unclosed_detail_is_a_violation = function()
    local file = written(
      "---\nagent: coder\ntask: t\n---\n<summary>\nx\n</summary>\n<detail>\na\n"
    )
    assert(ids(file):find("detail%-unclosed"), ids(file))
  end,

  a_conforming_session_tier_report_is_clean = function()
    local handoff = require("lib.handoff")
    local dir = path.join(fs.tempdir(), handoff.HANDOFF_REL, "20260101-000000-ab")
    fs.mkdir(dir)
    local file = path.join(dir, "03-reviewer-diff.md")
    fs.write(
      file,
      "---\nagent: reviewer\ntask: review the batch diff\nsession: 20260101-000000-ab\nseq: 03\n---\n"
        .. "<summary>\nblocking: none\n</summary>\n<detail>\nthe full list\n</detail>\n"
    )
    assert(ids(file) == "", ids(file))
  end,

  a_conforming_exception_tier_report_is_clean = function()
    local file = written(
      "---\nagent: artifact-reviewer\ntask: review spec.md against intent.md\n---\n"
        .. "<summary>\nSPEC: none blocking\n</summary>\n<detail>\nthe findings\n</detail>\n",
      "claudestacks-sdlc-chain-spec-01.md"
    )
    assert(ids(file) == "", ids(file))
  end,

  a_conforming_init_refused_report_is_clean = function()
    local dir = path.join(fs.tempdir(), "handoff")
    fs.mkdir(dir)
    local file = path.join(dir, "02-explorer-map.md")
    fs.write(
      file,
      "---\nagent: explorer\ntask: map the transport module\n---\n<summary>\n12 files\n</summary>\n"
    )
    assert(ids(file) == "", ids(file))
  end,

  an_absent_file_is_unreadable = function()
    local file = path.join(fs.tempdir(), "does-not-exist.md")
    assert(ids(file) == "unreadable", ids(file))
  end,

  a_denied_read_classifies_separately_from_an_absent_file = function()
    -- The gate runs with --allow-read /, so a real confinement denial cannot be provoked there;
    -- classify the literal error text `airsl` 0.1.2 returns instead (probed 2026-09-21).
    local absent =
      "read_lines failed on `/private/tmp/claude-501/absent-file.md`: No such file or directory (os error 2)"
    local denied =
      "fs.read_lines denied: `/private/etc/hosts` is outside the granted read roots: /private/tmp/claude-501"
    assert(report.classify_read_error(absent) == "unreadable", report.classify_read_error(absent))
    assert(report.classify_read_error(denied) == "read-denied", report.classify_read_error(denied))
  end,

  an_unterminated_frontmatter_is_not_reported_as_missing = function()
    local file = written("---\nagent: coder\ntask: t\n")
    local found = ids(file)
    assert(found:find("frontmatter%-unterminated"), found)
    assert(not found:find("frontmatter%-missing"), found)
  end,

  a_missing_frontmatter_is_not_reported_as_unterminated = function()
    local file = written("<summary>\nfine\n</summary>\n")
    local found = ids(file)
    assert(found:find("frontmatter%-missing"), found)
    assert(not found:find("frontmatter%-unterminated"), found)
  end,

  an_exception_tier_path_is_found = function()
    -- The case a shape-keyed matcher misses: no NN- prefix, no handoff/ segment.
    assert(report.path_in("done. report at /tmp/journal-curator-review.md")
      == "/tmp/journal-curator-review.md")
  end,

  a_session_tier_path_is_found = function()
    assert(report.path_in("blocking: none\n.airsstack/cc/plugins/claudestacks/handoff/s/03-reviewer-diff.md")
      == ".airsstack/cc/plugins/claudestacks/handoff/s/03-reviewer-diff.md")
  end,

  a_trailing_period_is_not_part_of_the_path = function()
    assert(report.path_in("written to /tmp/a-report.md.") == "/tmp/a-report.md")
  end,

  a_backticked_path_is_unwrapped = function()
    assert(report.path_in("see `/tmp/a-report.md`") == "/tmp/a-report.md")
  end,

  text_with_no_markdown_path_yields_nil = function()
    assert(report.path_in("no handoff path was given, receipt inline") == nil)
  end,

  the_last_path_wins = function()
    -- The summary may cite a source file; the handoff path comes after it.
    assert(report.path_in("read plans/01-foo.md; report at /tmp/out.md") == "/tmp/out.md")
  end,

  -- The two false positives the live gate caught on its first day, both at `PostToolUse`, which
  -- is handed an arbitrary `tool_input.file_path` rather than a `.md` candidate.

  a_non_markdown_file_in_the_temp_root_is_not_a_report = function()
    -- Measured: a commit-message `.txt` under the session scratchpad was validated as a handoff
    -- report and its violations attached to the write. The fix round had replaced the `%.md$`
    -- filter with the root test instead of requiring both.
    assert(report.under_handoff_root("/tmp/msgs3/9.txt", nil) == false)
    assert(report.under_handoff_root("/private/tmp/claude-501/s/scratchpad/m/9.txt", nil) == false)
  end,

  a_nested_markdown_file_in_the_temp_root_is_not_a_report = function()
    -- A doc page curled into the session scratchpad is Markdown and sits under /tmp, but is not
    -- a report. The exception tier is a DIRECT child of the temp root; the `init`-refused tier
    -- carries a `handoff/` segment. Neither admits an arbitrary nested path.
    assert(report.under_handoff_root("/tmp/claude-501/sess/scratchpad/hooks.md", nil) == false)
  end,

  the_init_refused_fallback_tier_is_still_a_report = function()
    -- `<session-scratch>/handoff/<NN>-<agent>-<slug>.md` — nested, so it qualifies on the
    -- segment rather than on being a direct child.
    assert(report.under_handoff_root(
      "/tmp/claude-501/sess/scratchpad/handoff/03-reviewer-diff.md", nil) == true)
  end,

  -- `under_handoff_root` — defect A/B/C's fix. A file qualifies only when it resolves (against
  -- `cwd`, if relative) under the session tree's `HANDOFF_REL` segment or under the temp root.

  a_session_tree_absolute_path_is_under_the_root = function()
    assert(report.under_handoff_root(
      "/repo/.airsstack/cc/plugins/claudestacks/handoff/s/01-coder-x.md", nil) == true)
  end,

  an_ordinary_project_file_is_not_under_the_root = function()
    -- Defect B: a plan file, a spec, CLAUDE.md — none of these sits under a handoff root, so
    -- the PostToolUse leg must leave them alone rather than validating them as reports.
    assert(report.under_handoff_root("/repo/CLAUDE.md", nil) == false)
    assert(report.under_handoff_root(
      "/repo/.claudestacks/sdlc/chain/plans/01-foo.md", nil) == false)
    assert(report.under_handoff_root("/repo/docs/spec.md", nil) == false)
  end,

  an_exception_tier_temp_path_is_under_the_root = function()
    -- A literal `/tmp` path rather than `fs.tempdir()`: this suite's own test grant
    -- (`cargo make plugins-test`) carries no `--allow-env TMPDIR`, so `fs.tempdir()`'s real
    -- location is unreadable to `under_handoff_root` here, and that denial is exactly what the
    -- function's `pcall` around `env.get` must survive — this fixture exercises the literal
    -- `/tmp` fallback that denial falls through to, which the end-to-end launcher runs (granted
    -- `TMPDIR`) exercise for the dynamic case.
    assert(report.under_handoff_root("/tmp/journal-curator-review.md", nil) == true)
  end,

  a_relative_session_path_resolves_against_cwd_and_qualifies = function()
    local relative = ".airsstack/cc/plugins/claudestacks/handoff/s/03-reviewer-diff.md"
    assert(report.under_handoff_root(relative, "/repo") == true)
  end,

  a_relative_path_with_no_cwd_does_not_qualify = function()
    -- There is nothing to resolve it against; guessing the process's own working directory is
    -- the bug being fixed (defect C), not a fallback to keep.
    local relative = ".airsstack/cc/plugins/claudestacks/handoff/s/03-reviewer-diff.md"
    assert(report.under_handoff_root(relative, nil) == false)
  end,

  non_string_or_empty_input_is_false_not_an_error = function()
    assert(report.under_handoff_root(nil, "/repo") == false)
    assert(report.under_handoff_root(42, "/repo") == false)
    assert(report.under_handoff_root("", "/repo") == false)
  end,

  -- `path_in_root` — the root-aware replacement for the bare last-`.md` rule.

  a_trailing_citation_does_not_become_the_path = function()
    -- Defect A, bare form: a conforming hand-back that correctly states its handoff path and
    -- then cites `file:line` evidence, as CLAUDE.md's "Never assert what you have not checked"
    -- requires. The citation is not under any handoff root, so it must not override the real
    -- path.
    local real = "/repo/.airsstack/cc/plugins/claudestacks/handoff/s/01-coder-x.md"
    local text = "wrote the report at " .. real .. ". The decision table sits at hooks.md:1011"
    assert(report.path_in_root(text, nil) == real, tostring(report.path_in_root(text, nil)))
  end,

  a_trailing_doc_url_does_not_become_the_path = function()
    -- Defect A, URL form.
    local real = "/repo/.airsstack/cc/plugins/claudestacks/handoff/s/01-coder-x.md"
    local text = "wrote the report at " .. real
      .. ". See https://code.claude.com/docs/en/hooks.md for the table."
    assert(report.path_in_root(text, nil) == real, tostring(report.path_in_root(text, nil)))
  end,

  a_trailing_absolute_claude_md_reference_does_not_become_the_path = function()
    local real = "/repo/.airsstack/cc/plugins/claudestacks/handoff/s/01-coder-x.md"
    local text = "wrote the report at " .. real .. ". Per /repo/CLAUDE.md this is mandatory."
    assert(report.path_in_root(text, nil) == real, tostring(report.path_in_root(text, nil)))
  end,

  an_exception_tier_path_qualifies_through_path_in_root = function()
    -- A literal `/tmp` path, for the same reason as `an_exception_tier_temp_path_is_under_the_root`
    -- above: this suite's test grant carries no `--allow-env TMPDIR`.
    local file = "/tmp/journal-curator-review.md"
    assert(report.path_in_root("done. report at " .. file, nil) == file)
  end,

  an_ordinary_project_path_alone_yields_nil_through_path_in_root = function()
    -- Defect B via the matcher: a plan file is the only `.md` mentioned, and it is not under any
    -- handoff root, so there is no qualifying path at all.
    assert(report.path_in_root("see /repo/plans/01-foo.md for context", nil) == nil)
  end,

  no_qualifying_path_at_all_yields_nil = function()
    assert(report.path_in_root("no handoff path was given, receipt inline", nil) == nil)
  end,

  a_relative_path_resolves_against_the_supplied_cwd_through_path_in_root = function()
    local relative = ".airsstack/cc/plugins/claudestacks/handoff/s/03-reviewer-diff.md"
    assert(report.path_in_root("report at " .. relative, "/repo")
      == "/repo/" .. relative)
  end,

  a_relative_path_does_not_silently_collapse_two_different_cwds_to_one_file = function()
    -- Defect C: the matcher used to ignore `cwd` entirely, so the same relative text resolved to
    -- whatever the hook process's own working directory happened to be, wherever that was. The
    -- fix makes resolution depend on `cwd`: the same text against two different directories must
    -- name two different absolute files, not collapse to one.
    local relative = ".airsstack/cc/plugins/claudestacks/handoff/s/03-reviewer-diff.md"
    local text = "report at " .. relative
    local first = report.path_in_root(text, "/repo-a")
    local second = report.path_in_root(text, "/repo-b")
    assert(first == "/repo-a/" .. relative, tostring(first))
    assert(second == "/repo-b/" .. relative, tostring(second))
    assert(first ~= second, "two different cwds must not resolve to the same file")
  end,

  -- `file_from_payload` — the dispatch itself, exercised directly rather than only through the
  -- launcher.

  file_from_payload_reads_post_tool_use_from_file_path = function()
    local real = "/repo/.airsstack/cc/plugins/claudestacks/handoff/s/01-coder-x.md"
    local payload = {
      hook_event_name = "PostToolUse",
      tool_input = { file_path = real },
    }
    assert(report.file_from_payload(payload) == real)
  end,

  file_from_payload_ignores_a_post_tool_use_write_outside_any_handoff_root = function()
    -- Defect B at the dispatch level: an ordinary markdown write must not qualify.
    local payload = {
      hook_event_name = "PostToolUse",
      tool_input = { file_path = "/repo/.claudestacks/sdlc/chain/plans/01-foo.md" },
    }
    assert(report.file_from_payload(payload) == nil)
  end,

  file_from_payload_reads_pre_tool_use_from_the_handback_message = function()
    local real = "/repo/.airsstack/cc/plugins/claudestacks/handoff/s/01-coder-x.md"
    local payload = {
      hook_event_name = "PreToolUse",
      tool_input = { message = "report at " .. real .. ". See hooks.md:1011." },
    }
    assert(report.file_from_payload(payload) == real)
  end,

  file_from_payload_reads_subagent_stop_from_last_assistant_message = function()
    local real = "/repo/.airsstack/cc/plugins/claudestacks/handoff/s/01-coder-x.md"
    local payload = {
      hook_event_name = "SubagentStop",
      last_assistant_message = "report at " .. real,
    }
    assert(report.file_from_payload(payload) == real)
  end,

  file_from_payload_resolves_a_relative_path_against_payload_cwd = function()
    local relative = ".airsstack/cc/plugins/claudestacks/handoff/s/03-reviewer-diff.md"
    local payload = {
      hook_event_name = "SubagentStop",
      last_assistant_message = "report at " .. relative,
      cwd = "/repo",
    }
    assert(report.file_from_payload(payload) == "/repo/" .. relative)
  end,

  file_from_payload_is_nil_on_a_missing_tool_input = function()
    local payload = { hook_event_name = "PostToolUse" }
    assert(report.file_from_payload(payload) == nil)
  end,

  file_from_payload_is_nil_on_a_non_string_message = function()
    local payload = {
      hook_event_name = "PreToolUse",
      tool_input = { message = 42 },
    }
    assert(report.file_from_payload(payload) == nil)
  end,

  file_from_payload_is_nil_on_an_absent_last_assistant_message = function()
    local payload = { hook_event_name = "SubagentStop" }
    assert(report.file_from_payload(payload) == nil)
  end,

  file_from_payload_is_nil_on_an_unknown_event = function()
    local real = "/repo/.airsstack/cc/plugins/claudestacks/handoff/s/01-coder-x.md"
    local payload = {
      hook_event_name = "SomeOtherEvent",
      tool_input = { file_path = real },
      last_assistant_message = real,
    }
    assert(report.file_from_payload(payload) == nil)
  end,

  file_from_payload_is_nil_on_a_non_table_payload = function()
    assert(report.file_from_payload(nil) == nil)
    assert(report.file_from_payload("not a table") == nil)
  end,
}
