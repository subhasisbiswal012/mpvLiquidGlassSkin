local helpers = require('tests.helpers')

describe('glass primitive', function()
  local glass

  before_each(function()
    helpers.stub_mp()
    package.loaded['lib/liquid/glass'] = nil
    package.loaded['lib/liquid/theme'] = nil
    glass = require('lib/liquid/glass')
  end)
  after_each(function() helpers.clear_mp() end)

  it('returns a non-empty ASS string', function()
    local out = glass.draw({ x = 0, y = 0, w = 60, h = 60, r = 30 })
    assert.is_string(out)
    assert.is_true(#out > 100, 'expected non-trivial output, got '..#out..' chars')
  end)

  it('emits four drawing-mode layers (\\p1 tag appears 4 times)', function()
    local out = glass.draw({ x = 0, y = 0, w = 60, h = 60, r = 30 })
    local count = 0
    for _ in out:gmatch('\\p1') do count = count + 1 end
    assert.are.equal(4, count, 'expected 4 visible layers (shadow, body, highlight, border); got '..count)
  end)

  it('does not emit Lua-style comments that would render as text', function()
    local out = glass.draw({ x = 0, y = 0, w = 60, h = 60, r = 30 })
    -- "--" inside an ASS dialogue line would render as two visible minuses.
    assert.is_falsy(out:find('--', 1, true), 'output contains "--" sequence; would render as literal text')
  end)

  it('respects theme switching by emitting different output', function()
    local theme = require('lib/liquid/theme')
    theme.set('dark')
    local dark_out = glass.draw({ x = 0, y = 0, w = 60, h = 60, r = 30 })
    theme.set('light')
    local light_out = glass.draw({ x = 0, y = 0, w = 60, h = 60, r = 30 })
    assert.are_not.equal(dark_out, light_out)
  end)

  it('respects intensity by scaling alpha values', function()
    local low  = glass.draw({ x = 0, y = 0, w = 60, h = 60, r = 30, intensity = 0.5 })
    local high = glass.draw({ x = 0, y = 0, w = 60, h = 60, r = 30, intensity = 1.5 })
    assert.are_not.equal(low, high)
  end)

  it('emits geometry matching the rect', function()
    local out = glass.draw({ x = 100, y = 200, w = 60, h = 60, r = 30 })
    assert.is_truthy(out:find('100', 1, true))
    assert.is_truthy(out:find('200', 1, true))
  end)

  it('accepts show_frost = false without error', function()
    local ok, _ = pcall(function()
      return glass.draw({ x = 0, y = 0, w = 60, h = 60, r = 30, show_frost = false })
    end)
    assert.is_true(ok)
  end)
end)
