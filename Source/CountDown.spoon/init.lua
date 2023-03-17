--- === CountDown ===
---
--- Countdown with visual indicator
---

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "CountDown"
obj.version = "1.1"
obj.author = "ashfinal <ashfinal@gmail.com> and Daniel Marques <danielbmarques@gmail.com> and Omar El-Domeiri <omar@doesnotexist.com> and Daniel German <dmg@turingmachine.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.canvas = nil
obj.timer = nil
obj.startTime = nil
obj.timerLen = nil

obj.canvasHeight = 5
obj.transparency = 0.8
obj.fillColorPassed = hs.drawing.color.osx_red
obj.fillColorToPass = hs.drawing.color.osx_green
obj.currentIcon = nil

-- default key bindings
obj.defaultKeyBindings = {
   start = {{"cmd", "ctrl", "alt"}, "T"},
   startWithTime = {{"cmd", "ctrl", "alt", "shift"}, "T"},
}


-- should the icon always show?
obj.alwaysShow=true
-- default timer in minutes

obj.defaultLenMin = 25
-- time to show the alert
-- 0 implies do not show
obj.alertLenMin = 5
-- Font size for alert
obj.alertTextSize = 80
-- set to nil to turn off notification when time's up or provide a hs.notify notification
obj.notification = nil
-- obj.notification = hs.notify.new({ title = "Done! 🍒", withdrawAfter = 0})
obj.sound = "Sonar"
-- obj.sound = hs.sound.getByFile("System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Resources/Sounds")

obj.iconIdle = "⏰"
obj.iconActive = "☣️"
obj.iconPlay = "▶️️"
obj.iconPause = "⏸️"
obj.iconStop = "🛑"
obj.lenMin = nil
-- percentage of advance for the time
obj.progress = 0

-- moment the timer is paused
obj.pausedAt = nil

function obj:init()
   self.menu = hs.menubar.new(obj.alwaysShow)
   self.canvas = hs.canvas.new({x=0, y=0, w=0, h=0}):show()
   self.canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
   self.canvas:level(hs.canvas.windowLevels.status)
   self.canvas:alpha(obj.transparency)
   self.canvas[1] = {
      type = "rectangle",
      action = "fill",
      fillColor = obj.fillColorPassed,
      frame = {x="0%", y="0%", w="0%", h="100%"}
   }
   self.canvas[2] = {
      type = "rectangle",
      action = "fill",
      fillColor = obj.fillColorToPass,
      frame = {x="0%", y="0%", w="0%", h="100%"}
   }
   obj:reset()
end

function obj:menu_items(isPaused)
   local label = nil
   if isPaused then
      label = string.format("%s Resume", obj.iconActive)
      obj.currentIcon = obj.iconPause
   else
      obj.currentIcon = obj.iconActive
      label = string.format("%s Pause", obj.iconPause)
   end
   local items = {
      { title = string.format("%s Stop", obj.iconStop),
        fn = function() obj:reset() end },
      { title = label, fn = function() obj:pauseOrResume() end }
   }
   self.menu:setMenu(items)
   obj:updateTimerString()
end

function obj:query_time_and_start()
   local button, time = hs.dialog.textPrompt("Enter time", "in minutes", string.format("%s", obj.defaultLenMin), "Ok", "Cancel")
   if button == "Ok" then
      local min = tonumber(time)
      if min then
         obj:startFor(min)
         message = string.format("Started timer for %d minutes", min)
         obj.defaultLenMin = min
      else
         message = string.format("Illegal number [%s]", time)
      end
      hs.alert.show(message, nil, hs.screen.mainScreen())
   end
end


function obj:menu_items_start()
   local items = {
      { title = string.format("%s Start %d min", obj.iconActive, obj.defaultLenMin),
        fn = function() obj:startFor(obj.defaultLenMin) end
      },
      { title = string.format("%s Start for ... ", obj.iconActive),
        fn = function() obj:query_time_and_start() end
      },
   }
   self.menu:setMenu(items)
end

--- CountDown:startFor(minutes)
--- Method
--- Start a countdown for `minutes` minutes immediately. Calling this method again will kill the existing countdown instance.
---
--- Parameters:
---  * minutes - How many minutes

local function canvas_cleanup()
    obj.canvas[1].frame.w = "0%"
    obj.canvas[2].frame.x = "0%"
    obj.canvas[2].frame.w = "0%"
    obj.canvas:frame({x=0, y=0, w=0, h=0})
end

local function timers_cleanup()
   if obj.timerBar then
      obj.timerBar:stop()
      obj.timerBar = nil
   end
   if obj.timer then
      obj.timer:stop()
      obj.timer = nil
   end
end

function obj:reset()
   canvas_cleanup()
   timers_cleanup()
   
   obj.menu:setTitle(obj.iconIdle)
   obj:menu_items_start()
   obj.timerRunning = false
   
   if not obj.alwaysShow then
      obj.menu:removeFromMenuBar()
   end
end

-- update the timer in the status bar
--
function obj:updateTimerString()
   local minutes = math.floor(self.timeLeft / 60)
   local seconds = self.timeLeft - (minutes * 60)
   local timerString = string.format("%s %02d:%02d", obj.currentIcon, minutes, seconds)
   self.menu:setTitle(timerString)
