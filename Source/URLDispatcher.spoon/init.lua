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
obj.version = "0.3"
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

--- URLDispatcher.url_redir_decoders
--- Variable
--- List containing optional additional redirection decoders (other
--- than the known Slack decoder, which is enabled by
--- `URLDispatcher.decode_slack_redir_urls` to apply to URLs before
--- dispatching them. Each list element must be a list itself with four
--- elements:
---   * String: a name to identify the decoder;
---   * String: a [Lua pattern](https://www.lua.org/pil/20.2.html) to match against the URL;
---   * String: a replacement pattern to apply if a match is found;
---   * (optional) Boolean: whether to skip URL-decoding of the resulting string (by default the results are always decoded);
---   * (optional) String or Table: a pattern or list of patterns to match against the name of the application from which the URL was opened. If this parameter is present, the decoder will only be applied when the application matches. Default is to apply the decoder regardless of the application.
--- The first two values are passed as arguments to
--- [string.gsub](https://www.lua.org/manual/5.3/manual.html#pdf-string.gsub)
--- applied on the original URL.  Default value: empty list
obj.url_redir_decoders = { }

--- URLDispatcher.url_patterns
--- Variable
--- URL dispatch rules.
--- A table containing a list of dispatch rules. Each rule should be its own table in the format: `{ "url pattern", "application bundle ID", "function" }`, and they are evaluated in the order they are declared. Note that the patterns are [Lua patterns](https://www.lua.org/pil/20.2.html) and not regular expressions. Defaults to an empty table, which has the effect of having all URLs dispatched to the `default_handler`. If "application bundle ID" is specified, that application will be used to open matching URLs. If no "application bundle ID" is specified, but "function" is provided (and is a Lua function) it will be called with the URL.
obj.url_patterns = { }

--- URLDispatcher.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('URLDispatcher')

--- URLDispatcher.set_system_handler
--- Variable
--- If true, URLDispatcher set itself as system handler for http requests. Defaults to `true`
obj.set_system_handler = true

-- Local functions to decode URLs
function hex_to_char(x)
   return string.char(tonumber(x, 16))
end

function obj.unescape(url)
   return url:gsub("%%(%x%x)", hex_to_char)
end

function obj.matchapp(app, pat)
  obj.logger.df("Matching %s with %s", app, pat)
  return string.find(app, "^"..pat.."$")
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
   local currentApp = hs.window.frontmostWindow():application():name()
   self.logger.df("Dispatching URL '%s' from application %s", url, currentApp)
   if self.decode_slack_redir_urls then
      local newUrl = string.match(url, 'https://slack.redir.net/.*url=(.*)')
      if newUrl then
         url = obj.unescape(newUrl)
      end
   end
   for i,dec in ipairs(self.url_redir_decoders) do
     if (dec[5] == nil) or
       (type(dec[5]) == 'string' and obj.matchapp(currentApp, dec[5])) or
       (type(dec[5]) == 'table' and hs.fnutils.some(dec[5], hs.fnutils.partial(obj.matchapp, currentApp)))
     then
       if string.find(url, dec[2]) then
         self.logger.df("Applying decoder '%s' to URL '%s'", url, dec[1])
         url = string.gsub(url, dec[2], dec[3])
         if not dec[4] then
           url = obj.unescape(url)
         end
         self.logger.df("  New URL after decoding: '%s'", url)
       end
     end
   end
   for i,pair in ipairs(self.url_patterns) do
      local p = pair[1]
      local app = pair[2]
      local func = pair[3]
      if string.match(url, p) then
         id = app
         if id ~= nil then
            self.logger.df("Match found, opening with '%s'", id)
            hs.application.launchOrFocusByBundleID(id)
            hs.urlevent.openURLWithBundle(url, id)
            return
         end
         if func ~= nil then
            self.logger.df("Match found, calling func '%s'", func)
            func(url)
            return
         end
      end
   end
   self.logger.df("No match found, opening with default handler '%s'", self.default_handler)
   hs.application.launchOrFocusByBundleID(self.default_handler)
   hs.urlevent.openURLWithBundle(url, self.default_handler)
end

--- URLDispatcher:start()
--- Method
--- Start dispatching URLs according to the rules
function obj:start()
   if hs.urlevent.httpCallback then
      self.logger.w("An hs.urlevent.httpCallback was already set. I'm overriding it with my own but you should check if this breaks any other functionality")
   end
   hs.urlevent.httpCallback = function(...) self:dispatchURL(...) end
   if self.set_system_handler then
      hs.urlevent.setDefaultHandler('http')
   end
   --   hs.urlevent.setRestoreHandler('http', self.default_handler)
   return self
end

return obj
