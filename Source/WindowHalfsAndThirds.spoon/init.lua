--- === WindowHalfsAndThirds ===
---
--- Simple window movement and resizing, focusing on half- and third-of-screen sizes
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowHalfsAndThirds.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowHalfsAndThirds.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "WindowHalfsAndThirds"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- WindowHalfsAndThirds.defaultHotkeys
--- Variable
--- Table containing a sample set of hotkeys that can be
--- assigned to the different operations. These are not bound
--- by default - if you want to use them you have to call:
--- `spoon.WindowHalfsAndThirds:bindHotkeys(spoon.WindowHalfsAndThirds.defaultHotkeys)`
--- after loading the spoon. Value:
--- ```
---  {
---     left_half   = { {"ctrl",        "cmd"}, "Left" },
---     right_half  = { {"ctrl",        "cmd"}, "Right" },
---     top_half    = { {"ctrl",        "cmd"}, "Up" },
---     bottom_half = { {"ctrl",        "cmd"}, "Down" },
---     third_left  = { {"ctrl", "alt"       }, "Left" },
---     third_right = { {"ctrl", "alt"       }, "Right" },
---     third_up    = { {"ctrl", "alt"       }, "Up" },
---     third_down  = { {"ctrl", "alt"       }, "Down" },
---     max_toggle  = { {"ctrl", "alt", "cmd"}, "f" },
---     max         = { {"ctrl", "alt", "cmd"}, "Up" },
---  }
--- ```
obj.defaultHotkeys = {
   left_half   = { {"ctrl",        "cmd"}, "Left" },
   right_half  = { {"ctrl",        "cmd"}, "Right" },
   top_half    = { {"ctrl",        "cmd"}, "Up" },
   bottom_half = { {"ctrl",        "cmd"}, "Down" },
   third_left  = { {"ctrl", "alt"       }, "Left" },
   third_right = { {"ctrl", "alt"       }, "Right" },
   third_up    = { {"ctrl", "alt"       }, "Up" },
   third_down  = { {"ctrl", "alt"       }, "Down" },
   max_toggle  = { {"ctrl", "alt", "cmd"}, "f" },
   max         = { {"ctrl", "alt", "cmd"}, "Up" },
}

