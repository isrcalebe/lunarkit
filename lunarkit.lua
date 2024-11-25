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

--#region LunarKit Dump

---The options to use for dumping a `table`.
---
---@class lk_dump_options
---@field public depth? number The maximum depth to traverse. (default: `math.huge`)
---@field public indent_size? number The number of spaces to use for indentation. (default: `2`)
---@field public new_line? string | '\n' The string to use for new lines. (default: `'\n'`)

---Dumps a `table` to a string representation.
---
---This function serializes a `table` into a string, with options to control
---the depth of serialization, indentation, and newline characters.
---
---@param object table The object to dump.
---@param options lk_dump_options? The options to use for dumping.
---@return string result The string representation of the object.
lk_dump = function(object, options)
  options = options or {}

  local depth = options.depth or math.huge
  local indent = string.rep(' ', options.indent_size or 2)
  local new_line = options.new_line or '\n'

  local lk_dump_serialize
  lk_dump_serialize = function(object, current_depth, path)
    if current_depth > depth then return '(...)' end

    local object_type = type(object)

    if object_type == 'string' then
      return string.format('%q', object)
    elseif
      object_type == 'number'
      or object_type == 'boolean'
      or object_type == 'nil'
    then
      return tostring(object)
    elseif object_type == 'function' then
      return tostring(object)
    elseif object_type == 'table' then
      if path[object] then return '(circular reference)' end

      path[object] = true

      local parts = {}
      table.insert(parts, '{')

      for k, v in pairs(object) do
        local key = type(k) == 'string' and string.format('[%q]', k)
          or string.format('[%s]', tostring(k))
        local value = lk_dump_serialize(v, current_depth + 1, path)

        table.insert(
          parts,
          indent:rep(current_depth) .. key .. ' = ' .. value .. ','
        )
      end

      table.insert(parts, indent:rep(current_depth - 1) .. '}')
      path[object] = nil

      return table.concat(parts, new_line)
    else
      return string.format('(unsupported type: %s)', object_type)
    end
  end

  return lk_dump_serialize(object, 1, {})
end

---Dumps a `table` to a string representation and prints it to the console.
---
---@param object table The object to dump.
---@param options lk_dump_options? The options to use for dumping.
lk_dump_print = function(object, options)
  print(lk_dump(object, options))
end

--#endregion

--#region LunarKit ANSI

local LK_ANSI_ENV = {
  enabled = false,
  html_tags = false,
  cache = true,
  __color_tag = '$%b{}',
  __reset_cmd = 'reset font_0',
  __palette = {},
}

