-- Roadmaps and milestones for the claudestacks-sdlc status board: scans
-- `roadmaps/`, resolves a chain's `milestone` key, counts progress, and
-- derives each roadmap's and milestone's STATE and NEXT.
--
-- Code side of the rules whose prose mirror is the "Roadmaps and
-- milestones" section of `references/artifact-chain.md`; the two MUST agree.
-- Nothing here is stored: progress is counted from the member chains each
-- time the board is rendered.

local fs = airsstack.fs
local path = airsstack.path

local M = {}

-- Directory under the chain root that holds every roadmap.
M.DIR = "roadmaps"

-- Roadmap names that are refused: `roadmaps/plans/NN-<topic>.md` would match
-- the glob the distill skill reads plans through.
local RESERVED = { plans = true }

-- Legal roadmap and milestone states; anything else is refused, not guessed.
local STATUSES = { draft = true, approved = true, done = true, dropped = true }

-- Reads one roadmap directory into { name, status, invalid, milestones }.
-- Each milestone is { num, file, stem, ref, roadmap, status, invalid,
-- members }, where `ref` is `<roadmap>/<NN>`, `roadmap` is the parent table
-- and `members` is filled by the board. `read_artifact` is lib/status's
-- frontmatter reader, passed in so this module does not require lib/status.
function M.read_roadmap(dir, name, read_artifact)
  local roadmap = { name = name, milestones = {} }

  local file = path.join(dir, "roadmap.md")
  if RESERVED[name] then
    roadmap.invalid = "reserved name"
  elseif not fs.exists(file) then
    roadmap.invalid = "roadmap.md: missing"
  else
    local fields, reason = read_artifact(file)
    if not fields then
      roadmap.invalid = "roadmap.md: " .. reason
    elseif not STATUSES[fields.status] then
      roadmap.invalid = "roadmap.md: unknown status " .. tostring(fields.status)
    else
      roadmap.status = fields.status
    end
  end

  -- Every entry that is not a file named `NN-<topic>.md` is ignored,
  -- roadmap.md included.
  local count = {}
  for _, fname in ipairs(fs.list(dir)) do
    local num = fname:match("^(%d%d)%-.+%.md$")
    if num and fs.is_file(path.join(dir, fname)) then
      local milestone = {
        num = num,
        file = fname,
        stem = fname:sub(1, -4),
        ref = name .. "/" .. num,
        roadmap = roadmap,
        members = {},
      }
      local fields, reason = read_artifact(path.join(dir, fname))
      if not fields then
        milestone.invalid = fname .. ": " .. reason
      elseif not STATUSES[fields.status] then
        milestone.invalid = fname .. ": unknown status " .. tostring(fields.status)
      else
        milestone.status = fields.status
      end
      roadmap.milestones[#roadmap.milestones + 1] = milestone
      count[num] = (count[num] or 0) + 1
    end
  end
  for _, milestone in ipairs(roadmap.milestones) do
    if count[milestone.num] > 1 and not milestone.invalid then
      milestone.invalid = milestone.file .. ": duplicate number " .. milestone.num
      milestone.status = nil
    end
  end

  return roadmap
end

-- All roadmaps under the chain root, in fs.list order. Empty when the
-- `roadmaps/` directory is absent, which is the common case.
function M.scan(rootdir, read_artifact)
  local roadmaps = {}
  local base = path.join(rootdir, M.DIR)
  if not (fs.exists(base) and fs.is_dir(base)) then
    return roadmaps
  end
  for _, name in ipairs(fs.list(base)) do
    local dir = path.join(base, name)
    if fs.is_dir(dir) then
      roadmaps[#roadmaps + 1] = M.read_roadmap(dir, name, read_artifact)
    end
  end
  return roadmaps
end

-- Resolves an intent's `milestone` value against the scanned roadmaps.
-- Returns the milestone, or nil and "unknown" (not `<roadmap>/<NN>`, or no
-- milestone file has that roadmap and number) or "ambiguous" (two files
-- share the number).
function M.resolve(roadmaps, value)
  if type(value) ~= "string" then
    return nil, "unknown"
  end
  local name, num = value:match("^([^/]+)/(%d%d)$")
  if not name then
    return nil, "unknown"
  end
  local found, count = nil, 0
  for _, roadmap in ipairs(roadmaps) do
    if roadmap.name == name then
      for _, milestone in ipairs(roadmap.milestones) do
        if milestone.num == num then
          found = found or milestone
          count = count + 1
        end
      end
    end
  end
  if count == 0 then
    return nil, "unknown"
  end
  if count > 1 then
    return nil, "ambiguous"
  end
  return found
end

-- A milestone's progress: how many members are `done`, out of the members
-- that are not `dropped`. Each member is { status, open }.
function M.progress(milestone)
  local done, total = 0, 0
  for _, member in ipairs(milestone.members) do
    if member.status ~= "dropped" then
      total = total + 1
      if member.status == "done" then
        done = done + 1
      end
    end
  end
  return done, total
end

-- True when a milestone has a member chain that is still a board row.
function M.has_open_member(milestone)
  for _, member in ipairs(milestone.members) do
    if member.open then
      return true
    end
  end
  return false
end

-- STATE and NEXT for one milestone row.
function M.milestone_row(milestone)
  if milestone.invalid then
    return "INVALID (" .. milestone.invalid .. ")", "fix " .. milestone.ref
  end
  local done, total = M.progress(milestone)
  local count = string.format("%d of %d done", done, total)
  local status = milestone.status
  if status == "dropped" then
    return "dropped", ""
  end
  if status == "draft" then
    return "draft, " .. count, "approve or drop"
  end
  if status == "done" then
    if done < total then
      return "INVALID (done with open chains)", "fix " .. milestone.ref
    end
    return "done, " .. count, ""
  end
  -- approved
  if total == 0 then
    return "approved, " .. count, "park scope"
  end
  if done == total then
    return "milestone complete", "roll up"
  end
  return "approved, " .. count, ""
end

-- A roadmap's progress: how many milestones are `done`, out of the
-- milestones that are not `dropped`. An invalid milestone has no status, so
-- it counts as neither and keeps the roadmap open.
function M.roadmap_progress(roadmap)
  local done, total = 0, 0
  for _, milestone in ipairs(roadmap.milestones) do
    if milestone.status ~= "dropped" then
      total = total + 1
      if milestone.status == "done" then
        done = done + 1
      end
    end
  end
  return done, total
end

-- STATE and NEXT for one roadmap row.
function M.roadmap_row(roadmap)
  if roadmap.invalid then
    return "INVALID (" .. roadmap.invalid .. ")", "fix " .. roadmap.name
  end
  local done, total = M.roadmap_progress(roadmap)
  local count = string.format("%d of %d milestones done", done, total)
  local status = roadmap.status
  if status == "dropped" then
    return "dropped", ""
  end
  if status == "draft" then
    return "draft, " .. count, "approve or drop"
  end
  if status == "done" then
    if done < total then
      return "INVALID (done with open milestones)", "fix " .. roadmap.name
    end
    return "done, " .. count, ""
  end
  -- approved
  if total == 0 then
    return "approved, " .. count, "add milestone"
  end
  if done == total then
    return "roadmap complete", "roll up"
  end
  return "approved, " .. count, ""
end

-- Whether a milestone gets a board row. Under a `done` or `dropped` roadmap
-- a milestone that is itself `done` or `dropped` is printed only while it
-- still has an open member chain, so every open member has a row above it.
function M.prints(milestone)
  local parent = milestone.roadmap.status
  if parent ~= "done" and parent ~= "dropped" then
    return true
  end
  if milestone.status ~= "done" and milestone.status ~= "dropped" then
    return true
  end
  return M.has_open_member(milestone)
end

return M
