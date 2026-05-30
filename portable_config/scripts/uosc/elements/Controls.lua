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

-- ===== Speedometer constants & tick sound =====
-- Speed steps the gauge snaps to. Match the existing speed picker.
local LG_SPEED_STEPS = {0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0}

-- Sweep: 0.25× sits at the bottom-left, 3.0× at the bottom-right,
-- 1.625× at the very top. 270° of travel between them.
local LG_SPEED_ANGLE_START = -135   -- degrees, 0° = pointing UP, clockwise positive
local LG_SPEED_ANGLE_END   =  135
local LG_SPEED_ANGLE_SPAN  = LG_SPEED_ANGLE_END - LG_SPEED_ANGLE_START  -- 270

-- Spring physics for the needle. Tune for the bike-cluster feel:
--   higher stiffness → snappier
--   higher damping   → less overshoot (2*sqrt(stiffness) = critical)
-- Defaults: one visible overshoot bob, settles in ~0.6 s. Try
-- stiffness=110, damping=7 for a sloppier (carnival) feel, or
-- stiffness=200, damping=22 for an electronic/digital cluster look.
local LG_SPEED_STIFFNESS = 160
local LG_SPEED_DAMPING   = 18
-- Wall-clock duration the OSD stays after the last scroll input.
local LG_SPEED_OSD_HOLD  = 1.8
-- A tick flashes gold for this many seconds after the needle crosses it.
local LG_SPEED_FLASH_DUR = 0.22

-- Subprocess-based audio tick. Plays portable_config/scripts/uosc/
-- assets/sounds/tick.wav if it exists; silent otherwise. Throttled to
-- ~80 ms between ticks so rapid scrolls don't pile up subprocesses.
local _lg_tick_last_play  = 0
local _lg_tick_path_cached = nil
local _lg_tick_path_checked = false
local function _lg_resolve_tick_path()
	if _lg_tick_path_checked then return _lg_tick_path_cached end
	_lg_tick_path_checked = true
	local utils = require('mp.utils')
	-- Primary: relative to this script's own directory. Most reliable.
	local candidate
	if mp.get_script_directory then
		local script_dir = mp.get_script_directory()
		if script_dir then
			candidate = utils.join_path(script_dir, 'assets/sounds/tick.wav')
		end
	end
	-- Fallback: mpv config expansion.
	if not candidate then
		local ok, expanded = pcall(mp.command_native,
			{name = 'expand-path', text = '~~/scripts/uosc/assets/sounds/tick.wav'})
		if ok then candidate = expanded end
	end
	if candidate then
		local info = utils.file_info(candidate)
		if info and info.is_file then
			_lg_tick_path_cached = candidate
			mp.msg.info('liquid speedo: tick sound resolved at ' .. candidate)
		else
			mp.msg.warn('liquid speedo: tick.wav not found at ' .. tostring(candidate))
		end
	else
		mp.msg.warn('liquid speedo: could not resolve assets/sounds/tick.wav path')
	end
	return _lg_tick_path_cached
