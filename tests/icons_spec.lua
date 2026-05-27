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

  it('has the four control-bar icons', function()
    for _, name in ipairs({ 'play', 'pause', 'prev', 'next' }) do
      assert.is_string(icons.get(name), 'missing icon: '..name)
    end
  end)

  it('returns icons centered on a 24x24 grid', function()
    -- Sanity: parse the path and check it stays within [-2, 26] on both axes.
    local path = icons.get('play')
    for num in path:gmatch('-?%d+%.?%d*') do
      local n = tonumber(num)
      assert.is_true(n >= -2 and n <= 26, 'coord out of range: '..n)
    end
  end)
end)
