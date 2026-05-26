local helpers = require('tests.helpers')

describe('theme', function()
  before_each(function() helpers.stub_mp() end)
  after_each(function() helpers.clear_mp() end)

  it('exposes dark and light token tables', function()
    local theme = require('lib/liquid/theme')
    assert.is_table(theme.dark)
    assert.is_table(theme.light)
  end)

  it('defaults current to dark', function()
    package.loaded['lib/liquid/theme'] = nil
    local theme = require('lib/liquid/theme')
    assert.are.equal(theme.dark, theme.current)
  end)

  it('switches current via set()', function()
    package.loaded['lib/liquid/theme'] = nil
    local theme = require('lib/liquid/theme')
    theme.set('light')
    assert.are.equal(theme.light, theme.current)
    theme.set('dark')
    assert.are.equal(theme.dark, theme.current)
  end)

  it('ignores invalid theme names', function()
    package.loaded['lib/liquid/theme'] = nil
    local theme = require('lib/liquid/theme')
    theme.set('purple')
    assert.are.equal(theme.dark, theme.current)
  end)

  it('applies intensity multiplier to alpha tokens', function()
    package.loaded['lib/liquid/theme'] = nil
    local theme = require('lib/liquid/theme')
    local base = theme.dark.body_alpha
    assert.are.equal(base * 0.5, theme.alpha('body_alpha', 0.5))
    assert.are.equal(base * 1.5, theme.alpha('body_alpha', 1.5))
  end)

  it('clamps intensity to [0.5, 1.5]', function()
    package.loaded['lib/liquid/theme'] = nil
    local theme = require('lib/liquid/theme')
    local base = theme.dark.body_alpha
    assert.are.equal(base * 0.5, theme.alpha('body_alpha', 0.1))
    assert.are.equal(base * 1.5, theme.alpha('body_alpha', 5.0))
  end)
end)
