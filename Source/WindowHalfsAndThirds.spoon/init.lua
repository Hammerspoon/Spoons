--- === WindowHalfsAndThirds ===
---
--- Simple window movement and resizing, focusing on half- and third-of-screen sizes
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowHalfsAndThirds.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowHalfsAndThirds.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "WindowHalfsAndThirds"
obj.version = "0.2"
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
---     larger      = { {        "alt", "cmd", "shift"}, "Right" },
---     smaller     = { {        "alt", "cmd", "shift"}, "Left" },
---  }
--- ```
obj.defaultHotkeys = {
   left_half    = { {"ctrl",        "cmd"}, "Left" },
   right_half   = { {"ctrl",        "cmd"}, "Right" },
   top_half     = { {"ctrl",        "cmd"}, "Up" },
   bottom_half  = { {"ctrl",        "cmd"}, "Down" },
   third_left   = { {"ctrl", "alt"       }, "Left" },
   third_right  = { {"ctrl", "alt"       }, "Right" },
   third_up     = { {"ctrl", "alt"       }, "Up" },
   third_down   = { {"ctrl", "alt"       }, "Down" },
   top_left     = { {"ctrl",        "cmd"}, "1" },
   top_right    = { {"ctrl",        "cmd"}, "2" },
   bottom_left  = { {"ctrl",        "cmd"}, "3" },
   bottom_right = { {"ctrl",        "cmd"}, "4" },
   max_toggle   = { {"ctrl", "alt", "cmd"}, "f" },
   max          = { {"ctrl", "alt", "cmd"}, "Up" },
   undo         = { {        "alt", "cmd"}, "z" },
   center       = { {        "alt", "cmd"}, "c" },
   larger       = { {        "alt", "cmd", "shift"}, "Right" },
   smaller      = { {        "alt", "cmd", "shift"}, "Left" },
}

--- WindowHalfsAndThirds.use_frame_correctness
--- Variable
--- If `true`, set [setFrameCorrectness](http://www.hammerspoon.org/docs/hs.window.html#setFrameCorrectness) for some resizing operations which fail when the window extends beyonds screen boundaries. This may cause some jerkiness in the resizing, so experiment and determine if you need it. Defaults to `false`
obj.use_frame_correctness = false

--- WindowHalfsAndThirds.clear_cache_after_seconds
--- Variable
--- We don't want our undo frame cache filling all available memory. Let's clear it after it hasn't been used for a while.
obj.clear_cache_after_seconds = 60

-- Internal terminology:
-- `actions` are the things hotkeys are bound to and express a user desire (eg. `third_left`: move a third further left
--   than the current `window_state`). See the keys of obj._window_moves or the keys of action_to_method_map in 
--   :bindHotkeys() for the available actions
-- `window_states` are states a window may be currently in (eg. `left_third`: the leftmost horizontal third of the screen)
-- sometimes `actions` and `window_states` share a name (eg. `left_half`)
-- sometimes `actions` and `window_states` don't share a name (`third_left`: `left_third`, `middle_third_h`, `right_third`)
--
-- `window_state_names` are states windows can be in (so since `third_left` implies a relative move there is no `third_left`
--   `window_state_name`, only a `third_left` `action`)
-- `window_state_rects` are `{x,y,w,l}` `hs.geometry.unitrect` tables defining those states
obj._window_state_name_to_rect = {
   left_half      = {0.00,0.00,0.50,1.00}, -- two decimal places required for `window_state_rect_strings` to match
   left_40        = {0.00,0.00,0.40,1.00},
   left_60        = {0.00,0.00,0.60,1.00},
   right_half     = {0.50,0.00,0.50,1.00},
   right_40       = {0.60,0.00,0.40,1.00},
   right_60       = {0.40,0.00,0.60,1.00},
   top_half       = {0.00,0.00,1.00,0.50},
   top_40         = {0.00,0.00,1.00,0.40},
   top_60         = {0.00,0.00,1.00,0.60},
   bottom_half    = {0.00,0.50,1.00,0.50},
   bottom_40      = {0.00,0.60,1.00,0.40},
   bottom_60      = {0.00,0.40,1.00,0.60},
   left_third     = {0.00,0.00,0.33,1.00},
   left_two_third = {0.00,0.00,0.67,1.00},
   middle_third_h = {0.33,0.00,0.34,1.00},
   right_third    = {0.67,0.00,0.33,1.00},
   right_two_third = {0.33,0.00,0.67,1.00},
   top_third      = {0.00,0.00,1.00,0.33},
   top_two_third  = {0.00,0.00,1.00,0.67},
   middle_third_v = {0.00,0.33,1.00,0.34},
   bottom_third   = {0.00,0.67,1.00,0.33},
   bottom_two_third = {0.00,0.33,1.00,0.67},
   top_left       = {0.00,0.00,0.50,0.50},
   top_right      = {0.50,0.00,0.50,0.50},
   bottom_left    = {0.00,0.50,0.50,0.50},
   bottom_right   = {0.50,0.50,0.50,0.50},
   max            = {0.00,0.00,1.00,1.00},
}

-- `window_state_rect_strings` because Lua does table identity comparisons in table keys instead of table content
--   comparisons; that is, table["0.00,0.00,0.50,1.00"] works where table[{0.00,0.00,0.50,1.00}] doesn't
obj._window_state_rect_string_to_name = {}
for state,rect in pairs(obj._window_state_name_to_rect) do
   obj._window_state_rect_string_to_name[table.concat(rect,",")] = state
end

-- `window_moves` are `action` to `window_state_name` pairs
--   `action` = {[`window_state_name` default], [if current `window_state_name`] = [then new `window_state_name`], ...}
--   so if a user takes `action` from `window_state_name` with a key, move to the paired value `window_state_name`,
--   or the default `window_state_name` the current `window_state_name` isn't a key for that `action`
--   (example below)
obj._window_moves = {
   left_half = {"left_half", left_half = "left_40", left_40 = "left_60"},
   half_left = {"left_half"},
   -- if `action` `left_half` is requested without a match in this table, move to `left_half`
   -- if `action` `left_half` is requested from `window_state_name` `left_half`, move to `left_40`
   -- if `action` `left_half` is requested from `window_state_name` `left_40`, move to `left_60`
   -- rationale: if a user requests a move to `left_half` and they're already there they're expressing a user need
   --   and it's our job to work out what that need is. Let's give them some other `left_half`ish options.
   right_half = {"right_half", right_half = "right_40", right_40 = "right_60"},
   half_right = {"right_half"},
   top_half = {"top_half", top_half = "top_40", top_40 = "top_60"},
   half_top = {"top_half"},
   bottom_half = {"bottom_half", bottom_half = "bottom_40", bottom_40 = "bottom_60"},
   half_bottom = {"bottom_half"},
   third_left = {"left_third", left_third = "right_third", middle_third_h = "left_third", right_third = "middle_third_h",
                               right_half = "middle_third_h"},
   third_right = {"right_third", left_third = "middle_third_h", middle_third_h = "right_third", right_third = "left_third",
                                 left_half = "middle_third_h"},
   left_third = {"left_third"}, -- `left_third` is a `window_state` specific `action`, not a relative action
                                -- it is not part of the default hotkey mapping
   left_two_third = {"left_two_third"},
   middle_third_h = {"middle_third_h"},
   right_third = {"right_third"},
   right_two_third = {"right_two_third"},
   third_up = {"top_third", top_third = "bottom_third", middle_third_v = "top_third", bottom_third = "middle_third_v",
                            bottom_half = "middle_third_v"},
   third_down = {"bottom_third", top_third = "middle_third_v", middle_third_v = "bottom_third", bottom_third = "top_third",
                                 top_half = "middle_third_v"},
   top_third = {"top_third"},
   top_two_third = {"top_two_third"},
   middle_third_v = {"middle_third_v"},
   bottom_third = {"bottom_third"},
   bottom_two_third = {"bottom_two_third"},
   top_left = {"top_left"},
   top_right = {"top_right"},
   bottom_left = {"bottom_left"},
   bottom_right = {"bottom_right"},
   max = {"max"},
}

-- Private utility functions

local function round(x, places)
   local places = places or 0
   local x = x * 10^places
   return (x + 0.5 - (x + 0.5) % 1) / 10^places
end

local function current_window_rect(win)
   local win = win or hs.window.focusedWindow()
   local ur, r = win:screen():toUnitRect(win:frame()), round
   return {r(ur.x,2), r(ur.y,2), r(ur.w,2), r(ur.h,2)} -- an hs.geometry.unitrect table
end

local function current_window_state_name(win)
   local win = win or hs.window.focusedWindow()
   return obj._window_state_rect_string_to_name[table.concat(current_window_rect(win),",")]
end

local function cacheWindow(win, move_to)
   local win = win or hs.window.focusedWindow()
   if (not win) or (not win:id()) then return end
   obj._frameCache[win:id()] = win:frame()
   obj._frameCacheClearTimer:start()
   obj._lastMoveCache[win:id()] = move_to
   return win
end

local function restoreWindowFromCache(win)
   local win = win or hs.window.focusedWindow()
   if (not win) or (not win:id()) or (not obj._frameCache[win:id()]) then return end
   local current_window_frame = win:frame()         -- enable undoing an undo action
   win:setFrame(obj._frameCache[win:id()])
   obj._frameCache[win:id()] = current_window_frame -- enable undoing an undo action
   return win
end

function obj.script_path_raw(n)
   return (debug.getinfo(n or 2, "S").source)
end
function obj.script_path(n)
   local str = obj.script_path_raw(n or 2):sub(2)
   return str:match("(.*/)")
end
function obj.generate_docs_json()
   io.open(obj.script_path().."docs.json","w"):write(hs.doc.builder.genJSON(obj.script_path())):close()
end

-- Internal functions to store/restore the current value of setFrameCorrectness.
local function _setFrameCorrectness()
   obj._savedFrameCorrectness = hs.window.setFrameCorrectness
   hs.window.setFrameCorrectness = obj.use_frame_correctness
end
local function _restoreFrameCorrectness()
   hs.window.setFrameCorrectness = obj._savedFrameCorrectness
end


-- --------------------------------------------------------------------
-- Base window resizing and moving functions
-- --------------------------------------------------------------------


-- Resize current window to different parts of the screen
-- If use_frame_correctness_preference is true, then use setFrameCorrectness according to the
-- configured value of `WindowHalfsAndThirds.use_frame_correctness`
function obj.resizeCurrentWindow(how, use_frame_correctness_preference)
   local win = hs.window.focusedWindow()
   if not win then return end

   local move_to = obj._lastMoveCache[win:id()] and obj._window_moves[how][obj._lastMoveCache[win:id()]] or
      obj._window_moves[how][current_window_state_name(win)] or obj._window_moves[how][1]
   if not move_to then
      obj.logger.e("I don't know how to move ".. how .." from ".. (obj._lastMoveCache[win:id()] or
         current_window_state_name(win)))
   end
   if current_window_state_name(win) == move_to then return end
   local move_to_rect = obj._window_state_name_to_rect[move_to]
   if not move_to_rect then
      obj.logger.e("I don't know how to move to ".. move_to)
      return
   end

   if use_frame_correctness_preference then _setFrameCorrectness() end
   cacheWindow(win, move_to)
   win:move(move_to_rect)
   if use_frame_correctness_preference then _restoreFrameCorrectness() end
end

-- --------------------------------------------------------------------
-- Action functions for obj.resizeCurrentWindow, for the hotkeys
-- --------------------------------------------------------------------

--- WindowHalfsAndThirds:leftHalf(win)
--- Method
--- Resize to the left half of the screen.
---
--- Parameters:
---  * win - hs.window to use, defaults to hs.window.focusedWindow()
---
--- Returns:
---  * the WindowHalfsAndThirds object
---
--- Notes:
---  * Variations of this method exist for other operations. See WindowHalfsAndThirds:bindHotkeys for details:
---    * .leftHalf .rightHalf .topHalf .bottomHalf .thirdLeft .thirdRight .leftThird .middleThirdH .rightThird
---    * .thirdUp .thirdDown .topThird .middleThirdV .bottomThird .topLeft .topRight .bottomLeft .bottomRight
---    * .maximize

obj.leftHalf       = hs.fnutils.partial(obj.resizeCurrentWindow, "left_half")
obj.halfLeft       = hs.fnutils.partial(obj.resizeCurrentWindow, "half_left")
obj.rightHalf      = hs.fnutils.partial(obj.resizeCurrentWindow, "right_half")
obj.halfRight      = hs.fnutils.partial(obj.resizeCurrentWindow, "half_right")
obj.topHalf        = hs.fnutils.partial(obj.resizeCurrentWindow, "top_half")
obj.halfTop        = hs.fnutils.partial(obj.resizeCurrentWindow, "half_top")
obj.bottomHalf     = hs.fnutils.partial(obj.resizeCurrentWindow, "bottom_half")
obj.halfBottom     = hs.fnutils.partial(obj.resizeCurrentWindow, "half_bottom")
obj.thirdLeft      = hs.fnutils.partial(obj.resizeCurrentWindow, "third_left")
obj.thirdRight     = hs.fnutils.partial(obj.resizeCurrentWindow, "third_right")
obj.leftThird      = hs.fnutils.partial(obj.resizeCurrentWindow, "left_third")
obj.leftTwoThird   = hs.fnutils.partial(obj.resizeCurrentWindow, "left_two_third")
obj.middleThirdH   = hs.fnutils.partial(obj.resizeCurrentWindow, "middle_third_h")
obj.rightThird     = hs.fnutils.partial(obj.resizeCurrentWindow, "right_third")
obj.rightTwoThird  = hs.fnutils.partial(obj.resizeCurrentWindow, "right_two_third")
obj.thirdUp        = hs.fnutils.partial(obj.resizeCurrentWindow, "third_up")
obj.thirdDown      = hs.fnutils.partial(obj.resizeCurrentWindow, "third_down")
obj.topThird       = hs.fnutils.partial(obj.resizeCurrentWindow, "top_third")
obj.topTwoThird    = hs.fnutils.partial(obj.resizeCurrentWindow, "top_two_third")
obj.middleThirdV   = hs.fnutils.partial(obj.resizeCurrentWindow, "middle_third_v")
obj.bottomThird    = hs.fnutils.partial(obj.resizeCurrentWindow, "bottom_third")
obj.bottomTwoThird = hs.fnutils.partial(obj.resizeCurrentWindow, "bottom_two_third")
obj.topLeft        = hs.fnutils.partial(obj.resizeCurrentWindow, "top_left")
obj.topRight       = hs.fnutils.partial(obj.resizeCurrentWindow, "top_right")
obj.bottomLeft     = hs.fnutils.partial(obj.resizeCurrentWindow, "bottom_left")
obj.bottomRight    = hs.fnutils.partial(obj.resizeCurrentWindow, "bottom_right")
obj.maximize       = hs.fnutils.partial(obj.resizeCurrentWindow, "max", true)


--- WindowHalfsAndThirds:toggleMaximized(win)
--- Method
--- Toggle win between its normal size, and being maximized
---
--- Parameters:
---  * win - hs.window to use, defaults to hs.window.focusedWindow()
---
--- Returns:
---  * the WindowHalfsAndThirds object
function obj.toggleMaximized(win)
   local win = win or hs.window.focusedWindow()
   if (not win) or (not win:id()) then
      return
   end
   if current_window_state_name() == "max" then
      restoreWindowFromCache(win)
   else
      cacheWindow(win, "max")
      win:maximize()
   end
   return obj
end

--- WindowHalfsAndThirds:undo(win)
--- Method
--- Undo window size changes for win if there've been any in WindowHalfsAndThirds.clear_cache_after_seconds
---
--- Parameters:
---  * win - hs.window to use, defaults to hs.window.focusedWindow()
---
--- Returns:
---  * the WindowHalfsAndThirds object
function obj.undo(win)
   restoreWindowFromCache(win)
   return obj
end

--- WindowHalfsAndThirds:center(win)
--- Method
--- Center window on screen
---
--- Parameters:
---  * win - hs.window to use, defaults to hs.window.focusedWindow()
---
--- Returns:
---  * the WindowHalfsAndThirds object
function obj.center(win)
   local win = win or hs.window.focusedWindow()
   if win then
      cacheWindow(win, "center")
      win:centerOnScreen()
   end
   return obj
end

--- WindowHalfsAndThirds:larger(win)
--- Method
--- Make win larger than its current size
---
--- Parameters:
---  * win - hs.window to use, defaults to hs.window.focusedWindow()
---
--- Returns:
---  * the WindowHalfsAndThirds object
function obj.larger(win)
   local win = win or hs.window.focusedWindow()
   if win then
      cacheWindow(win, nil)
      local cw = current_window_rect(win)
      local move_to_rect = {}
      move_to_rect[1] = math.max(cw[1]-0.02,0)
      move_to_rect[2] = math.max(cw[2]-0.02,0)
      move_to_rect[3] = math.min(cw[3]+0.04,1 - move_to_rect[1])
      move_to_rect[4] = math.min(cw[4]+0.04,1 - move_to_rect[2])
      win:move(move_to_rect)
   end
   return obj
end

--- WindowHalfsAndThirds:smaller(win)
--- Method
--- Make win smaller than its current size
---
--- Parameters:
---  * win - hs.window to use, defaults to hs.window.focusedWindow()
---
--- Returns:
---  * the WindowHalfsAndThirds object
function obj.smaller(win)
   local win = win or hs.window.focusedWindow()
   if win then
      cacheWindow(win, nil)
      local cw = current_window_rect(win)
      local move_to_rect = {}
      move_to_rect[3] = math.max(cw[3]-0.04,0.1)
      move_to_rect[4] = cw[4] > 0.95 and 1 or math.max(cw[4]-0.04,0.1) -- some windows (MacVim) don't size to 1
      move_to_rect[1] = math.min(cw[1]+0.02,1 - move_to_rect[3])
      move_to_rect[2] = cw[2] == 0 and 0 or math.min(cw[2]+0.02,1 - move_to_rect[4])
      win:move(move_to_rect)
   end
   return obj
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
---   * left_third, middle_third_h, right_third - resize and move the window to the corresponding horizontal third of the screen
---   * top_third, middle_third_v, bottom_third - resize and move the window to the corresponding vertical third of the screen
---   * top_left, top_right, bottom_left, bottom_right - resize and move the window to the corresponding quarter of the screen
---   * undo - restore window to position before last move
---   * center - move window to center of screen
---   * larger - grow window larger than its current size
---   * smaller - shrink window smaller than its current size
---
--- Returns:
---  * the WindowHalfsAndThirds object
function obj:bindHotkeys(mapping)
   local action_to_method_map = {
      left_half = self.leftHalf,
      half_left = self.halfLeft,
      right_half = self.rightHalf,
      half_right = self.halfRight,
      top_half = self.topHalf,
      half_top = self.halfTop,
      bottom_half = self.bottomHalf,
      half_bottom = self.halfBottom,
      third_left = self.thirdLeft,
      third_right = self.thirdRight,
      third_up = self.thirdUp,
      third_down = self.thirdDown,
      max = self.maximize,
      max_toggle = self.toggleMaximized,
      left_third = self.leftThird,
      left_two_third = self.leftTwoThird,
      middle_third_h = self.middleThirdH,
      right_third = self.rightThird,
      right_two_third = self.rightTwoThird,
      top_third = self.topThird,
      top_two_third = self.topTwoThird,
      middle_third_v = self.middleThirdV,
      bottom_third = self.bottomThird,
      bottom_two_third = self.bottomTwoThird,
      top_left = self.topLeft,
      top_right = self.topRight,
      bottom_left = self.bottomLeft,
      bottom_right = self.bottomRight,
      undo = self.undo,
      center = self.center,
      larger = self.larger,
      smaller = self.smaller,
      -- Legacy (`action` names changed for internal consistency, old names preserved)
      left = self.leftHalf,
      right = self.rightHalf,
      top = self.topHalf,
      bottom = self.bottomHalf,
   }
   hs.spoons.bindHotkeysToSpec(action_to_method_map, mapping)
   return self
end

function obj:init()
   self._frameCache = {}
   obj._lastMoveCache = {}
   self._frameCacheClearTimer = hs.timer.delayed.new(obj.clear_cache_after_seconds,
      function() obj._frameCache = {}; obj._lastMoveCache = {} end)
end


-- Legacy (names changed for internal consistency, old names preserved)
function obj.oneThirdLeft() obj.thirdLeft() end
function obj.oneThirdRight() obj.thirdRight() end
function obj.oneThirdUp() obj.thirdUp() end
function obj.onethirdDown() obj.thirdDown() end


return obj

