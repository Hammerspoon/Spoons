local module = {}

-- grabs screen with active window, unless it's Finder's desktop
-- then we use mouse position
module.activeScreen = function()
  local mousePoint   = hs.geometry.point(hs.mouse.getAbsolutePosition())
  local activeWindow = hs.window.focusedWindow()

  if activeWindow and activeWindow:role() ~= 'AXScrollArea' then
    return activeWindow:screen()
  else
    return hs.fnutils.find(hs.screen.allScreens(), function(screen)
      return mousePoint:inside(screen:frame())
    end)
  end
end

module.focusScreen = function(screen)
  local frame         = screen:frame()
  local mousePosition = hs.mouse.getAbsolutePosition()

  -- if mouse is already on the given screen we can safely return
  if hs.geometry(mousePosition):inside(frame) then return false end

  -- "hide" cursor in the lower right side of screen
  -- it's invisible while we are changing spaces
  local newMousePosition = {
    x = frame.x + frame.w - 1,
    y = frame.y + frame.h - 1
  }

  hs.mouse.setAbsolutePosition(newMousePosition)
  hs.timer.usleep(1000)

  return true
end

return module
