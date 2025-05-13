--- === DockGuard ===
---
--- Prevent the macOS Dock from moving from the main monitor (the one with the menu bar) to another monitor.
--- When the mouse cursor approaches the bottom edge of a screen, DockGuard nudges the cursor upward to prevent the Dock from moving.
--- This is almost unnoticeable in normal use.
---
--- Usage example in your init.lua:
--- hs.loadSpoon("DockGuard")
--- spoon.DockGuard:start()
---
--- The default config is as follows:
---     edgeTriggerMargin = 1,        -- Number of pixels from the bottom edge to trigger the nudge
---     mouseNudgeDistance = 1,       -- Number of pixels to nudge the cursor upward
---     watcherRestartDelay = 0.1,    -- Delay (in seconds) before restarting the watcher after nudging
---
--- You can override these defaults before calling :start(), for example:
--- hs.loadSpoon("DockGuard")
--- spoon.DockGuard.edgeTriggerMargin = 5 -- Trigger within 5px of the bottom edge
--- spoon.DockGuard.mouseNudgeDistance = 2 -- Nudge cursor up by 2px
--- spoon.DockGuard.watcherRestartDelay = 0.2 -- Restart watcher after 0.2s
--- spoon.DockGuard:start()
--- Note: If 'Automatically hide and show the Dock' is enabled, this plugin may not work as expected.


local obj = {}
obj.__index = obj

obj.name = "DockGuard"
obj.version = "0.1"
obj.author = "Ohyoung Park <ohyoungpark@mail.com>"
obj.homepage = "https://github.com/ohyoungpark/DockGuard.spoon"
obj.license = "The Unlicense - https://unlicense.org/"

obj.edgeTriggerMargin = 1
obj.watcherRestartDelay = 0.1
obj.mouseNudgeDistance = 1

--- DockGuard:start()
--- Method
--- Starts monitoring mouse movement. When the mouse cursor approaches the bottom edge of the main screen, it nudges the cursor upward to prevent the Dock from moving to another monitor.
---
--- Parameters:
---  * None
function obj:start()
  local mouseMoveWatcher = nil

  mouseMoveWatcher = hs.eventtap.new({ hs.eventtap.event.types.mouseMoved }, function(event)
    local pos = event:location()
    local screen = hs.mouse.getCurrentScreen()
    if not screen then
      return false
    end
    local frame = screen:fullFrame()
    local relativeY = pos.y - frame.y
    local bottomY = frame.h

    if relativeY >= (bottomY - self.edgeTriggerMargin) then
      mouseMoveWatcher:stop()
      local fakePos = { x = pos.x, y = pos.y - self.mouseNudgeDistance }
      hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.mouseMoved, fakePos):post()
      hs.timer.doAfter(self.watcherRestartDelay, function()
        mouseMoveWatcher:start()
      end)
    end
    return false
  end)
  mouseMoveWatcher:start()
  self._mouseMoveWatcher = mouseMoveWatcher
end

--- DockGuard:stop()
--- Method
--- Stops monitoring mouse movement and allows the Dock to move to another monitor.
---
--- Parameters:
---  * None
function obj:stop()
  if self._mouseMoveWatcher then
    self._mouseMoveWatcher:stop()
    self._mouseMoveWatcher = nil
  end
end

return obj