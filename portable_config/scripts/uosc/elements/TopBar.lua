local Element = require('elements/Element')

---@alias TopBarButtonProps {icon: string; hover_fg?: string; hover_bg?: string; command: (fun():string)}

---@class TopBar : Element
local TopBar = class(Element)

function TopBar:new() return Class.new(self) --[[@as TopBar]] end
function TopBar:init()
	Element.init(self, 'top_bar', {render_order = 4})
	self.size = 0
	self.icon_size, self.font_size, self.title_by = 1, 1, 1
	self.show_alt_title = false
	self.main_title, self.alt_title = nil, nil

	local function maximized_command()
		if state.platform == 'windows' then
			mp.command(state.border
				and (state.fullscreen and 'set fullscreen no;cycle window-maximized' or 'cycle window-maximized')
				or 'set window-maximized no;cycle fullscreen')
		else
			mp.command(state.fullormaxed and 'set fullscreen no;set window-maximized no' or 'set window-maximized yes')
		end
	end

	local close = {icon = 'close', hover_bg = '2311e8', hover_fg = 'ffffff', command = function() mp.command('quit') end}
	local max = {icon = 'crop_square', command = maximized_command}
	local min = {icon = 'minimize', command = function() mp.command('cycle window-minimized') end}
	self.buttons = options.top_bar_controls == 'left' and {close, max, min} or {min, max, close}

	self:decide_titles()
	self:decide_enabled()
	self:update_dimensions()
end

function TopBar:decide_enabled()
	if options.top_bar == 'no-border' then
		self.enabled = not state.border or state.title_bar == false or state.fullscreen
	else
		self.enabled = options.top_bar == 'always'
	end
	self.enabled = self.enabled and (options.top_bar_controls or options.top_bar_title ~= 'no' or state.has_playlist)
end

function TopBar:decide_titles()
	self.alt_title = state.alt_title ~= '' and state.alt_title or nil
	self.main_title = state.title ~= '' and state.title or nil

	if (self.main_title == 'No file') then
		self.main_title = t('No file')
	end

	-- Fall back to alt title if main is empty
	if not self.main_title then
		self.main_title, self.alt_title = self.alt_title, nil
	end

	-- Deduplicate the main and alt titles by checking if one completely
	-- contains the other, and using only the longer one.
	if self.main_title and self.alt_title and not self.show_alt_title then
		local longer_title, shorter_title
		if #self.main_title < #self.alt_title then
			longer_title, shorter_title = self.alt_title, self.main_title
		else
			longer_title, shorter_title = self.main_title, self.alt_title
		end

		local escaped_shorter_title = regexp_escape(shorter_title --[[@as string]])
		if string.match(longer_title --[[@as string]], escaped_shorter_title) then
			self.main_title, self.alt_title = longer_title, nil
		end
	end
end

function TopBar:update_dimensions()
	self.size = round(options.top_bar_size * state.scale)
	self.icon_size = round(self.size * 0.5)
	self.font_size = math.floor((self.size - (math.ceil(self.size * 0.25) * 2)) * options.font_scale)
	local window_border_size = Elements:v('window_border', 'size', 0)
	self.ax = window_border_size
	self.ay = window_border_size
	self.bx = display.width - window_border_size
	self.by = self.size + window_border_size
end

function TopBar:toggle_title()
	if options.top_bar_alt_title_place ~= 'toggle' then return end
	self.show_alt_title = not self.show_alt_title
	request_render()
end

function TopBar:on_prop_title() self:decide_titles() end
function TopBar:on_prop_alt_title() self:decide_titles() end

function TopBar:on_prop_border()
	self:decide_enabled()
	self:update_dimensions()
end

function TopBar:on_prop_title_bar()
	self:decide_enabled()
	self:update_dimensions()
end

function TopBar:on_prop_fullscreen()
	self:decide_enabled()
	self:update_dimensions()
end

function TopBar:on_prop_maximized()
	self:decide_enabled()
	self:update_dimensions()
end

function TopBar:on_prop_has_playlist()
	self:decide_enabled()
	self:update_dimensions()
end

function TopBar:on_display() self:update_dimensions() end

