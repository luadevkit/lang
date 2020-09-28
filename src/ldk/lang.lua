--- Classes and mixins.
--
-- @module ldk.lang
local M = {}

local hash = require 'ldk.hash'
local checks = require 'ldk.checks'

local type = type
local error = error
local pairs = pairs
local ipairs = ipairs
local rawget = rawget
local getmetatable = getmetatable
local setmetatable = setmetatable

local tbl_pack = table.pack

_ENV = M

local function errorf(level, fmt, ...)
  error(fmt:format(...), level + 1)
end

local mixin_mt = {
  __type = 'mixin',
  __tostring = function(self)
    return ('mixin: 0x%x'):format(hash.hash(self))
  end
}

--- Creates a mixin with a given name.
--
-- Mixins are like classes but cannot be instantiated.
-- @tparam string name the name of the new mixin.
-- @treturn table a new mixin.
function mixin(name)
  checks.check_types('string')

  local mixin = {
    __type = name,
    prototype = {}
  }
  return setmetatable(mixin, mixin_mt)
end

--- Checks if the given value is a mixin.
-- @param v the value to test.
-- @treturn bool `true` if the value is a mixin, otherwise `false`.
function is_mixin(v)
  return type(v) == 'table' and getmetatable(v) == mixin_mt
end

local function find_in_parent(class, k)
  while class do
    local v = rawget(class, k)
    if v ~= nil then
      return v
    end
    class = super(class)
  end
end

local function new_instance(class, ...)
  local allocate = find_in_parent(class, 'allocate')
  local instance = allocate == nil and {} or allocate()
  setmetatable(instance, class)

  local initialize = find_in_parent(class, 'initialize')
  if initialize then
    initialize(instance, ...)
  end

  return instance
end

local function class_tostring(class)
  local name = rawget(class, '__type')
  return name
    and ('class %s: 0x%x'):format(name, hash.hash(class))
    or ('class: 0x%x'):format(hash.hash(class))
end

local function object_tostring(object)
  local class = class_of(object)
  local class_name = name_of(class) or 'object'
  return ('%s: 0x%x'):format(class_name, hash.hash(object))
end

local class_prototype = {}
local class_mt = {
  __type = 'class',
  __call = new_instance,
  __tostring = class_tostring,
  __index = class_prototype
}

--- Creates a new subclass.
-- @within Class Functions
-- @function subclass
-- Creates a class with the given name, parent, and mixins.
-- Mixins are included into the new class in the order they are passed to the function.
-- @tparam string name the name of the new class.
-- @tparam[opt] mixin ... the mixins for the new class.
-- @treturn class the new class.
-- @remark if the class object defines the function `subclssed`, the function will
-- be invoked with the new class as argument.
-- @remark if any mixin object defines the function `included`, the function will
-- be invoked with the new class as argument.
-- @raise if different mixins define values with the same name but different types.
function class_prototype:subclass(name, ...)
  return class(name, self, ...)
end

local function copy_value(value)
  if type(value) == 'table' then
    local r = {}
    for k, v in pairs(value) do
      r[k] = copy_value(v)
    end
    return r
  end
  return value
end

local function nicify_field_name(class_or_mixin, k)
  local r = ("%s.%s"):format(name_of(class_or_mixin), k)
  if type(class_or_mixin.prototype[k]) == 'function' then
    r = r .. "()"
  end
  return r
end

local function include_mixin(mixin, class)
  if type(mixin.prototype) ~= 'table' then
    return false
  end
  if not class.__mixins[mixin] then
    class.__mixins[mixin] = true
    for k, v in pairs(mixin.prototype) do
      if class.prototype[k] == nil or type(v) == type(class.prototype[k]) then
        class.prototype[k] = copy_value(v)
      else
        errorf(3, "'%s' is not a valid override for '%s': expected %s, got %s.",
          nicify_field_name(mixin, k), nicify_field_name(class, k), type(class.prototype[k]), type(v))
      end
    end

    if responds_to(mixin, 'included') then
      mixin.included(class)
    end
  end
  return true
end

