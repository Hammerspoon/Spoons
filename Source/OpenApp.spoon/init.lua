--- === OpenApp ===
---
--- open a chooser to open apps.

obj = {}
obj.__index = obj

-- Metadata
obj.name = "OpenApp"
obj.version = "0.7"
obj.author = "Yuan Fu <casouri@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"


--- OpenApp.searchPath
--- Variable
--- OpenApp search paths in this list for applications.
obj.searchPath = {'/Applications'}

--- OpenApp.show()
--- Function
--- Call this function to pop chooser to choose applications.
function obj.show()
   obj.chooser:show()
end

local function getAppList()
   local appList = {}
   for index = 1, #obj.searchPath do
      -- resolve relative path and symlinks
      local path = hs.fs.pathToAbsolute(obj.searchPath[index])
      local iterFunc, dicTable = hs.fs.dir(path)
      while true do
         local fileName = iterFunc(dicTable)
         -- when there are no other files
         if not fileName then break end
         if fileName ~= '.' and fileName ~= '..' then
            table.insert(appList, {text=fileName})
         end
      end
   end
   return appList
end

local function openApp(appTable)
   obj.chooser:hide()
   if appTable then
      hs.application.launchOrFocus(appTable.text)
   end
end

function obj:init()
   obj.chooser = hs.chooser.new(openApp)
   obj.chooser:choices(getAppList)
   obj.chooser:searchSubText(true)
   return obj.chooser
end

return obj
