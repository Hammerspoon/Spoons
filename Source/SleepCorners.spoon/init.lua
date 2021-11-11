
--- === SleepCorners ===
---
--- Trigger or prevent screen saver/sleep by moving your mouse pointer to specified hot corners on your screen.
---
--- While this functionality is provided by macOS in the Mission Control System Preferences, it doesn't provide any type of visual feedback so it's easy to forget which corners have been assigned which roles.
---
--- For best results while using this spoon, it is recommended that you disable "Start Screen Saver" and "Disable Screen Saver" if they are currently assigned to a corner with the Mission Control System Preferences Panel as this Spoon can't override them and may result in confusing or incorrect behavior.
---
--- The visual feed back provided by this spoon is of a small plus (for triggering sleep now) or a small minus (to prevent sleep) when the mouse pointer is moved into the appropriate corner. This feedback was inspired by a vague recollection of an early Mac screen saver (After Dark maybe?) which provided similar functionality. If someone knows for certain, please inform me and I will give appropriate attribution.
---
--- Note that sleep prevention is not guaranteed; macOS may override our attempts at staying awake in extreme situations (CPU temperature dangerously high, low battery, etc.) See `hs.caffeinate` for more details.
---
--- Download: https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SleepCorners.spoon.zip

-- local logger  = require("hs.logger")

local canvas     = require("hs.canvas")
local caffeinate = require("hs.caffeinate")
local screen     = require("hs.screen")
local image      = require("hs.image")
local timer      = require("hs.timer")
local fnutils    = require("hs.fnutils")
local eventtap   = require("hs.eventtap")
local alert      = require("hs.alert")
local spoons     = require("hs.spoons")

local obj    = {
-- Metadata
    name      = "SleepCorners",
    author    = "A-Ron",
    homepage  = "https://github.com/Hammerspoon/Spoons",
    license   = "MIT - https://opensource.org/licenses/MIT",
    spoonPath = spoons.scriptPath(),
    spoonMeta = "placeholder for _coresetup metadata creation",
}
-- version is outside of obj table definition to facilitate its auto detection by
-- external documentation generation scripts
obj.version   = "0.1.1"

local metadataKeys = {} ; for k, v in fnutils.sortByKeys(obj) do table.insert(metadataKeys, k) end

local defaultLevel = canvas.windowLevels.screenSaver

obj.__index = obj

-- collection of details that probably shouldn't be externally changed but may help
-- in debugging

local _internals = {}

-- The following are wrapped by obj's __index/__newindex metamethods so they appear
-- as regular variables and are thus documented as such

--- SleepCorners.sleepDelay
--- Variable
--- Specifies the number of seconds, default 2, the mouse pointer must remain within the trigger area of the sleep now corner in order to put the system's display to sleep.
---
--- When the mouse pointer moves into the trigger area for the sleep now hot corner, visual feedback will be provided for the user. If the user does not move the mouse pointer out of the trigger area within the number of seconds specified by this variable, display sleep will be activated.
_internals.sleepDelay = 2

--- SleepCorners.sleepScreen
--- Variable
--- Specifies the screen on which the sleep corners are made active. Defaults to the value returned by `hs.screen.primaryScreen()`.
---
--- This variable may be set to an `hs.screen` userdata object or a function which returns an `hs.screen` userdata object. For example, to make the sleep corners active on the screen with the currently focused window, you could use the following function:
---
---     SleepCorners.sleepScreen = function()
---         return hs.screen.mainScreen()
---     end
_internals.sleepScreen = screen.primaryScreen()

--- SleepCorners.sleepNowCorner
--- Variable
--- Specifies the location of the sleep now corner on the screen. Defaults to "LL".
---
--- This variable may be set to one of the following string values:
---
---   `*`  - Do not provide a sleep now corner (disable this feature)
---   `UL` - Upper left corner
---   `UR` - Upper right corner
---   `LR` - Lower right corner
---   `LL` - Lower left corner
_internals.sleepNowCorner = "LL"

