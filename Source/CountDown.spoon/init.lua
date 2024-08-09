--- === CountDown ===
---
--- Countdown with visual indicator
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/CountDown.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/CountDown.spoon.zip)
---

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "CountDown"
obj.version = "2"
obj.author = "ashfinal <ashfinal@gmail.com> and Daniel Marques <danielbmarques@gmail.com> and Omar El-Domeiri <omar@doesnotexist.com> and Daniel German <dmg@turingmachine.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- This countdown timer has three different progress indicators:

--   horizontal bar at the bottom of the screen (always enabled)
--   Warning: every few minutes, display the minutes left (optional)
--   MenuBar: an icon that displays the current state of the timer (optional)
--            it also displays the time left       
--
--   When the time is up an alert message is displayed.

-- User-configurable variables

--- CountDown.defaultLenMinutes
--- Variable
--- Default timer in minutes. 
obj.defaultLenMinutes = 25

--- CountDown.useLastTimerAsDefault
--- Variable
--- if true, make defaultLenMinutes the last time length used 
obj.useLastTimerAsDefault = true

--- CountDown.nofity
--- Variable
--- set to nil to turn off notification when time's up or provide a hs.notify notification
obj.notify = true

--- CountDown.defaultKeyBindings
--- Variable
--- default key bindings
obj.defaultKeyBindings = {
   startFor      = {{"cmd", "ctrl", "alt"}, "T"},
   startInteractive = {{"cmd", "ctrl", "alt", "shift"}, "T"},
   pauseOrResume = {{"cmd", "ctrl", "alt"}, "P"},
   cancel        = {{"cmd", "ctrl", "alt"}, "C"}
}

--- CountDown.messageDuration
--- Variable
--- Duration of notification messages
obj.messageDuration = 2

--- CountDown.messageAttributes
--- Variable
--- Properties of progress message 
obj.messageAttributes = {atScreenEdge = 0, textSize = 40}

-- bar: progress bar at the bottom of the screen

--- CountDown.barCanvasHeight
--- Variable
--- indicator bar at the bottom of the screen
obj.barCanvasHeight = 5

--- CountDown.barTransparency
--- Variable
--- Transparency for progress bar
obj.barTransparency = 0.8

--- CountDown.barFillColorPassed
--- Variable
--- Color for time passed in progress bar
obj.barFillColorPassed = hs.drawing.color.osx_green

--- CountDown.barFillColorToPass
--- Variable
--- Color for time to pass in progress bar
obj.barFillColorToPass = hs.drawing.color.osx_red

-- alert: what happens when the timer is up?

--- CountDown.alertLen
--- Variable
---   time to show the end-of-time alert. 0 implies do not show
obj.alertLen = 5

--- CountDown.alertSound
--- Variable
---   Sounds to play when time is up. No sound if nil
obj.alertSound = "Sonar"

--- CountDown.alertAttributes
--- Variable
---   how to display timer is up notification
obj.alertAttributes = {atScreenEdge = 1}

-- warning related configuration

--- CountDown.warningShow
--- Variable
---  Do we show progress warnings. A progress warning happens
---  at logarithmic intervals: 1, 2, 4, 8, 16... minutes
---  before timer expiration
obj.warningShow = true

--- CountDown.warningFormat
--- Variable
---   Format to display the warning.
---   It takes two integers: hours and minutes
obj.warningFormat = "Time left %02d:%02d"

--- CountDown.warningshowDuration
--- Variable
--- for how many seconds to show the warning
obj.warningshowDuration = 3

-- menu bar related

--- CountDown.menuBarAlwaysShow
--- Variable
--- If true, always show the menu bar icon.
---   if false, only show when timer active
---   (shows pause, cancel toggle)
obj.menuBarAlwaysShow=false

--- CountDown.menuBarIconIdle
--- Variable
---   icon to show in menu bar when idle
obj.menuBarIconIdle   = "⏰"
--- CountDown.menuBarIconActive
--- Variable
---   icon to show in menu bar when active
obj.menuBarIconActive = "☣️"
--- CountDown.menuBarIconPlay
--- Variable
---   icon for resume playing in menu bar submenu
obj.menuBarIconPlay   = "▶️️"
--- CountDown.menuBarIconPause
--- Variable
---   icon for pause playing in menu bar submenu
obj.menuBarIconPause  = "⏸️"
--- CountDown.menuBarIconStop
--- Variable
---   icon for cancelling timer in menu bar submenu
obj.menuBarIconStop   = "🛑"

