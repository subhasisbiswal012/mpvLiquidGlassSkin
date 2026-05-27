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
-- Original uosc Controls had no :render() method — it only lays out child
-- Button/CycleButton elements (which render themselves). Here we add a
-- :render() that draws three glass pebbles (play, time, progress) instead,
-- and disable the original button children so they don't overlap our pebbles.
--
-- To restore stock uosc behavior: delete this entire block AND remove the
-- `enabled = false` loop in update_dimensions (or revert from upstream).

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

	-- Disable stock child elements so only our pebbles render.
	for _, control in ipairs(self.layout) do
		if control.element then control.element.enabled = false end
	end

	local lg = _G.liquid_glass or { intensity = 1.0, show_frost = true }
	local ass = assdraw.ass_new()

	-- Suppress all stock uosc surfaces so only our three pebbles render.
	-- Setting `enabled = false` per frame is not enough — several elements
	-- (Speed, Volume, Timeline) re-enable themselves on hover/drag, and
	-- uosc renders them anyway when they're interacting. We additionally
	-- monkey-patch :render() to return nil on first sight, which is
	-- bulletproof. Idempotent: we set a sentinel so we only patch once
	-- per element instance.
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
		-- Stock child Buttons live as control_1, control_2, ... — disable
		-- their render too so the prev/next/shuffle/etc. text strip can't
		-- bleed through behind our pebbles.
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
			if layer_text ~= '' then
				ass:new_event()
				ass:append(layer_text)
			end
		end
	end

	-- Pebble layout: three independent rounded rects.
	-- Row stretches across the controls bounding box (which already has
	-- uosc's controls_margin baked into self.ax/self.bx), with an extra
	-- ~4% inset on each side for visual breathing. Time pebble grows
	-- modestly with window width; play pebble stays icon-sized; progress
	-- pebble consumes whatever is left.
	local pebble_h = 68
	local pebble_r = pebble_h / 2
	local gap = 16
	local play_w = 68

	local box_w = self.bx - self.ax
	local side_inset = math.floor(box_w * 0.04)
	local row_x1 = self.ax + side_inset
	local row_x2 = self.bx - side_inset
	local row_w  = row_x2 - row_x1

	-- Time pebble: scales gently with row, clamped to a readable range.
	local times_w = math.max(210, math.min(320, math.floor(row_w * 0.20)))
	local progress_w = row_w - play_w - times_w - 2 * gap
	if progress_w < 140 then
		-- Window is too narrow for the comfortable layout — shrink the
		-- time pebble before the progress pebble vanishes.
		times_w = math.max(160, times_w - (140 - progress_w))
		progress_w = row_w - play_w - times_w - 2 * gap
		if progress_w < 100 then progress_w = 100 end
	end

	-- Bottom-pin the row to self.by (uosc's bottom edge, above timeline)
	-- with a small visual margin. Centering inside (self.ay..self.by) put
	-- the row half above the bbox because pebble_h exceeds the bbox
	-- height (controls_size ~32).
	local row_y = self.by - pebble_h - 12

	local play_x     = row_x1
	local times_x    = play_x + play_w + gap
	local progress_x = times_x + times_w + gap

	local function pebble_geom(x, w)
		return {
			x = x, y = row_y, w = w, h = pebble_h, r = pebble_r,
			intensity = lg.intensity, show_frost = lg.show_frost,
		}
	end

	local ink_bgr = _lg_bgr(liquid_theme_lib.current.ink)
	local pf_bgr  = _lg_bgr(liquid_theme_lib.current.progress_fill)

	-- Hitboxes for cursor zones (interactivity below).
	local play_hitbox     = {ax = play_x,     ay = row_y, bx = play_x + play_w,     by = row_y + pebble_h}
	local progress_hitbox = {ax = progress_x, ay = row_y, bx = progress_x + progress_w, by = row_y + pebble_h}

	-- 1. Play / pause pebble + icon (icon scaled up via \fscx/\fscy on the
	-- 24x24 vector path — ~140% of source = ~33px effective).
	draw_glass(pebble_geom(play_x, play_w))

	local icon_name = state.pause and 'play' or 'pause'
	local icon_path = liquid_icons_lib.get(icon_name)
	if icon_path then
		local icon_scale = 140  -- percent
		local icon_render_w = 24 * icon_scale / 100
		ass:new_event()
		ass:append(string.format(
			'{\\an7\\pos(%d,%d)\\fscx%d\\fscy%d\\bord0\\shad0\\1c&H%s&\\1a&H0F&\\p1}%s{\\p0}',
			play_x + math.floor((play_w - icon_render_w) / 2),
			row_y + math.floor((pebble_h - icon_render_w) / 2),
			icon_scale, icon_scale,
			ink_bgr,
			icon_path
		))
	end

	-- 2. Time readout pebble + text. Geist (sans) Medium for a premium
	-- modern look; tnum is implicit via Geist's design but we explicitly
	-- add a touch of letter-spacing via \fsp for breathing room.
	draw_glass(pebble_geom(times_x, times_w))
	local time_str = string.format('%s / %s',
		_lg_format_time(state.time or 0),
		_lg_format_time(state.duration or 0))
	ass:new_event()
	ass:append(string.format(
		'{\\an5\\pos(%d,%d)\\fnGeist Medium\\fs26\\fsp1\\bord0\\shad0\\1c&H%s&}%s',
		times_x + math.floor(times_w / 2),
		row_y + math.floor(pebble_h / 2),
		ink_bgr,
		time_str
	))

	-- 3. Progress pebble + track. Track is a rounded pill (height 6) so it
	-- reads as a real progress bar rather than a hairline. Track sits
	-- centered vertically on the pebble.
	draw_glass(pebble_geom(progress_x, progress_w))
	local track_h = 6
	local track_y = row_y + math.floor((pebble_h - track_h) / 2)
	local track_inset = 28
	local track_x1 = progress_x + track_inset
	local track_x2 = progress_x + progress_w - track_inset
	local track_w = track_x2 - track_x1
	local progress = (state.duration and state.duration > 0)
		and ((state.time or 0) / state.duration) or 0
	if progress < 0 then progress = 0 elseif progress > 1 then progress = 1 end

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
			.. 'm %.2f %.2f l %.2f %.2f '
			.. 'b %.2f %.2f %.2f %.2f %.2f %.2f '
			.. 'l %.2f %.2f '
			.. 'b %.2f %.2f %.2f %.2f %.2f %.2f '
			.. 'l %.2f %.2f '
			.. 'b %.2f %.2f %.2f %.2f %.2f %.2f '
			.. 'l %.2f %.2f '
			.. 'b %.2f %.2f %.2f %.2f %.2f %.2f'
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

	-- track background (translucent white pill)
	emit_pill(track_x1, track_y, track_x2, track_h, 'FFFFFF', '&H80&')
	-- progress fill (opaque accent/white)
	local fill_x = track_x1 + math.floor(track_w * progress)
	if fill_x > track_x1 + track_h then
		emit_pill(track_x1, track_y, fill_x, track_h, pf_bgr, '&H10&')
	end

	-- ===== Interactivity (Milestone 2 was the original target, pulled
	-- forward because the read-only chrome made the pebbles feel broken).
	-- Zones are rebound every frame, per uosc's cursor.zone contract. =====
	if cursor and cursor.zone then
		-- Play / pause toggle.
		cursor:zone('primary_down', play_hitbox, function()
			mp.commandv('cycle', 'pause')
		end)

		-- Progress: click to seek + drag to scrub. Same pattern as
		-- Timeline:handle_cursor_down — pause while dragging, restore on
		-- release.
		local seek_inset = track_inset
		local seek_x1 = progress_x + seek_inset
		local seek_w  = progress_w - 2 * seek_inset
		local function seek_to_cursor(fast)
			if not (state.duration and state.duration > 0) then return end
			local cx = cursor.x - seek_x1
			if cx < 0 then cx = 0 elseif cx > seek_w then cx = seek_w end
			local p = cx / seek_w
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
		-- Drag scrubbing handled by Controls:on_global_mouse_move below.
		self._lg_seek_handler = seek_to_cursor
	end

	return ass
end

-- Drag scrubbing for progress pebble. Triggered by uosc's global mouse-move
-- dispatch (same hook Timeline uses).
function Controls:on_global_mouse_move()
	if self._lg_seek_drag and self._lg_seek_handler then
		local fast = state.is_video and cursor and cursor.get_velocity
			and math.abs(cursor:get_velocity().x) > 20
		self._lg_seek_handler(fast)
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
