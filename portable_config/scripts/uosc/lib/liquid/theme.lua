-- Liquid Glass token tables. Flip `current` to switch themes.

local M = {}

-- Token values per design spec §6 (six-layer glass primitive).
-- Body is white at low alpha in BOTH themes — the "dark" / "light" feel
-- comes from highlight/rim contrast and the ink (text) color, not from a
-- dark body fill. A dark body fill reads as an opaque plate, not glass.
M.dark = {
  body_alpha       = 0.08,
  body_color       = 'FFFFFF',
  frost_alpha      = 0.06,
  top_highlight    = 0.18,
  rim_light        = 0.45,
  border           = 0.10,
  shadow_alpha     = 0.30,
  ink              = 'FFFFFF',
  ink_alpha        = 0.95,
  ink_dim          = 0.55,
  ink_quiet        = 0.30,
  accent           = 'E8553A',
  progress_fill    = 'FFFFFF',
}

M.light = {
  body_alpha       = 0.18,
  body_color       = 'FFFFFF',
  frost_alpha      = 0.08,
  top_highlight    = 0.28,
  rim_light        = 0.60,
  border           = 0.12,
  shadow_alpha     = 0.32,
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