local LK_ANSI_SGR = {
  --- Attributes
  reset = 0,
  normal = 0,

  bold = 1,
  bold_off = 22,

  intense = 1,
  intense_off = 22,
  faint = 2,
  faint_off = 22,

  dim = 2,
  dim_off = 22,
  italic = 3,
  italic_off = 23,

  oblique = 3,
  oblique_off = 23,

  underline = 4,
  underline_off = 24,

  blink = 5,
  blink_off = 25,

  slow_blink = 5,
  slow_blink_off = 25,

  rapid_blink = 6,
  rapid_blink_off = 25,

  inverse = 7,
  inverse_off = 27,

  hide = 8,
  hide_off = 28,

  conceal = 8,
  reveal = 28,

  cross_out = 9,
  cross_out_off = 29,

  strikethrough = 9,
  strikethrough_off = 29,

  --- Fonts

  primary_font = 10,

  font_0 = 10,
  font_1 = 11,
  font_2 = 12,
  font_3 = 13,
  font_4 = 14,
  font_5 = 15,
  font_6 = 16,
  font_7 = 17,
  font_8 = 18,
  font_9 = 19,

  black_letter = 20,
  black_letter_off = 23,

  --- Additional Attributes

  double_underline = 21,
  double_underline_off = 24,

  proportional = 26,
  proportional_off = 50,

  --- Foreground Colors

  fg_black = 30,
  fg_red = 31,
  fg_green = 32,
  fg_yellow = 33,
  fg_brown = 33,
  fg_blue = 34,
  fg_magenta = 35,
  fg_cyan = 36,
  fg_white = 37,
  fg_default = 39,

  --- Background Colors

  bg_black = 40,
  bg_red = 41,
  bg_green = 42,
  bg_yellow = 43,
  bg_brown = 43,
  bg_blue = 44,
  bg_magenta = 45,
  bg_cyan = 46,
  bg_white = 47,
  bg_default = 49,

  --- Additional Less Supported Attributes

  frame = 51,
  frame_off = 54,

  encircle = 52,
  encircle_off = 54,

  overline = 53,
  overline_off = 55,

  default_underline_color = 59,

  --- MinTTY Attributes

  shadow = '1:2',
  shadow_off = 22,

  solid_underline = '4:1',
  solid_underline_off = 24,

  wavy_underline = '4:3',
  wavy_underline_off = 24,

  dotted_underline = '4:4',
  dotted_underline_off = 24,

  dashed_underline = '4:5',
  dashed_underline_off = 24,

  overstrike = '8:7',
  overstrike_off = 28,

  superscript = 73,
  superscript_off = 75,

  subscript = 74,
  subscript_off = 75,

  --- Bright Foreground Colors

  bright_fg_black = 90,
  bright_fg_red = 91,
  bright_fg_green = 92,
  bright_fg_yellow = 93,
  bright_fg_blue = 94,
  bright_fg_magenta = 95,
  bright_fg_cyan = 96,
  bright_fg_white = 97,

  --- Bright Background Colors

  bright_bg_black = 100,
  bright_bg_red = 101,
  bright_bg_green = 102,
  bright_bg_yellow = 103,
  bright_bg_blue = 104,
  bright_bg_magenta = 105,
  bright_bg_cyan = 106,
  bright_bg_white = 107,

  --- Internal Use

  on = false,
  bright = false,
  off = false,
}

local LK_ANSI_HTML = {
  ['b'] = '\27[1m',
  ['/b'] = '\27[22m',
  ['strong'] = '\27[1m',
  ['/strong'] = '\27[22m',
  ['i'] = '\27[3m',
  ['/i'] = '\27[23m',
  ['em'] = '\27[3m',
  ['/em'] = '\27[23m',
  ['u'] = '\27[4m',
  ['/u'] = '\27[24m',
  ['sup'] = '\27[73m',
  ['/sup'] = '\27[75m',
  ['sub'] = '\27[74m',
  ['/sub'] = '\27[75m',
}

local lk_ansi_to_ansi_memo = setmetatable({}, { __mode = 'v' })

lk_ansi_setup = function()
  if LK_ANSI_ENV.enabled then return end

  do
    local color

    for i = 0, 255 do
      LK_ANSI_SGR['color' .. i] = string.format('38;5;%d', i)
      LK_ANSI_SGR['bg_color' .. i] = string.format('48;5;%d', i)
      LK_ANSI_SGR['underline_color' .. i] = string.format('58;5;%d', i)
    end

    for red = 0, 5 do
      for green = 0, 5 do
        for blue = 0, 5 do
          color = 16 + red * 36 + green * 6 + blue

          LK_ANSI_SGR['rgb' .. red .. green .. blue] =
            string.format('38;5;%d', color)
          LK_ANSI_SGR['bg_rgb' .. red .. green .. blue] =
            string.format('48;5;%d', color)
          LK_ANSI_SGR['underline_rgb' .. red .. green .. blue] =
            string.format('58;5;%d', color)
        end
      end
    end

    for i = 0, 23 do
      color = i + 232

      LK_ANSI_SGR['gray' .. i] = string.format('38;5;%d', color)
      LK_ANSI_SGR['bg_gray' .. i] = string.format('48;5;%d', color)
      LK_ANSI_SGR['underline_gray' .. i] = string.format('58;5;%d', color)
    end
  end

  LK_ANSI_ENV.enabled = true
end

lk_ansi_html_tags = function(value)
  assert(type(value) == 'boolean', 'lk_ansi_html_tags: expected a boolean')

  LK_ANSI_ENV.html_tags = value
end

