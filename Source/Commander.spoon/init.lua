--- === Commander ===
---
--- This spoon lets execute commands from other spoon by a chooser.
---
--- The way of Commander to generate it command list is
--- it goes to each spoon and extract all public functions inside the spoon table.
--- for each function the name is set to "spoonName.functionName".
--- if the spoon has a table called `commandderCommandTable`, Commander will
--- ignore everything else and take whatever is in the table.
--- In this case the naming convention is the same.
--- Then Commander grabs all the functions in global table.
--- functions are tested against `Commander.ignoredCommandList`,
--- except when spoon author provides a `commanderCommandList`.
---
--- Commander.chooser is the chooser, you can set background color, rows, etc, to it.

local obj={}
obj.__index = obj


-- Metadata
obj.name = "Commander"
obj.version = "0.7"
obj.author = "Yuan Fu <casouri@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- it will be updated the first time when obj.getCommands was called.
-- you can add your comstom commands dynamically
-- key is name of command
-- value is the command(function)
--- Commander.commandTable
--- Variable
--- This is the table which stores all the commands
--- Each key is the name of the command,
--- and each value is the actual function.
--- you can add your custom commands to it.
obj.commandTable = {}

--- Commander.ignoredCommandList
--- Variable
--- This list contains all the ignored function names,
--- any function matches the name inside this list will not
--- be added to Commander.commandTable.
---
--- The list contains normal lua builtin functions
--- and some hammerspoon functions that generally shouldn't
--- be a command, such as init, bindHotkeys, etc.
obj.ignoredCommandList = {
   'load', 'pcall', 'dofile', 'pairs', 'rawset', 'callback', 'setmetatable',
   'tonumber', 'print', 'require', 'getmetatable', 'error', 'init', 'rawequal',
   'collectgarbage', 'rawget', 'rawrequire', 'assert', 'tostring', 'loadfile',
   'xpcall', 'next', 'rawlen', 'type', 'ipairs','bindHotkeys'
}

--- Commander.forceLayout
--- Variable
--- If you want to switch to a layout when enabled chooser,
--- set this to name of that layout
obj.forceLayout = nil

--- Commander.forceMethod
--- Variable
--- If you want to switch to a method when enabled chooser,
--- set this to name of that method
obj.forceMethod = nil

--- Commander.show()
--- Function
--- This function shows the command chooser.
--- Bind this to a hotkey to use commander. 
function obj.show()
   hs.keycodes.setLayout(obj.forceLayout or '')
   hs.keycodes.setMethod(obj.forceMethod or '')
   obj.chooser:show()
end


-- test if testValue is in list
local function isMemberOf(testValue, list)
   for index = 1, #list do
      if testValue == list[index] then
         return true
      end
   end
   return false
end


local function getCommandList()
   -- if it is the first time called
   -- or commandTable is reseted
   if #obj.commandTable == 0 then
      -- get spoon commands
      for spoonKey, spoonTable in pairs(spoon) do
         -- when spoon author provids a set of commands
         -- note that ignoredCommandList is not checked
         if spoonTable.commanderCommandList then
            for name, func in pairs(spoonTable.commanderCommandList) do
               obj.commandTable[spoonKey..'.'..name] = func
            end
         -- when spoon author didn't
         else
            for commandName, commandFunc in pairs(spoonTable) do
               if type(commandFunc) == 'function' and not isMemberOf(commandName, obj.ignoredCommandList) then
                  obj.commandTable[spoonKey..'.'..commandName] = commandFunc
               end
            end
         end
      end
      -- get global commands
      for name, value in pairs(_G) do
         if type(value) == 'function' and not isMemberOf(name, obj.ignoredCommandList) then
            obj.commandTable[name] = value
         end
      end
   end
   local choiceList = {}
   for name, func in pairs(obj.commandTable) do
      table.insert(choiceList, {text=name})
   end
   return choiceList
end


--- Commander.addCommand(commandTable)
--- Function
--- Add a command to Commander.commandTable
---
--- Parameters:
--- * comamndTable - It is a table with same form of Commander.commandTable
---                  key is name of command, value is the function.
---
--- Note:
--- Commander doesn't test the name against Commander.ignoredCommandList
--- because it assumes you know what you are doing.
function obj.addCommand(commandTable)
   obj.commandTable[commandTable.name] = commandTable.command
end

--- Commander.resetCommandTable()
--- Function
--- This function simply set Commander.commandTable to {},
--- Then the next time commander chooser is called
--- it will generate the table again.
function obj.resetCommandTable()
   obj.commandTable = {}
end


local function runCommand(selectedTable)
   obj.chooser:hide()
   obj.commandTable[selectedTable.text]()
end

function obj:init()
   obj.chooser = hs.chooser.new(runCommand)
   obj.chooser:choices(getCommandList)
   obj.chooser:searchSubText(true)
   return obj.chooser
end


return obj
