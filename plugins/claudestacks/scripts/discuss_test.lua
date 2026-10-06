-- Tests for lib/discuss — the per-session topic index behind /claudestacks:discuss.
--
--   cargo make plugins-test

local discuss = require("lib.discuss")
local fs = airsstack.fs
local path = airsstack.path
local hash = airsstack.hash

local NOW = 1791100000

-- A communication-protocol report in `dir` named `name`, with one topic per title.
local function report(dir, name, titles, extra)
  local lines = { "---", "agent: reviewer", "task: t", "protocol: discuss/1", "---",
    "<summary>", "s", "</summary>" }
  if #titles > 0 then
    lines[#lines + 1] = "<topics>"
    for index, title in ipairs(titles) do
      lines[#lines + 1] = index .. ". " .. title
    end
    lines[#lines + 1] = "</topics>"
    lines[#lines + 1] = "<detail>"
    for index, title in ipairs(titles) do
      lines[#lines + 1] = "## " .. index .. ". " .. title
      lines[#lines + 1] = "body of " .. title
    end
    lines[#lines + 1] = "</detail>"
  end
  local file = path.join(dir, name)
  fs.write(file, table.concat(lines, "\n") .. "\n" .. (extra or ""))
  return file
end

-- A fresh project directory under a fresh storage root.
local function project()
  return path.join(fs.tempdir(), "discussions", "repo-00000000")
end

return {
  keep_takes_a_positive_integer = function()
    assert(discuss.keep("5") == 5)
    assert(discuss.keep(7) == 7)
  end,

  keep_falls_back_to_twenty_for_anything_else = function()
    for _, value in ipairs({ "${user_config.archive_keep}", "0", "-1", "2.5", "" }) do
      assert(discuss.keep(value) == 20, value)
    end
    assert(discuss.keep(nil) == 20)
  end,

  the_key_matches_the_reference_shell_block = function()
    -- Captured 2026-10-04 by running the `skills/snapshot-save/SKILL.md` reference block with
    -- abs='/Users/someone/my repo/.git' → `my-repo-73a3d285`.
    assert(discuss.key_for("my repo", "/Users/someone/my repo/.git") == "my-repo-73a3d285")
  end,

  a_linked_worktree_shares_its_main_worktrees_key = function()
    local base = fs.tempdir()
    local main = path.join(base, "repo")
    fs.mkdir(path.join(main, ".git", "worktrees", "wt"))
    local linked = path.join(base, "wt")
    fs.mkdir(linked)
    -- `fs.tempdir()` is already physical (`/private/var/…` on macOS, probed 2026-10-04). Write
    -- the pointer through the `/var` symlink instead, so only a port that canonicalises the
    -- common dir — as the reference block's `pwd -P` does — produces equal keys. On a system
    -- without that symlink the spelling is unchanged and this checks equality only.
    local pointer = path.join(main, ".git", "worktrees", "wt"):gsub("^/private/var/", "/var/")
    fs.write(path.join(linked, ".git"), "gitdir: " .. pointer .. "\n")
    assert(discuss.project_key(main) == discuss.project_key(linked),
      tostring(discuss.project_key(main)) .. " vs " .. tostring(discuss.project_key(linked)))
  end,

  outside_a_repository_the_key_hashes_the_directory = function()
    local dir = path.join(fs.tempdir(), "loose")
    fs.mkdir(dir)
    local key = discuss.project_key(dir)
    assert(key == "loose-" .. hash.sha1(fs.canonicalize(dir)):sub(1, 8), key)
  end,

  start_creates_an_open_discussion = function()
    local dir = project()
    local index, resumed = discuss.start(dir, "sess-a", 20, NOW)
    assert(index.state == "open" and index.opened == NOW and index.touched == NOW)
    assert(#index.topics == 0 and resumed == false)
    assert(discuss.load(path.join(dir, "sess-a")).state == "open")
  end,

  start_resumes_an_open_discussion = function()
    local dir = project()
    discuss.start(dir, "sess-a", 20, NOW)
    local index, resumed = discuss.start(dir, "sess-a", 20, NOW + 5)
    assert(resumed == true and index.opened == NOW and index.touched == NOW + 5)
  end,

  start_reopens_a_closed_discussion_of_the_same_session = function()
    local dir = project()
    local index = discuss.start(dir, "sess-a", 20, NOW)
    index.state, index.closed = "closed", NOW + 1
    discuss.save(path.join(dir, "sess-a"), index, NOW + 1)
    local again = discuss.start(dir, "sess-a", 20, NOW + 2)
    assert(again.state == "open" and again.closed == nil)
  end,

  a_session_id_with_a_path_separator_is_refused = function()
    local dir = project()
    fs.mkdir(dir)
    assert(not pcall(discuss.start, dir, "../evil", 20, NOW))
    assert(not pcall(discuss.start, dir, "", 20, NOW))
  end,

  prune_keeps_the_newest_n_others_and_never_the_current = function()
    local dir = project()
    for age, name in ipairs({ "old", "mid", "new" }) do
      discuss.save(path.join(dir, name), { state = "closed", topics = {} }, NOW + age)
    end
    -- The current session is the oldest of all, and still survives.
    discuss.save(path.join(dir, "current"), { state = "open", topics = {} }, NOW)
    local removed = discuss.prune(dir, "current", 2)
    assert(#removed == 1 and removed[1] == "old")
    assert(fs.is_dir(path.join(dir, "current")))
    assert(fs.is_dir(path.join(dir, "new")) and fs.is_dir(path.join(dir, "mid")))
  end,

  start_prunes_the_projects_other_discussions = function()
    local dir = project()
    for age, name in ipairs({ "oldest", "middle", "newest" }) do
      discuss.save(path.join(dir, name), { state = "closed", topics = {} }, NOW + age)
    end
    discuss.start(dir, "current", 2, NOW + 10)
    assert(not fs.exists(path.join(dir, "oldest")))
    assert(fs.is_dir(path.join(dir, "middle")) and fs.is_dir(path.join(dir, "newest")))
    assert(fs.is_dir(path.join(dir, "current")))
  end,

  an_abandoned_open_discussion_ages_out_like_a_closed_one = function()
    local dir = project()
    discuss.save(path.join(dir, "crashed"), { state = "open", topics = {} }, NOW)
    discuss.save(path.join(dir, "later"), { state = "closed", topics = {} }, NOW + 1)
    local removed = discuss.prune(dir, "current", 1)
    assert(#removed == 1 and removed[1] == "crashed")
  end,

  add_numbers_topics_after_the_existing_ones = function()
    local dir = project()
    local index = discuss.start(dir, "s", 20, NOW)
    local tmp = fs.tempdir()
    discuss.add(index, report(tmp, "01-a.md", { "alpha", "beta" }))
    local added = discuss.add(index, report(tmp, "02-b.md", { "gamma" }))
    assert(#index.topics == 3 and added[1].id == 3 and added[1].title == "gamma")
    assert(index.topics[2].heading == "## 2. beta" and index.topics[2].read == false)
  end,

  add_refuses_a_report_failing_either_validator = function()
    local index = discuss.start(project(), "s", 20, NOW)
    local file = report(fs.tempdir(), "01-a.md", { "alpha" })
    fs.write(file, (fs.read(file):gsub("## 1%. alpha", "## 1. other")))
    local added, violations = discuss.add(index, file)
    assert(added == nil and violations[1].id == "topic-heading-missing")
    assert(#index.topics == 0)
  end,

  add_refuses_a_report_failing_only_the_base_schema = function()
    local index = discuss.start(project(), "s", 20, NOW)
    local file = report(fs.tempdir(), "01-a.md", { "alpha" })
    fs.write(file, (fs.read(file):gsub("task: t\n", "")))
    local added, violations = discuss.add(index, file)
    assert(added == nil and violations[1].id == "task-missing")
    assert(#index.topics == 0)
  end,

  add_requires_the_protocol_key = function()
    local index = discuss.start(project(), "s", 20, NOW)
    local file = report(fs.tempdir(), "01-a.md", { "alpha" })
    fs.write(file, (fs.read(file):gsub("protocol: discuss/1\n", "")))
    local added, violations = discuss.add(index, file)
    assert(added == nil and violations[1].id == "protocol-missing")
  end,

  add_refuses_the_same_report_twice = function()
    local index = discuss.start(project(), "s", 20, NOW)
    local file = report(fs.tempdir(), "01-a.md", { "alpha" })
    discuss.add(index, file)
    local added, violations = discuss.add(index, file)
    assert(added == nil and violations[1].id == "already-added")
  end,

  add_recognises_the_same_report_under_another_spelling = function()
    local tmp = fs.tempdir()
    fs.mkdir(path.join(tmp, "sub"))
    local file = report(tmp, "01-a.md", { "alpha" })
    local spellings = {
      path.join(tmp, "sub", "..", "01-a.md"),
      path.join(tmp, ".", "01-a.md"),
      (file:gsub("^/private/var/", "/var/")),
    }
    for _, spelling in ipairs(spellings) do
      local index = discuss.start(project(), "s", 20, NOW)
      assert(discuss.add(index, file))
      local added, violations = discuss.add(index, spelling)
      assert(added == nil and violations[1].id == "already-added", spelling)
      assert(#index.topics == 1, spelling)
    end
  end,

  add_stores_the_canonical_path = function()
    local tmp = fs.tempdir()
    fs.mkdir(path.join(tmp, "sub"))
    local file = report(tmp, "01-a.md", { "alpha" })
    local index = discuss.start(project(), "s", 20, NOW)
    local added = discuss.add(index, path.join(tmp, "sub", "..", "01-a.md"))
    assert(added[1].report == fs.canonicalize(file), added[1].report)
  end,

  a_thin_report_adds_no_topics = function()
    local index = discuss.start(project(), "s", 20, NOW)
    local added = discuss.add(index, report(fs.tempdir(), "01-a.md", {}))
    assert(added and #added == 0 and #index.topics == 0)
  end,

  list_shows_id_read_mark_and_title = function()
    local index = discuss.start(project(), "s", 20, NOW)
    discuss.add(index, report(fs.tempdir(), "01-a.md", { "alpha", "beta" }))
    index.topics[1].read = true
    assert(discuss.list_lines(index) == "  1  * alpha\n  2    beta")
  end,

  the_archive_lists_other_discussions_with_their_state = function()
    local dir = project()
    local other = discuss.start(dir, "abcdef1234", 20, NOW)
    discuss.add(other, report(fs.tempdir(), "01-a.md", { "alpha" }))
    other.state = "closed"
    discuss.save(path.join(dir, "abcdef1234"), other, NOW + 1)
    discuss.start(dir, "current", 20, NOW + 2)
    assert(discuss.archive_lines(dir, "current") == "abcdef12/1  closed  alpha")
  end,

  show_returns_one_section_and_marks_it_read = function()
    local dir = project()
    local index = discuss.start(dir, "s", 20, NOW)
    discuss.add(index, report(fs.tempdir(), "01-a.md", { "alpha", "beta" }))
    discuss.save(path.join(dir, "s"), index, NOW)
    local text = discuss.show(dir, "s", "2", NOW + 1)
    assert(text == "## 2. beta\nbody of beta", text)
    assert(discuss.load(path.join(dir, "s")).topics[2].read == true)
  end,

  show_reaches_an_archived_topic_by_sid8 = function()
    local dir = project()
    local old = discuss.start(dir, "abcdef1234", 20, NOW)
    discuss.add(old, report(fs.tempdir(), "01-a.md", { "alpha" }))
    discuss.save(path.join(dir, "abcdef1234"), old, NOW)
    discuss.start(dir, "current", 20, NOW + 1)
    assert(discuss.show(dir, "current", "abcdef12/1", NOW + 2) == "## 1. alpha\nbody of alpha")
  end,

  show_names_a_vanished_report = function()
    local dir = project()
    local index = discuss.start(dir, "s", 20, NOW)
    local file = report(fs.tempdir(), "01-a.md", { "alpha" })
    discuss.add(index, file)
    discuss.save(path.join(dir, "s"), index, NOW)
    fs.remove(file)
    local text, err = discuss.show(dir, "s", "1", NOW)
    assert(text == nil and err == "report gone: " .. index.topics[1].report, tostring(err))
  end,

  a_plain_subheading_stays_inside_its_topic = function()
    local dir = project()
    local index = discuss.start(dir, "s", 20, NOW)
    local file = report(fs.tempdir(), "01-a.md", { "alpha", "beta" })
    fs.write(file, (fs.read(file):gsub("body of alpha", "body of alpha\n## notes\nmore")))
    discuss.add(index, file)
    discuss.save(path.join(dir, "s"), index, NOW)
    assert(discuss.show(dir, "s", "1", NOW) == "## 1. alpha\nbody of alpha\n## notes\nmore")
  end,

  show_finds_a_heading_that_carries_trailing_spaces = function()
    local dir = project()
    local index = discuss.start(dir, "s", 20, NOW)
    local file = report(fs.tempdir(), "01-a.md", { "alpha", "beta" })
    fs.write(file, (fs.read(file):gsub("\n## 1%. alpha\n", "\n## 1. alpha   \n")
      :gsub("\n## 2%. beta\n", "\n## 2. beta \t\n")))
    assert(discuss.add(index, file), "add refused the report")
    discuss.save(path.join(dir, "s"), index, NOW)
    assert(discuss.show(dir, "s", "1", NOW) == "## 1. alpha\nbody of alpha")
    assert(discuss.show(dir, "s", "2", NOW) == "## 2. beta\nbody of beta")
  end,

  show_ignores_a_matching_line_outside_the_detail = function()
    local dir = project()
    local index = discuss.start(dir, "s", 20, NOW)
    local file = report(fs.tempdir(), "01-a.md", { "alpha" })
    fs.write(file, (fs.read(file):gsub("\ns\n</summary>", "\n## 1. alpha\n</summary>")))
    assert(discuss.add(index, file), "add refused the report")
    discuss.save(path.join(dir, "s"), index, NOW)
    local text = discuss.show(dir, "s", "1", NOW)
    assert(text == "## 1. alpha\nbody of alpha", tostring(text))
  end,

  show_refuses_an_unknown_id = function()
    local dir = project()
    discuss.start(dir, "s", 20, NOW)
    local text, err = discuss.show(dir, "s", "9", NOW)
    assert(text == nil and err == "unknown topic: 9")
  end,

  done_copies_reports_into_the_discussion_and_closes_it = function()
    local dir = project()
    local index = discuss.start(dir, "s", 20, NOW)
    local file = report(fs.tempdir(), "01-reviewer-x.md", { "alpha", "beta" })
    discuss.add(index, file)
    discuss.save(path.join(dir, "s"), index, NOW)
    local missing = discuss.done(dir, "s", NOW + 9)
    local closed = discuss.load(path.join(dir, "s"))
    assert(#missing == 0 and closed.state == "closed" and closed.closed == NOW + 9)
    local copy = path.join(dir, "s", "reports", "01-01-reviewer-x.md")
    assert(closed.topics[1].report == copy and closed.topics[2].report == copy)
    fs.remove(file)
    assert(discuss.show(dir, "s", "2", NOW + 10) == "## 2. beta\nbody of beta")
  end,

  done_records_a_vanished_report_and_still_closes = function()
    local dir = project()
    local index = discuss.start(dir, "s", 20, NOW)
    local file = report(fs.tempdir(), "01-a.md", { "alpha" })
    discuss.add(index, file)
    discuss.save(path.join(dir, "s"), index, NOW)
    local stored = index.topics[1].report
    fs.remove(file)
    local missing = discuss.done(dir, "s", NOW)
    assert(#missing == 1 and missing[1] == stored, tostring(missing[1]))
    assert(discuss.load(path.join(dir, "s")).state == "closed")
  end,

  done_without_an_open_discussion_is_refused = function()
    local ok, err = discuss.done(project(), "nobody", NOW)
    assert(ok == nil and err == "no open discussion for this session")
  end,

  done_twice_refuses_the_second_close = function()
    local dir = project()
    discuss.start(dir, "s", 20, NOW)
    assert(discuss.done(dir, "s", NOW + 1))
    local again, err = discuss.done(dir, "s", NOW + 2)
    assert(again == nil and err == "no open discussion for this session", tostring(err))
  end,

  done_keeps_a_main_thread_report_where_it_is_under_a_symlinked_root = function()
    -- `fs.tempdir()` is physical (`/private/var/…` on macOS), so the `/var` spelling reaches the
    -- same directory through a symlink and `report_path` hands back that spelling. On a system
    -- without the symlink the spelling is unchanged and this checks the plain case.
    local dir = (project():gsub("^/private/var/", "/var/"))
    local index = discuss.start(dir, "s", 20, NOW)
    local target = discuss.report_path(dir, "s", "why")
    local file = report(path.dirname(target), path.basename(target), { "alpha" })
    assert(discuss.add(index, file), "add refused the report")
    discuss.save(path.join(dir, "s"), index, NOW)
    local stored = index.topics[1].report
    local missing = discuss.done(dir, "s", NOW + 1)
    assert(#missing == 0)
    local names = fs.list(path.join(dir, "s", "reports"))
    assert(#names == 1 and names[1] == path.basename(target), table.concat(names, ", "))
    assert(discuss.load(path.join(dir, "s")).topics[1].report == stored)
  end,

  report_path_after_done_is_refused = function()
    local dir = project()
    discuss.start(dir, "s", 20, NOW)
    assert(discuss.done(dir, "s", NOW + 1))
    local p, err = discuss.report_path(dir, "s", "ok")
    assert(p == nil and err == "no open discussion for this session", tostring(err))
  end,

  report_path_refuses_a_session_id_that_names_a_path = function()
    local dir = project()
    fs.mkdir(dir)
    assert(not pcall(discuss.report_path, dir, "../x", "ok"))
  end,

  report_path_numbers_after_existing_reports = function()
    local dir = project()
    discuss.start(dir, "s", 20, NOW)
    local reports = path.join(dir, "s", "reports")
    fs.mkdir(reports)
    fs.write(path.join(reports, "03-main-old.md"), "x")
    assert(discuss.report_path(dir, "s", "why-it-broke") == path.join(reports, "04-main-why-it-broke.md"))
  end,

  report_path_refuses_a_bad_slug_or_no_discussion = function()
    local dir = project()
    discuss.start(dir, "s", 20, NOW)
    local p, err = discuss.report_path(dir, "s", "Bad Slug")
    assert(p == nil and err == "slug must match [a-z0-9-]+: Bad Slug")
    local q, why = discuss.report_path(dir, "nobody", "ok")
    assert(q == nil and why == "no open discussion for this session")
  end,
}
