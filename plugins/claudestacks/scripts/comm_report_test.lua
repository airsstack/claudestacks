-- Tests for lib/comm_report — the communication protocol's report additions.
--
--   cargo make plugins-test

local comm = require("lib.comm_report")
local fs = airsstack.fs
local path = airsstack.path
local handoff = require("lib.handoff_report")

local function lines_of(text)
  local out = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    out[#out + 1] = line
  end
  return out
end

local VALID = table.concat({
  "---",
  "agent: reviewer",
  "task: review x",
  "protocol: discuss/1",
  "---",
  "<summary>",
  "Two findings; one blocks.",
  "</summary>",
  "<topics>",
  "1. classifier false triggers",
  "2. machine-wide flag",
  "</topics>",
  "<detail>",
  "## 1. classifier false triggers",
  "body",
  "## 2. machine-wide flag",
  "body",
  "</detail>",
}, "\n")

local function ids(violations)
  local out = {}
  for _, v in ipairs(violations) do
    out[#out + 1] = v.id
  end
  return table.concat(out, ",")
end

local function with(old, new)
  local text = VALID:gsub(old, new, 1)
  return lines_of(text)
end

return {
  topics_are_parsed_in_order_with_trailing_space_trimmed = function()
    local topics, malformed = comm.topics(lines_of("<topics>\n1. first \n\n2. second\n</topics>"), 1)
    assert(#topics == 2 and #malformed == 0)
    assert(topics[1].n == 1 and topics[1].title == "first")
    assert(topics[2].n == 2 and topics[2].title == "second")
  end,

  a_line_that_is_not_n_dot_title_is_malformed = function()
    local topics, malformed = comm.topics(lines_of("<topics>\n- first\n1. ok\n</topics>"), 1)
    assert(#topics == 1 and #malformed == 1 and malformed[1] == "- first")
  end,

  no_topics_block_means_nil = function()
    assert(comm.topics(lines_of("<summary>\nx\n</summary>"), 1) == nil)
  end,

  a_conforming_report_has_no_violations = function()
    assert(ids(comm.check_lines(lines_of(VALID))) == "")
  end,

  a_report_without_protocol_is_not_ours = function()
    assert(ids(comm.check_lines(with("protocol: discuss/1\n", ""))) == "")
  end,

  add_requires_protocol = function()
    local lines = with("protocol: discuss/1\n", "")
    assert(ids(comm.check_lines(lines, { require_protocol = true })) == "protocol-missing")
  end,

  an_unknown_protocol_version_is_named = function()
    assert(ids(comm.check_lines(with("discuss/1", "discuss/2"))) == "protocol-unknown")
  end,

  a_summary_over_six_lines_is_too_long = function()
    local lines = with("Two findings; one blocks.", "a\nb\nc\nd\ne\nf\ng")
    assert(ids(comm.check_lines(lines)) == "summary-too-long")
  end,

  detail_without_topics_is_missing_topics = function()
    local lines = with("<topics>\n1%. classifier false triggers\n2%. machine%-wide flag\n</topics>\n", "")
    assert(ids(comm.check_lines(lines)) == "topics-missing")
  end,

  topics_without_detail_are_named = function()
    local lines = with("<detail>.*</detail>", "")
    assert(ids(comm.check_lines(lines)) == "topics-without-detail")
  end,

  a_malformed_topic_line_is_named = function()
    assert(ids(comm.check_lines(with("2%. machine%-wide flag\n</topics>", "two. machine-wide flag\n</topics>")))
      == "topics-malformed")
  end,

  out_of_order_numbers_are_named = function()
    local lines = with("2%. machine%-wide flag\n</topics>", "3. machine-wide flag\n</topics>")
    assert(ids(comm.check_lines(lines)):find("topics-numbering", 1, true))
  end,

  a_topic_without_its_heading_is_named = function()
    assert(ids(comm.check_lines(with("## 2%. machine%-wide flag", "## 2. other title")))
      == "topic-heading-missing")
  end,

  a_non_ascii_digit_topic_is_malformed_not_a_crash = function()
    local lines = with("2%. machine%-wide flag\n</topics>", "１. machine-wide flag\n</topics>")
    assert(ids(comm.check_lines(lines)) == "topics-malformed")
  end,

  a_detail_heading_with_trailing_space_still_matches = function()
    local lines = with("## 1%. classifier false triggers", "## 1. classifier false triggers ")
    assert(ids(comm.check_lines(lines)) == "")
  end,

  the_conforming_fixture_passes_both_validators_from_disk = function()
    local file = path.join(fs.tempdir(), "01-reviewer-x.md")
    fs.write(file, VALID .. "\n")
    assert(#handoff.check(file) == 0, "base validator rejected a communication report")
    assert(#comm.check(file) == 0)
  end,

  post_tool_use_emits_a_block_decision = function()
    local out = comm.hook_output("PostToolUse", { { id = "topics-missing", line = "x" } })
    assert(out.kind == "emit" and out.value.decision == "block")
    assert(out.value.reason:find("topics-missing: x", 1, true))
  end,

  the_gate_events_write_to_stdout = function()
    for _, event in ipairs({ "PreToolUse", "SubagentStop" }) do
      local out = comm.hook_output(event, { { id = "topics-missing", line = "x" } })
      assert(out.kind == "stdout" and out.value:find("topics-missing: x", 1, true), event)
    end
  end,

  no_violations_means_no_output = function()
    assert(comm.hook_output("PreToolUse", {}) == nil)
  end,
}
