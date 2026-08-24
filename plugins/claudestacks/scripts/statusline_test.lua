-- Tests for lib/statusline — the pure formatting half of the Claude Code status line.
--
--   cargo make plugins-test

local sl = require("lib.statusline")

return {
  a_path_under_home_is_abbreviated = function()
    assert(sl.abbreviate_path("/Users/x/Projects/app", "/Users/x") == "~/Projects/app")
  end,

  a_path_outside_home_is_verbatim = function()
    assert(sl.abbreviate_path("/tmp", "/Users/x") == "/tmp")
  end,

  home_itself_is_a_bare_tilde = function()
    assert(sl.abbreviate_path("/Users/x", "/Users/x") == "~")
  end,

  a_sibling_sharing_the_home_prefix_is_not_abbreviated = function()
    -- "/Users/xfoo" starts with "/Users/x" as a *string* but is not under it as a *path*.
    assert(sl.abbreviate_path("/Users/xfoo", "/Users/x") == "/Users/xfoo")
  end,

  an_empty_cwd_yields_an_empty_string = function()
    assert(sl.abbreviate_path("", "/Users/x") == "")
  end,

  tokens_below_a_thousand_are_plain_integers = function()
    assert(sl.format_tokens(0) == "0", sl.format_tokens(0))
    assert(sl.format_tokens(999) == "999", sl.format_tokens(999))
  end,

  tokens_at_a_thousand_switch_to_k = function()
    assert(sl.format_tokens(1000) == "1.0k", sl.format_tokens(1000))
    assert(sl.format_tokens(46700) == "46.7k", sl.format_tokens(46700))
    assert(sl.format_tokens(999999) == "1000.0k", sl.format_tokens(999999))
  end,

  tokens_at_a_million_switch_to_m = function()
    assert(sl.format_tokens(1000000) == "1.0M", sl.format_tokens(1000000))
  end,

  a_nil_token_count_is_zero = function()
    assert(sl.format_tokens(nil) == "0", sl.format_tokens(nil))
  end,

  a_fractional_token_count_below_a_thousand_truncates = function()
    -- The bash reference's awk %d truncates rather than raising; the Lua port must match.
    assert(sl.format_tokens(999.5) == "999", sl.format_tokens(999.5))
  end,

  the_bar_is_empty_at_zero_and_full_at_a_hundred = function()
    assert(sl.bar(0) == string.rep("▱", 10), sl.bar(0))
    assert(sl.bar(100) == string.rep("▰", 10), sl.bar(100))
  end,

  the_bar_rounds_to_the_nearest_block = function()
    -- 5% of 10 blocks is 0.5, which rounds up to 1.
    assert(sl.bar(5) == "▰" .. string.rep("▱", 9), sl.bar(5))
    assert(sl.bar(85) == string.rep("▰", 9) .. "▱", sl.bar(85))
  end,

  the_bar_rounds_down_below_the_half_block = function()
    -- 4% of 10 blocks is 0.4, which rounds *down* to 0. A `math.ceil` implementation would
    -- round this up to 1 and still pass every other case in this file — this is the one
    -- point in the table where round-half-up and ceiling disagree.
    assert(sl.bar(4) == string.rep("▱", 10), sl.bar(4))
  end,

  the_bar_clamps_out_of_range_input = function()
    assert(sl.bar(-10) == string.rep("▱", 10), sl.bar(-10))
    assert(sl.bar(250) == string.rep("▰", 10), sl.bar(250))
  end,

  the_colour_constants_match_the_bash_reference_literally = function()
    -- Pinned against ~/.claude/statusline-command.sh:21-27 so a mutated escape sequence
    -- cannot hide behind assertions that only compare the module against itself.
    assert(sl.CYAN == "\27[2;36m", sl.CYAN)
    assert(sl.YELLOW == "\27[2;33m", sl.YELLOW)
    assert(sl.GREEN == "\27[2;32m", sl.GREEN)
    assert(sl.RED == "\27[2;31m", sl.RED)
    assert(sl.DIM == "\27[2m", sl.DIM)
    assert(sl.RESET == "\27[0m", sl.RESET)
  end,

  the_colour_band_changes_at_fifty_and_eighty = function()
    assert(sl.band(49) == sl.GREEN)
    assert(sl.band(50) == sl.YELLOW)
    assert(sl.band(79) == sl.YELLOW)
    assert(sl.band(80) == sl.RED)
  end,

  joining_puts_one_separator_between_segments = function()
    local sep = " " .. sl.DIM .. "·" .. sl.RESET .. " "
    assert(sl.join({ "a", "b", "c" }) == "a" .. sep .. "b" .. sep .. "c", sl.join({ "a", "b", "c" }))
  end,

  joining_one_segment_adds_no_separator = function()
    assert(sl.join({ "only" }) == "only", sl.join({ "only" }))
  end,

  joining_nothing_yields_an_empty_string = function()
    assert(sl.join({}) == "", sl.join({}))
  end,

  joining_never_leaves_a_dangling_separator = function()
    -- The caller omits absent segments rather than passing empty strings; this pins that a
    -- two-segment join has exactly one separator and no trailing whitespace.
    local out = sl.join({ "x", "y" })
    assert(not out:match("%s$"), out)
    local _, count = out:gsub("·", "")
    assert(count == 1, out)
  end,

  line_one_is_the_bare_path_outside_a_repo = function()
    local lines = sl.render({ workspace = { current_dir = "/tmp" } }, {}, "/Users/x")
    assert(lines[1] == sl.YELLOW .. "/tmp" .. sl.RESET, lines[1])
    -- No dangling separator and no trailing space is the whole point of this case.
    assert(not lines[1]:match("|"), lines[1])
    assert(not lines[1]:match(" $"), lines[1])
  end,

  line_one_appends_the_branch_inside_a_repo = function()
    local lines = sl.render({ workspace = { current_dir = "/Users/x/app" } },
      { branch = "main" }, "/Users/x")
    local want = sl.YELLOW .. "~/app" .. sl.RESET
      .. " " .. sl.DIM .. "|" .. sl.RESET .. " " .. sl.CYAN .. "main" .. sl.RESET
    assert(lines[1] == want, lines[1])
  end,

  line_one_appends_ahead_behind_when_an_upstream_exists = function()
    local lines = sl.render({ workspace = { current_dir = "/Users/x/app" } },
      { branch = "main", ahead = 2, behind = 1 }, "/Users/x")
    -- Full equality, not a tail match: pins the dim "·" separator ahead of the counts. A
    -- mutant that drops `.. " " .. sl.DIM .. "·" .. sl.RESET` from this branch still ends in
    -- "↑2 ↓1" and would slip past a `:match("↑2 ↓1$")` check untouched.
    local want = sl.YELLOW .. "~/app" .. sl.RESET
      .. " " .. sl.DIM .. "|" .. sl.RESET .. " " .. sl.CYAN .. "main" .. sl.RESET
      .. " " .. sl.DIM .. "·" .. sl.RESET .. " " .. "↑2 ↓1"
    assert(lines[1] == want, lines[1])
  end,

  line_one_omits_ahead_behind_without_an_upstream = function()
    local lines = sl.render({ workspace = { current_dir = "/Users/x/app" } },
      { branch = "main" }, "/Users/x")
    assert(not lines[1]:match("↑"), lines[1])
  end,

  line_one_falls_back_to_the_top_level_cwd_field = function()
    local lines = sl.render({ cwd = "/tmp" }, {}, "/Users/x")
    assert(lines[1] == sl.YELLOW .. "/tmp" .. sl.RESET, lines[1])
  end,

  line_two_carries_the_meter_tokens_model_and_limits = function()
    local lines = sl.render({
      workspace = { current_dir = "/tmp" },
      model = { display_name = "Opus 5" },
      effort = { level = "high" },
      context_window = {
        used_percentage = 5, total_input_tokens = 46700,
        total_output_tokens = 457, context_window_size = 1000000,
      },
      rate_limits = {
        five_hour = { used_percentage = 3 },
        seven_day = { used_percentage = 0 },
      },
    }, {}, "/Users/x")
    -- Full equality over the whole line, built from the same primitives sl.render is pinned
    -- against elsewhere in this file (band, bar, format_tokens, join). Five independent
    -- mutations — a dropped join separator, a reversed segment order, or a segment stripped
    -- of its band/DIM/RESET wrapper — all land on this one assertion; four separate
    -- `:match()` calls, one per segment, cannot see any of them because none looks at what
    -- sits *between* segments.
    local meter = sl.band(5) .. sl.bar(5) .. sl.RESET .. "  5%  "
      .. sl.DIM .. sl.format_tokens(46700) .. "/" .. sl.format_tokens(1000000) .. sl.RESET
    local out = sl.DIM .. "out " .. sl.format_tokens(457) .. sl.RESET
    local model = "Opus 5 (high)"
    local limits = sl.DIM .. "5h:3% 7d:0%" .. sl.RESET
    local want = sl.join({ meter, out, model, limits })
    assert(lines[2] == want, lines[2])
  end,

  line_two_degrades_to_the_model_alone = function()
    local lines = sl.render({ model = { display_name = "Haiku 4.5" } }, {}, "/Users/x")
    assert(lines[2] == "Haiku 4.5", lines[2])
  end,

  line_two_is_absent_when_nothing_is_known = function()
    local lines = sl.render({ workspace = { current_dir = "/tmp" } }, {}, "/Users/x")
    assert(lines[2] == nil, tostring(lines[2]))
  end,

  line_two_omits_zero_output_tokens = function()
    local lines = sl.render({
      model = { display_name = "Opus 5" },
      context_window = { total_output_tokens = 0 },
    }, {}, "/Users/x")
    -- Full equality rather than a substring-absence check: pins that the model segment
    -- stands alone with no dangling separator, not just that the literal text "out" happens
    -- not to appear.
    assert(lines[2] == "Opus 5", lines[2])
  end,

  the_model_stands_alone_without_an_effort_level = function()
    local lines = sl.render({ model = { display_name = "Opus 5" } }, {}, "/Users/x")
    assert(lines[2] == "Opus 5", lines[2])
  end,

  the_context_percentage_truncates_but_rate_limits_round = function()
    -- The bash reference is deliberately inconsistent here (%d vs %.0f) and the port keeps it.
    local lines = sl.render({
      context_window = { used_percentage = 5.7, total_input_tokens = 1, context_window_size = 2 },
      rate_limits = { five_hour = { used_percentage = 5.7 } },
    }, {}, "/Users/x")
    -- Full equality: pins the truncated "5%" against the rounded "6%" in the same string,
    -- plus the join separator between the two segments and the absent out/model segments.
    local meter = sl.band(5) .. sl.bar(5) .. sl.RESET .. "  5%  "
      .. sl.DIM .. sl.format_tokens(1) .. "/" .. sl.format_tokens(2) .. sl.RESET
    local limits = sl.DIM .. "5h:6%" .. sl.RESET
    local want = sl.join({ meter, limits })
    assert(lines[2] == want, lines[2])
  end,

  ahead_and_behind_parse_from_tab_separated_counts = function()
    -- `git rev-list --left-right --count @{upstream}...HEAD` emits "behind<TAB>ahead".
    local ahead, behind = sl.parse_ahead_behind("0\t0\n")
    assert(ahead == 0 and behind == 0, tostring(ahead) .. "/" .. tostring(behind))
    local a2, b2 = sl.parse_ahead_behind("1\t2\n")
    assert(b2 == 1 and a2 == 2, tostring(a2) .. "/" .. tostring(b2))
  end,

  unparseable_counts_yield_nil = function()
    assert(sl.parse_ahead_behind("") == nil)
    assert(sl.parse_ahead_behind("fatal: no upstream configured\n") == nil)
  end,
}