--- Creates a new class.
--
-- Creates a class with the given name, parent, and mixins.
-- Mixins are included into the new class in the order they are passed to the function.
-- @tparam string name the name of the new class.
-- @tparam[opt] class super the parent of the new class.
-- @tparam[opt] mixin ... the mixins for the new class.
-- @treturn class the new class.
-- @remark if the parent class object defines the function `subclssed`, the function will
-- be invoked with the new class as argument.
-- @remark if any mixin object defines the function `included`, the function will
-- be invoked with the new class as argument.
-- @raise if different mixins define values with the same name but different types.
function class(name, super, ...)
  checks.check_types('string', '?class|mixin', '*?mixin')

  local prototype = {}
  local class = {
    __type = name,
    __super = super,
    __index = prototype,
    __tostring = object_tostring,
    __mixins = {},
    prototype = prototype
  }

  setmetatable(class, class_mt)

  if is_mixin(super) then
    if not include_mixin(super, class) then
      checks.arg_error(2, "not a valid mixin");
    end
    super = nil
  end

  local mixins = tbl_pack(...)
  for i, mixin in ipairs(mixins) do
    if not include_mixin(mixin, class) then
      checks.arg_error(2 + i, "not a valid mixin");
    end
  end

  setmetatable(prototype, super)

  if super and responds_to(super, 'subclassed') then
    super.subclassed(class)
  end

  return class
end

--- Returns a value indicating whether a given value is a class.
-- @param v the value to test.
-- @treturn bool `true` if the value is a class, otherwise `false`.
function is_class(v)
  return type(v) == 'table' and getmetatable(v) == class_mt
end

--- Returns a value indicating whether a given class  has the specified parent among its ancestors.
-- @tparam class class the class to test.
-- @tparam class parent the class to compare with the ancestors of the given class.
-- @treturn bool `true` if the given class has the specified parent among its ancestors, otherwise `false`.
function is_subclass_of(class, parent)
  checks.check_types('class', 'class')
  while class do
    if class == parent then
      return true
    end
    class = super(class)
  end
  return false
end

--- Returns a value indicating whether a given value is an object.
-- @param v the value to test.
-- @treturn bool `true` if the value is an object, otherwise `false`.
function is_object(v)
  return class_of(v) ~= nil
end

--- Returns a value indicating whether a given value is an instance of the specified class.
-- @param v the value to test.
-- @tparam class class the class to compare with the value's class.
-- @treturn bool `true` if the value is an instance of the specified class, otherwise `false`.
function is_a(v, class)
  checks.check_types('?any', 'class')
  return class_of(v) == class
end

--- Returns the class of a given value.
-- @param v the value to get the class of.
-- @treturn class the class of the given value, or `nil` if the value is not an object.
function class_of(v)
  local mt = getmetatable(v)
  if is_class(mt) then
    return mt
  end
end

--- Returns the parent of a given class.
-- @tparam class class the class to get the parent class of.
-- @treturn class the parent of the given class, otherwise `nil`.
function super(class)
  checks.check_types('class')
  return class_of(class.prototype)
end

--- Returns the name of a given class or mixin.
-- @tparam class|mixin class_or_mixin the type to get the name of.
-- @treturn string the name of the given type, or `nil` if the input argument
-- is `nil`.
-- @raise if the given argument is not a class, a mixin, or `nil`.
function name_of(class_or_mixin)
  checks.check_types('?class|mixin')
  return rawget(class_or_mixin, '__type')
end

--- Returns the type of a given value.
-- @param v the value to get the type of.
-- @treturn string the type of the given value.
function type_of(v)
  local r = type(v)
  if r == 'table' then
    local mt = getmetatable(v)
    if mt then
      return rawget(mt, '__type') or r
    end
  end
  return r
end

--- Returns a value indicating whether a given value responds to the specified method call.
-- @tparam table v the value to test.
-- @tparam string name the name of the method to test for.
-- @treturn boolean `true` if the given value responds to the specified method, otherwise `false`.
function responds_to(v, name)
  return is_object_like(v) and type(v[name]) == 'function'
end

--- Returns a value indicating whether a given value is object-like.
--
-- Object-like values are values supporting methods-like function calls.
-- @param v the value to test.
-- @treturn boolean `true` if the given value is object-like, otherwise `false`.
function is_object_like(v)
  local v_type = type(v)
  return v_type == 'table' or v_type == 'userdata' or v_type == 'string'
end

--- Returns a value indicating whether a given class includes the specified mixin.
-- @tparam class class the class to test.
-- @tparam mixin mixin the mixin to test for.
-- @treturn boolean `true` if the given class contains the specified mixin, otherwise `false`.
function includes(class, mixin)
  checks.check_types('class', 'mixin')
  return class.__mixins[mixin]
end

checks.register('object', is_object)

return M
