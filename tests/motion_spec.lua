describe('motion easings', function()
  local motion

  before_each(function()
    package.loaded['lib/liquid/motion'] = nil
    motion = require('lib/liquid/motion')
  end)

  describe('spring_out', function()
    it('returns 0 at t=0', function()
      assert.is_true(math.abs(motion.spring_out(0)) < 1e-6)
    end)

    it('returns 1 at t=1', function()
      assert.is_true(math.abs(motion.spring_out(1) - 1) < 1e-6)
    end)

    it('overshoots above 1 somewhere in the middle', function()
      local max_v = 0
      for i = 1, 99 do
        local v = motion.spring_out(i / 100)
        if v > max_v then max_v = v end
      end
      assert.is_true(max_v > 1.04, 'expected overshoot > 4%, got '..max_v)
      assert.is_true(max_v < 1.15, 'expected overshoot < 15%, got '..max_v)
    end)
  end)

  describe('spring_settle', function()
    it('returns 0 at t=0 and 1 at t=1', function()
      assert.is_true(math.abs(motion.spring_settle(0)) < 1e-6)
      assert.is_true(math.abs(motion.spring_settle(1) - 1) < 1e-6)
    end)

    it('never overshoots', function()
      for i = 0, 100 do
        local v = motion.spring_settle(i / 100)
        assert.is_true(v <= 1 + 1e-6, 'overshoot at t='..(i/100)..' value='..v)
      end
    end)
  end)

  describe('liquid_fade', function()
    it('returns 0 alpha at t=0', function()
      local a, s = motion.liquid_fade(0)
      assert.is_true(math.abs(a) < 1e-6)
      assert.is_true(math.abs(s - 0.96) < 1e-6)
    end)

    it('returns 1 alpha and 1 scale at t=1', function()
      local a, s = motion.liquid_fade(1)
      assert.is_true(math.abs(a - 1) < 1e-6)
      assert.is_true(math.abs(s - 1) < 1e-6)
    end)
  end)

  describe('reduced motion', function()
    it('all easings return target instantly when motion.reduced is true', function()
      motion.reduced = true
      assert.are.equal(1, motion.spring_out(0.001))
      assert.are.equal(1, motion.spring_settle(0.001))
      local a, s = motion.liquid_fade(0.001)
      assert.are.equal(1, a)
      assert.are.equal(1, s)
      motion.reduced = false
    end)
  end)

  describe('apply_reduced(value)', function()
    it('accepts truthy values', function()
      package.loaded['lib/liquid/motion'] = nil
      local motion = require('lib/liquid/motion')
      motion.apply_reduced('yes')
      assert.is_true(motion.reduced)
      motion.apply_reduced(true)
      assert.is_true(motion.reduced)
      motion.apply_reduced(1)
      assert.is_true(motion.reduced)
    end)

    it('accepts falsy values', function()
      package.loaded['lib/liquid/motion'] = nil
      local motion = require('lib/liquid/motion')
      motion.reduced = true
      motion.apply_reduced('no')
      assert.is_false(motion.reduced)
      motion.apply_reduced(false)
      assert.is_false(motion.reduced)
      motion.apply_reduced(nil)
      assert.is_false(motion.reduced)
    end)
  end)
end)
