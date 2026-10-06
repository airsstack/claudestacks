---
status: approved
created: 2026-10-04
depends-on: [02]
---

# Discuss CLI Implementation Plan

**Goal:** `scripts/discuss.lua` manages a per-session topic index whose discussions outlive the worktree.

**Architecture:** All logic is in `scripts/lib/discuss.lua` as functions that take every varying value — storage root, working directory, session id, time, keep count — as arguments, because the test gate grants no environment variables (spec P17, §5.6). `scripts/discuss.lua` is the only file that reads `HOME`/`AIRSSTACK_HOME`, parses `arg`, and turns errors into a non-zero exit. Storage is `<root>/discussions/<project-key>/<session-id>/index.json` plus `reports/` (spec §5.1). Validation reuses `lib.handoff_report` and plan 02's `lib.comm_report`; the per-repository key is ported from `hooks/lib/enforce.lua:85-174` because `require` cannot reach `hooks/lib/` from `scripts/` (spec P2, P15).

**Tech Stack:** `airsl` Lua 5.4 (`airsstack.fs`, `airsstack.path`, `airsstack.json`, `airsstack.hash`, `airsstack.regex`, `airsstack.time`, `airsstack.stdio`, `airsstack.env`).

---

## File structure

```
plugins/claudestacks/scripts/lib/discuss.lua    — [create] keep parsing, project key, index storage, commands as functions
plugins/claudestacks/scripts/discuss_test.lua   — [create] tests for lib/discuss
plugins/claudestacks/scripts/discuss.lua        — [create] CLI entry: argv, environment, exit status
plugins/claudestacks/skills/snapshot-save/SKILL.md — [modify] the key-port sync note names the new copy
```

Facts this plan encodes, each checked on 2026-10-04 by an `airsl test` probe unless cited:

- `fs.mkdir(p)` creates every missing parent; `fs.list(dir)` returns a table of names; `fs.stat(f)` returns `kind`, `size`, `modified` (epoch seconds); `fs.remove_dir(d)` removes a tree; `fs.read` on a missing file raises `read failed on \`<path>\`: No such file or directory (os error 2)`.
- `airsstack.time.now()` returns epoch seconds; `hash.sha1("abc")` → `a9993e364706816aba3e25717850c26c9cd0d89d`; `fs.canonicalize` of `fs.tempdir()` on macOS returns the `/private/var/…` form.
- `json.encode_pretty({ topics = {} })` writes `"topics": {}` — an empty Lua table encodes as an object. Only this module reads the index, and it treats both forms as an empty list.
- `regex.replace_all(pattern, text, replacement)` is the sanitizer call (`hooks/lib/enforce.lua:36-37`).
- A CLI signals failure with `error(message, 0)` after writing to stdout; `airsl` then exits 1 (`scripts/handoff_report.lua:21-38`; probe: exit 1).
- Script arguments arrive in `arg` (`hooks/enforce.lua:155-160`); the working directory is `airsstack.path.absolute(".")` (`scripts/handoff.lua:56`).
- Test runs go through `cargo make plugins-test` (`Makefile.toml:143`).

The shared test helpers below go at the top of `discuss_test.lua` in Task 1 and are used by every later task:

```lua
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
```

### Task 1 — Parse the keep count

**Files:**
- Test `plugins/claudestacks/scripts/discuss_test.lua`
- Create `plugins/claudestacks/scripts/lib/discuss.lua`

**Steps:**

1. Create `plugins/claudestacks/scripts/discuss_test.lua` with the shared helpers above, followed by:

   ```lua
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
   }
   ```

2. Run it and confirm failure:

   ```
   $ cargo make plugins-test
   …/plugins/claudestacks/scripts/discuss_test.lua: lua error in …/discuss_test.lua: module `lib.discuss` not found under `…/plugins/claudestacks/scripts`
   ```

3. Create `plugins/claudestacks/scripts/lib/discuss.lua`:

   ```lua
   -- The per-session topic index behind /claudestacks:discuss.
   --
   -- Prose authority: `skills/discuss/references/protocol.md` and this chain's spec. Every value a
   -- test varies arrives as an argument; `scripts/discuss.lua` alone reads the environment.

   local comm = require("lib.comm_report")
   local handoff = require("lib.handoff_report")
   local fs = airsstack.fs
   local hash = airsstack.hash
   local json = airsstack.json
   local path = airsstack.path
   local regex = airsstack.regex

   local M = {}

   M.DEFAULT_KEEP = 20

   -- The archive size from `--keep`. Anything that is not a positive integer — including the
   -- literal `${user_config.archive_keep}` an unset option leaves in skill text — is the default.
   function M.keep(value)
     local number = tonumber(value)
     if number and number >= 1 and number == math.floor(number) then
       return number
     end
     return M.DEFAULT_KEEP
   end

   return M
   ```

