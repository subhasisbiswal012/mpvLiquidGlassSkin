-- SF Symbols-style icon registry for the Liquid Glass skin.
--
-- Entries can be one of two forms:
--
--   1. Legacy string — a single ASS drawing path on a 24x24 grid that
--      should be FILLED. Kept for the inline icons authored before the
--      SVG pipeline shipped, plus as the fallback when assets/ is
--      missing.
--
--   2. Shape list — { {ass_path, mode, stroke_width, opacity}, ... }
--      Produced by lib/liquid/svg.lua at startup from SVG files in
--      assets/icons/. Each shape can independently fill or stroke,
--      letting one icon mix solid blobs with outlined strokes (e.g.
--      the info square: outlined frame + solid dot + stroked stem).
--
-- Names are aligned with upstream uosc's icon registry where they
-- overlap (volume_*, crop_square, close, minimize), so patched
-- elements can pass stock uosc icon strings straight into draw_at().

local M = {}

-- ===== M1 / M2 fallback paths (filled, used when no SVG present) =====

local PLAY = 'm 7 6.5 l 7 17.5 b 7 19 7 19 8.3 18.25 l 17.7 12.75 b 19 12 19 12 17.7 11.25 l 8.3 5.75 b 7 5 7 5 7 6.5'

local PAUSE = 'm 7 5.5 b 7 4 10 4 10 5.5 l 10 18.5 b 10 20 7 20 7 18.5 l 7 5.5 m 14 5.5 b 14 4 17 4 17 5.5 l 17 18.5 b 17 20 14 20 14 18.5 l 14 5.5'

local PREV = 'm 4 5 l 7 5 l 7 19 l 4 19 l 4 5 m 20 5 l 20 19 l 8 12 l 20 5'
local NEXT_ = 'm 4 5 l 16 12 l 4 19 l 4 5 m 17 5 l 20 5 l 20 19 l 17 19 l 17 5'

local FORWARD_10 =
  'm 12 4 l 12 7 l 17 7 b 19 7 21 9 21 12 b 21 16 17 19 13 19 b 9 19 5 16 5 12 ' ..
  'm 11 10 l 11 16 m 13 11 b 13 10 17 10 17 13 b 17 16 13 16 13 15'
local REWIND_10 =
  'm 12 4 l 12 7 l 7 7 b 5 7 3 9 3 12 b 3 16 7 19 11 19 b 15 19 19 16 19 12 ' ..
  'm 9 10 l 9 16 m 11 11 b 11 10 15 10 15 13 b 15 16 11 16 11 15'

local _SPEAKER = 'm 3 9 l 7 9 l 13 4 l 13 20 l 7 15 l 3 15 l 3 9'
local VOLUME_OFF = _SPEAKER .. ' m 17 8 l 23 16 m 23 8 l 17 16'
local VOLUME_MUTE = _SPEAKER
local VOLUME_DOWN = _SPEAKER .. ' m 16 9 b 19 10.5 19 13.5 16 15'
local VOLUME_UP = _SPEAKER ..
  ' m 16 9 b 19 10.5 19 13.5 16 15' ..
  ' m 18 5 b 23 8 23 16 18 19'

local FULLSCREEN_ENTER =
  'm 3 3 l 9 3 l 9 5 l 5 5 l 5 9 l 3 9 l 3 3 ' ..
  'm 15 3 l 21 3 l 21 9 l 19 9 l 19 5 l 15 5 l 15 3 ' ..
  'm 3 15 l 5 15 l 5 19 l 9 19 l 9 21 l 3 21 l 3 15 ' ..
  'm 19 15 l 21 15 l 21 21 l 15 21 l 15 19 l 19 19 l 19 15'

