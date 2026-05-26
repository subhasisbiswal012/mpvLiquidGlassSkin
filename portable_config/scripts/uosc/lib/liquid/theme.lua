-- Liquid Glass token tables. Flip `current` to switch themes.

local M = {}

M.dark = {
  body_alpha       = 0.40,
  body_color       = '0A0A0C',
  frost_alpha      = 0.06,
  top_highlight    = 0.45,
  rim_light        = 0.75,
  border           = 0.35,
  shadow_alpha     = 0.55,
  ink              = 'FFFFFF',
  ink_alpha        = 0.95,
  ink_dim          = 0.55,
  ink_quiet        = 0.30,
  accent           = 'E8553A',
  progress_fill    = 'FFFFFF',
}

M.light = {
  body_alpha       = 0.65,
  body_color       = 'F4F1EA',
  frost_alpha      = 0.08,
  top_highlight    = 0.55,
  rim_light        = 0.80,
  border           = 0.40,
  shadow_alpha     = 0.20,
  ink              = '0A0A0C',
  ink_alpha        = 0.95,
  ink_dim          = 0.55,
  ink_quiet        = 0.30,
  accent           = 'D43A1F',
  progress_fill    = '0A0A0C',
}

M.current = M.dark

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function M.set(name)
  if M[name] then
    M.current = M[name]
  end
end

-- Returns the named token's value scaled by intensity (clamped to [0.5, 1.5]).
-- Use for alpha tokens; pass intensity=1 for plain lookup.
function M.alpha(token, intensity)
  intensity = clamp(intensity or 1.0, 0.5, 1.5)
  local v = M.current[token]
  if not v then return 0 end
  return v * intensity
end

return M
