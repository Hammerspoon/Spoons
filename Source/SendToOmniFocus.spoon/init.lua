--- === SendToOmniFocus ===
---
--- Handles "send current item to OmniFocus" for multiple applications
---
--- The following applications are supported: out of the box: Outlook, Evernote, Mail, Chrome and any Chrome-based apps (such as SSBs created by [Epichrome](https://github.com/dmarmor/epichrome))
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SendToOmniFocus.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SendToOmniFocus.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "SendToOmniFocus"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- --------------------------------------------------------------------
-- Methods from hs.spoons inserted locally to make he spoon self-sufficient
-- while hs.spoons is merged (https://github.com/Hammerspoon/hammerspoon/pull/1405)

local function _script_path(n)
   if n == nil then n = 2 end
   local str = debug.getinfo(n, "S").source:sub(2)
   return str:match("(.*/)")
end

local function _resource_path(partial)
   return(_script_path(3) .. partial)
end

function obj:bindHotkeysToSpec(def,map)
   local spoonpath = _script_path(3)
   for name,key in pairs(map) do
      if def[name] ~= nil then
         local keypath = spoonpath .. name
         if self._keys[keypath] then
            self._keys[keypath]:delete()
         end
         self._keys[keypath]=hs.hotkey.bindSpec(key, def[name])
      else
         self.logger.ef("Error: Hotkey requested for undefined action '%s'", name)
      end
   end
end

-- --------------------------------------------------------------------

--- SendToOmniFocus.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('SendToOmniFocus')

--- SendToOmniFocus.notifications
--- Variable
--- Boolean to control Hammerspoon-generated notifications when filing items (doest not control AppleScript notifications, if any, generated from within the scripts). Defaults to `true`.
obj.notifications = true

--- SendToOmniFocus.quickentrydialog
--- Variable
--- Whether to display the new tasks in the OmniFocus quick-entry dialog before adding them. Defaults to `true` (set to `false` to send directly to the Inbox, without prompting)
obj.quickentrydialog = true

--- SendToOmniFocus.actions
--- Variable
--- Table containing application handlers for sending the current item to OmniFocus.
---
--- Notes:
---  * Each entry's key is the application name, and its value is another table with the following keys:
---   * `itemname` - how to name the current item in the context of the application. Purely for cosmetic purposes in the notifications (e.g. in Mail, the notification says "filing message" instead of "filing item". Defaults to "item".
---   * One of the following, invoked to do the actual filing:
---     * `as_scriptfile` - path of a file containing AppleScript code. It will be executed using the `osascript` command. If `quickentrydialog` is set to `false`, the string `nodialog` will be passed as argument to the script.
---     * `as_script` - string containing AppleScript code. There is no way to pass an argument to the script via this method.
---     * `fn` - a function. It will be passed a boolean indicating the value of `quickentrydialog`.
---     * `apptype` - a predefined "application type" to trigger different behavior for application families. The only valid value at the moment is "chromeapp", which can be used for any Chrome-based applications, including Google Chrome itself and, for example, any site-specific browsers generated using [Epichrome](https://github.com/dmarmor/epichrome).
---  * The built-in handlers for Outlook, Evernote, Chrome and Mail are implemented by scripts bundled with the SendToOmniFocus spoon.
---  * New handlers can be registered using `SendToOmniFocus:registerApplication()`
---  * Default value:
--- ```
---   {
---      ["Microsoft Outlook"] = {
---         as_scriptfile = _resource_path("scripts/outlook-to-omnifocus.applescript"),
---         itemname = "message"
---      },
---      Evernote = {
---         as_scriptfile = _resource_path("scripts/evernote-to-omnifocus.applescript"),
---         itemname = "note"
---      },
---      ["Google Chrome"] = {
---         apptype = "chromeapp",
---         itemname = "tab"
---      },
---      Mail = {
---         as_scriptfile = _resource_path("scripts/mail-to-omnifocus.applescript"),
---         itemname = "message"
---      }
---   }
--- ```
obj.actions = {
   ["Microsoft Outlook"] = {
      as_scriptfile = _resource_path("scripts/outlook-to-omnifocus.applescript"),
      itemname = "message"
   },
   Evernote = {
      as_scriptfile = _resource_path("scripts/evernote-to-omnifocus.applescript"),
      itemname = "note"
   },
   ["Google Chrome"] = {
      apptype = "chromeapp",
      itemname = "tab"
   },
   Mail = {
      as_scriptfile = _resource_path("scripts/mail-to-omnifocus.applescript"),
      itemname = "message"
   }
}

-- --------------------------------------------------------------------

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

--- SendToOmniFocus:sendCurrentItem
--- Method
--- Send current item in current application to OmniFocus by triggering the appropriate handler.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The SendToOmniFocus object
function obj:sendCurrentItem()
   local curapp = hs.application.frontmostApplication()
   local appname = curapp:name()
   self.logger.df("appname = %s", appname)
   local action = self.actions[appname]
   if action ~= nil then
      local itemname = (action.itemname or "item")
      if (not (action.as_scriptfile or action.as_script or action.fn or action.apptype)) then
         self.logger.ef("Action for " .. appname .. " exists, but it doesn't have an action attribute (as_scriptfile/as_script/fn/apptype) configured!")
      else
         if self.notifications then
            hs.notify.show("Hammerspoon", "", "Creating OmniFocus inbox item based on the current " .. itemname)
         end
         local as_script = nil
         if action.apptype == "chromeapp" then
            local data = {
               quickentry_open = (self.quickentrydialog and "tell quick entry" or ""),
               quickentry_close = (self.quickentrydialog and "open\n  end tell" or ""),
               app = appname,
               item = itemname,
            }
            local template_file = _resource_path("scripts/chrome-to-omnifocus.tpl")
            local text=slurp(template_file)
            as_script = interp(text, data)
            self.logger.df("action.as_script=%s", action.as_script)
         elseif action.as_script ~= nil then
            as_script = action.as_script
         end
         if action.as_scriptfile ~= nil then
            local cmd = "/usr/bin/osascript '" .. action.as_scriptfile .. "'" .. (self.quickentrydialog and "" or " nodialog")
            self.logger.df("Executing command %s", cmd)
            os.execute(cmd)
         elseif as_script ~= nil then
            self.logger.df("Executing AppleScript code:\n%s", as_script)
            hs.osascript.applescript(as_script)
         elseif action.fn ~= nil then
            self.logger.df("Calling function %s", action.fn)
            hs.fnutils.partial(action.fn, self.quickentrydialog)
         end
      end
   else
      hs.notify.show("Hammerspoon", "", "I don't know how to file to Omnifocus from " .. appname)
   end
   return self
end

--- SendToOmniFocus:registerApplication(app, handlerSpec)
--- Method
--- Register a new application handler
---
--- Parameters:
---  * app - application name
---  * handlerSpec - a handler definition in the format of `SendToOmniFocus.actions`, or `nil` to unregister the application.
function obj:registerApplication(app, handlerSpec)
   self.actions[app] = handlerSpec
end

--- SendToOmniFocus:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for SendToOmniFocus
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * send_to_omnifocus - file current item to OmniFocus.
function obj:bindHotkeys(mapping)
   self:bindHotkeysToSpec(
      { send_to_omnifocus = hs.fnutils.partial(self.sendCurrentItem, self) },
      mapping)
end

function obj:init()
   self._keys = {}
end

return obj
