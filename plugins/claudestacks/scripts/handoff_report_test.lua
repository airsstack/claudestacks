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
}
