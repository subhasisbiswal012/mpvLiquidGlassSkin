local Element = require('elements/Element')
local chapters_lib = require('lib/chapters')

---@class Timeline : Element
local Timeline = class(Element)

function Timeline:new() return Class.new(self) --[[@as Timeline]] end
function Timeline:init()
	Element.init(self, 'timeline', {render_order = 5})
	---@type false|{pause: boolean, distance: number, last: {x: number, y: number}}
	self.pressed = false
	self.obstructed = false
	self.size = 0
	self.progress_size = 0
	self.min_progress_size = 0 -- used for `flash-progress`
	self.font_size = 0
	self.top_border = 0
	self.line_width = 0
	self.progress_line_width = 0
	self.is_hovered = false
	self.has_thumbnail = false

	self:decide_progress_size()
	self:update_dimensions()

	-- Release any dragging when file gets unloaded
	self:register_mp_event('end-file', function() self.pressed = false end)
end

function Timeline:get_visibility()
	return math.max(Elements:maybe('controls', 'get_visibility') or 0, Element.get_visibility(self))
end

function Timeline:decide_enabled()
	local previous = self.enabled
	self.enabled = not self.obstructed and state.duration ~= nil and state.duration > 0 and state.time ~= nil
	if self.enabled ~= previous then Elements:trigger('timeline_enabled', self.enabled) end
end

function Timeline:get_effective_size()
	if Elements:v('speed', 'dragging') then return self.size end
	local progress_size = math.max(self.min_progress_size, self.progress_size)
	return progress_size + math.ceil((self.size - self.progress_size) * self:get_visibility())
end

function Timeline:get_is_hovered() return self.enabled and self.is_hovered end

function Timeline:update_dimensions()
	self.size = round(options.timeline_size * state.scale)
	self.top_border = round(options.timeline_border * state.scale)
	self.line_width = round(options.timeline_line_width * state.scale)
	self.progress_line_width = round(options.progress_line_width * state.scale)
	self.font_size = math.floor(math.min((self.size + 60 * state.scale) * 0.2, self.size * 0.96) * options.font_scale)
	local window_border_size = Elements:v('window_border', 'size', 0)
	self.ax = window_border_size
	self.ay = display.height - window_border_size - self.size - self.top_border
	self.bx = display.width - window_border_size
	self.by = display.height - window_border_size
	self.width = self.bx - self.ax
	self.chapter_size = math.max((self.by - self.ay) / 10, 3)
	self.chapter_size_hover = self.chapter_size * 2

	-- Disable if not enough space
	local available_space = display.height - window_border_size * 2 - Elements:v('top_bar', 'size', 0)
	self.obstructed = available_space < self.size + 10
	self:decide_enabled()
end

function Timeline:decide_progress_size()
	local show = options.progress == 'always'
		or (options.progress == 'fullscreen' and state.fullormaxed)
		or (options.progress == 'windowed' and not state.fullormaxed)
	self.progress_size = show and options.progress_size or 0
end

function Timeline:toggle_progress()
	local current = self.progress_size
	self:tween_property('progress_size', current, current > 0 and 0 or options.progress_size)
	request_render()
end

function Timeline:flash_progress()
	if self.enabled and options.flash_duration > 0 then
		if not self._flash_progress_timer then
			self._flash_progress_timer = mp.add_timeout(options.flash_duration / 1000, function()
				self:tween_property('min_progress_size', options.progress_size, 0)
			end)
			self._flash_progress_timer:kill()
		end

		self:tween_stop()
		self.min_progress_size = options.progress_size
		request_render()
		self._flash_progress_timer.timeout = options.flash_duration / 1000
		self._flash_progress_timer:kill()
		self._flash_progress_timer:resume()
	end
end

function Timeline:get_time_at_x(x)
	local line_width = (options.timeline_style == 'line' and self.line_width - 1 or 0)
	local time_width = self.width - line_width - 1
	local fax = (time_width) * state.time / state.duration
	local fbx = fax + line_width
	-- time starts 0.5 pixels in
	x = x - self.ax - 0.5
	if x > fbx then
		x = x - line_width
	elseif x > fax then
		x = fax
	end
	local progress = clamp(0, x / time_width, 1)
	return state.duration * progress
