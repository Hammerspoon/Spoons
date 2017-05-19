--- === TextClipboardHistory ===
---
--- Keep a history of the clipboard, only for text entries.
--- Originally based on https://github.com/VFS/.hammerspoon/blob/master/tools/clipboard.lua.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/TextClipboardHistory.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/TextClipboardHistory.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "TextClipboardHistory"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- TextClipboardHistory.frequency
--- Variable
--- Speed in seconds to check for clipboard changes. If you check too frequently, you will degrade performance, if you check sparsely you will loose copies. Defaults to 0.8.
obj.frequency = 0.8

--- TextClipboardHistory.hist_size
--- Variable
--- How many items to keep on history. Defaults to 100
obj.hist_size = 100

--- TextClipboardHistory.honor_clearcontent
--- Variable
--- If any application (i.e. a password manager) clears the pasteboard, we also remove it from the history. Defaults to `true`
obj.honor_clearcontent = true

--- TextClipboardHistory.paste_on_select
--- Variable
--- Whether to auto-type the item when selecting it from the menu. Can be toggled on the fly from the chooser. Defaults to `false`.
obj.paste_on_select = false

--- TextClipboardHistory.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('TextClipboardHistory')

----------------------------------------------------------------------

-- Internal variable - Chooser/menu object
obj.selectorobj = nil
-- Internal variable - Cache for focused window to work around the current window losing focus after the chooser comes up
obj.prevFocusedWindow = nil

local pasteboard = require("hs.pasteboard") -- http://www.hammerspoon.org/docs/hs.pasteboard.html
local settings = require("hs.settings") -- http://www.hammerspoon.org/docs/hs.settings.html

-- Keep track of last change counter
local last_change = nil;
-- Array to store the clipboard history
local clipboard_history = nil

-- Internal function - persist the current history so it survives across restarts
function _persistHistory()
   settings.set("TextClipboardHistory.items",clipboard_history)
end

--- TextClipboardHistory.togglePasteOnSelect()
--- Method
--- Toggle the value of `TextClipboardHistory.paste_on_select`
function obj:togglePasteOnSelect()
         self.paste_on_select = not self.paste_on_select
         hs.notify.show("TextClipboardHistory", "Paste-on-select is now " .. (self.paste_on_select and "enabled" or "disabled"), "")
end

-- Internal method - process the selected item from the chooser. An item may invoke special actions, defined in the `actions` variable.
function obj:_processSelectedItem(value)
   local actions = {
      none = function() end,
      clear = hs.fnutils.partial(self.clearAll, self),
      toggle_paste_on_select  = hs.fnutils.partial(self.togglePasteOnSelect, self),
   }
   if self.prevFocusedWindow ~= nil then
      self.prevFocusedWindow:focus()
   end
   if value and type(value) == "table" then
      if value.action and actions[value.action] then
         actions[value.action](value)
      elseif value.text then
         pasteboard.setContents(value.text)
         if (self.paste_on_select) then
            hs.eventtap.keyStroke({"cmd"}, "v")
         end
      end
      last_change = pasteboard.changeCount()
   end
end

--- TextClipboardHistory.clearAll()
--- Method
--- Clears the clipboard and history
function obj:clearAll()
   pasteboard.clearContents()
   clipboard_history = {}
   _persistHistory()
   last_change = pasteboard.changeCount()
end

--- TextClipboardHistory.clearLastItem()
--- Method
--- Clears the last added to the history
function obj:clearLastItem()
   table.remove(clipboard_history, 1)
   _persistHistory()
   last_change = pasteboard.changeCount()
end

--- TextClipboardHistory.pasteboardToClipboard(item)
--- Method
--- Add the current contents of the pasteboard to the history
function obj:pasteboardToClipboard(item)
   table.insert(clipboard_history, 1, item)
   clipboard_history = table.move(clipboard_history, 1, self.hist_size, 1, {})
   _persistHistory() -- updates the saved history
end

-- Internal function - fill in the chooser options, including the control options
function obj:_populateChooser()
   menuData = {}
   for k,v in pairs(clipboard_history) do
      if (type(v) == "string") then
         table.insert(menuData, {text=v, subText=""})
      end
   end
   if #menuData == 0 then
      table.insert(menuData, { text="",
                               subText="《Clipboard is empty》",
                               action = 'none',
                               image = hs.image.imageFromName('NSCaution')})
   else
      table.insert(menuData, { text="《Clear Clipboard History》",
                               action = 'clear',
                               image = hs.image.imageFromName('NSTrashFull') })
   end
   table.insert(menuData, {
                   text="《" .. (self.paste_on_select and "Disable" or "Enable") .. " Paste-on-select》",
                   action = 'toggle_paste_on_select',
                   image = (self.paste_on_select and hs.image.imageFromName('NSSwitchEnabledOn') or hs.image.imageFromName('NSSwitchEnabledOff'))
   })
   self.logger.df("Returning menuData = %s", hs.inspect(menuData))
   return menuData
end

--- TextClipboardHistory:checkAndStorePasteboard()
--- Method
--- If the pasteboard has changed, we add the current item to our history and update the counter
function obj:checkAndStorePasteboard()
   now = pasteboard.changeCount()
   if (now > last_change) then
      current_clipboard = pasteboard.getContents()
      self.logger.df("current_clipboard = %s", tostring(current_clipboard))
      if (current_clipboard == nil) and (pasteboard.getImageContents ~= nil) then
         self.logger.df("Ignoring image contents in clipboard")
      elseif (current_clipboard == nil and self.honor_clearcontent) then
         self.logger.df("Clearing last clipboard item at application request")
         self:clearLastItem()
      else
         self.logger.df("Adding %s to clipboard history", current_clipboard)
         self:pasteboardToClipboard(current_clipboard)
      end
      last_change = now
   end
end

--- TextClipboardHistory:start()
--- Method
--- Start the clipboard history collector
function obj:start()
   clipboard_history = settings.get("TextClipboardHistory.items") or {} -- If no history is saved on the system, create an empty history
   last_change = pasteboard.changeCount() -- keeps track of how many times the pasteboard owner has changed // Indicates a new copy has been made
   self.selectorobj = hs.chooser.new(hs.fnutils.partial(self._processSelectedItem, self))
   self.selectorobj:choices(hs.fnutils.partial(self._populateChooser, self))

   --Checks for changes on the pasteboard. Is it possible to replace with eventtap?
   timer = hs.timer.new(self.frequency, hs.fnutils.partial(self.checkAndStorePasteboard, self))
   timer:start()
end

--- TextClipboardHistory:showClipboard()
--- Method
--- Display the current clipboard list in a chooser
function obj:showClipboard()
   if self.selectorobj ~= nil then
      self.selectorobj:refreshChoicesCallback()
      self.prevFocusedWindow = hs.window.focusedWindow()
      self.selectorobj:show()
   else
      hs.notify.show("TextClipboardHistory not properly initialized", "Did you call TextClipboardHistory:start()?", "")
   end
end

--- TextClipboardHistory:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for TextClipboardHistory
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * show_clipboard - Display the clipboard history chooser
function obj:bindHotkeys(mapping)
   local def = {show_clipboard = hs.fnutils.partial(self.showClipboard, self) }
   hs.spoons.bindHotkeysToSpec(def, mapping)
end

return obj

