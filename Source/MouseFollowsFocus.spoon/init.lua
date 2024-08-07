--- === MouseFollowsFocus ===
---
--- Set the mouse pointer to the center of the focused window whenever focus changes.
---
--- Additionally, if focused window moves when no mouse buttons are pressed, set the
--- mouse pointer to the new center.  This is intended to work with other utilities
--- which warp the focused window.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/MouseFollowsFocus.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/MouseFollowsFocus.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "MouseFollowsFocus"
obj.version = "0.1"
obj.author = "Jason Felice <jason.m.felice@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"
obj.onChangeOfScreenOnly = false
obj.onWindowMoved = false
obj.currentWindowScreen = nil

--- MouseFollowsFocus.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('MouseFollowsFocus')

--- MouseFollowsFocus:configure(configuration)
--- Method
--- Configures the spoon.
---
--- Parameters:
---  * configuration - a table containing the settings for onWindowMoved or onChangeOfScreenOnly:
function obj:configure(configuration)
  if configuration['onChangeOfScreenOnly'] then
    self.onChangeOfScreenOnly = configuration['onChangeOfScreenOnly']
  end
  if configuration['onWindowMoved'] then
    self.onWindowMoved = configuration['onWindowMoved']
  end
end

--- MouseFollowsFocus:start()
--- Method
--- Starts updating the mouse position when window focus changes
---
--- Parameters:
---  * None
function obj:start()
  self.window_filter = hs.window.filter.new({override={
    visible = true,
  }}):setDefaultFilter({
    visible = true,
  })
  self.window_filter:subscribe({
    hs.window.filter.windowFocused
  }, function(window) 
      if self.onChangeOfScreenOnly and self.currentWindowScreen and self.currentWindowScreen:id() == window:screen():id() then return end
      self:updateMouse(window)
      self.currentWindowScreen = window:screen()
  end)
  self.window_filter:subscribe({
    hs.window.filter.windowMoved
  }, function(window)
    if not self.onWindowMoved then return end
    if window ~= hs.window.focusedWindow() then return end
    if #hs.mouse.getButtons() ~= 0 then return end
    self:updateMouse(window)
  end)
end

--- MouseFollowsFocus:stop()
--- Method
--- Stops updating the mouse position when window focus changes
---
--- Parameters:
---  * None
function obj:stop()
  self.window_filter:unsubscribeAll()
  self.window_filter = nil
end

--- MouseFollowsFocus:updateMouse(window)
--- Method
--- Moves the mouse to the center of the given window unless it's already inside the window
---
--- Parameters:
---  * None
function obj:updateMouse(window)
  local current_pos = hs.geometry(hs.mouse.absolutePosition())
  local frame = window:frame()
  if not current_pos:inside(frame) then
    hs.mouse.absolutePosition(frame.center)
  end
end

return obj
