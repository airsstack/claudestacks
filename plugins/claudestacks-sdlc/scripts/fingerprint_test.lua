-- Tests for lib/fingerprint — body extraction and hashing. The literal
-- values are the ones `scripts/fingerprint.sh` must print for the same
-- files; the fingerprint gate in `cargo make plugins-test` checks that side.
--
--   airsl test --policy confined --allow-read / \
--     --allow-write "${TMPDIR:-/tmp}" --allow-exec git \
--     plugins/claudestacks-sdlc/scripts

local fingerprint = require("lib.fingerprint")

local fs = airsstack.fs
local path = airsstack.path

local FM = "---\nstatus: approved\ncreated: 2026-10-13\n---\n"
local BODY = "# Spec: sample\n\nA line with --- inside it.\n---\nlast line"

local function expect(text, want)
  local got, reason = fingerprint.of_text(text)
  assert(got == want, "want " .. tostring(want) .. ", got " .. tostring(got) .. " / " .. tostring(reason))
end

return {
  a_body_with_a_final_newline_has_the_recorded_fingerprint = function()
    expect(FM .. BODY .. "\n", "db42cc1eff57")
  end,

  a_missing_final_newline_does_not_change_the_fingerprint = function()
    expect(FM .. BODY, "db42cc1eff57")
  end,

  crlf_line_endings_do_not_change_the_fingerprint = function()
    expect((FM .. BODY .. "\n"):gsub("\n", "\r\n"), "db42cc1eff57")
  end,

  a_status_flip_does_not_change_the_fingerprint = function()
    expect(FM:gsub("approved", "done") .. BODY .. "\n", "db42cc1eff57")
  end,

  an_edited_body_changes_the_fingerprint = function()
    expect(FM .. BODY .. " changed\n", "02746658f17b")
  end,

  an_empty_body_has_the_fingerprint_of_the_empty_string = function()
    expect(FM, "e3b0c44298fc")
  end,

  missing_frontmatter_has_no_fingerprint = function()
    local got, reason = fingerprint.of_text("# just a heading\n")
    assert(got == nil and reason == "missing frontmatter", tostring(got) .. " / " .. tostring(reason))
  end,

  unterminated_frontmatter_has_no_fingerprint = function()
    local got, reason = fingerprint.of_text("---\nstatus: draft\n")
    assert(got == nil and reason == "unterminated frontmatter", tostring(got) .. " / " .. tostring(reason))
  end,

  a_file_is_fingerprinted_by_its_text = function()
    local file = path.join(fs.tempdir(), "spec.md")
    fs.write(file, FM .. BODY .. "\n")
    assert(fingerprint.of_file(file) == "db42cc1eff57", tostring(fingerprint.of_file(file)))
  end,

  an_unreadable_file_has_no_fingerprint = function()
    local got, reason = fingerprint.of_file(path.join(fs.tempdir(), "absent.md"))
    assert(got == nil and reason == "unreadable", tostring(got) .. " / " .. tostring(reason))
  end,
}
