--- === UniversalArchive ===
---
--- Handle "archive current item" for multiple applications using the same hotkey
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/UniversalArchive.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/UniversalArchive.spoon.zip)
---
--- Currently Evernote, Mail.app and Outlook are supported.
--- For Evernote, also allows specifying other keybindings for
--- archiving directly to different notebooks.

local obj={}
obj.__index = obj

-- Metadata
obj.name = "UniversalArchive"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- UniversalArchive.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('UniversalArchive')

--- UniversalArchive.evernote_archive_notebook
--- Variable
--- Name of the Notebook to use for archiving in Evernote. Defaults to "Archive"
obj.evernote_archive_notebook = "Archive"

--- UniversalArchive.outlook_archive_folder
--- Variable
--- Name of the mailbox to use for archiving in Outlook. You must move a message manually to that mailbox at least once so that it appears in the "Message" -> "Move..." submenu. Defaults to "Archive"
obj.outlook_archive_folder = "Archive"

--- UniversalArchive.archive_notifications
--- Variable
--- Boolean indicating whether a notification should be produced when an item is archived. Defaults to "true".
obj.archive_notifications = true

-- Do not change this unless you know what you are doing
obj.evernote_delay_before_typing = 0.2

function obj:evernoteArchive(where)
   local ev = hs.appfinder.appFromName("Evernote")
   -- Archiving Evernote notes
   if ev:selectMenuItem({"Note", "Move To Notebook…"}) then
      local dest = where 
      if dest == nil then
         dest = self.evernote_archive_notebook
      end
      if self.archive_notifications then
         hs.notify.show("Evernote", "", "Archiving note to " .. dest)
      end
      hs.timer.doAfter(self.evernote_delay_before_typing, function() hs.eventtap.keyStrokes(dest .. "\n") end)
   else
      hs.notify.show("Hammerspoon", "", "Something went wrong, couldn't find Evernote's menu item for archiving")
   end
end

--- Archive current message in Mail.app
function obj:mailArchive()
   local mail = hs.appfinder.appFromName("Mail")
   if mail:selectMenuItem({"Message", "Archive"}) then
      if self.archive_notifications then
         hs.notify.show("Mail", "", "Archiving message")
      end
   else
      hs.notify.show("Hammerspoon", "", "Something went wrong, couldn't find Mail's menu item for archiving")
   end
end

--- Archive current message in Spark
function obj:sparkArchive()
   local spark = hs.appfinder.appFromName("Spark")
   if spark:selectMenuItem({"Message", "Archive"}) then
      if self.archive_notifications then
         hs.notify.show("Spark", "", "Archiving message")
      end
   else
      hs.notify.show("Hammerspoon", "", "Something went wrong, couldn't find Spark's menu item for archiving")
   end
end

--- Archive current message in Outlook
function obj:outlookArchive(where)
   local outlook = hs.appfinder.appFromName("Microsoft Outlook")
   if outlook:selectMenuItem({"Message", "Move", self.outlook_archive_folder}) then
      if self.archive_notifications then
         hs.notify.show("Outlook", "", "Archiving message")
      end
   else
      hs.notify.show("Hammerspoon", "", "Something went wrong, couldn't find Outlook's menu item for archiving")
   end
end

function obj:universalArchive(where)
   local ev = hs.appfinder.appFromName("Evernote")
   local mail = hs.appfinder.appFromName("Mail")
   local spark = hs.appfinder.appFromName("Spark")
   local outlook = hs.appfinder.appFromName("Microsoft Outlook")

   if ev ~= nil and ev:isFrontmost() then
      -- Archiving Evernote notes
      self:evernoteArchive(where)
   elseif mail ~= nil and mail:isFrontmost() then
      -- Archiving Mail messages
      self:mailArchive()
   elseif spark ~= nil and spark:isFrontmost() then
      -- Archiving Mail messages in Spark
      self:sparkArchive()
   elseif outlook ~= nil and outlook:isFrontmost() then
      -- Archiving Outlook messages
      self:outlookArchive()
   else
      hs.notify.show("Hammerspoon", "", "I don't know how to archive in " .. hs.application.frontmostApplication():name())
   end
end

--- WindowManipulation:bindHotkeysToSpec(def, map)
--- Method
--- Map a number of hotkeys according to a definition table
--- *** This function should be in a separate spoon or (preferably) in an hs.spoon module. I'm including it here for now to make the Spoon self-sufficient.
---
--- Parameters:
---  * def - table containing name-to-function definitions for the hotkeys supported by the Spoon. Each key is a hotkey name, and its value must be a function that will be called when the hotkey is invoked.
---  * map - table containing name-to-hotkey definitions, as supported by [bindHotkeys in the Spoon API](https://github.com/Hammerspoon/hammerspoon/blob/master/SPOONS.md#hotkeys). Not all the entries in `def` must be bound, but if any keys in `map` don't have a definition, an error will be produced.
function obj:bindHotkeysToSpec(def,map)
   for name,key in pairs(map) do
      if def[name] ~= nil then
         if self._keys[name] then
            self._keys[name]:delete()
         end
         self._keys[name]=hs.hotkey.bindSpec(key, def[name])
      else
         self.logger.ef("Error: Hotkey requested for undefined action '%s'", name)
      end
   end
   return self
end

--- UniversalArchive:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for UniversalArchive
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * hello - Say Hello
function obj:bindHotkeys(mapping)
   self:bindHotkeysToSpec({archive = function() self:universalArchive() end}, mapping)
   for a,k in pairs(mapping) do
      local _,_,notebook = string.find(a, "^evernote_(.+)")
      if notebook ~= nil then
         if self._keys[a] then
            self._keys[a]:delete()
         end
         self._keys[a] = hs.hotkey.bindSpec(k, function() self:evernoteArchive(notebook) end)
      end
   end
end

function obj:init()
   self._keys = {}
end

return obj