4. Run it and confirm green:

   ```
   $ cargo make plugins-test
     ok    keep_takes_a_positive_integer
     ok    keep_falls_back_to_twenty_for_anything_else
   ```

   Break it: change `number >= 1` to `number >= 0`, rerun, confirm `FAIL  keep_falls_back_to_twenty_for_anything_else`. Restore.

5. Commit `feat(repo): parse the discuss archive keep count`.

### Task 2 — Port the per-repository key

**Files:**
- Test `plugins/claudestacks/scripts/discuss_test.lua`
- Modify `plugins/claudestacks/scripts/lib/discuss.lua`
- Modify `plugins/claudestacks/skills/snapshot-save/SKILL.md`

**Steps:**

1. Add to the returned table in `discuss_test.lua`:

   ```lua
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
   ```

2. Run it and confirm failure:

   ```
   $ cargo make plugins-test
     FAIL  the_key_matches_the_reference_shell_block
     FAIL  a_linked_worktree_shares_its_main_worktrees_key
     FAIL  outside_a_repository_the_key_hashes_the_directory
   ```

3. Add to `plugins/claudestacks/scripts/lib/discuss.lua`, above `return M`:

   ```lua
   -- The per-repository key, ported from `hooks/lib/enforce.lua:35-174`, whose reference form is
   -- the shell block in `skills/snapshot-save/SKILL.md`. A port rather than a `require` because
   -- `airsl` resolves `require` only beside the running script. Keep the copies in sync.

   -- Every character outside [A-Za-z0-9._-] becomes '-'.
   function M.sanitize(text)
     return (regex.replace_all("[^A-Za-z0-9._-]", text or "", "-"))
   end

   local function realpath(target)
     local ok, resolved = pcall(fs.canonicalize, target)
     return ok and resolved or nil
   end

   -- The nearest ancestor holding `.git`, and that `.git` — or nil outside a repository.
   local function dot_git(cwd)
     local current = realpath(cwd) or cwd
     while true do
       local candidate = path.join(current, ".git")
       local seen, present = pcall(fs.exists, candidate)
       if seen and present then
         return current, candidate
       end
       local parent = path.dirname(current)
       if parent == current or parent == "" then
         return nil, nil
       end
       current = parent
     end
   end

   -- The main repository's `.git`, without running git.
   function M.common_dir(cwd)
     local top, candidate = dot_git(cwd)
     if not top then
       return nil
     end
     local ok, is_file = pcall(fs.is_file, candidate)
     if not ok then
       return nil
     end
     if not is_file then
       return candidate
     end
     local read, text = pcall(fs.read, candidate)
     if not read or not text then
       return nil
     end
     local target = text:match("^%s*gitdir:%s*(.-)%s*$")
     if not target or target == "" then
       return nil
     end
     if not path.is_absolute(target) then
       target = path.join(top, target)
     end
     local parent = path.dirname(target)
     if path.basename(parent) == "worktrees" then
       return path.dirname(parent)
     end
     return target
   end

   -- `<sanitized base>-<first 8 hex of sha1(absolute)>` — the reference block's last three lines.
   function M.key_for(base, absolute)
     return M.sanitize(base) .. "-" .. hash.sha1(absolute):sub(1, 8)
   end

   -- The key of the repository `cwd` sits in, over its physical common dir; outside a repository,
   -- over the physical working directory.
   function M.project_key(cwd)
     local common = M.common_dir(cwd)
     local absolute, base
     if common then
       if not path.is_absolute(common) then
         common = path.join(cwd, common)
       end
       local parent = realpath(path.dirname(common)) or path.dirname(common)
       absolute = path.join(parent, path.basename(common))
       base = path.basename(path.dirname(absolute))
     else
       absolute = realpath(cwd)
       if not absolute then
         return nil
       end
       base = path.basename(absolute)
     end
     return M.key_for(base, absolute)
   end
   ```

4. Run it and confirm green:

   ```
   $ cargo make plugins-test
     ok    the_key_matches_the_reference_shell_block
     ok    a_linked_worktree_shares_its_main_worktrees_key
     ok    outside_a_repository_the_key_hashes_the_directory
   ```

   Break it twice, restoring after each: (a) in `M.key_for`, change `:sub(1, 8)` to `:sub(1, 7)` → `FAIL  the_key_matches_the_reference_shell_block`; (b) in `M.project_key`, replace `local parent = realpath(path.dirname(common)) or path.dirname(common)` with `local parent = path.dirname(common)` → on macOS, `FAIL  a_linked_worktree_shares_its_main_worktrees_key` (the pointer's `/var/…` spelling now hashes differently from the main checkout's `/private/var/…`). If (b) stays green, the platform has no `/var` symlink; record that in the task notes rather than skipping the check silently.

