-- Tests for lib/vault — the helpers every journal script shares.
--
--   airsl test --allow-read /tmp --allow-write /tmp plugins/claudestacks-journal/scripts

local vault = require("lib.vault")
local json = airsstack.json
local fs = airsstack.fs
local path = airsstack.path

return {
  sanitize_replaces_every_character_outside_the_safe_set = function()
    assert(vault.sanitize("my repo/name") == "my-repo-name")
    assert(vault.sanitize("keeps.dots_and-dashes") == "keeps.dots_and-dashes")
    assert(vault.sanitize("") == "")
  end,

  frontmatter_splits_the_fence_from_the_body = function()
    local fields, body = vault.frontmatter("---\ntype: concept\n---\nBody text.\n")
    assert(fields.type == "concept", tostring(fields.type))
    assert(body == "Body text.\n", string.format("%q", body))
  end,

  a_note_without_a_fence_has_no_frontmatter_and_is_not_an_error = function()
    local fields, body = vault.frontmatter("Just a body.\n")
    assert(next(fields) == nil, "expected no fields")
    assert(body == "Just a body.\n")
  end,

  an_unterminated_fence_is_reported_rather_than_guessed_at = function()
    local fields, reason = vault.frontmatter("---\ntype: concept\nno close\n")
    assert(fields == nil, "an unterminated fence must not parse")
    assert(reason:find("unterminated", 1, true), reason)
  end,

  a_frontmatter_line_without_a_colon_is_reported = function()
    local fields, reason = vault.frontmatter("---\nthis line has no colon\n---\n")
    assert(fields == nil)
    assert(reason:find("without ':'", 1, true), reason)
  end,

  an_inline_flow_list_parses_as_a_list = function()
    local fields = vault.frontmatter("---\ndomains: [rust, async]\n---\n")
    assert(json.encode(fields.domains) == '["rust","async"]', json.encode(fields.domains))
  end,

  an_empty_flow_list_parses_as_an_empty_list = function()
    local fields = vault.frontmatter("---\ndomains: []\n---\n")
    assert(type(fields.domains) == "table")
    assert(#fields.domains == 0)
  end,

  a_block_list_parses_as_a_list = function()
    local fields = vault.frontmatter("---\ntags:\n  - tokio\n  - async\ntype: concept\n---\n")
    assert(json.encode(fields.tags) == '["tokio","async"]', json.encode(fields.tags))
    assert(fields.type == "concept", "a scalar after a block list must still parse")
  end,

  quotes_around_a_scalar_are_stripped = function()
    local fields = vault.frontmatter('---\ntitle: "Quoted title"\nother: \'single\'\n---\n')
    assert(fields.title == "Quoted title", fields.title)
    assert(fields.other == "single", fields.other)
  end,

  scalar_joins_a_list_the_way_the_shell_rendered_it = function()
    assert(vault.scalar({ "a", "b" }) == "a, b")
    assert(vault.scalar("plain") == "plain")
    assert(vault.scalar(nil) == "")
  end,

  as_list_normalises_every_shape_to_a_list_of_strings = function()
    assert(#vault.as_list(nil) == 0)
    assert(json.encode(vault.as_list("one")) == '["one"]')
    assert(json.encode(vault.as_list({ "a", "b" })) == '["a","b"]')
  end,

  sort_rows_orders_element_by_element_like_a_tuple = function()
    local rows = vault.sort_rows({ { "b", "1" }, { "a", "2" }, { "a", "1" } })
    assert(rows[1][1] == "a" and rows[1][2] == "1", "got " .. json.encode(rows))
    assert(rows[2][1] == "a" and rows[2][2] == "2")
    assert(rows[3][1] == "b")
  end,

  a_shorter_row_sorts_before_its_own_prefix_extension = function()
    local rows = vault.sort_rows({ { "a", "b" }, { "a" } })
    assert(#rows[1] == 1, "the shorter row must come first")
  end,

  unquote_strips_one_surrounding_pair_and_the_space_around_it = function()
    assert(vault.unquote('  "spaced"  ') == "spaced")
    assert(vault.unquote("'single'") == "single")
    assert(vault.unquote("bare") == "bare")
  end,

  an_unpaired_quote_is_left_alone = function()
    assert(vault.unquote('"opened') == '"opened', vault.unquote('"opened'))
    assert(vault.unquote("closed'") == "closed'")
    assert(vault.unquote("\"mixed'") == "\"mixed'")
  end,

  only_the_outermost_quote_pair_comes_off = function()
    assert(vault.unquote('""nested""') == '"nested"', vault.unquote('""nested""'))
  end,

  parse_value_returns_a_scalar_when_there_is_no_flow_list = function()
    assert(vault.parse_value(' "concept" ') == "concept")
    assert(vault.parse_value("plain") == "plain")
  end,

  parse_value_splits_a_flow_list_and_unquotes_each_item = function()
    assert(json.encode(vault.parse_value('[rust, "async", \'tokio\']')) == '["rust","async","tokio"]')
    assert(json.encode(vault.parse_value("[one]")) == '["one"]')
  end,

  an_empty_or_blank_flow_list_is_a_list_and_not_a_scalar = function()
    -- Both spellings must reach the `{}` branch: falling through to `unquote` would hand a
    -- consumer the string "[]" where it expects something it can iterate.
    assert(json.encode(vault.array(vault.parse_value("[]"))) == "[]")
    assert(json.encode(vault.array(vault.parse_value("[   ]"))) == "[]")
  end,

  array_encodes_as_a_json_array_even_when_it_is_empty = function()
    -- The whole reason the helper exists: a bare `{}` encodes as an object, so an empty
    -- `orphans` field would ship as `{}` and break every consumer expecting a list.
    assert(json.encode(vault.array({})) == "[]", json.encode(vault.array({})))
    assert(json.encode(vault.array(nil)) == "[]")
    assert(json.encode(vault.array({ "a", "b" })) == '["a","b"]')
  end,

  sorted_keys_orders_the_keys_and_survives_an_empty_map = function()
    assert(json.encode(vault.sorted_keys({ b = 1, a = 2, c = 3 })) == '["a","b","c"]')
    assert(#vault.sorted_keys({}) == 0)
  end,

  -- The project floor without git. `--allow-exec git` cannot be passed from a worktree-isolated
  -- Claude Code session — the guard refuses the whole command over that operand — so the floor has
  -- to come from `.git` itself, which carries the same answer `rev-parse --git-common-dir` gives.

  the_common_dir_of_a_plain_checkout_is_its_own_dot_git = function()
    local repo = fs.tempdir()
    fs.mkdir(path.join(repo, ".git"))
    assert(vault.common_dir(repo) == path.join(repo, ".git"), tostring(vault.common_dir(repo)))
  end,

  a_linked_worktree_resolves_to_the_main_repository_dot_git = function()
    -- What `.git` holds in a linked worktree, verbatim: a gitdir pointer into the main repo.
    local main = fs.tempdir()
    fs.mkdir(path.join(main, ".git"))
    local tree = fs.tempdir()
    fs.write(path.join(tree, ".git"), "gitdir: " .. path.join(main, ".git", "worktrees", "wt") .. "\n")

    assert(vault.common_dir(tree) == path.join(main, ".git"), tostring(vault.common_dir(tree)))
  end,

  a_subdirectory_finds_the_checkout_above_it = function()
    local repo = fs.tempdir()
    fs.mkdir(path.join(repo, ".git"))
    local deep = path.join(repo, "crates", "clauders")
    fs.mkdir(deep)
    assert(vault.common_dir(deep) == path.join(repo, ".git"), tostring(vault.common_dir(deep)))
  end,

  outside_a_repository_there_is_no_common_dir = function()
    assert(vault.common_dir(fs.tempdir()) == nil)
  end,

  every_worktree_of_one_repository_shares_the_project_floor = function()
    -- The point of the whole resolution: notes from a linked worktree file under the main repo's
    -- name, not the worktree directory's.
    local main = fs.tempdir()
    fs.mkdir(path.join(main, ".git"))
    local tree = fs.tempdir()
    fs.write(path.join(tree, ".git"), "gitdir: " .. path.join(main, ".git", "worktrees", "wt") .. "\n")

    assert(vault.project_base(tree) == vault.project_base(main), vault.project_base(tree))
    assert(vault.project_base(tree) == vault.sanitize(path.basename(main)), vault.project_base(tree))
  end,

  a_malformed_dot_git_file_stops_the_ascent = function()
    -- Real git refuses rather than looking further up: `fatal: invalid gitfile format`, exit 128.
    -- Ascending past it would answer with the outer repository, which is a different repository
    -- from the one the caller is standing in. `lib/enforce.lua`'s `common_dir` must agree.
    local outer = fs.tempdir()
    fs.mkdir(path.join(outer, ".git"))
    local child = path.join(outer, "child")
    fs.mkdir(child)
    fs.write(path.join(child, ".git"), "not a gitdir pointer\n")

    assert(vault.common_dir(child) == nil, tostring(vault.common_dir(child)))
  end,

  outside_a_repository_the_project_floor_is_the_directory_name = function()
    local loose = fs.tempdir()
    assert(vault.project_base(loose) == vault.sanitize(path.basename(loose)), vault.project_base(loose))
  end,
}
