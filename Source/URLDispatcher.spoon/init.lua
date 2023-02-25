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
obj.version = "0.5"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- URLDispatcher.default_handler
--- Variable
--- Default URL handler (Defaults to `"com.apple.Safari"`)
---
--- Notes:
--- Can be a string containing the Bundle ID of an application, or a function
--- that takes one argument, and which will be invoked with the URL to open.
obj.default_handler = "com.apple.Safari"

--- URLDispatcher.decode_slack_redir_urls
--- Variable
--- If true, handle Slack-redir URLs to apply the rule on the destination URL. Defaults to `true`
obj.decode_slack_redir_urls = true

--- URLDispatcher.url_redir_decoders
--- Variable
--- URL redirection decoders. Default value: empty list
---
--- Notes:
--- List containing optional redirection decoders (other than the known Slack
--- decoder, which is enabled by `URLDispatcher.decode_slack_redir_urls` to
--- apply to URLs before dispatching them. Each list element must be a list
--- itself with a maximum of five elements:
---   * `decoder-name`: (String) a name to identify the decoder;
---   * `decoder-pattern-or-function`: (String or Function) if a string is
---     given, it is used as a [Lua pattern](https://www.lua.org/pil/20.2.html)
---     to match against the URL. If a function is given, it will be called with
---     arguments `scheme`, `host`, `params`, `fullUrl`, `senderPid` (the same
---     arguments as passed to
---     [hs.urlevent.httpCallback](https://www.hammerspoon.org/docs/hs.urlevent.html#httpCallback)),
---     and must return a string that contains the URL to be opened. The
---     returned value will be URL-decoded according to the value of `skip-decode-url` (below).
---   * `pattern-replacement`: (String) a replacement pattern to apply if a
---     match is found when a decoder pattern (previous argument) is provided.
---     If a decoder function is given, this argument is ignored.
---   * `skip-decode-url`: (Boolean, optional) whether to skip URL-decoding of the
---     resulting string (defaults to `false`, by default URLs are always decoded)
---   * `source-application`: (String or Table, optional): a pattern or list of
---     patterns to match against the name of the application from which the URL
---     was opened. If this parameter is present, the decoder will only be
---     applied when the application matches. Default is to apply the decoder
---     regardless of the application.
--- If given as strings, `decoder-pattern-or-function` and `pattern-replacement`
--- are passed as arguments to
--- [string.gsub](https://www.lua.org/manual/5.3/manual.html#pdf-string.gsub)
--- applied on the original URL.
obj.url_redir_decoders = { }

--- URLDispatcher.url_patterns
--- Variable
--- URL dispatch rules.
---
--- Notes:
---  A table containing a list of dispatch rules. Rules are evaluated in the
---  order they are declared. Each rule is a table with the following structure:
---  `{ url-patterns, app-bundle-ID-or-function, function, app-patterns }`
---  * `url-patterns` can be: (a) a single pattern as a string, (b) a table
---    containing a list of strings, or (c) a string containing the path of a
---    file from which the patterns will be read (if the string contains a valid
---    filename it's used as a file, otherwise as a pattern). In case (c), a
---    watcher will be set to automatically re-read the contents of the file
---    when it changes. If a relative path is given (not starting with a "/"),
---    then it is considered to be relative to the Hammerspoon configuration
---    directory.
---  * If `app-bundle-ID-or-function` is specified as a string, it is
---    interpreted as a macOS application ID, and that application will be used
---    to open matching URLs. If it is a function pointer, or not given but
---    "function" is provided, it is expected to be a function that accepts a
---    single argument, and it will be called with the URL.
---  * If `app-patterns` is given, it should be a string or a table containing a
---    pattern/list of patterns, and the rule will only be evaluated if the URL
---    was opened from an application whose name matches one of those patterns.
---  * Note that the patterns are [Lua patterns](https://www.lua.org/pil/20.2.html)
---    and not regular expressions.
---  * Defaults to an empty table, which has the effect of having all URLs
---    dispatched to the `default_handler`.
obj.url_patterns = { }

--- URLDispatcher.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log
--- level for the messages coming from the Spoon.
---
--- Notes:
--- Example: `spoon.URLDispatcher.logger.setLogLevel("debug")`
obj.logger = hs.logger.new('URLDispatcher')

--- URLDispatcher.set_system_handler
--- Variable
--- If true, URLDispatcher sets itself as system handler for http requests.
--- Defaults to `true`
obj.set_system_handler = true

--- URLDispatcher.pat_files
--- Variable
--- Internal variable containing a table where the pattern lists read from files are kept indexed by file name, and automatically updated.
obj.pat_files = {}

--- URLDispatcher.pat_watchers
--- Variable
--- Internal variable containing a table where the watchers for the pattern files are kept indexed by file name.
obj.pat_watchers = {}

-- Local functions to decode URLs
function hex_to_char(x)
   return string.char(tonumber(x, 16))
end

function obj.unescape(url)
   return url:gsub("%%(%x%x)", hex_to_char)
end

-- Match a single pattern against an application name.
function obj.matchapp(app, pat)
  obj.logger.df("Matching appname '%s' against pattern '%s'", app, pat)
  return string.find(app, pat)
end

-- Match a pattern or a list of patterns against an application name.
-- The pattern can also be nil, in this case it's considered a success.
function obj.matchapps(app, pat)
   local ismatch = (pat == nil) or
      (type(pat) == 'string' and obj.matchapp(app, pat)) or
      (type(pat) == 'table' and hs.fnutils.some(pat, hs.fnutils.partial(obj.matchapp, app)))
   if ismatch then
      obj.logger.df("  App pattern '%s' is nil or matches application name '%s' - evaluating rule.", pat, app)
   else
      obj.logger.df("  App pattern '%s' does not match application name '%s' - skipping rule.", pat, app)
   end
   return ismatch
end

function obj:read_and_store(patfile)
   self.logger.df("Reading patterns from file '%s'", patfile)
   local pats = {}
   for line in io.lines(patfile) do
      -- Skip empty lines and lines starting with "#" (comments)
      if (line ~= '') and not (string.find(line, '^%s*#')) then
         table.insert(pats, line)
      end
   end
   self.pat_files[patfile] = hs.fnutils.copy(pats)
end

function obj:patfileWatcher(patfile, paths, flags)
   -- Only trigger re-reading the file when the 'itemModified' flag is present,
   -- otherwise the file gets read multiple times due to file manipulations done
   -- by editors
   if hs.fnutils.some(flags, function(f) return f['itemModified'] end) then
      self:read_and_store(patfile)
   end
end

function obj:setupPatfile(patfile)
   -- If the file exists, read it and setup a watcher to update it.
   if hs.fs.attributes(patfile) then
      self.logger.df("File '%s' has not been loaded, reading it now.", patfile)
      -- Read the file and set up the watcher to auto-update it.
      self:read_and_store(patfile)
      self.logger.df("Creating watcher for file '%s'", patfile)
      self.pat_watchers[patfile] = hs.pathwatcher.new(patfile, hs.fnutils.partial(self.patfileWatcher, self, patfile)):start()
      return self.pat_files[patfile]
   else
      return nil
   end
end

--- URLDispatcher:dispatchURL(scheme, host, params, fullUrl, senderPid)
--- Method
--- Dispatch a URL to an application according to the defined `url_patterns`.
---
--- Parameters:
---  * scheme - A string containing the URL scheme (i.e. "http")
---  * host - A string containing the host requested (e.g. "www.hammerspoon.org")
---  * params - A table containing the key/value pairs of all the URL parameters
---  * fullURL - A string containing the full, original URL. This is the only parameter used in this implementation.
---  * senderPID - An integer containing the PID of the application that opened the URL, if available (otherwise -1)
---
--- Notes:
---  * The parameters (follow to the [httpCallback](http://www.hammerspoon.org/docs/hs.urlevent.html#httpCallback) specification)
function obj:dispatchURL(scheme, host, params, fullUrl, senderPid)
   local url = fullUrl
   local currentApp = ""
   if senderPid ~= -1 then
      currentApp = hs.application.applicationForPID(senderPid):name()
   end
   self.logger.df("Dispatching URL '%s' from application '%s'", url, currentApp)
   if self.decode_slack_redir_urls then
      local newUrl = string.match(url, 'https://slack.redir.net/.*url=(.*)')
      if newUrl then
         url = obj.unescape(newUrl)
         self.logger.df("  Decoded Slack redirect. New URL: '%s'", url)
      end
   end
   for i,dec in ipairs(self.url_redir_decoders) do
      self.logger.df("  Testing decoder '%s'", dec[1])
      local processed = false
      if self.matchapps(currentApp, dec[5]) then
         if type(dec[2]) == "string" then
            if string.find(url, dec[2]) then
               self.logger.df("    Applying pattern-based decoder '%s' to URL '%s'", dec[1], url)
               url = string.gsub(url, dec[2], dec[3])
               self.logger.df("    Decoded URL: '%s'", url)
               processed = true
            end
         elseif type(dec[2]) == "function" then
            self.logger.df("    Applying function-based decoder '%s' to URL '%s'", dec[1], url)
            url = dec[2](scheme, host, params, fullUrl, senderPid)
            self.logger.df("    Decoded URL: '%s'", url)
            processed = true
         else
            self.logger.ef("    Decoder '%s' has an unknown second value of type '%s'", dec[1], dec[2])
         end
         if processed and (not dec[4]) then
            self.logger.df("    Unescaping decoded URL '%s'", url)
            url = obj.unescape(url)
            self.logger.df("    Unescaped URL: '%s'", url)
         end

      end
   end
   self.logger.df("Final URL to open: '%s'", url)
   for i,pair in ipairs(self.url_patterns) do
      self.logger.df("Evaluating rule %s", hs.inspect(pair))

      local pats = pair[1]
      local app = pair[2]
      local func = pair[3]
      local app_pats = pair[4]

      -- If app_pats is given, then first of all check whether the source app
      -- matches, otherwise we skip the whole thing
      if self.matchapps(currentApp, app_pats) then
         -- First determine how to interpret the url-patterns
         if type(pats) == "string" then
            -- A string can be a single pattern, or a filename to load
            if self.pat_files[pats] then
               -- If it's already a known pattern file, use its content
               self.logger.df("    File '%s' is already read, using its contents.", pats)
               pats = self.pat_files[pats]
            else
               -- Else, try to load it as a file
               local patsfile = self:setupPatfile(pats)
               -- If this fails, we use it as a single pattern
               if patsfile then
                  pats = patsfile
               else
                  self.logger.df("  Single pattern given, converting to list for processing.")
                  pats = { pats }
               end
            end
         end

         for i,p in ipairs(pats) do
            self.logger.df("  Testing URL with pattern '%s'", p)
            if string.match(url, p) then
               local id = nil
               if type(app) == "string" then
                  id = app
               elseif type(app) == "function" then
                  func = app
               end
               if id ~= nil then
                  self.logger.df("    Match found, opening with '%s'", id)
                  hs.application.launchOrFocusByBundleID(id)
                  hs.urlevent.openURLWithBundle(url, id)
                  return
               end
               if func ~= nil then
                  self.logger.df("    Match found, calling func '%s'", func)
                  func(url)
                  return
               end
            end
         end
      end
   end
   -- Fall through to the default handler
   if type(self.default_handler) == "string" then
      self.logger.df("No match found, opening with default handler '%s'", self.default_handler)
      hs.application.launchOrFocusByBundleID(self.default_handler)
      hs.urlevent.openURLWithBundle(url, self.default_handler)
   elseif type(self.default_handler) == "function" then
      self.logger.df("No match found, opening with default handler func '%s'", self.default_handler)
      self.default_handler(url)
   else
      self.logger.ef("Unknown type '%s' for default_handler '%s', must be a string or a function.",
                     type(self.default_handler), self.default_handler)
   end
end

--- URLDispatcher:start()
--- Method
--- Start dispatching URLs according to the rules
---
--- Parameters:
---  * None
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
