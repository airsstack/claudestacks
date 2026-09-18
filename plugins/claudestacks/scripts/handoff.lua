-- Context Handoff session manager for the claudestacks orchestration.
--
-- Single source of truth (code side) for the handoff tree path, the session liveness lease, and
-- pruning. Prose mirror: `skills/process-guidelines/references/context-handoff.md`. The two MUST
-- agree — change one, change the other.
--
-- Subcommands:
--   init [--root <dir>]  resolve base, mint a session, write .active, prune, print dir + id
--   beat <session-dir>   refresh the session's .active lease (heartbeat)
--   end  <session-dir>   remove the session's .active lease (clean close)
--
--   airsl run --policy confined \
--     --allow-env AIRSSTACK_HANDOFF_KEEP --allow-env AIRSSTACK_HANDOFF_GRACE \
--     --allow-read . --allow-write . \
--     scripts/handoff.lua {init [--root <dir>]|beat <dir>|end <dir>}
--
-- No `--allow-exec git`: a worktree-isolated Claude Code session cannot pass that flag, its guard
-- refusing the whole command over the `git` operand. Full account in the prose mirror above.
-- Without the grant the probe in `lib.handoff.worktree_root` is denied and the working directory
-- is used, which is correct whenever the caller stands at the repository root. A caller standing
-- anywhere else passes `--root <dir>`, an absolute literal path — a variable is refused too. Omit
-- both from a subdirectory and the run still succeeds, minting its tree in the wrong place; the
-- warning below is what makes that visible.

local handoff = require("lib.handoff")
local env = airsstack.env
local stdio = airsstack.stdio

local function die(message)
  stdio.error(message .. "\n")
  error(message, 0)
end

local function number_from(name, fallback)
  local value = tonumber(env.get(name) or "")
  if not value or value < 0 then
    return fallback
  end
  return math.floor(value)
end

-- `arg`, from `first` onwards, as a plain list — what `handoff.parse_init_args` takes.
local function tail(first)
  local args = {}
  local index = first
  while arg[index] do
    args[#args + 1] = arg[index]
    index = index + 1
  end
  return args
end

local command = arg[1]

if command == "init" then
  local cwd = airsstack.path.absolute(".")
  local root, problem = handoff.parse_init_args(tail(2))
  if problem then
    die(problem)
  end
  local directory, id, source = handoff.init(
    cwd,
    os.date("%Y%m%d-%H%M%S"),
    number_from("AIRSSTACK_HANDOFF_KEEP", handoff.DEFAULT_KEEP),
    airsstack.time.now(),
    number_from("AIRSSTACK_HANDOFF_GRACE", handoff.DEFAULT_GRACE_MINUTES),
    root
  )
  -- `cwd` is the answer only when the caller stands at the root, and that cannot be checked with
  -- git — that is the grant this script does without. `.git` beside `cwd` settles it without one:
  -- present, and `cwd` IS the root, so the common case stays quiet. Absent, the tree was probably
  -- minted in the wrong place and only this line would say so.
  if source == "cwd" and not handoff.looks_like_root(cwd) then
    stdio.error(
      "handoff: resolved the root from the working directory ("
        .. cwd
        .. "); pass --root <dir> if that is not the repository root\n"
    )
  end
  stdio.write(directory .. "\n" .. id .. "\n")
elseif command == "beat" then
  if not arg[2] or arg[2] == "" then
    die("beat: missing <session-dir>")
  end
  if not handoff.beat(arg[2]) then
    die("beat: no such session dir: " .. arg[2])
  end
elseif command == "end" then
  if not arg[2] or arg[2] == "" then
    die("end: missing <session-dir>")
  end
  handoff.close(arg[2])
else
  die("usage: handoff.lua {init [--root <dir>]|beat <dir>|end <dir>}")
end
