local Element = require('elements/Element')
local Button = require('elements/Button')
local CycleButton = require('elements/CycleButton')
local ManagedButton = require('elements/ManagedButton')
local Speed = require('elements/Speed')

-- sizing:
--   static - shrink, have highest claim on available space, disappear when there's not enough of it
--   dynamic - shrink to make room for static elements until they reach their ratio_min, then disappear
--   gap - shrink if there's no space left
--   space - expands to fill available space, shrinks as needed
-- scale - `options.controls_size` scale factor.
-- ratio - Width/height ratio of a static or dynamic element.
-- ratio_min Min ratio for 'dynamic' sized element.
---@alias ControlItem {element?: Element; kind: string; sizing: 'space' | 'static' | 'dynamic' | 'gap'; scale: number; ratio?: number; ratio_min?: number; hide: boolean; dispositions?: table<string, boolean>}

---@class Controls : Element
local Controls = class(Element)

function Controls:new() return Class.new(self) --[[@as Controls]] end
function Controls:init()
	Element.init(self, 'controls', {render_order = 6})
	---@type ControlItem[] All control elements serialized from `options.controls`.
	self.controls = {}
	---@type ControlItem[] Only controls that match current dispositions.
	self.layout = {}

	self:init_options()
end

function Controls:destroy()
	self:destroy_elements()
	Element.destroy(self)
end

