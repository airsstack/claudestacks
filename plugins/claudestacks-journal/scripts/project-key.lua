-- Resolve the human-readable `project` floor for a journal note: the repository basename.
--
-- Linked worktrees collapse onto the main repo (by reading `.git`, not by running git); outside a
-- repository the working directory's basename is the floor. The token is sanitised so it is safe
-- as a frontmatter scalar. Deterministic, no side effects, always prints one line, always exits 0.
--
--   airsl run --policy confined --allow-read . scripts/project-key.lua
--
-- No `--allow-exec git`: a worktree-isolated Claude Code session cannot pass that flag — its guard
-- refuses the whole command over the `git` operand — and this script must work there. See
-- `lib/vault.lua`'s `common_dir`.

local vault = require("lib.vault")

local base = vault.project_base()
airsstack.stdio.write(base .. "\n")