local FULLSCREEN_EXIT =
  'm 3 8 l 8 8 l 8 3 l 10 3 l 10 10 l 3 10 l 3 8 ' ..
  'm 14 3 l 16 3 l 16 8 l 21 8 l 21 10 l 14 10 l 14 3 ' ..
  'm 3 14 l 10 14 l 10 21 l 8 21 l 8 16 l 3 16 l 3 14 ' ..
  'm 14 14 l 21 14 l 21 16 l 16 16 l 16 21 l 14 21 l 14 14'

local PIP =
  'm 3 5 l 21 5 b 22 5 22 5 22 6 l 22 18 b 22 19 22 19 21 19 l 3 19 b 2 19 2 19 2 18 l 2 6 b 2 5 2 5 3 5 ' ..
  'm 13 12 l 20 12 l 20 17 l 13 17 l 13 12'

local SUBTITLE =
  'm 3 5 l 21 5 b 22 5 23 6 23 7 l 23 17 b 23 18 22 19 21 19 l 3 19 b 2 19 1 18 1 17 l 1 7 b 1 6 2 5 3 5 ' ..
  'm 7 9 b 5 9 5 15 7 15 l 9 15 l 9 13 l 8 13 b 7 13 7 11 8 11 l 9 11 l 9 9 l 7 9 ' ..
  'm 15 9 b 13 9 13 15 15 15 l 17 15 l 17 13 l 16 13 b 15 13 15 11 16 11 l 17 11 l 17 9 l 15 9'

local AUDIO_TRACK =
  'm 7 4 l 19 2 l 19 3 l 9 5 l 9 15 ' ..
  'b 9 18 5 18 5 15 b 5 12 9 12 9 15 l 9 5 ' ..
  'm 19 3 l 19 13 b 19 16 15 16 15 13 b 15 10 19 10 19 13'

local CHAPTER_LIST =
  'm 4 6 l 6 6 m 9 6 l 20 6 ' ..
  'm 4 12 l 6 12 m 9 12 l 20 12 ' ..
  'm 4 18 l 6 18 m 9 18 l 20 18'

local PLAYLIST =
  'm 4 7 l 20 7 ' ..
  'm 4 12 l 20 12 ' ..
  'm 4 17 l 16 17'

local SETTINGS =
  'm 4 6 l 20 6 l 20 8 l 4 8 l 4 6 ' ..
  'm 14 4 l 17 4 l 17 10 l 14 10 l 14 4 ' ..
  'm 4 11 l 20 11 l 20 13 l 4 13 l 4 11 ' ..
  'm 7 9 l 10 9 l 10 15 l 7 15 l 7 9 ' ..
  'm 4 16 l 20 16 l 20 18 l 4 18 l 4 16 ' ..
  'm 15 14 l 18 14 l 18 20 l 15 20 l 15 14'

local CLOSE = 'm 5 5 l 19 19 m 19 5 l 5 19'
local MINIMIZE = 'm 5 17 l 19 17'
local CROP_SQUARE =
  'm 5 5 l 19 5 b 19 5 19 5 19 6 l 19 19 l 5 19 ' ..
  'b 5 19 5 19 5 18 l 5 5'

local EJECT =
  'm 12 5 l 19 14 l 5 14 l 12 5 ' ..
  'm 5 18 l 19 18'

local SEARCH =
  'm 14 5 b 19 5 19 13 14 13 b 9 13 9 5 14 5 ' ..
  'm 10 12 l 5 17'

local EXPAND_MENU = 'm 5 9 l 12 16 l 19 9'

local SPEED =
  'm 4 18 b 4 10 8 5 12 5 b 16 5 20 10 20 18 ' ..
  'l 17 18 b 17 12 15 8 12 8 b 9 8 7 12 7 18 l 4 18 ' ..
  'm 11 11 l 14 16 l 12 17 l 10 12 l 11 11'

local INFO =
  'm 12 3 b 17 3 21 7 21 12 b 21 17 17 21 12 21 b 7 21 3 17 3 12 b 3 7 7 3 12 3 ' ..
  'm 11 10.5 l 13 10.5 l 13 17 l 11 17 l 11 10.5 ' ..
  'm 11 6.5 l 13 6.5 l 13 8.5 l 11 8.5 l 11 6.5'