5. In `plugins/claudestacks/skills/snapshot-save/SKILL.md` (line 74 on 2026-10-04), replace

   ```
   `sanitize` character class and an 8-hex-digit hash; `claudestacks-journal`'s
   ```

   with

   ```
   `sanitize` character class and an 8-hex-digit hash; `scripts/lib/discuss.lua`'s `M.project_key`
   is a second Lua copy, kept because `airsl` cannot `require` across `hooks/` and `scripts/`;
   `claudestacks-journal`'s
   ```

6. Commit `feat(repo): port the per-repository key into lib/discuss`.

### Task 3 — Start or resume a discussion

**Files:**
- Test `plugins/claudestacks/scripts/discuss_test.lua`
- Modify `plugins/claudestacks/scripts/lib/discuss.lua`

**Steps:**

1. Add to the returned table:

   ```lua
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
       assert(not pcall(discuss.start, project(), "../evil", 20, NOW))
       assert(not pcall(discuss.start, project(), "", 20, NOW))
     end,
   ```

2. Run it and confirm failure:

   ```
   $ cargo make plugins-test
     FAIL  start_creates_an_open_discussion
     FAIL  start_resumes_an_open_discussion
     FAIL  start_reopens_a_closed_discussion_of_the_same_session
     ok    a_session_id_with_a_path_separator_is_refused
   ```

   The last passes for the wrong reason (`discuss.start` is nil, so `pcall` fails); it is pinned by the mutation in step 4.

3. Add to `plugins/claudestacks/scripts/lib/discuss.lua`, above `return M`:

   ```lua
   -- The storage directory for this project's discussions.
   function M.project_dir(root, cwd)
     return path.join(root, "discussions", M.project_key(cwd) or "unknown")
   end

   -- A session id may name a directory and nothing else.
   function M.check_session(session)
     if type(session) ~= "string" or not session:match("^[%w-]+$") then
       error("invalid session id: " .. tostring(session), 0)
     end
     return session
   end

   -- The index in `dir`, or nil when there is none or it cannot be read.
   function M.load(dir)
     local ok, text = pcall(fs.read, path.join(dir, "index.json"))
     if not ok then
       return nil
     end
     local decoded, index = pcall(json.decode, text)
     if not decoded or type(index) ~= "table" then
       return nil
     end
     if type(index.topics) ~= "table" then
       index.topics = {}
     end
     return index
   end

   -- Writes `index` to `dir`, stamping `touched`.
   function M.save(dir, index, now)
     index.touched = now
     fs.mkdir(dir)
     fs.write(path.join(dir, "index.json"), json.encode_pretty(index) .. "\n")
   end

   -- Opens, resumes or reopens this session's discussion, then prunes the project's others.
   -- Returns the index and whether one already existed.
   function M.start(project, session, keep, now)
     M.check_session(session)
     local dir = path.join(project, session)
     local index = M.load(dir)
     local resumed = index ~= nil
     if not index then
       index = { state = "open", opened = now, topics = {} }
     end
     index.state, index.closed = "open", nil
     M.save(dir, index, now)
     M.prune(project, session, keep)
     return index, resumed
   end

   -- Placeholder until Task 4: keeps every discussion.
   function M.prune()
     return {}
   end
   ```

4. Run it and confirm green:

   ```
   $ cargo make plugins-test
     ok    start_creates_an_open_discussion
     ok    start_resumes_an_open_discussion
     ok    start_reopens_a_closed_discussion_of_the_same_session
     ok    a_session_id_with_a_path_separator_is_refused
   ```

   Break it: change the pattern in `M.check_session` to `"^.+$"`, rerun, confirm `FAIL  a_session_id_with_a_path_separator_is_refused`. Restore.

5. Commit `feat(repo): start or resume a discussion`.

### Task 4 — Prune the archive

**Files:**
- Test `plugins/claudestacks/scripts/discuss_test.lua`
- Modify `plugins/claudestacks/scripts/lib/discuss.lua`

**Steps:**

1. Add to the returned table:

   ```lua
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

     an_abandoned_open_discussion_ages_out_like_a_closed_one = function()
       local dir = project()
       discuss.save(path.join(dir, "crashed"), { state = "open", topics = {} }, NOW)
       discuss.save(path.join(dir, "later"), { state = "closed", topics = {} }, NOW + 1)
       local removed = discuss.prune(dir, "current", 1)
       assert(#removed == 1 and removed[1] == "crashed")
     end,
   ```