end

---@param fast? boolean
function Timeline:set_from_cursor(fast)
	if state.time and state.duration then
		mp.commandv('seek', self:get_time_at_x(cursor.x), fast and 'absolute+keyframes' or 'absolute+exact')
	end
end

function Timeline:clear_thumbnail()
	mp.commandv('script-message-to', 'thumbfast', 'clear')
	self.has_thumbnail = false
end

function Timeline:handle_cursor_down()
	self.pressed = {pause = state.pause, distance = 0, last = {x = cursor.x, y = cursor.y}}
	mp.set_property_native('pause', true)
	self:set_from_cursor()
end
function Timeline:on_prop_duration() self:decide_enabled() end
function Timeline:on_prop_time() self:decide_enabled() end
function Timeline:on_prop_border() self:update_dimensions() end
function Timeline:on_prop_title_bar() self:update_dimensions() end
function Timeline:on_prop_fullormaxed()
	self:decide_progress_size()
	self:update_dimensions()
end
function Timeline:on_display() self:update_dimensions() end
function Timeline:on_options()
	self:decide_progress_size()
	self:update_dimensions()
end
function Timeline:handle_cursor_up()
	if self.pressed then
		mp.set_property_native('pause', self.pressed.pause)
		self.pressed = false
	end
end
function Timeline:on_global_mouse_leave()
	self.pressed = false
end

function Timeline:on_global_mouse_move()
	if self.pressed then
		self.pressed.distance = self.pressed.distance + get_point_to_point_proximity(self.pressed.last, cursor)
		self.pressed.last.x, self.pressed.last.y = cursor.x, cursor.y
		if state.is_video and math.abs(cursor:get_velocity().x) / self.width * state.duration > 30 then
			self:set_from_cursor(true)
		else
			self:set_from_cursor()
		end
	end
end