local HEADPHONES =
  'm 4 13 b 4 5 20 5 20 13 l 19 13 b 19 7 5 7 5 13 l 4 13 ' ..
  'm 4 13 l 8 13 l 8 19 l 4 19 l 4 13 ' ..
  'm 16 13 l 20 13 l 20 19 l 16 19 l 16 13'

local PLAYLIST_PLAY =
  'm 3 6 l 13 6 l 13 8 l 3 8 l 3 6 ' ..
  'm 3 10 l 13 10 l 13 12 l 3 12 l 3 10 ' ..
  'm 3 14 l 9 14 l 9 16 l 3 16 l 3 14 ' ..
  'm 14 11 l 21 16 l 14 21 l 14 11'

local registry = {
  play              = PLAY,
  pause             = PAUSE,
  prev              = PREV,
  ['next']          = NEXT_,
  forward_10        = FORWARD_10,
  rewind_10         = REWIND_10,
  volume_up         = VOLUME_UP,
  volume_down       = VOLUME_DOWN,
  volume_mute       = VOLUME_MUTE,
  volume_off        = VOLUME_OFF,
  fullscreen_enter  = FULLSCREEN_ENTER,
  fullscreen_exit   = FULLSCREEN_EXIT,
  pip               = PIP,
  subtitle          = SUBTITLE,
  audio_track       = AUDIO_TRACK,
  chapter_list      = CHAPTER_LIST,
  playlist          = PLAYLIST,
  settings          = SETTINGS,
  close             = CLOSE,
  minimize          = MINIMIZE,
  crop_square       = CROP_SQUARE,
  eject             = EJECT,
  search            = SEARCH,
  expand_menu       = EXPAND_MENU,
  speed             = SPEED,
  info              = INFO,
  headphones        = HEADPHONES,
  playlist_play     = PLAYLIST_PLAY,
}

-- Promote a legacy string entry to a single-shape filled list.
local function as_shapes(entry)
  if type(entry) == 'string' then
    return {{ass_path = entry, mode = 'fill', stroke_width = 0, opacity = 1}}
  end
  return entry
end

