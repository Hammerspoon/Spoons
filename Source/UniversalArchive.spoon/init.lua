--- === UniversalArchive ===
---
--- Handle "archive current item" for multiple applications using the same hotkey
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/UniversalArchive.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/UniversalArchive.spoon.zip)
---
--- Using this Spoon enables you to use a single hotkey to archive an
--- item in multiple applications.  Out of the box the following
--- applications are supported: Evernote, Mail, Spark and Outlook. You
--- can easily register handlers for new applications (or override the
--- built-in ones) using the `registerApplication()` method. If you
--- write a new handler and feel others could benefit from it, please
--- submit a pull request!
---
--- Handlers can also provide support for archiving to multiple
--- locations, and you can bind different hotkeys for each
--- destination. At the moment only Evernote supports this. See the
--- documentation for `bindHotkeys()` for the details on how to
--- specify multiple-destination filing hotkeys.

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

--- UniversalArchive.evernote_delay_before_typing
--- Variable
--- In Evernote, archive is done by selectin "Move note" and then
--- simulating typing of the notebook name. A short pause in between
--- makes it more reliable for Evernote to recognize the notebook name
--- correctly. This variable controls how much to wait, in seconds.
--- Do not change this unless you know what you are doing
obj.evernote_delay_before_typing = 0.2

--- UniversalArchive:evernoteArchive(where)
--- Method
--- Archive current note in Evernote.
---
--- Parameters:
---  * where - destination notebook. Defaults to the value of `UniversalArchive.evernote_archive_notebook`.
function obj:evernoteArchive(where)
  local ev = hs.appfinder.appFromName("Evernote")
  -- Archiving Evernote notes
  if (ev:selectMenuItem({"Note", "Move To Notebook…"}) or ev:selectMenuItem({"Note", "Move to Notebook…"}) or ev:selectMenuItem({"Note", "Move Note to…"})) then
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
   return self
end

--- UniversalArchive:mailArchive()
--- Method
--- Archive current message in Mail using the built-in Archive functionality
---
--- Parameters:
---  * none
function obj:mailArchive()
   local mail = hs.appfinder.appFromName("Mail")
   if mail:selectMenuItem({"Message", "Archive"}) then
      if self.archive_notifications then
         hs.notify.show("Mail", "", "Archiving message")
      end
   else
      hs.notify.show("Hammerspoon", "", "Something went wrong, couldn't find Mail's menu item for archiving")
   end
   return self
end

--- UniversalArchive:sparkArchive()
--- Method
--- Archive current message in Spark using the built-in Archive functionality
---
--- Parameters:
---  * none
function obj:sparkArchive()
   local spark = hs.appfinder.appFromName("Spark")
   if spark:selectMenuItem({"Message", "Archive"}) then
      if self.archive_notifications then
         hs.notify.show("Spark", "", "Archiving message")
      end
   else
      hs.notify.show("Hammerspoon", "", "Something went wrong, couldn't find Spark's menu item for archiving")
   end
   return self
end

--- UniversalArchive:outlookArchive()
--- Method
--- Archive current message in Outlook to the folder specified in
--- `UniversalArchive.outlook_archive_folder`. The folder has to
--- appear in the Message -> Move submenu for this to work. Since this
--- submenu only lists the last few destination folders, you have to
--- move a message by hand the first time (or periodically if you
--- don't archive very often).
---
--- Parameters:
---  * none
function obj:outlookArchive()
   local outlook = hs.appfinder.appFromName("Microsoft Outlook")
   if outlook:selectMenuItem({"Message", "Move", self.outlook_archive_folder}) then
      if self.archive_notifications then
         hs.notify.show("Outlook", "", "Archiving message")
      end
   else
      hs.notify.show("Hammerspoon", "", "Something went wrong, couldn't find Outlook's menu item for archiving")
   end
   return self
end

--- UniversalArchive:universalArchive(where)
--- Method
--- Main entry point for archiving an item. If a handler function is
--- defined for the current application, it is called with the
--- `UniversalArchive` object as its first argument, and the archive
--- destination (if provided) as the second. Handlers must have a
--- "default destination" that gets used when no destination is
--- provided. Not all handlers support specifying a destination. New
--- handlers can be registered using the `registerApplication()`
--- method.
function obj:universalArchive(where)
   local app = hs.application.frontmostApplication()
   if app ~= nil then
      local appname = app:name()
      if self.archive_functions[appname] ~= nil then
         self.archive_functions[appname](self, where)
      else
         hs.notify.show("Hammerspoon", "", "I don't know how to archive in " .. appname)
      end
   end
   return self
end

--- UniversalArchive:registerApplication(appname, fn)
--- Method
--- Register a handler function for an application.
---
--- Parameters:
---  * appname - string containing the name of the application. If the application already has a handler, it will be replaced with the new one.
---  * fn - handler function (to remove the handler for an application, use `nil`). The function receives the following arguments:
---    * self - the UniversalArchive object, so the handler can make use of all the object methods and variables.
---    * where - optional "destination" for the archive operation. Handlers must provide a default destination when `where == nil`. Destination doesn't make sense for all applications, so the implementation of this is optional and depending on the handler.
function obj:registerApplication(appname, fn)
   if appname then
      self.archive_functions[appname] = fn
      self.logger.f("Registered handler for application '%s'", appname)
   end
   return self
end

--- UniversalArchive:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for UniversalArchive
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * `archive` - hotkey for trigger the `universalArchive()` method, to archive the current item on the current application.
---   * `<app>_<dest>` - if an application handler supports multiple destinations, you can specify hotkeys for specific destinations using this format. For example, to assign a hotkey that files the current note in Evernote to the "MyProject" notebook using Ctrl-Alt-Cmd-M, you would specify `Evernote_MyProject = { { "ctrl", "alt", "cmd" }, "m" }` as one of the elements of `mapping`. Keep in mind that the application name must appear exactly as the system sees it (including upper/lowercase), and that if either the application or the destination name contain spaces or other non-alphanumeric characters, you need to use the Lua table notation. For example: `["Evernote_Some Long Notebook Name"] = { keybinding }`. At the moment only the Evernote handler supports multiple destinations.
function obj:bindHotkeys(mapping)
   -- Set up the universal hotkey
   if mapping.archive then
      if self._keys.archive then
         self._keys.archive:delete()
      end
      self._keys.archive = hs.hotkey.bindSpec(mapping.archive, function() self:universalArchive() end)
   end
   -- Set up app-specific hotkeys for specific destinations
   for app, fn in pairs(self.archive_functions) do
      for a,k in pairs(mapping) do
         local _,_,dest = string.find(a, "^" .. app .. "_(.+)")
         if dest ~= nil then
            if self._keys[a] then
               self._keys[a]:delete()
            end
            self._keys[a] = hs.hotkey.bindSpec(k, function() fn(self,dest) end)
         end
      end
   end
end

function obj:init()
   self._keys = {}
   self.archive_functions = {
      Evernote = obj.evernoteArchive,
      Mail     = obj.mailArchive,
      Spark    = obj.sparkArchive,
      ["Microsoft Outlook"] = obj.outlookArchive,
   }
end

return obj