function Timeline:render()
	if self.size == 0 then return end
	local visibility = self:get_visibility()
	if visibility <= 0 then return end
	if not state.duration or state.duration <= 0 then return end

	local glass = require('lib/liquid/glass')
	local theme = require('lib/liquid/theme')
	local lg = _G.liquid_glass or { intensity = 1.0, show_frost = true }

	local ass = assdraw.ass_new()
	local function draw_glass(geom)
		for layer_text in glass.draw(geom):gmatch('[^\n]+') do
			if layer_text:sub(1, 2) ~= '--' and layer_text ~= '' then
				ass:new_event()
				ass:append(layer_text)
			end
		end
	end

	-- Geometry: pebble centered on the timeline strip, slim and full-width-ish.
	local strip_h = math.max(8, math.floor(self:get_effective_size() * 0.65))
	local horizontal_pad = math.floor((self.bx - self.ax) * 0.02)
	local pebble_ax = self.ax + horizontal_pad
	local pebble_bx = self.bx - horizontal_pad
	local pebble_w = pebble_bx - pebble_ax
	local pebble_ay = self.by - strip_h - 4
	local pebble_by = self.by - 4
	local pebble_r = strip_h / 2

	draw_glass({
		x = pebble_ax, y = pebble_ay, w = pebble_w, h = strip_h, r = pebble_r,
		intensity = lg.intensity,
		show_frost = lg.show_frost,
	})

	-- Progress fill (accent color) inset 4px from pebble edges.
	local progress = (state.time or 0) / state.duration
	if progress < 0 then progress = 0 elseif progress > 1 then progress = 1 end
	local inset = 4
	local fill_ax = pebble_ax + inset
	local fill_by = pebble_by - inset
	local fill_ay = pebble_ay + inset
	local fill_max_w = pebble_w - inset * 2
	local fill_w = math.floor(fill_max_w * progress)
	if fill_w > 0 then
		local accent = theme.current.accent
		local accent_bgr = accent:sub(5, 6) .. accent:sub(3, 4) .. accent:sub(1, 2)
		ass:new_event()
		ass:append(string.format(
			'{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H%s&\\1a&H30&\\p1}m %d %d l %d %d l %d %d l %d %d{\\p0}',
			accent_bgr,
			fill_ax, fill_ay,
			fill_ax + fill_w, fill_ay,
			fill_ax + fill_w, fill_by,
			fill_ax, fill_by
		))
	end

	-- Chapter ticks: thin vertical lines through the strip.
	if state.chapters and #state.chapters > 0 then
		for _, chapter in ipairs(state.chapters) do
			if chapter.time > 0 and chapter.time < state.duration then
				local tx = pebble_ax + math.floor(pebble_w * (chapter.time / state.duration))
				ass:new_event()
				ass:append(string.format(
					'{\\an7\\pos(0,0)\\bord0\\shad0\\1c&HFFFFFF&\\1a&H80&\\p1}m %d %d l %d %d l %d %d l %d %d{\\p0}',
					tx, pebble_ay + 2, tx + 1, pebble_ay + 2,
					tx + 1, pebble_by - 2, tx, pebble_by - 2
				))
			end
		end
	end

	-- Hover behavior: glow the hovered chapter's span + show its title. Files
	-- without chapters (or the gap before the first chapter) fall back to a
	-- thin seek indicator so scrubbing still has visual feedback.
	if self.is_hovered and cursor.x >= pebble_ax and cursor.x <= pebble_bx then
		local accent = theme.current.accent
		local accent_bgr = accent:sub(5, 6) .. accent:sub(3, 4) .. accent:sub(1, 2)
		local hover_time = self:get_time_at_x(cursor.x)
		local chapter, chapter_i = chapters_lib.chapter_at_time(state.chapters, hover_time)

		if chapter then
			-- Glow the whole span of the hovered chapter on the strip.
			local span = chapters_lib.chapter_span(state.chapters, chapter_i, state.duration)
			local gx_a = clamp(pebble_ax, math.floor(pebble_ax + pebble_w * (span.start / state.duration)), pebble_bx)
			local gx_b = clamp(pebble_ax, math.ceil(pebble_ax + pebble_w * (span.stop / state.duration)), pebble_bx)
			local function band(alpha, blur, pad)
				ass:new_event()
				ass:append(string.format(
					'{\\an7\\pos(0,0)\\bord0\\shad0\\blur%d\\1c&H%s&\\1a&H%s&\\p1}m %d %d l %d %d l %d %d l %d %d{\\p0}',
					blur, accent_bgr, alpha,
					gx_a, pebble_ay - pad, gx_b, pebble_ay - pad,
					gx_b, pebble_by + pad, gx_a, pebble_by + pad
				))
			end
			band('A0', 8, 2) -- soft outer glow
			band('60', 2, 0) -- crisper inner band

			-- Chapter title tooltip above the timeline (title only, no timestamp).
			local label = chapters_lib.truncate(chapters_lib.chapter_label(chapter, chapter_i), 48)
			ass:new_event()
			ass:append(string.format(
				'{\\an2\\pos(%d,%d)\\bord0\\shad2\\fn%s\\fs%d\\1c&H%s&\\1a&H10&}%s',
				math.floor(cursor.x), pebble_ay - 6,
				'Geist Mono', self.font_size > 0 and self.font_size or 14,
				'FFFFFF', label
			))
		else
			-- Thin vertical seek indicator at cursor.x.
			ass:new_event()
			ass:append(string.format(
				'{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H%s&\\1a&H20&\\p1}m %d %d l %d %d l %d %d l %d %d{\\p0}',
				accent_bgr,
				math.floor(cursor.x) - 1, pebble_ay,
				math.floor(cursor.x) + 1, pebble_ay,
				math.floor(cursor.x) + 1, pebble_by,
				math.floor(cursor.x) - 1, pebble_by
			))
		end
	end

	-- Preserve uosc's click/drag handling: register zones on the full strip.
	if visibility > 0 then
		cursor:zone('primary_down', self, function()
			self:handle_cursor_down()
			cursor:once('primary_up', function() self:handle_cursor_up() end)
		end)
		if config.timeline_step ~= 0 then
			cursor:zone('wheel_down', self, function()
				mp.commandv('seek', -config.timeline_step, config.timeline_step_flag)
			end)
			cursor:zone('wheel_up', self, function()
				mp.commandv('seek', config.timeline_step, config.timeline_step_flag)
			end)
		end
	end

	return ass
end

return Timeline
