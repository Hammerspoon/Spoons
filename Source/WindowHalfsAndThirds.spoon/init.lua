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

--- WindowHalfsAndThirds.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('WindowHalfsAndThirds')

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
---     top_left    = { {"ctrl",        "cmd"}, "1" },
---     top_right   = { {"ctrl",        "cmd"}, "2" },
---     bottom_left = { {"ctrl",        "cmd"}, "3" },
---     bottom_right= { {"ctrl",        "cmd"}, "4" },
---     max_toggle  = { {"ctrl", "alt", "cmd"}, "f" },
---     max         = { {"ctrl", "alt", "cmd"}, "Up" },
---     undo        = { {        "alt", "cmd"}, "z" },
---     center      = { {        "alt", "cmd"}, "c" },
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
   top_left    = { {"ctrl",        "cmd"}, "1" },
   top_right   = { {"ctrl",        "cmd"}, "2" },
   bottom_left = { {"ctrl",        "cmd"}, "3" },
   bottom_right= { {"ctrl",        "cmd"}, "4" },
   max_toggle  = { {"ctrl", "alt", "cmd"}, "f" },
   max         = { {"ctrl", "alt", "cmd"}, "Up" },
   undo        = { {        "alt", "cmd"}, "z" },
   center      = { {        "alt", "cmd"}, "c" },
}

--- WindowHalfsAndThirds.use_frame_correctness
--- Variable
--- If `true`, set [setFrameCorrectness](http://www.hammerspoon.org/docs/hs.window.html#setFrameCorrectness) for some resizing operations which fail when the window extends beyonds screen boundaries. This may cause some jerkiness in the resizing, so experiment and determine if you need it. Defaults to `false`
obj.use_frame_correctness = false

--- WindowHalfsAndThirds.clear_cache_after_seconds
--- Variable
--- We don't want our undo frame cache filling all available memory. Let's clear it after it hasn't been used for a while.
obj.clear_cache_after_seconds = 60*60

-- Private utility functions
local function round(x)
   return x + 0.5 - (x + 0.5) % 1
end
local function windowIsMaxmized(win)
   local ur, r = win:screen():toUnitRect(win:frame()), round
   return r(ur.x) == 0 and r(ur.y) == 0 and r(ur.w) == 1 and r(ur.h) == 1
end
local function cacheWindow(win)
   local win = win or hs.window.focusedWindow()
   if (win == nil) or (win:id() == nil) then
      return
   end
   obj._frameCache[win:id()] = win:frame()
   obj._frameCacheClearTimer:start()
end
local function restoreWindowFromCache(win)
   local win = win or hs.window.focusedWindow()
   if (not win) or (not win:id()) or (not obj._frameCache[win:id()]) then
      return
   end
   local old_cache = win:frame()
   win:setFrame(obj._frameCache[win:id()])
   obj._frameCache[win:id()] = old_cache
end

-- --------------------------------------------------------------------
-- Base window resizing and moving functions
-- --------------------------------------------------------------------

-- Internal functions to store/restore the current value of setFrameCorrectness.
local function _setFC()
   obj._savedFC = hs.window.setFrameCorrectness
   hs.window.setFrameCorrectness = obj.use_frame_correctness
end

local function _restoreFC()
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
   elseif how == "top_right" then
      newrect = {0.5,0,0.5,0.5}
   elseif how == "top_left" then
      newrect = {0,0,0.5,0.5}
   elseif how == "bottom_left" then
      newrect = {0,0.5,0.5,0.5}
   elseif how == "bottom_right" then
      newrect = {0.5,0.5,0.5,0.5}
   end

   if use_fc_preference then _setFC() end
   cacheWindow(win)
   win:move(newrect)
   if use_fc_preference then _restoreFC() end
end

-- Toggle current window between its normal size, and being maximized
function obj.toggleMaximized()
   local win = hs.window.focusedWindow()
   if (win == nil) or (win:id() == nil) then
      return
   end
   if windowIsMaxmized(win) then
      restoreWindowFromCache(win)
   else
      cacheWindow(win)
      win:maximize()
   end
end


-- Get the horizontal third of the screen in which a window is at the moment
local function get_horizontal_third(win)
   if win == nil then
      return
   end
   local frame=win:frame()
   local screenframe=win:screen():frame()
   local relframe=hs.geometry(frame.x-screenframe.x, frame.y-screenframe.y, frame.w, frame.h)
   local third = math.floor(3.01*relframe.x/screenframe.w)
   return third
end

-- Get the vertical third of the screen in which a window is at the moment
local function get_vertical_third(win)
   if win == nil then
      return
   end
   local frame=win:frame()
   local screenframe=win:screen():frame()
   local relframe=hs.geometry(frame.x-screenframe.x, frame.y-screenframe.y, frame.w, frame.h)
   local third = math.floor(3.01*relframe.y/screenframe.h)
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
obj.topLeft        = hs.fnutils.partial(obj.resizeCurrentWindow, "top_left")
obj.topRight       = hs.fnutils.partial(obj.resizeCurrentWindow, "top_right")
obj.bottomLeft     = hs.fnutils.partial(obj.resizeCurrentWindow, "bottom_left")
obj.bottomRight    = hs.fnutils.partial(obj.resizeCurrentWindow, "bottom_right")
obj.maximize       = hs.fnutils.partial(obj.resizeCurrentWindow, "max", true)

-- Undo window size changes if there've been any
function obj.undo() restoreWindowFromCache() end

-- Center window on screen
function obj.center()
   local win = hs.window.focusedWindow()
   if win then
      cacheWindow(win)
      win:centerOnScreen()
   end
end


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
---   * top_left, top_right, bottom_left, bottom_right - resize and move the window to the corresponding quarter of the screen
---   * undo - restore window to position before last move
---   * center - move window to center of screen
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
      top_third = self.topThird,
      middle_third_v = self.middleThirdV,
      bottom_third = self.bottomThird,
      left_third = self.leftThird,
      middle_third_h = self.middleThirdH,
      right_third = self.rightThird,
      top_left = self.topLeft,
      top_right = self.topRight,
      bottom_left = self.bottomLeft,
      bottom_right = self.bottomRight,
      undo = self.undo,
      center = self.center,
   }
   hs.spoons.bindHotkeysToSpec(hotkeyDefinitions, mapping)
   return self
end

function obj:init()
   -- Window cache for window maximize toggler
   self._frameCache = {}
   obj._frameCacheClearTimer = hs.timer.delayed.new(obj.clear_cache_after_seconds, function() obj._frameCache = {} end)
end

return obj