-- state variables

obj.barTimer= nil
-- timerRunning true if current timer running
obj.timerRunning = nil 
obj.timer = nil

-- time when timer should end, in absolute seconds
-- since epoch
obj.endingTime = nil
-- minutes the timer is expected to run
--     the actual length might be affected by pausing timer
obj.timerLenMinutes = nil

obj.currentIcon = nil
-- moment the timer is paused
obj.pausedAt = nil
-- status bar
obj.menuBar = nil
-- progress bar related
-- proportion of time that has elapsed [0 to 1]
obj.barProgress = 0
obj.barCanvas = nil

-- events

-- callback when timer is up
-- callback is only called when timer succeeds
-- if timer is cancelled, it is not called
-- takes two parms: event and minutes passed
obj.callback = nil
obj.timerEventResume = "resumed"
obj.timerEventPause = "paused"
obj.timerEventReset = "cancelled"
obj.timerEventStart = "started"
obj.timerEventEnd   = "ended"
obj.timerEventSetProgress   = "setProgress"


function obj:init()
   obj:bar_init()
   obj:menuBar_init()

   obj:reset_timer()
end

-- some support functions

function obj:time_absolute_seconds()
   -- return hs.timer.absoluteTime() in seconds
   local timeNow = hs.timer.absoluteTime()
   return math.floor(timeNow / 1e9)
end

function obj:is_power_of_2(j)
   -- is j a power of 2?
   -- j is float... 
   i = math.floor(j)
   if j ~= i  then
      return false
   end
   i = math.floor(i)
   while (i % 2 == 0) do
      i = i // 2
   end
   return i ==1 
end

function obj:show_message(msg, duration)
   -- display any notification, including warnings
   -- but not the final alert when time is up
   if not duration  then
      duration = obj.messageDuration
   end
   print(">>>>>>>>>>>>>>>>", duration)
   hs.alert.show(msg, obj.messageAttributes, nil, duration)
end

function obj:reset_timer()
   obj.timerRunning = false

   obj:timers_cleanup()
   obj.timeLeft = 0

   obj:bar_reset()
   obj:menuBar_reset()
end

function obj:timers_cleanup()
   if obj.timer then
      obj.timer:stop()
      obj.timer = nil
   end
   if barTimer then
      barTimer:stop()
      barTimer = nil
   end
end

function obj:end_of_timer_notify(requestedMinutes)
  -- end of timer notification
  --
  -- we have 2 ways of notification: event and message
  --
  -- save the window, so we can go back
  -- when user acknowledges the timer
  local currentWin = hs.window.focusedWindow()

  -- do callback if defined
  if obj.callback then
     obj.callback(obj.timerEventEnd, requestedMinutes)
  end

  -- determine which one is the current screen
  if currentWin then
    screen = currentWin:screen()
  else
    screen = hs.screen.mainScreen()
  end
  hs.focus()
  local mainRes = screen:fullFrame()

  if not requestedMinutes then
     message = "Time is up"
  else
     message = string.format("Time is up: %d minutes", requestedMinutes)
  end
  strTime = "Time is " .. os.date("%X")
  
  if obj.alertSound then
     hs.notify.new({
           title = message,
           informativeText = strTime,
           hasActionButton = true,
           withdrawAfter = 100
     }):soundName(obj.alertSound):send()
  end

  if obj.alertLen > 0 then
     hs.alert.show(message, obj.alertAttributes, screen, obj.alertLen)
  end
  -- display alert in active screen
  -- stealing focus, return to where it
  -- when closing window
  if obj.notify then
     hs.dialog.alert(mainRes.x + mainRes.w/2-50,
        mainRes.y + mainRes.h/2-50,
        function(result)
           currentWin:focus()
        end,
        message,
        strTime, "OK")
  end
end

-- indication bar related functions

function obj:bar_init()
  -- initialize all the horizontal bar related values
  obj.barCanvas = hs.canvas.new({x=0, y=0, w=0, h=0}):show()
  obj.barCanvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
  obj.barCanvas:level(hs.canvas.windowLevels.status)
  obj.barCanvas:alpha(obj.barTransparency)
  obj.barCanvas[1] = {
    type = "rectangle",
    action = "fill",
    fillColor = obj.barFillColorPassed,
    frame = {x="0%", y="0%", w="0%", h="100%"}
  }
  obj.barCanvas[2] = {
    type = "rectangle",
    action = "fill",
    fillColor = obj.barFillColorToPass,
    frame = {x="0%", y="0%", w="0%", h="100%"}
  }
