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

--- EvernoteOpenAndTagHotkeys:evernoteIsFrontmost()
--- Method
--- Returns `true` if Evernote is the frontmost application
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if Evernote is the frontmost application, `false` otherwise
function obj:evernoteIsFrontmost()
   local ev = hs.appfinder.appFromName("Evernote")
   return(ev ~= nil and ev:isFrontmost())
end

--- EvernoteOpenAndTagHotkeys:openCurrentNoteInWindow()
--- Method
--- Open the currently-selected Evernote notes new windows
--- Applescript from https://discussion.evernote.com/topic/85685-feature-request-open-note-in-separate-window-keyboard-shortcut/#comment-366797
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
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

--- EvernoteOpenAndTagHotkeys:tagCurrentNote(tags)
--- Method
--- Assigns tags to the currently-selected Evernote notes
---
--- Parameters:
---  * tags - a table containing a list of tags to apply. The tags must already exist in Evernote.
---
--- Returns:
---  * None
function obj:tagCurrentNote(tags)
   for i,t in ipairs(tags) do
      hs.osascript.applescript(string.format([[
        tell application "Evernote"
          set _sel to selection
          if _sel ≠ {} then
            repeat with aNote in _sel
              assign tag "%s" to aNote
            end repeat
          end if
        end tell]], t))
   end
end

--- EvernoteOpenAndTagHotkeys:openAndTagCurrentNote(tags)
--- Method
--- Open the current Evernote note in a new window and apply the given tags to it
---
--- Parameters:
---  * tags - a table containing a list of tags to apply. The tags must already exist in Evernote.
---
--- Returns:
---  * None
---
--- Notes:
---  * Even if multiple notes are selected, only the first one is tagged, as it will become the "current one" after it's opened in a new window
function obj:openAndTagCurrentNote(tags)
   if self:evernoteIsFrontmost() then
      self:openCurrentNoteInWindow()
      self:tagCurrentNote(tags)
   end
end

--- EvernoteOpenAndTagHotkeys:inlineTagCurrentNote(tags)
--- Method
--- Apply the given tags to the selected Evernote notes
---
--- Parameters:
---  * tags - a table containing a list of tags to apply. The tags must already exist in Evernote.
---
--- Returns:
---  * None
---
--- Notes:
---  * If multiple notes are selected, the tags are applied to all of them
function obj:inlineTagCurrentNote(tags)
   if self:evernoteIsFrontmost() then
      self:tagCurrentNote(tags)
      hs.eventtap.keyStrokes("\n")
   end
end

-- Internal function - Simple string split - based on http://lua-users.org/wiki/SplitJoin
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
---   * `open_note` - open the current note in a new window
---   * `open_and_tag-<tag1>,<tag2>..." - open the current note and apply all the comma-separated tags given. The tags must already exist in Evernote for the tagging to succeed.
---   * `tag-<tag1>,<tag2>..." - open the current note and apply all the comma-separated tags given. The tags must already exist in Evernote for the tagging to succeed.
function obj:bindHotkeys(mapping)
   local def = { open_note = hs.fnutils.partial(self.openCurrentNoteInWindow, self) }
   local ops = { open_and_tag = hs.fnutils.partial(self.openAndTagCurrentNote, self),
                 tag = hs.fnutils.partial(self.tagCurrentNote, self) }
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