function Controls:init_options()
	-- Serialize control elements
	local shorthands = {
		['play-pause'] = 'cycle:pause:pause:no/yes=play_arrow?' .. t('Play/Pause'),
		menu = 'command:menu:script-binding uosc/menu-blurred?' .. t('Menu'),
		subtitles = 'command:subtitles:script-binding uosc/subtitles#sub>0?' .. t('Subtitles'),
		audio = 'command:graphic_eq:script-binding uosc/audio#audio>1?' .. t('Audio'),
		['audio-device'] = 'command:speaker:script-binding uosc/audio-device?' .. t('Audio device'),
		video = 'command:theaters:script-binding uosc/video#video>1?' .. t('Video'),
		playlist = 'command:list_alt:script-binding uosc/playlist?' .. t('Playlist'),
		chapters = 'command:bookmark:script-binding uosc/chapters#chapters>0?' .. t('Chapters'),
		['editions'] = 'command:bookmarks:script-binding uosc/editions#editions>1?' .. t('Editions'),
		['stream-quality'] = 'command:high_quality:script-binding uosc/stream-quality?' .. t('Stream quality'),
		['open-file'] = 'command:file_open:script-binding uosc/open-file?' .. t('Open file'),
		['items'] = 'command:list_alt:script-binding uosc/items?' .. t('Playlist/Files'),
		prev = 'command:arrow_back_ios:script-binding uosc/prev?' .. t('Previous'),
		next = 'command:arrow_forward_ios:script-binding uosc/next?' .. t('Next'),
		first = 'command:first_page:script-binding uosc/first?' .. t('First'),
		last = 'command:last_page:script-binding uosc/last?' .. t('Last'),
		['loop-playlist'] = 'cycle:repeat:loop-playlist:no/inf!?' .. t('Loop playlist'),
		['loop-file'] = 'cycle:repeat_one:loop-file:no/inf!?' .. t('Loop file'),
		shuffle = 'toggle:shuffle:shuffle?' .. t('Shuffle'),
		autoload = 'toggle:hdr_auto:autoload@uosc?' .. t('Autoload'),
		fullscreen = 'cycle:crop_free:fullscreen:no/yes=fullscreen_exit!?' .. t('Fullscreen'),
	}

	-- Parse out disposition/config pairs
	local items = {}
	local in_disposition = false
	local current_item = nil
	for c in options.controls:gmatch('.') do
		if not current_item then current_item = {disposition = '', config = ''} end
		if c == '<' and #current_item.config == 0 then
			in_disposition = true
		elseif c == '>' and #current_item.config == 0 then
			in_disposition = false
		elseif c == ',' and not in_disposition then
			items[#items + 1] = current_item
			current_item = nil
		else
			local prop = in_disposition and 'disposition' or 'config'
			current_item[prop] = current_item[prop] .. c
		end
	end
	items[#items + 1] = current_item

	-- Create controls
	self.controls = {}
	for i, item in ipairs(items) do
		local config = shorthands[item.config] and shorthands[item.config] or item.config
		local config_tooltip = split(config, ' *%? *')
		local tooltip = config_tooltip[2]
		config = shorthands[config_tooltip[1]]
			and split(shorthands[config_tooltip[1]], ' *%? *')[1] or config_tooltip[1]
		local config_badge = split(config, ' *# *')
		config = config_badge[1]
		local badge = config_badge[2]
		local parts = split(config, ' *: *')
		local kind, params = parts[1], itable_slice(parts, 2)

		-- Serialize dispositions
		local dispositions = {}
		for _, definition in ipairs(comma_split(item.disposition)) do
			if #definition > 0 then
				local value = definition:sub(1, 1) ~= '!'
				local name = not value and definition:sub(2) or definition
				local prop = name:sub(1, 4) == 'has_' and name or 'is_' .. name
				dispositions[prop] = value
			end
		end

		-- Convert toggles into cycles
		if kind == 'toggle' then
			kind = 'cycle'
			params[#params + 1] = 'no/yes!'
		end

		-- Create a control element
		local control = {dispositions = dispositions, kind = kind}

		if kind == 'space' then
			control.sizing = 'space'
		elseif kind == 'gap' then
			table_assign(control, {sizing = 'gap', scale = 1, ratio = params[1] or 0.3, ratio_min = 0})
		elseif kind == 'command' then
			if #params ~= 2 then
				mp.error(string.format(
					'command button needs 2 parameters, %d received: %s', #params, table.concat(params, '/')
				))
			else
				local element = Button:new('control_' .. i, {
					render_order = self.render_order,
					icon = params[1],
					anchor_id = 'controls',
					on_click = function() mp.command(params[2]) end,
					tooltip = tooltip,
					count_prop = 'sub',
				})
				table_assign(control, {element = element, sizing = 'static', scale = 1, ratio = 1})
				if badge then self:register_badge_updater(badge, element) end
			end
		elseif kind == 'cycle' then
			if #params ~= 3 then
				mp.error(string.format(
					'cycle button needs 3 parameters, %d received: %s',
					#params, table.concat(params, '/')
				))
			else
				local state_configs = split(params[3], ' */ *')
				local states = {}

				for _, state_config in ipairs(state_configs) do
					local active = false
					if state_config:sub(-1) == '!' then
						active = true
						state_config = state_config:sub(1, -2)
					end
					local state_params = split(state_config, ' *= *')
					local value, icon = state_params[1], state_params[2] or params[1]
					states[#states + 1] = {value = value, icon = icon, active = active}
				end

				local element = CycleButton:new('control_' .. i, {
					render_order = self.render_order,
					prop = params[2],
					anchor_id = 'controls',
					states = states,
					tooltip = tooltip,
				})
				table_assign(control, {element = element, sizing = 'static', scale = 1, ratio = 1})
				if badge then self:register_badge_updater(badge, element) end
			end
		elseif kind == 'button' then
			if #params ~= 1 then
				mp.error(string.format(
					'managed button needs 1 parameter, %d received: %s', #params, table.concat(params, '/')
				))
			else
				local element = ManagedButton:new('control_' .. i, {
					name = params[1],
					render_order = self.render_order,
					anchor_id = 'controls',
				})
				table_assign(control, {element = element, sizing = 'static', scale = 1, ratio = 1})
			end
		elseif kind == 'speed' then
			if not Elements.speed then
				local element = Speed:new({anchor_id = 'controls', render_order = self.render_order})
				local scale = tonumber(params[1]) or 1.3
				table_assign(control, {
					element = element, sizing = 'dynamic', scale = scale, ratio = 3.5, ratio_min = 2,
				})
			else
				msg.error('there can only be 1 speed slider')
			end
		else
			msg.error('unknown element kind "' .. kind .. '"')
			break
		end

		self.controls[#self.controls + 1] = control
	end

	self:reflow()
end

function Controls:reflow()
	-- Populate the layout only with items that match current disposition
	self.layout = {}
	for _, control in ipairs(self.controls) do
		local matches = false
		local dispositions = 0
		for prop, value in pairs(control.dispositions) do
			dispositions = dispositions + 1
			if state[prop] == value then
				matches = true
			end
		end
		if dispositions == 0 then matches = true end
		if control.element then control.element.enabled = matches end
		if matches then self.layout[#self.layout + 1] = control end
	end

	self:update_dimensions()
	Elements:trigger('controls_reflow')
end

---@param badge string
---@param element Element An element that supports `badge` property.
function Controls:register_badge_updater(badge, element)
	local prop_and_limit = split(badge, ' *> *')
	local prop, limit = prop_and_limit[1], tonumber(prop_and_limit[2] or -1)
	local observable_name, serializer, is_external_prop = prop, nil, false

	if itable_index_of({'sub', 'audio', 'video'}, prop) then
		observable_name = 'track-list'
		serializer = function(value)
			local count = 0
			for _, track in ipairs(value) do if track.type == prop then count = count + 1 end end
			return count
		end
	else
		local parts = split(prop, '@')
		-- Support both new `prop@owner` and old `@prop` syntaxes
		if #parts > 1 then prop, is_external_prop = parts[1] ~= '' and parts[1] or parts[2], true end
		serializer = function(value) return value and (type(value) == 'table' and #value or tostring(value)) or nil end
	end

	local function handler(_, value)
		local new_value = serializer(value) --[[@as nil|string|integer]]
		local value_number = tonumber(new_value)
		if value_number then new_value = value_number > limit and value_number or nil end
		element.badge = new_value
		request_render()
	end

	if is_external_prop then
		element['on_external_prop_' .. prop] = function(_, value) handler(prop, value) end
	else
		self:observe_mp_property(observable_name, handler)
	end
end

function Controls:get_visibility()
	return Elements:v('speed', 'dragging') and 1 or Elements:maybe('timeline', 'get_is_hovered')
		and -1 or Element.get_visibility(self)
end

function Controls:update_dimensions()
	local window_border = Elements:v('window_border', 'size', 0)
	local size = round(options.controls_size * state.scale)
	local spacing = round(options.controls_spacing * state.scale)
	local margin = round(options.controls_margin * state.scale)

	-- Disable when not enough space
	local available_space = display.height - window_border * 2 - Elements:v('top_bar', 'size', 0)
		- Elements:v('timeline', 'size', 0)
	self.enabled = available_space > size + 10

	-- Reset hide/enabled flags
	for c, control in ipairs(self.layout) do
		control.hide = false
		if control.element then control.element.enabled = self.enabled end
	end

	if not self.enabled then return end

	-- Container
	self.bx = display.width - window_border - margin
	self.by = Elements:v('timeline', 'ay', display.height - window_border) - margin
	self.ax, self.ay = window_border + margin, self.by - size

	-- Controls
	local available_width, statics_width = self.bx - self.ax, 0
	local min_content_width = statics_width
	local max_dynamics_width, dynamic_units, spaces, gaps = 0, 0, 0, 0

	-- Calculate statics_width, min_content_width, and count spaces & gaps
	for c, control in ipairs(self.layout) do
		if control.sizing == 'space' then
			spaces = spaces + 1
		elseif control.sizing == 'gap' then
			gaps = gaps + control.scale * control.ratio
		elseif control.sizing == 'static' then
			local width = size * control.scale * control.ratio + (c ~= #self.layout and spacing or 0)
			statics_width = statics_width + width
			min_content_width = min_content_width + width
		elseif control.sizing == 'dynamic' then
			local spacing = (c ~= #self.layout and spacing or 0)
			statics_width = statics_width + spacing
			min_content_width = min_content_width + size * control.scale * control.ratio_min + spacing
			max_dynamics_width = max_dynamics_width + size * control.scale * control.ratio
			dynamic_units = dynamic_units + control.scale * control.ratio
		end
	end

	-- Hide & disable elements in the middle until we fit into available width
	if min_content_width > available_width then
		local i = math.ceil(#self.layout / 2 + 0.1)
		for a = 0, #self.layout - 1, 1 do
			i = i + (a * (a % 2 == 0 and 1 or -1))
			local control = self.layout[i]

			if control.sizing ~= 'gap' and control.sizing ~= 'space' then
				control.hide = true
				if control.element then control.element.enabled = false end
				if control.sizing == 'static' then
					local width = size * control.scale * control.ratio
					min_content_width = min_content_width - width - spacing
					statics_width = statics_width - width - spacing
				elseif control.sizing == 'dynamic' then
					statics_width = statics_width - spacing
					min_content_width = min_content_width - size * control.scale * control.ratio_min - spacing
					max_dynamics_width = max_dynamics_width - size * control.scale * control.ratio
					dynamic_units = dynamic_units - control.scale * control.ratio
				end

				if min_content_width < available_width then break end
			end
		end
	end

	-- Lay out the elements
	local current_x = self.ax
	local width_for_dynamics = available_width - statics_width
	local empty_space_width = width_for_dynamics - max_dynamics_width
	local width_for_gaps = math.min(empty_space_width, size * gaps)
	local individual_space_width = spaces > 0 and ((empty_space_width - width_for_gaps) / spaces) or 0

	for c, control in ipairs(self.layout) do
		if not control.hide then
			local sizing, element, scale, ratio = control.sizing, control.element, control.scale, control.ratio
			local width, height = 0, 0

			if sizing == 'space' then
				if individual_space_width > 0 then width = individual_space_width end
			elseif sizing == 'gap' then
				if width_for_gaps > 0 then width = width_for_gaps * (ratio / gaps) end
			elseif sizing == 'static' then
				height = size * scale
				width = height * ratio
			elseif sizing == 'dynamic' then
				height = size * scale
				width = max_dynamics_width < width_for_dynamics
					and height * ratio or width_for_dynamics * ((scale * ratio) / dynamic_units)
			end

			local bx = current_x + width
			if element then element:set_coordinates(round(current_x), round(self.by - height), bx, self.by) end
			current_x = element and bx + spacing or bx
		end
	end

	Elements:update_proximities()
	request_render()
end

function Controls:on_dispositions() self:reflow() end
function Controls:on_display() self:update_dimensions() end
function Controls:on_prop_border() self:update_dimensions() end
function Controls:on_prop_title_bar() self:update_dimensions() end
function Controls:on_prop_fullormaxed() self:update_dimensions() end
function Controls:on_timeline_enabled() self:update_dimensions() end

-- ===== Liquid Glass skin patch (Controls render) =====
-- YouTube-style layout: full-width progress bar on top, single row of
-- glass buttons below. All stock elements (Timeline, Volume, etc.) are
-- suppressed — everything draws here.

local liquid_glass_lib  = require('lib/liquid/glass')
local liquid_icons_lib  = require('lib/liquid/icons')
local liquid_theme_lib  = require('lib/liquid/theme')

local function _lg_format_time(s)
	s = math.max(0, math.floor(s or 0))
	local m = math.floor(s / 60)
	local sec = s % 60
	local h = math.floor(m / 60)
	if h > 0 then
		return string.format('%d:%02d:%02d', h, m % 60, sec)
	end
	return string.format('%02d:%02d', m, sec)
end

local function _lg_bgr(rrggbb)
	return rrggbb:sub(5, 6) .. rrggbb:sub(3, 4) .. rrggbb:sub(1, 2)
end

function Controls:render()
	local visibility = self:get_visibility()
	if visibility <= 0 then return end
	if not self.enabled then return end

	for _, control in ipairs(self.layout) do
		if control.element then control.element.enabled = false end
	end

	local lg = _G.liquid_glass or { intensity = 1.0, show_frost = true }
	local ass = assdraw.ass_new()
	self._lg_play_hover = self._lg_play_hover or 0

	-- Suppress all stock uosc surfaces — we draw everything here.
	if Elements then
		local blocked = {
			'timeline', 'top_bar', 'volume', 'speed',
			'pause_indicator', 'buffering_indicator', 'curtain',
		}
		for _, key in ipairs(blocked) do
			local el = Elements[key]
			if el then
				el.enabled = false
				if not el._lg_render_suppressed then
					el.render = function() return nil end
					el._lg_render_suppressed = true
				end
			end
		end
		for _, control in ipairs(self.layout) do
			local el = control.element
			if el and not el._lg_render_suppressed then
				el.enabled = false
				el.render = function() return nil end
				el._lg_render_suppressed = true
			end
		end
	end

	local function draw_glass(geom)
		for layer_text in liquid_glass_lib.draw(geom):gmatch('[^\n]+') do
			if layer_text:sub(1, 2) ~= '--' and layer_text ~= '' then
				ass:new_event()
				ass:append(layer_text)
			end
		end
	end

	local ink_bgr = _lg_bgr(liquid_theme_lib.current.ink)
	local accent_bgr = _lg_bgr(liquid_theme_lib.current.accent)

	-- Helper: draw a rounded pill (for progress bar tracks).
	local function emit_pill(px1, py, px2, ph, color_hex, alpha_byte_str)
		local pw = px2 - px1
		if pw < ph then return end
		local pr = ph / 2
		local k = pr * 0.5523
		local x1, x2 = px1, px2
		local y1, y2 = py, py + ph
		ass:new_event()
		ass:append(string.format(
			'{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H%s&\\1a%s\\p1}'
			.. 'm %.1f %.1f l %.1f %.1f '
			.. 'b %.1f %.1f %.1f %.1f %.1f %.1f '
			.. 'l %.1f %.1f '
			.. 'b %.1f %.1f %.1f %.1f %.1f %.1f '
			.. 'l %.1f %.1f '
			.. 'b %.1f %.1f %.1f %.1f %.1f %.1f '
			.. 'l %.1f %.1f '
			.. 'b %.1f %.1f %.1f %.1f %.1f %.1f'
			.. '{\\p0}',
			color_hex, alpha_byte_str,
			x1 + pr, y1,         x2 - pr, y1,
			x2 - pr + k, y1,     x2, y1 + pr - k,     x2, y1 + pr,
			x2, y2 - pr,
			x2, y2 - pr + k,     x2 - pr + k, y2,     x2 - pr, y2,
			x1 + pr, y2,
			x1 + pr - k, y2,     x1, y2 - pr + k,     x1, y2 - pr,
			x1, y1 + pr,
			x1, y1 + pr - k,     x1 + pr - k, y1,     x1 + pr, y1
		))
	end

	-- Helper: draw a glass button pebble with an icon centered inside.
	local function draw_button(bx, by, bw, bh, icon_name, is_hovered)
		local br = bh / 2
		draw_glass({
			x = bx, y = by, w = bw, h = bh, r = br,
			intensity = lg.intensity * (is_hovered and 1.2 or 1.0),
			show_frost = lg.show_frost,
		})
		local icon_path = liquid_icons_lib.get(icon_name)
		if icon_path then
			local scale = (bh * 0.50) / 24
			ass:new_event()
			ass:append(string.format(
				'{\\an7\\pos(%d,%d)\\bord0\\shad0\\1c&H%s&\\1a&H10&\\fscx%d\\fscy%d\\p1}%s{\\p0}',
				bx + (bw - 24 * scale) / 2,
				by + (bh - 24 * scale) / 2,
				ink_bgr,
				scale * 100, scale * 100,
				icon_path
			))
		end
	end

	-- ==================== LAYOUT ====================
	-- Full control area from self.ax to self.bx, bottom-pinned to self.by.
	local pad_x = 16
	local area_ax = self.ax + pad_x
	local area_bx = self.bx - pad_x
	local area_w  = area_bx - area_ax

	-- Sizes
	local btn_h = 40
	local btn_w = 40
	local btn_gap = 10
	local progress_h = 14
	local progress_r = progress_h / 2
	local row_gap = 10
	local vol_slider_w = 100

	-- Vertical positions: progress bar on top, button row below.
	local btn_row_y = self.by - btn_h - 8
	local progress_y = btn_row_y - row_gap - progress_h

	-- ==================== 1. PROGRESS BAR (full width, glass strip) ====================
	draw_glass({
		x = area_ax, y = progress_y, w = area_w, h = progress_h, r = progress_r,
		intensity = lg.intensity, show_frost = lg.show_frost,
	})

	local progress = (state.duration and state.duration > 0)
		and ((state.time or 0) / state.duration) or 0
	if progress < 0 then progress = 0 elseif progress > 1 then progress = 1 end

	-- Track background
	local trk_inset = 3
	local trk_h = progress_h - trk_inset * 2
	local trk_ax = area_ax + trk_inset
	local trk_bx = area_bx - trk_inset
	local trk_y  = progress_y + trk_inset
	local trk_w  = trk_bx - trk_ax
	emit_pill(trk_ax, trk_y, trk_bx, trk_h, 'FFFFFF', '&H80&')

	-- Progress fill (accent color)
	local fill_x = trk_ax + math.floor(trk_w * progress)
	if fill_x > trk_ax + trk_h then
		emit_pill(trk_ax, trk_y, fill_x, trk_h, accent_bgr, '&H20&')
	end

	-- Progress bar hitbox (full glass strip area for easier clicking)
	local progress_hitbox = {ax = area_ax, ay = progress_y, bx = area_bx, by = progress_y + progress_h}

	-- Chapter ticks on progress bar
	if state.chapters and #state.chapters > 0 and state.duration and state.duration > 0 then
		for _, chapter in ipairs(state.chapters) do
			if chapter.time > 0 and chapter.time < state.duration then
				local tx = trk_ax + math.floor(trk_w * (chapter.time / state.duration))
				ass:new_event()
				ass:append(string.format(
					'{\\an7\\pos(0,0)\\bord0\\shad0\\1c&HFFFFFF&\\1a&H60&\\p1}m %d %d l %d %d l %d %d l %d %d{\\p0}',
					tx, trk_y, tx + 1, trk_y,
					tx + 1, trk_y + trk_h, tx, trk_y + trk_h
				))
			end
		end
	end

	-- ==================== 2. BUTTON ROW ====================
	-- Left side: Play | Prev | Next | Volume icon | Volume slider | Time
	-- Right side: Settings | Fullscreen
	local cx = area_ax  -- cursor X for laying out buttons left-to-right

	-- Play / pause button (with spring hover-scale)
	local play_rect = {ax = cx, ay = btn_row_y, bx = cx + btn_w, by = btn_row_y + btn_h}
	local is_play_hover = get_point_to_rectangle_proximity(cursor, play_rect) == 0
	local hover_target = is_play_hover and 1 or 0
	if math.abs(self._lg_play_hover - hover_target) > 0.01 then
		self._lg_play_hover = self._lg_play_hover + (hover_target - self._lg_play_hover) * 0.25
		request_render()
	end
	local motion = lg.motion or nil
	local hover_t = motion and motion.spring_out(self._lg_play_hover) or self._lg_play_hover
	local play_scale = 1 + 0.06 * hover_t
	local sw = btn_w * play_scale
	local sh = btn_h * play_scale
	local sx = cx - (sw - btn_w) / 2
	local sy = btn_row_y - (sh - btn_h) / 2
	draw_glass({
		x = sx, y = sy, w = sw, h = sh, r = sh / 2,
		intensity = lg.intensity * (1 + 0.2 * hover_t),
		show_frost = lg.show_frost,
	})
	local play_icon = state.pause and 'play' or 'pause'
	local play_icon_path = liquid_icons_lib.get(play_icon)
	if play_icon_path then
		local pscale = (btn_h * 0.55) / 24
		ass:new_event()
		ass:append(string.format(
			'{\\an7\\pos(%d,%d)\\bord0\\shad0\\1c&H%s&\\1a&H0F&\\fscx%d\\fscy%d\\p1}%s{\\p0}',
			cx + (btn_w - 24 * pscale) / 2,
			btn_row_y + (btn_h - 24 * pscale) / 2,
			ink_bgr,
			pscale * 100, pscale * 100,
			play_icon_path
		))
	end
	cx = cx + btn_w + btn_gap

	-- Previous button
	local prev_rect = {ax = cx, ay = btn_row_y, bx = cx + btn_w, by = btn_row_y + btn_h}
	local prev_hover = get_point_to_rectangle_proximity(cursor, prev_rect) == 0
	draw_button(cx, btn_row_y, btn_w, btn_h, 'prev', prev_hover)
	cx = cx + btn_w + btn_gap

	-- Next button
	local next_rect = {ax = cx, ay = btn_row_y, bx = cx + btn_w, by = btn_row_y + btn_h}
	local next_hover = get_point_to_rectangle_proximity(cursor, next_rect) == 0
	draw_button(cx, btn_row_y, btn_w, btn_h, 'next', next_hover)
	cx = cx + btn_w + btn_gap

	-- Volume icon button
	local vol_icon_rect = {ax = cx, ay = btn_row_y, bx = cx + btn_w, by = btn_row_y + btn_h}
	local vol_hover = get_point_to_rectangle_proximity(cursor, vol_icon_rect) == 0
	local vol_icon = 'volume_up'
	if state.mute then vol_icon = 'volume_off'
	elseif (state.volume or 0) <= 0 then vol_icon = 'volume_mute'
	elseif (state.volume or 0) <= 60 then vol_icon = 'volume_down'
	end
	draw_button(cx, btn_row_y, btn_w, btn_h, vol_icon, vol_hover)
	cx = cx + btn_w + btn_gap

	-- Horizontal volume slider (glass pill with accent fill)
	local vol_slider_h = btn_h - 12
	local vol_slider_y = btn_row_y + (btn_h - vol_slider_h) / 2
	local vol_slider_r = vol_slider_h / 2
	draw_glass({
		x = cx, y = vol_slider_y, w = vol_slider_w, h = vol_slider_h, r = vol_slider_r,
		intensity = lg.intensity * 0.8, show_frost = lg.show_frost,
	})
	local vol_frac = math.min((state.volume or 0) / (state.volume_max or 100), 1)
	if vol_frac < 0 then vol_frac = 0 end
	local vol_fill_inset = 3
	local vol_fill_ax = cx + vol_fill_inset
	local vol_fill_bx = cx + vol_slider_w - vol_fill_inset
	local vol_fill_w = vol_fill_bx - vol_fill_ax
	local vol_fill_h = vol_slider_h - vol_fill_inset * 2
	local vol_fill_y = vol_slider_y + vol_fill_inset
	local vol_filled_x = vol_fill_ax + math.floor(vol_fill_w * vol_frac)
	if vol_filled_x > vol_fill_ax + vol_fill_h then
		emit_pill(vol_fill_ax, vol_fill_y, vol_filled_x, vol_fill_h, accent_bgr, '&H30&')
	end
	local vol_slider_rect = {ax = cx, ay = btn_row_y, bx = cx + vol_slider_w, by = btn_row_y + btn_h}
	cx = cx + vol_slider_w + btn_gap + 6

	-- Time readout (plain text, no pebble — keeps it light)
	local time_str = string.format('%s / %s',
		_lg_format_time(state.time or 0),
		_lg_format_time(state.duration or 0))
	ass:new_event()
	ass:append(string.format(
		'{\\an4\\pos(%d,%d)\\fnGeist Mono\\fs16\\bord0\\shad0\\1c&H%s&\\1a&H10&}%s',
		cx, btn_row_y + btn_h / 2,
		ink_bgr,
		time_str
	))

	-- Right-side buttons: Fullscreen (rightmost), Settings (second from right)
	local rx = area_bx  -- cursor from the right edge

	-- Fullscreen button
	rx = rx - btn_w
	local fs_rect = {ax = rx, ay = btn_row_y, bx = rx + btn_w, by = btn_row_y + btn_h}
	local fs_hover = get_point_to_rectangle_proximity(cursor, fs_rect) == 0
	local fs_icon = state.fullscreen and 'fullscreen_exit' or 'fullscreen_enter'
	draw_button(rx, btn_row_y, btn_w, btn_h, fs_icon, fs_hover)
	rx = rx - btn_gap

	-- Settings button
	rx = rx - btn_w
	local settings_rect = {ax = rx, ay = btn_row_y, bx = rx + btn_w, by = btn_row_y + btn_h}
	local settings_hover = get_point_to_rectangle_proximity(cursor, settings_rect) == 0
	draw_button(rx, btn_row_y, btn_w, btn_h, 'settings', settings_hover)
	rx = rx - btn_gap

	-- Subtitle button
	rx = rx - btn_w
	local sub_rect = {ax = rx, ay = btn_row_y, bx = rx + btn_w, by = btn_row_y + btn_h}
	local sub_hover = get_point_to_rectangle_proximity(cursor, sub_rect) == 0
	draw_button(rx, btn_row_y, btn_w, btn_h, 'subtitle', sub_hover)

	-- ==================== 3. INTERACTIVITY ====================
	if cursor and cursor.zone then
		-- Play / pause
		cursor:zone('primary_down', play_rect, function()
			mp.commandv('cycle', 'pause')
		end)

		-- Previous / Next
		cursor:zone('primary_down', prev_rect, function()
			mp.command('playlist-prev')
		end)
		cursor:zone('primary_down', next_rect, function()
			mp.command('playlist-next')
		end)

		-- Volume icon: toggle mute
		cursor:zone('primary_down', vol_icon_rect, function()
			mp.commandv('cycle', 'mute')
		end)

		-- Volume slider: click to set volume
		cursor:zone('primary_down', vol_slider_rect, function()
			local frac = (cursor.x - vol_fill_ax) / vol_fill_w
			if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
			mp.commandv('set', 'volume', math.floor(frac * (state.volume_max or 100)))
		end)

		-- Volume scroll on the slider area
		cursor:zone('wheel_up', vol_slider_rect, function()
			mp.commandv('set', 'volume', math.min((state.volume or 0) + 5, state.volume_max or 100))
		end)
		cursor:zone('wheel_down', vol_slider_rect, function()
			mp.commandv('set', 'volume', math.max((state.volume or 0) - 5, 0))
		end)

		-- Progress bar: click to seek + drag to scrub
		local seek_ax = trk_ax
		local seek_w  = trk_w
		local function seek_to_cursor(fast)
			if not (state.duration and state.duration > 0) then return end
			local cx_pos = cursor.x - seek_ax
			if cx_pos < 0 then cx_pos = 0 elseif cx_pos > seek_w then cx_pos = seek_w end
			local p = cx_pos / seek_w
			mp.commandv('seek', state.duration * p, fast and 'absolute+keyframes' or 'absolute+exact')
		end
		cursor:zone('primary_down', progress_hitbox, function()
			self._lg_seek_drag = {pause_was = state.pause}
			mp.set_property_native('pause', true)
			seek_to_cursor(false)
			cursor:once('primary_up', function()
				if self._lg_seek_drag then
					mp.set_property_native('pause', self._lg_seek_drag.pause_was)
					self._lg_seek_drag = nil
				end
			end)
		end)
		self._lg_seek_handler = seek_to_cursor

		-- Fullscreen toggle
		cursor:zone('primary_down', fs_rect, function()
			mp.commandv('cycle', 'fullscreen')
		end)

		-- Settings menu
		cursor:zone('primary_down', settings_rect, function()
			mp.command('script-binding uosc/menu')
		end)

		-- Subtitle picker
		cursor:zone('primary_down', sub_rect, function()
			mp.command('script-binding uosc/subtitles')
		end)
	end

	return ass
end

-- Drag scrubbing for progress bar.
function Controls:on_global_mouse_move()
	if self._lg_seek_drag and self._lg_seek_handler then
		self._lg_seek_handler(false)
	end
end

function Controls:on_global_mouse_leave()
	if self._lg_seek_drag then
		mp.set_property_native('pause', self._lg_seek_drag.pause_was)
		self._lg_seek_drag = nil
	end
end
-- ===== /Liquid Glass skin patch =====

function Controls:destroy_elements()
	for _, control in ipairs(self.controls) do
		if control.element then control.element:destroy() end
	end
end

function Controls:on_options()
	self:destroy_elements()
	self:init_options()
end

return Controls
