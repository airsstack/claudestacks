-- Architecture decision records for the claudestacks-sdlc status board:
-- scans `adrs/`, reads number-list frontmatter values, checks each ADR's seal
-- and supersession, resolves an ADR by number, marks the ADRs a plan
-- disproves, and derives each ADR's board row and the block's heading.
--
-- Code side of the rules whose prose mirror is the ADR section of
-- `references/artifact-chain.md`; the two MUST agree. Nothing here is
-- stored: every ADR is read from its file each time the board is rendered.

local fingerprint = require("lib.fingerprint")

local fs = airsstack.fs
local path = airsstack.path

local M = {}

-- Directory under the chain root that holds every ADR.
M.DIR = "adrs"

-- Legal ADR states; anything else is refused, not guessed.
local STATUSES = {
  draft = true, approved = true, superseded = true, deprecated = true, dropped = true,
}

-- The states that carry a seal. Only an ADR in one of them has its `sealed`
-- checked, and only a valid one can list another ADR in `supersedes`.
local SEALED = { approved = true, superseded = true, deprecated = true }

-- Normalises one number token (e.g. "3", "0003", "  12 ") to the four-digit
-- form ADR file names use. The digit string is padded as text, so a run too
-- long for an integer is kept without padding instead of raising. Non-numeric
-- tokens pass through unchanged so a typo surfaces as an unknown number
-- rather than vanishing.
local function normalize(token)
  local digits = tostring(token):match("^%s*(%d+)%s*$")
  if digits then
    digits = digits:gsub("^0+", "")
    return string.rep("0", 4 - #digits) .. digits
  end
  return tostring(token)
end

-- Reads a number-list frontmatter value (absent, a block list as a table, or
-- an inline "[3, 0007]" string) into a list of four-digit strings, in
-- written order. `%d+` (not `%d%d%d%d`) so a short token like "[3]" is not
-- silently dropped.
function M.numbers(value)
  local list = {}
  if type(value) == "table" then
    for _, item in ipairs(value) do
      list[#list + 1] = normalize(item)
    end
  elseif type(value) == "string" then
    for num in value:gmatch("%d+") do
      list[#list + 1] = normalize(num)
    end
  end
  return list
end

-- Whether `item` is a lister of `num`: an ADR in a sealed state whose
-- `supersedes` names it. Only the status is checked, so while the checks run
-- this holds for an ADR not yet found invalid; once they have run, an invalid
-- ADR has no status and the test reads "a valid lister".
local function lists(item, num)
  if not SEALED[item.status] then
    return false
  end
  for _, listed in ipairs(M.numbers(item.fields.supersedes)) do
    if listed == num then
      return true
    end
  end
  return false
end

-- Whether number token `a` is lower than `b`. Normalised digit strings
-- compare as numbers (a longer run is a larger number, since leading zeros
-- were stripped); a digit string is lower than any other token. This is the
-- order every "lowest number" is reported in, here and in lib/status.
function M.lower(a, b)
  local a_digits, b_digits = a:match("^%d+$"), b:match("^%d+$")
  if a_digits and b_digits then
    if #a ~= #b then
      return #a < #b
    end
    return a < b
  end
  if a_digits or b_digits then
    return a_digits ~= nil
  end
  return a < b
end

-- The set of ADRs on a loop of `supersedes` edges. An edge is a sealed
-- ADR's `supersedes` entry naming exactly one ADR file; "sealed" is the
-- status alone, whether or not the seal is intact. `count` is the number of
-- files each number has. Reads the status the number and status checks left,
-- so it must run before any seal check clears one.
local function on_loops(adrs, count)
  local by_num = {}
  for _, item in ipairs(adrs) do
    by_num[item.num] = item
  end

  local function edges(item)
    local targets = {}
    if SEALED[item.status] then
      for _, listed in ipairs(M.numbers(item.fields.supersedes)) do
        if count[listed] == 1 then
          targets[#targets + 1] = by_num[listed]
        end
      end
    end
    return targets
  end

  local loops = {}
  for _, start in ipairs(adrs) do
    local seen, pending = {}, edges(start)
    while #pending > 0 do
      local item = table.remove(pending)
      if item == start then
        loops[start] = true
        break
      end
      if not seen[item] then
        seen[item] = true
        for _, target in ipairs(edges(item)) do
          pending[#pending + 1] = target
        end
      end
    end
  end
  return loops
end

-- Applies the seal and supersession checks to every ADR the first two checks
-- left valid, in number order, the first check that holds deciding the
-- reason. The checks on the ADR's own seal and `supersedes` come first and
-- need no other ADR's verdict; only the lister checks do, since a lister
-- counts only while valid. Every ADR on a `supersedes` loop is settled
-- before the lister checks are reached, so the walk along listers never
-- returns to an ADR still being settled. Each result is kept once known, for
-- speed only. `count` is the number of files each number has.
local function check_seals(adrs, count)
  local known = {}
  for _, item in ipairs(adrs) do
    known[item.num] = true
  end
  local loops = on_loops(adrs, count)
  local settled = {}
  local settle

  -- The number of the lowest-numbered lister of `item`, or nil.
  local function lister(item)
    for _, other in ipairs(adrs) do
      if lists(other, item.num) then
        settle(other)
        if lists(other, item.num) then
          return other.num
        end
      end
    end
    return nil
  end

  -- The reason `item` is invalid, or nil. A second result is the NEXT of the
  -- row when it is not `fix adr NNNN`.
  local function reason(item)
    local state = item.status
    if SEALED[state] then
      local sealed = item.fields.sealed
      if type(sealed) ~= "string" then
        return "missing sealed"
      end
      if fingerprint.of_text(item.text) ~= sealed then
        return "edited after approval"
      end
      local unknown
      for _, listed in ipairs(M.numbers(item.fields.supersedes)) do
        if not known[listed] and (not unknown or M.lower(listed, unknown)) then
          unknown = listed
        end
      end
      if unknown then
        return "supersedes unknown " .. unknown
      end
      if loops[item] then
        return "supersedes cycle"
      end
    end
    local successor = lister(item)
    if successor and state ~= "superseded" then
      local next_step = state == "approved" and "adr" or "fix adr " .. successor
      return "superseded by " .. successor .. " but still " .. state, next_step
    end
    if state == "superseded" and not successor then
      return "superseded by nothing"
    end
    return nil
  end

  settle = function(item)
    if settled[item] or item.invalid then
      return
    end
    settled[item] = true
    local why, next_step = reason(item)
    if why then
      item.invalid = item.file .. ": " .. why
      item.next = next_step
      item.status = nil
    end
  end

  for _, item in ipairs(adrs) do
    settle(item)
  end
end

-- All ADRs under the chain root, in fs.list order (four digits, so number
-- order). Each is { num, file, fields, text, status, invalid, next,
-- disproven_by }: `fields` and `text` are nil when `read_artifact` rejects the
-- file, `status` is nil whenever `invalid` holds a reason, `next` is the
-- board's NEXT for an invalid ADR when that is not `fix adr NNNN`, and
-- `disproven_by` is the "<chain>/NN" string `mark_disproofs` sets later.
-- Every entry of `adrs/` that is not a file named `NNNN-<topic>.md` is
-- ignored. Empty when `adrs/` is absent, which is the common case.
-- `read_artifact` is lib/status's frontmatter reader, passed in so this
-- module does not require lib/status.
--
-- An ADR is invalid for the first of these that holds: unreadable,
-- unparseable, missing or unknown status; a number another file shares; a
-- sealed state with no `sealed`; a body that no longer matches `sealed`; a
-- `supersedes` naming a number no file has; a place on a `supersedes` loop;
-- a lister that leaves it in a state other than `superseded`; being
-- `superseded` with no lister.
function M.scan(rootdir, read_artifact)
  local adrs = {}
  local base = path.join(rootdir, M.DIR)
  if not (fs.exists(base) and fs.is_dir(base)) then
    return adrs
  end

  local count = {}
  for _, fname in ipairs(fs.list(base)) do
    local num = fname:match("^(%d%d%d%d)%-.+%.md$")
    if num and fs.is_file(path.join(base, fname)) then
      local item = { num = num, file = fname }
      -- read_artifact's second result is the file's text on success and the
      -- reason on failure.
      local fields, detail = read_artifact(path.join(base, fname))
      if not fields then
        item.invalid = fname .. ": " .. detail
      else
        item.fields = fields
        item.text = detail
        if type(fields.status) ~= "string" then
          -- An empty `status:` parses to a table, not a string.
          item.invalid = fname .. ": missing status"
        elseif not STATUSES[fields.status] then
          item.invalid = fname .. ": unknown status " .. fields.status
        else
          item.status = fields.status
        end
      end
      adrs[#adrs + 1] = item
      count[num] = (count[num] or 0) + 1
    end
  end
  for _, item in ipairs(adrs) do
    if count[item.num] > 1 and not item.invalid then
      item.invalid = item.file .. ": duplicate number " .. item.num
      item.status = nil
    end
  end
  check_seals(adrs, count)

  return adrs
end

-- The number of the lowest-numbered lister of `num` among scanned ADRs, or
-- nil. Reads the validity `scan` settled, so an invalid ADR is no lister. Nil
-- as well for a number two or more files share, which names no one ADR.
function M.successor(adrs, num)
  local _, why = M.resolve(adrs, num)
  if why == "ambiguous" then
    return nil
  end
  for _, item in ipairs(adrs) do
    if lists(item, num) then
      return item.num
    end
  end
  return nil
end

-- Resolves an ADR number (already four digits) against the scanned ADRs.
-- Returns the ADR, or nil and "unknown" (no file has that number) or
-- "ambiguous" (two or more files share it). A single invalid file still
-- resolves.
function M.resolve(adrs, num)
  local found, count = nil, 0
  for _, item in ipairs(adrs) do
    if item.num == num then
      found = found or item
      count = count + 1
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

-- Marks every ADR a plan disproves: sets `disproven_by` to "<chain>/NN" on
-- each valid `approved` ADR that exactly one file holds and that a plan which
-- is not `superseded` names in `disproves-adr`. The first chain in list
-- order and its lowest plan decide the value. A chain's intent status is not
-- consulted, so a `done` or `dropped` chain counts; an `invalid` chain
-- counts for nothing, since the plans it did read before the failing file
-- were never trusted. `chains` is lib/status's `scan` result.
function M.mark_disproofs(adrs, chains)
  for _, chain in ipairs(chains) do
    if not chain.invalid then
      for _, plan in ipairs(chain.plans) do
        if plan.status ~= "superseded" then
          for _, num in ipairs(M.numbers(plan["disproves-adr"])) do
            local item = M.resolve(adrs, num)
            if item and item.status == "approved" and not item.disproven_by then
              item.disproven_by = chain.name .. "/" .. plan.num
            end
          end
        end
      end
    end
  end
end

-- The board row of one scanned ADR as STATE and NEXT. Only an invalid ADR, a
-- disproven one (see `mark_disproofs`) or a draft gets a row; any other ADR
-- gives nil.
function M.row(item)
  if item.invalid then
    return "INVALID (" .. item.invalid .. ")", item.next or "fix adr " .. item.num
  end
  if item.status == "approved" and item.disproven_by then
    return "disproven by " .. item.disproven_by, "adr supersede " .. item.num
  end
  if item.status == "draft" then
    return "draft", "approve or drop"
  end
  return nil
end

-- Counted in the heading in this order; an invalid ADR counts as `invalid`
-- whatever its file said.
local HEADING_ORDER = {
  "approved", "superseded", "deprecated", "draft", "dropped", "invalid",
}

-- The heading label of the ADR block: `ADRS: ` and the non-zero counts, in
-- the order of HEADING_ORDER, e.g. "ADRS: 2 approved, 1 draft". Call it only
-- when at least one ADR file exists; for none it reads "ADRS: " with a
-- trailing space.
function M.heading(adrs)
  local counts = {}
  for _, item in ipairs(adrs) do
    local word = item.invalid and "invalid" or item.status
    counts[word] = (counts[word] or 0) + 1
  end
  local parts = {}
  for _, word in ipairs(HEADING_ORDER) do
    if counts[word] then
      parts[#parts + 1] = counts[word] .. " " .. word
    end
  end
  return "ADRS: " .. table.concat(parts, ", ")
end

return M
