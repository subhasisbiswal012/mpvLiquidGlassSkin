describe('icons', function()
  local icons

  before_each(function()
    package.loaded['lib/liquid/icons'] = nil
    icons = require('lib/liquid/icons')
  end)

  it('exposes get(name) returning ASS path string', function()
    local path = icons.get('play')
    assert.is_string(path)
    assert.is_true(#path > 10, 'expected non-trivial path data')
  end)

  it('returns nil for unknown icons (caller decides fallback)', function()
    assert.is_nil(icons.get('this-icon-does-not-exist'))
  end)

  local REQUIRED = {
    'play', 'pause', 'prev', 'next',
    'forward_10', 'rewind_10',
    'volume_up', 'volume_down', 'volume_mute', 'volume_off',
    'fullscreen_enter', 'fullscreen_exit', 'pip',
    'subtitle', 'audio_track', 'chapter_list', 'playlist',
    'settings', 'close', 'minimize', 'crop_square', 'eject', 'search',
    'expand_menu',
  }

  it('has all 22 spec icons (plus aliases)', function()
    for _, name in ipairs(REQUIRED) do
      local p = icons.get(name)
      assert.is_string(p, 'missing icon: ' .. name)
      assert.is_true(#p > 5, 'icon path too short: ' .. name)
    end
  end)

  it('returns icons centered on a 24x24 grid (coords within [-2,26])', function()
    for _, name in ipairs(REQUIRED) do
      local path = icons.get(name)
      for num in path:gmatch('%-?%d+%.?%d*') do
        local n = tonumber(num)
        if n then
          assert.is_true(n >= -2 and n <= 26,
            ('coord out of range for %s: %s'):format(name, tostring(n)))
        end
      end
    end
  end)

  it('register() adds new icons at runtime', function()
    icons.register('custom_test', 'm 0 0 l 24 24')
    assert.are.equal('m 0 0 l 24 24', icons.get('custom_test'))
  end)
end)