--- SleepCorners.neverSleepCorner
--- Variable
--- Specifies the location of the never sleep corner on the screen. Defaults to "LR".
---
--- This variable may be set to one of the following string values:
---
---   * `*`  - Do not provide a sleep now corner (disable this feature)
---   * `UL` - Upper left corner
---   * `UR` - Upper right corner
---   * `LR` - Lower right corner
---   * `LL` - Lower left corner
_internals.neverSleepCorner = "LR"

--- SleepCorners.feedbackSize
--- Variable
--- Specifies the height and width in screen pixels, default 20, of the visual feedback to be displayed when the mouse pointer moves into one of the recognized hot corners
_internals.feedbackSize = 20

--- SleepCorners.triggerSize
--- Variable
--- Specifies the height and width in screen pixels, default 2, of the trigger area for the recognized hot corners.
---
--- The trigger area, which may be smaller than the [SleepCorners.feedbackSize](#feedbackSize) area, is the region which the mouse pointer must be moved into before the specified feedback or sleep activity will occur.
_internals.triggerSize = 2

--- SleepCorners.preferSleepNow
--- Variable
--- Specifies which action should be preferred if both the sleep now and never sleep hot corners are assigned to the same location on the screen. The default is false.
---
--- If this variable is set to `true`, then sleep now action will be triggered if both hot corners are assigned to the same location on the screen. If this variable is set to `false`, then the never sleep action will be triggered.
---
--- Note that this variable has no effect if the hot corners are distinct (i.e. are not assigned to the same corner)
_internals.preferSleepNow = false

--- SleepCorners.immediateSleepModifiers
--- Variable
--- A table, default `{ fn = true }`, specifying keyboard modifiers which if held when the mouse pointer enters the sleep now hot corner will trigger sleep immediately rather then delay for [SleepCorners.sleepDelay](#sleepDelay) seconds.
---
--- Notes:
---  * This variable may be set to nil or an empty table, disabling the immediate sleep option, or a table containing one or more of the following keys:
---   * `fn`    - Set to true to require that the `Fn` key be pressed. May not be available on all keyboards, especially non-Apple ones.
---   * `cmd`   - Set to true to require that the Command (⌘) key be pressed
---   * `alt`   - Set to true to require that the Alt (or Option) (⌥) key be pressed
---   * `shift` - Set to true to require that the Shift (⇧) key be pressed
---   * `ctrl`  - Set to true to require that the Control (^) key be pressed
---  * If this table contains multiple keys, then all of the specified modifiers must be pressed for immediate sleep to take affect.
_internals.immediateSleepModifiers = { fn = true }

--- SleepCorners.sleepNowShouldLock
--- Variable
--- Specifies whether the sleep now corner should trigger the display sleep or lock the users session. Defaults to false.
---
--- Notes:
---  * When this variable is set to true, triggering the sleep now corner will lock the users session. When this variable is false, the display will be put to sleep instead.
---  * Note that depending upon the user's settings in the Security & Privacy System Preferences, triggering the display sleep may also lock the user session immediately.
_internals.sleepNowShouldLock = false

--- SleepCorners.immediateSleepShouldLock
--- Variable
--- Specifies whether the sleep now corner, when the modifiers defined for [SleepCorners.immediateSleepModifiers](#immediateSleepModifiers) are also held, should trigger the display sleep or lock the users session. Defaults to true.
---
--- Notes:
---  * When this variable is set to true, triggering the sleep now corner for immediate sleep will lock the users session. When this variable is false, the display will be put to sleep instead.
---  * Note that depending upon the user's settings in the Security & Privacy System Preferences, triggering the display sleep may also lock the user session immediately.
_internals.immediateSleepShouldLock = true

--- SleepCorners.neverSleepLockModifiers
--- Variable
--- A table, default `{ fn = true }`, specifying keyboard modifiers which if held when the mouse pointer enters the never sleep hot corner will disable display sleep and leave it disabled even if the mouse pointer leaves the hot corner. While the never sleep lock is in effect the never sleep visual feedback will remain visible in the appropriate corner of the screen. The never sleep lock may is unlocked when you move the mouse pointer back into the never sleep corner with the modifiers held down a second time or move the mouse pointer into the sleep now corner.
---
--- Notes:
---  * This variable may be set to nil or an empty table, disabling the never sleep lock option, or a table containing one or more of the following keys:
---   * `fn`    - Set to true to require that the `Fn` key be pressed. May not be available on all keyboards, especially non-Apple ones.
---   * `cmd`   - Set to true to require that the Command (⌘) key be pressed
---   * `alt`   - Set to true to require that the Alt (or Option) (⌥) key be pressed
---   * `shift` - Set to true to require that the Shift (⇧) key be pressed
---   * `ctrl`  - Set to true to require that the Control (^) key be pressed
---  * If this table contains multiple keys, then all of the specified modifiers must be pressed for the never sleep lock to be triggered.
_internals.neverSleepLockModifiers = { fn = true }

local neverSleepSymbol = [[
1*******2
*       *
*       *
*       *
*  a*a  *
*       *
*       *
*       *
4*******3]]

local sleepNowSymbol = [[
1*******2
*       *
*       *
*   c   *
*  a*a  *
*   c   *
*       *
*       *
4*******3]]

local validScreenCorners = { "UL", "UR", "LR", "LL", "*" }
local validModifierKeys  = { "fn", "alt", "shift", "cmd", "control" }

local _neverSleepCanvas  = canvas.new{
    h = _internals.feedbackSize,
    w = _internals.feedbackSize
}
local _sleepNowCanvas = canvas.new{
    h = _internals.feedbackSize,
    w = _internals.feedbackSize
}

-- checks two tables with key-value pairs for truthiness equivalence
--
-- assumes that a value of false for a key in one table is equivalent to the
-- key being absent in the other table (basically that the value = nil).
local truthinessMatch = function(tableA, tableB)
    local isGood = true
    for k,v in pairs(tableA) do
        if v and not tableB[k] then
            isGood = false
            break
        end
    end
    if isGood then
        for k,v in pairs(tableB) do
            if v and not tableA[k] then
                isGood = false
                break
            end
        end
    end
    return isGood
end

local lastSleepSetting = caffeinate.get("displayIdle")
local neverSleepFunction = function(c, m, i, x, y)
    -- this corner is disabled so skip
    if _internals.neverSleepCorner == "*" then return end
    -- if we're being displayed for reference, skip the triggering
    if _internals._showTimer then return end

    if m == "mouseEnter" then
        if not _internals._neverSleepLockOn then
            lastSleepSetting = caffeinate.get("displayIdle")
        end

        if next(_internals.neverSleepLockModifiers) then
            local currentMods = eventtap.checkKeyboardModifiers()
            -- purge the modifiers we don't care about
            for k,v in pairs(currentMods) do
                if not fnutils.contains(validModifierKeys, k) then currentMods[k] = nil end
            end

            if truthinessMatch(currentMods, _internals.neverSleepLockModifiers) then
                _internals._neverSleepLockOn = not _internals._neverSleepLockOn
            end
        end

        caffeinate.set("displayIdle", true)
        _neverSleepCanvas["image"].action = "strokeAndFill"
    elseif m == "mouseExit" then
        if not _internals._neverSleepLockOn then
            caffeinate.set("displayIdle", lastSleepSetting)
            _neverSleepCanvas["image"].action = "skip"
        end
    end
end

local sleepNowFunction = function(c, m, i, x, y)
    -- this corner is disabled so skip
    if _internals.sleepNowCorner == "*" then return end
    -- if we're being displayed for reference, skip the triggering
    if _internals._showTimer then return end

    if _internals._neverSleepLockOn then
        _internals._neverSleepLockOn = false
        neverSleepFunction(c, "mouseExit", i, x, y)
    end

    if m == "mouseEnter" then
        if _internals._sleepNowTimer then
            print("*** sleep delay timer already exists and shouldn't; resetting")
            _internals._sleepNowTimer:stop()
            _internals._sleepNowTimer = nil
        end

        local doImmediateSleep = next(_internals.immediateSleepModifiers) and true or false

        if next(_internals.immediateSleepModifiers) then
            local currentMods = eventtap.checkKeyboardModifiers()
            -- purge the modifiers we don't care about
            for k,v in pairs(currentMods) do
                if not fnutils.contains(validModifierKeys, k) then currentMods[k] = nil end
            end

            doImmediateSleep = truthinessMatch(currentMods, _internals.immediateSleepModifiers)
        end

        if doImmediateSleep then
            if _internals.immediateSleepShouldLock then
                caffeinate.lockScreen()
            else
                caffeinate.startScreensaver()

-- allows the user to lift the modifier keys without it being considered an "event" that
-- should wake up the display; only really matters if immediateSleepShouldLock is false and
-- Require Password in the Security & Privacy System Preferences is not "immediately"
                _internals._swallowModifierKeys = eventtap.new({ eventtap.event.types.flagsChanged }, function(ev)
                    return true
                end):start()
                _internals._clearModifierSwallow = timer.doAfter(_internals.sleepDelay, function()
                    _internals._clearModifierSwallow:stop()
                    _internals._clearModifierSwallow = nil
                    _internals._swallowModifierKeys:stop()
                    _internals._swallowModifierKeys = nil
                end)

            end
        else
            _internals._sleepNowTimer = timer.doAfter(obj.sleepDelay, function()
                _internals._sleepNowTimer:stop()
                _internals._sleepNowTimer = nil
                if _internals.sleepNowShouldLock then
                    caffeinate.lockScreen()
                else
                    caffeinate.startScreensaver()
                end
            end)
        end
        _sleepNowCanvas["image"].action = "strokeAndFill"
    elseif m == "mouseExit" then
        if _internals._sleepNowTimer then
            _internals._sleepNowTimer:stop()
            _internals._sleepNowTimer = nil
        end
        if _internals._clearModifierSwallow then _internals._clearModifierSwallow:fire() end
        _sleepNowCanvas["image"].action = "skip"
    end
end

_neverSleepCanvas:mouseCallback(neverSleepFunction)
                 :behavior("canJoinAllSpaces")
                 :level(defaultLevel + (_internals.preferSleepNow and 0 or 1))
_neverSleepCanvas[#_neverSleepCanvas + 1] = {
    type                = "rectangle",
    id                  = "activator",
    strokeColor         = { alpha = 0 },
    fillColor           = { alpha = 0 },
    frame               = {
        x = 0,
        y = 0,
        h = _internals.triggerSize,
        w = _internals.triggerSize
    },
    trackMouseEnterExit = true,
}
_neverSleepCanvas[#_neverSleepCanvas + 1] = {
    type   = "image",
    id     = "image",
    action = "skip",
    image  = image.imageFromASCII(neverSleepSymbol, {
        { fillColor = { white = 1, alpha = .5 }, strokeColor = { alpha = 1 } },
        { fillColor = { alpha = 0 }, strokeColor = { alpha = 1 } },
    })
}

_sleepNowCanvas:mouseCallback(sleepNowFunction)
               :behavior("canJoinAllSpaces")
               :level(defaultLevel + (_internals.preferSleepNow and 1 or 0))
_sleepNowCanvas[#_sleepNowCanvas + 1] = {
    type                = "rectangle",
    id                  = "activator",
    strokeColor         = { alpha = 0 },
    fillColor           = { alpha = 0 },
    frame               = {
        x = 0,
        y = 0,
        h = _internals.triggerSize,
        w = _internals.triggerSize
    },
    trackMouseEnterExit = true,
}
_sleepNowCanvas[#_sleepNowCanvas + 1] = {
    type   = "image",
    id     = "image",
    action = "skip",
    image  = image.imageFromASCII(sleepNowSymbol, {
        { fillColor = { white = 1, alpha = .5 }, strokeColor = { alpha = 1 } },
        { fillColor = { alpha = 0 }, strokeColor = { alpha = 1 } },
    })
}

local positionCanvas = function(c, p)
    local frame = (type(_internals.sleepScreen) ~= "userdata" and _internals.sleepScreen() or _internals.sleepScreen):fullFrame()
    if p == "UL" then
        c:frame{
            x = frame.x,
            y = frame.y,
            h = _internals.feedbackSize,
            w = _internals.feedbackSize
        }
        c["activator"].frame = {
            x = 0,
            y = 0,
            h = _internals.triggerSize,
            w = _internals.triggerSize
        }
    elseif p == "UR" then
        c:frame{
            x = frame.x + frame.w - _internals.feedbackSize,
            y = frame.y,
            h = _internals.feedbackSize,
            w = _internals.feedbackSize
        }
        c["activator"].frame = {
            x = _internals.feedbackSize - _internals.triggerSize,
            y = 0,
            h = _internals.triggerSize,
            w = _internals.triggerSize
        }
    elseif p == "LR" then
        c:frame{
            x = frame.x + frame.w - _internals.feedbackSize,
            y = frame.y + frame.h - _internals.feedbackSize,
            h = _internals.feedbackSize,
            w = _internals.feedbackSize
        }
        c["activator"].frame = {
            x = _internals.feedbackSize - _internals.triggerSize,
            y = _internals.feedbackSize - _internals.triggerSize,
            h = _internals.triggerSize,
            w = _internals.triggerSize
        }
    elseif p == "LL" then
        c:frame{
            x = frame.x,
            y = frame.y + frame.h - _internals.feedbackSize,
            h = _internals.feedbackSize,
            w = _internals.feedbackSize
        }
        c["activator"].frame = {
            x = 0,
            y = _internals.feedbackSize - _internals.triggerSize,
            h = _internals.triggerSize,
            w = _internals.triggerSize
        }
    elseif p == "*" then -- technically it still exists, but it has 0 dimensions
        c:frame{
            x = 0,
            y = 0,
            h = 0,
            w = 0,
        }
    end
end

_internals._sleepNowCanvas   = _sleepNowCanvas
_internals._neverSleepCanvas = _neverSleepCanvas

_internals._neverSleepLockOn = false

-- we use newWithActiveScreen in case they've set sleepScreen to a function
-- which returns the main screen (i.e. the screen with the currently focused
-- window)
_internals._screenWatcher = screen.watcher.newWithActiveScreen(function(state)
    positionCanvas(_sleepNowCanvas, _internals.sleepNowCorner)
    positionCanvas(_neverSleepCanvas, _internals.neverSleepCorner)
end)

--- SleepCorners:isActive() -> boolean
--- Method
--- Returns whether or not the sleep corners are currently active
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if the sleep corners are currently active or `false` if they are not
---
--- Notes:
---  * This method only identifies whether or not the SleepCorners spoon has been started; it does not check whether or not the specified corners have been set to a location of "*" with [SleepCorners.sleepNowCorner](#sleepNowCorner) or [SleepCorners.neverSleepCorner](#neverSleepCorner).
---  * If you want to check to see if SleepCorners has been started and that at least one of the corners is assigned to a corner, you should use something like `SleepCorners:isActive() and (SleepCorners.sleepNowCorner ~= "*" or SleepCorners.neverSleepCorner ~= "*")`
obj.isActive = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    return _sleepNowCanvas:isShowing()
end

--- SleepCorners:start() -> self
--- Method
--- Starts monitoring the defined sleep corners to allow triggering or preventing the system display  sleep state.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the SleepCorners spoon object
---
--- Notes:
---  * has no effect if SleepCorners has already been started
obj.start = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if not self:isActive() then
        positionCanvas(_sleepNowCanvas, _internals.sleepNowCorner)
        positionCanvas(_neverSleepCanvas, _internals.neverSleepCorner)

        _internals._neverSleepLockOn = false
        lastSleepSetting = caffeinate.get("displayIdle")

        _sleepNowCanvas:show()
        _neverSleepCanvas:show()
        _internals._screenWatcher:start()
    end
    return self
end

--- SleepCorners:stop() -> self
--- Method
--- Stop monitoring the defined sleep corners.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the SleepCorners spoon object
---
--- Notes:
---  * has no effect if SleepCorners has already been stopped
---  * if SleepCorners was active, this method will return the display idle sleep setting back to its previous state and reset the never sleep lock if it has been triggered.
obj.stop = function(self)
    -- in case called as function
    if self ~= obj then self = obj end

    if self:isActive() then
        -- clear any existing timers
        if _internals._showTimer then _internals._showTimer:fire() end
        if _internals._clearModifierSwallow then _internals._clearModifierSwallow:fire() end
        if _internals._sleepNowTimer then
            _internals._sleepNowTimer:stop()
            _internals._sleepNowTimer = nil
        end

        _internals._neverSleepLockOn = false
        caffeinate.set("displayIdle", lastSleepSetting)

        _sleepNowCanvas:hide()
        _neverSleepCanvas:hide()
        _internals._screenWatcher:stop()
    end
    return self
end

--- SleepCorners:toggle([state]) -> self
--- Method
--- Toggles or sets whether or not SleepCorners is currently monitoring the defined screen corners for managing the system display's sleep state and displays an alert indicating the new state of the SleepCorners spoon.
---
--- Parameters:
---  * `state` - an optional boolean which specifies specifically whether SleepCorners should be started if it isn't already running (true) or stopped if it currently is running (false)
---
--- Returns:
---  * the SleepCorners spoon object
---
--- Notes:
---  * If `state` is not provided, this method will start SleepCorners if it is currently stopped or stop it if is currently started.
---  * `SleepCorners:toggle(true)` is equivalent to [SleepCorners:start()](#start) with the addition of displaying an alert specifying that SleepCorners is active.
---  * `SleepCorners:toggle(false)` is equivalent to [SleepCorners:stop()](#stop) with the addition of displaying an alert specifying that SleepCorners has been deactivated.
obj.toggle = function(self, value)
    -- in case called as function
    if self ~= obj then self, value = obj, self end
    local shouldTurnOn = not self:isActive()
    if type(value) == "boolean" then shouldTurnOn = value end
    if shouldTurnOn then
        self:start()
        alert("SleepCorners is now active")
    else
        self:stop()
        alert("SleepCorners has been deactivated")
    end
    return self
end

-- not really needed, so don't bother defining init
-- obj.init = function(self)
--     positionCanvas(_sleepNowCanvas, _internals.sleepNowCorner)
--     positionCanvas(_neverSleepCanvas, _internals.neverSleepCorner)
--     return self
-- end

--- SleepCorners:show([duration]) -> self
--- Method
--- Temporarily show the SleepCorner feedback images in their current locations as a reminder of their positions on the screen.
---
--- Parameters:
---  * `duration` - an optional number, default 3, specifying the number of seconds the feedback images should be displayed. If you specify `false` and the feedback images are currently being shown, the timer will be cur short and the images will be removed immediately.
---
--- Returns:
---  * the SleepCorners spoon object
---
--- Notes:
---  * this method will temporarily show the feedback images even if SleepCorners has been stopped (or has not yet been started).
obj.show = function(self, duration)
    -- in case called as function
    if self ~= obj then self, duration = obj, self end
    if duration == false then
        if _internals._showTimer then _internals._showTimer:fire() end
        return
    end

    duration = duration or 3
    -- disable sleepNow timer if it exists since we will be in an indeterminate state for a bit
    if _internals._sleepNowTimer then
        _internals._sleepNowTimer:stop()
        _internals._sleepNowTimer = nil
    end
    -- if the show timer exists, halt it so we don't get confused with multiple clean up callbacks
    if _internals._showTimer then
        _internals._showTimer:stop()
        _internals._showTimer = nil
    end

    local wasActive = self:isActive()
    _sleepNowCanvas:show()
    _sleepNowCanvas["image"].action = "strokeAndFill"
    _neverSleepCanvas:show()
    _neverSleepCanvas["image"].action = "strokeAndFill"
    _internals._showTimer = timer.doAfter(duration, function()
        _internals._showTimer:stop()
        _internals._showTimer = nil
        if not wasActive then
            _sleepNowCanvas:hide()
            _neverSleepCanvas:hide()
        end
        _sleepNowCanvas["image"].action = "skip"
        if not _internals._neverSleepLockOn then
            _neverSleepCanvas["image"].action = "skip"
        end
    end)
    return self
end

--- SleepCorners:bindHotkeys(mapping) -> self
--- Method
--- Binds hotkeys for SleepCorners
---
--- Parameters:
---  * `mapping` - A table containing hotkey modifier/key details for one or more of the following commands:
---    * "start"  - start monitoring the defined corners
---    * "stop"   - stop monitoring the defined corners
---    * "toggle" - toggles monitoring on or off
---    * "show"   - shows the current corners for 3 seconds as a reminder of their assigned locations
---
--- Returns:
---  * the SleepCorners spoon object
---
--- Notes:
---  * the `mapping` table is a table of one or more key-value pairs of the format `command = { { modifiers }, key }` where:
---    * `command`   - is one of the commands listed above
---    * `modifiers` - is a table containing keyboard modifiers, as specified in `hs.hotkey.bind()`
---    * `key`       - is a string containing the name of a keyboard key, as specified in `hs.hotkey.bind()`
obj.bindHotkeys = function(self, mapping)
    -- in case called as function
    if self ~= obj then self, mapping = obj, self end

    local def = {
        start  = obj.start,
        stop   = obj.stop,
        toggle = obj.toggle,
        show   = obj.show,
    }
    spoons.bindHotkeysToSpec(def, mapping)

    return self
end

obj._internals = _internals

return setmetatable(obj, {
    -- cleaner, IMHO, then "table: 0x????????????????"
    __tostring = function(self)
        local result, fieldSize = "", 0
        for i, v in ipairs(metadataKeys) do fieldSize = math.max(fieldSize, #v) end
        for i, v in ipairs(metadataKeys) do
            result = result .. string.format("%-"..tostring(fieldSize) .. "s %s\n", v, self[v])
        end
        return result
    end,

    -- I find it's easier to validate variables once as they're being set then to have to add
    -- a bunch of code everywhere else to verify that the variable was set to a valid/useful
    -- value each and every time I want to use it. Plus the user sees an error immediately
    -- rather then some obscure sort of halfway working until some special combination of things
    -- occurs... (ok, ok, it only reduces those situations but doesn't eliminate them entirely...)

    __index = function(self, key)
        if not tostring(key):match("^_") then
            return _internals[key]
        else
            return nil
        end
    end,
    __newindex = function(self, key, value)
        local errMsg = nil
        if key == "sleepNowCorner" then
            if type(value) == "string" and fnutils.contains(validScreenCorners, tostring(value):upper()) then
                _internals.sleepNowCorner = string.upper(value)
                positionCanvas(_sleepNowCanvas, _internals.sleepNowCorner)
            else
                errMsg = "sleepNowCorner must be one of " .. table.concat(validScreenCorners, ", ")
            end
        elseif key == "neverSleepCorner" then
            if type(value) == "string" and fnutils.contains(validScreenCorners, tostring(value):upper()) then
                _internals.neverSleepCorner = string.upper(value)
                positionCanvas(_neverSleepCanvas, _internals.neverSleepCorner)
            else
                errMsg = "neverSleepCorner must be one of " .. table.concat(validScreenCorners, ", ")
            end
        elseif key == "sleepDelay" then
            if type(value) == "number" then
                _internals.sleepDelay = value
            else
                errMsg = "sleepDelay must be a number"
            end
        elseif key == "feedbackSize" then
            if type(value) == "number" then
                _internals.feedbackSize = value
                positionCanvas(_sleepNowCanvas, _internals.sleepNowCorner)
                positionCanvas(_neverSleepCanvas, _internals.neverSleepCorner)
            else
                errMsg = "feedbackSize must be a number"
            end
        elseif key == "triggerSize" then
            if type(value) == "number" then
                _internals.triggerSize = value
                positionCanvas(_sleepNowCanvas, _internals.sleepNowCorner)
                positionCanvas(_neverSleepCanvas, _internals.neverSleepCorner)
            else
                errMsg = "triggerSize must be a number"
            end
        elseif key == "sleepScreen" then
            local testValue = (type(value) == "function" or (type(value) == "table" and (getmetatable(value) or {}).__call)) and value() or value
            if getmetatable(testValue) == hs.getObjectMetatable("hs.screen") then
                _internals.sleepScreen = value
                positionCanvas(_sleepNowCanvas, _internals.sleepNowCorner)
                positionCanvas(_neverSleepCanvas, _internals.neverSleepCorner)
            else
                errMsg = "sleepScreen must be an hs.screen object or a function which returns an hs.screen object"
            end
        elseif key == "preferSleepNow" then
            if type(value) == "boolean" then
                _internals.preferSleepNow = value
                _neverSleepCanvas:level(defaultLevel + (value and 0 or 1))
                _sleepNowCanvas:level(defaultLevel + (value and 1 or 0))
            else
                errMsg = "preferSleepNow must be a boolean"
            end
        elseif key == "immediateSleepModifiers" then
            local isBad = false
            if type(value) == "table" then
                for k,v in pairs(value) do
                    if not fnutils.contains(validModifierKeys, tostring(k):lower()) or not type(v) == "boolean" then
                        isBad = true
                        errMsg = "invalid key or value for " .. tostring(k) .. "; "
                        break
                    end
                end
                if not isBad then _internals.immediateSleepModifiers = value end
            elseif type(value) == "nil" then
                _internals.immediateSleepModifiers = {}
            else
                isBad = true
            end
            if isBad then
                errMsg = errMsg .. "immediateSleepModifiers must be a table containg true or false values for one or more of the following keys: " .. table.concat(validModifierKeys, ", ")
            end
        elseif key == "neverSleepLockModifiers" then
            local isBad = false
            if type(value) == "table" then
                for k,v in pairs(value) do
                    if not fnutils.contains(validModifierKeys, tostring(k):lower()) or not type(v) == "boolean" then
                        isBad = true
                        errMsg = "invalid key or value for " .. tostring(k) .. "; "
                        break
                    end
                end
                if not isBad then _internals.neverSleepLockModifiers = value end
            elseif type(value) == "nil" then
                _internals.neverSleepLockModifiers = {}
            else
                isBad = true
            end
            if isBad then
                errMsg = errMsg .. "neverSleepLockModifiers must be a table containg true or false values for one or more of the following keys: " .. table.concat(validModifierKeys, ", ")
            end
        elseif key == "sleepNowShouldLock" then
            if type(value) == "boolean" then
                _internals.sleepNowShouldLock = value
            else
                errMsg = "sleepNowShouldLock must be a boolean"
            end
        elseif key == "immediateSleepShouldLock" then
            if type(value) == "boolean" then
                _internals.immediateSleepShouldLock = value
            else
                errMsg = "immediateSleepShouldLock must be a boolean"
            end
        else
            errMsg = tostring(key) .. " is not a recognized paramter of SleepCorners"
        end

        if errMsg then error(errMsg, 2) end
    end
})
