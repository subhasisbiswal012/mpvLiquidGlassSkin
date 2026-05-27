-- SF Symbols-style icons as ASS vector paths.
-- All icons designed on a 24x24 grid, centered at (12,12).
-- ASS path syntax: m=move, l=line, b=bezier (3 control points = cubic).
--
-- Names are aligned with upstream uosc's icon registry where they overlap
-- (volume_*, crop_square, close, minimize), so patched elements can pass
-- stock uosc icon strings straight into icons.get().

local M = {}

-- ===== M1 icons (kept) =====

local PLAY = 'm 7 6.5 l 7 17.5 b 7 19 7 19 8.3 18.25 l 17.7 12.75 b 19 12 19 12 17.7 11.25 l 8.3 5.75 b 7 5 7 5 7 6.5'

local PAUSE = 'm 7 5.5 b 7 4 10 4 10 5.5 l 10 18.5 b 10 20 7 20 7 18.5 l 7 5.5 m 14 5.5 b 14 4 17 4 17 5.5 l 17 18.5 b 17 20 14 20 14 18.5 l 14 5.5'

-- Skip backward: double left chevron (clearly different from play triangle).
local PREV = 'm 11 12 l 19 6 l 19 18 l 11 12 m 5 12 l 13 6 l 13 18 l 5 12'

-- Skip forward: double right chevron.
local NEXT_ = 'm 13 12 l 5 6 l 5 18 l 13 12 m 19 12 l 11 6 l 11 18 l 19 12'

-- ===== M2 icons =====

local FORWARD_10 =
  'm 12 4 l 12 7 l 17 7 b 19 7 21 9 21 12 b 21 16 17 19 13 19 b 9 19 5 16 5 12 ' ..
  'm 11 10 l 11 16 m 13 11 b 13 10 17 10 17 13 b 17 16 13 16 13 15'
local REWIND_10 =
  'm 12 4 l 12 7 l 7 7 b 5 7 3 9 3 12 b 3 16 7 19 11 19 b 15 19 19 16 19 12 ' ..
  'm 9 10 l 9 16 m 11 11 b 11 10 15 10 15 13 b 15 16 11 16 11 15'

-- Bold speaker: wider body for visibility at small sizes.
local _SPEAKER = 'm 3 9 l 7 9 l 13 4 l 13 20 l 7 15 l 3 15 l 3 9'

local VOLUME_OFF = _SPEAKER .. ' m 17 8 l 23 16 m 23 8 l 17 16'
local VOLUME_MUTE = _SPEAKER
local VOLUME_DOWN = _SPEAKER .. ' m 16 9 b 19 10.5 19 13.5 16 15'
local VOLUME_UP = _SPEAKER ..
  ' m 16 9 b 19 10.5 19 13.5 16 15' ..
  ' m 18 5 b 23 8 23 16 18 19'

-- Fullscreen: bold corner brackets (3px thick L-shapes).
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

-- Subtitle: speech bubble with "T" inside (like a text/caption icon).
local SUBTITLE =
  'm 4 4 l 20 4 b 21 4 22 5 22 6 l 22 15 b 22 16 21 17 20 17 l 13 17 l 9 21 l 9 17 l 4 17 b 3 17 2 16 2 15 l 2 6 b 2 5 3 4 4 4 ' ..
  'm 8 8 l 16 8 l 16 10 l 13 10 l 13 15 l 11 15 l 11 10 l 8 10 l 8 8'

local AUDIO_TRACK =
  'm 10 6 l 18 5 l 18 16 ' ..
  'm 18 15 b 18 18 13 18 13 15 b 13 12 18 12 18 15 ' ..
  'm 10 17 b 10 20 5 20 5 17 b 5 14 10 14 10 17 l 10 6'

local CHAPTER_LIST =
  'm 4 6 l 6 6 m 9 6 l 20 6 ' ..
  'm 4 12 l 6 12 m 9 12 l 20 12 ' ..
  'm 4 18 l 6 18 m 9 18 l 20 18'

local PLAYLIST =
  'm 4 7 l 20 7 ' ..
  'm 4 12 l 20 12 ' ..
  'm 4 17 l 16 17'

-- Settings: three horizontal bars with slider knobs (equalizer style).
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

local registry = {
  play   = PLAY,
  pause  = PAUSE,
  prev   = PREV,
  ['next'] = NEXT_,
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
}

function M.get(name) return registry[name] end

function M.register(name, ass_path) registry[name] = ass_path end

return M