2. Run it and confirm failure:

   ```
   $ cargo make plugins-test
     FAIL  prune_keeps_the_newest_n_others_and_never_the_current
     FAIL  an_abandoned_open_discussion_ages_out_like_a_closed_one
   ```

3. In `plugins/claudestacks/scripts/lib/discuss.lua`, replace the placeholder `M.prune` with:

   ```lua
   -- The discussions under `project` other than `current`, as `{ name, index }`, newest first.
   function M.others(project, current)
     local found = {}
     local ok, names = pcall(fs.list, project)
     if not ok then
       return found
     end
     for _, name in ipairs(names) do
       local dir = path.join(project, name)
       local read, is_dir = pcall(fs.is_dir, dir)
       if name ~= current and read and is_dir then
         found[#found + 1] = { name = name, index = M.load(dir) or { touched = 0, topics = {} } }
       end
     end
     table.sort(found, function(a, b)
       return (a.index.touched or 0) > (b.index.touched or 0)
     end)
     return found
   end

   -- Removes every discussion except `current` and the newest `keep` others. Open ones count:
   -- a session that ended without `done` still ages out. Returns the names removed.
   function M.prune(project, current, keep)
     local removed = {}
     for position, other in ipairs(M.others(project, current)) do
       if position > keep and pcall(fs.remove_dir, path.join(project, other.name)) then
         removed[#removed + 1] = other.name
       end
     end
     return removed
   end
   ```

4. Run it and confirm green:

   ```
   $ cargo make plugins-test
     ok    prune_keeps_the_newest_n_others_and_never_the_current
     ok    an_abandoned_open_discussion_ages_out_like_a_closed_one
   ```

   Break it: change `>` to `<` in the `table.sort` comparator, rerun, confirm `FAIL  prune_keeps_the_newest_n_others_and_never_the_current`. Restore.

5. Commit `feat(repo): prune old discussions when one starts`.

### Task 5 — Add a report's topics

**Files:**
- Test `plugins/claudestacks/scripts/discuss_test.lua`
- Modify `plugins/claudestacks/scripts/lib/discuss.lua`

**Steps:**

1. Add to the returned table:

   ```lua
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

     a_thin_report_adds_no_topics = function()
       local index = discuss.start(project(), "s", 20, NOW)
       local added = discuss.add(index, report(fs.tempdir(), "01-a.md", {}))
       assert(added and #added == 0 and #index.topics == 0)
     end,
   ```

2. Run it and confirm failure:

   ```
   $ cargo make plugins-test
     FAIL  add_numbers_topics_after_the_existing_ones
     FAIL  add_refuses_a_report_failing_either_validator
     FAIL  add_requires_the_protocol_key
     FAIL  add_refuses_the_same_report_twice
     FAIL  a_thin_report_adds_no_topics
   ```

3. Add to `plugins/claudestacks/scripts/lib/discuss.lua`, above `return M`:

   ```lua
   -- Validates `file` with both validators and appends its topics to `index` (the caller saves).
   -- Returns the topics added, or nil plus the violations.
   function M.add(index, file)
     for _, topic in ipairs(index.topics) do
       if topic.report == file then
         return nil, { { id = "already-added", line = "already in this discussion: " .. file } }
       end
     end
     local violations = handoff.check(file)
     for _, violation in ipairs(comm.check(file, { require_protocol = true })) do
       violations[#violations + 1] = violation
     end
     if #violations > 0 then
       return nil, violations
     end
     local topics = comm.topics(fs.read_lines(file), 1) or {}
     local added = {}
     for _, topic in ipairs(topics) do
       local entry = {
         id = #index.topics + 1,
         title = topic.title,
         report = file,
         heading = "## " .. topic.n .. ". " .. topic.title,
         read = false,
       }
       index.topics[#index.topics + 1] = entry
       added[#added + 1] = entry
     end
     return added
   end
   ```

4. Run it and confirm green:

   ```
   $ cargo make plugins-test
     ok    add_numbers_topics_after_the_existing_ones
     ok    add_refuses_a_report_failing_either_validator
     ok    add_requires_the_protocol_key
     ok    add_refuses_the_same_report_twice
     ok    a_thin_report_adds_no_topics
   ```

   Break it: remove `{ require_protocol = true }` from the `comm.check` call, rerun, confirm `FAIL  add_requires_the_protocol_key`. Restore.

5. Commit `feat(repo): add a report's topics to the discussion index`.

