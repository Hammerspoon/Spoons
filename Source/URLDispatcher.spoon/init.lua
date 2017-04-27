--- === URLDispatcher ===
---
--- Flexible URL handling
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/URLDispatcher.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/URLDispatcher.spoon.zip)
---
--- Sets Hammerspoon as the default browser for HTTP/HTTPS links, and
--- dispatches them to different apps according to the patterns defined
--- in the config. If no pattern matches, `default_handler` is used.

local obj={}
obj.__index = obj

-- Metadata
obj.name = "URLDispatcher"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- URLDispatcher.default_handler
--- Variable
--- Bundle ID for default URL handler
obj.default_handler = "com.apple.Safari"

--- URLDispatcher.decode_slack_redir_urls
--- Variable
--- If true, handle Slack-redir URLs to apply the rule on the destination URL
obj.decode_slack_redir_urls = true

--- URLDispatcher.url_patterns
--- Variable
--- URL dispatch rules.
--- Evaluated in the order they are declared. Entry format: { "url pattern", "application bundle ID" }
obj.url_patterns = { }

-- Local functions to decode URLs
function hex_to_char(x)
   return string.char(tonumber(x, 16))
end

function unescape(url)
   return url:gsub("%%(%x%x)", hex_to_char)
end

--- URLDispatcher:somePublicMethod(param)
--- Method
--- Documentation for a public API method and its parameters
---
--- Parameters:
---  * param - Description of the parameter
function obj:dispatchURL(scheme, host, params, fullUrl)
   local url = fullUrl
   if self.decode_slack_redir_urls then
      local newUrl = string.match(url, 'https://slack.redir.net/.*url=(.*)')
      if newUrl then
         url = unescape(newUrl)
      end
   end
   for i,pair in ipairs(self.url_patterns) do
      local p = pair[1]
      local app = pair[2]
      if string.match(url, p) then
         id = app
         if id ~= nil then
            hs.urlevent.openURLWithBundle(url, id)
            return
         end
      end
   end
   hs.urlevent.openURLWithBundle(url, self.default_handler)
end

--- URLDispatcher:start()
--- Method
--- Start dispatching URLs according to the rules
function obj:start()
   hs.urlevent.httpCallback = function(...) self:dispatchURL(...) end
   hs.urlevent.setDefaultHandler('http')
   return self
end

return obj
