--- === VisualBell ===
---
--- Flashes the screen as a visual notification, similar to Vim's 'visualbell'.
---
---

local obj = {}
obj.__index = obj

obj.name = "VisualBell"
obj.version = "1.0"
obj.author = "Jon Lorusso <jonlorusso@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- VisualBell.color
--- Variable
--- The color of the flash
obj.color = { white = 1.0, alpha = 0.2 }


--- VisualBell.duration
--- Variable
--- The duration of the flash
obj.duration = 0.15

--- VisualBell:flash()
--- Method
--- Flashes the screen using the configured color and duration
---
--- Parameters:
---  * None
function obj:flash()
  local screenFrame = hs.screen.mainScreen():fullFrame()
  local flash = hs.drawing.rectangle(screenFrame)

  flash:setFillColor(obj.color)
  flash:setFill(true)
  flash:setLevel(hs.drawing.windowLevels.overlay)
  flash:show()

  hs.timer.doAfter(obj.duration, function() flash:delete() end)
end

return obj
