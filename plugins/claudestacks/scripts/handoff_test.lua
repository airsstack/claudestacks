-- Tests for lib/handoff — session minting, the liveness lease, and pruning.
--
--   airsl test --allow-read "$TMPDIR" --allow-write "$TMPDIR" --allow-read . plugins/claudestacks/scripts
--
-- The header command grants no `--allow-exec git`, matching the shipped invocation (see
-- `handoff.lua`). `cargo make plugins-test` runs the whole tree WITH the grant, for the sibling
-- `enforce_test.lua` fixtures — these tests pass either way, because `fs.tempdir()` sits outside
-- any repository, so the probe finds nothing whether or not it is allowed to run.

local handoff = require("lib.handoff")
local fs = airsstack.fs
local path = airsstack.path

-- Real time, not a fixed epoch: the lease files these tests create carry a real modification
-- time, and judging them against a constant would make every lease look ancient.
local NOW = airsstack.time.now()

-- A handoff base holding `names`, each with an optional lease age in minutes.
local function base_with(names)
  local base = fs.tempdir()
  for name, lease_age in pairs(names) do
    fs.mkdir(path.join(base, name))
    if lease_age then
      fs.write(path.join(base, name, handoff.LEASE), "")
    end
  end
  return base
end

return {
  a_session_id_carries_a_sortable_timestamp_and_a_suffix = function()
    local id = handoff.session_id("20260101-120000")
    assert(id:sub(1, 15) == "20260101-120000", id)
    assert(id:match("^%d+%-%d+%-%x%x%x%x$"), id)
  end,

  two_ids_from_one_timestamp_differ = function()
    -- The suffix only has to separate two sessions minted in the same second.
    local seen = {}
    for _ = 1, 32 do
      seen[handoff.session_id("20260101-120000")] = true
    end
    local distinct = 0
    for _ in pairs(seen) do
      distinct = distinct + 1
    end
    assert(distinct > 1, "the suffix must vary")
  end,

  init_mints_a_directory_with_a_live_lease = function()
    local project = fs.tempdir()
    local directory, id = handoff.init(project, "20260101-120000", 10, NOW, 120)
    assert(fs.is_dir(directory), directory)
    assert(fs.exists(path.join(directory, handoff.LEASE)), "a new session holds its lease")
    assert(directory:sub(-#id) == id, directory .. " should end in " .. id)
  end,

  init_ignores_the_handoff_tree_in_git = function()
    local project = fs.tempdir()
    handoff.init(project, "20260101-120000", 10, NOW, 120)
    local lines = fs.read_lines(path.join(project, ".gitignore"))
    assert(lines[1] == handoff.IGNORE_LINE, tostring(lines[1]))
  end,

  a_linked_worktree_keeps_its_gitignore_untouched = function()
    -- A linked worktree shares the main checkout's TRACKED `.gitignore`, so appending to it leaves
    -- an uncommitted change in the very tree the session is working on. The main checkout is where
    -- the line belongs, and the worktree is not it. Issue #6, fourth proposal.
    local tree = fs.tempdir()
    fs.write(path.join(tree, ".git"), "gitdir: /elsewhere/.git/worktrees/wt\n")
    fs.write(path.join(tree, ".gitignore"), "target/\n")

    handoff.init(tree, "20260101-120000", 10, NOW, 120, tree)

    local lines = fs.read_lines(path.join(tree, ".gitignore"))
    assert(#lines == 1 and lines[1] == "target/", table.concat(lines, ","))
  end,

  a_linked_worktree_still_mints_its_session = function()
    local tree = fs.tempdir()
    fs.write(path.join(tree, ".git"), "gitdir: /elsewhere/.git/worktrees/wt\n")

    local directory = handoff.init(tree, "20260101-120000", 10, NOW, 120, tree)
    assert(fs.is_dir(directory), directory)
    assert(fs.exists(path.join(directory, handoff.LEASE)), "a new session holds its lease")
  end,

  the_ignore_line_is_never_added_twice = function()
    local project = fs.tempdir()
    handoff.init(project, "20260101-120000", 10, NOW, 120)
    handoff.init(project, "20260101-120001", 10, NOW, 120)

    local found = 0
    for _, line in ipairs(fs.read_lines(path.join(project, ".gitignore"))) do
      if line == handoff.IGNORE_LINE then
        found = found + 1
      end
    end
    assert(found == 1, "expected one ignore line, found " .. found)
  end,

  an_existing_gitignore_keeps_its_content = function()
    local project = fs.tempdir()
    fs.write(path.join(project, ".gitignore"), "target/\n")
    handoff.init(project, "20260101-120000", 10, NOW, 120)
    local lines = fs.read_lines(path.join(project, ".gitignore"))
    assert(lines[1] == "target/" and lines[2] == handoff.IGNORE_LINE)
  end,

  sessions_are_listed_oldest_first = function()
    local base = base_with({ ["20260103-000000-aa"] = false, ["20260101-000000-bb"] = false })
    local names = handoff.sessions(base)
    assert(names[1] == "20260101-000000-bb", names[1])
  end,

  a_loose_file_is_not_a_session = function()
    local base = base_with({ ["20260101-000000-aa"] = false })
    fs.write(path.join(base, "notes.txt"), "x")
    assert(#handoff.sessions(base) == 1)
  end,

  pruning_removes_only_the_oldest_beyond_the_keep_count = function()
    local base = base_with({
      ["20260101-000000-a"] = false,
      ["20260102-000000-b"] = false,
      ["20260103-000000-c"] = false,
      ["20260104-000000-d"] = false,
    })
    local removed = handoff.prune(base, 2, NOW, 120)
    assert(#removed == 2, "expected two pruned, got " .. #removed)
    assert(removed[1] == "20260101-000000-a", removed[1])
    assert(#handoff.sessions(base) == 2)
  end,

  pruning_below_the_keep_count_removes_nothing = function()
    local base = base_with({ ["20260101-000000-a"] = false })
    assert(#handoff.prune(base, 10, NOW, 120) == 0)
  end,

  a_live_lease_protects_its_session_from_pruning = function()
    local base = base_with({
      ["20260101-000000-a"] = true,
      ["20260102-000000-b"] = false,
      ["20260103-000000-c"] = false,
    })
    local removed = handoff.prune(base, 1, NOW, 120)
    assert(#removed == 1 and removed[1] == "20260102-000000-b", table.concat(removed, ","))
    assert(fs.is_dir(path.join(base, "20260101-000000-a")), "the leased session must survive")
  end,

  a_lease_older_than_the_grace_window_no_longer_protects = function()
    local base = base_with({ ["20260101-000000-a"] = true, ["20260102-000000-b"] = false })
    -- The lease was written now; judging it from beyond the grace window makes it stale.
    local removed = handoff.prune(base, 1, NOW + 121 * 60, 120)
    assert(#removed == 1 and removed[1] == "20260101-000000-a", table.concat(removed, ","))
  end,

  a_heartbeat_refreshes_a_lease_and_reports_a_missing_session = function()
    local project = fs.tempdir()
    local directory = handoff.init(project, "20260101-120000", 10, NOW, 120)
    assert(handoff.beat(directory) == true)
    assert(handoff.beat(path.join(project, "no-such-session")) == false)
  end,

  closing_drops_the_lease_and_leaves_the_session = function()
    local project = fs.tempdir()
    local directory = handoff.init(project, "20260101-120000", 10, NOW, 120)
    handoff.close(directory)
    assert(not fs.exists(path.join(directory, handoff.LEASE)), "the lease is gone")
    assert(fs.is_dir(directory), "the session's contents are not")
  end,

  closing_an_already_closed_session_is_not_an_error = function()
    local project = fs.tempdir()
    local directory = handoff.init(project, "20260101-120000", 10, NOW, 120)
    handoff.close(directory)
    handoff.close(directory)
  end,

  -- `init`'s argument parsing, which the driver delegates here so it is covered by a test rather
  -- than only by running the script.

  no_arguments_means_no_root = function()
    local root, problem = handoff.parse_init_args({})
    assert(root == nil and problem == nil, tostring(root) .. " / " .. tostring(problem))
  end,

  parse_returns_the_root_directory = function()
    local dir = fs.tempdir()
    local root, problem = handoff.parse_init_args({ "--root", dir })
    assert(root == dir and problem == nil, tostring(root) .. " / " .. tostring(problem))
  end,

  a_misspelt_flag_is_an_error_rather_than_a_silent_cwd_fallback = function()
    local root, problem = handoff.parse_init_args({ "--rooot", "/tmp" })
    assert(root == nil, tostring(root))
    assert(problem == "init: unexpected argument: --rooot", tostring(problem))
  end,

  a_root_without_a_value_is_an_error = function()
    local _, problem = handoff.parse_init_args({ "--root" })
    assert(problem == "init: --root needs a directory", tostring(problem))
    local _, next_flag = handoff.parse_init_args({ "--root", "--root" })
    assert(next_flag == "init: --root needs a directory", tostring(next_flag))
  end,

  a_root_that_is_not_a_directory_is_an_error = function()
    -- Otherwise it surfaces as a traceback out of `ensure_gitignore`, naming a `.gitignore` the
    -- caller never mentioned.
    local _, problem = handoff.parse_init_args({ "--root", "/nope/nope" })
    assert(problem == "init: --root is not a directory: /nope/nope", tostring(problem))
  end,

  a_repeated_root_is_an_error_rather_than_last_wins = function()
    local dir = fs.tempdir()
    local _, problem = handoff.parse_init_args({ "--root", dir, "--root", dir })
    assert(problem == "init: --root given twice", tostring(problem))
  end,

  a_directory_holding_dot_git_looks_like_a_root = function()
    -- What the driver's stderr warning is suppressed by: at a real root the common case is quiet.
    local repo = fs.tempdir()
    fs.mkdir(path.join(repo, ".git"))
    assert(handoff.looks_like_root(repo))
    assert(not handoff.looks_like_root(fs.tempdir()))
  end,

  -- Root resolution. The git probe needs `--allow-exec git`, which a worktree-isolated Claude Code
  -- session cannot pass — the guard reads `git` as an operand of a launcher it cannot see through
  -- and refuses the whole command. So the root has to be resolvable without it.

  an_explicit_root_wins_over_the_working_directory = function()
    local elsewhere = fs.tempdir()
    local root, source = handoff.worktree_root(fs.tempdir(), elsewhere)
    assert(root == elsewhere, root)
    assert(source == "explicit", tostring(source))
  end,

  an_empty_root_is_not_a_root = function()
    -- An unset `--root` arrives as "" rather than nil; it must not win over the real resolution.
    local cwd = fs.tempdir()
    local root, source = handoff.worktree_root(cwd, "")
    assert(root == cwd, root)
    assert(source ~= "explicit", tostring(source))
  end,

  without_a_root_and_without_git_the_working_directory_is_used = function()
    -- This suite runs without `--allow-exec git`, so the probe is denied and `cwd` is the answer.
    local cwd = fs.tempdir()
    local root, source = handoff.worktree_root(cwd)
    assert(root == cwd, root)
    assert(source == "cwd", tostring(source))
  end,

  an_explicit_root_places_the_session_tree = function()
    local root = fs.tempdir()
    local subdir = path.join(root, "crates", "clauders")
    fs.mkdir(subdir)

    local directory = handoff.init(subdir, "20260101-120000", 10, NOW, 120, root)
    local expected = path.join(root, handoff.HANDOFF_REL)
    assert(directory:sub(1, #expected) == expected, directory .. " should sit under " .. expected)
  end,

  without_a_root_a_subdirectory_mints_its_own_tree = function()
    -- The cost of the `cwd` fallback, pinned so it cannot change unnoticed: called from a
    -- subdirectory with no root and no git, `init` builds a second tree there. This is what the
    -- driver's stderr warning exists to make visible.
    local root = fs.tempdir()
    local subdir = path.join(root, "crates")
    fs.mkdir(subdir)

    local directory = handoff.init(subdir, "20260101-120000", 10, NOW, 120)
    assert(directory:sub(1, #subdir) == subdir, directory .. " should sit under " .. subdir)
  end,
}
