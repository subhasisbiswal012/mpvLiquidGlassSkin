--[[ Liquid Glass: small-window layout intelligence.

Owns three responsibilities:

  1. Detect video orientation (portrait vs landscape) from `video-params`.
  2. Compute the minimum window size the player can be without controls
     overlapping each other, for either orientation.
  3. Expose helpers that main.lua / Controls.lua read to decide which
     layout to draw and whether to clamp a user-driven resize.

The actual rendering decisions live in Controls.lua. This module is the
single source of truth for the numbers.
]]

local M = {}

-- ===== Tunable thresholds =====================================================
-- Landscape minima — derived from the actual YouTube-style row geometry in
-- Controls.lua. Numbers below are the rendered widths summed at landscape /
-- non-narrow defaults:
--
--   pad(10*2 = 20)
--   + play(42) + gap(10)                         =  52
--   + prev/next pebble(98) + gap(10)             = 108
--   + speed(42) + gap(6)                         =  48
--   + quality(90) + gap(10)                      = 100
--   + time(250) + gap(10)                        = 260
--   + horizontal volume(42+8+110+64 = 224) + gap = 234
--   left subtotal                                = 802
--   + right cluster (5 * (48+gap6) + last 48)    = 306
--   subtotal                                     ≈ 1128
--   + breathing room between clusters            = 112
--   ===========================================    1240
--
-- Height: window border + top_bar(40) + video room + filename(30+gap) +
-- progress(16) + row_gap(10) + btn(42) + bottom margin ≈ 200 chrome, plus
-- some video area = 420.
M.LANDSCAPE_MIN_WIDTH  = 1240
M.LANDSCAPE_MIN_HEIGHT = 420

-- Portrait minima — compact row only: play, prev/next, time-no-%, settings,
-- fullscreen. No volume control in portrait (mpv's wheel + hotkeys + the
-- settings menu cover that, and the row would crowd otherwise).
--
--   pad(20) + play(42+10) + prev/next(98+10) +
--   time-narrow(200+10) + settings(48+6) + fullscreen(48) ≈ 492.
-- Round up to 510 for breathing room.
--
-- Height: top_bar(40) + minimum video room + progress(16) + row_gap(10) +
-- btn(42) + margin. 480 leaves comfortable room.
M.PORTRAIT_MIN_WIDTH  = 510
M.PORTRAIT_MIN_HEIGHT = 480

-- Portrait detection: video aspect ratio at or below this counts as portrait.
-- Square videos stay landscape so the full toolbar shows.
M.PORTRAIT_ASPECT_MAX = 0.95

-- Hysteresis when clamping live resizes. The user has to drag a few pixels
-- below the floor before we snap them back, so a single pixel of OSD jitter
-- doesn't cause a feedback loop.
M.CLAMP_SLACK_PX = 4

-- ===== Orientation detection =================================================

---Returns 'portrait' or 'landscape' for the current video, or nil if unknown.
function M.video_orientation()
	local w = mp.get_property_number('video-params/w', 0)
	local h = mp.get_property_number('video-params/h', 0)
	if w <= 0 or h <= 0 then return nil end
	local aspect = w / h
	if aspect <= M.PORTRAIT_ASPECT_MAX then return 'portrait' end
	return 'landscape'
end

---Minimum window dimensions (px) for the given orientation.
function M.min_window(orientation)
	if orientation == 'portrait' then
		return M.PORTRAIT_MIN_WIDTH, M.PORTRAIT_MIN_HEIGHT
	end
	return M.LANDSCAPE_MIN_WIDTH, M.LANDSCAPE_MIN_HEIGHT
end

---Returns true if the requested window dimensions would force control overlap.
function M.would_overlap(orientation, w, h)
	local min_w, min_h = M.min_window(orientation)
	return (w + M.CLAMP_SLACK_PX) < min_w or (h + M.CLAMP_SLACK_PX) < min_h
end

---Clamp the given dimensions up to the orientation minimum.
---Returns clamped width, height, and whether anything changed.
function M.clamp(orientation, w, h)
	local min_w, min_h = M.min_window(orientation)
	local cw = math.max(w, min_w)
	local ch = math.max(h, min_h)
	return cw, ch, (cw ~= w or ch ~= h)
end

return M