function TopBar:on_options()
	self:decide_enabled()
	self:update_dimensions()
end

function TopBar:render()
	local visibility = self:get_visibility()
	if visibility <= 0 then return end
	local ass = assdraw.ass_new()

	local glass = require('lib/liquid/glass')
	local icons = require('lib/liquid/icons')
	local theme = require('lib/liquid/theme')
	local lg = _G.liquid_glass or { intensity = 1.0, show_frost = true }

	local function draw_glass(geom)
		for layer_text in glass.draw(geom):gmatch('[^\n]+') do
			if layer_text:sub(1, 2) ~= '--' and layer_text ~= '' then
				ass:new_event()
				ass:append(layer_text)
			end
		end
	end

	local function ink_bgr()
		local ink = theme.current.ink
		return ink:sub(5, 6) .. ink:sub(3, 4) .. ink:sub(1, 2)
	end

	local ax, bx = self.ax, self.bx
	local ay, by = self.ay, self.by
	local size = self.size
	local margin = math.floor(size * 0.18)
	local pebble_h = size - margin * 2
	local pebble_r = pebble_h / 2

	-- Window controls: one small glass pebble per button.
	if options.top_bar_controls then
		local is_left = options.top_bar_controls == 'left'
		local btn_ax
		if is_left then
			btn_ax = ax + margin
			ax = ax + size * #self.buttons
		else
			btn_ax = bx - size * #self.buttons + margin
			bx = bx - size * #self.buttons
		end

		for _, button in ipairs(self.buttons) do
			local rect = { ax = btn_ax - margin, ay = ay, bx = btn_ax + pebble_h + margin, by = by }
			cursor:zone('primary_down', rect, button.command)

			local is_hover = get_point_to_rectangle_proximity(cursor, rect) == 0

			draw_glass({
				x = btn_ax, y = ay + margin, w = pebble_h, h = pebble_h, r = pebble_r,
				intensity = lg.intensity * (is_hover and 1.15 or 1.0),
				show_frost = lg.show_frost,
			})

			local icon_path = icons.get(button.icon)
			if icon_path then
				local scale = (pebble_h * 0.55) / 24
				ass:new_event()
				ass:append(string.format(
					'{\\an7\\pos(%d,%d)\\bord0\\shad0\\1c&H%s&\\1a&H0F&\\fscx%d\\fscy%d\\p1}%s{\\p0}',
					btn_ax + (pebble_h - 24 * scale) / 2,
					ay + margin + (pebble_h - 24 * scale) / 2,
					ink_bgr(),
					scale * 100, scale * 100,
					icon_path
				))
			end

			btn_ax = btn_ax + size
		end
	end

	-- Title strip: one wide glass pebble.
	if options.top_bar_title ~= 'no' and (self.main_title or state.has_playlist) then
		local strip_ax = ax + margin
		local strip_bx = bx - margin
		if strip_bx - strip_ax > pebble_h then
			local title_rect = { ax = strip_ax, ay = ay + margin, bx = strip_bx, by = by - margin }

			draw_glass({
				x = title_rect.ax, y = title_rect.ay,
				w = title_rect.bx - title_rect.ax, h = title_rect.by - title_rect.ay,
				r = pebble_r,
				intensity = lg.intensity,
				show_frost = lg.show_frost,
			})

			local title = self.show_alt_title and self.alt_title or self.main_title
			if title and self.font_size and self.font_size > 6 then
				ass:new_event()
				ass:append(string.format(
					'{\\an4\\pos(%d,%d)\\bord0\\shad0\\fn%s\\fs%d\\1c&H%s&\\1a&H10&\\clip(%d,%d,%d,%d)}%s',
					title_rect.ax + pebble_h * 0.5,
					(title_rect.ay + title_rect.by) / 2,
					'Geist', self.font_size,
					ink_bgr(),
					title_rect.ax, title_rect.ay, title_rect.bx, title_rect.by,
					title
				))
			end

			if options.top_bar_alt_title_place == 'toggle' then
				cursor:zone('primary_down', title_rect, function() self:toggle_title() end)
			end
		end
	end

	self.title_by = self.ay + (self.main_title and size or 0)

	return ass
end

return TopBar
