local Element = require('elements/Element')

--[[ VolumeSlider ]]

---@class VolumeSlider : Element
local VolumeSlider = class(Element)
---@param props? ElementProps
function VolumeSlider:new(props) return Class.new(self, props) --[[@as VolumeSlider]] end
function VolumeSlider:init(props)
	Element.init(self, 'volume_slider', props)
	self.pressed = false
	self.nudge_y = 0 -- vertical position where volume overflows 100
	self.nudge_size = 0
	self.draw_nudge = false
	self.spacing = 0
	self.border_size = 0
	self:update_dimensions()
end

function VolumeSlider:update_dimensions()
	self.border_size = math.max(0, round(options.volume_border * state.scale))
end

function VolumeSlider:get_visibility() return Elements.volume:get_visibility(self) end

function VolumeSlider:set_volume(volume)
	volume = round(volume / options.volume_step) * options.volume_step
	if state.volume == volume then return end
	mp.commandv('set', 'volume', clamp(0, volume, state.volume_max))
end

function VolumeSlider:set_from_cursor()
	local volume_fraction = (self.by - cursor.y - self.border_size) / (self.by - self.ay - self.border_size)
	self:set_volume(volume_fraction * state.volume_max)
end

function VolumeSlider:on_display() self:update_dimensions() end
function VolumeSlider:on_options() self:update_dimensions() end
function VolumeSlider:on_coordinates()
	if type(state.volume_max) ~= 'number' or state.volume_max <= 0 then return end
	local width = self.bx - self.ax
	self.nudge_y = self.by - round((self.by - self.ay) * (100 / state.volume_max))
	self.nudge_size = round(width * 0.18)
	self.draw_nudge = self.ay < self.nudge_y
	self.spacing = round(width * 0.2)
end
function VolumeSlider:on_global_mouse_move()
	if self.pressed then self:set_from_cursor() end
end
function VolumeSlider:handle_wheel_up() self:set_volume(state.volume + options.volume_step) end
function VolumeSlider:handle_wheel_down() self:set_volume(state.volume - options.volume_step) end

function VolumeSlider:render()
    local visibility = self:get_visibility()
    local ax, ay, bx, by = self.ax, self.ay, self.bx, self.by
    local width, height = bx - ax, by - ay
    if width <= 0 or height <= 0 or visibility <= 0 then return end

    cursor:zone('primary_down', self, function()
        self.pressed = true
        self:set_from_cursor()
        cursor:once('primary_up', function() self.pressed = false end)
    end)
    cursor:zone('wheel_down', self, function() self:handle_wheel_down() end)
    cursor:zone('wheel_up', self, function() self:handle_wheel_up() end)

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

    local pebble_r = math.min(width, height) / 2
    draw_glass({
        x = ax, y = ay, w = width, h = height, r = pebble_r,
        intensity = lg.intensity, show_frost = lg.show_frost,
    })

    local vol_fraction = math.min((state.volume or 0) / (state.volume_max or 100), 1)
    if vol_fraction < 0 then vol_fraction = 0 end
    local fill_inset = 4
    local fill_full_h = height - fill_inset * 2
    local fill_h = math.floor(fill_full_h * vol_fraction)
    if fill_h > 0 then
        local accent = theme.current.accent
        local accent_bgr = accent:sub(5, 6) .. accent:sub(3, 4) .. accent:sub(1, 2)
        local fax = ax + fill_inset
        local fbx = bx - fill_inset
        local fby = by - fill_inset
        local fay = fby - fill_h
        ass:new_event()
        ass:append(string.format(
            '{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H%s&\\1a&H30&\\p1}m %d %d l %d %d l %d %d l %d %d{\\p0}',
            accent_bgr, fax, fay, fbx, fay, fbx, fby, fax, fby
        ))
    end

    if self.draw_nudge then
        ass:new_event()
        ass:append(string.format(
            '{\\an7\\pos(0,0)\\bord0\\shad0\\1c&HFFFFFF&\\1a&H80&\\p1}m %d %d l %d %d l %d %d l %d %d{\\p0}',
            ax + fill_inset, self.nudge_y,
            bx - fill_inset, self.nudge_y,
            bx - fill_inset, self.nudge_y + 1,
            ax + fill_inset, self.nudge_y + 1
        ))
    end

    return ass
