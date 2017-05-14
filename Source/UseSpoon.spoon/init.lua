--- === UseSpoon ===
---
--- Install, load and configure a spoon in a single statement. Inspired by Emacs' [use-package](https://www.masteringemacs.org/article/spotlight-use-package-a-declarative-configuration-tool)
---
--- Example usage:
--- ```
--- hs.loadSpoon("UseSpoon")
--- ...
--- -- This will install the spoon if needed, load it, and run the provided config function (if given)
--- spoon.UseSpoon("BrewInfo",
---                function(s)
---                   s:bindHotkeys({
---                         show_brew_info = {hyper, "b"},
---                         open_brew_url = {shift_hyper, "b"},
---                   })
---                   s.brew_info_style = {
---                      textFont = "Inconsolata",
---                      textSize = 14,
---                      radius = 10 }
--- end)
--- --- ```
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/UseSpoon.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/UseSpoon.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "UseSpoon"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- WindowScreenLeftAndRight.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('UseSpoon')

function obj.use(name, arg)
   obj.logger.df("UseSpoon(%s, %s)", name, hs.inspect(arg))
   local repo = arg.repo or "default"
   local _load_and_config =function()
      hs.loadSpoon(name)
      local spn=spoon[name]
      if spn then
         if arg.loglevel and spn.logger then
            spn.logger.setLogLevel(arg.loglevel)
         end
         if arg.config then
            for k,v in pairs(arg.config) do
               obj.logger.df("Setting config: spoon.%s.%s = %s", name, k, hs.inspect(v))
               spn[k] = v
            end
         end
         if arg.hotkeys then
            local mapping = arg.hotkeys
            if mapping == 'default' then
               if spn.defaultHotkeys then
                  mapping = spn.defaultHotkeys
               else
                  obj.logger.ef("Default bindings requested, but spoon %s does not have a defaultHotkeys definition", name)
               end
            end
            if type(mapping) == 'table' then
               obj.logger.df("Binding hotkeys: spoon.%s:bindHotkeys(%s)", name, hs.inspect(arg.hotkeys))
               spn:bindHotkeys(mapping)
            end
         end 
         if arg.fn then
            obj.logger.df("Calling configuration function %s", hs.inspect(arg.fn))
            arg.fn(spn)
         end
         if arg.start then
            obj.logger.df("Calling spoon.%s:start()", name)
            spn:start()
         end
      else
         obj.logger.ef("I could not load spoon %s\n", name)
      end
   end
   if hs.spoons.isInstalled(name) then
      _load_and_config()
   else
      if hs.spoons.repos[repo] then
         if hs.spoons.repos[repo].data then
            hs.spoons.asyncInstallSpoonFromRepo(name, repo,
                                                function(urlparts, success)
                                                   if success then
                                                      hs.notify.show("Installed Spoon " .. name, "Enjoy!", "")
                                                      _load_and_config() 
                                                   else
                                                      obj.logger.ef("Error installing Spoon '%s' from repo '%s'", name, repo)
                                                   end
                                                end
            )
         else
            hs.spoons.asyncUpdateRepo(repo,
                                      function(repo, success)
                                         if success then
                                            obj.use(name, arg)
                                         else
                                            obj.logger.ef("Error updating repository '%s'", repo)
                                         end
                                      end
            )
         end
      else
         obj.logger.ef("Unknown repository '%s' for Spoon", repo, name)
      end
   end
end

setmetatable(obj, { __call = function(_, ...) return obj.use(...) end })

return obj
