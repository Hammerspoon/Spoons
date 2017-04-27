--- === URLDispatcher ===
---
--- Route URLs to different applications with pattern matching
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
--- Bundle ID for default URL handler. (Defaults to `"com.apple.Safari"`)
obj.default_handler = "com.apple.Safari"

--- URLDispatcher.decode_slack_redir_urls
--- Variable
--- If true, handle Slack-redir URLs to apply the rule on the destination URL. Defaults to `true`
obj.decode_slack_redir_urls = true

--- URLDispatcher.url_patterns
--- Variable
--- URL dispatch rules.
--- A table containing a list of dispatch rules. Each rule should be its own table in the format: `{ "url pattern", "application bundle ID" }`, and they are evaluated in the order they are declared. Note that the patterns are [Lua patterns](https://www.lua.org/pil/20.2.html) and not regular expressions. Defaults to an empty table, which has the effect of having all URLs dispatched to the `default_handler`.
obj.url_patterns = { }

local logger = hs.logger.new("URLDispatcher")

-- Local functions to decode URLs
function hex_to_char(x)
   return string.char(tonumber(x, 16))
end

function unescape(url)
   return url:gsub("%%(%x%x)", hex_to_char)
end

--- URLDispatcher:dispatchURL(scheme, host, params, fullUrl)
--- Method
--- Dispatch a URL to an application according to the defined `url_patterns`.
---
--- Parameters (according to the [httpCallback](http://www.hammerspoon.org/docs/hs.urlevent.html#httpCallback) specification):
---  * scheme - A string containing the URL scheme (i.e. "http")
---  * host - A string containing the host requested (e.g. "www.hammerspoon.org")
---  * params - A table containing the key/value pairs of all the URL parameters
---  * fullURL - A string containing the full, original URL
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
   if hs.urlevent.httpCallback then
      logger.w("An hs.urlevent.httpCallback was already set. I'm overriding it with my own but you should check if this breaks any other functionality")
   end
   hs.urlevent.httpCallback = function(...) self:dispatchURL(...) end
   hs.urlevent.setDefaultHandler('http')
   return self
end

return obj
