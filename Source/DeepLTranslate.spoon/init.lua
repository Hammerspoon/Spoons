--- === DeepLTranslate ===
---
--- Show a popup window with the translation of the currently selected text
---
--- The spoon uses the https://www.deepl.com translator page
--- The selected text is copied into the source field.  
--- The modal hotkey cmd+alt+ctrl+O replaces the selected text with the translation
---
--- Supported language codes are listed at https://www.deepl.com/translator
---
--- This is just an adaption of the Spoon PopupTranslateSelection written by Diego Zamboni
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/DeepLTranslate.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/DeepLTranslate.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "DeepLTranslate"
obj.version = "0.1"
obj.author = "Alfred Schilken <alfred@schilken.de>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- User-configurable variables

--- DeepLTranslate.popup_size
--- Variable
--- `hs.geometry` object representing the size to use for the translation popup window. Defaults to `hs.geometry.size(770, 610)`.
obj.popup_size = hs.geometry.size(770, 610)

--- DeepLTranslate.popup_style
--- Variable
--- Value representing the window style to be used for the translation popup window. This value needs to be a valid argument to [`hs.webview.setStyle()`](http://www.hammerspoon.org/docs/hs.webview.html#windowStyle) (i.e. a combination of values from [`hs.webview.windowMasks`](http://www.hammerspoon.org/docs/hs.webview.html#windowMasks[]). Default value: `hs.webview.windowMasks.utility|hs.webview.windowMasks.HUD|hs.webview.windowMasks.titled|hs.webview.windowMasks.closable`
obj.popup_style = hs.webview.windowMasks.utility|hs.webview.windowMasks.HUD|hs.webview.windowMasks.titled|hs.webview.windowMasks.closable

--- DeepLTranslate.popup_close_on_escape
--- Variable
--- If true, pressing ESC on the popup window will close it. Defaults to `true`
obj.popup_close_on_escape = true

--- DeepLTranslate.popup_close_after_copy
--- Variable
--- If true, the popup window will close after translated text is copied to pasteboard. Defaults to `true`
obj.popup_close_after_copy = false


--- DeepLTranslate.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('DeepLTranslate')

----------------------------------------------------------------------

function obj:modalOKCallback()
   -- print("modalCallback")
   hs.eventtap.keyStroke({"cmd"}, "a")
   hs.eventtap.keyStroke({"cmd"}, "c")
   hs.eventtap.keyStroke({"cmd"}, "w")
   self.modal_keys:exit()

   if self.prevFocusedWindow ~= nil then
      hs.timer.doAfter(1, function() 
        self.prevFocusedWindow:focus()
        hs.timer.doAfter(0.5, function() hs.eventtap.keyStroke({"cmd"}, "v") end)
      end)
   end
end

-- Internal variable - the hs.webview object for the popup
obj.webview = nil

--- DeepLTranslate:translatePopup(text)
--- Method
--- Display a translation popup with the translation of the given text
---
--- Parameters:
---  * text - string containing the text to translate
---
--- Returns:
---  * The DeepLTranslate object
function obj:translatePopup(text)
   local url = "https://www.deepl.com/translator"

   self.modal_keys = hs.hotkey.modal.new()
   self.modal_keys:bind({"cmd", "alt", "ctrl"}, "O", 
                              hs.fnutils.partial(self.modalOKCallback, self))
   self.modal_keys:enter()
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
   hs.timer.doAfter(1, function() 
         hs.eventtap.keyStroke({"cmd"}, "v")
      end)
   hs.timer.doAfter(1.5, function() 
         hs.eventtap.keyStroke({}, "tab")
      end)

--[[   hs.timer.doAfter(5, function() 
         hs.eventtap.keyStroke({"cmd"}, "a")
         hs.eventtap.keyStroke({"cmd"}, "c")
         if self.popup_close_after_copy then
            hs.eventtap.keyStroke({"cmd"}, "w")
         end
      end)
--]]
   return self
end

--- DeepLTranslate:translatePopup(text)
--- Method
--- Display a translation popup with the translation of the given text
---
--- Parameters:
---  * text - string containing the text to translate
---
--- Returns:
---  * The DeepLTranslate object
function obj:rephrasePopup(text)
   local url = "https://www.deepl.com/translator"

   self.modal_keys = hs.hotkey.modal.new()
   self.modal_keys:bind({"cmd", "alt", "ctrl"}, "O", 
                              hs.fnutils.partial(self.modalOKCallback, self))
   self.modal_keys:enter()
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
   hs.timer.doAfter(1, function() 
         hs.eventtap.keyStroke({"cmd"}, "v")
      end)
   hs.timer.doAfter(1.5, function() 
         hs.eventtap.keyStroke({}, "tab")
         hs.timer.doAfter(1.5, function() 
            hs.eventtap.keyStroke({"cmd"}, "a")
            hs.timer.doAfter(0.5, function() 
               hs.eventtap.keyStroke({"cmd"}, "c")
               hs.timer.usleep(100000)
               hs.eventtap.keyStroke({"shift"}, "tab")
               hs.timer.doAfter(1.0, function() 
                  hs.eventtap.keyStroke({"cmd"}, "a")
                  hs.eventtap.keyStroke({"cmd"}, "v")
                  hs.timer.doAfter(1.0, function() 
                     hs.eventtap.keyStroke({}, "tab")
                     end)
                  end)

                end)
            end)

          end)


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
   else
      print("sel:" .. sel)   
   end
   return (sel or "")
end

--- DeepLTranslate:translateSelectionPopup()
--- Method
--- Get the current selected text in the frontmost window and display a translation popup with the translation between the specified languages
---
--- Returns:
---  * The DeepLTranslate object
function obj:translateSelectionPopup()
   self.prevFocusedWindow = hs.window.focusedWindow()
   local text=current_selection()
   return self:translatePopup(text)
end

function obj:rephraseSelectionPopup()
   self.prevFocusedWindow = hs.window.focusedWindow()
   local text=current_selection()
   return self:rephrasePopup(text)
end

--- DeepLTranslate:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for DeepLTranslate
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * `translate` - translate the selected text without specifying source/destination languages (source defaults to auto-detect, destination defaults to your last choice or to English)
---
--- Sample value for `mapping`:
--- ```
---  {
---     translate = { { "ctrl", "alt", "cmd" }, "E" },
---  }
--- ```
function obj:bindHotkeys(mapping)
   local def = {}
   for action,key in pairs(mapping) do
      if action == "translate" then
         def.translate = hs.fnutils.partial(self.translateSelectionPopup, self)
      elseif action == "rephrase" then
         def.rephrase = hs.fnutils.partial(self.rephraseSelectionPopup, self)
      else 
         self.logger.ef("Invalid hotkey action '%s'", action)
      end
   end
   hs.spoons.bindHotkeysToSpec(def, mapping)
   obj.mapping = mapping
end

return obj
