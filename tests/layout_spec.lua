local helpers = require('helpers')

local function load_layout(props)
  helpers.stub_mp({properties = props or {}})
  package.loaded['lib/liquid/layout'] = nil
  package.path = 'portable_config/scripts/uosc/?.lua;' .. package.path
  return require('lib/liquid/layout')
end

describe('lib/liquid/layout', function()
  it('returns landscape for 16:9 video', function()
    local layout = load_layout({['video-params/w'] = 1920, ['video-params/h'] = 1080})
    assert.are.equal('landscape', layout.video_orientation())
  end)

  it('returns portrait for a vertical reels-style video', function()
    local layout = load_layout({['video-params/w'] = 1080, ['video-params/h'] = 1920})
    assert.are.equal('portrait', layout.video_orientation())
  end)

  it('returns landscape for a perfect square', function()
    -- Square stays in landscape so the full toolbar shows.
    local layout = load_layout({['video-params/w'] = 800, ['video-params/h'] = 800})
    assert.are.equal('landscape', layout.video_orientation())
  end)

  it('returns nil when video params are unknown', function()
    local layout = load_layout({})
    assert.is_nil(layout.video_orientation())
  end)

  it('flags overlap when the window is too small for landscape', function()
    local layout = load_layout()
    assert.is_true(layout.would_overlap('landscape', 960, 300))
    assert.is_false(layout.would_overlap('landscape', 1280, 720))
  end)

  it('flags overlap when the window is too small for portrait', function()
    local layout = load_layout()
    assert.is_true(layout.would_overlap('portrait', 380, 300))
    assert.is_false(layout.would_overlap('portrait', 600, 700))
  end)

  it('clamps tiny landscape dimensions up to the floor', function()
    local layout = load_layout()
    local w, h, changed = layout.clamp('landscape', 200, 100)
    assert.is_true(changed)
    assert.are.equal(layout.LANDSCAPE_MIN_WIDTH, w)
    assert.are.equal(layout.LANDSCAPE_MIN_HEIGHT, h)
  end)

  it('leaves comfortable windows alone', function()
    local layout = load_layout()
    local w, h, changed = layout.clamp('portrait', 700, 1000)
    assert.is_false(changed)
    assert.are.equal(700, w)
    assert.are.equal(1000, h)
  end)
end)
