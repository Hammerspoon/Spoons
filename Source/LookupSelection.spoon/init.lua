--- === LookupSelection ===
---
--- Show a popup window with the currently selected word in lexicon, notes, online help
---
--- The spoon uses hs.urlevent.openURL("dict://" .. text) 
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/LookupSelection.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/LookupSelection.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "LookupSelection"
obj.version = "0.1"
obj.author = "Alfred Schilken <alfred@schilken.de>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- User-configurable variables
-- may used later --
-- LookupSelection.popup_size
-- Variable
-- `hs.geometry` object representing the size to use for the translation popup window. Defaults to `hs.geometry.size(770, 610)`.
--obj.popup_size = hs.geometry.size(770, 610)

-- LookupSelection.popup_style
-- Variable
-- Value representing the window style to be used for the translation popup window. This value needs to be a valid argument to [`hs.webview.setStyle()`](http://www.hammerspoon.org/docs/hs.webview.html#windowStyle) (i.e. a combination of values from [`hs.webview.windowMasks`](http://www.hammerspoon.org/docs/hs.webview.html#windowMasks[]). Default value: `hs.webview.windowMasks.utility|hs.webview.windowMasks.HUD|hs.webview.windowMasks.titled|hs.webview.windowMasks.closable`
--obj.popup_style = hs.webview.windowMasks.utility|hs.webview.windowMasks.HUD|hs.webview.windowMasks.titled|hs.webview.windowMasks.closable

-- LookupSelection.popup_close_on_escape
-- Variable
-- If true, pressing ESC on the popup window will close it. Defaults to `true`
--obj.popup_close_on_escape = true

-- LookupSelection.popup_close_after_copy
-- Variable
-- If true, the popup window will close after translated text is copied to pasteboard. Defaults to `true`
--obj.popup_close_after_copy = false


--- LookupSelection.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('LookupSelection')

----------------------------------------------------------------------

-- Internal function to get the currently selected text.
-- issues a Cmd-c and get the pasteboard contents
function current_selection()
   hs.eventtap.keyStroke({"cmd"}, "c")
   hs.timer.usleep(20000)
   sel=hs.pasteboard.getContents()
   return (sel or "")
end

--- LookupSelection:openLexicon()
--- Method
--- Get the current selected text in the frontmost window and display a translation popup with the translation between the specified languages
---
--- Returns:
---  * The LookupSelection object
function obj:openLexicon()
   local text=current_selection()
   hs.urlevent.openURL("dict://" .. text)
end


function obj:neue_notiz()
    local text=current_selection()
    hs.application.launchOrFocusByBundleID("com.apple.Notes")
    local notizenApp = hs.appfinder.appFromName("Notizen")
    notizenApp:selectMenuItem({"Ablage", "Neue Notiz"})
    hs.eventtap.keyStroke({"cmd"}, "v")
end

function obj:hsdocs()
    local text=current_selection()
    if #text < 2 then
      text = nil
    elseif not text:starts_with("hs.") then
      text = "hs." .. text
    end
    print("obj:hsdocs():|" .. tostring(text) .. "|")
    hs.doc.hsdocs.moduleEntitiesInSidebar(true)
    hs.doc.hsdocs.help(text)
end

--- LookupSelection:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for LookupSelection
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * `lexicon` - open in lexicon app
---   * `neue_notiz` -  create new note in notes app
---   * `hsdocs` -  display online help
---
--- Sample value for `mapping`:
--- ```
---  {
---     lexicon = { { "ctrl", "alt", "cmd" }, "L" },
---     neue_notiz = { { "ctrl", "alt", "cmd" }, "N" },
---     hsdocs = { { "ctrl", "alt", "cmd" }, "H" },
---  }
--- ```
function obj:bindHotkeys(mapping)
   local def = {}
   for action,key in pairs(mapping) do
      if action == "lexicon" then
         def.lexicon = hs.fnutils.partial(self.openLexicon, self)
      elseif action == "neue_notiz" then
         def.neue_notiz = hs.fnutils.partial(self.neue_notiz, self)
      elseif action == "hsdocs" then
         def.hsdocs = hs.fnutils.partial(self.hsdocs, self)
      else 
         self.logger.ef("Invalid hotkey action '%s'", action)
      end
   end
   hs.spoons.bindHotkeysToSpec(def, mapping)
   obj.mapping = mapping
end

return obj
