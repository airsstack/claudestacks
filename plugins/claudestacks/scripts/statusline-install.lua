-- Install, inspect, or remove the Claude Code status line — machine-wide (global) or scoped to
-- one project.
--
-- NOT plugin content — see statusline.lua. Driven by skills/statusline/SKILL.md.
--
--   airsl run --allow-env HOME --allow-read "$HOME/.claude" --allow-write "$HOME/.claude" \
--     plugins/claudestacks/scripts/statusline-install.lua <dry-run|apply|uninstall> \
--       [--project] [base] [source]
--
-- Global (default): installs into $HOME/.claude, copies the driver and lib into
-- <base>/statusline/, and writes an absolute command into settings.json — right for a
-- machine-wide status line.
--
-- --project: scopes the install to one project. Writes to .claude/settings.local.json — Claude
-- Code's own per-machine, git-ignored local settings file — points the command straight at
-- <source>/statusline.lua with no copying at all, and defaults `base` to the project's own
-- .claude directory. settings.local.json is personal by that convention alone; this module does
-- not inspect git state to decide anything.
--
-- `--project` may appear anywhere among the arguments and is stripped before positional parsing.
--
-- The base directory is an argument, defaulting to $HOME/.claude (or, in project mode, the
-- project's own .claude), so the tests exercise this exact code path against fs.tempdir() rather
-- than a stub.

local fs = airsstack.fs
local json = airsstack.json
local path = airsstack.path
local env = airsstack.env
local proc = airsstack.proc

local M = {}

M.DIR = "statusline"
M.SETTINGS = "settings.json"
M.BACKUP = "settings.json.bak"
M.PROJECT_SETTINGS = "settings.local.json"
M.PROJECT_BACKUP = "settings.local.json.bak"
M.PROJECT_BASE = ".claude"
M.GRANTS = "run --fail-open --allow-exec git --allow-env HOME"

local function settings_filename(project)
  return project and M.PROJECT_SETTINGS or M.SETTINGS
end

local function backup_filename(project)
  return project and M.PROJECT_BACKUP or M.BACKUP
end

local function settings_path(base, project)
  return path.join(base, settings_filename(project))
end

local function backup_path(base, project)
  return path.join(base, backup_filename(project))
end

-- The script path the written command points at. Global mode always resolves under
-- <base>/statusline/ — the copy apply makes there. Project mode always resolves under
-- <source_dir> directly, since apply never copies anything in that mode; a source_dir is
-- meaningless without it, which is why project mode requires one.
local function script_path(base, source_dir, project)
  if project then
    return path.join(source_dir, "statusline.lua")
  end
  return path.join(base, M.DIR, "statusline.lua")
end

-- The exact command string written into the settings file. The airsl path is absolute because
-- the status line runs under whatever PATH Claude Code hands it, and airsl lives in
-- ~/.cargo/bin.
function M.command_string(base, airsl, source_dir, project)
  return airsl .. " " .. M.GRANTS .. " " .. script_path(base, source_dir, project)
end

-- Ours if the command string ends with our script path under this base (or, in project mode,
-- this source); anything else — even a wrapper that merely mentions the path in the middle (a
-- `timeout` shim, an `sh -c` chain) — counts as foreign. This must be an ends-with test, not a
-- substring-anywhere test: the latter would classify a command that only quotes our path as ours
-- and silently overwrite it.
function M.is_ours(command, base, source_dir, project)
  if type(command) ~= "string" then
    return false
  end
  local suffix = script_path(base, source_dir, project)
  return command:sub(-#suffix) == suffix
end

-- Read settings. Returns table, error. A missing file is {} with no error — the fresh-machine
-- path. Malformed JSON is an error, never a silent reset.
local function read_settings(base, project)
  local p = settings_path(base, project)
  if not fs.exists(p) then
    return {}, nil
  end
  local raw = fs.read(p)
  local ok, decoded = pcall(json.decode, raw)
  if not ok or type(decoded) ~= "table" then
    return nil, settings_filename(project) .. " is not valid JSON — refusing to write: " .. p
  end
  return decoded, nil
end

-- What apply would do, without doing it.
-- The two files apply keeps in step, as {source, installed} pairs. One list so inspect and apply
-- can never disagree about what "installed" means.
local function file_pairs(base, source_dir)
  local target = path.join(base, M.DIR)
  return {
    { path.join(source_dir, "statusline.lua"), path.join(target, "statusline.lua") },
    { path.join(source_dir, "lib", "statusline.lua"), path.join(target, "lib", "statusline.lua") },
  }
end

-- Would apply copy anything? Read-only: the comparison must never repair what it notices.
-- Project mode never copies, so it always reports false — not a special case at the call site,
-- but the honest answer for a mode where apply makes no copy to compare against.
function M.source_differs(base, source_dir, project)
  if project or not source_dir then
    return false
  end
  for _, pair in ipairs(file_pairs(base, source_dir)) do
    local from, to = pair[1], pair[2]
    if fs.exists(from) and not (fs.exists(to) and fs.same_content(from, to)) then
      return true
    end
  end
  return false
end

function M.inspect(base, airsl, source_dir, project)
  if project and not source_dir then
    return { ok = false, message = "project mode requires a source directory" }
  end

  local settings, err = read_settings(base, project)
  if err then
    return { ok = false, message = err }
  end
  local existing = settings.statusLine
  if existing and not M.is_ours(existing.command, base, source_dir, project) then
    return {
      ok = false,
      message = "a statusLine is already set and is not ours: "
        .. tostring(existing.command) .. " — refusing to overwrite",
    }
  end
  local want = M.command_string(base, airsl, source_dir, project)
  local sp = script_path(base, source_dir, project)
  if existing and existing.command == want and fs.exists(sp) then
    -- The settings key is right and the script is there, but a source file may still have moved
    -- on. Reporting no-op here would hand the caller the one receipt SKILL.md says to stop on,
    -- in exactly the case where re-applying is what they need.
    if M.source_differs(base, source_dir, project) then
      return {
        ok = true,
        noop = false,
        message = "would re-copy the status line at " .. sp .. " — the source changed",
      }
    end
    return { ok = true, noop = true, message = "already installed at " .. sp }
  end
  return { ok = true, noop = false, message = "would install the status line at " .. sp }
end

function M.dry_run(base, airsl, source_dir, project)
  return M.inspect(base, airsl, source_dir, project)
end

-- Resolve the `airsl` binary path without letting proc.which crash the installer: under the
-- confined policy it *raises* when `airsl` is not in --allow-exec, and returns nil when it is
-- granted but simply missing from PATH. Both are the same "stop, report" case to the caller, so
-- both collapse to a nil return here rather than one of them producing a traceback.
function M.resolve_airsl()
  local ok, result = pcall(proc.which, "airsl")
  if not ok then
    return nil
  end
  return result
end

-- Copy one file only when it differs, so editing the repository copy re-syncs while an
-- unchanged file is left alone.
local function sync(from, to)
  if fs.exists(to) and fs.same_content(from, to) then
    return false
  end
  fs.mkdir(path.dirname(to))
  fs.copy(from, to)
  return true
end

function M.apply(base, airsl, source_dir, project)
  local planned = M.inspect(base, airsl, source_dir, project)
  if not planned.ok then
    return planned
  end

  local settings = read_settings(base, project)

  -- Project mode never copies: the command points straight at source_dir, so there is nothing
  -- under <base>/statusline/ to create or keep in sync.
  local copied = false
  if not project then
    local target = path.join(base, M.DIR)
    fs.mkdir(target)
    if source_dir then
      for _, pair in ipairs(file_pairs(base, source_dir)) do
        copied = sync(pair[1], pair[2]) or copied
      end
    end
  end

  local want = M.command_string(base, airsl, source_dir, project)
  local sp = script_path(base, source_dir, project)
  local current = settings.statusLine and settings.statusLine.command
  if current == want and not copied then
    return { ok = true, noop = true, message = "already installed at " .. sp }
  end

  -- Back up only a real change, and never over an existing backup: a blind backup would let a
  -- second apply overwrite the pre-install copy with the already-patched file.
  local settings_p = settings_path(base, project)
  local bp = backup_path(base, project)
  if current ~= want and fs.exists(settings_p) and not fs.exists(bp) then
    fs.copy(settings_p, bp)
  end

  settings.statusLine = { type = "command", command = want }
  fs.atomic_write(settings_p, json.encode_pretty(settings))
  return { ok = true, noop = false, message = "installed the status line at " .. sp }
end

-- Unconditional: unlike apply, uninstall does not check is_ours before clearing statusLine or
-- removing <base>/statusline. This is the escape hatch a foreign (e.g. bash) status line entry
-- gets cleared through, so it stays unconditional on purpose — see statusline_install_test.lua
-- for the tests that pin this asymmetry.
--
-- Project mode never deletes a directory: <base>/statusline/ is a global-mode artifact only, and
-- uninstall never created anything under source_dir to begin with, so there is nothing of ours to
-- remove there.
function M.uninstall(base, project)
  local settings, err = read_settings(base, project)
  if err then
    return { ok = false, message = err }
  end
  local sp = settings_path(base, project)
  local had_status_line = settings.statusLine ~= nil

  -- Back up before destroying a statusLine, under apply's rule: only on a real change, and never
  -- over an existing backup. uninstall is the documented escape hatch for clearing someone
  -- else's statusLine, so it is the path most likely to be aimed at a foreign command — losing
  -- that command with no copy would undo the protection apply's refusal exists to provide.
  local bp = backup_path(base, project)
  if had_status_line and fs.exists(sp) and not fs.exists(bp) then
    fs.copy(sp, bp)
  end

  -- Rewriting the settings file (through json.encode_pretty) reformats it, so that write is
  -- skipped entirely when there is no statusLine key to remove — otherwise an uninstall on a
  -- machine that never had our status line would silently reformat the user's file for no reason.
  if had_status_line then
    settings.statusLine = nil
    if fs.exists(sp) then
      fs.atomic_write(sp, json.encode_pretty(settings))
    end
  end

  local target = path.join(base, M.DIR)
  local removed_dir = false
  if not project then
    removed_dir = fs.exists(target)
    if removed_dir then
      fs.remove_dir(target)
    end
  end

  if not had_status_line and not removed_dir then
    return { ok = true, noop = true, message = "no status line to remove at " .. base }
  end

  local message = "removed the status line from " .. base
  if removed_dir then
    message = message .. " and deleted " .. target
  end
  return { ok = true, noop = false, message = message }
end

-- Driver: only when run directly, so `require` from the tests does not execute anything. Under
-- `airsl test`, arg[0] is the test file's own path, never this module's, so the guard below stays
-- inert during the suite — pinned by statusline_install_test.lua.
if arg and arg[0] and arg[0]:find("statusline%-install%.lua$") then
  -- --project may appear anywhere among the arguments; strip it before positional parsing so
  -- `mode`/`base`/`source` land on the same argument slots regardless of where the flag sat.
  local positional = {}
  local project = false
  for i = 1, #arg do
    if arg[i] == "--project" then
      project = true
    else
      positional[#positional + 1] = arg[i]
    end
  end

  local mode = positional[1] or "dry-run"
  local base = positional[2]
  if not base then
    base = project and path.absolute(M.PROJECT_BASE) or path.join(env.get("HOME") or "", ".claude")
  end
  local source = positional[3]

  local receipt
  if mode == "uninstall" then
    -- uninstall never touches airsl's own path, so it never calls proc.which for it: the escape
    -- hatch should not need an --allow-exec airsl grant the other two modes require.
    receipt = M.uninstall(base, project)
  else
    local airsl = M.resolve_airsl()
    if not airsl then
      receipt = { ok = false, message = "airsl is not on PATH — cannot write a runnable command" }
    elseif mode == "apply" then
      receipt = M.apply(base, airsl, source, project)
    else
      receipt = M.dry_run(base, airsl, source, project)
    end
  end
  airsstack.stdio.write(receipt.message .. "\n")
  -- No os.exit here: the confined policy does not expose it (`os.exit` is nil, verified). The
  -- receipt text is the signal the skill reads, which is what the spec already specifies.
end

return M
