--- === Cherry ===
---
--- Cherry tomato (a tiny Pomodoro) -- a Pomodoro Timer for the menubar
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/Cherry.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/Cherry.spoon.zip)
---

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Cherry"
obj.version = "0.1"
obj.author = "Daniel Marques <danielbmarques@gmail.com>"
obj.license = "MIT"
obj.homepage = "https://github.com/Hammerspoon/Spoons"

-- Default Settings
obj.duration = 1 -- timer duration in minutes

-- set this to true to always show the menu bar item
-- (making the keyboard shortcut superfluous):
obj.alwaysShow = false

obj.DefaultMapping = {
  start = {{"cmd", "ctrl", "alt"}, "C"}
}


--- Cherry:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for Cherry
---
--- Parameters:
---  * mapping - A table containing hotkey details for the following items:
---   * start - start the pomodoro timer (Default: cmd-ctrl-alt-C)
function obj:bindHotkeys(mapping)
  if (self.hotkey) then
     self.hotkey.delete()
  end

  if mapping and mapping["start"] then
    hs.hotkey.bind(mapping["start"][1], mapping["start"][2], function() self:start() end)
  else
    hs.hotkey.bind(self.DefaultMapping["start"][1], self.DefaultMapping["start"][2], function() self:start() end)
  end
end


function obj:init()
  self.timer = hs.timer.new(1, function() self:tick() end)
  self.menu = hs.menubar.new(self.alwaysShow)
  self:reset()
end


function obj:reset()
  local items = {
      { title = "Start", fn = function() self:start() end}
  }
  self.menu:setMenu(items)
  self.timeLeft = obj.duration * 60
  self.menu:setTitle("🍒")
end


function obj:updateTimerString()
    local minutes = math.floor(self.timeLeft / 60)
    local seconds = self.timeLeft - (minutes * 60)
    local timerString = string.format("%02d:%02d 🍒", minutes, seconds)
    self.menu:setTitle(timerString)
end


function obj:tick()
  self.timeLeft = self.timeLeft - 1
  self:updateTimerString()
  if self.timeLeft <= 0 then
    self.timer:stop()
    self:reset()
    if not self.alwaysShow then
      self.menu:removeFromMenuBar()
    end
    hs.alert.show("Done! 🍒")
  end
end

--- Cherry:start()
--- Method
--- Starts the timer and displays the countdown in a menubar item
---
--- Parameters:
---  * isResume - boolean when true resets the countdown
---
--- Returns:
---  * None
function obj:start(isResume)
  if not self.menu:isInMenuBar() then
    self.menu:returnToMenuBar()
  end
  if not isResume then
     self.timeLeft = self.duration * 60
  end
  self.timer:start()
  local items = {
    { title = "Stop",  fn = function() self:stop() end},
    { title = "Pause", fn = function() self:pause() end}
  }
  self.menu:setMenu(items)
end

function obj:pause()
    self.timer:stop()
    local items = {
      { title = "Stop", fn = function() self:stop() end},
      { title = "Resume", fn = function() self:start(true) end}
    }
    self.menu:setMenu(items)
end

--- Cherry:stop()
--- Method
--- Stops the timer and removes the menubar item if Cherry.alwaysShow is false
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:stop()
  self.timer:stop()
  self:reset()
  if not self.alwaysShow then
    self.menu:removeFromMenuBar()
  end
end


return obj