function M.get(name)
  local e = registry[name]
  if not e then return nil end
  if type(e) == 'string' then return e end
  -- Concatenate paths for legacy callers (loses per-shape mode info).
  local parts = {}
  for _, sh in ipairs(e) do parts[#parts + 1] = sh.ass_path end
  return table.concat(parts, ' ')
end

function M.get_shapes(name)
  local e = registry[name]
  if not e then return nil end
  return as_shapes(e)
end

function M.register(name, value)
  registry[name] = value
end

----------------------------------------------------------------- draw --

-- Convert "RRGGBB" → "BBGGRR" (libass colour byte order).
local function bgr(rrggbb)
  return rrggbb:sub(5, 6) .. rrggbb:sub(3, 4) .. rrggbb:sub(1, 2)
end

-- Combine a per-shape opacity (0..1) with a caller alpha-byte
-- ("&H10&"-style; 00 = opaque, FF = clear). Returns "&HXX&".
local function combine_alpha(caller_alpha_byte, shape_opacity)
  local op = shape_opacity or 1
  if op >= 1 then return caller_alpha_byte or '&H10&' end
  local user_val = 16
  if caller_alpha_byte then
    user_val = tonumber(caller_alpha_byte:match('&H(%x+)&') or '10', 16) or 16
  end
  local eff = math.floor(255 - (255 - user_val) * op + 0.5)
  if eff < 0 then eff = 0 elseif eff > 255 then eff = 255 end
  return string.format('&H%02X&', eff)
end

-- Render an icon, centred on (cx, cy), at the given pixel size.
--   ass         - assdraw object the renderer hands us
--   name        - registry key
--   cx, cy      - centre position in screen pixels
--   size        - rendered icon height (px); the 24-unit grid scales to this
--   ink_rgb     - foreground colour as "RRGGBB"
--   alpha_byte  - libass alpha (e.g. "&H10&"); defaults to "&H10&"
--   extra_tags  - optional ASS override tags injected after \shad0
--                 (e.g. "\\be3" for a soft blur — used for hover glows)
-- Returns true if the icon was found and emitted, false otherwise.
function M.draw_at(ass, name, cx, cy, size, ink_rgb, alpha_byte, extra_tags)
  local shapes = M.get_shapes(name)
  if not shapes then return false end
  local ink_bgr = bgr(ink_rgb)
  local scale_pct = (size / 24) * 100
  local x = cx - size / 2
  local y = cy - size / 2
  local extras = extra_tags or ''
  local xr = math.floor(x + 0.5)
  local yr = math.floor(y + 0.5)
  for _, sh in ipairs(shapes) do
    local eff_alpha = combine_alpha(alpha_byte, sh.opacity)
    if sh.mode == 'stroke' then
      -- Stroke width is in path-units; scale to screen pixels so the
      -- visible stroke stays proportional as the icon grows or shrinks.
      local sw_px = (sh.stroke_width or 1.5) * (size / 24)
      ass:new_event()
      ass:append(string.format(
        '{\\an7\\pos(%d,%d)\\bord%.2f\\shad0%s\\1a&HFF&\\3c&H%s&\\3a%s' ..
        '\\fscx%.2f\\fscy%.2f\\p1}%s{\\p0}',
        xr, yr, sw_px, extras, ink_bgr, eff_alpha, scale_pct, scale_pct, sh.ass_path
      ))
    else
      ass:new_event()
      ass:append(string.format(
        '{\\an7\\pos(%d,%d)\\bord0\\shad0%s\\1c&H%s&\\1a%s' ..
        '\\fscx%.2f\\fscy%.2f\\p1}%s{\\p0}',
        xr, yr, extras, ink_bgr, eff_alpha, scale_pct, scale_pct, sh.ass_path
      ))
    end
  end
  return true
end

-- Paint a soft outward HALO around an icon's silhouette.
--
-- This is the companion to draw_at(). Every shape in the icon —
-- whether the source SVG drew it as a stroke or as a fill — gets
-- rendered here as a FAT, BLURRED stroke in `glow_rgb`. The fill is
-- always hidden (\1a&HFF&). Drawing the icon's own paths with a
-- bord_px-thick blurred outline makes the gold bleed outward from the
-- visible glyph instead of sitting as a thin offset edge.
--
--   bord_px     - libass border thickness in screen pixels. 3 = wisp,
--                 4-5 = noticeable halo, 7+ = strong glow
--   blur_iters  - libass \be iterations (1..10). Higher = softer halo
function M.draw_glow_at(ass, name, cx, cy, size, glow_rgb, alpha_byte, bord_px, blur_iters)
  local shapes = M.get_shapes(name)
  if not shapes then return false end
  local g_bgr = bgr(glow_rgb)
  local scale_pct = (size / 24) * 100
  local x = cx - size / 2
  local y = cy - size / 2
  local xr = math.floor(x + 0.5)
  local yr = math.floor(y + 0.5)
  for _, sh in ipairs(shapes) do
    local eff_alpha = combine_alpha(alpha_byte, sh.opacity)
    ass:new_event()
    ass:append(string.format(
      '{\\an7\\pos(%d,%d)\\bord%.2f\\be%d\\shad0\\1a&HFF&\\3c&H%s&\\3a%s' ..
      '\\fscx%.2f\\fscy%.2f\\p1}%s{\\p0}',
      xr, yr, bord_px, blur_iters or 3,
      g_bgr, eff_alpha, scale_pct, scale_pct, sh.ass_path
    ))
  end
  return true
end

return M
