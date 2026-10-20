-- Tests for lib/adr — scanning `adrs/`, reading number lists, resolving an
-- ADR by number, checking the seal, supersession and `supersedes` loops,
-- reading disproofs from chains, and deriving each ADR's row and the heading.
--
--   airsl test --policy confined --allow-read / \
--     --allow-write "${TMPDIR:-/tmp}" --allow-exec git \
--     plugins/claudestacks-sdlc/scripts

local adr = require("lib.adr")
local fingerprint = require("lib.fingerprint")
local status = require("lib.status")

local fs = airsstack.fs
local path = airsstack.path

-- Builds a chain root in a temp dir; returns its path.
local function root()
  local dir = path.join(fs.tempdir(), "sdlc")
  fs.mkdir(dir)
  return dir
end

-- Creates `adrs/` under a chain root; returns its path.
local function adrs_dir(dir)
  local adir = path.join(dir, "adrs")
  fs.mkdir(adir)
  return adir
end

-- Writes one ADR file with the given status.
local function write_adr(adir, name, status_value)
  fs.write(path.join(adir, name),
    "---\nstatus: " .. status_value .. "\ncreated: 2026-10-20\n---\n# body\n")
end

local function scan(dir)
  return adr.scan(dir, status.read_artifact)
end

-- The seal an ADR whose body is the one line `body` carries when approved.
local function seal_of(body)
  return fingerprint.of_text("---\n---\n" .. body .. "\n")
end

-- Writes one ADR that may carry a seal. `o.status` is required; `o.body`
-- defaults to `# body`; `o.supersedes` is the inline list text, e.g.
-- "[0003]"; `o.sealed` is the `sealed` value — nil seals the body, false
-- writes no `sealed` key, a string is written as given.
local function write_sealed(adir, name, o)
  local body = o.body or "# body"
  local seal = o.sealed
  if seal == nil then
    seal = seal_of(body)
  end
  local text = "---\nstatus: " .. o.status .. "\ncreated: 2026-10-20\n"
  if o.supersedes then
    text = text .. "supersedes: " .. o.supersedes .. "\n"
  end
  if seal then
    text = text .. "sealed: " .. seal .. "\n"
  end
  fs.write(path.join(adir, name), text .. "---\n" .. body .. "\n")
end

-- Asserts the ADR with number `num` is invalid with exactly `want`, and so
-- has no status.
local function expect_invalid(adrs, num, want)
  local item = adr.resolve(adrs, num)
  assert(item, "no ADR " .. num)
  assert(item.invalid == want, "ADR " .. num .. ": want " .. want .. ", got " .. tostring(item.invalid))
  assert(item.status == nil, "an invalid ADR has no status")
end

-- Asserts the ADR with number `num` is valid.
local function expect_valid(adrs, num)
  local item = adr.resolve(adrs, num)
  assert(item, "no ADR " .. num)
  assert(item.invalid == nil, "ADR " .. num .. " is invalid: " .. tostring(item.invalid))
end

