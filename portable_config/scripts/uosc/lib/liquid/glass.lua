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

-- Border-color tag for \bord-stroked layers. libass strokes pick up \3c
-- (outline color), not \1c (fill color) — setting only \1c on a stroke
-- layer leaves the outline at the style default, which is opaque black
-- and shows up as a hard dark frame on bright video.
local function border_color_tag(rrggbb)
  return string.format('\\3c&H%s&', bgr(rrggbb))
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

  -- Layer 1: drop shadow.
  -- libass note: \blur only softens the border (\bord) — on a \bord0 filled
  -- drawing it does nothing, leaving a hard dark rectangle. \be (box blur,
  -- iterations) softens the full rendered fill, so use that instead.
  -- Map shadow_blur (px-ish) to \be iterations with a soft cap.
  local be_iters = math.max(1, math.min(10, math.floor(shadow_blur / 3)))
  local shadow_path = rounded_rect_path(x, y + shadow_offset_y, w, h, r)
  table.insert(out, event(
    string.format('%s\\1a%s\\be%d\\p1', color_tag('000000'), alpha_byte(theme.alpha('shadow_alpha', intensity)), be_iters),
    shadow_path .. '{\\p0}'
  ))

  -- Layer 2: glass body. No \be here — even a 1-iter box blur spreads the
  -- (white) body alpha ~1px in every direction, which shows up as a faint
  -- white halo above and around the pebble's top edge. libass's default
  -- AA on the bezier corners is sufficient.
  local body_path = rounded_rect_path(x, y, w, h, r)
  table.insert(out, event(
    string.format('%s\\1a%s\\p1', color_tag(t.body_color), alpha_byte(theme.alpha('body_alpha', intensity))),
    body_path .. '{\\p0}'
  ))

  -- Layer 3: frost noise — placeholder for future PNG compositing.
  -- show_frost flag is honored (currently a no-op since the PNG slot isn't wired up).
  -- We still read the flag to keep its behavior tested.
  local _ = show_frost

  -- Layer 4: top highlight — clipped to the body so it never escapes the
  -- pebble shape, and uses the body's own rounded corners so the top arc
  -- aligns perfectly. The wash drops off well before the bottom of the
  -- pebble (height = 45% of pebble) so it reads as a soft top gradient,
  -- not a separate floating pill.
  local hl_h = math.floor(h * 0.45)
  local hl_path = rounded_rect_path(x, y, w, hl_h, r)
  table.insert(out, event(
    string.format('\\clip(%s)%s\\1a%s\\p1',
      body_path,
      color_tag('FFFFFF'),
      alpha_byte(theme.alpha('top_highlight', intensity))),
    hl_path .. '{\\p0}'
  ))

  -- Inset path for stroked layers: libass renders \bord centered on the
  -- path (0.5px inside, 0.5px outside). Using the body path verbatim made
  -- the stroke poke 0.5px ABOVE the body's top edge, which read as a
  -- faint white sliver floating above each pebble — most visible at the
  -- rounded corners where the curve presents more stroke pixels into the
  -- overflow zone. Insetting by 0.5px keeps the entire \bord1 spread
  -- inside the nominal body bounds.
  local stroke_path = rounded_rect_path(x + 0.5, y + 0.5, w - 1, h - 1, math.max(0, r - 0.5))

  -- Layer 5 (rim light / glass cap) intentionally removed: a 1px stroke
  -- clipped to a 2px band at the top arc rendered as a pixelated white
  -- sliver in libass — subpixel AA on a 1px stroke at that scale is
  -- inadequate, and the artifact is more visible than the glass cue it
  -- was meant to add. The Layer 4 highlight wash now carries the top
  -- edge on its own.

  -- Layer 6: full border on the inset path so the stroke stays inside.
  table.insert(out, event(
    string.format('\\bord1%s\\3a%s\\1a&HFF&\\p1', border_color_tag('FFFFFF'), alpha_byte(theme.alpha('border', intensity))),
    stroke_path .. '{\\p0}'
  ))

  return table.concat(out)
end

return M
