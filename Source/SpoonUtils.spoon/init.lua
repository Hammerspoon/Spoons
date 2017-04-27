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

-- Interpolate table values into a string
-- From http://lua-users.org/wiki/StringInterpolation
function interp(s, tab)
   return (s:gsub('($%b{})', function(w) return tab[w:sub(3, -2)] or w end))
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
function obj.newSpoon(name, basedir, metadata)
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
   f:write(interp([[
--- === ${name} ===
---
--- ${description}
---
--- Download: [${download_url}](${download_url})

local obj={}
obj.__index = obj

-- Metadata
obj.name = "${name}"
obj.version = "${version}"
obj.author = "${author}"
obj.homepage = "${homepage}"
obj.license = "${license}"

--- Some internal variable
obj.key_hello = nil

--- ${name}.some_config_param
--- Variable
--- Some configuration parameter
obj.some_config_param = true

--- ${name}:sayHello()
--- Method
--- Greet the user
function obj:sayHello()
   hs.alert.show("Hello!")
   return self
end

--- BrewInfo:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for ${name}
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * hello - Say Hello
function obj:bindHotkeys(mapping)
   if mapping["hello"] then
      if (self.key_hello) then
         self.key_hello:delete()
      end
      self.key_hello = hs.hotkey.bindSpec(mapping["hello"], function() self:sayHello() end)
   end
end

return obj
]], meta))
   f:close()
   print("Created new spoon " .. dirname)
end

return obj
