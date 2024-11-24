if _VERSION < 'Lua 5.4' then error('LunarKit requires Lua 5.4 or later.') end

--#region LunarKit Object

---
--- `lk_obj*` is a class that represents an object with event handling capabilities.
---
---@class lk_obj*
---@field private __events table<string, table<number, function>>
---@field private __max_listeners number
local LK_Object = {}
LK_Object.__index = LK_Object

---Adds the `listener` function to the end of the listeners array for the event named `event_name`.
---No checks are made to see if the `listener` has already been added.
---Multiple calls passing the same combination of `event_name` and `listener` will result in the `listener` being added, and called, multiple times.
---
---@param self lk_obj* The object instance.
---@param event_name string The name of the event.
---@param listener function The callback function.
LK_Object.on = function(self, event_name, listener)
  if not self.__events[event_name] then self.__events[event_name] = {} end

  if #self.__events[event_name] >= self.__max_listeners then
    error('lk_obj_on: max listeners reached for event: ' .. event_name)
  end

  table.insert(self.__events[event_name], listener)

  self:emit('new_listener', event_name, listener)

  return self
end

---Adds a one-time `listener` function for the event named `event_name`.
---The next time `event_name` is triggered, this `listener` is removed and then invoked.
---
---@param self lk_obj* The object instance.
---@param event_name string The name of the event.
---@param listener function The callback function.
LK_Object.once = function(self, event_name, listener)
  local wrapper
  wrapper = function(...)
    listener(...)

    self:off(event_name, wrapper)
  end

  self:on(event_name, wrapper)
end

---Removes the specified `listener` from the listener array for the event named `event_name`.
---
---@param self lk_obj* The object instance.
---@param event_name string The name of the event.
---@param listener function The callback function.
LK_Object.off = function(self, event_name, listener)
  local listeners = self.__events[event_name]

  if not listeners then return end

  for i = #listeners, 1, -1 do
    if listeners[i] == listener then
      table.remove(listeners, i)

      self:emit('remove_listener', event_name, listener)

      break
    end
  end

  if #listeners == 0 then self.__events[event_name] = nil end
end

---Synchronously calls each of the listeners registered for the event named `event_name`, in the order they were registered, passing the supplied arguments to each.
---
---@param self lk_obj* The object instance.
---@param event_name string The name of the event.
---@param ... any The arguments to pass to the listeners.
---@return boolean result Returns `true` if the event had listeners, `false` otherwise.
LK_Object.emit = function(self, event_name, ...)
  local listeners = self.__events[event_name]

  if not listeners then return false end

  for _, listener in ipairs(listeners) do
    listener(...)
  end

  return true
end

---Returns an array listing the events for which the emitter has registered listeners.
---
---@param self lk_obj* The object instance.
---@return string[] event_names The array of event names.
LK_Object.event_names = function(self)
  local event_names = {}

  for event_name, _ in pairs(self.__events) do
    table.insert(event_names, event_name)
  end

  return event_names
end

---Returns the current max listener value for the object which is either set by `set_max_listeners` or the default value of 10.
---
---@param self lk_obj* The object instance.
---@return number max_listeners The max listener value.
LK_Object.get_max_listeners = function(self)
  return self.__max_listeners
end

---Sets the max listener value for the object.
---
---@param self lk_obj* The object instance.
---@param max_listeners number The max listener value.
LK_Object.set_max_listeners = function(self, max_listeners)
  self.__max_listeners = max_listeners
end

---Returns the number of listeners for the event named `event_name`.
---
---@param self lk_obj* The object instance.
---@param event_name string The name of the event.
---@return integer count The number of listeners.
LK_Object.listener_count = function(self, event_name)
  local listeners = self.__events[event_name]

  return listeners and #listeners or 0
end

---Returns a copy of the array of listeners for the event named `event_name`.
---
---@param self lk_obj* The object instance.
---@param event_name string The name of the event.
---@return function[] listeners The array of listeners.
LK_Object.listeners = function(self, event_name)
  return self.__events[event_name] or {}
end

---Creates a new `lk_obj*` object.
---
---@return lk_obj* object The new object instance.
lk_obj_create = function()
  local self = setmetatable({
    __events = {
      new_listener = {},
      remove_listener = {},
    },
    __max_listeners = 10,
  }, LK_Object)

  return self
end

--#endregion
