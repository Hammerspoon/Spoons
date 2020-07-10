--- === WindowScreenLeftAndRight ===
---
--- Move windows to other screens
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowScreenLeftAndRight.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowScreenLeftAndRight.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "WindowScreenLeftAndRight"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- WindowScreenLeftAndRight.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('WindowScreenLeftAndRight')

--- WindowScreenLeftAndRight.defaultHotkeys
--- Variable
--- Table containing a sample set of hotkeys that can be
--- assigned to the different operations. These are not bound
--- by default - if you want to use them you have to call:
--- `spoon.WindowScreenLeftAndRight:bindHotkeys(spoon.WindowScreenLeftAndRight.defaultHotkeys)`
--- after loading the spoon. Value:
--- ```
---  {
---     screen_left = { {"ctrl", "alt", "cmd"}, "Left" },
---     screen_right= { {"ctrl", "alt", "cmd"}, "Right" },
---  }
--- ```
obj.defaultHotkeys = {
   screen_left = { {"ctrl", "alt", "cmd"}, "Left" },
   screen_right= { {"ctrl", "alt", "cmd"}, "Right" },
}

--- WindowScreenLeftAndRight.animationDuration
--- Variable
--- Length of the animation to use for the window movements across the
--- screens. `nil` means to use the existing value from
--- `hs.window.animationDuration`. 0 means to disable the
--- animations. Default: `nil`.
obj.animationDuration = nil

-- Internal functions to store/restore the current value of setFrameCorrectness and animationDuration
local function _setFC()
  obj._savedFC = hs.window.setFrameCorrectness
  obj._savedDuration = hs.window.animationDuration
  hs.window.setFrameCorrectness = obj.use_frame_correctness
  if obj.animationDuration ~= nil then
    hs.window.animationDuration = obj.animationDuration
  end
end

local function _restoreFC()
  hs.window.setFrameCorrectness = obj._savedFC
  if obj.animationDuration ~= nil then
    hs.window.animationDuration = obj._savedDuration
  end
end

-- Move current window to a different screen
function obj.moveCurrentWindowToScreen(how)
   local win = hs.window.focusedWindow()
   if win == nil then
      return
   end
   _setFC()
   if how == "left" then
      win:moveOneScreenWest()
   elseif how == "right" then
      win:moveOneScreenEast()
   end
   _restoreFC()
end

-- --------------------------------------------------------------------
-- Shortcut functions for those above, for the hotkeys
-- --------------------------------------------------------------------

obj.oneScreenLeft  = hs.fnutils.partial(obj.moveCurrentWindowToScreen, "left")
obj.oneScreenRight = hs.fnutils.partial(obj.moveCurrentWindowToScreen, "right")

--- WindowScreenLeftAndRight:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for WindowScreenLeftAndRight
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * screen_left, screen_right - move the window to the left/right screen (if you have more than one monitor connected, does nothing otherwise)
function obj:bindHotkeys(mapping)
   local hotkeyDefinitions = {
      screen_left = self.oneScreenLeft,
      screen_right = self.oneScreenRight,
   }
   hs.spoons.bindHotkeysToSpec(hotkeyDefinitions, mapping)
   return self
end

return obj
