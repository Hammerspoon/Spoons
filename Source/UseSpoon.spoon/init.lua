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

function obj.use(name, repo, configfn)
   -- Second parameter is optional
   if type(repo) == "function" then
      configfn = repo
      repo = nil
   end
   print(hs.inspect(hs.spoons.repos))
   if not hs.spoons.isInstalled(name) then
      hs.spoons.installSpoonFromRepo(name, repo)
   end
   hs.timer.doAfter(0.5,
                    function()
                       hs.loadSpoon(name)
                       if spoon[name] then
                          if configfn then
                             configfn(spoon[name])
                          end
                       else
                          obj.logger.ef("I could not load spoon %s\n", name)
                       end
   end)
end

function obj:init()
   hs.spoons.updateAllRepos()
end

setmetatable(obj, { __call = function(_, ...) return obj.use(...) end })

return obj
