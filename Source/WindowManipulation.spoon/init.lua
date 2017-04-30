--- === WindowManipulation ===
---
--- Window movement and resizing
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowManipulation.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowManipulation.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "WindowManipulation"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- WindowManipulation.defaultHotkeys
--- Variable
--- Table containing a sample set of hotkeys that can be
--- assigned to the different operations. These are not bound
--- by default - if you want to use them you have to call:
--- `spoon.WindowManipulation:bindHotkeys(spoon.WindowManipulation.defaultHotkeys)`
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
---     max_toggle  = { {"ctrl", "alt", "cmd"}, "F" },
---     max         = { {"ctrl", "alt", "cmd"}, "Up" },
---     screen_left = { {"ctrl", "alt", "cmd"}, "Left" },
---     screen_right= { {"ctrl", "alt", "cmd"}, "Right" },
---  }
obj.defaultHotkeys = {
   left_half   = { {"ctrl",        "cmd"}, "Left" },
   right_half  = { {"ctrl",        "cmd"}, "Right" },
   top_half    = { {"ctrl",        "cmd"}, "Up" },
   bottom_half = { {"ctrl",        "cmd"}, "Down" },
   third_left  = { {"ctrl", "alt"       }, "Left" },
   third_right = { {"ctrl", "alt"       }, "Right" },
   third_up    = { {"ctrl", "alt"       }, "Up" },
   third_down  = { {"ctrl", "alt"       }, "Down" },
   max_toggle  = { {"ctrl", "alt", "cmd"}, "F" },
   max         = { {"ctrl", "alt", "cmd"}, "Up" },
   screen_left = { {"ctrl", "alt", "cmd"}, "Left" },
   screen_right= { {"ctrl", "alt", "cmd"}, "Right" },
}

----------------------------------------------------------------------
--- Base window resizing and moving functions
----------------------------------------------------------------------

-- Resize current window to different parts of the screen
function obj.resizeCurrentWindow(how)
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

   win:move(newrect)
end

-- Move current window to a different screen
function obj.moveCurrentWindowToScreen(how)
   local win = hs.window.focusedWindow()
   if win == nil then
      return
   end
   hs.window.setFrameCorrectness = true
   if how == "left" then
      win:moveOneScreenWest()
   elseif how == "right" then
      win:moveOneScreenEast()
   end
   hs.window.setFrameCorrectness = false
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

----------------------------------------------------------------------
--- Shortcut functions for those above
----------------------------------------------------------------------

function obj.leftHalf()
   obj.resizeCurrentWindow("left")
end

function obj.rightHalf()
   obj.resizeCurrentWindow("right")
end

function obj.topHalf()
   obj.resizeCurrentWindow("top")
end

function obj.bottomHalf()
   obj.resizeCurrentWindow("bottom")
end

function obj.maximize()
   hs.window.setFrameCorrectness = true
   obj.resizeCurrentWindow("max")
   hs.window.setFrameCorrectness = false
end

function obj.oneThirdLeft()
   local win = hs.window.focusedWindow()
   if win == nil then
      return
   end
   local third = get_horizontal_third(win)
   obj.resizeCurrentWindow("hthird-" .. math.max(third-1,0))
end

function obj.oneThirdRight()
   local win = hs.window.focusedWindow()
   if win == nil then
      return
   end
   local third = get_horizontal_third(win)
   obj.resizeCurrentWindow("hthird-" .. math.min(third+1,2))
end

function obj.oneThirdUp()
   local win = hs.window.focusedWindow()
   if win == nil then
      return
   end
   local third = get_vertical_third(win)
   obj.resizeCurrentWindow("vthird-" .. math.max(third-1,0))
end

function obj.onethirdDown()
   local win = hs.window.focusedWindow()
   if win == nil then
      return
   end
   local third = get_vertical_third(win)
   obj.resizeCurrentWindow("vthird-" .. math.min(third+1,2))
end

function obj.oneScreenLeft()
   obj.moveCurrentWindowToScreen("left")
end

function obj.oneScreenRight()
   obj.moveCurrentWindowToScreen("right")
end

--- WindowManipulation:bindHotkeysToSpec(def, map)
--- Method
--- Map a number of hotkeys according to a definition table
--- *** This function should be in a separate spoon or (preferably) in an hs.spoon module. I'm including it here for now to make the Spoon self-sufficient.
---
--- Parameters:
---  * def - table containing name-to-function definitions for the hotkeys supported by the Spoon. Each key is a hotkey name, and its value must be a function that will be called when the hotkey is invoked.
---  * map - table containing name-to-hotkey definitions, as supported by [bindHotkeys in the Spoon API](https://github.com/Hammerspoon/hammerspoon/blob/master/SPOONS.md#hotkeys). Not all the entries in `def` must be bound, but 
function obj:bindHotkeysToSpec(def,map)
   for name,key in pairs(map) do
      if def[name] ~= nil then
         if self._keys[name] then
            self._keys[name]:delete()
         end
         self._keys[name]=hs.hotkey.bindSpec(key, def[name])
      else
         self.logger.ef("Error: Hotkey requested for undefined action '%s'", name)
      end
   end
   return self
end

--- WindowManipulation:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for WindowManipulation
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * left_half, right_half, top_half, bottom_half - resize to the corresponding half of the screen
---   * third_left, third_right - resize to one horizontal-third of the screen and move left/right
---   * third_up, third_down - resize to one vertical-third of the screen and move up/down
---   * max - maximize the window
---   * max_toggle - toggle maximization
---   * screen_left, screen_right - move the window to the left/right screen (if you have more than one monitor connected, does nothing otherwise)
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
   }
   spoon.SpoonUtils:bindHotkeysToSpec(hotkeyDefinitions, mapping)
   return self
end

function obj:init()
   -- Window cache for window maximize toggler
   self._frameCache = {}
   -- Cache for bound keys
   self._keys = {}
end

return obj
