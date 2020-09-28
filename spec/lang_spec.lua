local lang = require 'ldk.lang'

describe('#mixin', function()
  it("should report bad arguments", function()
    assert.error(function() lang.mixin(1) end, "bad argument #1 to 'mixin' (string expected, got number)")
    assert.error(function() lang.mixin({}) end, "bad argument #1 to 'mixin' (string expected, got table)")
  end)
  it("should create a new mixin", function()
    local m = lang.mixin("m")
    function m:included(class) end
    assert.is_true(lang.is_mixin(m))
    assert.is_true(tostring(m):find('mixin', 1, true) == 1)
    assert.is_true(type(m.prototype) == 'table')
    assert.is_true(lang.responds_to(m, 'included'))
  end)
end)
describe("#class", function()
  it("should report bad arguments", function()
    assert.error(function() lang.class(1) end, "bad argument #1 to 'class' (string expected, got number)")
    assert.error(function() lang.class('class', 'super') end, "bad argument #2 to 'class' (nil, class or mixin expected, got string)")
  end)
  it("should create a new class", function()
    local c = lang.class("C")
    function c:subclassed(class) end
    assert.is_true(lang.is_class(c))
    assert.is_true(tostring(c):find('class', 1, true) == 1)
    assert.is_true(type(c.prototype) == 'table')
    assert.is_true(lang.responds_to(c, 'subclassed'))
  end)
  it("should create a new class with the given parent", function()
    local parent = lang.class("C")
    local subclassed_called
    function parent.subclassed(class)
      subclassed_called = class
    end
    local c = lang.class("C", parent)
    assert.is_true(lang.is_class(c))
    assert.is_false(lang.responds_to(c, 'subclassed'))
    assert.equal(c, subclassed_called)
    assert.equal(lang.super(c), parent)
    assert.is_true(lang.is_subclass_of(c, parent))
  end)
  it("should create a new class with the given mixins", function()
    local m = lang.mixin("M")
    local included_in
    function m.included(class)
      included_in = class
    end
    function m.prototype:fn() end
    local c = lang.class("C", m)
    assert.is_true(lang.is_class(c))
    assert.is_false(lang.responds_to(c, 'included'))
    assert.is_true(lang.responds_to(c.prototype, 'fn'))
    assert.equal(c, included_in)
  end)
  it("should include a mixin only once", function()
    local m1, m2 = lang.mixin("M1"), lang.mixin("M2")
    local i1 = 0
    function m1.included(class)
      i1 = i1 + 1
    end
    local i2 = 0
    function m2.included(class)
      i2 = i2 + 1
    end
    local c = lang.class("C", m1, m2, m1, m2)
    assert.is_true(lang.is_class(c))
    assert.equal(1, i1)
    assert.equal(1, i2)
  end)
  it("should overwrite functions defined in multiple mixins", function()
    local m1, m2 = lang.mixin("M1"), lang.mixin("M2")
    function m1.prototype:fn() end
    function m2.prototype:fn() end
    local c = lang.class("C", m1, m2)
    assert.not_equal(m1.prototype.fn, m2.prototype.fn)
    assert.equal(c.prototype.fn, m2.prototype.fn)
  end)
  it("should raise with invalid overwrites", function()
    local m1, m2 = lang.mixin("M1"), lang.mixin("M2")
    function m1.prototype:fn() end
    m2.prototype.fn = 10
    assert.error(function() lang.class("C", m1, m2) end)
  end)
  it("should correctly instantiate a class", function()
    local c = lang.class("C")
    local foo_called
    function c.prototype:foo()
      foo_called = true
    end

    local o = c()
    assert.is_true(lang.is_object(o))
    assert.equal(c, lang.class_of(o))
    assert.is_true(lang.responds_to(o, 'foo'))
    o:foo()
    assert.is_true(foo_called)
  end)
end)
