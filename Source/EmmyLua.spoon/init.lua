--- === EmmyLua ===
---
--- Thie plugin generates EmmyLua annotations for Hammerspoon and any installed Spoons
--- under ~/.hammerspoon/Spoons/EmmyLua.spoon/annotations.
--- Annotations will only be generated if they don't exist yet or are out of date.
---
--- Note: Load this Spoon before any pathwatchers are defined to avoid unintended behaviour (for example multiple reloads when the annotions are created).
---
--- In order to get auto completion in your editor, you need to have one of the following LSP servers properly configured:
--- * [lua-language-server](https://github.com/sumneko/lua-language-server) (recommended)
--- * [EmmyLua-LanguageServer](https://github.com/EmmyLua/EmmyLua-LanguageServer)
---
--- To start using this annotations library, add the annotations folder to your workspace.
--- for lua-languag-server:
---
--- ```json
--- {
---   "Lua.workspace.library": ["/Users/YOUR_USERNAME/.hammerspoon/Spoons/EmmyLua.spoon/annotations"]
--- }
--- ```
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/EmmyLua.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/EmmyLua.spoon.zip)

local M = {}

M.name = "EmmyLua"
M.version = "1.0"
M.author = "http://github.com/folke"
M.license = "MIT - https://opensource.org/licenses/MIT"

local options = {
  annotations = hs.spoons.resourcePath("annotations"),
  types = {
    bool = "boolean",
    boolean = "boolean",
    ["false"] = "boolean",
    ["true"] = "boolean",
    string = "string",
    number = "number",
    float = "number",
    integer = "number",
    app = "hs.application",
    hsminwebtable = "hs.httpserver.hsminweb",
    notificationobject = "hs.notify",
    point = "hs.geometry",
    rect = "hs.geometry",
    ["hs.geometry rect"] = "hs.geometry",
    size = "hs.geometry",
  },
}

M.spoonPath = hs.spoons.scriptPath()

function M.comment(str, commentStr)
  commentStr = commentStr or "--"
  return commentStr .. " " .. str:gsub("[\n]", "\n" .. commentStr .. " "):gsub("%s+\n", "\n") .. "\n"
end

function M.parseType(module, str)
  if not str then
    return
  end

  str = str:lower()

  if options.types[str] then
    return options.types[str]
  end

  local type = str:match("^(hs%.%S*)%s*object")
  if type then
    return type
  end

  type = str:match("^list of (hs%.%S*)%s*object")
  if type then
    return type .. "[]"
  end

  if module.name:find(str, 1, true) or str == "self" then
    return module.name
  end
end

function M.trim(str)
  str = str:gsub("^%s*", "")
  str = str:gsub("%s*$", "")
  return str
end

function M.parseArgs(str)
  local name, args = str:match("^(.*)%((.*)%)$")
  if name then
    args = args:gsub("%s*|%s*", "_or_")
    args = args:gsub("%s+or%s+", "_or_")
    args = args:gsub("[%[%]{}%(%)]", "")
    if args:find("...") then
      args = args:gsub(",?%s*%.%.%.", "")
      args = M.trim(args)
      if #args > 0 then
        args = args .. ", "
      end
      args = args .. "..."
    end
    args = hs.fnutils.split(args, "%s*,%s*")
    for a, arg in ipairs(args) do
      if arg == "false" then
        args[a] = "_false"
      elseif arg == "function" then
        args[a] = "fn"
      elseif arg == "end" then
        args[a] = "_end"
      end
    end
    return name, args
  end
  return str
end

function M.parseDef(module, el)
  el.def = el.def or ""
  el.def = module.prefix .. el.def
  local parts = hs.fnutils.split(el.def, "%s*%-+>%s*")
  local name, args = M.parseArgs(parts[1])
  local ret = { name = name, args = args, type = M.parseType(module, parts[2]) }
  if name:match("%[.*%]$") then
    if not ret.type then
      ret.type = "table"
    end
    ret.name = ret.name:sub(1, ret.name:find("%[") - 1)
  end
  return ret
end

function M.processModule(module)
  io.write("--# selene: allow(unused_variable)\n")
  io.write("---@diagnostic disable: unused-local\n\n")

  if module.name == "hs" then
    io.write("--- global variable containing loaded spoons\n")
    io.write("spoon = {}\n\n")
  end

  io.write(M.comment(module.doc))
  io.write("---@class " .. module.name .. "\n")
  io.write("local M = {}\n")
  io.write(module.name .. " = M\n\n")

  for _, item in ipairs(module.items) do
    local def = M.parseDef(module, item)
    -- io.write("-- " .. item.def)
    io.write(M.comment(item.doc))
    local name = def.name
    if def.name:find(module.name, 1, true) == 1 then
      name = "M" .. def.name:sub(#module.name + 1)
    end
    if def.args then
      if def.type then
        io.write("---@return " .. def.type .. "\n")
      end
      io.write("function " .. name .. "(" .. table.concat(def.args, ", ") .. ") end\n")
    else
      if def.type then
        io.write("---@type " .. def.type .. "\n")
      end
      if def.type and (def.type:find("table") or def.type:find("%[%]")) then
        io.write(name .. " = {}\n")
      else
        io.write(name .. " = nil\n")
      end
    end
    io.write("\n")
  end
end

function M.create(jsonDocs, prefix)
  local mtime = hs.fs.attributes(jsonDocs, "modification")
  prefix = prefix or ""
  local data = hs.json.read(jsonDocs)
  for _, module in ipairs(data) do
    if module.type ~= "Module" then
      error("Expected a module, but found type=" .. module.type)
    end
    module.prefix = prefix
    module.name = prefix .. module.name
    local fname = options.annotations .. "/" .. module.name .. ".lua"
    local fmtime = hs.fs.attributes(fname, "modification")
    if fmtime == nil or mtime > fmtime then
      -- print("creating " .. fname)
      local fd = io.open(fname, "w+")
      io.output(fd)
      M.processModule(module)
      io.close(fd)
    end
  end
end

function M:init()
  hs.fs.mkdir(options.annotations)
  -- Load hammerspoon docs
  M.create(hs.docstrings_json_file)

  -- Load Spoons
  for _, spoon in ipairs(hs.spoons.list()) do
    local doc = hs.configdir .. "/Spoons/" .. spoon.name .. ".spoon/docs.json"
    if hs.fs.attributes(doc, "modification") then
      M.create(doc, "spoon.")
    end
  end
end

return M