--- WindowHalfsAndThirds.use_frame_correctness
--- Variable
--- If `true`, set [setFrameCorrectness](http://www.hammerspoon.org/docs/hs.window.html#setFrameCorrectness) for some resizing operations which fail when the window extends beyonds screen boundaries. This may cause some jerkiness in the resizing, so experiment and determine if you need it. Defaults to `false`
obj.use_frame_correctness = false

-- --------------------------------------------------------------------
-- Base window resizing and moving functions
-- --------------------------------------------------------------------

-- Internal functions to store/restore the current value of setFrameCorrectness.
function _setFC()
   obj._savedFC = hs.window.setFrameCorrectness
   hs.window.setFrameCorrectness = obj.use_frame_correctness
end

function _restoreFC()
   hs.window.setFrameCorrectness = obj._savedFC
end

-- Resize current window to different parts of the screen
-- If use_fc_preference is true, then use setFrameCorrectness according to the configured value of `WindowHalfsAndThirds.use_frame_correctness`
function obj.resizeCurrentWindow(how, use_fc_preference)
   local win = hs.window.focusedWindow()
   if win == nil then
      return
   end
   local app = win:application():name()
   local windowLayout
   local newrect

   if how == "left" then
      newrect = hs.layout.left50
   elseif how == "right" then
      newrect = hs.layout.right50
   elseif how == "top" then
      newrect = {0,0,1,0.5}
   elseif how == "bottom" then
      newrect = {0,0.5,1,0.5}
   elseif how == "max" then
      newrect = hs.layout.maximized
   elseif how == "left_third" or how == "hthird-0" then
      newrect = {0,0,1/3,1}
   elseif how == "middle_third_h" or how == "hthird-1" then
      newrect = {1/3,0,1/3,1}
   elseif how == "right_third" or how == "hthird-2" then
      newrect = {2/3,0,1/3,1}
   elseif how == "top_third" or how == "vthird-0" then
      newrect = {0,0,1,1/3}
   elseif how == "middle_third_v" or how == "vthird-1" then
      newrect = {0,1/3,1,1/3}
   elseif how == "bottom_third" or how == "vthird-2" then
      newrect = {0,2/3,1,1/3}
   end

   if use_fc_preference then _setFC() end
   win:move(newrect)
   if use_fc_preference then _restoreFC() end
end

-- Toggle current window between its normal size, and being maximized
function obj.toggleMaximized()
   local win = hs.window.focusedWindow()
   if (win == nil) or (win:id() == nil) then
      return
   end
   if obj._frameCache[win:id()] then
      win:setFrame(obj._frameCache[win:id()])
      obj._frameCache[win:id()] = nil
   else
      obj._frameCache[win:id()] = win:frame()
      win:maximize()
   end
end

-- Get the horizontal third of the screen in which a window is at the moment
function get_horizontal_third(win)
   if win == nil then
      return
   end
   local frame=win:frame()
   local screenframe=win:screen():frame()
   local relframe=hs.geometry(frame.x-screenframe.x, frame.y-screenframe.y, frame.w, frame.h)
   local third = math.floor(3.01*relframe.x/screenframe.w)
   omh.logger.df("Screen frame: %s", screenframe)
   omh.logger.df("Window frame: %s, relframe %s is in horizontal third #%d", frame, relframe, third)
   return third
end

-- Get the vertical third of the screen in which a window is at the moment
function get_vertical_third(win)
   if win == nil then
      return
   end
   local frame=win:frame()
   local screenframe=win:screen():frame()
   local relframe=hs.geometry(frame.x-screenframe.x, frame.y-screenframe.y, frame.w, frame.h)
   local third = math.floor(3.01*relframe.y/screenframe.h)
   omh.logger.df("Screen frame: %s", screenframe)
   omh.logger.df("Window frame: %s, relframe %s is in vertical third #%d", frame, relframe, third)
   return third
end

-- --------------------------------------------------------------------
-- Shortcut functions for those above, for the hotkeys
-- --------------------------------------------------------------------

obj.leftHalf       = hs.fnutils.partial(obj.resizeCurrentWindow, "left")
obj.rightHalf      = hs.fnutils.partial(obj.resizeCurrentWindow, "right")
obj.topHalf        = hs.fnutils.partial(obj.resizeCurrentWindow, "top")
obj.bottomHalf     = hs.fnutils.partial(obj.resizeCurrentWindow, "bottom")
obj.leftThird      = hs.fnutils.partial(obj.resizeCurrentWindow, "left_third")
obj.middleThirdH   = hs.fnutils.partial(obj.resizeCurrentWindow, "middle_third_h")
obj.rightThird     = hs.fnutils.partial(obj.resizeCurrentWindow, "right_third")
obj.topThird       = hs.fnutils.partial(obj.resizeCurrentWindow, "top_third")
obj.middleThirdV   = hs.fnutils.partial(obj.resizeCurrentWindow, "middle_third_v")
obj.bottomThird    = hs.fnutils.partial(obj.resizeCurrentWindow, "bottom_third")
obj.maximize       = hs.fnutils.partial(obj.resizeCurrentWindow, "max", true)

function obj.oneThirdLeft()
   local win = hs.window.focusedWindow()
   if win ~= nil then
      local third = get_horizontal_third(win)
      obj.resizeCurrentWindow("hthird-" .. math.max(third-1,0))
   end
end

function obj.oneThirdRight()
   local win = hs.window.focusedWindow()
   if win ~= nil then
      local third = get_horizontal_third(win)
      obj.resizeCurrentWindow("hthird-" .. math.min(third+1,2))
   end
end

function obj.oneThirdUp()
   local win = hs.window.focusedWindow()
   if win ~= nil then
      local third = get_vertical_third(win)
      obj.resizeCurrentWindow("vthird-" .. math.max(third-1,0))
   end
end

function obj.onethirdDown()
   local win = hs.window.focusedWindow()
   if win ~= nil then
      local third = get_vertical_third(win)
      obj.resizeCurrentWindow("vthird-" .. math.min(third+1,2))
   end
end

--- WindowHalfsAndThirds:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for WindowHalfsAndThirds
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * left_half, right_half, top_half, bottom_half - resize to the corresponding half of the screen
---   * third_left, third_right - resize to one horizontal-third of the screen and move left/right
---   * third_up, third_down - resize to one vertical-third of the screen and move up/down
---   * max - maximize the window
---   * max_toggle - toggle maximization
---   * screen_left, screen_right - move the window to the left/right screen (if you have more than one monitor connected, does nothing otherwise)
---   * top_third, middle_third_v, bottom_third - resize and move the window to the corresponding vertical third of the screen
---   * left_third, middle_third_h, right_third - resize and move the window to the corresponding horizontal third of the screen
function obj:bindHotkeys(mapping)
   local hotkeyDefinitions = {
      left_half = self.leftHalf,
      right_half = self.rightHalf,
      top_half = self.topHalf,
      bottom_half = self.bottomHalf,
      third_left = self.oneThirdLeft,
      third_right = self.oneThirdRight,
      third_up = self.oneThirdUp,
      third_down = self.onethirdDown,
      max_toggle = self.toggleMaximized,
      max = self.maximize,
      screen_left = self.oneScreenLeft,
      screen_right = self.oneScreenRight,
      top_third = self.topThird,
      middle_third_v = self.middleThirdV,
      bottom_third = self.bottomThird,
      left_third = self.leftThird,
      middle_third_h = self.middleThirdH,
      right_third = self.rightThird,
   }
   hs.spoons.bindHotkeysToSpec(hotkeyDefinitions, mapping)
   return self
end

function obj:init()
   -- Window cache for window maximize toggler
   self._frameCache = {}
end

return obj