-- Asserts a list holds exactly the wanted strings, in order.
local function expect_list(want, got)
  assert(#got == #want, "want " .. table.concat(want, ",") .. ", got " .. table.concat(got, ","))
  for i, value in ipairs(want) do
    assert(got[i] == value, "item " .. i .. ": want " .. value .. ", got " .. tostring(got[i]))
  end
end

-- Writes one chain under a chain root: an intent with the given status and
-- one plan file per entry of `plans`, each { num, status, disproves } where
-- `disproves` is the inline `disproves-adr` list text, if any. Returns the
-- chain's directory.
local function write_chain(dir, name, intent_status, plans)
  local cdir = path.join(dir, name)
  fs.mkdir(cdir)
  fs.write(path.join(cdir, "intent.md"),
    "---\nstatus: " .. intent_status .. "\ncreated: 2026-10-20\n---\n# intent\n")
  fs.mkdir(path.join(cdir, "plans"))
  for _, plan in ipairs(plans) do
    local text = "---\nstatus: " .. plan.status .. "\ncreated: 2026-10-20\n"
    if plan.disproves then
      text = text .. "disproves-adr: " .. plan.disproves .. "\n"
    end
    fs.write(path.join(cdir, "plans", plan.num .. "-x.md"), text .. "---\n# plan\n")
  end
  return cdir
end

-- Scans the ADRs of a root and marks the disproofs of its chains.
local function scan_marked(dir)
  local adrs = scan(dir)
  adr.mark_disproofs(adrs, status.scan(dir))
  return adrs
end

-- Asserts the row of the ADR numbered `num` reads exactly `state` and `next_step`.
local function expect_row(adrs, num, state, next_step)
  local got_state, got_next = adr.row(adr.resolve(adrs, num))
  assert(got_state == state, "ADR " .. num .. ": want state " .. state .. ", got " .. tostring(got_state))
  assert(got_next == next_step, "ADR " .. num .. ": want next " .. next_step .. ", got " .. tostring(got_next))
end

return {
  a_root_without_an_adrs_directory_scans_to_none = function()
    assert(#scan(root()) == 0)
  end,

  only_four_digit_markdown_files_are_adrs = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_adr(adir, "0001-a.md", "draft")
    fs.write(path.join(adir, "README.md"), "not an adr\n")
    write_adr(adir, "001-b.md", "draft")
    write_adr(adir, "0002-c.txt", "draft")
    fs.mkdir(path.join(adir, "0003-d.md"))
    fs.mkdir(path.join(adir, "notes"))
    local found = scan(dir)
    assert(#found == 1, "want 1 ADR, got " .. #found)
    assert(found[1].num == "0001" and found[1].file == "0001-a.md", tostring(found[1].file))
  end,

  adrs_scan_in_number_order = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_adr(adir, "0010-x.md", "draft")
    write_adr(adir, "0002-y.md", "draft")
    write_adr(adir, "0001-z.md", "draft")
    local nums = {}
    for _, item in ipairs(scan(dir)) do
      nums[#nums + 1] = item.num
    end
    expect_list({ "0001", "0002", "0010" }, nums)
  end,

  a_scanned_adr_carries_its_fields_text_and_status = function()
    local dir = root()
    write_adr(adrs_dir(dir), "0001-a.md", "draft")
    local item = scan(dir)[1]
    assert(item.status == "draft" and item.invalid == nil, tostring(item.invalid))
    assert(item.fields.created == "2026-10-20", tostring(item.fields.created))
    assert(item.text:find("# body", 1, true), "the file's text must be kept")
  end,

  an_inline_number_list_normalises_to_four_digits = function()
    expect_list({ "0003", "0007", "0012" }, adr.numbers("[3, 0007, 12]"))
  end,

  a_block_number_list_normalises_to_four_digits = function()
    expect_list({ "0003", "0011" }, adr.numbers({ "3", "0011" }))
  end,

  an_absent_or_empty_number_list_reads_as_none = function()
    expect_list({}, adr.numbers(nil))
    expect_list({}, adr.numbers({}))
    expect_list({}, adr.numbers("[]"))
  end,

  a_huge_number_normalizes_without_error = function()
    expect_list({ "99999999999999999999" }, adr.numbers("[99999999999999999999]"))
    expect_list({ "99999999999999999999", "0003" }, adr.numbers({ "99999999999999999999", "3" }))
    expect_list({ "0000" }, adr.numbers("[00000000000000000000]"))
  end,

  a_non_numeric_list_item_passes_through = function()
    expect_list({ "abc" }, adr.numbers({ "abc" }))
  end,

  a_block_list_parsed_from_a_file_reads_back = function()
    local fields = status.parse_frontmatter("---\nsupersedes:\n  - 3\n  - 0011\n---\n")
    expect_list({ "0003", "0011" }, adr.numbers(fields.supersedes))
  end,

  an_unparseable_adr_is_invalid_with_its_reason = function()
    local dir = root()
    local adir = adrs_dir(dir)
    fs.write(path.join(adir, "0001-a.md"), "# no frontmatter\n")
    fs.write(path.join(adir, "0002-b.md"), "---\ncreated: 2026-10-20\n---\n# body\n")
    local found = scan(dir)
    assert(found[1].invalid == "0001-a.md: missing frontmatter", tostring(found[1].invalid))
    assert(found[2].invalid == "0002-b.md: missing status", tostring(found[2].invalid))
    assert(found[1].status == nil and found[2].status == nil, "an invalid ADR has no status")
  end,

  an_unknown_adr_status_is_invalid = function()
    local dir = root()
    write_adr(adrs_dir(dir), "0001-a.md", "accepted")
    local item = scan(dir)[1]
    assert(item.invalid == "0001-a.md: unknown status accepted", tostring(item.invalid))
    assert(item.status == nil, "an invalid ADR has no status")
  end,

  an_empty_status_reads_missing_status = function()
    local dir = root()
    fs.write(path.join(adrs_dir(dir), "0001-a.md"),
      "---\nstatus:\ncreated: 2026-10-20\n---\n# body\n")
    local item = scan(dir)[1]
    assert(item.invalid == "0001-a.md: missing status", tostring(item.invalid))
    assert(item.status == nil, "an invalid ADR has no status")
  end,

  two_adrs_sharing_a_number_are_both_invalid = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_adr(adir, "0004-a.md", "draft")
    write_adr(adir, "0004-b.md", "draft")
    local found = scan(dir)
    assert(found[1].invalid == "0004-a.md: duplicate number 0004", tostring(found[1].invalid))
    assert(found[2].invalid == "0004-b.md: duplicate number 0004", tostring(found[2].invalid))
    assert(found[1].status == nil and found[2].status == nil, "an invalid ADR has no status")
  end,

  an_unparseable_duplicate_keeps_its_first_reason = function()
    local dir = root()
    local adir = adrs_dir(dir)
    fs.write(path.join(adir, "0004-a.md"), "---\ncreated: 2026-10-20\n---\n# body\n")
    write_adr(adir, "0004-b.md", "draft")
    local found = scan(dir)
    assert(found[1].invalid == "0004-a.md: missing status", tostring(found[1].invalid))
    assert(found[2].invalid == "0004-b.md: duplicate number 0004", tostring(found[2].invalid))
  end,

  resolve_finds_one_adr_by_number = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_adr(adir, "0001-a.md", "draft")
    write_adr(adir, "0002-b.md", "draft")
    local found = adr.resolve(scan(dir), "0001")
    assert(found and found.file == "0001-a.md", tostring(found and found.file))
  end,

  resolve_reports_unknown_and_ambiguous = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_adr(adir, "0001-a.md", "draft")
    write_adr(adir, "0004-a.md", "draft")
    write_adr(adir, "0004-b.md", "draft")
    local adrs = scan(dir)
    local found, why = adr.resolve(adrs, "0009")
    assert(found == nil and why == "unknown", tostring(why))
    found, why = adr.resolve(adrs, "0004")
    assert(found == nil and why == "ambiguous", tostring(why))
  end,

  resolve_returns_a_single_invalid_adr = function()
    local dir = root()
    write_adr(adrs_dir(dir), "0005-x.md", "accepted")
    local found = adr.resolve(scan(dir), "0005")
    assert(found and found.file == "0005-x.md" and found.invalid ~= nil, tostring(found))
  end,

  a_sealed_status_without_sealed_is_invalid = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "approved", sealed = false })
    write_sealed(adir, "0002-b.md", { status = "superseded", sealed = false })
    write_sealed(adir, "0003-c.md", { status = "deprecated", sealed = false })
    write_sealed(adir, "0004-d.md", { status = "approved", sealed = "" })
    local found = scan(dir)
    expect_invalid(found, "0001", "0001-a.md: missing sealed")
    expect_invalid(found, "0002", "0002-b.md: missing sealed")
    expect_invalid(found, "0003", "0003-c.md: missing sealed")
    expect_invalid(found, "0004", "0004-d.md: missing sealed")
  end,

  a_draft_or_dropped_adr_ignores_sealed = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "draft", sealed = "000000000000" })
    write_sealed(adir, "0002-b.md", { status = "dropped", sealed = false })
    write_sealed(adir, "0003-c.md", { status = "draft", sealed = false, supersedes = "[0009]" })
    local found = scan(dir)
    expect_valid(found, "0001")
    expect_valid(found, "0002")
    expect_valid(found, "0003")
  end,

  an_approved_adr_matching_its_seal_is_valid = function()
    local dir = root()
    write_sealed(adrs_dir(dir), "0001-a.md", { status = "approved" })
    local item = scan(dir)[1]
    assert(item.invalid == nil and item.status == "approved", tostring(item.invalid))
  end,

  an_approved_adr_edited_after_approval_is_invalid = function()
    local dir = root()
    write_sealed(adrs_dir(dir), "0001-a.md",
      { status = "approved", body = "# edited", sealed = seal_of("# body") })
    expect_invalid(scan(dir), "0001", "0001-a.md: edited after approval")
  end,

  a_status_flip_never_breaks_the_seal = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "approved" })
    expect_valid(scan(dir), "0001")
    write_sealed(adir, "0001-a.md", { status = "deprecated" })
    local item = scan(dir)[1]
    assert(item.invalid == nil and item.status == "deprecated", tostring(item.invalid))
  end,

  a_sealed_adr_superseding_an_unknown_number_is_invalid = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0002-b.md", { status = "approved", supersedes = "[0009]" })
    expect_invalid(scan(dir), "0002", "0002-b.md: supersedes unknown 0009")
    write_sealed(adir, "0002-b.md", { status = "approved", supersedes = "[0009, 0008]" })
    expect_invalid(scan(dir), "0002", "0002-b.md: supersedes unknown 0008")
  end,

  the_lowest_unknown_number_compares_numerically = function()
    local dir = root()
    write_sealed(adrs_dir(dir), "0002-b.md", { status = "approved", supersedes = "[10000, 9999]" })
    expect_invalid(scan(dir), "0002", "0002-b.md: supersedes unknown 9999")
  end,

  the_lowest_unknown_number_is_named_whatever_the_written_order = function()
    local dir = root()
    write_sealed(adrs_dir(dir), "0002-b.md", { status = "approved", supersedes = "[0008, 0009]" })
    expect_invalid(scan(dir), "0002", "0002-b.md: supersedes unknown 0008")
  end,

  lower_orders_digit_strings_by_length_then_text = function()
    assert(adr.lower("9999", "10000"))
    assert(not adr.lower("10000", "9999"))
    assert(adr.lower("0008", "0009"))
    assert(not adr.lower("0009", "0008"))
    assert(not adr.lower("0008", "0008"))
  end,

  lower_puts_a_digit_string_before_any_other_token = function()
    assert(adr.lower("0008", "abc"))
    assert(not adr.lower("abc", "0008"))
    assert(adr.lower("abc", "abd"))
  end,

  a_digit_number_is_lower_than_a_non_numeric_token = function()
    local dir = root()
    fs.write(path.join(adrs_dir(dir), "0002-b.md"),
      "---\nstatus: approved\ncreated: 2026-10-20\nsupersedes:\n  - abc\n  - 0008\n"
        .. "sealed: " .. seal_of("# body") .. "\n---\n# body\n")
    expect_invalid(scan(dir), "0002", "0002-b.md: supersedes unknown 0008")
  end,

  a_listed_approved_adr_reads_superseded_but_still_approved = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "approved" })
    write_sealed(adir, "0002-b.md", { status = "approved", supersedes = "[0001]" })
    local found = scan(dir)
    expect_invalid(found, "0001", "0001-a.md: superseded by 0002 but still approved")
    expect_valid(found, "0002")
  end,

  a_listed_draft_dropped_or_deprecated_adr_names_its_status = function()
    for _, state in ipairs({ "draft", "dropped", "deprecated" }) do
      local dir = root()
      local adir = adrs_dir(dir)
      write_sealed(adir, "0001-a.md", { status = state })
      write_sealed(adir, "0002-b.md", { status = "approved", supersedes = "[0001]" })
      local found = scan(dir)
      expect_invalid(found, "0001", "0001-a.md: superseded by 0002 but still " .. state)
      expect_valid(found, "0002")
    end
  end,

  the_lowest_lister_is_named = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "approved" })
    write_sealed(adir, "0003-c.md", { status = "approved", supersedes = "[0001]" })
    write_sealed(adir, "0005-e.md", { status = "approved", supersedes = "[0001]" })
    expect_invalid(scan(dir), "0001", "0001-a.md: superseded by 0003 but still approved")
  end,

  a_superseded_adr_nothing_lists_is_invalid = function()
    local dir = root()
    write_sealed(adrs_dir(dir), "0001-a.md", { status = "superseded" })
    expect_invalid(scan(dir), "0001", "0001-a.md: superseded by nothing")
  end,

  a_draft_listing_an_adr_supersedes_nothing = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "approved" })
    write_sealed(adir, "0002-b.md", { status = "draft", sealed = false, supersedes = "[0001]" })
    local found = scan(dir)
    expect_valid(found, "0001")
    expect_valid(found, "0002")
    assert(adr.successor(found, "0001") == nil, "a draft is not a lister")
  end,

  an_invalid_lister_supersedes_nothing = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "superseded" })
    write_sealed(adir, "0002-b.md", {
      status = "approved", supersedes = "[0001]", body = "# edited", sealed = seal_of("# body"),
    })
    local found = scan(dir)
    expect_invalid(found, "0001", "0001-a.md: superseded by nothing")
    expect_invalid(found, "0002", "0002-b.md: edited after approval")
  end,

  an_interrupted_supersede_invalidates_down_the_line = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0003-c.md", { status = "superseded" })
    write_sealed(adir, "0009-i.md", { status = "approved", supersedes = "[0003]" })
    write_sealed(adir, "0012-l.md", { status = "approved", supersedes = "[0009]" })
    local found = scan(dir)
    expect_invalid(found, "0009", "0009-i.md: superseded by 0012 but still approved")
    expect_invalid(found, "0003", "0003-c.md: superseded by nothing")
    expect_valid(found, "0012")
    assert(adr.successor(found, "0003") == nil, "an invalid lister is no successor")
  end,

  a_supersedes_cycle_ends = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "superseded", supersedes = "[0002]" })
    write_sealed(adir, "0002-b.md", { status = "superseded", supersedes = "[0001]" })
    local found = scan(dir)
    expect_invalid(found, "0001", "0001-a.md: supersedes cycle")
    expect_invalid(found, "0002", "0002-b.md: supersedes cycle")
  end,

  a_loop_of_approved_adrs_is_a_cycle_on_both = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "approved", supersedes = "[0002]" })
    write_sealed(adir, "0002-b.md", { status = "approved", supersedes = "[0001]" })
    local found = scan(dir)
    expect_invalid(found, "0001", "0001-a.md: supersedes cycle")
    expect_invalid(found, "0002", "0002-b.md: supersedes cycle")
  end,

  a_loop_of_one_superseded_and_one_approved_adr_is_a_cycle_on_both = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "superseded", supersedes = "[0002]" })
    write_sealed(adir, "0002-b.md", { status = "approved", supersedes = "[0001]" })
    local found = scan(dir)
    expect_invalid(found, "0001", "0001-a.md: supersedes cycle")
    expect_invalid(found, "0002", "0002-b.md: supersedes cycle")
  end,

  a_loop_through_three_adrs_is_a_cycle_on_each = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "approved", supersedes = "[0003]" })
    write_sealed(adir, "0002-b.md", { status = "approved", supersedes = "[0001]" })
    write_sealed(adir, "0003-c.md", { status = "superseded", supersedes = "[0002]" })
    local found = scan(dir)
    for _, num in ipairs({ "0001", "0002", "0003" }) do
      local item = adr.resolve(found, num)
      expect_invalid(found, num, item.file .. ": supersedes cycle")
    end
  end,

  a_loop_closed_through_a_draft_adr_is_not_a_cycle = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "draft", sealed = false, supersedes = "[0002]" })
    write_sealed(adir, "0002-b.md", { status = "approved", supersedes = "[0001]" })
    local found = scan(dir)
    expect_invalid(found, "0001", "0001-a.md: superseded by 0002 but still draft")
    expect_row(found, "0001", "INVALID (0001-a.md: superseded by 0002 but still draft)", "fix adr 0002")
    expect_valid(found, "0002")
    assert(adr.row(adr.resolve(found, "0002")) == nil, "a valid approved ADR has no row")
  end,

  an_adr_listing_itself_is_a_cycle = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "approved", supersedes = "[0001]" })
    write_sealed(adir, "0002-b.md", { status = "superseded", supersedes = "[0002]" })
    local found = scan(dir)
    expect_invalid(found, "0001", "0001-a.md: supersedes cycle")
    expect_invalid(found, "0002", "0002-b.md: supersedes cycle")
  end,

  an_adr_listed_only_by_loop_members_has_no_lister = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "approved", supersedes = "[0002, 0003]" })
    write_sealed(adir, "0002-b.md", { status = "approved", supersedes = "[0001, 0004]" })
    write_sealed(adir, "0003-c.md", { status = "superseded" })
    write_sealed(adir, "0004-d.md", { status = "approved" })
    local found = scan(dir)
    expect_invalid(found, "0001", "0001-a.md: supersedes cycle")
    expect_invalid(found, "0002", "0002-b.md: supersedes cycle")
    expect_invalid(found, "0003", "0003-c.md: superseded by nothing")
    expect_valid(found, "0004")
    assert(adr.successor(found, "0004") == nil, "a loop member is no lister")
  end,

  a_valid_adr_listing_a_loop_member_does_not_change_its_row = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "approved", supersedes = "[0002]" })
    write_sealed(adir, "0002-b.md", { status = "approved", supersedes = "[0001]" })
    write_sealed(adir, "0003-c.md", { status = "approved", supersedes = "[0001]" })
    local found = scan(dir)
    expect_invalid(found, "0001", "0001-a.md: supersedes cycle")
    expect_invalid(found, "0002", "0002-b.md: supersedes cycle")
    expect_valid(found, "0003")
  end,

  a_loop_through_an_adr_invalid_by_an_earlier_row_keeps_that_row = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "approved", supersedes = "[0002]", sealed = false })
    write_sealed(adir, "0002-b.md", { status = "approved", supersedes = "[0001]" })
    write_sealed(adir, "0003-c.md", {
      status = "approved", supersedes = "[0004]", body = "# edited", sealed = seal_of("# body"),
    })
    write_sealed(adir, "0004-d.md", { status = "approved", supersedes = "[0003]" })
    write_sealed(adir, "0005-e.md", { status = "approved", supersedes = "[0006, 0009]" })
    write_sealed(adir, "0006-f.md", { status = "approved", supersedes = "[0005]" })
    local found = scan(dir)
    expect_invalid(found, "0001", "0001-a.md: missing sealed")
    expect_invalid(found, "0002", "0002-b.md: supersedes cycle")
    expect_invalid(found, "0003", "0003-c.md: edited after approval")
    expect_invalid(found, "0004", "0004-d.md: supersedes cycle")
    expect_invalid(found, "0005", "0005-e.md: supersedes unknown 0009")
    expect_invalid(found, "0006", "0006-f.md: supersedes cycle")
  end,

  an_entry_naming_a_duplicated_number_is_not_an_edge = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "approved", supersedes = "[0002]" })
    write_sealed(adir, "0002-b.md", { status = "approved", supersedes = "[0001]" })
    write_sealed(adir, "0002-c.md", { status = "approved" })
    local found = scan(dir)
    expect_valid(found, "0001")
    assert(found[2].invalid == "0002-b.md: duplicate number 0002", tostring(found[2].invalid))
    assert(found[3].invalid == "0002-c.md: duplicate number 0002", tostring(found[3].invalid))
  end,

  a_cycle_reads_the_same_whatever_the_number_order = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "superseded", supersedes = "[0002]" })
    write_sealed(adir, "0002-b.md", { status = "approved", supersedes = "[0001, 0003]" })
    write_sealed(adir, "0003-c.md", { status = "approved", supersedes = "[0002]" })
    local forward = scan(dir)
    fs.remove(path.join(adir, "0001-a.md"))
    fs.remove(path.join(adir, "0002-b.md"))
    fs.remove(path.join(adir, "0003-c.md"))
    write_sealed(adir, "0007-a.md", { status = "superseded", supersedes = "[0006]" })
    write_sealed(adir, "0006-b.md", { status = "approved", supersedes = "[0007, 0005]" })
    write_sealed(adir, "0005-c.md", { status = "approved", supersedes = "[0006]" })
    local backward = scan(dir)
    -- Renumbering the same shape the other way round must not change which
    -- ADRs read a cycle.
    for i = 1, 3 do
      assert(forward[i].invalid ~= nil and backward[4 - i].invalid ~= nil)
      assert(forward[i].invalid:match(": supersedes cycle$"), forward[i].invalid)
      assert(backward[4 - i].invalid:match(": supersedes cycle$"), backward[4 - i].invalid)
    end
  end,

  a_second_generation_supersession_keeps_every_record_valid = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0003-c.md", { status = "superseded" })
    write_sealed(adir, "0009-i.md", { status = "superseded", supersedes = "[0003]" })
    write_sealed(adir, "0012-l.md", { status = "approved", supersedes = "[0009]" })
    local found = scan(dir)
    expect_valid(found, "0003")
    expect_valid(found, "0009")
    expect_valid(found, "0012")
  end,

  a_deprecated_successor_keeps_its_predecessor_valid = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0003-c.md", { status = "superseded" })
    write_sealed(adir, "0009-i.md", { status = "deprecated", supersedes = "[0003]" })
    local found = scan(dir)
    expect_valid(found, "0003")
    expect_valid(found, "0009")
    assert(adr.successor(found, "0003") == "0009", tostring(adr.successor(found, "0003")))
  end,

  successor_is_the_lowest_valid_sealed_lister = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "superseded" })
    write_sealed(adir, "0003-c.md", { status = "approved", supersedes = "[0001]" })
    write_sealed(adir, "0005-e.md", { status = "approved", supersedes = "[0001]" })
    local found = scan(dir)
    assert(adr.successor(found, "0001") == "0003", tostring(adr.successor(found, "0001")))
    assert(adr.successor(found, "0003") == nil, "nothing lists 0003")
    write_sealed(adir, "0003-c.md", {
      status = "approved", supersedes = "[0001]", body = "# edited", sealed = seal_of("# body"),
    })
    found = scan(dir)
    assert(adr.successor(found, "0001") == "0005", tostring(adr.successor(found, "0001")))
  end,

  successor_of_a_duplicated_number_is_nil = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "superseded" })
    write_sealed(adir, "0001-b.md", { status = "superseded" })
    write_sealed(adir, "0003-c.md", { status = "approved", supersedes = "[0001]" })
    local found = scan(dir)
    assert(adr.successor(found, "0001") == nil, tostring(adr.successor(found, "0001")))
  end,

  the_first_row_that_holds_names_the_reason = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md",
      { status = "approved", body = "# edited", sealed = seal_of("# body") })
    write_sealed(adir, "0002-b.md", { status = "approved", supersedes = "[0001]" })
    write_sealed(adir, "0003-c.md", { status = "deprecated", sealed = false })
    write_sealed(adir, "0004-d.md", { status = "approved", supersedes = "[0003]" })
    local found = scan(dir)
    expect_invalid(found, "0001", "0001-a.md: edited after approval")
    expect_invalid(found, "0003", "0003-c.md: missing sealed")
  end,

  a_plan_naming_an_approved_adr_disproves_it = function()
    local dir = root()
    write_sealed(adrs_dir(dir), "0003-c.md", { status = "approved" })
    write_chain(dir, "2026-10-20-a", "approved", {
      { num = "01", status = "done" },
      { num = "02", status = "approved", disproves = "[0003]" },
    })
    local item = adr.resolve(scan_marked(dir), "0003")
    assert(item.disproven_by == "2026-10-20-a/02", tostring(item.disproven_by))
  end,

  a_superseded_plan_disproves_nothing = function()
    local dir = root()
    write_sealed(adrs_dir(dir), "0003-c.md", { status = "approved" })
    write_chain(dir, "2026-10-20-a", "approved", {
      { num = "02", status = "superseded", disproves = "[0003]" },
    })
    assert(adr.resolve(scan_marked(dir), "0003").disproven_by == nil)
  end,

  a_disproof_of_a_retired_adr_is_history = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0003-c.md", { status = "superseded" })
    write_sealed(adir, "0004-d.md", { status = "deprecated" })
    write_sealed(adir, "0009-i.md", { status = "approved", supersedes = "[0003]" })
    write_chain(dir, "2026-10-20-a", "approved", {
      { num = "02", status = "approved", disproves = "[0003, 0004]" },
    })
    local adrs = scan_marked(dir)
    assert(adr.resolve(adrs, "0003").disproven_by == nil, "a superseded ADR is not disproven")
    assert(adr.resolve(adrs, "0004").disproven_by == nil, "a deprecated ADR is not disproven")
  end,

  a_disproof_counts_from_a_done_chain_and_a_dropped_chain = function()
    for _, intent_status in ipairs({ "done", "dropped" }) do
      local dir = root()
      write_sealed(adrs_dir(dir), "0003-c.md", { status = "approved" })
      write_chain(dir, "2026-10-20-a", intent_status, {
        { num = "02", status = "done", disproves = "[0003]" },
      })
      local item = adr.resolve(scan_marked(dir), "0003")
      assert(item.disproven_by == "2026-10-20-a/02", intent_status .. ": " .. tostring(item.disproven_by))
    end
  end,

  an_invalid_chain_contributes_no_disproof = function()
    local dir = root()
    write_sealed(adrs_dir(dir), "0003-c.md", { status = "approved" })
    local cdir = write_chain(dir, "2026-10-20-a", "approved", {
      { num = "01", status = "approved", disproves = "[0003]" },
    })
    fs.write(path.join(cdir, "plans", "02-x.md"), "# no frontmatter\n")
    local chains = status.scan(dir)
    assert(chains[1].invalid, "the chain with an unparseable plan is invalid")
    local adrs = scan(dir)
    adr.mark_disproofs(adrs, chains)
    assert(adr.resolve(adrs, "0003").disproven_by == nil, "an invalid chain's plans read nothing")
  end,

  an_adr_that_is_not_valid_and_approved_is_never_disproven = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "draft", sealed = false })
    write_sealed(adir, "0002-b.md", { status = "approved", sealed = false })
    write_sealed(adir, "0004-d.md", { status = "approved" })
    write_sealed(adir, "0004-e.md", { status = "approved" })
    write_chain(dir, "2026-10-20-a", "approved", {
      { num = "01", status = "approved", disproves = "[0001, 0002, 0004, 0009]" },
    })
    for _, item in ipairs(scan_marked(dir)) do
      assert(item.disproven_by == nil, item.file .. " must not be disproven")
    end
  end,

  the_first_chain_and_lowest_plan_name_the_disproof = function()
    local dir = root()
    write_sealed(adrs_dir(dir), "0003-c.md", { status = "approved" })
    write_chain(dir, "2026-10-21-b", "approved", {
      { num = "01", status = "approved", disproves = "[0003]" },
    })
    write_chain(dir, "2026-10-20-a", "approved", {
      { num = "02", status = "approved", disproves = "[3]" },
      { num = "03", status = "approved", disproves = "[0003]" },
    })
    local item = adr.resolve(scan_marked(dir), "0003")
    assert(item.disproven_by == "2026-10-20-a/02", tostring(item.disproven_by))
  end,

  a_disproven_adr_row_names_its_chain_and_plan = function()
    local dir = root()
    write_sealed(adrs_dir(dir), "0003-c.md", { status = "approved" })
    write_chain(dir, "2026-10-20-a", "approved", {
      { num = "02", status = "approved", disproves = "[0003]" },
    })
    expect_row(scan_marked(dir), "0003", "disproven by 2026-10-20-a/02", "adr supersede 0003")
  end,

  an_invalid_adr_row_names_its_file_and_fix = function()
    local dir = root()
    write_sealed(adrs_dir(dir), "0003-x.md", { status = "approved", sealed = false })
    expect_row(scan(dir), "0003", "INVALID (0003-x.md: missing sealed)", "fix adr 0003")
  end,

  a_cycle_row_sends_to_a_fix = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "approved", supersedes = "[0002]" })
    write_sealed(adir, "0002-b.md", { status = "superseded", supersedes = "[0001]" })
    local adrs = scan(dir)
    expect_row(adrs, "0001", "INVALID (0001-a.md: supersedes cycle)", "fix adr 0001")
    expect_row(adrs, "0002", "INVALID (0002-b.md: supersedes cycle)", "fix adr 0002")
  end,

  a_still_approved_row_sends_to_the_adr_skill = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0003-c.md", { status = "approved" })
    write_sealed(adir, "0009-i.md", { status = "approved", supersedes = "[0003]" })
    expect_row(scan(dir), "0003", "INVALID (0003-c.md: superseded by 0009 but still approved)", "adr")
  end,

  a_still_status_row_sends_to_the_lister = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0003-c.md", { status = "draft", sealed = false })
    write_sealed(adir, "0009-i.md", { status = "approved", supersedes = "[0003]" })
    expect_row(scan(dir), "0003", "INVALID (0003-c.md: superseded by 0009 but still draft)", "fix adr 0009")
  end,

  a_draft_adr_row_asks_to_approve_or_drop = function()
    local dir = root()
    write_adr(adrs_dir(dir), "0001-a.md", "draft")
    expect_row(scan(dir), "0001", "draft", "approve or drop")
  end,

  a_healthy_adr_has_no_row = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "approved" })
    write_sealed(adir, "0002-b.md", { status = "superseded" })
    write_sealed(adir, "0003-c.md", { status = "deprecated", supersedes = "[0002]" })
    write_sealed(adir, "0004-d.md", { status = "dropped", sealed = false })
    local adrs = scan_marked(dir)
    for _, num in ipairs({ "0001", "0002", "0003", "0004" }) do
      assert(adr.row(adr.resolve(adrs, num)) == nil, "ADR " .. num .. " must have no row")
    end
  end,

  the_heading_counts_non_zero_statuses_in_order = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "approved" })
    write_sealed(adir, "0002-b.md", { status = "approved" })
    write_sealed(adir, "0003-c.md", { status = "superseded" })
    write_sealed(adir, "0004-d.md", { status = "deprecated", supersedes = "[0003]" })
    write_adr(adir, "0005-e.md", "draft")
    write_sealed(adir, "0006-f.md", { status = "dropped", sealed = false })
    write_sealed(adir, "0007-g.md", { status = "approved", sealed = false })
    local heading = adr.heading(scan(dir))
    assert(heading == "ADRS: 2 approved, 1 superseded, 1 deprecated, 1 draft, 1 dropped, 1 invalid", heading)
  end,

  the_heading_omits_zero_counts = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_sealed(adir, "0001-a.md", { status = "approved" })
    write_sealed(adir, "0002-b.md", { status = "approved" })
    write_adr(adir, "0003-c.md", "draft")
    local heading = adr.heading(scan(dir))
    assert(heading == "ADRS: 2 approved, 1 draft", heading)
  end,

  an_invalid_adr_counts_only_as_invalid_in_the_heading = function()
    local dir = root()
    local adir = adrs_dir(dir)
    write_adr(adir, "0001-a.md", "draft")
    write_adr(adir, "0001-b.md", "draft")
    local heading = adr.heading(scan(dir))
    assert(heading == "ADRS: 2 invalid", heading)
  end,
}
