--- === EvernoteOpenAndTagHotkeys ===
---
--- Add some missing hotkeys for opening a note in Evernote, and for common tag sets
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/EvernoteOpenAndTagHotkeys.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/EvernoteOpenAndTagHotkeys.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "EvernoteOpenAndTagHotkeys"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- EvernoteOpenAndTagHotkeys.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('EvernoteOpenAndTagHotkeys')

function obj:evernoteIsFrontmost()
   local ev = hs.appfinder.appFromName("Evernote")
   return(ev ~= nil and ev:isFrontmost())
end

-- Applescript from https://discussion.evernote.com/topic/85685-feature-request-open-note-in-separate-window-keyboard-shortcut/#comment-366797
function obj:openCurrentNoteInWindow()
   if self:evernoteIsFrontmost() then
      hs.osascript.applescript([[tell application "Evernote"
	set _sel to selection -- Gets the Note(s) Selected in Evernote
	if _sel ≠ {} then
                repeat with aNote in _sel
		    open note window with aNote
                end repeat
	end if
end tell]])
   end   
end

function obj:tagCurrentNote(tags)
   hs.eventtap.keyStroke({"cmd"}, "'")
   hs.eventtap.keyStroke({"cmd"}, "a")
   hs.eventtap.keyStroke({}, "delete")
   for i,t in ipairs(tags) do
      self.logger.df("tagging %s", t)
      hs.eventtap.keyStrokes(t .. "\n")
   end
end

function obj:openAndTagCurrentNote(tags)
   if self:evernoteIsFrontmost() then
      self:openCurrentNoteInWindow()
      self:tagCurrentNote(tags)
   end
end

function obj:inlineTagCurrentNote(tags)
   if self:evernoteIsFrontmost() then
      self:tagCurrentNote(tags)
      hs.eventtap.keyStrokes("\n")
   end
end

-- Simple string split - based on http://lua-users.org/wiki/SplitJoin
function _split(str, sep)
   local fields={};
   local pattern = string.format("([^%s]+)", sep);
   str:gsub(pattern, function(c) table.insert(fields,c) end);
   return fields
end

--- EvernoteOpenAndTagHotkeys:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for EvernoteOpenAndTagHotkeys
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * hello - Say Hello
function obj:bindHotkeys(mapping)
   local ops = { open_and_tag = hs.fnutils.partial(self.openAndTagCurrentNote, self),
                 tag = hs.fnutils.partial(self.tagCurrentNote, self) }
   local def = { open_note = hs.fnutils.partial(self.openCurrentNoteInWindow, self) }
   -- Build up 'def' dynamically based on the keys provided in 'mapping'
   for action,key in pairs(mapping) do
      if action ~= 'open_note' then
         local op,tagstr = string.match(action, "(.+)-(.+)")
         if ops[op] then
            local tags = _split(tagstr, ",")
            if #tags > 0 then
               def[action] = hs.fnutils.partial(ops[op], tags)
            else
               self.logger.ef("No tags found in key '%s', please check.", action)
            end
         else
            self.logger.ef("Invalid hotkey keyword '%s' - valid ones are 'open_and_tag' and 'tag'", op)
         end
      end
   end
   hs.spoons.bindHotkeysToSpec(def, mapping)
end

return obj
