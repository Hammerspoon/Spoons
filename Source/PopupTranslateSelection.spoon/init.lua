--- === PopupTranslateSelection ===
---
--- Show a popup window with the translation of the currently selected (or other) text
---
--- Supported language codes are listed at https://cloud.google.com/translate/docs/languages
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/PopupTranslateSelection.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/PopupTranslateSelection.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "PopupTranslateSelection"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- User-configurable variables

--- PopupTranslateSelection.popup_size
--- Variable
--- `hs.geometry` object representing the size to use for the translation popup window. Defaults to `hs.geometry.size(770, 610)`.
obj.popup_size = hs.geometry.size(770, 610)

--- PopupTranslateSelection.popup_style
--- Variable
--- Value representing the window style to be used for the translation popup window. This value needs to be a valid argument to [`hs.webview.setStyle()`](http://www.hammerspoon.org/docs/hs.webview.html#windowStyle) (i.e. a combination of values from [`hs.webview.windowMasks`](http://www.hammerspoon.org/docs/hs.webview.html#windowMasks[]). Default value: `hs.webview.windowMasks.utility|hs.webview.windowMasks.HUD|hs.webview.windowMasks.titled|hs.webview.windowMasks.closable`
obj.popup_style = hs.webview.windowMasks.utility|hs.webview.windowMasks.HUD|hs.webview.windowMasks.titled|hs.webview.windowMasks.closable

--- PopupTranslateSelection.popup_close_on_escape
--- Variable
--- If true, pressing ESC on the popup window will close it. Defaults to `true`
obj.popup_close_on_escape = true

--- PopupTranslateSelection.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('PopupTranslateSelection')

----------------------------------------------------------------------

-- Internal variable - the hs.webview object for the popup
obj.webview = nil

--- PopupTranslateSelection:translatePopup(text, to, from)
--- Method
--- Display a translation popup with the translation of the given text between the specified languages
---
--- Parameters:
---  * text - string containing the text to translate
---  * to - two-letter code for destination language. If `nil`, Google Translate will use your most recent selection, or default to English
---  * from - two-letter code for source language. If `nil`, Google Translate will try to auto-detect it
---
--- Returns:
---  * The PopupTranslateSelection object
function obj:translatePopup(text, to, from)
   local query=hs.http.encodeForQuery(text)
   local url = "http://translate.google.com/translate_t?" ..
      (from and ("sl=" .. from .. "&") or "") ..
      (to and ("tl=" .. to .. "&") or "") ..
      "text=" .. query
   -- Persist the window between calls to reduce startup time on subsequent calls
   if self.webview == nil then
      local rect = hs.geometry.rect(0, 0, self.popup_size.w, self.popup_size.h)
      rect.center = hs.screen.mainScreen():frame().center
      self.webview=hs.webview.new(rect)
         :allowTextEntry(true)
         :windowStyle(self.popup_style)
         :closeOnEscape(self.popup_close_on_escape)
   end
   self.webview:url(url)
      :bringToFront()
      :show()
   self.webview:hswindow():focus()
   return self
end

-- Internal function to get the currently selected text.
-- It tries through hs.uielement, but if that fails it
-- tries issuing a Cmd-c and getting the pasteboard contents
-- afterwards.
function current_selection()
   local elem=hs.uielement.focusedElement()
   local sel=nil
   if elem then
      sel=elem:selectedText()
   end
   if (not sel) or (sel == "") then
      hs.eventtap.keyStroke({"cmd"}, "c")
      hs.timer.usleep(20000)
      sel=hs.pasteboard.getContents()
   end
   return (sel or "")
end

--- PopupTranslateSelection:translateSelectionPopup(to, from)
--- Method
--- Get the current selected text in the frontmost window and display a translation popup with the translation between the specified languages
---
--- Parameters:
---  * to - two-letter code for destination language. If `nil`, Google Translate will use your most recent selection, or default to English
---  * from - two-letter code for source language. If `nil`, Google Translate will try to auto-detect it
---
--- Returns:
---  * The PopupTranslateSelection object
function obj:translateSelectionPopup(to,from)
   local text=current_selection()
   return self:translatePopup(text,to,from)
end

--- PopupTranslateSelection:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for PopupTranslateSelection
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * `translate` - translate the selected text without specifying source/destination languages (source defaults to auto-detect, destination defaults to your last choice or to English)
---   * `translate_to_<lang>` - translate the selected text to the given destination language. Source language will be auto-detected.
---   * `translate_from_<lang>` - translate the selected text from the given destination language. Destination language will default to your last choice, or to English.
---   * `translate_<from>_<to>` - translate the selected text between the given languages.
---
--- Sample value for `mapping`:
--- ```
---  {
---     translate_to_en = { { "ctrl", "alt", "cmd" }, "e" },
---     translate_to_de = { { "ctrl", "alt", "cmd" }, "d" },
---     translate_to_es = { { "ctrl", "alt", "cmd" }, "s" },
---     translate_de_en = { { "shift", "ctrl", "alt", "cmd" }, "e" },
---     translate_en_de = { { "shift", "ctrl", "alt", "cmd" }, "d" },
---  }
--- ```
function obj:bindHotkeys(mapping)
   local def = {}
   for action,key in pairs(mapping) do
      if action == "translate" then
         def.translate = hs.fnutils.partial(self.translateSelectionPopup, self)
      elseif action:match("^translate[-_](.*)[-_](.*)$") then
         local from,to = nil,nil
         local l1,l2 = action:match("^translate[-_](.*)[-_](.*)$")
         if l1 == 'from' then
            -- "translate_from_<lang>"
            from=l2
         elseif l1 == 'to' then
            -- "translate_to_<lang>"
            to=l2
         else
            -- "translate_<from>_<to>"
            from,to = l1,l2
         end
         def[action] = hs.fnutils.partial(self.translateSelectionPopup, self, to, from)
      else
         self.logger.ef("Invalid hotkey action '%s'", action)
      end
   end
   hs.spoons.bindHotkeysToSpec(def, mapping)
end

return obj
