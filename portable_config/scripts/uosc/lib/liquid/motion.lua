-- Easing functions for the Liquid Glass aesthetic.
-- Each takes t in [0,1] and returns a progress value (sometimes >1 for overshoot).

local M = {}

-- When mpv passes --no-osc-animation or the reduced_motion script-opt is set,
-- caller flips this and all easings collapse to the end state.
M.reduced = false

-- Overshoot easing: ~9% overshoot, settles at 1.
-- Decaying sinusoid: 1 - e^(-7t) * cos(8t).
function M.spring_out(t)
  if M.reduced then return 1 end
  if t <= 0 then return 0 end
  if t >= 1 then return 1 end
  return 1 - math.exp(-7 * t) * math.cos(8 * t)
end

-- No-overshoot soft cubic ease-out (approximates cubic-bezier(0.2, 0.8, 0.2, 1)).
function M.spring_settle(t)
  if M.reduced then return 1 end
  if t <= 0 then return 0 end
  if t >= 1 then return 1 end
  local u = 1 - t
  return 1 - (u * u * u)
end

-- Returns (alpha, scale). Alpha 0->1, scale 0.96->1.0.
function M.liquid_fade(t)
  if M.reduced then return 1, 1 end
  if t <= 0 then return 0, 0.96 end
  if t >= 1 then return 1, 1 end
  local eased = M.spring_settle(t)
  return eased, 0.96 + 0.04 * eased
end

function M.apply_reduced(value)
  if value == nil or value == false or value == 'no' or value == 'false' or value == 0 or value == '0' then
    M.reduced = false
  else
    M.reduced = true
  end
end

return M