end
local function _lg_play_tick_sound()
	-- Lightweight guard against the same Windows-message scroll firing
	-- twice in the same animation frame; user-driven scrolls are
	-- naturally rate-limited so we don't need a longer throttle now
	-- that this fires once per scroll click instead of per crossing.
	local now = mp.get_time()
	if now - _lg_tick_last_play < 0.02 then return end
	local path = _lg_resolve_tick_path()
	if not path then return end
	_lg_tick_last_play = now
	if state.platform ~= 'windows' then return end
	-- Escape single quotes inside the PowerShell literal. Backslashes
	-- inside single-quoted PowerShell strings are kept verbatim, so
	-- C:\Path\To\tick.wav goes through clean.
	local safe_path = path:gsub("'", "''")
	-- PlaySync blocks the subprocess until the WAV is done. The
	-- subprocess itself is async (mpv doesn't wait), so PlaySync just
	-- guarantees the player thread doesn't exit before audio finishes.
	-- Play() (non-sync) sometimes cuts the tail off when PowerShell
	-- exits immediately on short WAVs.
	mp.command_native_async({
		name = 'subprocess',
		playback_only = false,
		capture_stdout = false,
		capture_stderr = false,
		args = {
			'powershell', '-NoProfile', '-WindowStyle', 'Hidden', '-Command',
			string.format("(New-Object Media.SoundPlayer '%s').PlaySync()", safe_path)
		},
	}, function(_, result, err)
		if err then
			mp.msg.warn('liquid speedo tick subprocess error: ' .. tostring(err))
		end
	end)
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
	self._lg_vol_osd_until = self._lg_vol_osd_until or 0
	self._lg_seek_osd_until = self._lg_seek_osd_until or 0
	self._lg_speed_osd_until = self._lg_speed_osd_until or 0

	-- Suppress all stock uosc surfaces — we draw everything here.
	if Elements then
		local blocked = {
			'timeline', 'top_bar', 'volume', 'volume_slider', 'speed',
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

	local ink_rgb = liquid_theme_lib.current.ink
	local ink_bgr = _lg_bgr(ink_rgb)
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

	-- ===== Hover glow =====
	-- A subtle warm-gold luminosity painted on the icon (or text) the
	-- cursor is over. The glass pebble itself does NOT change on hover —
	-- only its glyph lights up. Knobs:
	--   LG_GLOW_COLOR     -- one hex RRGGBB used everywhere
	--   LG_GLOW_BLUR      -- libass \be iterations (1=tight, 10=soft cloud)
	--   LG_GLOW_ALPHA     -- libass alpha byte. &H00& solid, &HFF& invisible
	--   LG_ICON_GLOW_BORD -- screen-px thickness of the gold halo around an icon
	--                        (3 wisp, 5 noticeable, 8 strong)
	--   LG_TEXT_GLOW_BORD -- thickness of the gold outline around text
	local LG_GLOW_COLOR      = 'FFD24C'
	local LG_GLOW_BLUR       = 6
	local LG_GLOW_ALPHA      = '&H80&'
	local LG_ICON_GLOW_BORD  = 5
	local LG_TEXT_GLOW_BORD  = 6

	-- ===== ICON SIZING =====
	-- LG_ICON_SCALE is the fallback used for any icon that doesn't have
	-- its own entry in LG_ICON_SCALES below. Each value is a fraction of
	-- the pebble's height (btn_h, normally 42 px), so 0.46 → ~19 px icon.
	-- Bump a number to enlarge that one glyph; drop it to shrink it.
	-- The play/pause pebble uses sh (which scales up on hover) instead of
	-- btn_h, so its icon still feels alive even with a static fraction.
	local LG_ICON_SCALE = 0.46
	local LG_ICON_SCALES = {
		play              = 0.50,
		pause             = 0.50,
		prev              = 0.50,
		['next']          = 0.50,
		speed             = 0.55,
		subtitle          = 0.62,
		audio_track       = 0.55,
		info              = 0.55,
		playlist_play     = 0.55,
		settings          = 0.60,
		fullscreen_enter  = 0.55,
		fullscreen_exit   = 0.55,
		volume_up         = 0.55,
		volume_down       = 0.55,
		volume_mute       = 0.55,
		volume_off        = 0.55,
	}
	local function icon_scale_for(name)
		return LG_ICON_SCALES[name] or LG_ICON_SCALE
	end

	-- Paint an SVG icon centred at (cx, cy) at the given pixel size.
	-- When `is_hovered` is true, draw_glow_at first paints a fat blurred
	-- gold stroke that hugs the icon's silhouette, then the sharp
	-- ink-coloured icon is laid on top.
	local function draw_icon(name, cx, cy, size, is_hovered)
		if is_hovered then
			liquid_icons_lib.draw_glow_at(
				ass, name, cx, cy, size,
				LG_GLOW_COLOR, LG_GLOW_ALPHA,
				LG_ICON_GLOW_BORD, LG_GLOW_BLUR
			)
		end
		liquid_icons_lib.draw_at(ass, name, cx, cy, size, ink_rgb, '&H10&')
	end

	-- Emit a centred text label, optionally glowing on hover. The glow
	-- is a blurred gold outline (\bord + \3c) rather than a backdrop pill.
	local function draw_text_label(text, cx, cy, font_size, is_hovered)
		local x = math.floor(cx + 0.5)
		local y = math.floor(cy + 0.5)
		if is_hovered then
			ass:new_event()
			ass:append(string.format(
				'{\\an5\\pos(%d,%d)\\fnGeist\\fs%d\\b1\\bord%d\\3c&H%s&\\3a%s\\shad0\\be%d\\1c&H%s&\\1a&HFF&}%s',
				x, y, font_size, LG_TEXT_GLOW_BORD,
				_lg_bgr(LG_GLOW_COLOR), LG_GLOW_ALPHA, LG_GLOW_BLUR,
				ink_bgr, text
			))
		end
		ass:new_event()
		ass:append(string.format(
			'{\\an5\\pos(%d,%d)\\fnGeist\\fs%d\\b1\\bord0\\shad0\\1c&H%s&}%s',
			x, y, font_size, ink_bgr, text
		))
	end

	-- Back-compat shim — callers that already use this name still work.
	-- When scale_factor is nil the per-icon table picks the size.
	local function emit_centered_icon(slot_name, bx, by, bw, bh, scale_factor, is_hovered)
		local size = bh * (scale_factor or icon_scale_for(slot_name))
		draw_icon(slot_name, bx + bw / 2, by + bh / 2, size, is_hovered or false)
	end

	-- Glass pebble + centred icon. The pebble itself no longer reacts on
	-- hover; only the icon brightens.
	local function draw_button(bx, by, bw, bh, icon_name, is_hovered, icon_scale_factor, _glow_slot)
		draw_glass({
			x = bx, y = by, w = bw, h = bh, r = bh / 2,
			intensity = lg.intensity, show_frost = lg.show_frost, shadow_blur = 20,
		})
		local size = bh * (icon_scale_factor or icon_scale_for(icon_name))
		draw_icon(icon_name, bx + bw / 2, by + bh / 2, size, is_hovered)
	end

	-- Glass pebble + centred text label. Same hover policy as the icon
	-- variant: only the text gains a glow, not the pebble.
	local function draw_text_button(bx, by, bw, bh, label, is_hovered, font_size, _glow_slot)
		draw_glass({
			x = bx, y = by, w = bw, h = bh, r = bh / 2,
			intensity = lg.intensity, show_frost = lg.show_frost, shadow_blur = 20,
		})
		draw_text_label(label, bx + bw / 2, by + bh / 2, font_size or 13, is_hovered)
	end

	-- ==================== LAYOUT ====================
	local pad_x = 10
	local area_ax = self.ax + pad_x
	local area_bx = self.bx - pad_x
	local area_w  = area_bx - area_ax

	local btn_h = 42
	local btn_w = 42
	local btn_gap = 6
	local block_gap = 10
	local progress_h = 16
	local row_gap = 10

	-- ===== TIME BLOCK SIZING (#5) =====
	-- The "1:23 / 4:56   42 %" pill that sits to the right of the quality pill.
	-- The block is FIXED width (does not grow with text) so it stays put as
	-- duration ticks across new digits. Bump TIME_BLOCK_FS to make the text
	-- bigger; bump TIME_BLOCK_W to make the surrounding pebble wider; tweak
	-- TIME_TEXT_GAP to control the visual spacing between time and "%".
	local TIME_BLOCK_FS_WIDE   = 28   -- font size on a normal-width player
	local TIME_BLOCK_FS_NARROW = 18   -- font size on a portrait/vertical player
	local TIME_BLOCK_W_WIDE    = 250  -- fixed pill width on normal-width player
	local TIME_BLOCK_W_NARROW  = 200  -- fixed pill width on a narrow player
	local TIME_TEXT_GAP        = '    ' -- spacing between "X / Y" and "Z %"

	-- ===== QUALITY BLOCK SIZING (#6) =====
	-- The "HD / 1080p / 4K" pill. Fixed width so the layout doesn't reflow
	-- when a different resolution shows up.
	local QUALITY_FS_WIDE      = 24   -- font size on a normal-width player
	local QUALITY_FS_NARROW    = 18   -- font size on a narrow player
	local QUALITY_W_WIDE       = 90   -- fixed pill width on normal-width player
	local QUALITY_W_NARROW     = 64   -- fixed pill width on a narrow player

	-- ===== VOLUME PERCENT SIZING (inside the volume pill) =====
	local VOL_PCT_FS           = 22   -- was 18 — match the new time/quality scale
	local VOL_PCT_SLOT_W       = 64   -- horizontal slot reserved for "100 %"

	-- ===== FILENAME LABEL (#4) =====
	-- Shown left-aligned just above the progress bar while controls are visible.
	-- FILENAME_FONT must match a font family installed on the system OR a
	-- font file shipped inside portable_config/fonts/ (mpv auto-loads any
	-- *.ttf/.otf in that folder). The default 'Bahnschrift' ships with
	-- Windows 10+ and is condensed/modern — drop a .ttf into the fonts
	-- folder and update this name to swap in something custom.
	local FILENAME_FONT        = 'Bahnschrift SemiBold'
	local FILENAME_FS          = 30   -- font size
	local FILENAME_GAP         = 6    -- vertical gap above the progress bar
	local FILENAME_INSET       = 4    -- horizontal inset from the controls area edge
	local FILENAME_BORD        = 2    -- outline thickness — keeps the title legible
	                                   -- against bright video in both light/dark themes
	local FILENAME_SHAD        = 2    -- soft drop shadow under the title

	-- Responsive: detect if too narrow for single row (vertical/portrait video).
	local is_narrow = area_w < 500
	-- Portrait video → compact controls: only Play/Pause, Prev/Next, Time (no %),
	-- Fullscreen, plus a vertical Volume column rendered outside the controls
	-- area. Driven by the player-wide orientation flag from lib/liquid/layout.
	local is_portrait = (_G.liquid_glass and _G.liquid_glass.orientation == 'portrait') or false
	local btn_row_y, progress_y
	if is_narrow and not is_portrait then
		-- Two-row layout: progress bar on top, then row 1 (main), then row 2 (right buttons).
		local row2_y = self.by - btn_h - 2
		btn_row_y = row2_y - btn_h - row_gap
		progress_y = btn_row_y - row_gap - progress_h
	else
		btn_row_y = self.by - btn_h - 4
		progress_y = btn_row_y - row_gap - progress_h
	end

	-- ==================== 0. FILENAME LABEL (#4) ====================
	-- Sits above the progress bar, left-aligned, only while controls are showing.
	-- Skipped in portrait/compact mode — no horizontal room for a title.
	if not is_portrait then do
		local fname = mp.get_property('filename', '')
		if fname and fname ~= '' then
			-- Rough character-budget so we don't overflow the player width.
			local avg_char_w = FILENAME_FS * 0.55
			local max_chars = math.floor((area_w - FILENAME_INSET * 2) / avg_char_w)
			local display_name = fname
			if max_chars > 8 and #fname > max_chars then
				display_name = fname:sub(1, max_chars - 1) .. '…'
			end
			-- ASS-escape braces / backslashes that would otherwise be parsed as tags.
			display_name = display_name:gsub('\\', '\\\\'):gsub('{', '\\{'):gsub('}', '\\}')
			ass:new_event()
			ass:append(string.format(
				'{\\an1\\pos(%d,%d)\\fn%s\\fs%d\\bord%d\\3c&H000000&\\3a&H10&' ..
				'\\shad%d\\4c&H000000&\\4a&H40&\\1c&H%s&}%s',
				area_ax + FILENAME_INSET,
				progress_y - FILENAME_GAP,
				FILENAME_FONT,
				FILENAME_FS,
				FILENAME_BORD,
				FILENAME_SHAD,
				ink_bgr,
				display_name
			))
		end
	end end  -- /not is_portrait

	-- ==================== 1. PROGRESS BAR (full width, bigger + smoother) ====================
	draw_glass({
		x = area_ax, y = progress_y, w = area_w, h = progress_h, r = progress_h / 2,
		intensity = lg.intensity * 1.1, show_frost = lg.show_frost,
		shadow_blur = 24,
	})

	local progress = (state.duration and state.duration > 0)
		and ((state.time or 0) / state.duration) or 0
	if progress < 0 then progress = 0 elseif progress > 1 then progress = 1 end

	local trk_inset = 4
	local trk_h = progress_h - trk_inset * 2
	local trk_ax = area_ax + trk_inset
	local trk_bx = area_bx - trk_inset
	local trk_y  = progress_y + trk_inset
	local trk_w  = trk_bx - trk_ax
	emit_pill(trk_ax, trk_y, trk_bx, trk_h, 'FFFFFF', '&H90&')
	local fill_x = trk_ax + math.floor(trk_w * progress)
	if fill_x > trk_ax + trk_h then
		emit_pill(trk_ax, trk_y, fill_x, trk_h, 'FFFFFF', '&H20&')
	end
	local progress_hitbox = {ax = area_ax, ay = progress_y, bx = area_bx, by = progress_y + progress_h}

	if state.chapters and #state.chapters > 0 and state.duration and state.duration > 0 then
		for _, chapter in ipairs(state.chapters) do
			if chapter.time > 0 and chapter.time < state.duration then
				local tx = trk_ax + math.floor(trk_w * (chapter.time / state.duration))
				ass:new_event()
				ass:append(string.format(
					'{\\an7\\pos(0,0)\\bord0\\shad0\\1c&HFFFFFF&\\1a&H50&\\p1}m %d %d l %d %d l %d %d l %d %d{\\p0}',
					tx, trk_y, tx + 2, trk_y, tx + 2, trk_y + trk_h, tx, trk_y + trk_h
				))
			end
		end
	end

	-- ==================== 2. BUTTON ROW ====================
	local cx = area_ax

	-- Play / pause (spring hover-scale).
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
	local play_glow_x = cx - (sw - btn_w) / 2
	local play_glow_y = btn_row_y - (sh - btn_h) / 2
	draw_glass({
		x = play_glow_x, y = play_glow_y, w = sw, h = sh, r = sh / 2,
		intensity = lg.intensity, show_frost = lg.show_frost, shadow_blur = 20,
	})
	local play_icon = state.pause and 'play' or 'pause'
	draw_icon(play_icon,
		play_glow_x + sw / 2, play_glow_y + sh / 2,
		sh * icon_scale_for(play_icon), is_play_hover)
	cx = cx + btn_w + block_gap

	-- Prev + Next in one block.
	local pn_btn = btn_w + 6
	local pn_block_w = pn_btn * 2 + 2
	local prev_rect = {ax = cx, ay = btn_row_y, bx = cx + pn_btn, by = btn_row_y + btn_h}
	local next_cx = cx + pn_btn + 2
	local next_rect = {ax = next_cx, ay = btn_row_y, bx = next_cx + pn_btn, by = btn_row_y + btn_h}
	local prev_hover = get_point_to_rectangle_proximity(cursor, prev_rect) == 0
	local next_hover = get_point_to_rectangle_proximity(cursor, next_rect) == 0
	draw_glass({ x = cx, y = btn_row_y, w = pn_block_w, h = btn_h, r = btn_h / 2, intensity = lg.intensity, show_frost = lg.show_frost, shadow_blur = 20 })
	emit_centered_icon('prev',  cx,       btn_row_y, pn_btn, btn_h, nil, prev_hover)
	emit_centered_icon('next',  next_cx,  btn_row_y, pn_btn, btn_h, nil, next_hover)
	cx = cx + pn_block_w + block_gap

	-- Speed, Quality, the inline Volume pill, and the optional right-cluster
	-- buttons (Settings/Subtitle/Audio/Info/Playlist) only appear in landscape
	-- mode. In portrait the only remaining controls are Play/Pause, Prev/Next,
	-- Times (no %), and Fullscreen — see below.
	local speed_rect, quality_rect, vol_icon_rect, vol_slider_rect
	local vs_ax, vs_bx, vol_fill_w
	local settings_rect, sub_rect, audio_rect, info_rect, playlist_rect
	local fs_rect

	if not is_portrait then
		-- Speed button (speedometer icon).
		speed_rect = {ax = cx, ay = btn_row_y, bx = cx + btn_w, by = btn_row_y + btn_h}
		self._lg_speed_rect = speed_rect  -- consumed by lg-scroll-* handlers
		local speed_hover = get_point_to_rectangle_proximity(cursor, speed_rect) == 0
		draw_button(cx, btn_row_y, btn_w, btn_h, 'speed', speed_hover)
		cx = cx + btn_w + btn_gap

		-- Quality button: shows current resolution + opens quality picker.
		local vid_h = mp.get_property_number('video-params/h', 0)
		local quality_label = 'HD'
		if vid_h >= 4320 then quality_label = '8K'
		elseif vid_h >= 2160 then quality_label = '4K'
		elseif vid_h >= 1440 then quality_label = '1440p'
		elseif vid_h >= 1080 then quality_label = '1080p'
		elseif vid_h >= 720 then quality_label = '720p'
		elseif vid_h >= 480 then quality_label = '480p'
		elseif vid_h >= 360 then quality_label = '360p'
		elseif vid_h >= 240 then quality_label = '240p'
		elseif vid_h >= 144 then quality_label = '144p'
		elseif vid_h > 0 then quality_label = tostring(vid_h) .. 'p'
		end
		local quality_fs = is_narrow and QUALITY_FS_NARROW or QUALITY_FS_WIDE
		local quality_w  = is_narrow and QUALITY_W_NARROW  or QUALITY_W_WIDE
		quality_rect = {ax = cx, ay = btn_row_y, bx = cx + quality_w, by = btn_row_y + btn_h}
		local quality_hover = get_point_to_rectangle_proximity(cursor, quality_rect) == 0
		draw_text_button(cx, btn_row_y, quality_w, btn_h, quality_label, quality_hover, quality_fs, 'quality')
		cx = cx + quality_w + block_gap
	end

	-- Time block. Landscape shows "1:23 / 4:56    42 %"; portrait drops the
	-- percentage per requirement ("Times (no %)") and uses a narrower pill.
	local time_str = string.format('%s / %s',
		_lg_format_time(state.time or 0),
		_lg_format_time(state.duration or 0))
	local time_display
	local time_fs, time_block_w
	if is_portrait then
		time_display = time_str
		time_fs = TIME_BLOCK_FS_NARROW
		time_block_w = TIME_BLOCK_W_NARROW
	else
		local pct = math.floor(progress * 100)
		time_display = time_str .. TIME_TEXT_GAP .. pct .. ' %'
		time_fs      = is_narrow and TIME_BLOCK_FS_NARROW or TIME_BLOCK_FS_WIDE
		time_block_w = is_narrow and TIME_BLOCK_W_NARROW  or TIME_BLOCK_W_WIDE
	end
	local time_rect  = {ax = cx, ay = btn_row_y, bx = cx + time_block_w, by = btn_row_y + btn_h}
	local time_hover = get_point_to_rectangle_proximity(cursor, time_rect) == 0
	draw_glass({ x = cx, y = btn_row_y, w = time_block_w, h = btn_h, r = btn_h / 2, intensity = lg.intensity * 0.9, show_frost = lg.show_frost, shadow_blur = 20 })
	draw_text_label(time_display, cx + time_block_w / 2, btn_row_y + btn_h / 2, time_fs, time_hover)
	cx = cx + time_block_w + block_gap

	if not is_portrait then
		-- Inline Volume pill: icon + horizontal slider + percentage.
		local vol_slider_w = is_narrow and 80 or 110
		local vol_pct_w = VOL_PCT_SLOT_W
		local vol_block_w = btn_w + 8 + vol_slider_w + vol_pct_w
		local vol_block_x = cx
		local vol_block_rect_pre = {ax = cx, ay = btn_row_y, bx = cx + vol_block_w, by = btn_row_y + btn_h}
		local vol_block_hover = get_point_to_rectangle_proximity(cursor, vol_block_rect_pre) == 0
		draw_glass({ x = cx, y = btn_row_y, w = vol_block_w, h = btn_h, r = btn_h / 2, intensity = lg.intensity * 0.9, show_frost = lg.show_frost, shadow_blur = 20 })
		vol_icon_rect = {ax = cx, ay = btn_row_y, bx = cx + btn_w, by = btn_row_y + btn_h}
		local vol_icon_hover = get_point_to_rectangle_proximity(cursor, vol_icon_rect) == 0
		local vol_icon = 'volume_up'
		if state.mute then vol_icon = 'volume_off'
		elseif (state.volume or 0) <= 0 then vol_icon = 'volume_mute'
		elseif (state.volume or 0) <= 60 then vol_icon = 'volume_down'
		end
		emit_centered_icon(vol_icon, cx, btn_row_y, btn_w, btn_h, nil, vol_icon_hover or vol_block_hover)
		vs_ax = cx + btn_w + 8
		vs_bx = cx + btn_w + 8 + vol_slider_w
		local vs_h = 8
		local vs_y = btn_row_y + (btn_h - vs_h) / 2
		emit_pill(vs_ax, vs_y, vs_bx, vs_h, 'FFFFFF', '&H80&')
		local vol_frac = math.min((state.volume or 0) / (state.volume_max or 100), 1)
		if vol_frac < 0 then vol_frac = 0 end
		vol_fill_w = vs_bx - vs_ax
		local vol_filled_x = vs_ax + math.floor(vol_fill_w * vol_frac)
		if vol_filled_x > vs_ax + vs_h then
			emit_pill(vs_ax, vs_y, vol_filled_x, vs_h, 'FFFFFF', '&H20&')
		end
		local vol_pct_text = tostring(math.floor((state.volume or 0) + 0.5)) .. ' %'
		local vol_pct_center_x = (vs_bx + cx + vol_block_w) / 2
		draw_text_label(vol_pct_text, vol_pct_center_x, btn_row_y + btn_h / 2, VOL_PCT_FS, vol_block_hover)
		vol_slider_rect = {ax = vs_ax, ay = btn_row_y, bx = vs_bx, by = btn_row_y + btn_h}
		local vol_block_rect = {ax = vol_block_x, ay = btn_row_y, bx = vol_block_x + vol_block_w, by = btn_row_y + btn_h}
		self._lg_vol_block_rect = vol_block_rect
		cx = cx + vol_block_w + block_gap
	end

	-- Right-side buttons. On narrow screens, use row 2. Portrait keeps only
	-- Fullscreen + Settings on the same row — Subtitle/Audio/Info/Playlist
	-- still reachable via the settings menu and input.conf bindings.
	local rrow_y = is_narrow and (self.by - btn_h - 2) or btn_row_y
	local rx = area_bx
	local rbtn = btn_w + 6

	-- Fullscreen (always visible).
	rx = rx - rbtn
	fs_rect = {ax = rx, ay = rrow_y, bx = rx + rbtn, by = rrow_y + btn_h}
	local fs_hover = get_point_to_rectangle_proximity(cursor, fs_rect) == 0
	draw_button(rx, rrow_y, rbtn, btn_h, state.fullscreen and 'fullscreen_exit' or 'fullscreen_enter', fs_hover)
	rx = rx - btn_gap

	-- Settings 3-dot menu (always visible — in portrait this is the only
	-- way to reach subtitle/audio/playlist pickers).
	rx = rx - rbtn
	settings_rect = {ax = rx, ay = rrow_y, bx = rx + rbtn, by = rrow_y + btn_h}
	local settings_hover = get_point_to_rectangle_proximity(cursor, settings_rect) == 0
	draw_button(rx, rrow_y, rbtn, btn_h, 'settings', settings_hover)
	rx = rx - btn_gap

	if not is_portrait then
		-- Subtitle: render the SVG icon now (was "CC" text).
		local sub_w = rbtn
		rx = rx - sub_w
		sub_rect = {ax = rx, ay = rrow_y, bx = rx + sub_w, by = rrow_y + btn_h}
		local sub_hover = get_point_to_rectangle_proximity(cursor, sub_rect) == 0
		draw_button(rx, rrow_y, sub_w, btn_h, 'subtitle', sub_hover)
		rx = rx - btn_gap

		-- Audio (musical-track-list svg).
		local audio_w = rbtn
		rx = rx - audio_w
		audio_rect = {ax = rx, ay = rrow_y, bx = rx + audio_w, by = rrow_y + btn_h}
		local audio_hover = get_point_to_rectangle_proximity(cursor, audio_rect) == 0
		draw_button(rx, rrow_y, audio_w, btn_h, 'audio_track', audio_hover)
		rx = rx - btn_gap

		-- Info: opens mpv stats overlay.
		local info_w = btn_h
		rx = rx - info_w
		info_rect = {ax = rx, ay = rrow_y, bx = rx + info_w, by = rrow_y + btn_h}
		local info_hover = get_point_to_rectangle_proximity(cursor, info_rect) == 0
		draw_button(rx, rrow_y, info_w, btn_h, 'info', info_hover)
		rx = rx - btn_gap

		-- Playlist (with play marker).
		local pl_w = btn_h
		rx = rx - pl_w
		playlist_rect = {ax = rx, ay = rrow_y, bx = rx + pl_w, by = rrow_y + btn_h}
		local playlist_hover = get_point_to_rectangle_proximity(cursor, playlist_rect) == 0
		draw_button(rx, rrow_y, pl_w, btn_h, 'playlist_play', playlist_hover)
	end

	-- Portrait mode intentionally renders no volume control here — there's
	-- not enough room without crowding the row, and mpv's wheel-on-video
	-- binding plus the global volume hotkeys still work. Volume can also be
	-- reached through the Settings menu.

	-- ==================== 3. INTERACTIVITY ====================
	if cursor and cursor.zone then
		cursor:zone('primary_down', play_rect, function() mp.commandv('cycle', 'pause') end)
		cursor:zone('primary_down', prev_rect, function() mp.command('playlist-prev') end)
		cursor:zone('primary_down', next_rect, function() mp.command('playlist-next') end)
		if speed_rect then
			cursor:zone('primary_down', speed_rect, function()
				local speeds = {0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0}
				local items = {}
				for _, s in ipairs(speeds) do
					local label = (s == 1.0) and 'Normal' or string.format('%.2gx', s)
					local active = math.abs((state.speed or 1) - s) < 0.01
					items[#items + 1] = {title = label, value = 'set speed ' .. s, active = active}
				end
				mp.commandv('script-message-to', 'uosc', 'open-menu', require('mp.utils').format_json({
					type = 'lg_speed', title = 'Speed', items = items
				}))
			end)
		end
		if quality_rect then
			cursor:zone('primary_down', quality_rect, function()
				local path = mp.get_property('path', '')
				local is_stream = path:match('^https?://') or path:match('^ytdl://')
				if is_stream then
					mp.command('script-binding uosc/stream-quality')
				else
					local vw = mp.get_property_number('video-params/w', 0)
					local vh = mp.get_property_number('video-params/h', 0)
					local codec = mp.get_property('video-codec', '?')
					local fps = mp.get_property_number('container-fps', 0)
					local fps_str = fps > 0 and string.format('%.1f fps', fps) or ''
					local br = mp.get_property_number('video-bitrate', 0)
					local br_str = br > 0 and string.format('%.1f Mbps', br / 1000000) or ''
					local info = string.format('%dx%d  %s  %s  %s', vw, vh, codec, fps_str, br_str)
					mp.commandv('script-message-to', 'uosc', 'open-menu', require('mp.utils').format_json({
						type = 'lg_quality', title = 'Video Quality',
						items = {{title = info, value = '', active = true}}
					}))
				end
			end)
		end
		if vol_icon_rect then
			cursor:zone('primary_down', vol_icon_rect, function() mp.commandv('cycle', 'mute') end)
		end
		if vol_slider_rect then
			cursor:zone('primary_down', vol_slider_rect, function()
				local frac = (cursor.x - vs_ax) / vol_fill_w
				if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
				mp.commandv('set', 'volume', math.floor(frac * (state.volume_max or 100)))
			end)
		end

		-- All scroll handling is routed through input.conf → lg-scroll-up/down
		-- script messages (global handler below). No cursor:zone wheel
		-- registrations here — they would intercept events before input.conf.

		-- Progress bar click-to-seek + drag scrub.
		local seek_ax = trk_ax
		local seek_w  = trk_w
		local function seek_to_cursor(fast)
			if not (state.duration and state.duration > 0) then return end
			local cx_pos = cursor.x - seek_ax
			if cx_pos < 0 then cx_pos = 0 elseif cx_pos > seek_w then cx_pos = seek_w end
			mp.commandv('seek', state.duration * cx_pos / seek_w, fast and 'absolute+keyframes' or 'absolute+exact')
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

		cursor:zone('primary_down', fs_rect, function() mp.commandv('cycle', 'fullscreen') end)
		if settings_rect then
			cursor:zone('primary_down', settings_rect, function() mp.command('script-binding uosc/menu') end)
		end
		if sub_rect then
			cursor:zone('primary_down', sub_rect, function() mp.command('script-binding uosc/subtitles') end)
		end
		if audio_rect then
			cursor:zone('primary_down', audio_rect, function() mp.command('script-binding uosc/audio') end)
		end
		if info_rect then
			cursor:zone('primary_down', info_rect, function()
				-- Toggle mpv's built-in stats overlay; gives codec/fps/bitrate/etc.
				mp.command('script-binding stats/display-stats-toggle')
			end)
		end
		if playlist_rect then
			cursor:zone('primary_down', playlist_rect, function() mp.command('script-binding uosc/items') end)
		end
	end

	-- ==================== 4. CENTERED OSD OVERLAYS (macOS style) ====================
	-- Centered on the full player window, not the controls area.
	local now = mp.get_time()
	local win_cx = display.width / 2
	local win_cy = display.height / 2

	-- Only one OSD at a time: volume > speed > seek priority.
	local show_vol_osd   = now < (self._lg_vol_osd_until or 0)
	local show_speed_osd = (not show_vol_osd) and now < (self._lg_speed_osd_until or 0)
	local show_seek_osd  = (not show_vol_osd) and (not show_speed_osd)
	                       and now < (self._lg_seek_osd_until or 0)

	if show_vol_osd then
		local osd_w, osd_h = 220, 180
		local osd_x = win_cx - osd_w / 2
		local osd_y = win_cy - osd_h / 2
		draw_glass({
			x = osd_x, y = osd_y, w = osd_w, h = osd_h, r = 28,
			intensity = lg.intensity * 1.8, show_frost = lg.show_frost, shadow_blur = 40,
		})
		-- Big speaker icon — same SVG family as the volume-bar control.
		local vol_icon_name = 'volume_up'
		if state.mute then vol_icon_name = 'volume_off'
		elseif (state.volume or 0) <= 0 then vol_icon_name = 'volume_mute'
		elseif (state.volume or 0) <= 60 then vol_icon_name = 'volume_down'
		end
		liquid_icons_lib.draw_at(ass, vol_icon_name, win_cx, win_cy - 18, 90, ink_rgb, '&H10&')
		-- Volume percentage below
		local vol_text = tostring(math.floor((state.volume or 0) + 0.5)) .. ' %'
		ass:new_event()
		ass:append(string.format(
			'{\\an5\\pos(%d,%d)\\fnGeist\\fs28\\b1\\bord0\\shad0\\1c&H%s&}%s',
			win_cx, win_cy + 52, ink_bgr, vol_text
		))
		if now < self._lg_vol_osd_until - 0.05 then request_render() end
	end

	if show_speed_osd then
		-- ---------- Speedometer OSD ----------
		-- Tunables — bump radii up if you grow OSD_SIZE.
		local OSD_SIZE       = 400          -- glass block size (square)
		local R_RIM          = 162          -- thin decorative outer ring
		local R_PROGRESS     = 156          -- accent-coloured fill arc
		local R_OUT          = 150          -- outer end of tick marks
		local R_MAJOR_IN     = 126          -- inner end of major ticks (24 px)
		local R_MINOR_IN     = 138          -- inner end of minor ticks (12 px)
		local R_LABEL        = 102          -- numeric labels radius
		local NEEDLE_LEN     = 128
		local NEEDLE_BACK    = 14
		local HUB_R          = 11
		local LABEL_FS       = 24           -- WAS 14 — much bigger now
		local VALUE_FS       = 48           -- the big centred speed text
		local SUBTITLE_FS    = 15
		local RIM_BORD       = 1.8          -- outer ring stroke thickness
		local PROGRESS_BORD  = 5            -- fill-arc stroke thickness

		local osd_x = win_cx - OSD_SIZE / 2
		local osd_y = win_cy - OSD_SIZE / 2
		draw_glass({
			x = osd_x, y = osd_y, w = OSD_SIZE, h = OSD_SIZE, r = 36,
			intensity = lg.intensity * 1.8, show_frost = lg.show_frost, shadow_blur = 40,
		})

		-- Helper: emit an arc as a stroked polyline (\bord gives thickness).
		local function emit_arc(radius, start_deg, end_deg, color_rgb, alpha_byte, bord)
			local span = math.abs(end_deg - start_deg)
			local samples = math.max(8, math.ceil(span / 4))
			local parts = {}
			for i = 0, samples do
				local a = start_deg + (end_deg - start_deg) * (i / samples)
				local theta = math.rad(a - 90)
				local x = win_cx + math.cos(theta) * radius
				local y = win_cy + math.sin(theta) * radius
				parts[#parts + 1] = string.format('%s %.1f %.1f',
					i == 0 and 'm' or 'l', x, y)
			end
			ass:new_event()
			ass:append(string.format(
				'{\\an7\\pos(0,0)\\bord%.2f\\shad0\\1a&HFF&\\3c&H%s&\\3a%s\\p1}%s{\\p0}',
				bord, _lg_bgr(color_rgb), alpha_byte, table.concat(parts, ' ')
			))
		end

		-- ---- Spring physics for the needle ----
		local cur_speed = state.speed or 1.0
		-- Nearest step → target angle.
		local nearest_idx = 1
		local nearest_diff = math.huge
		for i, s in ipairs(LG_SPEED_STEPS) do
			local d = math.abs(s - cur_speed)
			if d < nearest_diff then nearest_diff = d; nearest_idx = i end
		end
		local function angle_for_index(i)
			return LG_SPEED_ANGLE_START + (i - 1) * (LG_SPEED_ANGLE_SPAN / (#LG_SPEED_STEPS - 1))
		end
		local target_angle = angle_for_index(nearest_idx)

		self._lg_speed_current_angle = self._lg_speed_current_angle or target_angle
		self._lg_speed_velocity      = self._lg_speed_velocity or 0
		self._lg_speed_last_t        = self._lg_speed_last_t or now

		local dt = math.min(0.05, now - self._lg_speed_last_t)
		self._lg_speed_last_t = now
		local prev_angle = self._lg_speed_current_angle
		local v = self._lg_speed_velocity
		-- Semi-implicit Euler spring step.
		v = v + (target_angle - prev_angle) * LG_SPEED_STIFFNESS * dt
		v = v - v * LG_SPEED_DAMPING * dt
		self._lg_speed_current_angle = prev_angle + v * dt
		self._lg_speed_velocity = v

		-- ---- Tick-crossing detection (visual gold flash only) ----
		-- Audio ticks are fired by the scroll handler so the user hears
		-- exactly one tick per scroll click. The visual flash still
		-- responds to every needle pass — it's part of the physics feel.
		self._lg_speed_tick_flash = self._lg_speed_tick_flash or {}
		do
			local lo = math.min(prev_angle, self._lg_speed_current_angle)
			local hi = math.max(prev_angle, self._lg_speed_current_angle)
			for i = 1, #LG_SPEED_STEPS do
				local ta = angle_for_index(i)
				if lo < ta and ta <= hi then
					self._lg_speed_tick_flash[i] = now
				end
			end
		end

		local current_angle = self._lg_speed_current_angle

		-- ---- Outer decorative rim (faint full sweep) ----
		emit_arc(R_RIM, LG_SPEED_ANGLE_START, LG_SPEED_ANGLE_END,
			ink_rgb, '&H90&', RIM_BORD)

		-- ---- Scale ticks + labels ----
		for i, s in ipairs(LG_SPEED_STEPS) do
			local a = angle_for_index(i)
			local theta = math.rad(a - 90)  -- 0° up → math 0° right
			local cos_t, sin_t = math.cos(theta), math.sin(theta)
			local x1, y1 = win_cx + cos_t * R_OUT, win_cy + sin_t * R_OUT
			-- Major step (whole numbers) vs minor (the 0.25/0.5/0.75 fractions).
			local is_major = (math.abs(s - math.floor(s + 0.5)) < 0.01)
			local r_in = is_major and R_MAJOR_IN or R_MINOR_IN
			local x2, y2 = win_cx + cos_t * r_in, win_cy + sin_t * r_in
			-- Flash colour if recently crossed.
			local flash_t = self._lg_speed_tick_flash[i]
			local is_flashing = flash_t and (now - flash_t) < LG_SPEED_FLASH_DUR
			local tick_color = is_flashing and LG_GLOW_COLOR or ink_rgb
			local tick_alpha = is_major and '&H00&' or '&H50&'
			if is_flashing then tick_alpha = '&H00&' end
			local tick_w = is_major and 3.5 or 2
			-- Emit as a thin rectangle along the radial direction.
			local px, py = -sin_t, cos_t
			local hw = tick_w / 2
			ass:new_event()
			ass:append(string.format(
				'{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H%s&\\1a%s\\p1}m %.1f %.1f l %.1f %.1f l %.1f %.1f l %.1f %.1f{\\p0}',
				_lg_bgr(tick_color), tick_alpha,
				x1 + px * hw, y1 + py * hw,
				x2 + px * hw, y2 + py * hw,
				x2 - px * hw, y2 - py * hw,
				x1 - px * hw, y1 - py * hw
			))
			-- Numeric label for major ticks only (keeps the dial clean).
			if is_major then
				local lx, ly = win_cx + cos_t * R_LABEL, win_cy + sin_t * R_LABEL
				local label = string.format('%.2g', s)
				-- The label "flashes" too — same gold pulse when its tick crosses.
				local label_color = is_flashing and LG_GLOW_COLOR or ink_rgb
				ass:new_event()
				ass:append(string.format(
					'{\\an5\\pos(%d,%d)\\fnGeist\\fs%d\\b1\\bord2\\3c&H000000&\\3a&H50&\\shad0\\1c&H%s&}%s',
					math.floor(lx + 0.5), math.floor(ly + 0.5),
					LABEL_FS, _lg_bgr(label_color), label
				))
			end
		end

		-- ---- Needle (rotated trapezoid) ----
		do
			local theta = math.rad(current_angle - 90)
			local nx, ny = math.cos(theta), math.sin(theta)
			local px, py = -ny, nx
			local base_w = 5
			local tip_w  = 1.2
			local bx1 = win_cx + px * base_w / 2 + nx * (-NEEDLE_BACK)
			local by1 = win_cy + py * base_w / 2 + ny * (-NEEDLE_BACK)
			local bx2 = win_cx - px * base_w / 2 + nx * (-NEEDLE_BACK)
			local by2 = win_cy - py * base_w / 2 + ny * (-NEEDLE_BACK)
			local tx1 = win_cx + px * tip_w / 2 + nx * NEEDLE_LEN
			local ty1 = win_cy + py * tip_w / 2 + ny * NEEDLE_LEN
			local tx2 = win_cx - px * tip_w / 2 + nx * NEEDLE_LEN
			local ty2 = win_cy - py * tip_w / 2 + ny * NEEDLE_LEN
			ass:new_event()
			ass:append(string.format(
				'{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H%s&\\1a&H00&\\p1}m %.1f %.1f l %.1f %.1f l %.1f %.1f l %.1f %.1f{\\p0}',
				accent_bgr,
				bx1, by1, tx1, ty1, tx2, ty2, bx2, by2
			))
		end

		-- ---- Centre hub (filled accent disc + thin ink ring) ----
		do
			local n = 18
			local parts = {}
			for k = 0, n - 1 do
				local a = (k / n) * 2 * math.pi
				local x = win_cx + math.cos(a) * HUB_R
				local y = win_cy + math.sin(a) * HUB_R
				parts[#parts + 1] = string.format('%s %.1f %.1f', k == 0 and 'm' or 'l', x, y)
			end
			ass:new_event()
			ass:append(string.format(
				'{\\an7\\pos(0,0)\\bord1.5\\shad0\\3c&H%s&\\3a&H00&\\1c&H%s&\\1a&H00&\\p1}%s{\\p0}',
				ink_bgr, accent_bgr, table.concat(parts, ' ')
			))
		end

		-- ---- Big value text below centre ----
		local val_text = string.format('%.2g×', cur_speed)
		ass:new_event()
		ass:append(string.format(
			'{\\an5\\pos(%d,%d)\\fnGeist\\fs%d\\b1\\bord2\\3c&H000000&\\3a&H40&\\shad0\\1c&H%s&}%s',
			win_cx, win_cy + 90, VALUE_FS, ink_bgr, val_text
		))
		-- Subtitle "PLAYBACK SPEED" below the value, lighter weight.
		ass:new_event()
		ass:append(string.format(
			'{\\an5\\pos(%d,%d)\\fnGeist\\fs%d\\b1\\bord0\\shad0\\1c&H%s&\\1a&H60&}PLAYBACK SPEED',
			win_cx, win_cy + 126, SUBTITLE_FS, ink_bgr
		))

		-- Keep rendering until the needle settles AND the OSD timeout has passed.
		local needs_anim = math.abs(target_angle - self._lg_speed_current_angle) > 0.05
		                 or math.abs(self._lg_speed_velocity) > 0.5
		if needs_anim or now < self._lg_speed_osd_until - 0.05 then
			request_render()
		end
	end

	if show_seek_osd then
		local osd_w, osd_h = 220, 180
		local osd_x = win_cx - osd_w / 2
		local osd_y = win_cy - osd_h / 2
		draw_glass({
			x = osd_x, y = osd_y, w = osd_w, h = osd_h, r = 28,
			intensity = lg.intensity * 1.8, show_frost = lg.show_frost, shadow_blur = 40,
		})
		-- Big video camera icon (user-provided SVG).
		liquid_icons_lib.draw_at(ass, 'video_camera', win_cx, win_cy - 18, 90, ink_rgb, '&H10&')
		-- Progress percentage below
		local seek_pct = (state.duration and state.duration > 0)
			and math.floor(((state.time or 0) / state.duration) * 100) or 0
		local seek_text = tostring(seek_pct) .. ' %'
		ass:new_event()
		ass:append(string.format(
			'{\\an5\\pos(%d,%d)\\fnGeist\\fs28\\b1\\bord0\\shad0\\1c&H%s&}%s',
			win_cx, win_cy + 52, ink_bgr, seek_text
		))
		if now < self._lg_seek_osd_until - 0.05 then request_render() end
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

-- Global scroll handler: input.conf routes WHEEL_UP/DOWN here.
-- If cursor is over the volume block, adjust volume + show volume OSD.
-- Otherwise, seek + show seek OSD.
-- Cursor-over-rect helper (the controls patch uses several of these).
local function _lg_cursor_in_rect(rect)
	return rect and cursor
		and cursor.x >= rect.ax and cursor.x <= rect.bx
		and cursor.y >= rect.ay and cursor.y <= rect.by
end

-- Step the speed by +/- 1 entry in LG_SPEED_STEPS, snapping to the
-- nearest existing step first if the current value is off-grid.
-- Returns the index of the previously-snapped speed (so the caller can
-- seed the needle's starting angle for the spring animation).
local function _lg_step_speed(direction)
	local cur = state.speed or 1.0
	local nearest_i, nearest_d = 1, math.huge
	for i, s in ipairs(LG_SPEED_STEPS) do
		local d = math.abs(s - cur)
		if d < nearest_d then nearest_d = d; nearest_i = i end
	end
	-- If we're sitting cleanly on a step, move by `direction`; otherwise
	-- the snap itself already moved us in the direction the user wants
	-- (e.g. 1.07× with +1 → snap to 1.0× then bump to 1.25×).
	local prev_i = nearest_i
	local target_i = nearest_i
	if nearest_d < 0.01 then target_i = nearest_i + direction
	elseif direction > 0 and LG_SPEED_STEPS[nearest_i] < cur then target_i = nearest_i + 1
	elseif direction < 0 and LG_SPEED_STEPS[nearest_i] > cur then target_i = nearest_i - 1
	end
	target_i = math.max(1, math.min(#LG_SPEED_STEPS, target_i))
	mp.commandv('no-osd', 'set', 'speed', LG_SPEED_STEPS[target_i])
	return prev_i
end

-- Seed the needle's current angle to the OLD speed step so the spring
-- has somewhere to swing FROM. No-op on second and later scrolls
-- because we keep the in-flight angle.
local function _lg_seed_needle_angle(ctrl, prev_i)
	if ctrl._lg_speed_current_angle == nil then
		ctrl._lg_speed_current_angle =
			LG_SPEED_ANGLE_START + (prev_i - 1) * (LG_SPEED_ANGLE_SPAN / (#LG_SPEED_STEPS - 1))
		ctrl._lg_speed_velocity = 0
	end
end

mp.register_script_message('lg-scroll-up', function()
	local ctrl = Elements and Elements.controls
	if not ctrl then mp.commandv('no-osd', 'seek', 5, 'relative+exact'); return end
	if _lg_cursor_in_rect(ctrl._lg_speed_rect) then
		local prev_i = _lg_step_speed(1)
		_lg_seed_needle_angle(ctrl, prev_i)
		_lg_play_tick_sound()
		ctrl._lg_speed_osd_until = mp.get_time() + LG_SPEED_OSD_HOLD
		ctrl._lg_vol_osd_until = 0
		ctrl._lg_seek_osd_until = 0
	elseif _lg_cursor_in_rect(ctrl._lg_vol_block_rect) then
		local new_vol = math.min((state.volume or 0) + 5, state.volume_max or 100)
		mp.commandv('no-osd', 'set', 'volume', new_vol)
		ctrl._lg_vol_osd_until = mp.get_time() + 2
		ctrl._lg_seek_osd_until = 0
	else
		mp.commandv('no-osd', 'seek', 5, 'relative+exact')
		ctrl._lg_seek_osd_until = mp.get_time() + 2
		ctrl._lg_vol_osd_until = 0
	end
	request_render()
end)

mp.register_script_message('lg-scroll-down', function()
	local ctrl = Elements and Elements.controls
	if not ctrl then mp.commandv('no-osd', 'seek', -5, 'relative+exact'); return end
	if _lg_cursor_in_rect(ctrl._lg_speed_rect) then
		local prev_i = _lg_step_speed(-1)
		_lg_seed_needle_angle(ctrl, prev_i)
		_lg_play_tick_sound()
		ctrl._lg_speed_osd_until = mp.get_time() + LG_SPEED_OSD_HOLD
		ctrl._lg_vol_osd_until = 0
		ctrl._lg_seek_osd_until = 0
	elseif _lg_cursor_in_rect(ctrl._lg_vol_block_rect) then
		local new_vol = math.max((state.volume or 0) - 5, 0)
		mp.commandv('no-osd', 'set', 'volume', new_vol)
		ctrl._lg_vol_osd_until = mp.get_time() + 2
		ctrl._lg_seek_osd_until = 0
	else
		mp.commandv('no-osd', 'seek', -5, 'relative+exact')
		ctrl._lg_seek_osd_until = mp.get_time() + 2
		ctrl._lg_vol_osd_until = 0
	end
	request_render()
end)

-- Keyboard-driven controls. Mirror the scroll wheel's centered OSD so that
-- seeking / volume changes from the keyboard get the same visual feedback.
local function _lg_show_seek_osd()
	local ctrl = Elements and Elements.controls
	if not ctrl then return end
	ctrl._lg_seek_osd_until = mp.get_time() + 2
	ctrl._lg_vol_osd_until = 0
	ctrl._lg_speed_osd_until = 0
	request_render()
end

local function _lg_show_vol_osd()
	local ctrl = Elements and Elements.controls
	if not ctrl then return end
	ctrl._lg_vol_osd_until = mp.get_time() + 2
	ctrl._lg_seek_osd_until = 0
	ctrl._lg_speed_osd_until = 0
	request_render()
end

-- Relative seek by N seconds (N may be negative), with the centered seek OSD.
mp.register_script_message('lg-seek', function(amount)
	mp.commandv('no-osd', 'seek', tonumber(amount) or 0, 'relative+exact')
	_lg_show_seek_osd()
end)

-- Absolute seek to a percentage of the video (0-100), with the centered seek OSD.
mp.register_script_message('lg-seek-percent', function(percent)
	mp.commandv('no-osd', 'seek', tonumber(percent) or 0, 'absolute-percent+exact')
	_lg_show_seek_osd()
end)

-- Adjust volume by N (N may be negative), clamped, with the centered volume OSD.
mp.register_script_message('lg-volume', function(delta)
	local new_vol = (state.volume or 0) + (tonumber(delta) or 0)
	new_vol = math.max(0, math.min(new_vol, state.volume_max or 100))
	mp.commandv('no-osd', 'set', 'volume', new_vol)
	_lg_show_vol_osd()
end)
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
