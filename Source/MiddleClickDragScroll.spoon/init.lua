--- === MiddleClickDragScroll ===
---
--- Allows scrolling by holding down the middle mouse button and dragging it, the same as it works on Windows.
--- Especially useful to quickly scroll to the top or bottom of a page, if you don't have a Magic Mouse.
---
--- Note: Due to OS limitations, it always scrolls the window currently below the mouse, not the window below the position
--- where the dragging started, like it works on Windows. You therefore need to take some care to stay inside the window.
---
--- == Usage ==
---
--- ```lua
--- local MiddleClickDragScroll = hs.loadSpoon("MiddleClickDragScroll"):start()
--- ```
---
--- You can temporarily stop the spoon by calling `MiddleClickDragScroll:stop()` and then restart it by calling `MiddleClickDragScroll:start()` again.
---
--- == Configuration ==
---
--- ```lua
--- local MiddleClickDragScroll = hs.loadSpoon("MiddleClickDragScroll"):configure{
---   excludedApps = {"Some App", "Other app"},         -- Don't activate scrolling in apps with these names
---   excludedWindows = {"^Some Window Title$"},        -- Don't activate scrolling in windows with these names (supports regex, for exact match, use "^title$")
---   excludedUrls = {"^https://geogebra.calculator$"}, -- Don't activate scrolling when the active window is on these URLs (supports regex, only works in Chrome and Safari, asks for extra permissions on first trigger)
---   indicatorSize = 25,   -- Size of the scrolling indicator in pixels
---   indicatorAttributes = -- Attributes of the scrolling indicator. Takes any specified on https://www.hammerspoon.org/docs/hs.canvas.html#attributes. Alternatively, you can pass a custom canvas, see the explenation below.
---   {
---     type = "circle",
---     fillColor = { red = 0, green = 0, blue = 0, alpha = 0.3 },
---     strokeColor = { red = 1, green = 1, blue = 1, alpha = 0.5 },
---   },
---   startDistance = 15,       -- Minimal distance to drag the mouse before scrolling is triggered.
---   scrollMode = "pixel",     -- Whether the scroll speed is in "line"s or "pixel"s. Scrolling by lines has smooting in some applications
---                             -- and therefore works with reduced frequency but it offers much less precise control.
---   scrollFrequency = 0.01,   -- How often to trigger scrolling (in seconds)
---   scrollAccelaration = 30,  -- How fast scrolling accelerates based on the mouse distance from the initial location. Larger is faster.
---   scrollSpeedFn =           -- How scrolling accelerates based on the mouse distance from the initial location.
---                             -- The default is dist^2 / scrollAcceleration^2. You can pass a custom function that recieves `self` as the first argument
---                             -- and the absolute distance as the second and returns the resulting speed (in pixels or lines, depending on the scrollMode setting).
---   function(self, x)
---     return (x ^ 2) / (self.scrollAccelaration ^ 2)
---   end
--- }:start()
--- ```
---
--- Unspecified keys are unchanged. You can call `configure` multiple times to dynamically change it but changing `indicatorAttributes` and `indicatorSize` only works when `MiddleClickDragScroll` is stopped.
---
--- Instead of `indicatorSize` and `indicatorAttributes`, you can also pass a custom canvas to `configure` or set it directly to have more control over the indicator style:
---
--- ```lua
---   MiddleClickDragScroll.canvas = hs.canvas.new{ w = 25, h = 25}:insertElement{
---     type = "circle",
---     fillColor = { red = 0, green = 0, blue = 0, alpha = 0.3 },
---     strokeColor = { red = 1, green = 1, blue = 1, alpha = 0.5 },
---   }
--- ```
---
--- For more details, see: https://www.hammerspoon.org/docs/hs.canvas.html
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/MiddleClickDragScroll.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/MiddleClickDragScroll.spoon.zip)

local MiddleClickDragScroll = {}

