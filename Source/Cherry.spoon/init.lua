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
obj.author = "Daniel Marques <danielbmarques@gmail.com> and Omar El-Domeiri <omar@doesnotexist.com>"
obj.license = "MIT"
obj.homepage = "https://github.com/Hammerspoon/Spoons"

-- Settings

-- timer duration in minutes
obj.duration = 25

-- set this to true to always show the menubar item
obj.alwaysShow = true

-- duration in seconds for alert to stay on screen
-- set to 0 to turn off alert completely
obj.alertDuration = 5

-- Font size for alert
obj.alertTextSize = 80

-- set to nil to turn off notification when time's up or provide a hs.notify notification
obj.notification = nil
-- obj.notification = hs.notify.new({ title = "Done! 🍒", withdrawAfter = 0})

-- set to nil to turn off notification sound when time's up or provide a hs.sound
obj.sound = nil
-- obj.sound = hs.sound.getByFile("System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Resources/Sounds")

obj.defaultMapping = {
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
    hs.hotkey.bind(self.defaultMapping["start"][1], self.defaultMapping["start"][2], function() self:start() end)
  end
end


function obj:init()
  self.menu = hs.menubar.new(self.alwaysShow)
  self:reset()
end


function obj:reset()
  local items = {
    { title = "Start", fn = function() self:start() end }
  }
  self.menu:setMenu(items)
  self.menu:setTitle("🍒")
  self.timerRunning = false
  if not self.alwaysShow then
      self.menu:removeFromMenuBar()
  end
end


function obj:updateTimerString()
    local minutes = math.floor(self.timeLeft / 60)
    local seconds = self.timeLeft - (minutes * 60)
    local timerString = string.format("%02d:%02d 🍒", minutes, seconds)
    self.menu:setTitle(timerString)
end


--- Cherry:popup()
--- Method
--- Popup an alert or notification when time is up.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:popup()
  if 0 < self.alertDuration then
    hs.alert.show("Done! 🍒", { textSize = self.alertTextSize }, self.alertDuration)
  end
  if self.notification then
    self.notification:send()
  end
  if self.sound then
    self.sound:play()
  end
end


function obj:tick()
  self.timeLeft = self.timeLeft - 1
  self:updateTimerString()
  if self.timeLeft <= 0 then
    self:reset()
    self:popup()
  end
end


--- Cherry:start()
--- Method
--- Starts the timer and displays the countdown in a menubar item
---
--- Parameters:
---  * resume - boolean when true resumes countdown at current value of self.timeLeft
---
--- Returns:
---  * None
function obj:start(resume)
  if not self.menu:isInMenuBar() then
    self.menu:returnToMenuBar()
  end
  if not resume then
     self.timeLeft = self.duration * 60
     self:updateTimerString()
  end
  self.timerRunning = true
  self.timer = hs.timer.doWhile(function() return self.timerRunning end, function() self:tick() end, 1)
  local items = {
    { title = "Stop",  fn = function() self:reset() end },
    { title = "Pause", fn = function() self:pause() end }
  }
  self.menu:setMenu(items)
end


function obj:pause()
  self.timerRunning = false
  local items = {
    { title = "Stop", fn = function() self:reset() end },
    { title = "Resume", fn = function() self:start(true) end }
  }
  self.menu:setMenu(items)
end


return obj
