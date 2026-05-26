-- SF Symbols-style icons as ASS vector paths.
-- All icons designed on a 24x24 grid, centered at (12,12).
-- ASS path syntax: m=move, l=line, b=bezier (3 control points = cubic).

local M = {}

-- Filled triangle pointing right.
local PLAY = 'm 6 4 l 6 20 l 20 12'

-- Two vertical bars.
local PAUSE = 'm 7 4 l 7 20 l 10 20 l 10 4 m 14 4 l 14 20 l 17 20 l 17 4'

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