end

function obj:bar_updateProgress()
   -- advance the progress bar according to the value of obj.barProgress
   progress = obj.barProgress
   if obj.barCanvas:frame().h == 0 then
      -- Make the canvas actully visible
      local mainScreen = hs.screen.primaryScreen()
      local mainRes = mainScreen:fullFrame()
      obj.barCanvas:frame({
            x=mainRes.x,
            y=mainRes.h-obj.barCanvasHeight,
            w=mainRes.w,
            h=obj.barCanvasHeight})
   end
   if progress >= 1 then
      -- do nothing... the timer is up
   else
      -- advance the timer...
      obj.barCanvas[1].frame.w = tostring(progress)
      obj.barCanvas[2].frame.x = tostring(progress)
      obj.barCanvas[2].frame.w = tostring(1-progress)
   end
end

function obj:bar_reset()
   -- make the canvas invisible
   obj.barCanvas[1].frame.w = "0%"
   obj.barCanvas[2].frame.x = "0%"
   obj.barCanvas[2].frame.w = "0%"
   obj.barCanvas:frame({x=0, y=0, w=0, h=0})
   obj.barProgress = 0
end

function obj:bar_create_timer()
  -- create the horizontal bar timer callback
  minutes = obj.timerLenMinutes
  local mainScreen = hs.screen.primaryScreen()
  local mainRes = mainScreen:fullFrame()
  
  obj.barCanvas:frame(
    {x=mainRes.x,
      y=mainRes.h-obj.barCanvasHeight,
      w=mainRes.w,
      h=obj.barCanvasHeight})
  
  -- compute the minimal step at which the bar will be updated
  -- 
  -- Set minimum visual step to 2px (i.e. Make sure every
  --   trigger updates 2px on screen at least.)
  local minimumStep = 2
  local secCount = math.ceil(60*minutes)
  obj.currentIcon = obj.menuBarIconActive
  obj.loopCount = 0
  
  if mainRes.w/secCount >= minimumStep then
    -- do every second
    barTimer = hs.timer.doEvery(1, function()
        obj:bar_updateProgress()
    end)
  else
    -- we need few seconds to advance two pixels
    local interval = 2/(mainRes.w/secCount)
    barTimer = hs.timer.doEvery(interval,
      function()
        obj:barSetProgresspercentage(obj.barProgress)
      end
    )
  end
end

---- warning related functions