---Converts a color string to an ANSI escape sequence.
---
---@param color string The color string to convert.
---@return string ansi The ANSI escape sequence.
local lk_ansi_internal = function(color)
  if not LK_ANSI_ENV.enabled then return '' end

  color = tostring(color or '')

  if LK_ANSI_ENV.cache and lk_ansi_to_ansi_memo[color] then
    return lk_ansi_to_ansi_memo[color].value
  end

  local format = color
    :gsub('%f[%w]bright%s+', 'bright_')
    :gsub('%f[%w]bg%s+', 'bg_')
    :gsub('%s+off%f[%W]', '_off')

  local buffer = {}

  for word in format:gmatch('[%S]+') do
    if LK_ANSI_SGR[word] then
      buffer[#buffer + 1] = LK_ANSI_SGR[word]
    elseif LK_ANSI_ENV.__palette[word] then
      buffer[#buffer + 1] = LK_ANSI_ENV.__palette[word] ~= ''
          and LK_ANSI_ENV.__palette[word]
        or nil
    elseif word:find('^fg_#%x%x%x%x%x%x$') then
      local red, green, blue = word:match('^fg_#(%x%x)(%x%x)(%x%x)')

      buffer[#buffer + 1] = string.format(
        '38;2;%d;%d;%d',
        tonumber(red, 16),
        tonumber(green, 16),
        tonumber(blue, 16)
      )
    elseif word:find('^bg_#%x%x%x%x%x%x$') then
      local red, green, blue = word:match('^bg_#(%x%x)(%x%x)(%x%x)')

      buffer[#buffer + 1] = string.format(
        '48;2;%d;%d;%d',
        tonumber(red, 16),
        tonumber(green, 16),
        tonumber(blue, 16)
      )
    elseif word:find('^=[%d:;]+$') then
      buffer[#buffer + 1] = word:match('^=([%d:;]+)$')
    else
      error(
        'lk_ansi: invalid token "' .. word .. '" in color "' .. format .. '"',
        2
      )
    end
  end

  local result = #buffer > 0 and '\27[' .. table.concat(buffer, ';') .. 'm'
    or ''

  if LK_ANSI_ENV.cache then lk_ansi_to_ansi_memo[color] = { value = result } end

  return result
end

lk_ansi_raw_paint = function(format, ...)
  format = select('#', ...) == 0 and '' .. format
    or table.concat({ format, ... })
  format = format:gsub(LK_ANSI_ENV.__color_tag, function(s)
    return lk_ansi_internal(s:sub(3, -2))
  end)

  return LK_ANSI_ENV.html_tags
      and (format:gsub('%b<>', function(s)
        return not LK_ANSI_ENV.enabled and LK_ANSI_HTML[s:sub(2, -2)] and ''
          or LK_ANSI_HTML[s:sub(2, -2)]
          or s
      end))
    or format
end

lk_ansi_paint = function(...)
  local format = lk_ansi_raw_paint(...)
  local reset = lk_ansi_internal(LK_ANSI_ENV.__reset_cmd)

  return format == '' and reset or reset .. format .. reset
end

lk_ansi_no_paint = function(format, ...)
  format = select('#', ...) == '0' and '' .. format
    or table.concat({ format, ... })
  format = format:gsub(LK_ANSI_ENV.__color_tag, ''):gsub('\27%[[%d:;]*m"', '')

  return LK_ANSI_ENV.html_tags
      and (format:gsub('%b<>', function(s)
        return LK_ANSI_HTML[s:sub(2, -2)] or s
      end))
    or format
end

lk_ansi = setmetatable({}, {
  __call = function(_, ...)
    return lk_ansi_paint(...)
  end,
  __index = function(self, key)
    local value = LK_ANSI_ENV[key]

    if value ~= nil then
      if key == '__palette' then value = {} end

      self[key] = value

      return value
    end

    local meta
    meta = {
      __call = function(_, format, ...)
        format = select('#', ...) == 0 and '' .. format
          or table.concat({ format, ... })

        return format ~= '' and lk_ansi_paint(lk_ansi_internal(key) .. format)
          or lk_ansi_internal(LK_ANSI_ENV.__reset_cmd)
      end,
      __index = function(_, sub_key)
        key = key .. ' ' .. sub_key

        return setmetatable({}, meta)
      end,
    }

    return setmetatable({}, meta)
  end,
})

--#endregion