**Checkpoint:** stop here for the author's review (agreed: inside plan 03, after start/add).

### Task 6 — List this discussion and the archive

**Files:**
- Test `plugins/claudestacks/scripts/discuss_test.lua`
- Modify `plugins/claudestacks/scripts/lib/discuss.lua`

**Steps:**

1. Add to the returned table:

   ```lua
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
   ```

2. Run it and confirm failure:

   ```
   $ cargo make plugins-test
     FAIL  list_shows_id_read_mark_and_title
     FAIL  the_archive_lists_other_discussions_with_their_state
   ```

3. Add to `plugins/claudestacks/scripts/lib/discuss.lua`, above `return M`:

   ```lua
   -- This discussion's topics, one per line: id, `*` once read, title.
   function M.list_lines(index)
     local lines = {}
     for _, topic in ipairs(index.topics) do
       lines[#lines + 1] = string.format("%3d  %s %s", topic.id, topic.read and "*" or " ", topic.title)
     end
     return table.concat(lines, "\n")
   end

   -- Every other discussion's topics, newest discussion first: `<sid8>/<id>  <state>  <title>`.
   function M.archive_lines(project, current)
     local lines = {}
     for _, other in ipairs(M.others(project, current)) do
       for _, topic in ipairs(other.index.topics or {}) do
         lines[#lines + 1] = string.format("%s/%d  %s  %s", other.name:sub(1, 8), topic.id,
           other.index.state or "unknown", topic.title)
       end
     end
     return table.concat(lines, "\n")
   end
   ```

4. Run it and confirm green:

   ```
   $ cargo make plugins-test
     ok    list_shows_id_read_mark_and_title
     ok    the_archive_lists_other_discussions_with_their_state
   ```

   Break it: change `other.name:sub(1, 8)` to `other.name`, rerun, confirm `FAIL  the_archive_lists_other_discussions_with_their_state`. Restore.

5. Commit `feat(repo): list a discussion's topics and the archive`.

### Task 7 — Show one topic

**Files:**
- Test `plugins/claudestacks/scripts/discuss_test.lua`
- Modify `plugins/claudestacks/scripts/lib/discuss.lua`

**Steps:**

1. Add to the returned table:

   ```lua
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
       assert(text == nil and err == "report gone: " .. file)
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

     show_refuses_an_unknown_id = function()
       local dir = project()
       discuss.start(dir, "s", 20, NOW)
       local text, err = discuss.show(dir, "s", "9", NOW)
       assert(text == nil and err == "unknown topic: 9")
     end,
   ```

2. Run it and confirm failure:

   ```
   $ cargo make plugins-test
     FAIL  show_returns_one_section_and_marks_it_read
     FAIL  show_reaches_an_archived_topic_by_sid8
     FAIL  show_names_a_vanished_report
     FAIL  a_plain_subheading_stays_inside_its_topic
     FAIL  show_refuses_an_unknown_id
   ```

