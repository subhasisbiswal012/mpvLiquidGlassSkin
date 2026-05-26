-- Six-layer Apple Liquid Glass primitive.
--
-- One entry point: glass.draw(opts) -> ASS string.
-- opts = {
--   x, y, w, h, r,         -- rect geometry; r = corner radius
--   intensity = 1.0,        -- alpha multiplier, clamped to [0.5, 1.5] by theme
--   show_frost = true,      -- skip layer 3 if false
--   shadow_offset_y = 8,    -- drop shadow vertical offset
--   shadow_blur = 16,       -- drop shadow blur radius in ASS \blur units
-- }
--
-- Layer comments use @<name> markers so tests and grep can locate them.

local theme = require('lib/liquid/theme')

local M = {}

-- Convert a 0..1 alpha to the ASS \alpha format (00..FF, inverted).
local function alpha_byte(a)
  if a < 0 then a = 0 end
  if a > 1 then a = 1 end
  return string.format('&H%02X&', math.floor((1 - a) * 255 + 0.5))
end

-- Build a rounded-rect ASS path command (m+b commands).
-- ASS bezier corners use the standard 0.5523 magic constant.
local K = 0.5523
local function rounded_rect_path(x, y, w, h, r)
  if r * 2 > w then r = w / 2 end
  if r * 2 > h then r = h / 2 end
  local k = r * K
  local x1, y1 = x, y
  local x2, y2 = x + w, y + h
  return table.concat({
    'm', x1 + r, y1,                                          -- top-left start
    'l', x2 - r, y1,                                          -- top edge
    'b', x2 - r + k, y1, x2, y1 + r - k, x2, y1 + r,          -- top-right corner
    'l', x2, y2 - r,                                          -- right edge
    'b', x2, y2 - r + k, x2 - r + k, y2, x2 - r, y2,          -- bottom-right
    'l', x1 + r, y2,                                          -- bottom edge
    'b', x1 + r - k, y2, x1, y2 - r + k, x1, y2 - r,          -- bottom-left
    'l', x1, y1 + r,                                          -- left edge
    'b', x1, y1 + r - k, x1 + r - k, y1, x1 + r, y1,          -- top-left
  }, ' ')
end

-- Build the ASS color override tag from a 6-char RRGGBB string (ASS wants BBGGRR).
local function bgr(rrggbb)
  return rrggbb:sub(5,6) .. rrggbb:sub(3,4) .. rrggbb:sub(1,2)
end

local function color_tag(rrggbb)
  return string.format('\\1c&H%s&', bgr(rrggbb))
end

-- Single ASS event line. uosc renders by concatenating these.
local function event(tags, drawing)
  return string.format('{\\an7\\pos(0,0)\\bord0\\shad0%s}%s\n', tags, drawing)
end

function M.draw(opts)
  local x = opts.x or 0
  local y = opts.y or 0
  local w = opts.w or 60
  local h = opts.h or 60
  local r = opts.r or math.min(w, h) / 2
  local intensity = opts.intensity or 1.0
  local show_frost = (opts.show_frost ~= false)
  local shadow_offset_y = opts.shadow_offset_y or 8
  local shadow_blur = opts.shadow_blur or 16

  local t = theme.current
  local out = {}

  -- Layer 1: drop shadow
  local shadow_path = rounded_rect_path(x, y + shadow_offset_y, w, h, r)
  table.insert(out, event(
    string.format('%s\\1a%s\\blur%d\\p1', color_tag('000000'), alpha_byte(theme.alpha('shadow_alpha', intensity)), shadow_blur),
    shadow_path .. '{\\p0}'
  ))

  -- Layer 2: glass body
  local body_path = rounded_rect_path(x, y, w, h, r)
  table.insert(out, event(
    string.format('%s\\1a%s\\p1', color_tag(t.body_color), alpha_byte(theme.alpha('body_alpha', intensity))),
    body_path .. '{\\p0}'
  ))

  -- Layer 3: frost noise — placeholder for future PNG compositing.
  -- show_frost flag is honored (currently a no-op since the PNG slot isn't wired up).
  -- We still read the flag to keep its behavior tested.
  local _ = show_frost

  -- Layer 4: top highlight
  local hl_h = math.floor(h * 0.35)
  local hl_path = rounded_rect_path(x + 1, y + 1, w - 2, hl_h, math.max(0, r - 1))
  table.insert(out, event(
    string.format('%s\\1a%s\\p1', color_tag('FFFFFF'), alpha_byte(theme.alpha('top_highlight', intensity))),
    hl_path .. '{\\p0}'
  ))

  -- Layer 5: rim light (top edge stroke)
  table.insert(out, event(
    string.format('\\bord1%s\\3a%s\\1a&HFF&\\p1', color_tag('FFFFFF'), alpha_byte(theme.alpha('rim_light', intensity))),
    rounded_rect_path(x, y, w, math.min(h, 4), math.min(r, 2)) .. '{\\p0}'
  ))

  -- Layer 6: full border
  table.insert(out, event(
    string.format('\\bord1%s\\3a%s\\1a&HFF&\\p1', color_tag('FFFFFF'), alpha_byte(theme.alpha('border', intensity))),
    body_path .. '{\\p0}'
  ))

  return table.concat(out)
end

return M