function obj:warning_show(min)
   obj:show_message(string.format(obj.warningFormat, min // 60,  min % 60),
      obj.warningShowDuration)
end

function obj:warning_update()
   if obj.warningShow and obj.timeLeft > 0 then
      minLeft =  obj.timeLeft / 60
      if minLeft < obj.timerLenMinutes and
         minLeft > 0 and obj:is_power_of_2(minLeft)  then
         obj:warning_show(minLeft)
      end
   end
end

------- menuBar bar related functions
function obj:menuBar_init()
   obj.menuBar = hs.menubar.new(obj.menuBarAlwaysShow)
   obj:menuBar_reset()
end

function obj:menuBar_reset()
   obj.menuBar:setTitle(obj.menuBarIconIdle)
   local items = {
      { title = string.format("%s Start %d min", obj.menuBarIconActive, obj.defaultLenMinutes),
         fn = function() obj:startFor(obj.defaultLenMinutes) end
      },
      { title = string.format("%s Start for ... ", obj.menuBarIconActive),
         fn = function() obj:startForInteractive() end
      },
   }
   obj.menuBar:setMenu(items)
   if not obj.menuBarAlwaysShow then
      obj.menuBar:removeFromMenuBar()
   end
end

function obj:menuBar_updateTimerString()
   local minutes = math.floor((obj.timeLeft % 3600) / 60)
   local hours =   math.floor(obj.timeLeft / 3600)
   local seconds = obj.timeLeft % 60 
   local timeString
   if hours > 0 then
      timerString = string.format("%s %d:%02d:%02d", obj.currentIcon, hours, minutes, seconds)
   else
      timerString = string.format("%s %02d:%02d", obj.currentIcon, minutes, seconds)
   end
   obj.menuBar:setTitle(timerString)
end

function obj:menuBar_update(isPaused)
   -- update the icons and textual information in menu bar
   -- if active, indicate time left
   if not obj.menuBar:isInMenuBar() then
      obj.menuBar:returnToMenuBar()
   end
   local label = nil
   if isPaused then
      label = string.format("%s Resume", obj.menuBarIconActive)
      obj.currentIcon = obj.menuBarIconPause
   else
      obj.currentIcon = obj.menuBarIconActive
      label = string.format("%s Pause", obj.menuBarIconPause)
   end
   local items = {
      { title = string.format("%s Stop", obj.menuBarIconStop),
         fn = function() obj:cancel() end },
      { title = label, fn = function() obj:pauseOrResume() end }
   }
   obj.menuBar:setMenu(items)
   obj:menuBar_updateTimerString()
end

function obj:tick()
   -- main timer callback
   -- keeps track of the time passed
   -- ticks every second...
   --   updates barProgress
   --   and potentially issues a warning
   if not obj.timerRunning then
      print("This should not happen!!")
      return
   end
   local timeNow = obj:time_absolute_seconds()
   obj.timeLeft = obj.endingTime - timeNow
   if obj.timeLeft <= 0 then
      obj.timerRunning = false
      -- we need to save this before we reset
      -- and we need to reset before we notify
      local requestedMinutes = obj.timerLenMinutes
      obj:reset_timer()
      obj:end_of_timer_notify(requestedMinutes)
   else --update progress ratio
      obj.barProgress = 1 - obj.timeLeft/(obj.timerLenMinutes * 60)
      obj:warning_update()
      obj:menuBar_updateTimerString()
   end
end

function obj:create_tick_timer()
   obj.endingTime = obj:time_absolute_seconds() + obj.timerLenMinutes * 60
   obj.timerRunning = true
   obj:tick()
   obj.timer = hs.timer.doWhile(function() return obj.timerRunning end,
      function() obj:tick() end,
      1)
end

-- API -------------------------------


--- CountDown:startFor(minutes, callback)
--- Method
--- Start a countdown for `minutes` minutes immediately. Calling this method again will kill the existing countdown instance.
---
--- Parameters:
---  * minutes - How many minutes
---              Defaults to obj.defaultLenMinutes
---  * callback: optional: a function to call when the timer 
---            is up. it takes one parameters (minutes)
---            the minutes that were requested.
---            The callback is not called if timer is cancelled
--- Returns:
---  * None
function obj:startFor(minutes, callback)
   if not minutes  then
      minutes = obj.defaultLenMinutes
   end
   if obj.timerRunning then
      obj:show_message("Error. Timer is already running. It is not possible to start another one.")
      return
   end
   if math.type(minutes) ~= "integer"  then
      message = string.format("Error. Minutes should be an integer [%s]", tostring(minutes))
      obj:show_message(message)
      return
   end
   if minutes < 0 then
      message = string.format("Error. Trying to start a timer for negative minutes [%d]", minutes)
      obj:show_message(message)
      return
   end
   if callback and type(callback) ~= 'function' then
      obj:show_message("Error. Second parameter should be a function")
      return
   end

   obj.timerLenMinutes = minutes
   obj.callback = callback
   
   obj.requestedMinutes = tostring(minutes) .. " minutes"

   -- we create two timers, one for the horizontal bar and one for 
   -- keeping track of the time
   -- the reason is that we update the bar much less frequently than the time
   
   obj:bar_create_timer()

   obj:create_tick_timer()

   obj:menuBar_update(false)

   if obj.useLastTimerAsDefault then
      obj.defaultLenMinutes = minutes
   end
   obj:show_message(string.format("Timer started for %d minutes", obj.defaultLenMinutes))

   if callback then
      obj.callback(obj.timerEventStart, 0)
   end

   return self
end

--- CountDown:startUntil(time, callback)
--- Method
--- Start a countdown until time indicated in parameter.
---
--- Parameters:
---  * time - A string of the form: hh:mm:ss, or mm:ss
---           if time is before current time, assume it is
---           for tomorrow.
---  * callback: optional: a function to call when the timer 
---            is up. it takes one parameters (minutes)
---            the minutes that were requested. 
--- Returns:
---  * None
function obj:startUntil(time, callback)
   local message
   local _, _, hour,min= string.find(time, "(%d+):(%d+)")
   if hour and min then
      totalMin = hour * 60 + min
      currentTime = os.date("*t")
      currentMin = currentTime["hour"] * 60 + currentTime["min"]
      -- modulus is always positive
      min = (totalMin - currentMin) % (24 * 60)
      obj:startFor(min, callback)
   else
      message = string.format("Illegal time [%s] provided. Must be <hour>:<min>", time)
   end
   hs.alert.show(message, nil, hs.screen.mainScreen())
end

--- CountDown:startUntil(time)
--- Method
--- Start a countdown until time indicated in parameter.
---
--- Parameters:
---  * callback: optional: a function to call when the timer 
---            is up. it takes one parameters (minutes)
---            the minutes that were requested. 
function obj:startForInteractive(callback)
  -- query the user for the timer duration
  -- and start it 
  local currentWin = hs.window.focusedWindow()
  hs.focus()
  local button, time = hs.dialog.textPrompt("Enter time", "in minutes or specific time (e.g. 10:30)",
    string.format("%s", obj.defaultLenMinutes), "OK", "Cancel")
  if button == "OK" then
    obj.requestedMinutes = time
    if string.find(time, ":") then
      -- time given as absolute time
      -- we need to convert time to seconds
      -- if time is before current time, assume it is tomorrow
      obj:startUntil(time, callback)
    else
       -- assume it is minutes, given as a string
       local mins = tonumber(time)
       if not mins then
          message = string.format("Illegal number [%s]", time)
          hs.alert.show(message, nil, hs.screen.mainScreen())
       else
          obj:startFor(mins, callback)
       end
    end
  end
  if currentWin then
    currentWin:focus()
  end
end

--- CountDown:pauseOrResume()
--- Method
--- Pause or resume the existing countdown.
---
--- Parameters:
---  * None
--- Returns:
---  * None
function obj:pauseOrResume()
   -- if the timer is paused, we need to offset
   -- the starting time for as long as the timer is paused

   if obj.timer then

      if obj.timer:running() then
         obj.pausedAt = obj:time_absolute_seconds()
         -- stop callbacks 
         obj.timer:stop()
         barTimer:stop()

         obj:menuBar_update(true)
         if obj.callback then
            obj.callback(obj.timerEventPause, obj.timeLeft/60)
         end
         obj:show_message("Timer paused")
      else
         -- offset the starting time by as many seconds as we were paused
         local pausedSeconds = obj:time_absolute_seconds() - obj.pausedAt
         obj.endingTime = obj.endingTime + pausedSeconds
         obj.pausedAt = nil
         -- restart timers
         obj.timer:start()
         barTimer:start()

         obj:menuBar_update(false)
         if obj.callback then
            obj.callback(obj.timerEventResume, obj.timeLeft/60)
         end
         obj:show_message("Timer resumed")
      end
   end
end

--- CountDown:cancel()
--- Method
---  Reset the timer
---
--- Parameters:
---  * None
--- Returns:
---  * None
function obj:cancel()
   if obj.timerRunning then
      local minLeft = obj.timeLeft/60
      if obj.callback then
         obj.callback(obj.timerEventReset, minLeft)
      end
      obj:reset_timer()
      obj:show_message(
         string.format("Timer was cancelled (time left %3.1f min).", minLeft))
   else
      obj:show_message("Error. Timer not running ")
   end
end

--- CountDown:setProgress(progress)
--- Method
---  Set the progress of visual indicator to progress.
---
--- Parameters:
---  * progress
---    a relative number specifying the new progress (0.0 - 1.0)
--- Returns:
---  * None
function obj:setProgress(progress)
   if obj.timerRunning then
      -- obj.endingTime containts ending time in seconds
      -- timerLenMinutes starting time
      local newMinutesLeft = obj.timerLenMinutes * (1- progress)
      obj.endingTime = obj:time_absolute_seconds() + newMinutesLeft *60
      obj:show_message(
         string.format("Timer reset to %.1f%% (%.1f minutes left)",
            progress*100, newMinutesLeft))
      if obj.callback then
         obj.callback(obj.timerEventSetProgress, newMinutesLeft)
      end
   else
      obj:show_message("Error. Timer not running ")
   end
end


--- CountDown:bindHotkeys(mapping)
--- Method
--- Bind hotkeys for this spoon
---
--- Parameters:
---  * mapping: a table with the callbacks
--- Returns:
---  * None
function obj:bindHotkeys(mapping)
   local def = {
      startFor           = function() obj:startFor() end,
      startInteractive   = function() obj:startForInteractive() end,
      cancel             = function() obj:cancel() end,
      pauseOrResume      = function() obj:pauseOrResume() end
   }

   if mapping then
      hs.spoons.bindHotkeysToSpec(def, mapping)
   else
      hs.spoons.bindHotkeysToSpec(def, obj.defaultKeyBindings)
   end
end

return obj