3. Add to `plugins/claudestacks/scripts/lib/discuss.lua`, above `return M`:

   ```lua
   -- The `heading` section of `file`'s <detail>: from that heading up to the next topic heading
   -- (`## N. `) or `</detail>`, trailing blank lines dropped. Any other `## ` line inside a topic
   -- stays in it. Nil plus a reason when it cannot be read.
   function M.section(file, heading)
     local ok, lines = pcall(fs.read_lines, file)
     if not ok then
       return nil, "report gone: " .. file
     end
     local kept
     for _, line in ipairs(lines) do
       if kept and (line:match("^## %d+%. ") or line == "</detail>") then
         break
       elseif kept then
         kept[#kept + 1] = line
       elseif line == heading then
         kept = { line }
       end
     end
     if not kept then
       return nil, "section not found: " .. heading .. " in " .. file
     end
     while #kept > 1 and not kept[#kept]:match("%S") do
       kept[#kept] = nil
     end
     return table.concat(kept, "\n")
   end

   -- The discussion directory and topic that `ref` names: `<id>` in this session, or
   -- `<sid8>/<id>` in another. Nil plus a reason otherwise.
   function M.resolve(project, session, ref)
     local prefix, number = tostring(ref):match("^([%w-]+)/(%d+)$")
     local dir
     if prefix then
       for _, other in ipairs(M.others(project, session)) do
         if other.name:sub(1, #prefix) == prefix then
           dir = path.join(project, other.name)
           break
         end
       end
     else
       number = tostring(ref):match("^(%d+)$")
       dir = path.join(project, session)
     end
     local index = dir and number and M.load(dir)
     local topic = index and index.topics[tonumber(number)]
     if not topic then
       return nil, nil, "unknown topic: " .. tostring(ref)
     end
     return dir, index, topic
   end

   -- The section `ref` names, marked read. Nil plus a reason otherwise.
   function M.show(project, session, ref, now)
     local dir, index, topic = M.resolve(project, session, ref)
     if not dir then
       return nil, topic
     end
     local text, err = M.section(topic.report, topic.heading)
     if not text then
       return nil, err
     end
     topic.read = true
     M.save(dir, index, now)
     return text
   end
   ```

   (`M.resolve` returns its reason in the third position; `M.show` passes it on.)

4. Run it and confirm green:

   ```
   $ cargo make plugins-test
     ok    show_returns_one_section_and_marks_it_read
     ok    show_reaches_an_archived_topic_by_sid8
     ok    show_names_a_vanished_report
     ok    a_plain_subheading_stays_inside_its_topic
     ok    show_refuses_an_unknown_id
   ```

   Break it: delete `or line == "</detail>"`, rerun, confirm `FAIL  show_returns_one_section_and_marks_it_read` (`beta` is the last topic, so its section now runs into `</detail>`). Restore. Then change `"^## %d+%. "` to `"^## "`, rerun, confirm `FAIL  a_plain_subheading_stays_inside_its_topic`. Restore.

5. Commit `feat(repo): show one discussion topic`.

### Task 8 — Close and archive

**Files:**
- Test `plugins/claudestacks/scripts/discuss_test.lua`
- Modify `plugins/claudestacks/scripts/lib/discuss.lua`

**Steps:**

1. Add to the returned table:

   ```lua
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
       fs.remove(file)
       local missing = discuss.done(dir, "s", NOW)
       assert(#missing == 1 and missing[1] == file)
       assert(discuss.load(path.join(dir, "s")).state == "closed")
     end,

     done_without_an_open_discussion_is_refused = function()
       local ok, err = discuss.done(project(), "nobody", NOW)
       assert(ok == nil and err == "no open discussion for this session")
     end,
   ```

2. Run it and confirm failure:

   ```
   $ cargo make plugins-test
     FAIL  done_copies_reports_into_the_discussion_and_closes_it
     FAIL  done_records_a_vanished_report_and_still_closes
     FAIL  done_without_an_open_discussion_is_refused
   ```

3. Add to `plugins/claudestacks/scripts/lib/discuss.lua`, above `return M`:

   ```lua
   -- One past the highest two-digit `NN-` prefix in `dir`.
   function M.next_number(dir)
     local highest = 0
     local ok, names = pcall(fs.list, dir)
     for _, name in ipairs(ok and names or {}) do
       local number = tonumber(name:match("^(%d%d)%-") or "")
       if number and number > highest then
         highest = number
       end
     end
     return highest + 1
   end

   -- Copies every cited report into `<dir>/reports/` (reports already there stay), repoints the
   -- index at the copies, and closes the discussion. Returns the report paths that had vanished,
   -- or nil plus a reason when there is no open discussion.
   function M.done(project, session, now)
     local dir = path.join(project, M.check_session(session))
     local index = M.load(dir)
     if not index or index.state ~= "open" then
       return nil, "no open discussion for this session"
     end
     local reports = path.join(dir, "reports")
     fs.mkdir(reports)
     local copied, missing = {}, {}
     for _, topic in ipairs(index.topics) do
       local source = topic.report
       if path.dirname(source) ~= reports and copied[source] == nil then
         local ok, text = pcall(fs.read, source)
         if ok then
           local target = path.join(reports, string.format("%02d-%s", M.next_number(reports),
             path.basename(source)))
           fs.write(target, text)
           copied[source] = target
         else
           copied[source] = false
           missing[#missing + 1] = source
         end
       end
       if copied[source] then
         topic.report = copied[source]
       end
     end
     index.state, index.closed = "closed", now
     M.save(dir, index, now)
     return missing
   end
   ```

4. Run it and confirm green:

   ```
   $ cargo make plugins-test
     ok    done_copies_reports_into_the_discussion_and_closes_it
     ok    done_records_a_vanished_report_and_still_closes
     ok    done_without_an_open_discussion_is_refused
   ```

   Break it: delete the line `topic.report = copied[source]`, rerun, confirm `FAIL  done_copies_reports_into_the_discussion_and_closes_it`. Restore.

5. Commit `feat(repo): close a discussion and archive its reports`.

### Task 9 — Path for a main-thread report

**Files:**
- Test `plugins/claudestacks/scripts/discuss_test.lua`
- Modify `plugins/claudestacks/scripts/lib/discuss.lua`

**Steps:**

1. Add to the returned table:

   ```lua
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
   ```

2. Run it and confirm failure:

   ```
   $ cargo make plugins-test
     FAIL  report_path_numbers_after_existing_reports
     FAIL  report_path_refuses_a_bad_slug_or_no_discussion
   ```

3. Add to `plugins/claudestacks/scripts/lib/discuss.lua`, above `return M`:

   ```lua
   -- The next free `<dir>/reports/NN-main-<slug>.md` for a main-thread report, creating
   -- `reports/`. Nil plus a reason when the slug is bad or no discussion is open.
   function M.report_path(project, session, slug)
     if type(slug) ~= "string" or not slug:match("^[a-z0-9-]+$") then
       return nil, "slug must match [a-z0-9-]+: " .. tostring(slug)
     end
     local dir = path.join(project, M.check_session(session))
     local index = M.load(dir)
     if not index or index.state ~= "open" then
       return nil, "no open discussion for this session"
     end
     local reports = path.join(dir, "reports")
     fs.mkdir(reports)
     return path.join(reports, string.format("%02d-main-%s.md", M.next_number(reports), slug))
   end
   ```

4. Run it and confirm green:

   ```
   $ cargo make plugins-test
     ok    report_path_numbers_after_existing_reports
     ok    report_path_refuses_a_bad_slug_or_no_discussion
   ```

   Break it: change `"%02d-main-%s.md"` to `"%d-main-%s.md"`, rerun, confirm `FAIL  report_path_numbers_after_existing_reports`. Restore.

5. Commit `feat(repo): give main-thread discussion reports a path`.

### Task 10 — The CLI entry

**Files:**
- Create `plugins/claudestacks/scripts/discuss.lua`

**Steps:**

1. Confirm the entry does not exist (red):

   ```
   $ airsl run --policy confined --allow-env HOME --allow-env AIRSSTACK_HOME --allow-read / --allow-write "$HOME/.airsstack" plugins/claudestacks/scripts/discuss.lua start --session plan03-check
   airsl: … No such file or directory …
   ```

2. Create `plugins/claudestacks/scripts/discuss.lua`:

   ```lua
   -- /claudestacks:discuss command line.
   --
   --   airsl run --policy confined --allow-env HOME --allow-env AIRSSTACK_HOME \
   --     --allow-read / --allow-write <airsstack-home> \
   --     scripts/discuss.lua <command> [argument] --session <id> [--keep <n>] [--archive]
   --
   -- Commands: start · add <report> · list [--archive] · show <id|sid8/id> · done ·
   -- report-path <slug>. Prints results on stdout. On failure prints one line on stdout and
   -- exits non-zero. The only file that reads the environment; `lib/discuss.lua` takes arguments.

   local discuss = require("lib.discuss")
   local env = airsstack.env
   local path = airsstack.path
   local stdio = airsstack.stdio

   local function fail(message)
     stdio.write(message .. "\n")
     error(message, 0)
   end

   local function say(text)
     if text and text ~= "" then
       stdio.write(text .. "\n")
     end
   end

   local positional, flags = {}, {}
   local index = 1
   while arg[index] do
     local value = arg[index]
     if value == "--archive" then
       flags.archive = true
     elseif value == "--session" or value == "--keep" then
       flags[value:sub(3)] = arg[index + 1]
       index = index + 1
     else
       positional[#positional + 1] = value
     end
     index = index + 1
   end

   local command = positional[1]
   if not command then
     fail("usage: discuss.lua <start|add|list|show|done|report-path> [argument] --session <id>")
   end
   local ok_session = pcall(discuss.check_session, flags.session)
   if not ok_session then
     fail("invalid or missing --session: " .. tostring(flags.session))
   end

   local function read_env(name)
     local ok, value = pcall(env.get, name)
     return ok and value ~= "" and value or nil
   end
   local root = read_env("AIRSSTACK_HOME") or path.join(read_env("HOME") or "", ".airsstack")
   local project = discuss.project_dir(root, path.absolute("."))
   local session = flags.session
   local now = airsstack.time.now()
   local dir = path.join(project, session)

   if command == "start" then
     local opened, resumed = discuss.start(project, session, discuss.keep(flags.keep), now)
     say((resumed and "resumed" or "started") .. " discussion " .. session:sub(1, 8)
       .. " (" .. #opened.topics .. " topics)")
     say(discuss.list_lines(opened))
   elseif command == "add" then
     local file = positional[2] or fail("usage: discuss.lua add <report> --session <id>")
     local current = discuss.load(dir)
     if not current or current.state ~= "open" then
       fail("no open discussion for this session")
     end
     local added, violations = discuss.add(current, path.absolute(file))
     if not added then
       local lines = {}
       for _, violation in ipairs(violations) do
         lines[#lines + 1] = violation.id .. ": " .. violation.line
       end
       fail(table.concat(lines, "\n"))
     end
     discuss.save(dir, current, now)
     for _, topic in ipairs(added) do
       say(string.format("%3d  %s", topic.id, topic.title))
     end
   elseif command == "list" and flags.archive then
     say(discuss.archive_lines(project, session))
   elseif command == "list" then
     local current = discuss.load(dir)
     if not current then
       fail("no discussion for this session; try: list --archive")
     end
     say(discuss.list_lines(current))
   elseif command == "show" then
     local text, err = discuss.show(project, session, positional[2] or "", now)
     say(text or fail(err))
   elseif command == "done" then
     local missing, err = discuss.done(project, session, now)
     if not missing then
       fail(err)
     end
     for _, file in ipairs(missing) do
       say("missing: " .. file)
     end
     say("closed discussion " .. session:sub(1, 8))
   elseif command == "report-path" then
     local file, err = discuss.report_path(project, session, positional[2])
     say(file or fail(err))
   else
     fail("unknown command: " .. command)
   end
   ```

3. Run every command and its exit cases against a scratch root. The worktree guard refuses fixture `printf`s and multi-command pipelines inline, so the run goes through a script file, as plan 04 does. Resolve the temp directory first with the plain command `echo "$TMPDIR"`; below, `<TMP>` is its output pasted as a literal, without the trailing `/`.

   Create `<TMP>/01-reviewer-plan03.md` with the Write tool, exactly:

   ```
   ---
   agent: reviewer
   task: t
   protocol: discuss/1
   ---
   <summary>
   s
   </summary>
   <topics>
   1. alpha
   </topics>
   <detail>
   ## 1. alpha
   body
   </detail>
   ```

   Create `<TMP>/plan03-cli.sh` with the Write tool:

   ```sh
   # Run from the repository root. The root is created first: granting --allow-write on a path that
   # does not exist yet, under the /var -> /private/var symlink, makes fs.mkdir fail with
   # "outside the granted write roots" (plan-set review, 2026-10-04).
   T='<TMP>'
   mkdir -p "$T/plan03-home"
   run() {
     AIRSSTACK_HOME="$T/plan03-home" airsl run --policy confined \
       --allow-env HOME --allow-env AIRSSTACK_HOME \
       --allow-read / --allow-write "$T/plan03-home" \
       plugins/claudestacks/scripts/discuss.lua "$@" 2>/dev/null
     echo "exit=$?"
   }
   run list --session plan03-check
   run start --session plan03-check --keep '${user_config.archive_keep}'
   run add "$T/01-reviewer-plan03.md" --session plan03-check
   run list --session plan03-check
   run list --archive --session plan03-check
   run show 1 --session plan03-check
   run report-path "Bad Slug" --session plan03-check
   run report-path why-x --session plan03-check
   run done --session plan03-check
   run add "$T/01-reviewer-plan03.md" --session plan03-check
   run show 9 --session plan03-check
   ```

   Run it and compare:

   ```
   $ sh <TMP>/plan03-cli.sh
   no discussion for this session; try: list --archive
   exit=1
   started discussion plan03-c (0 topics)
   exit=0
     1  alpha
   exit=0
     1    alpha
   exit=0
   exit=0
   ## 1. alpha
   body
   exit=0
   slug must match [a-z0-9-]+: Bad Slug
   exit=1
   <TMP>/plan03-home/discussions/<key>/plan03-check/reports/01-main-why-x.md
   exit=0
   closed discussion plan03-c
   exit=0
   no open discussion for this session
   exit=1
   unknown topic: 9
   exit=1
   ```

   `<key>` is this repository's key. `list --archive` prints nothing because no other discussion exists. The `start` line passes `--keep` single-quoted with the literal placeholder (spec P3a) and must not fail. `airsl` also writes a Lua traceback to stderr on each failure; the script discards it. Delete `<TMP>/plan03-home`, the fixture and the script afterwards.

4. Run the gate:

   ```
   $ cargo make plugins
   … 0 failed …
   ```

   (`airsl check` compiles `discuss.lua`; no suite test loads it, by design.)

5. Commit `feat(repo): add the discuss command line`.

## Verification summary (plan-level)

- `cargo make plugins` green, with the twenty-eight `discuss_test.lua` tests among the passes, each seen failing first.
- Task 10 step 3 transcript reproduced, including a non-zero exit for an unknown topic and a `start` that survives the unset-option placeholder.
- Checkpoints: after Task 5 and at the end of the plan.
