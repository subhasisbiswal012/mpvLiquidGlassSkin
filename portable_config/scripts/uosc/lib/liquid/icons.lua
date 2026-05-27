-- SF Symbols-style icons as ASS vector paths.
-- All icons designed on a 24x24 grid, centered at (12,12).
-- ASS path syntax: m=move, l=line, b=bezier (3 control points = cubic).

local M = {}

-- Filled triangle pointing right, with all three vertices rounded so the
-- icon reads as a soft modern shape rather than three sharp points. Corner
-- radius ~1.5px in the 24x24 grid; cubic bezier per vertex with the control
-- points sitting at the original (sharp) vertex location.
local PLAY = 'm 7 6.5 l 7 17.5 b 7 19 7 19 8.3 18.25 l 17.7 12.75 b 19 12 19 12 17.7 11.25 l 8.3 5.75 b 7 5 7 5 7 6.5'

-- Two vertical bars with pill-rounded top and bottom ends.
local PAUSE = 'm 7 5.5 b 7 4 10 4 10 5.5 l 10 18.5 b 10 20 7 20 7 18.5 l 7 5.5 m 14 5.5 b 14 4 17 4 17 5.5 l 17 18.5 b 17 20 14 20 14 18.5 l 14 5.5'

-- Triangle pointing left + vertical bar on the left.
local PREV = 'm 8 12 l 18 4 l 18 20 m 6 4 l 6 20'

-- Triangle pointing right + vertical bar on the right.
local NEXT_ = 'm 16 12 l 6 4 l 6 20 m 18 4 l 18 20'

local registry = {
  play   = PLAY,
  pause  = PAUSE,
  prev   = PREV,
  ['next'] = NEXT_,
}

function M.get(name) return registry[name] end

-- Used by `tools/icon-forge.lua` and follow-on milestones to register more icons.
function M.register(name, ass_path) registry[name] = ass_path end

return M
