-- Exercises the SkipPill element against a stubbed uosc runtime so its
-- decision logic (resolve) and draw path (render) are covered without mpv.

local function load_pill(env)
	-- Reset module cache so each test gets a clean element + fresh globals.
	package.loaded['elements/SkipPill'] = nil
	package.loaded['elements/Element'] = nil

	-- Minimal uosc class system.
	_G.class = function(base)
		local c = {}
		if base then setmetatable(c, {__index = base}) end
		return c
	end
	_G.Class = {
		new = function(cls)
			local o = setmetatable({}, {__index = cls})
			if o.init then o:init() end
			return o
		end,
	}
	-- Fake Element base.
	package.loaded['elements/Element'] = {
		init = function(self, id, props)
			self.id = id
			if props then for k, v in pairs(props) do self[k] = v end end
		end,
		is_alive = function() return true end,
	}

	-- Globals the element reads.
	env.state.scale = env.state.scale or 1
	_G.state = env.state
	_G.mp = env.mp or {get_property = function() return nil end, commandv = function() end}
	_G.round = function(x) return math.floor(x + 0.5) end
	_G.clamp = function(lo, v, hi) return math.max(lo, math.min(v, hi)) end
	_G.text_width = function() return 80 end
	_G.config = {font = 'Geist'}
	_G.options = {font_bold = false, text_border = 1}
	_G.display = {width = 1920, height = 1080}
	_G.bg = '000000'
	_G.fg = 'FFFFFF'
	_G.liquid_glass = {next_video_threshold = env.threshold or 120}

	_G.Elements = {
		curtain = {opacity = env.curtain or 0},
		timeline = {ax = 0, ay = 1000, bx = 1920, by = 1060, enabled = true},
		maybe = function(_, _, method)
			if method == 'get_visibility' then return env.controls_visibility or 0 end
			return nil
		end,
		v = function(_, _, _, default) return default end,
	}
	_G.cursor = {zone = function() end}

	-- Fake ASS object: records nothing, just must not error.
	_G.assdraw = {
		ass_new = function()
			local a = {}
			function a:new_event() end
			function a:append() end
			function a:rect() end
			function a:txt() end
			function a:icon() end
			return a
		end,
	}

	return require('elements/SkipPill'):new()
end

local function chs()
	return {
		{time = 0, title = 'Intro'},
		{time = 30, title = 'Body'},
		{time = 90, title = 'Outro'},
	}
end

describe('SkipPill:resolve', function()
	it('returns nil with no chapters and no playlist', function()
		local pill = load_pill({state = {duration = 100, time = 10, chapters = {}}})
		assert.is_nil((pill:resolve()))
	end)

	it('offers a chapter jump when a later chapter exists', function()
		local pill = load_pill({state = {duration = 120, time = 10, chapters = chs()}})
		local mode, label = pill:resolve()
		assert.are.equal('chapter', mode)
		assert.are.equal('Jump: Body', label)
	end)

	it('offers a jump to the first chapter before it starts', function()
		local pill = load_pill({state = {
			duration = 120, time = 5,
			chapters = {{time = 20, title = 'Start'}, {time = 60, title = 'End'}},
		}})
		local mode, label = pill:resolve()
		assert.are.equal('chapter', mode)
		assert.are.equal('Jump: Start', label)
	end)

	it('hides the jump on the last chapter', function()
		local pill = load_pill({state = {duration = 120, time = 100, chapters = chs()}})
		assert.is_nil((pill:resolve()))
	end)

	it('shows the next-video pill near the end with a queued playlist item', function()
		local pill = load_pill({
			state = {
				duration = 600, time = 540, chapters = {},
				has_playlist = true, playlist_pos = 1, playlist_count = 3,
			},
			mp = {get_property = function(name)
				if name == 'playlist/1/title' then return 'The Next One' end
			end, commandv = function() end},
		})
		local mode, label = pill:resolve()
		assert.are.equal('video', mode)
		assert.are.equal('Next: The Next One', label)
	end)

	it('prefers the next-video pill over a chapter jump near the end', function()
		local pill = load_pill({
			state = {
				duration = 600, time = 540, chapters = chs(),
				has_playlist = true, playlist_pos = 1, playlist_count = 3,
			},
			mp = {get_property = function() return 'Queued' end, commandv = function() end},
		})
		assert.are.equal('video', (pill:resolve()))
	end)

	it('hides the next-video pill on the last playlist item', function()
		local pill = load_pill({state = {
			duration = 600, time = 540, chapters = {},
			has_playlist = true, playlist_pos = 3, playlist_count = 3,
		}})
		assert.is_nil((pill:resolve()))
	end)

	it('falls back to a filename when the next item has no title', function()
		local pill = load_pill({
			state = {
				duration = 600, time = 590, chapters = {},
				has_playlist = true, playlist_pos = 1, playlist_count = 2,
			},
			mp = {get_property = function(name)
				if name == 'playlist/1/filename' then return 'C:/clips/holiday.mkv' end
			end, commandv = function() end},
		})
		local _, label = pill:resolve()
		assert.are.equal('Next: holiday.mkv', label)
	end)
end)

describe('SkipPill:render', function()
	it('returns nothing when hidden', function()
		local pill = load_pill({state = {duration = 100, time = 10, chapters = {}}})
		assert.is_nil((pill:render()))
	end)

	it('draws and registers a click zone for a chapter jump when controls are visible', function()
		local zoned = false
		local pill = load_pill({state = {duration = 120, time = 10, chapters = chs()}, controls_visibility = 1})
		_G.cursor.zone = function() zoned = true end
		local ass = pill:render()
		assert.is_table(ass)
		assert.is_true(zoned)
		assert.are_not.equal(0, pill.bx) -- coordinates set for the hitbox
	end)

	it('stays hidden for a chapter jump when controls are not visible', function()
		local pill = load_pill({state = {duration = 120, time = 10, chapters = chs()}, controls_visibility = 0})
		assert.is_nil((pill:render()))
	end)

	it('draws the next-video pill when controls are visible', function()
		local pill = load_pill({
			state = {
				duration = 600, time = 540, chapters = {},
				has_playlist = true, playlist_pos = 1, playlist_count = 2,
			},
			controls_visibility = 1,
			mp = {get_property = function() return 'Up Next' end, commandv = function() end},
		})
		assert.is_table((pill:render()))
	end)

	it('hides the next-video pill when controls are hidden', function()
		local pill = load_pill({
			state = {
				duration = 600, time = 540, chapters = {},
				has_playlist = true, playlist_pos = 1, playlist_count = 2,
			},
			controls_visibility = 0,
			mp = {get_property = function() return 'Up Next' end, commandv = function() end},
		})
		assert.is_nil((pill:render()))
	end)

	it('hides behind an open menu (curtain)', function()
		local pill = load_pill({
			state = {
				duration = 600, time = 540, chapters = {},
				has_playlist = true, playlist_pos = 1, playlist_count = 2,
			},
			curtain = 1,
			mp = {get_property = function() return 'Up Next' end, commandv = function() end},
		})
		assert.is_nil((pill:render()))
	end)
end)
