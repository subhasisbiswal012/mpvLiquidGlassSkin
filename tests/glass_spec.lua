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

  it('returns an ASS string with all six layer markers', function()
    local out = glass.draw({ x = 0, y = 0, w = 60, h = 60, r = 30 })
    assert.is_string(out)
    -- Each layer leaves a recognizable signature in the ASS output.
    for _, marker in ipairs({
      '@shadow',     -- layer 1
      '@body',       -- layer 2
      '@frost',      -- layer 3
      '@highlight',  -- layer 4
      '@rim',        -- layer 5
      '@border',     -- layer 6
    }) do
      assert.is_truthy(out:find(marker, 1, true), 'missing layer marker: '..marker)
    end
  end)

  it('respects theme switching by emitting different colors', function()
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
    -- Check the coords show up in the body's move-to.
    assert.is_truthy(out:find('100', 1, true))
    assert.is_truthy(out:find('200', 1, true))
  end)

  it('honors show_frost = false by omitting frost layer', function()
    local out = glass.draw({ x = 0, y = 0, w = 60, h = 60, r = 30, show_frost = false })
    assert.is_falsy(out:find('@frost', 1, true))
  end)
end)