end

function obj:create_bar_timer(minutes)
   local mainScreen = hs.screen.primaryScreen()
   local mainRes = mainScreen:fullFrame()
   obj.canvas:frame({x=mainRes.x, y=mainRes.h-obj.canvasHeight, w=mainRes.w, obj.canvasHeight})
   -- Set minimum visual step to 2px (i.e. Make sure every trigger updates 2px on screen at least.)

   local minimumStep = 2
   local secCount = math.ceil(60*minutes)
   obj.currentIcon = obj.iconActive
   obj.loopCount = 0
   
   if mainRes.w/secCount >= minimumStep then
      -- do every second
      obj.timerBar = hs.timer.doEvery(1, function()
                                         obj:setProgress(obj.progress)
      end)
   else
      -- we need few seconds to advance two pixels
      local interval = 2/(mainRes.w/secCount)
      obj.timerBar = hs.timer.doEvery(interval,
                                      function()
                                         obj:setProgress(obj.progress)
                                      end
      )
   end

end

function obj:time_absolute_seconds()
   -- return hs.timer.absoluteTime() in seconds
   local timeNow = hs.timer.absoluteTime()
   return math.floor(timeNow / 1e9)
end

function obj:tick()
   -- ticks every second...
   local timeNow = obj:time_absolute_seconds()
   obj.timeLeft = (obj.startTime + obj.lenMin * 60) - timeNow
   if obj.timeLeft <= 0 then
      obj.timeLeft = 0
      obj:reset()
      obj:notify()
      obj.lenMin = nil
      obj.progress = 0
   else --update progress ratio
      obj.progress = 1 - obj.timeLeft/(obj.lenMin * 60)
   end
end

function obj:create_time_timer(minutes)
   obj.timerRunning = true
   obj.lenMin = minutes
   obj.timeLeft = minutes * 60
   obj.startTime = obj:time_absolute_seconds()
   obj.timer = hs.timer.doWhile(function() return obj.timerRunning end,
      function() obj:tick() end,
      1)
end

function obj:startFor(minutes)
   if obj.timer then
      -- reset current timer and do nothing
      obj:reset()
   else
      obj.lenMin = minutes
      -- let us keep two timers.
      -- one for time, one for the bar
      -- the visual one does not trigger the alert
      -- only the time one

      obj:create_bar_timer(minutes)
--
      obj:create_time_timer(minutes)
      obj:menu_items(false)
    end

   return self
end


--- CountDown:pauseOrResume()
--- Method
--- Pause or resume the existing countdown.
---
--- Parameters:
---  * None

function obj:pauseOrResume()
   -- if the timer is paused, we need to offset
   -- the starting time for as long as the timer is paused

   if obj.timer and obj.timerBar then
      if obj.timer:running() then
         obj.pausedAt = obj:time_absolute_seconds()
         obj.timer:stop()
         obj.timerBar:stop()

         obj:menu_items(true)

      else
         -- offset the starting time by as many seconds as we were paused
         local pausedSeconds = obj:time_absolute_seconds() - obj.pausedAt
         obj.startTime = obj.startTime + pausedSeconds
         obj.pausedAt = nil
         obj.timer:start()
         obj.timerBar:start()

         obj:menu_items(false)
      end
    end
end

function obj:notify()
   strTime = "Time is " .. os.date("%X")
   message = "Time (" .. obj.lenMin .. " mins) is up!"
   
   hs.notify.new({
         title = message,
         informativeText = strTime,
         hasActionButton = true,
         withdrawAfter = 100
   }):soundName(obj.sound):send()

   hs.alert.show(message, nil, hs.screen.mainScreen(), obj.alertLenMin)
   hs.dialog.blockAlert(message, strTime)
end

--⭕ ☣️  ⏸️
--- CountDown:setProgress(progress)
--- Method
--- Set the progress of visual indicator to `progress`.
---
--- Parameters:
---  * progress - an number specifying the value of progress (0.0 - 1.0)

function obj:setProgress(progress)
    if obj.canvas:frame().h == 0 then
        -- Make the canvas actully visible
        local mainScreen = hs.screen.primaryScreen()
        local mainRes = mainScreen:fullFrame()
        obj.canvas:frame({x=mainRes.x, y=mainRes.h-obj.canvasHeight, w=mainRes.w, h=obj.canvasHeight})
    end
    obj:updateTimerString()
    if progress >= 1 then
       -- do nothing... the other timer will finish the timer
    else
       -- advance the timer...
       obj.canvas[1].frame.w = tostring(progress)
       obj.canvas[2].frame.x = tostring(progress)
       obj.canvas[2].frame.w = tostring(1-progress)
    end
end

function obj:bindHotkeys(mapping)
   local def = {
      start           = function() obj:startFor(obj.defaultLenMin) end,
      startWithTime   = function() obj:query_time_and_start() end
   }

   if mapping then
      hs.spoons.bindHotkeysToSpec(def, mapping)
   else
      hs.spoons.bindHotkeysToSpec(def, obj.defaultKeyBindings)
   end

end




return obj
