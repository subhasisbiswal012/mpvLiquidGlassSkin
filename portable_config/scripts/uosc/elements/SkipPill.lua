local Element = require('elements/Element')
local chapters_lib = require('lib/chapters')
local theme = require('lib/liquid/theme')
local liquid_icons = require('lib/liquid/icons')

-- A single floating "skip" pill anchored above the right end of the timeline.
-- It resolves to exactly one of three states each frame:
--   * 'chapter' — a next chapter exists and the controls are visible.
--                 Label "Jump: <title>", click jumps to the next chapter.
--   * 'video'   — within the last `next_video_threshold` seconds of the file
--                 and another playlist item exists. Label "Next: <title>",
--                 click plays the next playlist entry.
--   * nil       — hidden.
-- 'video' takes priority over 'chapter' (only realistic on the last chapter
-- near the end), so the two pills never overlap.
---@class SkipPill : Element
local SkipPill = class(Element)

function SkipPill:new() return Class.new(self) --[[@as SkipPill]] end
function SkipPill:init()
	Element.init(self, 'skip_pill', {render_order = 6})
	self._action = nil
	self._nv_idx = nil
	self._nv_title = nil
end

-- Returns the 0-based playlist index of the next item, or nil if none.
function SkipPill:next_video_index()
	local pos = state.playlist_pos -- 1-based current item
	if not state.has_playlist or not pos or not state.playlist_count then return nil end
	if pos >= state.playlist_count then return nil end
	return pos -- next item's 0-based index == current (1-based) position
end

-- Title of the next playlist item, cached until the playlist position changes.
function SkipPill:next_video_title(idx)
	if self._nv_idx ~= idx then
		self._nv_idx = idx
		local title = mp.get_property('playlist/' .. idx .. '/title')
		if not title or title == '' then
			local fn = mp.get_property('playlist/' .. idx .. '/filename')
			title = (fn and (fn:match('([^/\\]+)$') or fn)) or ('Video ' .. (idx + 1))
		end
		self._nv_title = title
	end
	return self._nv_title
end

-- Decides the current pill state. Returns mode, label, action or nil.
function SkipPill:resolve()
	if not state.duration or state.duration <= 0 or state.time == nil then return nil end

	-- Priority 1: end-of-video "next video" pill.
	local nv_idx = self:next_video_index()
	local threshold = (_G.liquid_glass and _G.liquid_glass.next_video_threshold) or 120
	if chapters_lib.should_show_next_video(state.time, state.duration, threshold, nv_idx ~= nil) then
		local title = chapters_lib.truncate(self:next_video_title(nv_idx), 36)
		return 'video', 'Next: ' .. title, function() mp.commandv('playlist-next', 'weak') end
	end

	-- Priority 2: jump-to-next-chapter pill.
	if state.chapters and #state.chapters > 0 then
		local _, cur_i = chapters_lib.chapter_at_time(state.chapters, state.time)
		local nxt = cur_i and state.chapters[cur_i + 1] or state.chapters[1]
		-- nxt is only the "next" chapter when it starts after the current time.
		if nxt and nxt.time and nxt.time > state.time then
			local idx = cur_i and (cur_i + 1) or 1
			local title = chapters_lib.truncate(chapters_lib.chapter_label(nxt, idx), 36)
			return 'chapter', 'Jump: ' .. title, function() mp.commandv('add', 'chapter', 1) end
		end
	end

	return nil
end

function SkipPill:render()
	local mode, label, action = self:resolve()
	if not mode then
		self.ax, self.ay, self.bx, self.by = 0, 0, 0, 0
		return
	end

	-- Hide behind menus / curtain.
	if Elements.curtain and Elements.curtain.opacity > 0 then return end

	-- Chapter pill rides the controls' visibility; the video pill is the
	-- end-of-file CTA and shows on its own.
	local opacity = mode == 'video' and 1 or (Elements:maybe('timeline', 'get_visibility') or 0)
	if opacity <= 0 then
		self.ax, self.ay, self.bx, self.by = 0, 0, 0, 0
		return
	end

	local scale = state.scale
	local fs = round(15 * scale)
	local pad_x = round(12 * scale)
	local pad_y = round(7 * scale)
	local gap = round(8 * scale)
	local icon_size = round(20 * scale)
	local accent = theme.current.accent
	local accent_bgr = accent:sub(5, 6) .. accent:sub(3, 4) .. accent:sub(1, 2)

	local text_w = text_width(label, {size = fs, font = config.font, bold = options.font_bold})
	local pill_w = pad_x + text_w + gap + icon_size + pad_x
	local pill_h = math.max(fs, icon_size) + pad_y * 2

	-- Anchor to the top-right of the timeline strip.
	local wb = Elements:v('window_border', 'size', 0)
	local tl = Elements.timeline
	local right = (tl and tl.bx or (display.width - wb)) - round(20 * scale)
	local base_y = (tl and tl.ay) or (display.height - wb - round(60 * scale))
	local pill_bx = right
	local pill_ax = pill_bx - pill_w
	local pill_by = base_y - round(10 * scale)
	local pill_ay = pill_by - pill_h

	self.ax, self.ay, self.bx, self.by = pill_ax, pill_ay, pill_bx, pill_by

	-- Click to act.
	cursor:zone('primary_click', self, function()
		if self:is_alive() then action() end
	end)

	local ass = assdraw.ass_new()
	local mid_y = round((pill_ay + pill_by) / 2)

	-- Pill background + accent rim.
	ass:rect(pill_ax, pill_ay, pill_bx, pill_by, {
		color = bg,
		opacity = 0.88 * opacity,
		radius = round(pill_h / 2),
		border = round(1 * scale),
		border_color = accent_bgr,
	})

	-- Label (left) and skip icon (right). The icon uses the skin's SVG-backed
	-- 'next' glyph (same as the control bar) for guaranteed, consistent rendering.
	ass:txt(pill_ax + pad_x, mid_y, 4, label, {
		size = fs, color = fg, font = config.font, opacity = opacity,
	})
	local alpha_byte = string.format('&H%02X&', clamp(0, math.floor((1 - opacity) * 255), 255))
	liquid_icons.draw_at(ass, 'next', pill_bx - pad_x - round(icon_size / 2), mid_y, icon_size, accent, alpha_byte)

	return ass
end

return SkipPill
