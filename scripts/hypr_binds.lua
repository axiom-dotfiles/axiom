-- Description: Lists the binds Hyprland Lua config files make, by running
--              them against a stand-in `hl` that only records hl.bind and
--              hl.unbind (so variables, string building and loops all work).
--              Used by merge_hypr_binds.py.
-- Usage:       lua hypr_binds.lua <hypr dir> <module>...
--              Each module is required as Hyprland's managed config does
--              (`user.<name>`), with <hypr dir> on package.path. Prints JSON:
--              { binds: [{ file, line, key, dispatcher, args, lua, opts }],
--                unbinds: [{ file, line, key }], errors: [text] }
--              `dispatcher` is the hl.dsp name ("window.close"), `args` its
--              arguments, `lua` the dispatcher as Lua source; all three are
--              absent when the dispatcher is a Lua function, which can't be
--              moved. Nothing else the files ask for is done: commands
--              aren't run and os.execute/exit/remove/rename do nothing.

---@diagnostic disable: duplicate-set-field, lowercase-global

local dir = arg[1]
local modules = { table.unpack(arg, 2) }

-- --- JSON ---

local function json(value)
  local kind = type(value)
  if kind == "nil" then
    return "null"
  elseif kind == "boolean" or kind == "number" then
    return tostring(value)
  elseif kind == "string" then
    return '"' .. value:gsub('[%c"\\]', function(c)
      local named = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" }
      return named[c] or string.format("\\u%04x", c:byte())
    end) .. '"'
  end
  -- A table: an array when its keys are 1..n (an empty one too)
  local n = #value
  local count = 0
  for _ in pairs(value) do count = count + 1 end
  local parts = {}
  if count == n then
    for i = 1, n do parts[i] = json(value[i]) end
    return "[" .. table.concat(parts, ",") .. "]"
  end
  local keys = {}
  for k in pairs(value) do keys[#keys + 1] = tostring(k) end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local v = value[k]
    if v == nil then v = value[tonumber(k)] end
    parts[#parts + 1] = json(k) .. ":" .. json(v)
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

-- --- Values back to Lua source ---

-- Plain values only (strings, numbers, booleans, tables of them); nil and
-- false when there's anything else
local function plain(value)
  local kind = type(value)
  if kind == "string" or kind == "number" or kind == "boolean" then
    return true
  elseif kind == "table" and getmetatable(value) == nil then
    for k, v in pairs(value) do
      if (type(k) ~= "string" and type(k) ~= "number") or not plain(v) then return false end
    end
    return true
  end
  return false
end

local function lua(value)
  local kind = type(value)
  if kind == "string" then
    return string.format("%q", value):gsub("\\\n", "\\n")
  elseif kind ~= "table" then
    return tostring(value)
  end
  local parts = {}
  for i = 1, #value do parts[#parts + 1] = lua(value[i]) end
  local keys = {}
  for k in pairs(value) do
    if not (math.type(k) == "integer" and k >= 1 and k <= #value) then keys[#keys + 1] = k end
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do
    local name = type(k) == "string" and k:match("^[%a_][%w_]*$") and k or ("[" .. lua(k) .. "]")
    parts[#parts + 1] = name .. " = " .. lua(value[k])
  end
  return #parts == 0 and "{}" or "{ " .. table.concat(parts, ", ") .. " }"
end

-- --- The stand-in hl ---

-- Anything but bind/unbind/dsp: indexing or calling it gives itself, so
-- hl.config{...}, hl.on(...), x:set_enabled(false) all pass
local sink
sink = setmetatable({}, {
  __index = function() return sink end,
  __call = function() return sink end,
})

local DISPATCHER = {}
local function dsp(name)
  return setmetatable({}, {
    __index = function(_, k) return dsp(name and (name .. "." .. k) or k) end,
    __call = function(_, ...)
      return setmetatable({ name = name, args = table.pack(...) }, DISPATCHER)
    end,
  })
end

local binds, unbinds, errors = {}, {}, {}

-- Where the hl.* call was made: its file and line
local function site()
  local info = debug.getinfo(3, "Sl")
  local source = info and info.source or ""
  return source:sub(1, 1) == "@" and source:sub(2) or "", info and info.currentline or 0
end

hl = setmetatable({
  dsp = dsp(nil),
  bind = function(key, dispatcher, opts)
    local file, line = site()
    local entry = { file = file, line = line, key = type(key) == "string" and key or nil }
    if getmetatable(dispatcher) == DISPATCHER then
      local args = {}
      for i = 1, dispatcher.args.n do args[i] = dispatcher.args[i] end
      local ok = dispatcher.args.n == #args
      for i = 1, #args do ok = ok and plain(args[i]) end
      if ok then
        local sources = {}
        for i = 1, #args do sources[i] = lua(args[i]) end
        entry.dispatcher = dispatcher.name
        entry.args = args
        entry.lua = "hl.dsp." .. dispatcher.name .. "(" .. table.concat(sources, ", ") .. ")"
      end
    end
    if type(opts) == "table" then
      entry.opts = {}
      for k, v in pairs(opts) do
        entry.opts[tostring(k)] = plain(v) and v or tostring(v)
      end
    end
    binds[#binds + 1] = entry
    return sink
  end,
  unbind = function(key)
    local file, line = site()
    unbinds[#unbinds + 1] = { file = file, line = line, key = type(key) == "string" and key or nil }
    return sink
  end,
}, { __index = function() return sink end })

os.execute = function() return true, "exit", 0 end
os.exit = function() error("os.exit", 0) end
os.remove = function() return true end
os.rename = function() return true end

package.path = dir .. "/?.lua;" .. dir .. "/?/init.lua;" .. package.path

for _, module in ipairs(modules) do
  local ok, err = pcall(require, module)
  if not ok then errors[#errors + 1] = module .. ": " .. tostring(err) end
end

io.write(json({ binds = binds, unbinds = unbinds, errors = errors }), "\n")
