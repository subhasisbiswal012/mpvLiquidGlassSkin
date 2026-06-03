local Element = require('elements/Element')
local chapters_lib = require('lib/chapters')
local theme = require('lib/liquid/theme')
local liquid_icons = require('lib/liquid/icons')
local glass = require('lib/liquid/glass')

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
	Element.init(self, 'skip_pill', {render_order = 7})
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

	-- Only show while the rest of the controls are visible.
	local opacity = Elements:maybe('controls', 'get_visibility') or 0
	if opacity <= 0 then
		self.ax, self.ay, self.bx, self.by = 0, 0, 0, 0
		return
	end

	local scale = state.scale
	local fs = round(14 * scale)
	local pad_x = round(13 * scale)
	local pad_y = round(5 * scale)
	local gap = round(8 * scale)
	local icon_size = round(18 * scale)
	local ink = theme.current.ink
	local ink_bgr = ink:sub(5, 6) .. ink:sub(3, 4) .. ink:sub(1, 2)

	local text_w = text_width(label, {size = fs, font = config.font, bold = options.font_bold})
	local pill_w = pad_x + text_w + gap + icon_size + pad_x
	local pill_h = math.max(fs, icon_size) + pad_y * 2

	-- Anchor to the filename line published by Controls: bottoms aligned with
	-- the title, right-aligned, on the same line just above the progress bar.
	local ctrl = Elements.controls
	local anchor = ctrl and ctrl.skip_anchor
	local pill_bx = (anchor and anchor.right) or (ctrl and ctrl.bx) or display.width
	local pill_by = (anchor and anchor.baseline) or (ctrl and ctrl.ay) or (display.height - round(60 * scale))
	local pill_ax = pill_bx - pill_w
	local pill_ay = pill_by - pill_h

	self.ax, self.ay, self.bx, self.by = pill_ax, pill_ay, pill_bx, pill_by

	-- Click to act.
	cursor:zone('primary_click', self, function()
		if self:is_alive() then action() end
	end)

	local ass = assdraw.ass_new()
	local mid_y = round((pill_ay + pill_by) / 2)

	-- Frosted-glass pill (same primitive as the progress bar).
	local lg = _G.liquid_glass or {intensity = 1.0, show_frost = true}
	for layer in glass.draw({
		x = pill_ax, y = pill_ay, w = pill_w, h = pill_h, r = round(pill_h / 2),
		intensity = lg.intensity, show_frost = lg.show_frost,
	}):gmatch('[^\n]+') do
		if layer:sub(1, 2) ~= '--' and layer ~= '' then
			ass:new_event()
			ass:append(layer)
		end
	end

	-- Label in ink with a soft border for legibility, plus the accent 'next'
	-- glyph (SVG-backed, same icon as the control bar).
	ass:txt(pill_ax + pad_x, mid_y, 4, label, {
		size = fs, color = ink_bgr, font = config.font,
		border = options.text_border * scale, border_color = bg,
	})
	liquid_icons.draw_at(ass, 'next', pill_bx - pad_x - round(icon_size / 2), mid_y, icon_size, ink, '&H10&')

	return ass
end

return SkipPill