end

--[[ Volume ]]

---@class Volume : Element
local Volume = class(Element)

function Volume:new() return Class.new(self) --[[@as Volume]] end
function Volume:init()
	Element.init(self, 'volume', {render_order = 7})
	self.size = 0
	self.mute_ay = 0
	self.slider = VolumeSlider:new({anchor_id = 'volume', render_order = self.render_order})
	self:update_dimensions()
end

function Volume:destroy()
	self.slider:destroy()
	Element.destroy(self)
end

function Volume:get_visibility()
	if state.is_image then return 0 end
	return self.slider.pressed and 1 or Elements:maybe('timeline', 'get_is_hovered') and -1
		or Element.get_visibility(self)
end

function Volume:update_dimensions()
	self.size = round(options.volume_size * state.scale)
	local min_y = Elements:v('top_bar', 'by') or Elements:v('window_border', 'size', 0)
	local max_y = Elements:v('controls', 'ay') or Elements:v('timeline', 'ay')
		or display.height - Elements:v('window_border', 'size', 0)
	local available_height = max_y - min_y
	local max_height = available_height * 0.8
	local height = round(math.min(self.size * 8, max_height))
	self.enabled = height > self.size * 2 -- don't render if too small
	local margin = (self.size / 2) + Elements:v('window_border', 'size', 0)
	self.ax = round(options.volume == 'left' and margin or display.width - margin - self.size)
	self.ay = min_y + round((available_height - height) / 2)
	self.bx = round(self.ax + self.size)
	self.by = round(self.ay + height)
	self.mute_ay = self.by - self.size
	self.slider.enabled = self.enabled
	self.slider:set_coordinates(self.ax, self.ay, self.bx, self.mute_ay)
end

function Volume:on_display() self:update_dimensions() end
function Volume:on_prop_border() self:update_dimensions() end
function Volume:on_prop_title_bar() self:update_dimensions() end
function Volume:on_controls_reflow() self:update_dimensions() end
function Volume:on_options() self:update_dimensions() end

function Volume:render()
    local visibility = self:get_visibility()
    if visibility <= 0 then return end

    cursor:zone('secondary_click', self, function()
        mp.set_property_native('mute', false)
        mp.set_property_native('volume', 100)
    end)

    local mute_rect = { ax = self.ax, ay = self.mute_ay, bx = self.bx, by = self.by }
    cursor:zone('primary_down', mute_rect, function() mp.commandv('cycle', 'mute') end)

    local glass = require('lib/liquid/glass')
    local icons = require('lib/liquid/icons')
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

    local mw = mute_rect.bx - mute_rect.ax
    local mh = mute_rect.by - mute_rect.ay
    local is_hover = get_point_to_rectangle_proximity(cursor, mute_rect) == 0
    draw_glass({
        x = mute_rect.ax, y = mute_rect.ay, w = mw, h = mh, r = math.min(mw, mh) / 2,
        intensity = lg.intensity * (is_hover and 1.15 or 1.0),
        show_frost = lg.show_frost,
    })

    local icon_name = 'volume_up'
    if state.mute then icon_name = 'volume_off'
    elseif (state.volume or 0) <= 0 then icon_name = 'volume_mute'
    elseif (state.volume or 0) <= 60 then icon_name = 'volume_down'
    end

    local icon_path = icons.get(icon_name)
    if icon_path then
        local scale = (math.min(mw, mh) * 0.55) / 24
        local ink = theme.current.ink
        local ink_bgr = ink:sub(5, 6) .. ink:sub(3, 4) .. ink:sub(1, 2)
        ass:new_event()
        ass:append(string.format(
            '{\\an7\\pos(%d,%d)\\bord0\\shad0\\1c&H%s&\\1a&H10&\\fscx%d\\fscy%d\\p1}%s{\\p0}',
            mute_rect.ax + (mw - 24 * scale) / 2,
            mute_rect.ay + (mh - 24 * scale) / 2,
            ink_bgr,
            scale * 100, scale * 100,
            icon_path
        ))
    end

    return ass
end

return Volume