MiddleClickDragScroll.author = "Benedikt Werner <1benediktwerner@gmail.com>"
MiddleClickDragScroll.homepage = "https://github.com/benediktwerner/MiddleClickDragScroll.spoon"
MiddleClickDragScroll.license = "MIT"
MiddleClickDragScroll.name = "MiddleClickDragScroll"
MiddleClickDragScroll.version = "1.0.0"
MiddleClickDragScroll.spoon = hs.spoons.scriptPath()

MiddleClickDragScroll.excludedApps = {}       -- Don't activate scrolling in apps with these names
MiddleClickDragScroll.excludedWindows = {}    -- Don't activate scrolling in windows with these names (supports regex)
MiddleClickDragScroll.excludedUrls = {}       -- Don't activate scrolling when the active window is on these URLs (supports regex, only works in Chrome and Safari, asks for extra permissions on first trigger)
MiddleClickDragScroll.indicatorSize = 25      -- Size of the scrolling indicator in pixels
MiddleClickDragScroll.indicatorAttributes =   -- Attributes of the scrolling indicator. Takes any specified on https://www.hammerspoon.org/docs/hs.canvas.html#attributes. Alternatively, you can pass a custom canvas.
{
  type = "circle",
  fillColor = { red = 0, green = 0, blue = 0, alpha = 0.3 },
  strokeColor = { red = 1, green = 1, blue = 1, alpha = 0.5 },
}
MiddleClickDragScroll.startDistance = 15      -- Minimal distance to drag the mouse before scrolling is triggered.
MiddleClickDragScroll.scrollMode = "pixel"    -- Whether the scroll speed is in "line"s or "pixel"s. Scrolling by lines has smooting in some applications and therefore works with reduced frequency but it offers much less precise control.
MiddleClickDragScroll.scrollFrequency = 0.01  -- How often to trigger scrolling (in seconds)
MiddleClickDragScroll.scrollAccelaration = 30 -- How fast scrolling accelerates based on the mouse distance from the initial location. Larger is faster.
MiddleClickDragScroll.scrollSpeedFn =         -- How scrolling accelerates based on the mouse distance from the initial location. The default is dist^2 / scrollAcceleration^2. You can pass a custom function that recieves `self` as the first argument and the absolute distance as the second and returns the resulting speed (in pixels or lines, depending on the scrollMode setting)
function(self, x)
  return (x ^ 2) / (self.scrollAccelaration ^ 2)
end

local function signum(n)
  if n > 0 then return 1
  elseif n < 0 then return -1
  else return 0 end
end

local function getWindowUnderMouse()
  -- Adapted from SkyRocket.spoon
  -- Invoke `hs.application` because `hs.window.orderedWindows()` doesn't do it and breaks itself
  local _ = hs.application

  local mousePos = hs.geometry.new(hs.mouse.absolutePosition())
  local screen = hs.mouse.getCurrentScreen()

  return hs.fnutils.find(hs.window.orderedWindows(), function(w)
    return screen == w:screen() and mousePos:inside(w:frame())
  end)
end

function MiddleClickDragScroll:init()
  self.position = nil
  self.isScrolling = false
  self.timer = nil

  self.middleMouseDownEventTap = hs.eventtap.new({hs.eventtap.event.types.otherMouseDown}, self:handleMouseDown())
  self.middleMouseDraggedEventTap = hs.eventtap.new({hs.eventtap.event.types.otherMouseDragged}, self:handleMouseDragged())
  self.middleMouseUpEventTap = hs.eventtap.new({hs.eventtap.event.types.otherMouseUp}, self:handleMouseUp())
end

function MiddleClickDragScroll:handleMouseDown()
  return function(event)
    self.isScrolling = false
    if self.timer ~= nil then
      self.timer:stop()
      self.timer = nil
    end
  
    if event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber) ~= 2 then
      return
    end
  
    local window = getWindowUnderMouse()
    if window == nil then return end
  
    local appTitle = window:application():title()
    if hs.fnutils.some(self.excludedApps, function(a) return a == appTitle end) then return end
  
    local windowTitle = window:title()
    if hs.fnutils.some(self.excludedWindows, function(w) return windowTitle:match(w) end) then return end
  
    if appTitle == "Safari" and #self.excludedUrls > 0 then
      local _, url = hs.osascript.applescript('tell application "Safari" to return URL of current tab of front window')
      if hs.fnutils.some(self.excludedUrls, function(u) return url:match(u) end) then return end
    end
  
    if appTitle == "Google Chrome" and #self.excludedUrls > 0 then
      local _, url = hs.osascript.applescript('tell application "Google Chrome" to return URL of active tab of front window')
      if hs.fnutils.some(self.excludedUrls, function(u) return url:match(u) end) then return end
    end
  
    self.startPos = event:location()

    return true
  end
