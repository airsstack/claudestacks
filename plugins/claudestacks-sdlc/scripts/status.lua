-- Renders the claudestacks-sdlc status board for the current repository.
--
--   airsl run --fail-open --policy confined --allow-read . scripts/status.lua

local status = require("lib.status")
local path = airsstack.path

airsstack.stdio.write(
  status.render(path.join(path.absolute("."), status.ROOT)) .. "\n")
