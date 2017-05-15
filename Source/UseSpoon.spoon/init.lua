--- === UseSpoon ===
---
--- Install, load and configure a spoon in a single statement. Inspired by Emacs' [use-package](https://www.masteringemacs.org/article/spotlight-use-package-a-declarative-configuration-tool)
---
--- Example usage:
--- ```
--- hs.loadSpoon("UseSpoon")
--- ...
--- -- This will install the spoon if needed, load it, and configure it accordingly
--- spoon.UseSpoon("Caffeine")
--- 
--- spoon.UseSpoon("SendToOmniFocus",
---                {
---                   config = {
---                      quickentrydialog = false,
---                      notifications = true
---                   },
---                   hotkeys = {
---                      send_to_omnifocus = { hyper, "t" }
---                   },
---                   fn = function(s)
---                      -- My Wiki and My Jira are apps created with Epichrome
---                      s:registerApplication("My Wiki", { apptype = "chromeapp", itemname = "wiki page" })
---                      s:registerApplication("My Jira", { apptype = "chromeapp", itemname = "issue" })
---                   end
---                }
--- )
--- --- --- --- ```
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

--- UseSpoon.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('UseSpoon')

--- UseSpoon.use(name, arg)
--- Method
--- Install, load and configure a Spoon
---
--- Parameters:
---  * name - the name of the Spoon to install (without the `.spoon` extension). If the Spoon is already installed, it will be loaded using `hs.loadSpoon()`. If it is not installed, it will be installed using `hs.spoons.asyncInstallSpoonFromRepo()` and then loaded.
---  * arg - if provided, can be used to specify the configuration of the Spoon. The following keys are recognized (all are optional):
---    * repo - repository from where the Spoon should be installed if not present in the system, as defined in `hs.spoons.repos`. Defaults to `"default"`.
---    * config - a table containing variables to be stored in the Spoon object to configure it. For example, `config = { answer = 42 }` will result in `spoon.<LoadedSpoon>.answer` being set to 42.
---    * hotkeys - a table containing hotkey bindings. If provided, will be passed as-is to the Spoon's `bindHotkeys()` method. The special string `"default"` can be given to use the Spoons `defaultHotkeys` variable, if it exists.
---    * fn - a function which will be called with the freshly-loaded Spoon object as its first argument.
---    * loglevel - if the Spoon has a variable called `logger`, its `setLogLevel()` method will be called with this value.
---    * start - if `true`, call the Spoon's `start()` method after configuring everything else.
---
--- Returns:
---  * None
---
--- Notes:
---  * For convenience, this method can be invoked directly on the UseSpoon object, i.e. `spoon.UseSpoon(name, arg)` instead of `spoon.UseSpoon.use(name, arg)`.

function obj.use(name, arg)
   obj.logger.df("UseSpoon(%s, %s)", name, hs.inspect(arg))
   if not arg then arg = {} end
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
                                                      hs.notify.show("Spoon installed by UseSpoon", name .. ".spoon is now available", "")
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