end

function MiddleClickDragScroll:handleMouseDragged()
  return function(event)
    if event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber) ~= 2 or self.startPos == nil then
      return
    end
  
    local loc = event:location()
    if loc == nil then
      return true
    end

    self.currPos = loc

    if self.isScrolling then
      return true
    end
  
    if (loc.x - self.startPos.x) ^ 2 + (loc.y - self.startPos.y) ^ 2 > self.startDistance ^ 2 then
      self.isScrolling = true
      local frame = self.canvas:frame()
      self.canvas:topLeft{ x = self.startPos.x - frame.w / 2, y = self.startPos.y - frame.h / 2 }:show()
      self.timer = hs.timer.doEvery(self.scrollFrequency, function(t)
        local xDiff = self.startPos.x - self.currPos.x
        local yDiff = self.startPos.y - self.currPos.y
        hs.eventtap.scrollWheel(
          {
            math.floor(self:scrollSpeedFn(xDiff)) * signum(xDiff),
            math.floor(self:scrollSpeedFn(yDiff)) * signum(yDiff),
          },
          {},
          self.scrollMode
        )
      end)
    end

    return true
  end
end

function MiddleClickDragScroll:handleMouseUp()
  return function(event)
    if event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber) ~= 2 or self.startPos == nil then
      return
    end

    if self.timer ~= nil then
      self.timer:stop()
      self.timer = nil
    end

    self.startPos = nil
    self.canvas:hide()

    if not self.isScrolling then
      self.middleMouseDownEventTap:stop()
      self.middleMouseUpEventTap:stop()
      hs.eventtap.middleClick(event:location(), 1)
      self.middleMouseUpEventTap:start()
      self.middleMouseDownEventTap:start()
    end

    return true
  end
end

function MiddleClickDragScroll:configure(options)
  self.excludedApps = options.excludedApps or self.excludedApps 
  self.excludedWindows = options.excludedWindows or self.excludedWindows 
  self.excludedUrls = options.excludedUrls or self.excludedUrls 
  self.startDistance = options.startDistance or self.startDistance 
  self.scrollMode = options.scrollMode or self.scrollMode 
  self.scrollFrequency = options.scrollFrequency or self.scrollFrequency 
  self.scrollSpeed = options.scrollSpeed or self.scrollSpeed 
  self.scrollSpeedFn = options.scrollSpeedFn or self.scrollSpeedFn 
  self.canvas = options.canvas or self.canvas
  self.indicatorSize = options.indicatorSize or self.indicatorSize
  self.indicatorAttributes = options.indicatorAttributes or self.indicatorAttributes
  if options.indicatorSize or options.indicatorAttributes then
    self.canvas = nil
  end
  return self
end

function MiddleClickDragScroll:start()
  if self.canvas == nil then
    self.canvas = hs.canvas.new{ w = self.indicatorSize, h = self.indicatorSize }
    self.canvas:insertElement(self.indicatorAttributes)
  end

  self.middleMouseDownEventTap:start()
  self.middleMouseDraggedEventTap:start()
  self.middleMouseUpEventTap:start()
  return self
end

function MiddleClickDragScroll:stop()
  self.middleMouseDownEventTap:stop()
  self.middleMouseDraggedEventTap:stop()
  self.middleMouseUpEventTap:stop()
  return self
end

function MiddleClickDragScroll:isEnabled()
  return self.middleMouseDownEventTap:isEnabled()
end

return MiddleClickDragScroll
