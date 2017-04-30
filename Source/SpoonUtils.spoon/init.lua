--- === SpoonUtils ===
---
--- Miscellaneous utility and management functions for spoons
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SpoonUtils.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SpoonUtils.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "SpoonUtils"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = hs.logger.new('SpoonUtils')

-- Interpolate table values into a string
-- From http://lua-users.org/wiki/StringInterpolation
local function interp(s, tab)
   return (s:gsub('($%b{})', function(w) return tab[w:sub(3, -2)] or w end))
end

-- Read a whole file into a string
local function slurp(path)
   local f = assert(io.open(path))
   local s = f:read("*a")
   f:close()
   return s
end

--- SpoonUtils.newSpoon(name, basedir, metadata)
--- Method
--- Create a skeleton directory for a new Spoon
---
--- Parameters:
---  * name: name of the new spoon, without the `.spoon` extension
---  * basedir: (optional) directory where to create the template. Defaults to `~/.hammerspoon/Spoons`
---  * metadata: (optional) table containing metadata values to be inserted in the template. Provided values are merged with the defaults. Defaults to:
---    ```
---    {
---      version = "0.1",
---      author = "Your Name <your@email.org>",
---      homepage = "https://github.com/Hammerspoon/Spoons",
---      license = "MIT - https://opensource.org/licenses/MIT",
---      download_url = "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/"..name..".spoon.zip"
---    }
---    ```
---  * template: (optional) absolute path of the template to use for the `init.lua` file of the new Spoon. Defaults to the `templates/init.tpl` file included with SpoonUtils.
function obj:newSpoon(name, basedir, metadata, template)
   if basedir == nil or basedir == "" then
      basedir = hs.configdir .. "/Spoons"
   end
   local meta={
      version = "0.1",
      author = "Your Name <your@email.org>",
      homepage = "https://github.com/Hammerspoon/Spoons",
      license = "MIT - https://opensource.org/licenses/MIT",
      download_url = "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/"..name..".spoon.zip",
      description = "A new Sample Spoon"
   }
   if metadata then
      for k,v in pairs(metadata) do meta[k] = v end
   end
   meta["name"]=name

   local dirname = basedir .. "/" .. name .. ".spoon"
   hs.fs.mkdir(dirname)
   hs.fs.chdir(dirname)
   local f=assert(io.open(dirname .. "/init.lua", "w"))
   local template_file = template or self:resource_path("templates/init.tpl")
   local text=slurp(template_file)
   f:write(interp(text, meta))
   f:close()
   print("Created new spoon " .. dirname)
end

--- SpoonUtils:script_path()
--- Method
--- Return path of the current spoon.
---
--- Parameters:
---  * n - (optional) stack level for which to get the path. Defaults to 2, which will return the path of the spoon which called `script_path()`
---
--- Returns:
---  * String with the path from where the calling code was loaded.
function obj:script_path(n)
   if n == nil then n = 2 end
   local str = debug.getinfo(n, "S").source:sub(2)
   return str:match("(.*/)")
end

--- SpoonUtils:resource_path(partial)
--- Method
--- Return full path of an object within a spoon directory, given its partial path.
---
--- Parameters:
---  * partial - path of a file relative to the Spoon directory. For example `images/img1.png` will refer to a file within the `images` directory of the Spoon.
---
--- Returns:
---  * Absolute path of the file. Note: no existence or other checks are done on the path.
function obj:resource_path(partial)
   return(self:script_path(3) .. partial)
end

return obj
